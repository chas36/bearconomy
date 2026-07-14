# screenshot.gd — снимает кадры игры для визуальной проверки UI.
# Запуск: $GODOT --path . --script tests/screenshot.gd --resolution 1600x900
# Кадры пишутся в /tmp/bearconomy_shot_<имя>.png
extends SceneTree

const WARMUP_FRAMES := 12

var _shots: Array[Dictionary] = []
var _current := 0
var _frame := 0
var _main: Node


func _init() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	_shots = [
		{"name": "map", "action": Callable()},
		{"name": "city", "action": _open_city.bind("Невьянск")},
		{"name": "city_moscow", "action": _open_city.bind("Москва")},
	]


func _process(_delta: float) -> bool:
	if _current >= _shots.size():
		quit()
		return true
	var shot: Dictionary = _shots[_current]
	if _frame == 0:
		var action: Callable = shot["action"]
		if action.is_valid():
			action.call()
	_frame += 1
	if _frame < WARMUP_FRAMES:
		return false
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("/tmp/bearconomy_shot_%s.png" % shot["name"])
	print("кадр: %s" % shot["name"])
	_current += 1
	_frame = 0
	return false


func _open_city(node_name: String) -> void:
	var economy = _main.gameplay.economy
	for i in range(economy.nodes.size()):
		if economy.nodes[i].name == node_name:
			_main._on_map_node_clicked(i)
			return
	push_warning("Узел не найден: %s" % node_name)
