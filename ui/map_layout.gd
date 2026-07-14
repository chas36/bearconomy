# map_layout.gd — раскладка карты и городских сцен (данные, не логика).
# Нормализованные координаты 0..1 от размера кадра. Перегенерировал
# картинку — поправь числа здесь, код не трогай.
extends RefCounted

# Узлы карты: позиция, латинский ключ файлов, тип, подпись.
# География сразу под этап v2: узлы без экономики просто не рисуются.
const NODES := {
	"Москва":
	{
		"pos": Vector2(0.18, 0.62),
		"key": "moskva",
		"kind": "capital",
		"subtitle": "столица",
	},
	"Тула":
	{
		"pos": Vector2(0.22, 0.80),
		"key": "tula",
		"kind": "works",
		"subtitle": "оружейное дело",
	},
	"Макарьево":
	{
		"pos": Vector2(0.46, 0.54),
		"key": "makarievo",
		"kind": "fair",
		"subtitle": "ярмарка",
	},
	"Невьянск":
	{
		"pos": Vector2(0.83, 0.28),
		"key": "nevyansk",
		"kind": "works",
		"subtitle": "заводы",
	},
	"Петербург":
	{
		"pos": Vector2(0.10, 0.16),
		"key": "petersburg",
		"kind": "capital",
		"subtitle": "новая столица",
	},
}

# Здания городских сцен: id открываемой бумаги (market / works /
# contracts / caravans), подпись, спрайт, прямоугольник (0..1 от кадра).
const CITY_BUILDINGS := {
	"Невьянск":
	[
		{
			"id": "works",
			"label": "Домна и завод",
			"sprite": "nevyansk_domna",
			"rect": Rect2(0.08, 0.35, 0.30, 0.55),
		},
		{
			"id": "market",
			"label": "Торговые ряды",
			"sprite": "nevyansk_ryady",
			"rect": Rect2(0.42, 0.50, 0.24, 0.40),
		},
		{
			"id": "caravans",
			"label": "Ямской двор",
			"sprite": "nevyansk_yam",
			"rect": Rect2(0.70, 0.55, 0.22, 0.35),
		},
	],
	"Макарьево":
	[
		{
			"id": "market",
			"label": "Ярмарочные ряды",
			"sprite": "makarievo_ryady",
			"rect": Rect2(0.30, 0.45, 0.40, 0.45),
		},
		{
			"id": "caravans",
			"label": "Ямской двор",
			"sprite": "makarievo_yam",
			"rect": Rect2(0.72, 0.55, 0.20, 0.35),
		},
		{
			"id": "works",
			"label": "Контора",
			"sprite": "makarievo_kontora",
			"rect": Rect2(0.08, 0.55, 0.18, 0.35),
		},
	],
	"Москва":
	[
		{
			"id": "market",
			"label": "Торговые ряды",
			"sprite": "moskva_ryady",
			"rect": Rect2(0.10, 0.50, 0.28, 0.40),
		},
		{
			"id": "contracts",
			"label": "Приказная изба",
			"sprite": "moskva_prikaz",
			"rect": Rect2(0.42, 0.45, 0.22, 0.45),
		},
		{
			"id": "works",
			"label": "Контора",
			"sprite": "moskva_kontora",
			"rect": Rect2(0.67, 0.55, 0.14, 0.35),
		},
		{
			"id": "caravans",
			"label": "Ямской двор",
			"sprite": "moskva_yam",
			"rect": Rect2(0.83, 0.58, 0.15, 0.32),
		},
	],
}

# Города без своей раскладки получают дефолтный набор без приказной избы
const DEFAULT_BUILDINGS := [
	{
		"id": "market",
		"label": "Торговые ряды",
		"sprite": "",
		"rect": Rect2(0.15, 0.50, 0.28, 0.40),
	},
	{
		"id": "works",
		"label": "Контора",
		"sprite": "",
		"rect": Rect2(0.50, 0.55, 0.20, 0.35),
	},
	{
		"id": "caravans",
		"label": "Ямской двор",
		"sprite": "",
		"rect": Rect2(0.75, 0.58, 0.18, 0.32),
	},
]


static func node_info(node_name: String) -> Dictionary:
	return NODES.get(node_name, {})


static func buildings(node_name: String) -> Array:
	return CITY_BUILDINGS.get(node_name, DEFAULT_BUILDINGS)
