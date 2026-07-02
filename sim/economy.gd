# economy.gd — состояние симуляции и тик экономики (порядок фаз строго фиксирован)
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const Recipes := preload("res://sim/recipes.gd")
const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")
const Caravan := preload("res://sim/caravan.gd")


class Agent:
	var id: String
	var display_name: String
	var is_player: bool
	var money := 500.0
	var state_relations := 50.0
	var enterprises: Array[Enterprise] = []

	func _init(agent_id := "player", agent_name := "Демидов", agent_is_player := true) -> void:
		id = agent_id
		display_name = agent_name
		is_player = agent_is_player


var nodes: Array[TradeNode] = []
var caravans: Array[Caravan] = []
var agents: Array[Agent] = []
var player := Agent.new()
var tick_count := 0
var sold_total := {}  # agent_id -> TradeNode -> Good -> float


func _init() -> void:
	agents.append(player)


func add_agent(id: String, display_name: String, is_player: bool) -> Agent:
	var existing := agent_by_id(id)
	if existing != null:
		existing.display_name = display_name
		existing.is_player = is_player
		if is_player:
			player = existing
			agents.erase(existing)
			agents.insert(0, existing)
		return existing

	var agent := Agent.new(id, display_name, is_player)
	if is_player:
		player = agent
		agents.insert(0, agent)
	else:
		agents.append(agent)
	return agent


func agent_by_id(id: String) -> Agent:
	for agent in agents:
		if agent.id == id:
			return agent
	return null


func all_enterprises() -> Array[Enterprise]:
	var result: Array[Enterprise] = []
	for agent in agents:
		for e in agent.enterprises:
			result.append(e)
	return result


func tick() -> void:
	tick_count += 1

	# 1. ПРОИЗВОДСТВО
	for agent in agents:
		for e in agent.enterprises:
			var r: Dictionary = Recipes.DEFS[e.recipe]
			var cap := e.effective_capacity()
			# ограничение по входам
			for g in r["in"]:
				var need: float = r["in"][g] * cap
				if e.node.stock[g] < need:
					cap *= e.node.stock[g] / max(need, 0.001)
			# зарплата и содержание
			var wage_cost := 0.0
			var grain_need := 0.0
			for l in e.workers:
				wage_cost += e.workers[l] * _wage_for(e, l)
				grain_need += e.workers[l] * Labor.UPKEEP_GRAIN[l]
			if agent.money < wage_cost or e.node.stock[Goods.Good.ZERNO] < grain_need:
				cap *= 0.5  # голод/безденежье: работаем вполсилы (v0-заглушка)
			agent.money -= wage_cost
			e.node.stock[Goods.Good.ZERNO] = max(0.0, e.node.stock[Goods.Good.ZERNO] - grain_need)
			# списываем входы, кладём выходы
			for g in r["in"]:
				e.node.stock[g] -= r["in"][g] * cap
			for g in r["out"]:
				e.node.stock[g] += r["out"][g] * cap

	# 2. ПОТРЕБЛЕНИЕ
	for n in nodes:
		for g in n.consumption:
			n.stock[g] = max(0.0, n.stock[g] - n.consumption[g])

	# 3. СГЛАЖИВАНИЕ ЦЕН: цена движется к целевой (см. TradeNode.PRICE_SMOOTHING)
	for n in nodes:
		n.smooth_prices()

	# 4. ЛОГИСТИКА: ранее отправленные караваны прибывают после движения цен
	_advance_caravans()

	# 5. РЫНОК ТРУДА: наёмные реагируют на ставку, казённые связи понемногу восстанавливаются
	_update_labor_market()


# Действие агента: купить товар в узле; вернёт, сколько реально куплено
func buy(agent: Agent, n: TradeNode, g: int, qty: float) -> float:
	var p := n.price(g)
	qty = min(qty, n.stock[g])
	if p > 0.0:
		qty = min(qty, agent.money / p)
	n.stock[g] -= qty
	agent.money -= p * qty
	if qty > 0.05:
		print(
			(
				"  [СДЕЛКА] %s: куплено %.1f %s в %s по %.2f (итого %.1f)"
				% [agent.display_name, qty, Goods.NAMES[g], n.name, p, p * qty]
			)
		)
	return qty


# Действие агента: купить товар и сразу отправить его караваном
func buy_and_dispatch(
	agent: Agent, origin: TradeNode, destination: TradeNode, g: int, qty: float, travel_ticks: int
) -> float:
	var p := origin.price(g)
	qty = min(qty, origin.stock[g])
	if p > 0.0:
		qty = min(qty, agent.money / p)
	if qty <= 0.05:
		return 0.0

	origin.stock[g] -= qty
	agent.money -= p * qty
	var caravan := Caravan.new(origin, destination, g, qty, travel_ticks, false, agent.id)
	caravans.append(caravan)
	print(
		(
			"  [КАРАВАН] %s: куплено и отправлено %.1f %s: %s -> %s, путь %d тика (итого %.1f)"
			% [
				agent.display_name,
				qty,
				Goods.NAMES[g],
				origin.name,
				destination.name,
				caravan.total_ticks,
				p * qty
			]
		)
	)
	return qty


# Действие агента: отправить товар из узла; при sell_on_arrival груз продаётся в пункте назначения
func dispatch(
	agent: Agent,
	origin: TradeNode,
	destination: TradeNode,
	g: int,
	qty: float,
	travel_ticks: int,
	sell_on_arrival := false
) -> float:
	qty = min(qty, origin.stock[g])
	if qty <= 0.05:
		return 0.0

	origin.stock[g] -= qty
	var caravan := Caravan.new(origin, destination, g, qty, travel_ticks, sell_on_arrival, agent.id)
	caravans.append(caravan)
	print(
		(
			"  [КАРАВАН] %s: отправлено %.1f %s: %s -> %s, путь %d тика"
			% [
				agent.display_name,
				qty,
				Goods.NAMES[g],
				origin.name,
				destination.name,
				caravan.total_ticks
			]
		)
	)
	return qty


func cargo_in_transit_to(destination: TradeNode, g: int) -> float:
	var total := 0.0
	for c in caravans:
		if c.destination == destination and c.good == g:
			total += c.qty
	return total


func set_hired_wage_offer(e: Enterprise, wage: float) -> void:
	e.hired_wage_offer = max(0.0, wage)
	print("  [ТРУД] %s: ставка наёмным %.2f за тик" % [e.name, e.hired_wage_offer])


func request_ascribed_workers(agent: Agent, e: Enterprise, qty: int) -> int:
	var open_slots := e.open_worker_slots()
	var max_by_relations := int(floor(agent.state_relations / Labor.ASCRIBED_RELATION_COST))
	var granted: int = min(qty, open_slots, max_by_relations)
	if granted <= 0:
		return 0

	e.workers[Labor.Type.ASCRIBED] += granted
	agent.state_relations -= granted * Labor.ASCRIBED_RELATION_COST
	print(
		(
			"  [КАЗНА] %s: приписано %d работников к %s (связи с казной %.1f)"
			% [agent.display_name, granted, e.name, agent.state_relations]
		)
	)
	return granted


# Действие агента: продать товар в узле
func sell(agent: Agent, n: TradeNode, g: int, qty: float) -> void:
	qty = min(qty, 999999.0)
	var p := n.price(g)
	n.stock[g] += qty
	agent.money += p * qty
	_record_sale(agent, n, g, qty)
	print(
		(
			"  [СДЕЛКА] %s: продано %.1f %s в %s по %.2f (итого %.1f)"
			% [agent.display_name, qty, Goods.NAMES[g], n.name, p, p * qty]
		)
	)


func _wage_for(e: Enterprise, labor_type: int) -> float:
	if labor_type == Labor.Type.HIRED:
		return e.hired_wage_offer
	return Labor.WAGE[labor_type]


func _advance_caravans() -> void:
	var active: Array[Caravan] = []
	for c in caravans:
		if c.advance():
			_arrive_caravan(c)
		else:
			active.append(c)
	caravans = active


func _arrive_caravan(c: Caravan) -> void:
	c.destination.stock[c.good] += c.qty
	if c.sell_on_arrival:
		var agent := agent_by_id(c.owner_id)
		if agent == null:
			agent = player
		var p := c.destination.price(c.good)
		agent.money += p * c.qty
		_record_sale(agent, c.destination, c.good, c.qty)
		print(
			(
				"  [КАРАВАН] %s: прибыло и продано %.1f %s в %s по %.2f (итого %.1f)"
				% [agent.display_name, c.qty, Goods.NAMES[c.good], c.destination.name, p, p * c.qty]
			)
		)
	else:
		var agent := agent_by_id(c.owner_id)
		var owner_name := agent.display_name if agent != null else c.owner_id
		print(
			(
				"  [КАРАВАН] %s: прибыло %.1f %s: %s -> %s"
				% [owner_name, c.qty, Goods.NAMES[c.good], c.origin.name, c.destination.name]
			)
		)


func _update_labor_market() -> void:
	for e in all_enterprises():
		_release_underpaid_hired(e)

	for n in nodes:
		_attract_hired_workers(n)

	for e in all_enterprises():
		_hire_available_hired(e)

	for agent in agents:
		agent.state_relations = min(100.0, agent.state_relations + Labor.STATE_RELATION_RECOVERY)


func _release_underpaid_hired(e: Enterprise) -> void:
	var hired: int = e.workers[Labor.Type.HIRED]
	if hired <= 0 or e.hired_wage_offer >= Labor.HIRED_RESERVATION_WAGE:
		return

	var leavers: int = min(hired, max(1, int(ceil(hired * Labor.HIRED_ATTRITION_RATE))))
	e.workers[Labor.Type.HIRED] -= leavers
	e.node.labor_pool[Labor.Type.HIRED] += leavers
	print(
		(
			"  [ТРУД] %d наёмных ушли с %s: ставка %.2f ниже ожиданий"
			% [leavers, e.name, e.hired_wage_offer]
		)
	)


func _attract_hired_workers(n: TradeNode) -> void:
	var best_offer := _best_open_hired_wage(n)
	if best_offer < Labor.HIRED_RESERVATION_WAGE + Labor.HIRED_MIGRATION_PREMIUM:
		return

	n.labor_pool[Labor.Type.HIRED] += Labor.HIRED_MIGRATION_PER_TICK
	print(
		(
			"  [ТРУД] В %s пришли %d наёмных: лучшая ставка %.2f"
			% [n.name, Labor.HIRED_MIGRATION_PER_TICK, best_offer]
		)
	)


func _hire_available_hired(e: Enterprise) -> void:
	if e.hired_wage_offer < Labor.HIRED_RESERVATION_WAGE:
		return

	var open_slots := e.open_worker_slots()
	var available: int = e.node.labor_pool[Labor.Type.HIRED]
	var hired: int = min(open_slots, available, Labor.HIRED_MAX_HIRE_PER_TICK)
	if hired <= 0:
		return

	e.workers[Labor.Type.HIRED] += hired
	e.node.labor_pool[Labor.Type.HIRED] -= hired
	print("  [ТРУД] %s нанял %d наёмных по %.2f" % [e.name, hired, e.hired_wage_offer])


func _best_open_hired_wage(n: TradeNode) -> float:
	var best := 0.0
	for e in all_enterprises():
		if e.node == n and e.open_worker_slots() > 0:
			best = max(best, e.hired_wage_offer)
	return best


func sold_amount(agent: Agent, n: TradeNode, g: int) -> float:
	if not sold_total.has(agent.id):
		return 0.0
	if not sold_total[agent.id].has(n):
		return 0.0
	return sold_total[agent.id][n].get(g, 0.0)


func _record_sale(agent: Agent, n: TradeNode, g: int, qty: float) -> void:
	if not sold_total.has(agent.id):
		sold_total[agent.id] = {}
	if not sold_total[agent.id].has(n):
		sold_total[agent.id][n] = {}
	sold_total[agent.id][n][g] = sold_total[agent.id][n].get(g, 0.0) + qty


func to_save_data() -> Dictionary:
	var agent_data: Array[Dictionary] = []
	for agent in agents:
		(
			agent_data
			. append(
				{
					"id": agent.id,
					"name": agent.display_name,
					"is_player": agent.is_player,
					"money": agent.money,
					"state_relations": agent.state_relations,
				}
			)
		)

	var node_data: Array[Dictionary] = []
	for n in nodes:
		(
			node_data
			. append(
				{
					"name": n.name,
					"stock": _number_dict_to_save(n.stock),
					"target_stock": _number_dict_to_save(n.target_stock),
					"consumption": _number_dict_to_save(n.consumption),
					"labor_pool": _number_dict_to_save(n.labor_pool),
					"prices": _number_dict_to_save(n.prices),
				}
			)
		)

	var enterprise_data: Array[Dictionary] = []
	for agent in agents:
		for e in agent.enterprises:
			(
				enterprise_data
				. append(
					{
						"owner": agent.id,
						"name": e.name,
						"node": nodes.find(e.node),
						"recipe": e.recipe,
						"capacity": e.capacity,
						"hired_wage_offer": e.hired_wage_offer,
						"workers": _number_dict_to_save(e.workers),
					}
				)
			)

	var caravan_data: Array[Dictionary] = []
	for c in caravans:
		(
			caravan_data
			. append(
				{
					"origin": nodes.find(c.origin),
					"destination": nodes.find(c.destination),
					"good": c.good,
					"qty": c.qty,
					"remaining_ticks": c.remaining_ticks,
					"total_ticks": c.total_ticks,
					"sell_on_arrival": c.sell_on_arrival,
					"owner": c.owner_id,
				}
			)
		)

	var sales_data: Array[Dictionary] = []
	for agent_id in sold_total:
		for n in sold_total[agent_id]:
			(
				sales_data
				. append(
					{
						"agent": agent_id,
						"node": nodes.find(n),
						"goods": _number_dict_to_save(sold_total[agent_id][n]),
					}
				)
			)

	return {
		"tick_count": tick_count,
		"agents": agent_data,
		"nodes": node_data,
		"enterprises": enterprise_data,
		"caravans": caravan_data,
		"sold_total": sales_data,
	}


func load_save_data(data: Dictionary) -> void:
	tick_count = data.get("tick_count", 0)
	agents.clear()
	for a_data in data.get("agents", []):
		var agent := add_agent(
			a_data.get("id", "player"),
			a_data.get("name", "Демидов"),
			a_data.get("is_player", false)
		)
		agent.money = a_data.get("money", 500.0)
		agent.state_relations = a_data.get("state_relations", 50.0)
		agent.enterprises.clear()

	if agents.is_empty():
		var fallback := add_agent("player", "Демидов", true)
		fallback.money = 500.0
		fallback.state_relations = 50.0
	elif player == null or not agents.has(player):
		player = agents[0]
		player.is_player = true

	nodes.clear()
	for n_data in data.get("nodes", []):
		var node := TradeNode.new(n_data.get("name", "Узел"))
		_load_number_dict(node.stock, n_data.get("stock", {}), Goods.Good.values())
		_load_number_dict(node.target_stock, n_data.get("target_stock", {}), Goods.Good.values())
		_load_number_dict(node.consumption, n_data.get("consumption", {}), Goods.Good.values())
		_load_number_dict(node.labor_pool, n_data.get("labor_pool", {}), Labor.Type.values())
		_load_number_dict(node.prices, n_data.get("prices", {}), Goods.Good.values())
		nodes.append(node)

	for e_data in data.get("enterprises", []):
		var node_index: int = e_data.get("node", 0)
		var owner := agent_by_id(e_data.get("owner", "player"))
		if owner == null:
			owner = player
		var e := Enterprise.new(
			e_data.get("name", "Предприятие"),
			nodes[node_index],
			e_data.get("recipe", "rudnik"),
			e_data.get("capacity", 1.0)
		)
		e.hired_wage_offer = e_data.get("hired_wage_offer", Labor.WAGE[Labor.Type.HIRED])
		_load_number_dict(e.workers, e_data.get("workers", {}), Labor.Type.values())
		owner.enterprises.append(e)

	caravans.clear()
	for c_data in data.get("caravans", []):
		var c := Caravan.new(
			nodes[c_data.get("origin", 0)],
			nodes[c_data.get("destination", 0)],
			c_data.get("good", Goods.Good.ZERNO),
			c_data.get("qty", 0.0),
			c_data.get("total_ticks", 1),
			c_data.get("sell_on_arrival", false),
			c_data.get("owner", "player")
		)
		c.remaining_ticks = c_data.get("remaining_ticks", c.total_ticks)
		caravans.append(c)

	sold_total.clear()
	for s_data in data.get("sold_total", []):
		var node: TradeNode = nodes[s_data.get("node", 0)]
		var agent_id: String = s_data.get("agent", "player")
		if not sold_total.has(agent_id):
			sold_total[agent_id] = {}
		sold_total[agent_id][node] = {}
		_load_number_dict(sold_total[agent_id][node], s_data.get("goods", {}), Goods.Good.values())


func _number_dict_to_save(source: Dictionary) -> Dictionary:
	var result := {}
	for k in source:
		result[str(k)] = source[k]
	return result


func _load_number_dict(target: Dictionary, source: Dictionary, keys: Array) -> void:
	for k in keys:
		var key := str(k)
		if source.has(key):
			target[k] = source[key]
