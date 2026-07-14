# screenshot.gd — снимает кадры игры для визуальной проверки UI.
# Запуск: $GODOT --path . --script tests/screenshot.gd --resolution 1600x900
# Кадры пишутся в /tmp/bearconomy_shot_<имя>.png
extends SceneTree

const WARMUP_FRAMES := 12

var _shots: Array[Dictionary] = []
var _current := 0
var _frame := 0


func _init() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	_shots = [{"name": "map", "action": Callable()}]
	# v0-заглушка: клики по городу/зданиям добавляются в задачах ниже,
	# когда появятся соответствующие экраны.


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < WARMUP_FRAMES:
		return false
	if _current >= _shots.size():
		quit()
		return true
	var shot: Dictionary = _shots[_current]
	var action: Callable = shot["action"]
	if action.is_valid():
		action.call()
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("/tmp/bearconomy_shot_%s.png" % shot["name"])
	print("кадр: %s" % shot["name"])
	_current += 1
	_frame = 0
	return false
