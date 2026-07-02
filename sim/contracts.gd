# contracts.gd — сеемая доска контрактов
extends RefCounted

const Goods := preload("res://sim/goods.gd")

const MAX_OPEN_OFFERS := 3
const GENERATION_PERIOD := 4
const MIN_REACHABLE_TICKS := 3
const MOSCOW_DESTINATION_CHANCE := 0.6
const STATE_RELATIONS_COMPLETE := 6.0
const STATE_RELATIONS_FAIL := 8.0

const WEIGHTED_GOODS := [
	Goods.Good.ZHELEZO,
	Goods.Good.ZHELEZO,
	Goods.Good.MUKA,
	Goods.Good.MUKA,
	Goods.Good.VODKA,
	Goods.Good.CHUGUN,
]

const BASE_QTY := {
	Goods.Good.CHUGUN: 5.0,
	Goods.Good.ZHELEZO: 4.0,
	Goods.Good.MUKA: 8.0,
	Goods.Good.VODKA: 3.0,
}

var rng := RandomNumberGenerator.new()
var open_offers: Array[Dictionary] = []
var active: Array[Dictionary] = []
var next_contract_id := 1
var completed_count := {}
var notices: Array[String] = []


func setup(seed_value: int) -> void:
	rng.seed = seed_value
	open_offers.clear()
	active.clear()
	next_contract_id = 1
	completed_count.clear()
	notices.clear()


func refresh(economy) -> void:
	notices.clear()
	_complete_active(economy)
	_fail_expired(economy)
	_prune_stale_open(economy)
	if open_offers.size() < MAX_OPEN_OFFERS and economy.tick_count % GENERATION_PERIOD == 0:
		open_offers.append(_generate_offer(economy))


func accept(contract_id: int, agent, economy) -> bool:
	for i in range(open_offers.size()):
		var offer: Dictionary = open_offers[i]
		if offer.get("id", -1) != contract_id:
			continue
		var contract := offer.duplicate(true)
		var destination = economy.nodes[contract["destination_index"]]
		contract["taken_by"] = agent.id
		contract["baseline_sold"] = economy.sold_amount(agent, destination, contract["good"])
		active.append(contract)
		open_offers.remove_at(i)
		notices.append(
			"%s взял заказ: %s." % [agent.display_name, contract_line(contract, economy)]
		)
		return true
	return false


func decline(contract_id: int) -> bool:
	for i in range(open_offers.size()):
		if open_offers[i].get("id", -1) == contract_id:
			open_offers.remove_at(i)
			return true
	return false


func contracts_for_agent(agent_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in active:
		if c.get("taken_by", "") == agent_id:
			result.append(c)
	return result


func progress(c: Dictionary, economy) -> float:
	var agent = economy.agent_by_id(c.get("taken_by", ""))
	if agent == null:
		return 0.0
	var destination = economy.nodes[c["destination_index"]]
	return economy.sold_amount(agent, destination, c["good"]) - c.get("baseline_sold", 0.0)


func contract_line(c: Dictionary, economy) -> String:
	var destination = economy.nodes[c["destination_index"]]
	var good_name: String = Goods.NAMES[c["good"]]
	var delivered := progress(c, economy) if c.get("taken_by", "") != "" else 0.0
	var ticks_left: int = max(0, c["deadline_tick"] - economy.tick_count)
	if c.get("taken_by", "") == "":
		return (
			"%s: %.1f в %s до тика %d, награда %.0f, штраф %.0f"
			% [good_name, c["qty"], destination.name, c["deadline_tick"], c["reward"], c["penalty"]]
		)
	return (
		"%s: %.1f / %.1f в %s, осталось %d т."
		% [good_name, delivered, c["qty"], destination.name, ticks_left]
	)


func to_save_data() -> Dictionary:
	return {
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"open_offers": open_offers,
		"active": active,
		"next_contract_id": next_contract_id,
		"completed_count": completed_count,
	}


func load_save_data(data: Dictionary, seed_value: int) -> void:
	rng.seed = data.get("rng_seed", seed_value)
	rng.state = data.get("rng_state", rng.state)
	open_offers.clear()
	for c in data.get("open_offers", []):
		open_offers.append(c)
	active.clear()
	for c in data.get("active", []):
		active.append(c)
	next_contract_id = data.get("next_contract_id", 1)
	completed_count = data.get("completed_count", {}).duplicate(true)
	notices.clear()


func _complete_active(economy) -> void:
	var remaining: Array[Dictionary] = []
	for c in active:
		var agent = economy.agent_by_id(c.get("taken_by", ""))
		if agent == null:
			continue
		if progress(c, economy) >= c["qty"]:
			agent.money += c["reward"]
			agent.state_relations = min(100.0, agent.state_relations + c["relations_bonus"])
			completed_count[agent.id] = completed_count.get(agent.id, 0) + 1
			notices.append(
				"%s выполнил заказ №%d. Награда %.0f." % [agent.display_name, c["id"], c["reward"]]
			)
		else:
			remaining.append(c)
	active = remaining


func _fail_expired(economy) -> void:
	var remaining: Array[Dictionary] = []
	for c in active:
		var agent = economy.agent_by_id(c.get("taken_by", ""))
		if agent == null:
			continue
		if economy.tick_count >= c["deadline_tick"]:
			agent.money = max(0.0, agent.money - c["penalty"])
			agent.state_relations = max(0.0, agent.state_relations - c["relations_penalty"])
			notices.append(
				"%s сорвал заказ №%d. Штраф %.0f." % [agent.display_name, c["id"], c["penalty"]]
			)
		else:
			remaining.append(c)
	active = remaining


func _prune_stale_open(economy) -> void:
	var fresh: Array[Dictionary] = []
	for c in open_offers:
		if c["deadline_tick"] > economy.tick_count + MIN_REACHABLE_TICKS:
			fresh.append(c)
	open_offers = fresh


func _generate_offer(economy) -> Dictionary:
	var good: int = WEIGHTED_GOODS[rng.randi_range(0, WEIGHTED_GOODS.size() - 1)]
	var destination_index := _choose_destination_index(economy)
	var tier := rng.randi_range(1, 3)
	var qty: float = BASE_QTY[good] * tier * rng.randf_range(0.8, 1.2)
	var deadline_tick: int = economy.tick_count + 10 + tier * 4
	var destination = economy.nodes[destination_index]
	var destination_factor: float = clamp(
		destination.price(good) / Goods.BASE_PRICE[good], 0.8, 1.4
	)
	var reward: float = (
		qty * Goods.BASE_PRICE[good] * destination_factor * rng.randf_range(1.3, 1.6)
	)
	var contract_id := next_contract_id
	next_contract_id += 1
	return {
		"id": contract_id,
		"good": good,
		"qty": snapped(qty, 0.1),
		"destination_index": destination_index,
		"deadline_tick": deadline_tick,
		"reward": snapped(reward, 1.0),
		"penalty": snapped(reward * 0.5, 1.0),
		"relations_bonus": STATE_RELATIONS_COMPLETE,
		"relations_penalty": STATE_RELATIONS_FAIL,
		"taken_by": "",
		"baseline_sold": 0.0,
	}


func _choose_destination_index(economy) -> int:
	var moskva_index := _node_index_by_name(economy, "Москва")
	if moskva_index >= 0 and rng.randf() < MOSCOW_DESTINATION_CHANCE:
		return moskva_index
	return rng.randi_range(0, economy.nodes.size() - 1)


func _node_index_by_name(economy, node_name: String) -> int:
	for i in range(economy.nodes.size()):
		if economy.nodes[i].name == node_name:
			return i
	return -1
