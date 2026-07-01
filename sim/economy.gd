# economy.gd — состояние симуляции и тик экономики (порядок фаз строго фиксирован)
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const Recipes := preload("res://sim/recipes.gd")
const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")


class Player:
	var money := 500.0
	var enterprises: Array[Enterprise] = []


var nodes: Array[TradeNode] = []
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
			wage_cost += e.workers[l] * Labor.WAGE[l]
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
