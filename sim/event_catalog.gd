# event_catalog.gd — data-first каталог событий и нарративного контекста
extends RefCounted

const Goods := preload("res://sim/goods.gd")

const STATE_INSPECTION := "state_inspection"
const WORKER_DEMAND := "worker_demand"
const FAIR_SHORTAGE := "fair_shortage"


static func all() -> Array[Dictionary]:
	return [_state_inspection(), _worker_demand(), _fair_shortage()]


static func find(event_id: String) -> Dictionary:
	for event_def in all():
		if event_def["id"] == event_id:
			return event_def
	return {}


static func _state_inspection() -> Dictionary:
	return {
		"id": STATE_INSPECTION,
		"title": "Казённый смотр",
		"body": "В Невьянск приехал приказчик. Дар сгладит вопросы к посессионным.",
		"trigger": {"tick": 5},
		"tags": ["state", "inspection", "labor"],
		"speaker_role": "podyachy",
		"participants": ["Казённый приказчик", "Заводская контора"],
		"location": "Невьянск",
		"stakes": "Связи с казной влияют на приписных работников и будущие разрешения.",
		"llm_context":
		{
			"scene_role": "state_pressure",
			"tone": "деловой нажим без карикатурного чиновничьего канцелярита",
			"npc_goal": "получить уступку и напомнить о зависимости завода от казны",
			"player_pressure": "игрок выбирает между деньгами сейчас и отношениями позже",
		},
		"choices":
		[
			{
				"text": "Дать 45 денег",
				"effect": {"money": -45.0, "state_relations": 8.0},
				"effect_summary": "Деньги -45, связи с казной +8",
				"result": "Приказчик уехал довольным. Связи с казной укрепились.",
				"llm_hint": "уступка сдержанная, без раболепия",
			},
			{
				"text": "Отказать",
				"effect": {"state_relations": -10.0},
				"effect_summary": "Связи с казной -10",
				"result": "Приказчик запомнил холодный приём.",
				"llm_hint": "конфликт тихий, но с долгим административным следом",
			},
		],
	}


static func _worker_demand() -> Dictionary:
	return {
		"id": WORKER_DEMAND,
		"title": "Слух о больших ставках",
		"body": "Наёмные на кузнице услышали, что в Верхотурье платят лучше.",
		"trigger": {"tick": 9},
		"tags": ["labor", "wage", "enterprise"],
		"speaker_role": "master",
		"participants": ["Наёмные кузнецы", "Приказчик кузницы"],
		"location": "Невьянск",
		"stakes": "Ставка наёмным определяет удержание людей и скорость выпуска железа.",
		"llm_context":
		{
			"scene_role": "worker_bargain",
			"tone": "бытовой спор у завода, короткие реплики, практичные аргументы",
			"npc_goal": "выбить ставку выше резервной зарплаты",
			"player_pressure": "экономия денег может обернуться оттоком рабочих",
		},
		"choices":
		[
			{
				"text": "Поднять ставку кузницы",
				"effect": {"kuznitsa_wage": 2.0},
				"effect_summary": "Ставка кузницы становится 2.0",
				"result": "Кузница подняла ставку. Люди охотнее держатся за место.",
				"llm_hint": "рабочие принимают решение без восторга, но с облегчением",
			},
			{
				"text": "Не уступать",
				"effect": {"kuznitsa_wage": 1.2},
				"effect_summary": "Ставка кузницы становится 1.2",
				"result": "Ставка снижена. Часть людей может уйти после следующего тика.",
				"llm_hint": "напряжение не взрывается сразу, но люди начинают оглядываться",
			},
		],
	}


static func _fair_shortage() -> Dictionary:
	return {
		"id": FAIR_SHORTAGE,
		"title": "Зерно на ярмарке дорожает",
		"body": "На Макарьевской ярмарке купцы придерживают зерно до большой воды.",
		"trigger": {"tick": 13},
		"conditions":
		{"node_stock_below": {"node": "Макарьево", "good": Goods.Good.ZERNO, "value": 160.0}},
		"tags": ["market", "grain", "logistics"],
		"speaker_role": "kupets",
		"participants": ["Макарьевские купцы", "Заводской закупщик"],
		"location": "Макарьево",
		"stakes": "Зерно кормит работников, а доставка на Урал занимает несколько тиков.",
		"llm_context":
		{
			"scene_role": "market_shortage",
			"tone": "торговый торг на ярмарке, без сказочной ярмарочной пестроты",
			"npc_goal": "поднять цену, пользуясь сезонной задержкой подвоза",
			"player_pressure": "закупить дорого сейчас или рискнуть будущим дефицитом",
		},
		"choices":
		[
			{
				"text": "Закупить сейчас",
				"effect": {"money": -8.0, "grain_to_nevyansk": 10.0},
				"effect_summary": "Деньги -8, 10 зерна отправляется в Невьянск",
				"result": "Зерно выкуплено и сразу отправлено на завод.",
				"llm_hint": "закупщик платит неохотно, но понимает цену простоя",
			},
			{
				"text": "Переждать",
				"effect": {"makarievo_grain_target": 90.0},
				"effect_summary": "Целевой запас зерна в Макарьево становится 90",
				"result": "Спрос на ярмарке вырос. Следующие закупки станут дороже.",
				"llm_hint": "купцы чувствуют слабину и придерживают товар увереннее",
			},
		],
	}
