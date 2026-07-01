# trade_node.gd — узел (город/ярмарка): склад, спрос, локальные цены
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")

var name: String
var stock := {}          # Good -> float
var target_stock := {}   # Good -> float (для формулы цены)
var consumption := {}    # Good -> float за тик (спрос населения)
var labor_pool := {}     # Labor.Type -> int (доступно в узле)


func _init(n: String) -> void:
	name = n
	for g in Goods.Good.values():
		stock[g] = 0.0
		target_stock[g] = 20.0
		consumption[g] = 0.0
	for l in Labor.Type.values():
		labor_pool[l] = 0


func price(g: int) -> float:
	var ratio: float = target_stock[g] / max(stock[g], 0.1)
	return Goods.BASE_PRICE[g] * clamp(ratio, 0.25, 4.0)
