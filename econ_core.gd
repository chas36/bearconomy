# econ_core.gd — headless-точка входа: демо-сценарий поверх ядра из /sim
# Запуск без редактора: godot --headless --script econ_core.gd
# Цепочка: руда -> чугун -> железо. Три типа труда. Локальные цены по узлам.

extends SceneTree

const Goods := preload("res://sim/goods.gd")
const Labor := preload("res://sim/labor.gd")
const TradeNode := preload("res://sim/trade_node.gd")
const Enterprise := preload("res://sim/enterprise.gd")
const Economy := preload("res://sim/economy.gd")

# Держим на заводе запас зерна ~2 тика содержания рабочих
const GRAIN_TOPUP := 14.0

var economy := Economy.new()


func setup() -> void:
	var nevyansk := TradeNode.new("Невьянск")  # уральский завод
	var makarievo := TradeNode.new("Макарьево")  # ярмарка
	var moskva := TradeNode.new("Москва")  # столица-потребитель

	# стартовые запасы и спрос
	nevyansk.stock[Goods.Good.ZERNO] = 30.0
	nevyansk.target_stock[Goods.Good.ZERNO] = 15.0  # ~2 тика содержания рабочих
	nevyansk.target_stock[Goods.Good.CHUGUN] = 3.0  # промежуточный товар не залёживается
	nevyansk.target_stock[Goods.Good.ZHELEZO] = 5.0  # копится только до отправки
	nevyansk.labor_pool = {
		Labor.Type.HIRED: 5, Labor.Type.ASCRIBED: 40, Labor.Type.POSSESSIONAL: 20
	}
	makarievo.stock[Goods.Good.ZERNO] = 150.0  # v0-заглушка: житница без своего производства
	makarievo.target_stock[Goods.Good.ZERNO] = 60.0
	makarievo.labor_pool = {
		Labor.Type.HIRED: 30, Labor.Type.ASCRIBED: 0, Labor.Type.POSSESSIONAL: 0
	}
	moskva.consumption[Goods.Good.ZHELEZO] = 1.2  # Москва ест железо -> тянет цену вверх
	moskva.consumption[Goods.Good.ZERNO] = 5.0
	moskva.stock[Goods.Good.ZERNO] = 100.0
	moskva.target_stock[Goods.Good.ZERNO] = 40.0
	moskva.target_stock[Goods.Good.ZHELEZO] = 8.0
	moskva.labor_pool = {Labor.Type.HIRED: 60, Labor.Type.ASCRIBED: 0, Labor.Type.POSSESSIONAL: 0}

	economy.nodes = [nevyansk, makarievo, moskva]

	# стартовое предприятие игрока: рудник + домна + кузница в Невьянске
	for cfg in [["Рудник", "rudnik", 3.0], ["Домна", "domna", 2.0], ["Кузница", "kuznitsa", 2.0]]:
		var e := Enterprise.new(cfg[0], nevyansk, cfg[1], cfg[2])
		economy.player.enterprises.append(e)

	# грубое распределение труда: сначала дешёвые крепостные, потом наёмные
	for e in economy.player.enterprises:
		var need := int(ceil(e.labor_needed()))
		for l in [Labor.Type.POSSESSIONAL, Labor.Type.ASCRIBED, Labor.Type.HIRED]:
			var take: int = min(need, e.node.labor_pool[l])
			e.workers[l] += take
			e.node.labor_pool[l] -= take
			need -= take
			if need <= 0:
				break


func report() -> void:
	print("\n===== ТИК %d | Казна игрока: %.1f =====" % [economy.tick_count, economy.player.money])
	for n in economy.nodes:
		var s := "  %s:" % n.name
		for g in Goods.Good.values():
			if n.stock[g] > 0.05 or n.consumption[g] > 0.0:
				s += "  %s=%.1f (цена %.2f)" % [Goods.NAMES[g], n.stock[g], n.price(g)]
		print(s)


func _init() -> void:
	setup()
	print(">>> Демидовский прототип: руда -> чугун -> железо, 3 типа труда <<<")
	var nevyansk: TradeNode = economy.nodes[0]
	var makarievo: TradeNode = economy.nodes[1]
	var moskva: TradeNode = economy.nodes[2]
	for i in range(16):
		economy.tick()
		# псевдо-логистика зерна: докупаем на ярмарке и «телепортируем» на завод
		var grain_gap: float = GRAIN_TOPUP - nevyansk.stock[Goods.Good.ZERNO]
		if grain_gap > 0.5:
			var bought: float = economy.buy(makarievo, Goods.Good.ZERNO, grain_gap)
			nevyansk.stock[Goods.Good.ZERNO] += bought
		# каждые 4 тика везём железо «в Москву» и продаём (телепорт вместо логистики — пока)
		if economy.tick_count % 4 == 0:
			var qty: float = nevyansk.stock[Goods.Good.ZHELEZO]
			if qty > 0.5:
				nevyansk.stock[Goods.Good.ZHELEZO] = 0.0
				economy.sell(moskva, Goods.Good.ZHELEZO, qty)
		report()
	quit()
