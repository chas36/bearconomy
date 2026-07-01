# gameplay.gd — тонкий игровой слой: контракт, события, ход сценария
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")
const Economy := preload("res://sim/economy.gd")
const DemoScenario := preload("res://sim/demo_scenario.gd")

const CONTRACT_GOOD := Goods.Good.ZHELEZO
const CONTRACT_TARGET := 16.0
const CONTRACT_DEADLINE := 18
const CONTRACT_REWARD := 240.0
const CONTRACT_PENALTY := 140.0
const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://savegame.json"

const EVENT_STATE_INSPECTION := "state_inspection"
const EVENT_WORKER_DEMAND := "worker_demand"
const EVENT_FAIR_SHORTAGE := "fair_shortage"
const GRAIN_ROUTE_TICKS := DemoScenario.GRAIN_ROUTE_TICKS
const IRON_ROUTE_TICKS := DemoScenario.IRON_ROUTE_TICKS

var economy := Economy.new()
var scenario := {}
var notices: Array[String] = []
var pending_event := {}
var completed_event_ids := {}
var contract_start_sold := 0.0
var contract_done := false
var contract_failed := false


func setup() -> void:
	scenario = DemoScenario.setup(economy)
	var moskva: TradeNode = scenario["moskva"]
	contract_start_sold = economy.sold_amount(moskva, CONTRACT_GOOD)
	_add_notice(
		"Заказ: поставить %.0f железа в Москву до тика %d." % [CONTRACT_TARGET, CONTRACT_DEADLINE]
	)


func advance_tick() -> void:
	if has_pending_event():
		return
	economy.tick()
	DemoScenario.run_logistics(
		economy, scenario["nevyansk"], scenario["makarievo"], scenario["moskva"]
	)
	_check_contract()
	_maybe_raise_event()


func contract_progress() -> float:
	var moskva: TradeNode = scenario["moskva"]
	return economy.sold_amount(moskva, CONTRACT_GOOD) - contract_start_sold


func contract_status_text() -> String:
	if contract_done:
		return "Выполнен: поставлено %.1f / %.1f железа" % [contract_progress(), CONTRACT_TARGET]
	if contract_failed:
		return "Провален: поставлено %.1f / %.1f железа" % [contract_progress(), CONTRACT_TARGET]
	var ticks_left: int = max(0, CONTRACT_DEADLINE - economy.tick_count)
	return (
		"Поставить %.1f / %.1f железа в Москву, осталось %d т."
		% [contract_progress(), CONTRACT_TARGET, ticks_left]
	)


func has_pending_event() -> bool:
	return not pending_event.is_empty()


func pending_event_title() -> String:
	return pending_event.get("title", "")


func pending_event_body() -> String:
	return pending_event.get("body", "")


func pending_event_choices() -> Array:
	return pending_event.get("choices", [])


func choose_event(choice_index: int) -> void:
	if pending_event.is_empty():
		return
	var choices: Array = pending_event["choices"]
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]
	_apply_event_effect(choice["effect"])
	_add_notice(choice["result"])
	completed_event_ids[pending_event["id"]] = true
	pending_event = {}


func save_to_file(path := DEFAULT_SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_add_notice("Не удалось открыть файл сохранения.")
		return false
	file.store_string(JSON.stringify(to_save_data(), "\t"))
	_add_notice("Игра сохранена.")
	return true


func load_from_file(path := DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		_add_notice("Файл сохранения не найден.")
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_add_notice("Не удалось прочитать файл сохранения.")
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_add_notice("Файл сохранения повреждён.")
		return false

	load_save_data(parsed)
	_add_notice("Игра загружена.")
	return true


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"economy": economy.to_save_data(),
		"notices": notices,
		"pending_event": pending_event,
		"completed_event_ids": completed_event_ids.keys(),
		"contract_start_sold": contract_start_sold,
		"contract_done": contract_done,
		"contract_failed": contract_failed,
	}


func load_save_data(data: Dictionary) -> void:
	economy = Economy.new()
	economy.load_save_data(data.get("economy", {}))
	scenario = _scenario_from_economy()

	notices.clear()
	for notice in data.get("notices", []):
		notices.append(notice)

	pending_event = data.get("pending_event", {})
	completed_event_ids.clear()
	for event_id in data.get("completed_event_ids", []):
		completed_event_ids[event_id] = true

	contract_start_sold = data.get("contract_start_sold", 0.0)
	contract_done = data.get("contract_done", false)
	contract_failed = data.get("contract_failed", false)


func _check_contract() -> void:
	if contract_done or contract_failed:
		return
	if contract_progress() >= CONTRACT_TARGET:
		contract_done = true
		economy.player.money += CONTRACT_REWARD
		economy.player.state_relations = min(100.0, economy.player.state_relations + 8.0)
		_add_notice(
			"Московский заказ закрыт. Награда %.0f, связи с казной выросли." % CONTRACT_REWARD
		)
		return
	if economy.tick_count >= CONTRACT_DEADLINE:
		contract_failed = true
		economy.player.money = max(0.0, economy.player.money - CONTRACT_PENALTY)
		economy.player.state_relations = max(0.0, economy.player.state_relations - 12.0)
		_add_notice(
			"Срок московского заказа сорван. Штраф %.0f и удар по связям." % CONTRACT_PENALTY
		)


func _maybe_raise_event() -> void:
	if has_pending_event():
		return
	if economy.tick_count == 5:
		_raise_event(EVENT_STATE_INSPECTION)
	if economy.tick_count == 9:
		_raise_event(EVENT_WORKER_DEMAND)
	if economy.tick_count == 13:
		_raise_event(EVENT_FAIR_SHORTAGE)


func _scenario_from_economy() -> Dictionary:
	var nevyansk := _find_node("Невьянск")
	var makarievo := _find_node("Макарьево")
	var moskva := _find_node("Москва")
	return {
		"nevyansk": nevyansk,
		"makarievo": makarievo,
		"moskva": moskva,
		"domna": _find_enterprise("Домна"),
		"kuznitsa": _find_enterprise("Кузница"),
	}


func _find_node(node_name: String) -> TradeNode:
	for n in economy.nodes:
		if n.name == node_name:
			return n
	return economy.nodes[0]


func _find_enterprise(enterprise_name: String) -> Enterprise:
	for e in economy.player.enterprises:
		if e.name == enterprise_name:
			return e
	return economy.player.enterprises[0]


func _raise_event(event_id: String) -> void:
	if completed_event_ids.has(event_id):
		return
	if event_id == EVENT_STATE_INSPECTION:
		pending_event = {
			"id": event_id,
			"title": "Казённый смотр",
			"body": "В Невьянск приехал приказчик. Дар сгладит вопросы к посессионным.",
			"choices":
			[
				{
					"text": "Дать 45 денег",
					"effect": {"money": -45.0, "state_relations": 8.0},
					"result": "Приказчик уехал довольным. Связи с казной укрепились.",
				},
				{
					"text": "Отказать",
					"effect": {"state_relations": -10.0},
					"result": "Приказчик запомнил холодный приём.",
				},
			],
		}
	elif event_id == EVENT_WORKER_DEMAND:
		pending_event = {
			"id": event_id,
			"title": "Слух о больших ставках",
			"body": "Наёмные на кузнице услышали, что в Верхотурье платят лучше.",
			"choices":
			[
				{
					"text": "Поднять ставку кузницы",
					"effect": {"kuznitsa_wage": 2.0},
					"result": "Кузница подняла ставку. Люди охотнее держатся за место.",
				},
				{
					"text": "Не уступать",
					"effect": {"kuznitsa_wage": 1.2},
					"result": "Ставка снижена. Часть людей может уйти после следующего тика.",
				},
			],
		}
	elif event_id == EVENT_FAIR_SHORTAGE:
		pending_event = {
			"id": event_id,
			"title": "Зерно на ярмарке дорожает",
			"body": "На Макарьевской ярмарке купцы придерживают зерно до большой воды.",
			"choices":
			[
				{
					"text": "Закупить сейчас",
					"effect": {"money": -8.0, "grain_to_nevyansk": 10.0},
					"result": "Зерно выкуплено и сразу отправлено на завод.",
				},
				{
					"text": "Переждать",
					"effect": {"makarievo_grain_target": 90.0},
					"result": "Спрос на ярмарке вырос. Следующие закупки станут дороже.",
				},
			],
		}


func _apply_event_effect(effect: Dictionary) -> void:
	if effect.has("money"):
		economy.player.money = max(0.0, economy.player.money + effect["money"])
	if effect.has("state_relations"):
		economy.player.state_relations = clamp(
			economy.player.state_relations + effect["state_relations"], 0.0, 100.0
		)
	if effect.has("kuznitsa_wage"):
		var kuznitsa: Enterprise = scenario["kuznitsa"]
		economy.set_hired_wage_offer(kuznitsa, effect["kuznitsa_wage"])
	if effect.has("grain_stock"):
		var makarievo: TradeNode = scenario["makarievo"]
		makarievo.stock[Goods.Good.ZERNO] = max(
			0.0, makarievo.stock[Goods.Good.ZERNO] + effect["grain_stock"]
		)
	if effect.has("grain_to_nevyansk"):
		var nevyansk: TradeNode = scenario["nevyansk"]
		var makarievo: TradeNode = scenario["makarievo"]
		economy.dispatch(
			makarievo,
			nevyansk,
			Goods.Good.ZERNO,
			effect["grain_to_nevyansk"],
			DemoScenario.GRAIN_ROUTE_TICKS
		)
	if effect.has("makarievo_grain_target"):
		var makarievo: TradeNode = scenario["makarievo"]
		makarievo.target_stock[Goods.Good.ZERNO] = effect["makarievo_grain_target"]


func _add_notice(text: String) -> void:
	notices.push_front("Тик %d: %s" % [economy.tick_count, text])
	if notices.size() > 8:
		notices.resize(8)
