# economy.gd — состояние симуляции и тик экономики (порядок фаз строго фиксирован)
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const Recipes := preload("res://sim/recipes.gd")
const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")
const Caravan := preload("res://sim/caravan.gd")


class Player:
	var money := 500.0
	var state_relations := 50.0
	var enterprises: Array[Enterprise] = []


var nodes: Array[TradeNode] = []
var caravans: Array[Caravan] = []
var player := Player.new()
var tick_count := 0


func tick() -> void:
	tick_count += 1

	# 1. ПРОИЗВОДСТВО
	for e in player.enterprises:
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
		if player.money < wage_cost or e.node.stock[Goods.Good.ZERNO] < grain_need:
			cap *= 0.5  # голод/безденежье: работаем вполсилы (v0-заглушка)
		player.money -= wage_cost
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


# Действие игрока: купить товар в узле; вернёт, сколько реально куплено
func buy(n: TradeNode, g: int, qty: float) -> float:
	var p := n.price(g)
	qty = min(qty, n.stock[g])
	if p > 0.0:
		qty = min(qty, player.money / p)
	n.stock[g] -= qty
	player.money -= p * qty
	if qty > 0.05:
		print(
			(
				"  [СДЕЛКА] Куплено %.1f %s в %s по %.2f (итого %.1f)"
				% [qty, Goods.NAMES[g], n.name, p, p * qty]
			)
		)
	return qty


# Действие игрока: купить товар и сразу отправить его караваном
func buy_and_dispatch(
	origin: TradeNode, destination: TradeNode, g: int, qty: float, travel_ticks: int
) -> float:
	var p := origin.price(g)
	qty = min(qty, origin.stock[g])
	if p > 0.0:
		qty = min(qty, player.money / p)
	if qty <= 0.05:
		return 0.0

	origin.stock[g] -= qty
	player.money -= p * qty
	var caravan := Caravan.new(origin, destination, g, qty, travel_ticks)
	caravans.append(caravan)
	print(
		(
			"  [КАРАВАН] Куплено и отправлено %.1f %s: %s -> %s, путь %d тика (итого %.1f)"
			% [qty, Goods.NAMES[g], origin.name, destination.name, caravan.total_ticks, p * qty]
		)
	)
	return qty


# Действие игрока: отправить товар из узла; при sell_on_arrival груз продаётся в пункте назначения
func dispatch(
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
	var caravan := Caravan.new(origin, destination, g, qty, travel_ticks, sell_on_arrival)
	caravans.append(caravan)
	print(
		(
			"  [КАРАВАН] Отправлено %.1f %s: %s -> %s, путь %d тика"
			% [qty, Goods.NAMES[g], origin.name, destination.name, caravan.total_ticks]
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


func request_ascribed_workers(e: Enterprise, qty: int) -> int:
	var open_slots := e.open_worker_slots()
	var max_by_relations := int(floor(player.state_relations / Labor.ASCRIBED_RELATION_COST))
	var granted: int = min(qty, open_slots, max_by_relations)
	if granted <= 0:
		return 0

	e.workers[Labor.Type.ASCRIBED] += granted
	player.state_relations -= granted * Labor.ASCRIBED_RELATION_COST
	print(
		(
			"  [КАЗНА] Приписано %d работников к %s (связи с казной %.1f)"
			% [granted, e.name, player.state_relations]
		)
	)
	return granted


# Действие игрока: продать товар в узле
func sell(n: TradeNode, g: int, qty: float) -> void:
	qty = min(qty, 999999.0)
	var p := n.price(g)
	n.stock[g] += qty
	player.money += p * qty
	print(
		(
			"  [СДЕЛКА] Продано %.1f %s в %s по %.2f (итого %.1f)"
			% [qty, Goods.NAMES[g], n.name, p, p * qty]
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
		var p := c.destination.price(c.good)
		player.money += p * c.qty
		print(
			(
				"  [КАРАВАН] Прибыло и продано %.1f %s в %s по %.2f (итого %.1f)"
				% [c.qty, Goods.NAMES[c.good], c.destination.name, p, p * c.qty]
			)
		)
	else:
		print(
			(
				"  [КАРАВАН] Прибыло %.1f %s: %s -> %s"
				% [c.qty, Goods.NAMES[c.good], c.origin.name, c.destination.name]
			)
		)


func _update_labor_market() -> void:
	for e in player.enterprises:
		_release_underpaid_hired(e)

	for n in nodes:
		_attract_hired_workers(n)

	for e in player.enterprises:
		_hire_available_hired(e)

	player.state_relations = min(100.0, player.state_relations + Labor.STATE_RELATION_RECOVERY)


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
	for e in player.enterprises:
		if e.node == n and e.open_worker_slots() > 0:
			best = max(best, e.hired_wage_offer)
	return best
