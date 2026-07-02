# game_text.gd — перевод состояния симуляции в текст эпохи: даты, деньги, маршруты
extends RefCounted

const START_YEAR := 1701
const WEEKS_PER_MONTH := 4

const MONTHS := [
	"Январь",
	"Февраль",
	"Март",
	"Апрель",
	"Май",
	"Июнь",
	"Июль",
	"Август",
	"Сентябрь",
	"Октябрь",
	"Ноябрь",
	"Декабрь",
]

# v0-заглушка: дистанции узлов пока задаёт UI, в /sim расстояний нет
const LONG_ROUTES := [["Невьянск", "Москва"]]
const LONG_ROUTE_TICKS := 3
const SHORT_ROUTE_TICKS := 2


static func date_line(tick: int) -> String:
	var month_index := tick / WEEKS_PER_MONTH
	var year := START_YEAR + month_index / MONTHS.size()
	var month: String = MONTHS[month_index % MONTHS.size()]
	var week := tick % WEEKS_PER_MONTH + 1
	return "%s %d г. · %d-я неделя" % [month, year, week]


static func year_line(tick: int) -> String:
	var year := START_YEAR + tick / (WEEKS_PER_MONTH * MONTHS.size())
	return "лета %d-го" % year


static func weeks(ticks: int) -> String:
	return "%d нед." % ticks


static func money(amount: float) -> String:
	var whole := int(round(amount))
	var sign := "-" if whole < 0 else ""
	var digits := str(abs(whole))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = " " + grouped
	return "%s%s руб." % [sign, grouped]


static func route_ticks(from_name: String, to_name: String) -> int:
	for pair in LONG_ROUTES:
		if from_name in pair and to_name in pair:
			return LONG_ROUTE_TICKS
	return SHORT_ROUTE_TICKS
