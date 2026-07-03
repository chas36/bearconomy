# trade_node.gd — узел (город/ярмарка): склад, спрос, локальные цены
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")

# Доля пути от текущей цены к целевой за один тик
const PRICE_SMOOTHING := 0.2

# Клампы целевой цены относительно базовой (дефицит/избыток)
const TARGET_PRICE_CLAMP_MIN := 0.25
const TARGET_PRICE_CLAMP_MAX := 4.0

var name: String
var stock := {}  # Good -> float
var target_stock := {}  # Good -> float (для формулы цены)
var consumption := {}  # Good -> float за тик (спрос населения)
var labor_pool := {}  # Labor.Type -> int (доступно в узле)
var prices := {}  # Good -> float (текущая сглаженная цена)


func _init(n: String) -> void:
	name = n
	for g in Goods.Good.values():
		stock[g] = 0.0
		target_stock[g] = 20.0
		consumption[g] = 0.0
		prices[g] = Goods.BASE_PRICE[g]
	for l in Labor.Type.values():
		labor_pool[l] = 0


# Целевая цена: дефицит/избыток на складе относительно target_stock
func target_price(g: int) -> float:
	var ratio: float = target_stock[g] / max(stock[g], 0.1)
	return Goods.BASE_PRICE[g] * clamp(ratio, TARGET_PRICE_CLAMP_MIN, TARGET_PRICE_CLAMP_MAX)


# Текущая (сглаженная) цена — по ней идут все сделки
func price(g: int) -> float:
	return prices[g]


# Шаг сглаживания: цена движется к целевой на PRICE_SMOOTHING за тик
func smooth_prices() -> void:
	for g in prices:
		prices[g] = lerpf(prices[g], target_price(g), PRICE_SMOOTHING)
