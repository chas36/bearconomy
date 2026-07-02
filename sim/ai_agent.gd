# ai_agent.gd — детерминированный fallback-контроллер дома-конкурента
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const Recipes := preload("res://sim/recipes.gd")
const TradeNode := preload("res://sim/trade_node.gd")

const GRAIN_BUFFER_TICKS := 6.0
const MAX_GRAIN_SPEND_SHARE := 0.25
const WAGE_STEP := 0.1
const MAX_HIRED_WAGE := 2.6
const MAX_ACTIVE_CONTRACTS := 2
const CONTRACT_MARGIN_SHARE := 0.15
const ROUTE_COST_PER_UNIT_TICK := 0.05
const BUILD_MONEY_THRESHOLD := 600.0
const BUILD_CAPACITY := 1.0
const BUILD_POSSESSIONAL_WORKERS := 2
const MIN_ACTION_QTY := 0.5
const MAX_SURPLUS_DISPATCH := 4.0
const NEGATIVE_MARGIN := -1000000000.0

var agent_id: String


func _init(id := "") -> void:
	agent_id = id


func act(economy, board) -> void:
	var agent = economy.agent_by_id(agent_id)
	if agent == null:
		return

	_ensure_grain_buffer(agent, economy)
	_adjust_wages(agent, economy)
	_accept_best_contract(agent, economy, board)
	_fulfill_contracts(agent, economy, board)
	_start_best_construction(agent, economy)
	_sell_surplus(agent, economy)


func _ensure_grain_buffer(agent, economy) -> void:
	for n in _owned_nodes(agent):
		var grain_need := 0.0
		for e in agent.enterprises:
			if e.node != n:
				continue
			for labor_type in e.workers:
				grain_need += e.workers[labor_type] * Labor.UPKEEP_GRAIN[labor_type]
		grain_need *= GRAIN_BUFFER_TICKS

		var gap: float = grain_need - n.stock[Goods.Good.ZERNO]
		gap -= _cargo_in_transit_to(agent, economy, n, Goods.Good.ZERNO)
		if gap <= MIN_ACTION_QTY:
			continue

		var source: TradeNode = _cheapest_source(economy, n, Goods.Good.ZERNO)
		if source == null:
			continue
		var price: float = source.price(Goods.Good.ZERNO)
		if price <= 0.0:
			continue

		var budget: float = agent.money * MAX_GRAIN_SPEND_SHARE
		var qty: float = min(gap, source.stock[Goods.Good.ZERNO], budget / price)
		if qty > MIN_ACTION_QTY:
			economy.buy_and_dispatch(
				agent, source, n, Goods.Good.ZERNO, qty, _route_ticks(source, n)
			)
			return


func _adjust_wages(agent, economy) -> void:
	for e in agent.enterprises:
		if e.open_worker_slots() > 0:
			var raised: float = min(MAX_HIRED_WAGE, e.hired_wage_offer + WAGE_STEP)
			if not is_equal_approx(raised, e.hired_wage_offer):
				economy.set_hired_wage_offer(e, raised)
		elif e.hired_wage_offer > Labor.HIRED_RESERVATION_WAGE + WAGE_STEP:
			var lowered: float = max(Labor.HIRED_RESERVATION_WAGE, e.hired_wage_offer - WAGE_STEP)
			if not is_equal_approx(lowered, e.hired_wage_offer):
				economy.set_hired_wage_offer(e, lowered)


func _accept_best_contract(agent, economy, board) -> void:
	if board.contracts_for_agent(agent.id).size() >= MAX_ACTIVE_CONTRACTS:
		return

	var best_contract := {}
	var best_margin := NEGATIVE_MARGIN
	for c in board.open_offers:
		if not _can_supply_contract(agent, economy, c):
			continue
		var margin := _contract_margin(agent, economy, c)
		if margin > best_margin:
			best_margin = margin
			best_contract = c

	if best_contract.is_empty():
		return
	if best_margin <= best_contract["reward"] * CONTRACT_MARGIN_SHARE:
		return
	board.accept(best_contract["id"], agent, economy)


func _fulfill_contracts(agent, economy, board) -> void:
	for c in board.contracts_for_agent(agent.id):
		var destination: TradeNode = economy.nodes[c["destination_index"]]
		var remaining: float = c["qty"] - board.progress(c, economy)
		if remaining <= MIN_ACTION_QTY:
			continue

		var source: TradeNode = _best_owned_stock_node(agent, c["good"], destination)
		if source == null:
			continue
		var route_ticks := _route_ticks(source, destination)
		if route_ticks <= 0 or route_ticks > c["deadline_tick"] - economy.tick_count:
			continue

		var qty: float = min(remaining, source.stock[c["good"]])
		if qty > MIN_ACTION_QTY:
			economy.dispatch(agent, source, destination, c["good"], qty, route_ticks, true)


func _start_best_construction(agent, economy) -> void:
	if agent.money <= BUILD_MONEY_THRESHOLD or _has_active_construction(agent, economy):
		return

	var best_node: TradeNode = null
	var best_recipe := ""
	var best_margin := 0.0
	for n in _owned_nodes(agent):
		for recipe in Recipes.DEFS:
			var margin := _recipe_margin_at_node(recipe, n)
			if margin > best_margin:
				best_margin = margin
				best_node = n
				best_recipe = recipe

	if best_node == null or best_recipe.is_empty():
		return

	var existing = _enterprise_for_recipe_at_node(agent, best_recipe, best_node)
	if existing != null:
		economy.expand_enterprise(agent, existing, BUILD_CAPACITY)
	else:
		economy.start_construction(
			agent, best_node, best_recipe, BUILD_CAPACITY, BUILD_POSSESSIONAL_WORKERS
		)


func _sell_surplus(agent, economy) -> void:
	for e in agent.enterprises:
		var recipe: Dictionary = Recipes.DEFS[e.recipe]
		for good in recipe["out"]:
			var reserve: float = max(e.node.target_stock[good], recipe["out"][good] * 2.0)
			var surplus: float = e.node.stock[good] - reserve
			if surplus <= MIN_ACTION_QTY:
				continue

			var destination: TradeNode = _best_sale_destination(economy, e.node, good)
			if destination == null:
				continue
			var route_ticks := _route_ticks(e.node, destination)
			var min_price: float = e.node.price(good) + route_ticks * ROUTE_COST_PER_UNIT_TICK
			if destination.price(good) <= min_price:
				continue

			var qty: float = min(surplus, MAX_SURPLUS_DISPATCH)
			economy.dispatch(agent, e.node, destination, good, qty, route_ticks, true)
			return


func _can_supply_contract(agent, economy, c: Dictionary) -> bool:
	var destination: TradeNode = economy.nodes[c["destination_index"]]
	var best_source: TradeNode = _best_contract_source(agent, economy, c["good"], destination)
	if best_source == null:
		return false

	var route_ticks := _route_ticks(best_source, destination)
	if route_ticks <= 0 or route_ticks > c["deadline_tick"] - economy.tick_count:
		return false

	var available := 0.0
	for n in _owned_nodes(agent):
		available += n.stock[c["good"]]
	var producible: float = _production_per_tick(agent, c["good"])
	var production_ticks: int = max(0, c["deadline_tick"] - economy.tick_count - route_ticks)
	return available + producible * production_ticks >= c["qty"] * 0.8


func _contract_margin(agent, economy, c: Dictionary) -> float:
	var destination: TradeNode = economy.nodes[c["destination_index"]]
	var source: TradeNode = _best_contract_source(agent, economy, c["good"], destination)
	if source == null:
		return NEGATIVE_MARGIN
	var route_ticks := _route_ticks(source, destination)
	return (
		c["reward"]
		- c["qty"] * source.price(c["good"])
		- c["qty"] * ROUTE_COST_PER_UNIT_TICK * route_ticks
	)


func _best_contract_source(agent, economy, good: int, destination: TradeNode) -> TradeNode:
	var best: TradeNode = null
	var best_price := INF
	for n in economy.nodes:
		if n == destination:
			continue
		if n.stock[good] <= MIN_ACTION_QTY and _production_at_node(agent, n, good) <= 0.0:
			continue
		var price: float = n.price(good)
		if price < best_price:
			best_price = price
			best = n
	return best


func _best_owned_stock_node(agent, good: int, destination: TradeNode) -> TradeNode:
	var best: TradeNode = null
	var best_qty := 0.0
	for n in _owned_nodes(agent):
		if n == destination or n.stock[good] <= MIN_ACTION_QTY:
			continue
		var route_ticks := _route_ticks(n, destination)
		if route_ticks <= 0:
			continue
		if n.stock[good] > best_qty:
			best_qty = n.stock[good]
			best = n
	return best


func _cheapest_source(economy, destination: TradeNode, good: int) -> TradeNode:
	var best: TradeNode = null
	var best_price := INF
	for n in economy.nodes:
		if n == destination or n.stock[good] <= MIN_ACTION_QTY:
			continue
		var price: float = n.price(good)
		if price < best_price:
			best_price = price
			best = n
	return best


func _best_sale_destination(economy, origin: TradeNode, good: int) -> TradeNode:
	var best: TradeNode = null
	var best_price: float = origin.price(good)
	for n in economy.nodes:
		if n == origin:
			continue
		var price: float = n.price(good)
		if price > best_price:
			best_price = price
			best = n
	return best


func _owned_nodes(agent) -> Array[TradeNode]:
	var result: Array[TradeNode] = []
	for e in agent.enterprises:
		if not result.has(e.node):
			result.append(e.node)
	return result


func _cargo_in_transit_to(agent, economy, destination: TradeNode, good: int) -> float:
	var total := 0.0
	for c in economy.caravans:
		if c.owner_id == agent.id and c.destination == destination and c.good == good:
			total += c.qty
	return total


func _production_per_tick(agent, good: int) -> float:
	var total := 0.0
	for e in agent.enterprises:
		total += _production_at_enterprise(e, good)
	return total


func _production_at_node(agent, node: TradeNode, good: int) -> float:
	var total := 0.0
	for e in agent.enterprises:
		if e.node == node:
			total += _production_at_enterprise(e, good)
	return total


func _production_at_enterprise(e, good: int) -> float:
	var recipe: Dictionary = Recipes.DEFS[e.recipe]
	if not recipe["out"].has(good):
		return 0.0
	return recipe["out"][good] * e.effective_capacity()


func _recipe_margin_at_node(recipe: String, node: TradeNode) -> float:
	var def: Dictionary = Recipes.DEFS[recipe]
	var revenue := 0.0
	for good in def["out"]:
		revenue += def["out"][good] * node.price(good)
	var inputs := 0.0
	for good in def["in"]:
		inputs += def["in"][good] * node.price(good)
	var labor_cost: float = def["labor"] * Labor.WAGE[Labor.Type.HIRED]
	return revenue - inputs - labor_cost


func _enterprise_for_recipe_at_node(agent, recipe: String, node: TradeNode):
	for e in agent.enterprises:
		if e.recipe == recipe and e.node == node:
			return e
	return null


func _has_active_construction(agent, economy) -> bool:
	for c in economy.construction_queue:
		if c.owner_id == agent.id:
			return true
	return false


func _route_ticks(origin: TradeNode, destination: TradeNode) -> int:
	if origin == destination:
		return 0
	if (
		(origin.name == "Невьянск" and destination.name == "Москва")
		or (origin.name == "Москва" and destination.name == "Невьянск")
	):
		return 3
	return 2
