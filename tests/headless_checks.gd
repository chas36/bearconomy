# headless_checks.gd — быстрые регрессионные проверки ядра без GUT
extends SceneTree

const Goods := preload("res://sim/goods.gd")
const Gameplay := preload("res://sim/gameplay.gd")
const TradeNode := preload("res://sim/trade_node.gd")

var failed := false


func _init() -> void:
	_check_prices_inside_clamps()
	_check_save_load_determinism()
	_check_v1_save_migration()

	if failed:
		quit(1)
	else:
		print("headless_checks: OK")
		quit()


func _check_prices_inside_clamps() -> void:
	var game := Gameplay.new()
	game.setup()
	_advance_with_default_choices(game, 16)

	for n in game.economy.nodes:
		for g in Goods.Good.values():
			var price: float = n.price(g)
			var low: float = Goods.BASE_PRICE[g] * 0.25
			var high: float = Goods.BASE_PRICE[g] * 4.0
			_expect(
				price > low and price < high,
				(
					"price clamp: %s/%s = %.3f outside (%.3f, %.3f)"
					% [n.name, Goods.NAMES[g], price, low, high]
				)
			)


func _check_save_load_determinism() -> void:
	var continuous := Gameplay.new()
	continuous.setup()
	_advance_with_default_choices(continuous, 16)

	var loaded := Gameplay.new()
	loaded.load_save_data(continuous.to_save_data())

	_advance_with_default_choices(continuous, 8)
	_advance_with_default_choices(loaded, 8)

	var continuous_json := JSON.stringify(continuous.to_save_data())
	var loaded_json := JSON.stringify(loaded.to_save_data())
	_expect(continuous_json == loaded_json, "save/load roundtrip diverged after 8 ticks")


func _check_v1_save_migration() -> void:
	var legacy := _legacy_v1_save()
	var game := Gameplay.new()
	game.load_save_data(legacy)

	_expect(game.to_save_data()["version"] == 2, "legacy save did not migrate to v2")
	_expect(game.economy.agents.size() == 1, "legacy save should create one agent")
	_expect(game.economy.player.id == "player", "legacy player id mismatch")
	_expect(game.economy.player.enterprises.size() == 3, "legacy enterprises not assigned")

	var moskva: TradeNode = game.scenario["moskva"]
	_expect(
		is_equal_approx(
			game.economy.sold_amount(game.economy.player, moskva, Goods.Good.ZHELEZO), 3.0
		),
		"legacy sold_total not assigned to player"
	)


func _advance_with_default_choices(game: Gameplay, ticks: int) -> void:
	for _i in range(ticks):
		game.advance_tick()
		if game.has_pending_event():
			game.choose_event(0)


func _legacy_v1_save() -> Dictionary:
	var game := Gameplay.new()
	game.setup()
	game.economy.sell(game.economy.player, game.scenario["moskva"], Goods.Good.ZHELEZO, 3.0)

	var data := game.to_save_data()
	data["version"] = 1

	var economy_data: Dictionary = data["economy"]
	var agent_data: Dictionary = economy_data["agents"][0]
	economy_data["player"] = {
		"money": agent_data["money"],
		"state_relations": agent_data["state_relations"],
	}
	economy_data.erase("agents")

	for e_data in economy_data["enterprises"]:
		e_data.erase("owner")

	for c_data in economy_data["caravans"]:
		c_data.erase("owner")

	for s_data in economy_data["sold_total"]:
		s_data.erase("agent")

	return data


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
