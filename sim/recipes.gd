# recipes.gd — производственные цепочки
extends RefCounted

const Goods := preload("res://sim/goods.gd")

# input -> output за 1 тик на 1 единицу мощности, labor = чел. на ед. мощности
const DEFS := {
	"rudnik":
	{
		"in": {},
		"out": {Goods.Good.RUDA: 3.0},
		"labor": 2.0,
		"build_cost": 60.0,
		"build_ticks": 4,
		"display_name": "Рудник",
	},
	"domna":
	{
		"in": {Goods.Good.RUDA: 3.0},
		"out": {Goods.Good.CHUGUN: 1.5},
		"labor": 3.0,
		"build_cost": 120.0,
		"build_ticks": 6,
		"display_name": "Домна",
	},
	"kuznitsa":
	{
		"in": {Goods.Good.CHUGUN: 1.5},
		"out": {Goods.Good.ZHELEZO: 1.0},
		"labor": 2.0,
		"build_cost": 90.0,
		"build_ticks": 5,
		"display_name": "Кузница",
	},
	"melnitsa":
	{
		"in": {Goods.Good.ZERNO: 3.0},
		"out": {Goods.Good.MUKA: 2.0},
		"labor": 2.0,
		"build_cost": 70.0,
		"build_ticks": 4,
		"display_name": "Мельница",
	},
	"vinokurnya":
	{
		"in": {Goods.Good.MUKA: 2.0},
		"out": {Goods.Good.VODKA: 1.0},
		"labor": 3.0,
		"build_cost": 140.0,
		"build_ticks": 6,
		"display_name": "Винокурня",
	},
}
