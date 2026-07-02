# gameplay.gd — тонкий игровой слой: контракты, события, ход сценария
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")
const Economy := preload("res://sim/economy.gd")
const ContractBoard := preload("res://sim/contracts.gd")
const DemoScenario := preload("res://sim/demo_scenario.gd")
const EventCatalog := preload("res://sim/event_catalog.gd")

const SCENARIO_SEED := 1725
const SAVE_VERSION := 4
const LLM_CONTEXT_VERSION := 1
const DEFAULT_SAVE_PATH := "user://savegame.json"

const GRAIN_ROUTE_TICKS := DemoScenario.GRAIN_ROUTE_TICKS
const IRON_ROUTE_TICKS := DemoScenario.IRON_ROUTE_TICKS

var economy := Economy.new()
var board := ContractBoard.new()
var scenario := {}
var notices: Array[String] = []
var pending_event := {}
var completed_event_ids := {}


func setup() -> void:
	scenario = DemoScenario.setup(economy)
	board.setup(SCENARIO_SEED)
	_add_notice("Приказная доска открыта: новые заказы появляются раз в четыре тика.")


func advance_tick() -> void:
	if has_pending_event():
		return
	economy.tick()
	board.refresh(economy)
	_drain_contract_notices()
	DemoScenario.run_logistics(
		economy, scenario["nevyansk"], scenario["makarievo"], scenario["moskva"]
	)
	_maybe_raise_event()


func open_contracts() -> Array[Dictionary]:
	return board.open_offers


func player_contracts() -> Array[Dictionary]:
	return board.contracts_for_agent(economy.player.id)


func accept_contract(contract_id: int) -> bool:
	var ok := board.accept(contract_id, economy.player, economy)
	_drain_contract_notices()
	return ok


func decline_contract(contract_id: int) -> bool:
	return board.decline(contract_id)


func contract_line(c: Dictionary) -> String:
	return board.contract_line(c, economy)


func contract_status_text() -> String:
	var active_count := player_contracts().size()
	var open_count := open_contracts().size()
	var completed: int = board.completed_count.get(economy.player.id, 0)
	return "Заказы: открыто %d, активно %d, выполнено %d" % [open_count, active_count, completed]


func has_pending_event() -> bool:
	return not pending_event.is_empty()


func pending_event_title() -> String:
	return pending_event.get("title", "")


func pending_event_body() -> String:
	return pending_event.get("generated_body", pending_event.get("body", ""))


func pending_event_choices() -> Array:
	return pending_event.get("choices", [])


func pending_event_tags() -> Array:
	return pending_event.get("tags", [])


func set_pending_event_narrative(text: String) -> void:
	if pending_event.is_empty():
		return
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		return
	pending_event["generated_body"] = clean_text
	_add_notice("Событие получило LLM-описание.")


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

	load_save_data(_migrate_save(parsed))
	_add_notice("Игра загружена.")
	return true


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"economy": economy.to_save_data(),
		"notices": notices,
		"pending_event": pending_event,
		"completed_event_ids": completed_event_ids.keys(),
		"contracts": board.to_save_data(),
	}


func to_llm_context() -> Dictionary:
	return {
		"schema_version": LLM_CONTEXT_VERSION,
		"purpose": "narrative_generation_only",
		"language": "ru",
		"style_constraints":
		[
			"Живой русский язык без клюквы и канцелярита.",
			"LLM не меняет числа симуляции и не придумывает новые эффекты.",
			"Ответ должен опираться только на переданные факты, ставки и варианты выбора.",
		],
		"world":
		{
			"period": "петровская и раннепослепетровская Россия, примерно 1700-1745",
			"themes":
			[
				"частный капитал",
				"казна",
				"дом Антуфьевых-Демидовых",
				"уральские заводы",
				"ярмарочная логистика",
			],
		},
		"state":
		{
			"tick": economy.tick_count,
			"player_money": economy.player.money,
			"state_relations": economy.player.state_relations,
			"contracts":
			{
				"open": _contracts_for_llm(open_contracts()),
				"active": _contracts_for_llm(player_contracts()),
				"completed_count": board.completed_count.get(economy.player.id, 0),
			},
			"nodes": _nodes_for_llm(),
			"enterprises": _enterprises_for_llm(),
			"caravans": _caravans_for_llm(),
			"construction": _construction_for_llm(),
		},
		"pending_event": _pending_event_for_llm(),
		"recent_notices": notices,
	}


func load_save_data(data: Dictionary) -> void:
	data = _migrate_save(data)
	economy = Economy.new()
	economy.load_save_data(data.get("economy", {}))
	board = ContractBoard.new()
	board.load_save_data(data.get("contracts", {}), SCENARIO_SEED)
	scenario = _scenario_from_economy()

	notices.clear()
	for notice in data.get("notices", []):
		notices.append(notice)

	pending_event = data.get("pending_event", {})
	completed_event_ids.clear()
	for event_id in data.get("completed_event_ids", []):
		completed_event_ids[event_id] = true

	_drain_contract_notices()


func _maybe_raise_event() -> void:
	if has_pending_event():
		return
	for event_def in EventCatalog.all():
		if _event_is_available(event_def):
			_raise_event(event_def["id"])
			return


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
	var event_def := EventCatalog.find(event_id)
	if event_def.is_empty():
		return
	pending_event = event_def.duplicate(true)


func _event_is_available(event_def: Dictionary) -> bool:
	var event_id: String = event_def.get("id", "")
	if event_id.is_empty() or completed_event_ids.has(event_id):
		return false

	var trigger: Dictionary = event_def.get("trigger", {})
	if trigger.has("tick") and economy.tick_count != trigger["tick"]:
		return false
	if trigger.has("from_tick") and economy.tick_count < trigger["from_tick"]:
		return false
	if trigger.has("until_tick") and economy.tick_count > trigger["until_tick"]:
		return false

	return _event_conditions_met(event_def.get("conditions", {}))


func _event_conditions_met(conditions: Dictionary) -> bool:
	if conditions.has("min_money") and economy.player.money < conditions["min_money"]:
		return false
	if (
		conditions.has("max_state_relations")
		and economy.player.state_relations > conditions["max_state_relations"]
	):
		return false
	if (
		conditions.has("min_state_relations")
		and economy.player.state_relations < conditions["min_state_relations"]
	):
		return false
	if conditions.has("node_stock_below") and not _node_stock_below(conditions["node_stock_below"]):
		return false
	return true


func _node_stock_below(rule: Dictionary) -> bool:
	var node := _find_node(rule.get("node", ""))
	var good: int = rule.get("good", Goods.Good.ZERNO)
	return node.stock[good] < rule.get("value", 0.0)


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
			economy.player,
			makarievo,
			nevyansk,
			Goods.Good.ZERNO,
			effect["grain_to_nevyansk"],
			DemoScenario.GRAIN_ROUTE_TICKS
		)
	if effect.has("makarievo_grain_target"):
		var makarievo: TradeNode = scenario["makarievo"]
		makarievo.target_stock[Goods.Good.ZERNO] = effect["makarievo_grain_target"]


func _migrate_save(data: Dictionary) -> Dictionary:
	var version: int = data.get("version", 1)
	if version >= 2:
		return data

	var migrated := data.duplicate(true)
	var economy_data: Dictionary = migrated.get("economy", {})
	var player_data: Dictionary = economy_data.get("player", {})
	economy_data["agents"] = [
		{
			"id": "player",
			"name": "Демидов",
			"is_player": true,
			"money": player_data.get("money", 500.0),
			"state_relations": player_data.get("state_relations", 50.0),
		}
	]

	for e_data in economy_data.get("enterprises", []):
		e_data["owner"] = e_data.get("owner", "player")

	for c_data in economy_data.get("caravans", []):
		c_data["owner"] = c_data.get("owner", "player")

	for s_data in economy_data.get("sold_total", []):
		s_data["agent"] = s_data.get("agent", "player")

	migrated["economy"] = economy_data
	migrated["version"] = 2
	return migrated


func _add_notice(text: String) -> void:
	notices.push_front("Тик %d: %s" % [economy.tick_count, text])
	if notices.size() > 8:
		notices.resize(8)


func _drain_contract_notices() -> void:
	for notice in board.notices:
		_add_notice(notice)
	board.notices.clear()


func _nodes_for_llm() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for n in economy.nodes:
		var goods_state: Array[Dictionary] = []
		for g in Goods.Good.values():
			(
				goods_state
				. append(
					{
						"good": Goods.NAMES[g],
						"stock": n.stock[g],
						"target_stock": n.target_stock[g],
						"price": n.price(g),
						"target_price": n.target_price(g),
						"consumption_per_tick": n.consumption[g],
						"market_pressure": _market_pressure(n, g),
					}
				)
			)
		(
			result
			. append(
				{
					"name": n.name,
					"goods": goods_state,
					"available_hired_workers": n.labor_pool[Labor.Type.HIRED],
				}
			)
		)
	return result


func _contracts_for_llm(contracts: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in contracts:
		var destination: TradeNode = economy.nodes[c["destination_index"]]
		(
			result
			. append(
				{
					"id": c["id"],
					"good": Goods.NAMES[c["good"]],
					"qty": c["qty"],
					"destination": destination.name,
					"deadline_tick": c["deadline_tick"],
					"reward": c["reward"],
					"penalty": c["penalty"],
					"taken_by": c.get("taken_by", ""),
					"delivered": board.progress(c, economy) if c.get("taken_by", "") != "" else 0.0,
				}
			)
		)
	return result


func _enterprises_for_llm() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in economy.player.enterprises:
		(
			result
			. append(
				{
					"name": e.name,
					"node": e.node.name,
					"recipe": e.recipe,
					"capacity": e.capacity,
					"effective_capacity": e.effective_capacity(),
					"hired_wage_offer": e.hired_wage_offer,
					"workers":
					{
						Labor.NAMES[Labor.Type.HIRED]: e.workers[Labor.Type.HIRED],
						Labor.NAMES[Labor.Type.ASCRIBED]: e.workers[Labor.Type.ASCRIBED],
						Labor.NAMES[Labor.Type.POSSESSIONAL]: e.workers[Labor.Type.POSSESSIONAL],
					},
				}
			)
		)
	return result


func _caravans_for_llm() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in economy.caravans:
		(
			result
			. append(
				{
					"origin": c.origin.name,
					"destination": c.destination.name,
					"good": Goods.NAMES[c.good],
					"qty": c.qty,
					"remaining_ticks": c.remaining_ticks,
					"sell_on_arrival": c.sell_on_arrival,
				}
			)
		)
	return result


func _construction_for_llm() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in economy.construction_queue:
		(
			result
			. append(
				{
					"owner": c.owner_id,
					"node": c.node.name,
					"recipe": c.recipe,
					"display_name": c.display_name,
					"capacity": c.capacity,
					"remaining_ticks": c.remaining_ticks,
					"possessional_workers": c.possessional_workers,
					"is_expansion": c.expand_target != null,
				}
			)
		)
	return result


func _pending_event_for_llm() -> Dictionary:
	if pending_event.is_empty():
		return {}

	var choices: Array[Dictionary] = []
	for choice in pending_event.get("choices", []):
		(
			choices
			. append(
				{
					"text": choice.get("text", ""),
					"effect_summary": choice.get("effect_summary", ""),
					"result_summary": choice.get("result", ""),
					"llm_hint": choice.get("llm_hint", ""),
				}
			)
		)

	return {
		"id": pending_event.get("id", ""),
		"title": pending_event.get("title", ""),
		"body": pending_event.get("body", ""),
		"tags": pending_event.get("tags", []),
		"participants": pending_event.get("participants", []),
		"location": pending_event.get("location", ""),
		"stakes": pending_event.get("stakes", ""),
		"llm_context": pending_event.get("llm_context", {}),
		"choices": choices,
	}


func _market_pressure(n: TradeNode, g: int) -> String:
	var target: float = n.target_price(g)
	var base: float = Goods.BASE_PRICE[g]
	if target >= base * 1.35:
		return "shortage"
	if target <= base * 0.75:
		return "surplus"
	return "stable"
