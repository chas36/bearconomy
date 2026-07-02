# construction.gd — стройка или расширение предприятия в очереди
extends RefCounted

const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")

var owner_id: String
var node: TradeNode
var recipe: String
var capacity: float
var remaining_ticks: int
var possessional_workers: int
var expand_target: Enterprise
var display_name: String


func _init(
	project_owner_id := "player",
	project_node: TradeNode = null,
	project_recipe := "",
	project_capacity := 1.0,
	project_ticks := 1,
	project_possessional_workers := 0,
	project_expand_target: Enterprise = null,
	project_display_name := ""
) -> void:
	owner_id = project_owner_id
	node = project_node
	recipe = project_recipe
	capacity = project_capacity
	remaining_ticks = max(1, project_ticks)
	possessional_workers = max(0, project_possessional_workers)
	expand_target = project_expand_target
	display_name = project_display_name


func advance() -> bool:
	remaining_ticks -= 1
	return remaining_ticks <= 0
