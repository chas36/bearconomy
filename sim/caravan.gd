# caravan.gd — груз в пути между торговыми узлами
extends RefCounted

const TradeNode := preload("res://sim/trade_node.gd")

var origin: TradeNode
var destination: TradeNode
var good: int
var qty: float
var remaining_ticks: int
var total_ticks: int
var sell_on_arrival: bool
var owner_id: String


func _init(
	origin_node: TradeNode,
	destination_node: TradeNode,
	cargo_good: int,
	cargo_qty: float,
	travel_ticks: int,
	should_sell_on_arrival := false,
	cargo_owner_id := "player"
) -> void:
	origin = origin_node
	destination = destination_node
	good = cargo_good
	qty = cargo_qty
	total_ticks = max(1, travel_ticks)
	remaining_ticks = total_ticks
	sell_on_arrival = should_sell_on_arrival
	owner_id = cargo_owner_id


func advance() -> bool:
	remaining_ticks -= 1
	return remaining_ticks <= 0
