# План реализации: редизайн UI под референсы

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task.

**Goal:** Перестроить UI в два экрана (карта на весь экран + интерактивный
городской экран) с AI-ассетами и обязательными фолбэками, портретами в
событиях и заказах — без изменения `/sim`.

**Architecture:** Дизайн утверждён в
`docs/plans/2026-07-14-ui-redesign-design.md` — читать перед началом.
Все PNG живут в `ui/assets/gen/`, загружаются через хелпер с фолбэком;
раскладка (координаты узлов и зданий) — data-файл `ui/map_layout.gd`.
Панели-«бумаги» переиспользуют существующий панельный код, обёрнутый в
пергаментную тему.

**Tech Stack:** Godot 4.x, GDScript со статической типизацией. Запуск:
`GODOT=/Applications/Godot.app/Contents/MacOS/Godot` (не в PATH).

**Правила процесса (для каждой задачи):**

- Перед коммитом: `pre-commit run --all-files`; если хук поправил файлы —
  `git add` и повторить коммит. `--no-verify` запрещён.
- Регрессии не ломать: `$GODOT --headless --script tests/headless_checks.gd`
  должен проходить после каждой задачи, затрагивающей код.
- Смоук: `$GODOT --headless --path . --quit-after 1` — сцена должна
  загружаться без ошибок скриптов.
- Строки для игрока — на русском, идентификаторы — на английском.

---

### Task 1: Скриншот-драйвер в репо

Инструмент проверки всех последующих задач.

**Files:**
- Create: `tests/screenshot.gd`

**Step 1: Создать скрипт**

```gdscript
# screenshot.gd — снимает кадры игры для визуальной проверки UI.
# Запуск: $GODOT --path . --script tests/screenshot.gd --resolution 1600x900
# Кадры пишутся в /tmp/bearconomy_shot_<имя>.png
extends SceneTree

const WARMUP_FRAMES := 12

var _shots: Array[Dictionary] = []
var _current := 0
var _frame := 0


func _init() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	_shots = [{"name": "map", "action": Callable()}]
	# v0-заглушка: клики по городу/зданиям добавляются в задачах ниже,
	# когда появятся соответствующие экраны.


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < WARMUP_FRAMES:
		return false
	if _current >= _shots.size():
		quit()
		return true
	var shot: Dictionary = _shots[_current]
	if shot["action"].is_valid():
		shot["action"].call()
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("/tmp/bearconomy_shot_%s.png" % shot["name"])
	print("кадр: %s" % shot["name"])
	_current += 1
	_frame = 0
	return false
```

**Step 2: Проверить**

Run: `$GODOT --path . --script tests/screenshot.gd --resolution 1600x900`
Expected: печать `кадр: map`, файл `/tmp/bearconomy_shot_map.png` существует
и показывает текущий экран игры. Открыть файл и посмотреть.

**Step 3: Commit**

```bash
git add tests/screenshot.gd
git commit -m "tests: скриншот-драйвер для визуальной проверки UI"
```

---

### Task 2: Спека ассетов с промптами

**Files:**
- Create: `docs/asset-brief.md`
- Create: `ui/assets/gen/.gitkeep` (плюс пустые подпапки)

**Step 1: Написать `docs/asset-brief.md`**

Документ для генерации в gpt-image (ChatGPT). Обязательная структура:

1. **Стилевой якорь** — абзац, с которого начинается КАЖДЫЙ промпт:
   гравюра/офорт начала XVIII века, русская парсуна, сдержанная палитра
   (пергамент #d9c69e, тушь #38291a, латунь #c9a44c), без текста на
   картинке, без современных деталей.
2. **Таблица файлов**: точное имя, размер в px, прозрачность, что на
   картинке. Имена файлов — строго из списка ниже (код будет их искать).
3. **Готовый промпт под каждым файлом** (описание сцены + требования
   к фону/композиции + стилевой якорь).

Полный список файлов (`ui/assets/gen/...`):

| Файл | Размер | Фон | Содержимое |
|---|---|---|---|
| `map/map_background.png` | 2048×1152 | — | Гравированная карта России Москва→Урал: Волга/Кама/Чусовая, Уральский хребет справа, леса значками, компас слева сверху, картуш снизу справа ПУСТОЙ (подпись рисует код). География под узлы: Москва юго-запад, Тула южнее Москвы, Макарьево центр (Волга), Петербург северо-запад, Невьянск северо-восток. |
| `map/marker_moskva.png` … `marker_tula.png`, `marker_makarievo.png`, `marker_nevyansk.png`, `marker_petersburg.png` | 160×160 | прозрачный | Круглый картуш-виньетка города: кремль/ярмарочные шатры/домна с дымом/верфь и шпиль. |
| `map/caravan.png` | 96×64 | прозрачный | Гружёная повозка с лошадью, вид сбоку, гравюра. |
| `cities/panorama_nevyansk.png` | 1920×1080 | — | Уральский завод у пруда: плотина, домна, избы, гора. Передний план внизу свободен под здания-спрайты. |
| `cities/panorama_makarievo.png` | 1920×1080 | — | Ярмарка у монастырских стен на Волге: ряды шатров, баржи. |
| `cities/panorama_moskva.png` | 1920×1080 | — | Москва: кремлёвская стена, купола, торговые ряды. |
| `buildings/nevyansk_domna.png`, `nevyansk_kontora.png`, `nevyansk_ryady.png`, `nevyansk_yam.png` | ~600×500 | прозрачный | Домна с дымом; заводская контора-изба; торговые ряды; ямской двор с воротами и телегой. |
| `buildings/makarievo_ryady.png`, `makarievo_kontora.png`, `makarievo_yam.png` | ~600×500 | прозрачный | Ярмарочные ряды-шатры; контора; ямской двор. |
| `buildings/moskva_ryady.png`, `moskva_prikaz.png`, `moskva_kontora.png`, `moskva_yam.png` | ~600×500 | прозрачный | Торговые ряды; каменная приказная изба с крыльцом; контора; ямской двор. |
| `goods/ruda.png`, `chugun.png`, `zhelezo.png`, `zerno.png`, `muka.png`, `vodka.png` | 128×128 | прозрачный | Гравюрные иконки: куски руды; чугунные чушки; железные полосы; сноп; мешок муки; штоф. |
| `portraits/podyachy_1.png`, `podyachy_2.png`, `kupets_1.png`, `kupets_2.png`, `kupets_3.png`, `prikazchik_1.png`, `prikazchik_2.png`, `master_1.png`, `master_2.png`, `starosta_1.png`, `starosta_2.png`, `officer_1.png` | 512×512 | тёмный нейтральный | Поясные портреты-парсуны: подьячий с бумагами; купцы; приказчики; мастер-литейщик; староста; офицер петровской армии. |
| `chrome/paper_frame.png` | 384×384 | прозрачный | Пергаментный лист с обтрёпанными краями, ЦЕНТР однородный (растягивается 9-patch: поля по 96 px). |
| `chrome/seal.png` | 128×128 | прозрачный | Сургучная печать с вензелем «Д». |

**Step 2: Создать папки**

```bash
mkdir -p ui/assets/gen/{map,cities,buildings,goods,portraits,chrome}
touch ui/assets/gen/{map,cities,buildings,goods,portraits,chrome}/.gitkeep
```

**Step 3: Commit**

```bash
git add docs/asset-brief.md ui/assets/gen
git commit -m "docs: спека AI-ассетов с промптами и структура ui/assets/gen"
```

---

### Task 3: Загрузчик ассетов с фолбэком

**Files:**
- Create: `ui/gen_assets.gd`

**Step 1: Написать хелпер**

```gdscript
# gen_assets.gd — доступ к AI-ассетам с обязательным фолбэком.
# Файла нет — возвращаем null, вызывающий код рисует процедурно.
extends RefCounted

const ROOT := "res://ui/assets/gen"

static var _cache := {}


static func texture(relative_path: String) -> Texture2D:
	if _cache.has(relative_path):
		return _cache[relative_path]
	var path := "%s/%s" % [ROOT, relative_path]
	var result: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		result = load(path)
	_cache[relative_path] = result
	return result


static func has(relative_path: String) -> bool:
	return texture(relative_path) != null
```

**Step 2: Проверить смоуком**

Run: `$GODOT --headless --path . --quit-after 1`
Expected: загрузка без ошибок (хелпер ещё не используется — проверка синтаксиса).

**Step 3: Commit**

```bash
git add ui/gen_assets.gd
git commit -m "ui: загрузчик gen-ассетов с фолбэком на процедурную отрисовку"
```

---

### Task 4: Data-файл раскладки

**Files:**
- Create: `ui/map_layout.gd`

**Step 1: Написать раскладку**

Ключи — имена узлов, как в `map_view.gd:16-27` сейчас. География — сразу
под v2 (Тула, Петербург); узлы без экономики просто не отрисуются
(маркеры рисуются только для `economy.nodes`).

```gdscript
# map_layout.gd — раскладка карты и городских сцен (данные, не логика).
# Нормализованные координаты 0..1 от размера кадра. Перегенерировал
# картинку — поправь числа здесь, код не трогай.
extends RefCounted

# Узлы карты: позиция, латинский ключ файлов, тип, подпись
const NODES := {
	"Москва": {"pos": Vector2(0.18, 0.62), "key": "moskva", "kind": "capital", "subtitle": "столица"},
	"Тула": {"pos": Vector2(0.22, 0.80), "key": "tula", "kind": "works", "subtitle": "оружейное дело"},
	"Макарьево": {"pos": Vector2(0.46, 0.54), "key": "makarievo", "kind": "fair", "subtitle": "ярмарка"},
	"Невьянск": {"pos": Vector2(0.83, 0.28), "key": "nevyansk", "kind": "works", "subtitle": "заводы"},
	"Петербург": {"pos": Vector2(0.10, 0.16), "key": "petersburg", "kind": "capital", "subtitle": "новая столица"},
}

# Здания городских сцен: id бумаги, подпись, прямоугольник (pos+size 0..1)
# building id -> какой документ открывает: market / works / contracts / caravans
const CITY_BUILDINGS := {
	"Невьянск":
	[
		{"id": "works", "label": "Домна и завод", "sprite": "nevyansk_domna", "rect": Rect2(0.08, 0.35, 0.30, 0.55)},
		{"id": "market", "label": "Торговые ряды", "sprite": "nevyansk_ryady", "rect": Rect2(0.42, 0.50, 0.24, 0.40)},
		{"id": "caravans", "label": "Ямской двор", "sprite": "nevyansk_yam", "rect": Rect2(0.70, 0.55, 0.22, 0.35)},
	],
	"Макарьево":
	[
		{"id": "market", "label": "Ярмарочные ряды", "sprite": "makarievo_ryady", "rect": Rect2(0.30, 0.45, 0.40, 0.45)},
		{"id": "caravans", "label": "Ямской двор", "sprite": "makarievo_yam", "rect": Rect2(0.72, 0.55, 0.20, 0.35)},
		{"id": "works", "label": "Контора", "sprite": "makarievo_kontora", "rect": Rect2(0.08, 0.55, 0.18, 0.35)},
	],
	"Москва":
	[
		{"id": "market", "label": "Торговые ряды", "sprite": "moskva_ryady", "rect": Rect2(0.10, 0.50, 0.28, 0.40)},
		{"id": "contracts", "label": "Приказная изба", "sprite": "moskva_prikaz", "rect": Rect2(0.42, 0.45, 0.22, 0.45)},
		{"id": "works", "label": "Контора", "sprite": "moskva_kontora", "rect": Rect2(0.67, 0.55, 0.14, 0.35)},
		{"id": "caravans", "label": "Ямской двор", "sprite": "moskva_yam", "rect": Rect2(0.83, 0.58, 0.15, 0.32)},
	],
}

# Города без своей раскладки получают дефолтный набор без приказной избы
const DEFAULT_BUILDINGS := [
	{"id": "market", "label": "Торговые ряды", "sprite": "", "rect": Rect2(0.15, 0.50, 0.28, 0.40)},
	{"id": "works", "label": "Контора", "sprite": "", "rect": Rect2(0.50, 0.55, 0.20, 0.35)},
	{"id": "caravans", "label": "Ямской двор", "sprite": "", "rect": Rect2(0.75, 0.58, 0.18, 0.32)},
]


static func node_info(node_name: String) -> Dictionary:
	return NODES.get(node_name, {})


static func buildings(node_name: String) -> Array:
	return CITY_BUILDINGS.get(node_name, DEFAULT_BUILDINGS)
```

**Step 2: Смоук + commit**

Run: `$GODOT --headless --path . --quit-after 1` — без ошибок.

```bash
git add ui/map_layout.gd
git commit -m "ui: data-файл раскладки карты и городских сцен"
```

---

### Task 5: Карта — фон, маркеры и обозы из ассетов

**Files:**
- Modify: `ui/map_view.gd`

**Step 1: Подключить раскладку и ассеты**

- Добавить преloads: `GenAssets := preload("res://ui/gen_assets.gd")`,
  `MapLayout := preload("res://ui/map_layout.gd")`.
- Удалить константы `NODE_POS`, `NODE_KIND`, `NODE_SUBTITLE`
  (`map_view.gd:16-27`); всюду читать из `MapLayout.node_info(node.name)`
  (`pos`, `kind`, `subtitle`); фолбэк-позиция `_fallback_pos()` остаётся.
- Letterbox: приватный метод `_map_rect() -> Rect2`, вписывающий
  пропорцию 16:9 в текущий `size` (центрирование, поля залить
  `UiTheme.COL_BG`). Все нормализованные координаты умножать на
  `_map_rect()` (позиция+размер), а не на `size` — заменить в
  `_node_center`, `_smooth_polyline`, `_draw_*`.

**Step 2: Фон-картинка с фолбэком**

В начале `_draw()`:

```gdscript
var background := GenAssets.texture("map/map_background.png")
if background != null:
	draw_texture_rect(background, _map_rect(), false)
else:
	_draw_parchment()
	_draw_rivers()
	_draw_ridge()
	_draw_forests()
```

`_draw_compass()` и `_draw_frame()` вызывать только в фолбэке (на
картинке компас уже нарисован); `_draw_cartouche()` оставить всегда —
подпись и легенда живут в коде.

**Step 3: Маркеры городов**

В `_draw_nodes()`: если есть `GenAssets.texture("map/marker_%s.png" % info["key"])`
— рисовать её (размер ~72 px, центр в `_node_center(i)`), поверх —
выделение/ховер золотой дугой как сейчас; иначе — текущая отрисовка
кружка с глифом. Подписи и бейджи предприятий не меняются.

**Step 4: Спрайт обоза**

В `_draw_caravans()`: если есть `map/caravan.png` — `draw_texture_rect`
(~48×32, центр в `pos`, зеркалить по направлению движения через
`Rect2` с отрицательной шириной), поверх — флажок цвета владельца
(маленький треугольник) и количество как сейчас; иначе — текущие круги.

**Step 5: Проверить**

Run: `$GODOT --path . --script tests/screenshot.gd --resolution 1600x900`
Expected (ассетов ещё нет): карта выглядит как раньше (фолбэк), пять
узлов НЕ появилось — рисуются только `economy.nodes` (три). Открыть PNG.

Run: `$GODOT --headless --script tests/headless_checks.gd`
Expected: все проверки проходят.

**Step 6: Commit**

```bash
git add ui/map_view.gd
git commit -m "ui: карта читает раскладку и ассеты с фолбэком на чертёж"
```

---

### Task 6: Два экрана — карта на весь экран, каркас города

**Files:**
- Modify: `ui/main.gd`
- Create: `ui/city_screen.gd` (каркас)

**Step 1: Каркас городского экрана**

```gdscript
# city_screen.gd — полноэкранная сцена города: панорама + здания
extends Control

signal back_requested
signal paper_requested(paper_id: String)  # market / works / contracts / caravans

const UiTheme := preload("res://ui/ui_theme.gd")
const GenAssets := preload("res://ui/gen_assets.gd")
const MapLayout := preload("res://ui/map_layout.gd")

var economy
var node_index := -1

var _panorama: TextureRect
var _fallback: ColorRect
var _title_label: Label
var _buildings_box: Control


func setup(economy_ref) -> void:
	economy = economy_ref
	_build()


func show_city(index: int) -> void:
	node_index = index
	_refresh()
	show()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# фон: панорама или тёмная заливка с названием
	# кнопка «На карту» в левом нижнем углу (AccentButton)
	# _buildings_box пересобирается в _refresh()
	...


func _refresh() -> void:
	...
```

В этой задаче: фон (панорама или `COL_BG` + крупный заголовок города),
кнопка «На карту» → `back_requested`. Здания — в Task 9.

**Step 2: Перестроить `main.gd`**

- Убрать `_build_side_panel()` и всё, что с ним связано
  (`_tab_buttons`, `_tab_panels`, `SIDE_PANEL_WIDTH`, `TAB_*`).
  Панели (`_city_panel` и пр.) пока создавать, но не добавлять в дерево —
  они переедут в бумаги (Task 8); чтобы смоук не падал, их `setup()`
  вызывать, а сами ноды складывать в невидимый контейнер.
- Структура: `_map_view` — full rect; `_top_bar` поверх сверху
  (anchors top wide); статус-строка поверх снизу; `_city_screen` —
  full rect, скрыт.
- `_on_map_node_clicked(index)` → `_select_node(index)`,
  `_city_screen.show_city(index)`, `_map_view.hide()`.
- `back_requested` → `_city_screen.hide()`, `_map_view.show()`.
- `_refresh_all()` обновляет и `_city_screen`, если виден.

**Step 3: Скриншоты обоих экранов**

Дополнить `tests/screenshot.gd`: второй кадр — клик по Невьянску
(вызвать `main._on_map_node_clicked(0)` напрямую — индекс Невьянска
уточнить по `economy.nodes`), имя кадра `city`.

Run: `$GODOT --path . --script tests/screenshot.gd --resolution 1600x900`
Expected: `map` — карта на весь экран с планкой поверх; `city` — тёмный
экран с названием города и кнопкой «На карту».

Run: `$GODOT --headless --script tests/headless_checks.gd` — проходит.

**Step 4: Commit**

```bash
git add ui/main.gd ui/city_screen.gd tests/screenshot.gd
git commit -m "ui: карта во весь экран и каркас городского экрана"
```

---

### Task 7: Пергаментная тема и контейнер «бумаги»

**Files:**
- Modify: `ui/ui_theme.gd`
- Create: `ui/paper_panel.gd`

**Step 1: Тема для бумаг**

В `ui_theme.gd` добавить `static func build_paper() -> Theme`: копия
структуры `build()`, но «чернильная»: `default` Label — `COL_INK`,
вариации `DimLabel`/`SmallDimLabel`/`SubHeaderLabel`/`ValueLabel`/
`HeaderLabel` — чернильные оттенки (`COL_INK`, `COL_INK_SOFT`, тёмная
латунь `#7a5c1e`), кнопки — стиль `ParchmentButton` как базовый
`Button`, `LineEdit`/`SpinBox`/`OptionButton`/`ProgressBar`/`CheckBox` —
светлый фон `COL_PARCHMENT_DARK`, чернильные рамки. Тема присваивается
корню бумаги — дочерние панели наследуют её автоматически, их код не
меняется.

**Step 2: Контейнер бумаги**

```gdscript
# paper_panel.gd — центрированный документ поверх сцены города
extends Control

signal closed

const UiTheme := preload("res://ui/ui_theme.gd")
const GenAssets := preload("res://ui/gen_assets.gd")
```

- Full rect, тёмная полупрозрачная подложка (клик по ней = закрыть).
- Центр: `PanelContainer` шириной 700 px, высота до 85% экрана,
  внутри `ScrollContainer`.
- Фон панели: если есть `chrome/paper_frame.png` —
  `StyleBoxTexture` с margin 96 px; иначе — `ParchmentPanel` из темы.
- Шапка: заголовок (`InkTitleLabel`), печать (`chrome/seal.png` или
  `WaxSeal` из `event_dialog.gd` — класс `WaxSeal` вынести в
  `ui_theme.gd` или отдельный файл, чтобы не дублировать), кнопка «×».
- `func open(title: String, content: Control) -> void` — вставляет
  контент, показывает; Esc закрывает (`_unhandled_key_input`).
- В `_init`: `theme = UiTheme.build_paper()`.

**Step 3: Проверка**

Смоук + headless_checks проходят (бумага ещё не используется).

**Step 4: Commit**

```bash
git add ui/ui_theme.gd ui/paper_panel.gd
git commit -m "ui: пергаментная тема и контейнер панели-бумаги"
```

---

### Task 8: Разрезать city_panel на бумаги

Сейчас `ui/city_panel.gd` — это рынок+торг+обоз+стройка+список дворов.
Маппинг на здания: рынок+торг → «Торговые ряды», обоз → «Ямской двор»,
стройка+дворы → «Контора» (вместе с works_panel), заказы → «Приказная
изба».

**Files:**
- Create: `ui/papers/market_paper.gd` — перенести из `city_panel.gd`:
  `_build_market_grid`, `_build_trade_box`, `_market_rows`, `_on_buy`,
  `_on_sell`, `_trend_direction`, `_update_trade_preview`. Селектор
  узла (`_node_select`) больше не нужен — узел задаётся снаружи
  (`set_node_index`), заголовок узла рисует бумага.
- Create: `ui/papers/caravan_paper.gd` — `_build_caravan_box`,
  `_rebuild_destinations`, `_update_travel_label`,
  `_update_dispatch_modes`, `_on_send_caravan`, `_player_has_works_here`
  (комментарий-заглушку v0 сохранить).
- Create: `ui/papers/works_paper.gd` — обёртка-VBox: сверху существующий
  `WorksPanel` (переиспользовать класс как есть), ниже — блок стройки из
  `city_panel.gd` (`_build_construction_box`, `_on_build`,
  `_update_build_preview`) и список дворов (`_refresh_enterprise_list`).
- Delete: `ui/city_panel.gd` (после переноса всего кода).
- Modify: `ui/main.gd` — создание панелей заменить на бумаги; сигналы
  `action_performed` подключить как раньше.

Сигнатуры всех бумаг одинаковые: `setup(gameplay_ref)`,
`set_node_index(index)`, `refresh()`, сигнал `action_performed(message)`.
`contracts_panel.gd` остаётся как есть (он уже самодостаточен).

**Step 1: Перенос кода** (механический, без изменения логики).

**Step 2: Временная проверка**: в `main.gd` пока нет зданий — открыть
бумаги нечем. Добавить в `city_screen.gd` временный ряд обычных кнопок
(«Торговые ряды», «Контора», «Заказы», «Ямской двор») внизу экрана,
эмитящих `paper_requested`; `main.gd` по сигналу открывает
`paper_panel.open(label, paper)`.

**Step 3: Скриншоты**: добавить в `tests/screenshot.gd` кадр
`city_market` (клик города + `paper_requested.emit("market")`).
Expected: пергаментный документ с чернильным текстом рынка, читаемый.
Проверить глазами контраст.

Run: headless_checks — проходит (симуляция не тронута).

**Step 4: Commit**

```bash
git add ui/papers ui/main.gd ui/city_screen.gd tests/screenshot.gd
git rm ui/city_panel.gd
git commit -m "ui: панели-бумаги города вместо боковых вкладок"
```

---

### Task 9: Здания городской сцены

**Files:**
- Modify: `ui/city_screen.gd`

**Step 1: Здания из раскладки**

В `_refresh()` пересобрать `_buildings_box` по
`MapLayout.buildings(node_name)`:

- Спрайт есть (`buildings/<sprite>.png`): `TextureButton`,
  `texture_normal` = спрайт, `ignore_texture_size = true`,
  `stretch_mode = STRETCH_KEEP_ASPECT`, позиция/размер из `rect`
  (нормализованные → пиксели окна), `texture_click_mask` из альфы:

```gdscript
var mask := BitMap.new()
mask.create_from_image_alpha(texture.get_image())
button.texture_click_mask = mask
```

- Спрайта нет: фолбэк — «табличка»: `Button` c текстом здания,
  позиция из того же `rect`, стиль `ParchmentButton`.
- Ховер: `mouse_entered`/`mouse_exited` → `modulate = Color(1.15,...)`
  и лента-подпись с названием у нижнего края здания (Label на
  тёмной полуплашке).
- «Приказная изба» рисуется только там, где есть в раскладке (Москва);
  `paper_requested("contracts")`.
- Убрать временный ряд кнопок из Task 8.

**Step 2: Проверить скриншотами**: кадры `city` (Невьянск) и
`city_moscow`. Expected: без ассетов — читаемые кнопки-таблички на
местах зданий; клик открывает нужную бумагу.

**Step 3: Commit**

```bash
git add ui/city_screen.gd tests/screenshot.gd
git commit -m "ui: кликабельные здания городской сцены с фолбэком"
```

---

### Task 10: Иконки товаров

**Files:**
- Modify: `ui/ui_theme.gd`

**Step 1:** Добавить в `ui_theme.gd`:

```gdscript
const GOOD_ICON_KEYS := {
	Goods.Good.RUDA: "ruda",
	Goods.Good.CHUGUN: "chugun",
	Goods.Good.ZHELEZO: "zhelezo",
	Goods.Good.ZERNO: "zerno",
	Goods.Good.MUKA: "muka",
	Goods.Good.VODKA: "vodka",
}


static func good_icon(good: int, diameter := 12) -> Texture2D:
	var asset := GenAssets.texture("goods/%s.png" % GOOD_ICON_KEYS[good])
	return asset if asset != null else good_dot(good, diameter)
```

(преload `GenAssets` добавить). Заменить вызовы `good_dot` на
`good_icon` в `ui/papers/market_paper.gd` и `ui/contracts_panel.gd`;
в `TextureRect` для иконок задать `custom_minimum_size = Vector2(20, 20)`
и `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`, `expand_mode =
EXPAND_IGNORE_SIZE` — иначе PNG 128×128 разорвёт таблицу.

**Step 2:** Смоук + скриншот `city_market` — таблица не разъехалась.

**Step 3: Commit**

```bash
git add ui/ui_theme.gd ui/papers/market_paper.gd ui/contracts_panel.gd
git commit -m "ui: иконки товаров из gen-ассетов с фолбэком на кружки"
```

---

### Task 11: Persona — детерминированные лица и имена (TDD)

**Files:**
- Create: `ui/persona.gd`
- Modify: `tests/headless_checks.gd`

**Step 1: Написать падающий тест**

В `tests/headless_checks.gd` добавить проверку (по образцу соседних):

```gdscript
const Persona := preload("res://ui/persona.gd")

# ...в списке проверок:
var p1 := Persona.for_contract({"id": 7, "good": 2, "relations_bonus": 3.0})
var p2 := Persona.for_contract({"id": 7, "good": 2, "relations_bonus": 3.0})
_check(p1 == p2, "persona: одинаковый контракт даёт одно лицо")
_check(p1["name"] != "", "persona: имя не пустое")
_check(
	Persona.for_contract({"id": 8, "good": 2, "relations_bonus": 0.0})["role"] == "kupets",
	"persona: частный заказ выдаёт купец"
)
_check(p1["role"] == "podyachy", "persona: казённый заказ выдаёт подьячий")
var ev := Persona.for_event("state_inspection", "podyachy")
_check(ev == Persona.for_event("state_inspection", "podyachy"), "persona: событие стабильно")
```

(точный синтаксис проверок подсмотреть в самом файле headless_checks —
использовать его существующий хелпер, не изобретать новый).

Run: `$GODOT --headless --script tests/headless_checks.gd`
Expected: FAIL — `persona.gd` не существует.

**Step 2: Реализовать `ui/persona.gd`**

```gdscript
# persona.gd — детерминированные лица и имена для UI (без RNG!)
# Выбор — стабильный хеш от данных: сейв и реплей всегда видят то же лицо.
extends RefCounted

const ROLE_PORTRAIT_COUNTS := {
	"podyachy": 2, "kupets": 3, "prikazchik": 2, "master": 2, "starosta": 2, "officer": 1
}
const ROLE_TITLES := {
	"podyachy": "Подьячий", "kupets": "Купец", "prikazchik": "Приказчик",
	"master": "Мастер", "starosta": "Староста", "officer": "Офицер"
}
const FIRST_NAMES := [
	"Аким", "Прохор", "Савва", "Фрол", "Гаврила", "Лукьян", "Никифор", "Осип", "Тихон", "Ерофей"
]
const LAST_NAMES := [
	"Оглоблин", "Шапошников", "Вяткин", "Коробов", "Сычёв", "Лодыгин",
	"Пятов", "Хомяков", "Бутурлин", "Скорняков"
]


static func for_contract(contract: Dictionary) -> Dictionary:
	var role := "podyachy" if contract.get("relations_bonus", 0.0) > 0.0 else "kupets"
	return _persona(role, hash("contract_%d" % int(contract.get("id", 0))))


static func for_event(event_id: String, speaker_role: String) -> Dictionary:
	return _persona(speaker_role, hash("event_%s" % event_id))


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
```

Внимание: `hash()` в Godot стабилен внутри версии движка — этого
достаточно (лица не сериализуются, расходятся максимум между версиями
Godot, что не ломает сейвы).

**Step 3:** Run headless_checks → PASS.

**Step 4: Commit**

```bash
git add ui/persona.gd tests/headless_checks.gd
git commit -m "ui: persona — детерминированные лица и имена + тесты"
```

---

### Task 12: Портрет в событии-письме

**Files:**
- Modify: `sim/event_catalog.gd` — в каждое из трёх событий добавить
  поле `"speaker_role"`: `state_inspection` → `"podyachy"`,
  `worker_demand` → `"master"`, `fair_shortage` → `"kupets"`.
- Modify: `ui/event_dialog.gd` — слева от текста колонка портрета:
  `TextureRect` 96×96 (`GenAssets.texture(persona["portrait"])`; если
  null — не показывать картинку) + подпись «Роль Имя Фамилия»
  (`InkDimLabel`). Данные: в `show_event()` вызвать
  `Persona.for_event(event["id"], event.get("speaker_role", "prikazchik"))`.
- Modify: `ui/main.gd` — если `show_event` теперь требует изменений
  вызова, поправить (не должен: событие уже несёт `id`).

Проверка: добавить кадр `event` в скриншот-драйвер (дотикать до тика 5
циклом `gameplay.advance_tick()` перед снятием кадра — событие
`state_inspection` откроется само). Подпись видна, без портрета-файла
вёрстка не разваливается. headless_checks проходит (поле — чистые
данные).

Commit: `git commit -m "ui: портрет и имя отправителя в событии-письме"`
(вместе с `sim/event_catalog.gd`; это data-поле, порядок фаз не тронут).

---

### Task 13: Лица на приказной доске

**Files:**
- Modify: `ui/contracts_panel.gd`

В `_card_base()` добавить строку персоны: мини-портрет 40×40 (если файл
есть) + «Купец Савва Коробов просит:» (`SmallDimLabel`) над заголовком.
`Persona.for_contract(contract)`.

Проверка: скриншот-кадр `city_contracts` (Москва → приказная изба).
Commit: `ui: заказы получают лицо и имя выдавшего`.

---

### Task 14: Летопись и статус-строка

**Files:**
- Modify: `ui/top_bar.gd` — кнопка «Летопись» (сигнал
  `journal_pressed`).
- Modify: `ui/main.gd` — по сигналу открывать `paper_panel.open(
  "Летопись", _journal_panel)` поверх любого экрана.

Проверка: смоук + скриншот. Commit: `ui: летопись открывается из планки`.

---

### Task 15: Финал — CLAUDE.md, полный прогон

**Step 1:** Обновить CLAUDE.md, раздел «Архитектура» `/ui`:
main/city_screen/paper_panel/papers/persona/gen_assets/map_layout,
упомянуть `docs/asset-brief.md` и правило фолбэков. Обновить
`docs/roadmap-history.md` строкой о редизайне.

**Step 2:** Полный прогон:

```bash
$GODOT --headless --script econ_core.gd            # тики печатаются
$GODOT --headless --script tests/headless_checks.gd # все проверки OK
$GODOT --headless --path . --quit-after 1           # смоук
$GODOT --path . --script tests/screenshot.gd --resolution 1600x900
```

Просмотреть ВСЕ кадры глазами: карта, город, рынок, контора, заказы,
событие. Проверить: контраст текста на пергаменте, ничего не
разъехалось, фолбэки не выглядят сломанными.

**Step 3:** Commit: `docs: обновить архитектуру /ui после редизайна`.

---

## После плана

Ассеты интегрируются без кода: пользователь генерит PNG по
`docs/asset-brief.md`, кладёт в `ui/assets/gen/...`, перезапускает игру.
Полировочный проход (позиции зданий, размеры маркеров под реальные
картинки) — отдельной сессией по скриншотам.
