# works_panel.gd — вкладка «Заводы»: предприятия игрока, труд, расширение
extends VBoxContainer

signal action_performed(message: String)

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const Recipes := preload("res://sim/recipes.gd")
const GameText := preload("res://ui/game_text.gd")

var gameplay
var enterprise_index := 0

var _enterprise_select: OptionButton
var _node_label: Label
var _chain_label: Label
var _capacity_label: Label
var _capacity_bar: ProgressBar
var _staff_label: Label
var _worker_labels := {}  # Labor.Type -> Label
var _wage_spin: SpinBox
var _ascribed_button: Button
var _expand_button: Button
var _construction_list: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 8)


func setup(gameplay_ref) -> void:
	gameplay = gameplay_ref
	_build()
	refresh()


func refresh() -> void:
	_sync_enterprise_select()
	var enterprise = _enterprise()
	if enterprise == null:
		return

	_node_label.text = "Стоит в узле %s" % enterprise.node.name
	_chain_label.text = _chain_text(enterprise)
	var effective: float = enterprise.effective_capacity()
	_capacity_label.text = "Мощность %.1f из %.1f" % [effective, enterprise.capacity]
	_capacity_bar.max_value = enterprise.capacity
	_capacity_bar.value = effective
	_staff_label.text = (
		"Штат %d из %d" % [enterprise.worker_count(), int(ceil(enterprise.labor_needed()))]
	)
	for labor_type in Labor.Type.values():
		_worker_labels[labor_type].text = str(enterprise.workers[labor_type])
	_wage_spin.set_value_no_signal(enterprise.hired_wage_offer)

	var relations: float = gameplay.economy.player.state_relations
	_ascribed_button.disabled = relations < Labor.ASCRIBED_RELATION_COST
	_ascribed_button.tooltip_text = (
		"Казна даст работника за %.0f связей (сейчас %.0f)"
		% [Labor.ASCRIBED_RELATION_COST, relations]
	)
	var expand_cost: float = Recipes.DEFS[enterprise.recipe]["build_cost"] * 0.8
	_expand_button.text = "Расширить +1 (%s)" % GameText.money(expand_cost)
	_expand_button.disabled = gameplay.economy.player.money < expand_cost

	_refresh_constructions()


func _build() -> void:
	_enterprise_select = OptionButton.new()
	_enterprise_select.item_selected.connect(_on_enterprise_selected)
	add_child(_enterprise_select)

	_node_label = Label.new()
	_node_label.theme_type_variation = "DimLabel"
	add_child(_node_label)

	_chain_label = Label.new()
	_chain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_chain_label)

	_capacity_label = Label.new()
	add_child(_capacity_label)

	_capacity_bar = ProgressBar.new()
	_capacity_bar.show_percentage = false
	_capacity_bar.custom_minimum_size.y = 10
	add_child(_capacity_bar)

	_staff_label = Label.new()
	add_child(_staff_label)

	_build_worker_grid()
	_build_actions()

	_add_subheader("Стройки дома")
	_construction_list = VBoxContainer.new()
	_construction_list.add_theme_constant_override("separation", 4)
	add_child(_construction_list)


func _build_worker_grid() -> void:
	_add_subheader("Люди")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	add_child(grid)

	var hints := {
		Labor.Type.HIRED: "за деньги, работают в полную силу, уходят при низкой ставке",
		Labor.Type.ASCRIBED: "от казны, кормятся зерном, работают вполсилы",
		Labor.Type.POSSESSIONAL: "куплены с заводом, неотчуждаемы",
	}
	for labor_type in Labor.Type.values():
		var caption := Label.new()
		caption.text = Labor.NAMES[labor_type]
		caption.tooltip_text = hints[labor_type]
		grid.add_child(caption)

		var count := Label.new()
		count.theme_type_variation = "ValueLabel"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.custom_minimum_size.x = 32
		grid.add_child(count)
		_worker_labels[labor_type] = count

		var efficiency := Label.new()
		efficiency.text = "усердие ×%.2f" % Labor.EFF[labor_type]
		efficiency.theme_type_variation = "SmallDimLabel"
		grid.add_child(efficiency)


func _build_actions() -> void:
	_add_subheader("Распоряжения")
	var wage_row := HBoxContainer.new()
	wage_row.add_theme_constant_override("separation", 6)
	add_child(wage_row)

	var wage_caption := Label.new()
	wage_caption.text = "Ставка наёмным"
	wage_caption.tooltip_text = (
		"Ниже %.1f — уходят; выше — приходят новые" % Labor.HIRED_RESERVATION_WAGE
	)
	wage_row.add_child(wage_caption)

	_wage_spin = SpinBox.new()
	_wage_spin.min_value = 0.5
	_wage_spin.max_value = 4.0
	_wage_spin.step = 0.1
	_wage_spin.custom_minimum_size.x = 90
	_wage_spin.value_changed.connect(_on_wage_changed)
	wage_row.add_child(_wage_spin)

	_ascribed_button = Button.new()
	_ascribed_button.text = "Просить приписных у казны"
	_ascribed_button.pressed.connect(_on_ascribed)
	add_child(_ascribed_button)

	_expand_button = Button.new()
	_expand_button.theme_type_variation = "AccentButton"
	_expand_button.pressed.connect(_on_expand)
	add_child(_expand_button)


func _add_subheader(text: String) -> void:
	var separator := HSeparator.new()
	add_child(separator)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "SubHeaderLabel"
	add_child(label)


func _refresh_constructions() -> void:
	_clear_children(_construction_list)

	var found := false
	for construction in gameplay.economy.construction_queue:
		if construction.owner_id != gameplay.economy.player.id:
			continue
		found = true
		var label := Label.new()
		label.text = (
			"%s в %s — ещё %s"
			% [
				construction.display_name,
				construction.node.name,
				GameText.weeks(construction.remaining_ticks),
			]
		)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_construction_list.add_child(label)
	if not found:
		var empty := Label.new()
		empty.text = "Артели простаивают: строек нет."
		empty.theme_type_variation = "DimLabel"
		_construction_list.add_child(empty)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.visible = false
		child.queue_free()


func _sync_enterprise_select() -> void:
	var enterprises: Array = gameplay.economy.player.enterprises
	enterprise_index = clampi(enterprise_index, 0, max(enterprises.size() - 1, 0))
	if _enterprise_select.item_count != enterprises.size():
		_enterprise_select.clear()
		for enterprise in enterprises:
			_enterprise_select.add_item(enterprise.name)
	if not enterprises.is_empty():
		_enterprise_select.select(enterprise_index)


func _chain_text(enterprise) -> String:
	var recipe: Dictionary = Recipes.DEFS[enterprise.recipe]
	var inputs: Array[String] = []
	for g in recipe["in"]:
		inputs.append("%.1f %s" % [recipe["in"][g], Goods.NAMES[g].to_lower()])
	var outputs: Array[String] = []
	for g in recipe["out"]:
		outputs.append("%.1f %s" % [recipe["out"][g], Goods.NAMES[g].to_lower()])
	if inputs.is_empty():
		return "Даёт %s в неделю на единицу мощности" % ", ".join(outputs)
	return "Из %s выходит %s в неделю" % [", ".join(inputs), ", ".join(outputs)]


func _enterprise():
	var enterprises: Array = gameplay.economy.player.enterprises
	if enterprises.is_empty():
		return null
	return enterprises[enterprise_index]


func _on_enterprise_selected(index: int) -> void:
	enterprise_index = index
	refresh()


func _on_wage_changed(value: float) -> void:
	var enterprise = _enterprise()
	if enterprise == null:
		return
	gameplay.economy.set_hired_wage_offer(enterprise, value)
	action_performed.emit("%s: ставка наёмным %.2f." % [enterprise.name, value])


func _on_ascribed() -> void:
	var enterprise = _enterprise()
	if enterprise == null:
		return
	var granted: int = gameplay.economy.request_ascribed_workers(
		gameplay.economy.player, enterprise, 1
	)
	if granted > 0:
		action_performed.emit("Казна приписала %d работника к %s." % [granted, enterprise.name])
	else:
		action_performed.emit("Казна отказала: мало связей или нет свободных мест.")


func _on_expand() -> void:
	var enterprise = _enterprise()
	if enterprise == null:
		return
	var ok: bool = gameplay.economy.expand_enterprise(gameplay.economy.player, enterprise, 1.0)
	if ok:
		action_performed.emit("%s: расширение начато." % enterprise.name)
	else:
		action_performed.emit("Расширение не начато: не хватает денег.")
