# recipes.gd — производственные цепочки
extends RefCounted

const Goods := preload("res://sim/goods.gd")

# input -> output за 1 тик на 1 единицу мощности, labor = чел. на ед. мощности
const DEFS := {
	"rudnik":   { "in": {}, "out": { Goods.Good.RUDA: 3.0 }, "labor": 2.0 },
	"domna":    { "in": { Goods.Good.RUDA: 3.0 }, "out": { Goods.Good.CHUGUN: 1.5 }, "labor": 3.0 },
	"kuznitsa": { "in": { Goods.Good.CHUGUN: 1.5 }, "out": { Goods.Good.ZHELEZO: 1.0 }, "labor": 2.0 },
}
