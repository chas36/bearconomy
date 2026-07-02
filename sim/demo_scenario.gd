# demo_scenario.gd — общий стартовый сценарий для headless-прогона и UI
extends RefCounted

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")

const GRAIN_TOPUP := 28.0
const GRAIN_ROUTE_TICKS := 2
const IRON_ROUTE_TICKS := 3


static func setup(economy) -> Dictionary:
	var nevyansk := TradeNode.new("Невьянск")  # уральский завод
	var makarievo := TradeNode.new("Макарьево")  # ярмарка
	var moskva := TradeNode.new("Москва")  # столица-потребитель

	nevyansk.stock[Goods.Good.ZERNO] = 30.0
	nevyansk.target_stock[Goods.Good.ZERNO] = 15.0
	nevyansk.target_stock[Goods.Good.CHUGUN] = 3.0
	nevyansk.target_stock[Goods.Good.ZHELEZO] = 5.0
	nevyansk.labor_pool = {Labor.Type.HIRED: 2, Labor.Type.ASCRIBED: 0, Labor.Type.POSSESSIONAL: 8}

	makarievo.stock[Goods.Good.ZERNO] = 340.0  # v0-заглушка: житница без своего производства
	makarievo.target_stock[Goods.Good.ZERNO] = 100.0
	makarievo.target_stock[Goods.Good.MUKA] = 8.0
	makarievo.labor_pool = {
		Labor.Type.HIRED: 30, Labor.Type.ASCRIBED: 0, Labor.Type.POSSESSIONAL: 0
	}

	moskva.consumption[Goods.Good.ZHELEZO] = 1.2
	moskva.consumption[Goods.Good.ZERNO] = 5.0
	moskva.consumption[Goods.Good.MUKA] = 1.5
	moskva.consumption[Goods.Good.VODKA] = 0.8
	moskva.stock[Goods.Good.ZERNO] = 100.0
	moskva.stock[Goods.Good.MUKA] = 8.0
	moskva.stock[Goods.Good.VODKA] = 4.0
	moskva.target_stock[Goods.Good.ZERNO] = 40.0
	moskva.target_stock[Goods.Good.ZHELEZO] = 8.0
	moskva.target_stock[Goods.Good.MUKA] = 12.0
	moskva.target_stock[Goods.Good.VODKA] = 6.0
	moskva.labor_pool = {Labor.Type.HIRED: 60, Labor.Type.ASCRIBED: 0, Labor.Type.POSSESSIONAL: 0}

	var nodes: Array[TradeNode] = [nevyansk, makarievo, moskva]
	economy.nodes = nodes
	var player = economy.add_agent("player", "Демидов", true)
	player.enterprises.clear()

	for cfg in [["Рудник", "rudnik", 3.0], ["Домна", "domna", 2.0], ["Кузница", "kuznitsa", 2.0]]:
		var e := Enterprise.new(cfg[0], nevyansk, cfg[1], cfg[2])
		player.enterprises.append(e)

	for e in player.enterprises:
		var need := int(ceil(e.labor_needed()))
		var take: int = min(need, e.node.labor_pool[Labor.Type.POSSESSIONAL])
		e.workers[Labor.Type.POSSESSIONAL] += take
		e.node.labor_pool[Labor.Type.POSSESSIONAL] -= take

	var domna: Enterprise = player.enterprises[1]
	var kuznitsa: Enterprise = player.enterprises[2]
	economy.request_ascribed_workers(player, domna, 4)
	economy.set_hired_wage_offer(kuznitsa, 1.8)

	return {
		"nevyansk": nevyansk,
		"makarievo": makarievo,
		"moskva": moskva,
		"domna": domna,
		"kuznitsa": kuznitsa,
	}


static func run_logistics(
	economy, nevyansk: TradeNode, makarievo: TradeNode, moskva: TradeNode
) -> void:
	var grain_in_transit: float = economy.cargo_in_transit_to(nevyansk, Goods.Good.ZERNO)
	var grain_gap: float = GRAIN_TOPUP - nevyansk.stock[Goods.Good.ZERNO] - grain_in_transit
	if grain_gap > 0.5:
		economy.buy_and_dispatch(
			economy.player, makarievo, nevyansk, Goods.Good.ZERNO, grain_gap, GRAIN_ROUTE_TICKS
		)

	if economy.tick_count % 4 == 0:
		var qty: float = nevyansk.stock[Goods.Good.ZHELEZO]
		if qty > 0.5:
			economy.dispatch(
				economy.player, nevyansk, moskva, Goods.Good.ZHELEZO, qty, IRON_ROUTE_TICKS, true
			)
