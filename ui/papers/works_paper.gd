# works_paper.gd — бумага «Контора»: заводы дома, стройка и дворы узла
# Обёртка над works_panel + блок стройки и список дворов из city_panel.
extends VBoxContainer

signal action_performed(message: String)

const Labor := preload("res://sim/labor.gd")
const Recipes := preload("res://sim/recipes.gd")
const UiTheme := preload("res://ui/ui_theme.gd")
const GameText := preload("res://ui/game_text.gd")
const WorksPanel := preload("res://ui/works_panel.gd")

const BUILD_RECIPE_IDS := ["rudnik", "domna", "kuznitsa", "melnitsa", "vinokurnya"]

var gameplay
var node_index := 0

var _works_panel: WorksPanel
var _recipe_select: OptionButton
var _possessional_spin: SpinBox
var _build_preview: Label
var _enterprise_list: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 8)


func setup(gameplay_ref) -> void:
	gameplay = gameplay_ref
	_build()
	refresh()


func set_node_index(index: int) -> void:
	node_index = clampi(index, 0, gameplay.economy.nodes.size() - 1)
	refresh()


func refresh() -> void:
	_works_panel.refresh()
	_update_build_preview()
	_refresh_enterprise_list()


func _build() -> void:
	_works_panel = WorksPanel.new()
	_works_panel.setup(gameplay)
	_works_panel.action_performed.connect(
		func(message: String) -> void: action_performed.emit(message)
	)
	add_child(_works_panel)

	_build_construction_box()

	_add_subheader("Дворы и заводы узла")
	_enterprise_list = VBoxContainer.new()
	_enterprise_list.add_theme_constant_override("separation", 4)
	add_child(_enterprise_list)


func _build_construction_box() -> void:
	_add_subheader("Стройка")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_recipe_select = OptionButton.new()
	for recipe_id in BUILD_RECIPE_IDS:
		_recipe_select.add_item(Recipes.DEFS[recipe_id]["display_name"])
	_recipe_select.select(0)
	_recipe_select.item_selected.connect(func(_i: int) -> void: refresh())
	_recipe_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_recipe_select)

	_possessional_spin = SpinBox.new()
	_possessional_spin.min_value = 0
	_possessional_spin.max_value = Labor.POSSESSIONAL_MAX_PER_CAPACITY
	_possessional_spin.value = 2
	_possessional_spin.custom_minimum_size.x = 70
	_possessional_spin.tooltip_text = "Посессионные работники: покупаются вместе с заводом"
	_possessional_spin.value_changed.connect(func(_v: float) -> void: refresh())
	row.add_child(_possessional_spin)

	_build_preview = Label.new()
	_build_preview.theme_type_variation = "SmallDimLabel"
	add_child(_build_preview)

	var build_button := Button.new()
	build_button.text = "Заложить завод"
	build_button.theme_type_variation = "AccentButton"
	build_button.pressed.connect(_on_build)
	add_child(build_button)


func _add_subheader(text: String) -> void:
	var separator := HSeparator.new()
	add_child(separator)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "SubHeaderLabel"
	add_child(label)


func _refresh_enterprise_list() -> void:
	_clear_children(_enterprise_list)

	var node = _node()
	var found := false
	for agent in gameplay.economy.agents:
		for enterprise in agent.enterprises:
			if enterprise.node != node:
				continue
			found = true
			_enterprise_list.add_child(
				_enterprise_row(
					agent.is_player,
					(
						"%s — %s, мощность %.1f"
						% [enterprise.name, agent.display_name, enterprise.effective_capacity()]
					)
				)
			)
	for construction in gameplay.economy.construction_queue:
		if construction.node != node:
			continue
		found = true
		var owner = gameplay.economy.agent_by_id(construction.owner_id)
		var is_player: bool = owner != null and owner.is_player
		_enterprise_list.add_child(
			_enterprise_row(
				is_player,
				(
					"%s — стройка, ещё %s"
					% [construction.display_name, GameText.weeks(construction.remaining_ticks)]
				)
			)
		)
	if not found:
		var empty := Label.new()
		empty.text = "Пусто: ни дворов, ни строек."
		empty.theme_type_variation = "DimLabel"
		_enterprise_list.add_child(empty)


func _enterprise_row(is_player: bool, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var dot := TextureRect.new()
	dot.texture = UiTheme.owner_dot(is_player)
	dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(dot)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.visible = false
		child.queue_free()


func _update_build_preview() -> void:
	var recipe: Dictionary = Recipes.DEFS[_selected_recipe_id()]
	var cost: float = recipe["build_cost"] + _possessional_spin.value * Labor.POSSESSIONAL_PRICE
	_build_preview.text = (
		"Обойдётся в %s, срок %s" % [GameText.money(cost), GameText.weeks(recipe["build_ticks"])]
	)


func _node():
	return gameplay.economy.nodes[node_index]


func _selected_recipe_id() -> String:
	return BUILD_RECIPE_IDS[max(_recipe_select.selected, 0)]


func _on_build() -> void:
	var economy = gameplay.economy
	var ok: bool = economy.start_construction(
		economy.player, _node(), _selected_recipe_id(), 1.0, int(_possessional_spin.value)
	)
	if ok:
		action_performed.emit(
			"Заложен %s в %s." % [Recipes.DEFS[_selected_recipe_id()]["display_name"], _node().name]
		)
	else:
		action_performed.emit("Стройка не начата: не хватает денег.")
