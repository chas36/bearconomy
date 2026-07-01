# goods.gd — товары и базовые цены
extends RefCounted

enum Good { RUDA, CHUGUN, ZHELEZO, ZERNO }  # зерно = еда для рабочих

const NAMES := {
	Good.RUDA: "Руда", Good.CHUGUN: "Чугун",
	Good.ZHELEZO: "Железо", Good.ZERNO: "Зерно",
}

const BASE_PRICE := {
	Good.RUDA: 2.0, Good.CHUGUN: 6.0,
	Good.ZHELEZO: 14.0, Good.ZERNO: 1.0,
}
