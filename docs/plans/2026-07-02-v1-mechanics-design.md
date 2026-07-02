# Этап v1 «Механики играбельности» — дизайн и инструкции

Статус: утверждён 2026-07-02. Реализация — по милстоунам M1–M7, строго по порядку.
Каждый милстоун коммитабелен и проверяем headless-прогоном (кроме UI-частей).

## 1. Зачем этот этап

v0 (роадмап CLAUDE.md пп. 1–7) выполнен: ядро симуляции, караваны, рынок труда,
минимальный UI, один контракт, события, сохранения. Но игрой это не ощущается.
Подтверждённые разрывы:

1. **Нет цели и прогрессии** — один контракт, после него «что дальше?».
2. **Нечего решать** — оптимальные действия очевидны, давления нет.
3. **Мир мёртвый** — нет конкурентов, рынок реагирует только на игрока.
4. **Непонятно и неудобно** — три панели без карты и обратной связи.

Принятые решения этапа:

- **Ядро фантазии — промышленник** (путь Демидова): строить и развивать заводы,
  управлять тремя типами труда. Торговля — сбыт продукции, не самоцель.
- **Формат — демо-прототип механик**: каждая механика проверяема отдельно,
  цельный сценарий с нарастающей сложностью соберём следующим этапом.
- **Конкурент равный игроку**: играет по тем же правилам через те же
  публичные API (симметричный агент). Первичный вектор пересмотрен в сторону
  честного LLM-конкурента: он видит тот же observation, что и игрок, а не
  скрытое состояние симуляции. См. `docs/llm-contract.md`.
- **Детерминизм сохраняется**: вся случайность этапа — один сеемый RNG
  в контрактной доске, seed+state сериализуются в сейв.

## 2. Наблюдения из кода, влияющие на дизайн

- `economy.gd` трогает `player` в ~12 местах: производство (зарплата/зерно),
  `buy/sell/dispatch/buy_and_dispatch`, `request_ascribed_workers`,
  `_arrive_caravan` (sell_on_arrival кредитует игрока), `_update_labor_market`,
  `_best_open_hired_wage`, save/load.
- `sold_total` глобален (`TradeNode -> Good -> float`) и является механизмом
  прогресса контракта (baseline-delta в `gameplay.gd`). Для контрактов двух
  агентов делаем его per-agent — в составе M1.
- **Циклы RefCounted**: обратная ссылка `Enterprise.owner: Agent` при
  `Agent.enterprises: Array[Enterprise]` даст цикл и утечку. Только
  `owner_id: String` (заодно тривиально сериализуется).
- `TradeNode._init` и `_load_number_dict` итерируют `Goods.Good.values()` —
  добавление товаров **в конец enum** обратно-совместимо со старыми сейвами.
  Существующие значения enum не переставлять никогда.
- Порядок фаз в CLAUDE.md уже резервирует фазу «действия игрока/ИИ» — ИИ и
  стройка встраиваются легально.
- Известная причуда: зарплата списывается даже при `money < wage_cost`
  (только cap×0.5) — деньги могут уйти в минус. Формулу молча не менять;
  для ИИ лечится эвристикой «не перенанимать».

## 3. Милстоуны

### M1 — Рефакторинг Player → Agent (save v2)

**Цель:** симметричные агенты; при одном агенте поведение бит-в-бит как сейчас.

`sim/economy.gd`:

- Inner class `Player` → `Agent`, новые поля: `id: String`,
  `display_name: String` (русское имя), `is_player: bool`. Остальное без
  изменений (`money`, `state_relations`, `enterprises`).
- `var agents: Array[Agent] = []`; `player` остаётся ссылкой на `agents[0]`
  (назначается в `add_agent()`) — сокращает churn в gameplay/ui.
- Хелперы: `add_agent(id, display_name, is_player) -> Agent`,
  `agent_by_id(id) -> Agent`, `all_enterprises() -> Array[Enterprise]`.
- Действия получают агента первым параметром (единственное «массовое»
  изменение): `buy(agent, n, g, qty)`, `sell(agent, ...)`, `dispatch(agent,
  ...)`, `buy_and_dispatch(agent, ...)`, `request_ascribed_workers(agent, e,
  qty)`. `set_hired_wage_offer(e, wage)` не трогать.
- Производство: `for a in agents: for e in a.enterprises:` — зарплата
  списывается с владельца. Порядок детерминирован (player всегда `agents[0]`).
- `_update_labor_market()` и `_best_open_hired_wage()` — по `all_enterprises()`.
- `Caravan.owner_id: String` (задаётся в dispatch); `_arrive_caravan`
  кредитует `agent_by_id(c.owner_id)`.
- `sold_total` → `agent_id -> TradeNode -> Good -> float`;
  `sold_amount(agent, n, g)`. Фундамент контрактов M4.
- Печать сделок префиксовать `display_name` агента.

Save v2 + миграция:

- `to_save_data()`: `"player"` → `"agents": [{id, name, is_player, money,
  state_relations}]`; в enterprise- и caravan-записях — `"owner": agent_id`;
  `sold_total` — с agent_id.
- `gameplay.gd`: `SAVE_VERSION := 2`; в `load_from_file` перед загрузкой —
  `_migrate_save(data)`: если `version < 2`, обернуть старого player в агента
  `"player"`, приписать ему все enterprises/caravans/sold_total (~30 строк).

Точки правки вызовов: `sim/demo_scenario.gd` (создание игрока через
`add_agent("player", "Демидов", true)`), `sim/gameplay.gd` (точечно:
`_apply_event_effect`, `to_llm_context`), `ui/main.gd` (6 обработчиков
кнопок — добавить `economy.player`). `econ_core.gd` — по сути без изменений.

`tests/headless_checks.gd` (новый, extends SceneTree, `assert()`, без GUT):

1. 16 тиков — все цены строго внутри клампов 0.25×/4× к тику 16.
2. save→load→8 тиков == непрерывные 24 тика (главный регресс-тест этапа —
   детерминизм это позволяет).
3. Захардкоженный v1-сейв мигрирует без ошибок.

Запуск: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/headless_checks.gd`

**Верификация:** diff вывода `econ_core.gd` до/после — расхождения только в
префиксах имён агента. Тесты зелёные. Коммиты: `sim: агент вместо игрока`,
`sim: save v2 и миграция v1`, `ui: действия от имени агента`,
`tests: headless-проверки детерминизма`.

### M2 — Строительство и расширение (save v3)

`sim/construction.gd` (новый, по образцу caravan.gd), RefCounted:
`owner_id: String`, `node: TradeNode`, `recipe: String`, `capacity: float`,
`remaining_ticks: int`, `possessional_workers: int`,
`expand_target: Enterprise` (null = новое предприятие),
`display_name: String`; метод `advance() -> bool`.

Баланс (data-shaped, пока в коде):

- `Recipes.DEFS` — каждому рецепту `"build_cost"` (за ед. мощности),
  `"build_ticks"`, `"display_name"` (для авто-именования «Кузница №2»).
  Ориентиры: rudnik 60/4, domna 120/6, kuznitsa 90/5.
- `labor.gd`: `const POSSESSIONAL_PRICE := 25.0`,
  `const POSSESSIONAL_MAX_PER_CAPACITY := 2`. Посессионные покупаются только
  вместе со стройкой, не отдельно (решение №3 CLAUDE.md).

`sim/economy.gd`:

- `var construction_queue: Array[Construction] = []`.
- `start_construction(agent, node, recipe, capacity, possessional := 0) ->
  bool`: стоимость = `build_cost * capacity + possessional *
  POSSESSIONAL_PRICE`; проверка денег и лимита посессионных; деньги сразу.
- `expand_enterprise(agent, e, extra_capacity) -> bool`: стоимость
  `build_cost * extra * 0.8`, срок `ceil(build_ticks * 0.6)`.
- Новая фаза тика **между караванами и рынком труда**:
  `_advance_construction()` — завершённые проекты создают Enterprise
  (посессионные сразу в `workers[POSSESSIONAL]`, мимо labor_pool — они
  куплены) или увеличивают `capacity` цели. До рынка труда — чтобы новый
  завод мог нанять в тот же тик. Фиксируется в CLAUDE.md в том же коммите
  (порядок фаз — ключевое решение №4).
- Save v3: сериализация очереди (owner, node index, recipe, capacity,
  remaining, possessional, expand-target index или −1). Отсутствие поля в
  старом сейве = пустая очередь.

UI-хук (механика играбельна сразу): кнопка «Расширить +1» в панели
предприятия; ряд «Построить: [рецепт] [посессионные] [кнопка]» в панели узла;
очередь строек строкой в панели «Ход».

**Верификация:** скриптовая стройка в econ_core на тике 2 — деньги упали
ровно на стоимость; через build_ticks предприятие появилось со штатом;
к тику 20 производит. Save/load посреди стройки переживает roundtrip.

### M3 — Вторая цепочка: зерно → мука → водка

- `goods.gd`: `enum Good { RUDA, CHUGUN, ZHELEZO, ZERNO, MUKA, VODKA }` —
  строго в конец. NAMES: «Мука», «Водка». BASE_PRICE: MUKA 2.5, VODKA 9.0
  (проверить прогоном).
- `recipes.gd`:
  - `"melnitsa"`: 3 зерна → 2 муки, labor 2.0, build 70/4.
  - `"vinokurnya"`: 2 муки → 1 водка, labor 3.0, build 140/6.
- `demo_scenario.gd`: Москва — `consumption` MUKA 1.5 / VODKA 0.8,
  `target_stock` 12/6, стартовые запасы 8/4 (чтобы цены не стартовали с
  клампа); Макарьево — `target_stock[MUKA] = 8` (зерно и 30 наёмных —
  естественная площадка цепочки). Заводы второй цепочки в сценарии **не
  сеять** — они строятся игроком/ИИ, это делает стройку осмысленной.
- **Вынос баланса в /data JSON — не в этом этапе.** Причины: enum-маппинг и
  валидация — код без игровой ценности сейчас; баланс сконцентрирован в трёх
  файлах и правится за минуту; этап про механики. Держать словари
  «data-shaped» (плоские, без логики) — будущий вынос станет механическим.

**Верификация:** 30-тиковый прогон со скриптовой стройкой мельницы (тик 1) и
винокурни (тик 6) в Макарьеве и перевозкой в Москву: цены всех 6 товаров вне
клампов; зерно в Макарьеве не рухнуло. headless_checks дополнить проверкой
клампов по всем товарам.

### M4 — Генератор контрактов + сеемый RNG (save v4)

`sim/contracts.gd` (новый) — `ContractBoard extends RefCounted`. Весь
недетерминизм этапа живёт здесь, в одном RNG.

- Поля: `rng := RandomNumberGenerator.new()`, `open_offers: Array[Dictionary]`,
  `active: Array[Dictionary]`, `next_contract_id: int`,
  `completed_count: Dictionary` (agent_id -> int).
- Контракт-словарь: `{id, good, qty, destination_index, deadline_tick, reward,
  penalty, relations_bonus, relations_penalty, taken_by: String ("" = открыт),
  baseline_sold: float}`.
- `setup(seed_value)` — `rng.seed = seed_value`.
- `refresh(economy)` раз в тик, строгий порядок:
  1. Завершение: `delivered = sold_amount(agent, dest, good) - baseline_sold`;
     при `>= qty` — reward, `+relations`, notice.
  2. Просрочка: penalty (`money = max(0, money - penalty)`), `-relations`.
  3. Протухание открытых офферов (дедлайн стал недостижим).
  4. Генерация: если открытых < 3 и `tick_count % 4 == 0` — один оффер.
     Броски строго в фиксированном порядке: товар (взвешенно, железо и мука
     чаще) → назначение (Москва ~60%) → tier 1–3 → qty = base_qty × tier ×
     `randf_range(0.8, 1.2)` → deadline = tick + 10 + tier×4 → reward =
     qty × BASE_PRICE × dest-фактор × `randf_range(1.3, 1.6)`,
     penalty = 0.5 × reward.
- `accept(contract_id, agent, economy)` — фиксирует `taken_by` и
  `baseline_sold`. `decline(contract_id)` — только игрок, без штрафа в v1.
- `to_save_data()/load_save_data()` — включая **`rng.seed` и `rng.state`**
  (оба int) — восстановление даёт идентичный дальнейший поток офферов.

`sim/gameplay.gd`:

- Удалить `CONTRACT_*`, `contract_start_sold/contract_done/contract_failed`,
  `_check_contract()`.
- `var board := ContractBoard.new()`; `board.setup(SCENARIO_SEED)`
  (const, например 1725).
- `advance_tick()`: `economy.tick()` → `board.refresh(economy)` → (M5: ИИ) →
  `run_logistics(...)` → `_maybe_raise_event()`.
- API для UI: `open_contracts()`, `player_contracts()`, `accept_contract(id)`,
  `decline_contract(id)`, `contract_line(c) -> String` (русская строка).
- `to_llm_context()`: секция `contract` → `contracts: {open, active}`.
- `SAVE_VERSION := 4`. Политика: бамп на каждый милстоун, меняющий схему;
  недостающие секции = дефолты; реальная миграция — только v1→v2.
- `DemoScenario.run_logistics` авто-продаёт железо в Москву — теперь это
  «бесплатный» прогресс контрактов. Пометить `# v0-заглушка: автопилот демо,
  убрать в M6` и убрать при переходе на карту.

UI-хук: в панели «Ход» — список открытых офферов с кнопками «Взять»/«Отказ»,
активные с прогрессом (`delivered/qty`, дедлайн). `contract_label` заменить.

**Верификация:** (1) два прогона с одним сидом → diff пуст; (2) другой сид →
другой поток; (3) скриптовое принятие и выполнение контракта →
`completed_count["player"] >= 1`; (4) save/load посреди активного контракта →
тот же дальнейший поток офферов; (5) просрочка снимает деньги.

### M5 — ИИ-конкурент

> Обновление после пересмотра LLM-контракта: M5 не должен превращаться в
> классического всевидящего AI. Если для локальных тестов нужен
> детерминированный контроллер, он допустим только как fallback/fixture.
> Целевая архитектура — LLM-конкурент с observation/action-контрактом из
> `docs/llm-contract.md`.

- `demo_scenario.gd`: `add_agent("stroganov", "Строгановы", false)`,
  деньги 400, стартовое предприятие — мельница cap 1.5 в Макарьеве (зерно и
  наёмные под боком; ИИ живёт во второй цепочке, но правила симметричны —
  может строить и железное).
- `sim/ai_agent.gd` (новый) — `AiAgent extends RefCounted`,
  **стейтлес**-контроллер: держит только `agent_id`; всё состояние — в
  Agent/Economy (сейв-совместимость бесплатно; контроллеры пересоздаются в
  `gameplay.setup()`/`load_save_data()` по `is_player == false`).
  `act(economy, board)` вызывается из `gameplay.advance_tick()` после
  `board.refresh()` — это фаза «действия ИИ».

Правила в фиксированном порядке, детерминированные, тай-брейки по индексу,
**никакого RNG**; пороги — const-блок наверху файла:

1. **Зерновой буфер**: для узлов со своими предприятиями
   `need = Σ UPKEEP_GRAIN штата × 6 тиков`; если `stock + in_transit < need` —
   `buy_and_dispatch` из самого дешёвого узла (≤1 закупки/тик,
   лимит 25% денег).
2. **Зарплаты**: недоштат → `offer + 0.1` (кламп до 2.6); полный штат и
   `offer > HIRED_RESERVATION_WAGE + 0.1` → `offer − 0.1`.
3. **Взять контракт**: если активных < 2 — маржа каждого оффера =
   `reward − qty × лучшая цена товара − qty × 0.05 × путь`; взять лучший с
   `margin > 0.15 × reward` при достижимом дедлайне.
4. **Исполнение**: по активным — `dispatch(..., sell_on_arrival = true)` в
   объёме `min(остаток, сток)`, если `путь <= deadline − tick`.
5. **Стройка**: `money > 600`, своих строек нет → маржа каждого рецепта по
   ценам домашнего узла (`out×price − in×price − labor×WAGE[HIRED]`);
   построить лучший cap 1.0 с 2 посессионными; если лучший — уже имеющийся
   рецепт, то `expand_enterprise` +0.5.
6. **Сброс излишков**: раз в 5 тиков, сток выхода > 2×target_stock →
   dispatch в узел с лучшей ценой, sell_on_arrival.

Принцип: ИИ действует **только через публичные API** Economy/ContractBoard —
ни одного прямого `money +=` или правки stock.

**Верификация (40 тиков):** ИИ хотя бы раз построил/расширил;
`completed_count["stroganov"] >= 1`; оба агента платёжеспособны на тике 40;
цены вне клампов; два прогона с одним сидом — идентичный вывод.

### M6 — Экран карты

`ui/map_view.gd` (новый) — `extends Control`, процедурно, в стиле main.gd.
Подход: **Control + `_draw()`**, не Node2D (main.gd целиком Control-лейаут,
не нужны камеры/трансформы).

- `const NODE_POS := {...}` — нормированные координаты × `size`
  (схематично запад→восток: Москва 0.15, Макарьево 0.5, Невьянск 0.85).
- `_draw()`: линии-маршруты (используемые пары жирнее); кружки узлов;
  мини-квадратики предприятий цветом владельца (игрок/ИИ); караваны — точки
  на линии в позиции `1.0 − remaining_ticks/total_ticks` с цветом владельца
  и подписью товара; значок стройки у узла при активном проекте.
- Клики: прозрачные flat-`Button` поверх узлов (позиционируются в
  `_notification(NOTIFICATION_RESIZED)`), сигнал `node_clicked(index)` —
  надёжнее ручного хит-теста.
- `refresh(economy)` — `queue_redraw()`; вызывается из `_refresh_all()`.
  Дискретная анимация по тикам — достаточно для демо.

`ui/main.gd` — перекомпоновка: хедер → **карта** (~60% высоты,
EXPAND_FILL) → нижняя полоса из трёх существующих панелей
(узел/предприятие/ход) — переиспользуются как detail views без переписывания.
`node_clicked` → выбор узла + `_refresh_all()`. Убрать авто-логистику железа
из `run_logistics` (см. M4).

**Верификация:** `--headless --path . --quit-after 1` без ошибок скриптов;
ручной прогон: клики переключают панель, караваны движутся, маркеры ИИ видны;
headless_checks зелёные (UI ничего не пишет в /sim).

### M7 — Финальная сверка CLAUDE.md

Правки CLAUDE.md идут по ходу милстоунов в том же коммите, что и изменение
(правило «Рабочего процесса»). M7 — контрольная сверка, что ничего не
потерялось:

- Архитектура: + `sim/construction.gd`, `sim/contracts.gd`,
  `sim/ai_agent.gd`, `ui/map_view.gd`, `tests/headless_checks.gd`.
- Порядок фаз: производство → потребление → цены → караваны → **стройка** →
  рынок труда → **контрактная доска → действия ИИ** → действия игрока
  (оркестрация пост-тиковых фаз — в `gameplay.advance_tick()`).
- Новые ключевые решения: симметрия агентов (ИИ только через публичные API);
  один RNG в ContractBoard (seed+state в сейве, детерминизм при фиксированном
  сиде обязателен); политика SAVE_VERSION (бамп при изменении схемы, миграции
  в `gameplay._migrate_save`). Правило про enum уже внесено (решение №6).
- Команды: запуск `tests/headless_checks.gd`.
- Роадмап: отметить пп. 9–15; следующий этап — вынос баланса в /data, GUT,
  расширение событийной системы, цельный сценарий.
- Контракт LLM-слоя: секция `contracts` вместо `contract`, конкурент в state.

## 4. Порядок, зависимости, размер

| # | Милстоун | Зависит от | Размер | Headless-проверка |
|---|---|---|---|---|
| M1 | Agent-рефакторинг + save v2 + tests | — | M | diff с golden-выводом; roundtrip-детерминизм |
| M2 | Стройка + посессионные + save v3 | M1 | M | скриптовая стройка: стоимость/сроки/штат |
| M3 | Мука/водка + баланс | M2 | S | 30 тиков, цены вне клампов |
| M4 | Контракты + RNG + save v4 | M1, M3 | M | идентичный поток при одном сиде |
| M5 | ИИ-конкурент | M1, M2, M4 | M | ИИ строит и закрывает контракт |
| M6 | Карта | M1–M5 | M | `--quit-after 1` + ручной прогон |
| M7 | CLAUDE.md | все | S | — |

Рационале порядка: рефакторинг первым, пока база мала; стройка раньше
цепочки (вторая цепочка проверяется «честно» через стройку, а не посев);
контракты раньше ИИ (ИИ — их потребитель); карта последней, когда есть что
показывать. Каждый sim-милстоун оставляет игру играбельной через минимальные
UI-хуки.

Рабочий процесс: коммиты мелкие внутри милстоуна (2–5 шт.), формат
`sim:/ui:/tests:/docs:`, pre-commit хук как есть, `--no-verify` не
использовать. Изменил /sim → прогнал headless → показал вывод тиков.
