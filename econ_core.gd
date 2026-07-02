# econ_core.gd — headless-точка входа: демо-сценарий поверх ядра из /sim
# Запуск без редактора: godot --headless --script econ_core.gd
# Цепочки: руда -> чугун -> железо; зерно -> мука -> водка.
# Три типа труда. Локальные цены по узлам.

extends SceneTree

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const Enterprise := preload("res://sim/enterprise.gd")
const Gameplay := preload("res://sim/gameplay.gd")

var gameplay := Gameplay.new()
var economy
var scenario := {}


func setup() -> void:
	gameplay.setup()
	economy = gameplay.economy
	scenario = gameplay.scenario


func dispatch_surplus_to_moscow(good: int, reserve: float, max_qty: float) -> void:
	var makarievo = scenario["makarievo"]
	var moskva = scenario["moskva"]
	var qty: float = min(max_qty, max(0.0, makarievo.stock[good] - reserve))
	if qty <= 0.05:
		return
	economy.dispatch(economy.player, makarievo, moskva, good, qty, 2, true)


func report() -> void:
	print(
		(
			"\n===== ТИК %d | Казна игрока: %.1f | Связи с казной: %.1f ====="
			% [economy.tick_count, economy.player.money, economy.player.state_relations]
		)
	)
	print("  Контракт: %s" % gameplay.contract_status_text())
	for n in economy.nodes:
		var s := "  %s:" % n.name
		for g in Goods.Good.values():
			if n.stock[g] > 0.05 or n.consumption[g] > 0.0:
				s += "  %s=%.1f (цена %.2f)" % [Goods.NAMES[g], n.stock[g], n.price(g)]
		s += "  | свободные наёмные=%d" % n.labor_pool[Labor.Type.HIRED]
		print(s)
	var labor_status := "  Штат:"
	for e in economy.player.enterprises:
		labor_status += " %s=%d/%d" % [e.name, e.worker_count(), int(ceil(e.labor_needed()))]
	print(labor_status)
	if not economy.caravans.is_empty():
		print("  Караваны в пути:")
		for c in economy.caravans:
			print(
				(
					"    %s -> %s: %.1f %s, осталось %d т."
					% [
						c.origin.name,
						c.destination.name,
						c.qty,
						Goods.NAMES[c.good],
						c.remaining_ticks
					]
				)
			)
	if not economy.construction_queue.is_empty():
		print("  Стройки:")
		for c in economy.construction_queue:
			if c.expand_target != null:
				print(
					(
						"    %s: +%.1f, осталось %d т."
						% [c.expand_target.name, c.capacity, c.remaining_ticks]
					)
				)
			else:
				print(
					(
						"    %s в %s: %.1f, осталось %d т."
						% [c.display_name, c.node.name, c.capacity, c.remaining_ticks]
					)
				)


func _init() -> void:
	setup()
	print(">>> Демидовский прототип: железо и новая цепочка зерно -> мука -> водка <<<")
	var kuznitsa: Enterprise = scenario["kuznitsa"]
	for i in range(30):
		gameplay.advance_tick()
		if economy.tick_count == 1:
			economy.start_construction(economy.player, scenario["makarievo"], "melnitsa", 2.0, 0)
		if economy.tick_count == 2:
			economy.start_construction(economy.player, scenario["nevyansk"], "rudnik", 1.0, 2)
		if economy.tick_count == 6:
			economy.start_construction(economy.player, scenario["makarievo"], "vinokurnya", 1.0, 0)
		if economy.tick_count % 2 == 0:
			dispatch_surplus_to_moscow(Goods.Good.MUKA, 8.0, 2.0)
			dispatch_surplus_to_moscow(Goods.Good.VODKA, 2.0, 2.0)
		if economy.tick_count == 10:
			economy.set_hired_wage_offer(kuznitsa, 1.2)
		if economy.tick_count == 12:
			economy.set_hired_wage_offer(kuznitsa, 1.8)
		if gameplay.has_pending_event():
			print("  [СОБЫТИЕ] %s — выбран первый вариант" % gameplay.pending_event_title())
			gameplay.choose_event(0)
		report()
	quit()
