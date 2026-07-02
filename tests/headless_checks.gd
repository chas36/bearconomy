# headless_checks.gd — быстрые регрессионные проверки ядра без GUT
extends SceneTree

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const Gameplay := preload("res://sim/gameplay.gd")
const TradeNode := preload("res://sim/trade_node.gd")

var failed := false


func _init() -> void:
	_check_prices_inside_clamps()
	_check_m3_chain_prices_inside_clamps()
	_check_save_load_determinism()
	_check_v1_save_migration()
	_check_construction_roundtrip()
	_check_contract_rng_determinism()
	_check_contract_completion()
	_check_contract_roundtrip()
	_check_contract_failure_penalty()

	if failed:
		quit(1)
	else:
		print("headless_checks: OK")
		quit()


func _check_prices_inside_clamps() -> void:
	var game := Gameplay.new()
	game.setup()
	_advance_with_default_choices(game, 16)

	_expect_prices_inside_clamps(game, "baseline")


func _check_m3_chain_prices_inside_clamps() -> void:
	var game := Gameplay.new()
	game.setup()
	var player = game.economy.player
	var makarievo: TradeNode = game.scenario["makarievo"]
	var moskva: TradeNode = game.scenario["moskva"]

	for _i in range(30):
		game.advance_tick()
		if game.economy.tick_count == 1:
			_expect(
				game.economy.start_construction(player, makarievo, "melnitsa", 2.0, 0),
				"M3 mill construction did not start"
			)
		if game.economy.tick_count == 6:
			_expect(
				game.economy.start_construction(player, makarievo, "vinokurnya", 1.0, 0),
				"M3 distillery construction did not start"
			)
		if game.economy.tick_count % 2 == 0:
			_dispatch_surplus(game, makarievo, moskva, Goods.Good.MUKA, 8.0, 2.0)
			_dispatch_surplus(game, makarievo, moskva, Goods.Good.VODKA, 2.0, 2.0)
		if game.has_pending_event():
			game.choose_event(0)

	_expect_prices_inside_clamps(game, "M3")
	_expect(
		makarievo.stock[Goods.Good.ZERNO] > 5.0,
		"M3 grain in Makarievo exhausted: %.1f" % makarievo.stock[Goods.Good.ZERNO]
	)


func _expect_prices_inside_clamps(game: Gameplay, label: String) -> void:
	for n in game.economy.nodes:
		for g in Goods.Good.values():
			var price: float = n.price(g)
			var low: float = Goods.BASE_PRICE[g] * 0.25
			var high: float = Goods.BASE_PRICE[g] * 4.0
			_expect(
				price > low and price < high,
				(
					"%s price clamp: %s/%s = %.3f outside (%.3f, %.3f)"
					% [label, n.name, Goods.NAMES[g], price, low, high]
				)
			)


func _dispatch_surplus(
	game: Gameplay,
	origin: TradeNode,
	destination: TradeNode,
	good: int,
	reserve: float,
	max_qty: float
) -> void:
	var qty: float = min(max_qty, max(0.0, origin.stock[good] - reserve))
	if qty <= 0.05:
		return
	game.economy.dispatch(game.economy.player, origin, destination, good, qty, 2, true)


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

	_expect(game.to_save_data()["version"] == 4, "legacy save did not migrate to current save")
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


func _check_construction_roundtrip() -> void:
	var game := Gameplay.new()
	game.setup()
	var player = game.economy.player
	var nevyansk = game.scenario["nevyansk"]
	var kuznitsa = game.scenario["kuznitsa"]
	var money_before: float = player.money

	var build_ok: bool = game.economy.start_construction(player, nevyansk, "rudnik", 1.0, 2)
	var expand_ok: bool = game.economy.expand_enterprise(player, kuznitsa, 1.0)
	_expect(build_ok, "construction did not start")
	_expect(expand_ok, "expansion did not start")
	_expect(
		is_equal_approx(player.money, money_before - 110.0 - 72.0), "construction cost mismatch"
	)

	_advance_with_default_choices(game, 2)
	var loaded := Gameplay.new()
	loaded.load_save_data(game.to_save_data())
	_expect(loaded.economy.construction_queue.size() == 2, "construction queue lost on save/load")
	_expect(
		(
			loaded.economy.construction_queue[0].remaining_ticks
			== game.economy.construction_queue[0].remaining_ticks
		),
		"construction remaining ticks mismatch after load"
	)

	_advance_with_default_choices(loaded, 3)
	var loaded_kuznitsa = loaded.scenario["kuznitsa"]
	_expect(is_equal_approx(loaded_kuznitsa.capacity, 3.0), "expansion did not increase capacity")
	_expect(loaded.economy.construction_queue.is_empty(), "construction queue should be empty")
	_expect(loaded.economy.player.enterprises.size() == 4, "new enterprise not added")

	var new_rudnik = loaded.economy.player.enterprises[3]
	_expect(
		new_rudnik.workers[Labor.Type.POSSESSIONAL] == 2,
		"possessional workers not assigned to new enterprise"
	)
	var loaded_nevyansk: TradeNode = loaded.scenario["nevyansk"]
	var ruda_before_production: float = loaded_nevyansk.stock[Goods.Good.RUDA]
	_advance_with_default_choices(loaded, 1)
	_expect(
		loaded_nevyansk.stock[Goods.Good.RUDA] > ruda_before_production,
		"completed construction did not produce"
	)


func _check_contract_rng_determinism() -> void:
	var first := Gameplay.new()
	first.setup()
	var second := Gameplay.new()
	second.setup()
	_advance_with_default_choices(first, 16)
	_advance_with_default_choices(second, 16)

	var first_contracts := JSON.stringify(first.board.to_save_data())
	var second_contracts := JSON.stringify(second.board.to_save_data())
	_expect(first_contracts == second_contracts, "same contract seed produced different offers")

	var different := Gameplay.new()
	different.setup()
	different.board.setup(999)
	_advance_with_default_choices(different, 16)
	var different_contracts := JSON.stringify(different.board.to_save_data())
	_expect(first_contracts != different_contracts, "different contract seed produced same offers")


func _check_contract_completion() -> void:
	var game := Gameplay.new()
	game.setup()
	var moskva: TradeNode = game.scenario["moskva"]
	var contract := _contract_fixture(game, Goods.Good.ZHELEZO, 2.0, moskva, 5, 120.0, 60.0)
	game.board.open_offers.append(contract)

	_expect(game.accept_contract(contract["id"]), "fixture contract was not accepted")
	game.economy.sell(game.economy.player, moskva, Goods.Good.ZHELEZO, 2.0)
	game.board.refresh(game.economy)
	_expect(
		game.board.completed_count.get(game.economy.player.id, 0) >= 1,
		"completed contract was not counted"
	)
	_expect(game.player_contracts().is_empty(), "completed contract remained active")


func _check_contract_roundtrip() -> void:
	var continuous := Gameplay.new()
	continuous.setup()
	_advance_with_default_choices(continuous, 4)
	_expect(not continuous.open_contracts().is_empty(), "contract generator did not create offer")
	continuous.accept_contract(continuous.open_contracts()[0]["id"])

	var loaded := Gameplay.new()
	loaded.load_save_data(continuous.to_save_data())

	_advance_with_default_choices(continuous, 8)
	_advance_with_default_choices(loaded, 8)

	var continuous_contracts := JSON.stringify(continuous.board.to_save_data())
	var loaded_contracts := JSON.stringify(loaded.board.to_save_data())
	_expect(continuous_contracts == loaded_contracts, "contract board diverged after save/load")


func _check_contract_failure_penalty() -> void:
	var game := Gameplay.new()
	game.setup()
	var moskva: TradeNode = game.scenario["moskva"]
	var contract := _contract_fixture(game, Goods.Good.MUKA, 10.0, moskva, 0, 100.0, 80.0)
	game.board.open_offers.append(contract)
	var money_before: float = game.economy.player.money

	_expect(game.accept_contract(contract["id"]), "expiring fixture contract was not accepted")
	game.board.refresh(game.economy)
	_expect(game.player_contracts().is_empty(), "expired contract remained active")
	_expect(
		is_equal_approx(game.economy.player.money, max(0.0, money_before - 80.0)),
		"expired contract penalty mismatch"
	)


func _contract_fixture(
	game: Gameplay,
	good: int,
	qty: float,
	destination: TradeNode,
	deadline_tick: int,
	reward: float,
	penalty: float
) -> Dictionary:
	var contract_id: int = game.board.next_contract_id
	game.board.next_contract_id += 1
	return {
		"id": contract_id,
		"good": good,
		"qty": qty,
		"destination_index": game.economy.nodes.find(destination),
		"deadline_tick": deadline_tick,
		"reward": reward,
		"penalty": penalty,
		"relations_bonus": 6.0,
		"relations_penalty": 8.0,
		"taken_by": "",
		"baseline_sold": 0.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
