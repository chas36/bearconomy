# enterprise.gd — предприятия
extends RefCounted

const Labor := preload("res://sim/labor.gd")
const Recipes := preload("res://sim/recipes.gd")
const TradeNode := preload("res://sim/trade_node.gd")

var name: String
var node: TradeNode
var recipe: String
var capacity: float  # ед. мощности
var hired_wage_offer: float
var workers := {}  # Labor.Type -> int (нанято/приписано)


func _init(n: String, nd: TradeNode, r: String, cap: float) -> void:
	name = n
	node = nd
	recipe = r
	capacity = cap
	hired_wage_offer = Labor.WAGE[Labor.Type.HIRED]
	for l in Labor.Type.values():
		workers[l] = 0


func labor_needed() -> float:
	return Recipes.DEFS[recipe]["labor"] * capacity


func worker_count() -> int:
	var total := 0
	for l in workers:
		total += workers[l]
	return total


func open_worker_slots() -> int:
	return max(0, int(ceil(labor_needed())) - worker_count())


# Сколько мощности реально закрыто трудом (с учётом эффективности)
func effective_capacity() -> float:
	var eff := 0.0
	for l in workers:
		eff += workers[l] * Labor.EFF[l]
	return min(capacity, eff / Recipes.DEFS[recipe]["labor"])
