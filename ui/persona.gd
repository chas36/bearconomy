# persona.gd — детерминированные лица и имена для UI (без RNG!)
# Выбор — стабильный хеш от данных: сейв и реплей всегда видят то же
# лицо; в сейв и в /sim ничего не пишется, UI вычисляет на лету.
extends RefCounted

# Число вариантов портретов на роль — по составу docs/asset-brief.md
const ROLE_PORTRAIT_COUNTS := {
	"podyachy": 2,
	"kupets": 3,
	"prikazchik": 2,
	"master": 2,
	"starosta": 2,
	"officer": 1,
}
const ROLE_TITLES := {
	"podyachy": "Подьячий",
	"kupets": "Купец",
	"prikazchik": "Приказчик",
	"master": "Мастер",
	"starosta": "Староста",
	"officer": "Офицер",
}
const FIRST_NAMES := [
	"Аким",
	"Прохор",
	"Савва",
	"Фрол",
	"Гаврила",
	"Лукьян",
	"Никифор",
	"Осип",
	"Тихон",
	"Ерофей",
]
const LAST_NAMES := [
	"Оглоблин",
	"Шапошников",
	"Вяткин",
	"Коробов",
	"Сычёв",
	"Лодыгин",
	"Пятов",
	"Хомяков",
	"Бутурлин",
	"Скорняков",
]


# Лицо, выдавшее контракт: казённый (есть бонус казны) — подьячий,
# частный — купец. Контракт не хранит персону — она выводится из id.
static func for_contract(contract: Dictionary) -> Dictionary:
	var role := "podyachy" if contract.get("relations_bonus", 0.0) > 0.0 else "kupets"
	return _persona(role, hash("contract_%d" % int(contract.get("id", 0))))


static func for_event(event_id: String, speaker_role: String) -> Dictionary:
	var role: String = speaker_role if ROLE_PORTRAIT_COUNTS.has(speaker_role) else "prikazchik"
	return _persona(role, hash("event_%s" % event_id))


static func _persona(role: String, seed_hash: int) -> Dictionary:
	var count: int = ROLE_PORTRAIT_COUNTS.get(role, 1)
	var variant := absi(seed_hash) % count + 1
	var full_name := (
		"%s %s"
		% [
			FIRST_NAMES[absi(seed_hash / 7) % FIRST_NAMES.size()],
			LAST_NAMES[absi(seed_hash / 13) % LAST_NAMES.size()],
		]
	)
	return {
		"role": role,
		"title": ROLE_TITLES.get(role, ""),
		"name": full_name,
		"portrait": "portraits/%s_%d.png" % [role, variant],
	}
