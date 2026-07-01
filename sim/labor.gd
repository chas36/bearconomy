# labor.gd — типы труда: наёмные / приписные / посессионные
extends RefCounted

enum Type { HIRED, ASCRIBED, POSSESSIONAL }

const NAMES := {
	Type.HIRED: "Наёмные",
	Type.ASCRIBED: "Приписные",
	Type.POSSESSIONAL: "Посессионные",
}

# Зарплата за тик (наёмным — деньги; крепостным — содержание зерном, см. тик)
const WAGE := {Type.HIRED: 1.5, Type.ASCRIBED: 0.2, Type.POSSESSIONAL: 0.1}
# Эффективность (крепостной труд менее производителен — исторично и балансно)
const EFF := {Type.HIRED: 1.0, Type.ASCRIBED: 0.7, Type.POSSESSIONAL: 0.75}
# Содержание зерном за тик (крепостных кормит владелец)
const UPKEEP_GRAIN := {Type.HIRED: 0.0, Type.ASCRIBED: 0.3, Type.POSSESSIONAL: 0.4}
