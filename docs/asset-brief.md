# Спека AI-ассетов (генерация в ChatGPT / gpt-image)

Все файлы кладутся в `ui/assets/gen/...` со СТРОГО этими именами — код
ищет их по имени, при отсутствии файла работает процедурный фолбэк, так
что генерить можно в любом порядке и частями.

## Как генерить

1. Каждый промпт начинается со **стилевого якоря** (ниже) — копируй его
   первым абзацем, затем текст конкретного ассета.
2. Промпты написаны по-английски — так модель стабильнее держит стиль.
3. Для ассетов с пометкой «прозрачный фон» проси transparent background
   и сохраняй PNG с альфой (в ChatGPT: «transparent background, PNG»).
4. gpt-image выдаёт 1024×1024, 1536×1024 или 1024×1536. Целевые размеры
   в таблице — что должно получиться ПОСЛЕ обрезки; квадратные ассеты
   можно класть как есть 1024×1024, движок сам масштабирует.
   Карту и панорамы: генерить 1536×1024, затем обрезать по центру до
   16:9 (1536×864) в любом редакторе (Preview: Tools → Crop).
5. Если стиль между генерациями поплыл — прикладывай к промпту уже
   принятую картинку как референс («match the style of this image»).

## Стилевой якорь (первый абзац каждого промпта)

> Early 18th-century Russian copper engraving and etching style, in the
> manner of old Petrine-era maps and parsuna portraits. Restrained
> palette: aged parchment (#d9c69e), dark sepia ink (#38291a), muted
> brass-gold accents (#c9a44c). Fine hatching and cross-hatching, slightly
> uneven hand-drawn lines, no modern objects, no anachronisms, NO text,
> NO letters, NO labels anywhere in the image.

## Карта

### `map/map_background.png` — 1536×864 (кроп из 1536×1024)

> An antique engraved map of central Russia from Moscow to the Ural
> mountains, drawn on aged parchment. Terrain shown with fine hatching:
> the Volga river winding vertically through the center, the Kama and
> Chusovaya rivers in the northeast, the Ural mountain ridge as a chain
> of small hatched peaks along the right edge. Clusters of tiny engraved
> pine trees for forests. A decorative compass rose in the upper left.
> An empty decorative cartouche frame in the lower right corner (blank
> inside). Composition must leave recognizable open spots for towns:
> southwest area (Moscow), just south of it (Tula), center on the Volga
> (Makaryevo fair), far northeast at the mountains (Nevyansk), far
> northwest near a sea gulf (St. Petersburg). No town drawings at those
> spots — just clear parchment. Subtle ink stains and darkened edges,
> like a well-used road chart.

Проверка: точки под города свободны, картуш пуст, текста нет.

### Маркеры городов — 5 файлов, 1024×1024, прозрачный фон

Общее продолжение промпта:

> A round vignette medallion for a game map marker: a miniature engraved
> scene inside a thin double ring border, parchment-tinted background
> inside the ring, transparent background outside the circle.

- `map/marker_moskva.png` — «…scene: the Moscow Kremlin — a fortress
  wall with towers and onion-dome churches behind it.»
- `map/marker_tula.png` — «…scene: a gunsmith workshop — a smithy with
  a chimney, crossed musket barrels leaning at the wall.»
- `map/marker_makarievo.png` — «…scene: a riverside trade fair — rows
  of market tents by a monastery wall, a river barge in front.»
- `map/marker_nevyansk.png` — «…scene: an Ural ironworks — a blast
  furnace with smoke, a dam and a water wheel, mountains behind.»
- `map/marker_petersburg.png` — «…scene: a young naval city — a thin
  golden spire, ship masts, sea waves.»

### `map/caravan.png` — 1024×1024 (в игре ~48 px), прозрачный фон

> A loaded merchant cart pulled by a single horse, side view, walking
> left to right. Wooden cart with sacks and barrels under a rope-tied
> tarp, a walking driver figure beside it. Compact silhouette, thick
> readable outlines (it will be shown very small). Transparent
> background.

## Панорамы городов — 1536×864 (кроп из 1536×1024)

Общее продолжение промпта:

> A wide panoramic view for a game city screen, horizon in the upper
> third, the lower third of the image is calm foreground ground with no
> important details (interactive building sprites will be placed over
> it). Muted parchment sky with engraved clouds.

- `cities/panorama_nevyansk.png` — «…An early 18th-century Ural
  ironworks settlement: a log dam across a river forming a pond, a tall
  smoking blast furnace, timber workshops and izba log houses, a
  forested mountain ridge behind.»
- `cities/panorama_makarievo.png` — «…A great river trade fair by a
  white-walled monastery on the Volga: long rows of market tents and
  timber stalls, moored barges and rafts at the bank, crowds suggested
  by small hatched figures.»
- `cities/panorama_moskva.png` — «…Moscow of Petrine times: the Kremlin
  wall with towers, onion-dome churches, timber merchant houses and
  smoke from chimneys, winter-less warm season view.»

## Спрайты зданий — 1024×1024, прозрачный фон

Общее продолжение промпта:

> A single free-standing building sprite for a game scene, transparent
> background, slight three-quarter view, ground shadow as light
> hatching directly under the building only. Thick readable outlines.

Невьянск:

- `buildings/nevyansk_domna.png` — «…An Ural blast furnace complex: a
  massive stone furnace tower with smoke, attached timber casting shed,
  a water wheel at its side.»
- `buildings/nevyansk_kontora.png` — «…A factory office izba: a sturdy
  two-storey log house with a steep shingle roof, small porch, a brass
  plaque-less door.»
- `buildings/nevyansk_ryady.png` — «…Short timber market rows: a long
  low log building with open stalls, goods (barrels, iron bars) at the
  counters.»
- `buildings/nevyansk_yam.png` — «…A coaching yard (yam): log gates
  with a small roof, a fence, a cart and a horse inside the yard.»

Макарьево:

- `buildings/makarievo_ryady.png` — «…Fair trade rows: a line of
  colorful-but-muted market tents and timber stalls with sacks and
  bales.»
- `buildings/makarievo_kontora.png` — «…A merchant office: a small log
  house with a high porch and a strongbox chest by the door.»
- `buildings/makarievo_yam.png` — «…A coaching yard: log gates, a
  covered cart, hay.»

Москва:

- `buildings/moskva_ryady.png` — «…Stone trading rows: a long arcade
  gallery with arched stalls, goods at the counters.»
- `buildings/moskva_prikaz.png` — «…A prikaz government office: a squat
  white-stone chamber building with small barred windows, a heavy
  ornate porch (kryltso) with a tented roof.»
- `buildings/moskva_kontora.png` — «…A merchant house office: a
  two-storey building, stone ground floor and timber upper floor.»
- `buildings/moskva_yam.png` — «…A large coaching yard: gates with an
  icon niche above, two carts, horses.»

## Иконки товаров — 1024×1024 (в игре ~20 px), прозрачный фон

Общее продолжение промпта:

> A single game inventory icon, centered, filling most of the frame,
> very bold simple silhouette with minimal inner hatching (it will be
> shown at 20 pixels), transparent background.

- `goods/ruda.png` — «…A rough chunk of iron ore rock with rusty
  streaks.»
- `goods/chugun.png` — «…Three stacked cast-iron ingots (pigs), dark
  metal.»
- `goods/zhelezo.png` — «…A bundle of forged iron strips tied with
  wire.»
- `goods/zerno.png` — «…A tied sheaf of wheat.»
- `goods/muka.png` — «…A plump cloth sack of flour, top rolled open
  showing white flour.»
- `goods/vodka.png` — «…A green glass shtof bottle (squat square
  Russian spirits bottle) with a cork.»

## Портреты — 1024×1024, тёмный нейтральный фон

Общее продолжение промпта:

> A waist-up parsuna-style portrait of an early 18th-century Russian
> character, three-quarter turn, dark neutral engraved background,
> serious face with individual features, hands visible.

По 1 генерации на файл; вариации внутри роли делай разными лицами
(возраст, борода, худоба) — модель сама разнообразит, если попросить
«a different person than before».

- `portraits/podyachy_1.png`, `podyachy_2.png` — «…A podyachy
  government clerk: ink-stained fingers, a quill behind the ear, a
  bundle of paper scrolls pressed to the chest, a plain dark kaftan,
  sly tired eyes.»
- `portraits/kupets_1.png`, `kupets_2.png`, `kupets_3.png` — «…A
  bearded Russian merchant: a fur-trimmed coat over a kaftan, a heavy
  money pouch in one hand, confident well-fed face.»
- `portraits/prikazchik_1.png`, `prikazchik_2.png` — «…A factory
  steward (prikazchik): a practical plain kaftan, a tally board and
  keys at the belt, sharp attentive face.»
- `portraits/master_1.png`, `master_2.png` — «…A foundry master
  craftsman: a leather apron over a linen shirt, soot on the hands and
  brow, strong forearms, calm proud face.»
- `portraits/starosta_1.png`, `starosta_2.png` — «…A village elder
  (starosta): a grey beard, a simple homespun coat, a walking staff,
  weathered patient face.»
- `portraits/officer_1.png` — «…A Petrine army officer: a green
  European-style uniform coat with brass buttons, a tricorn hat under
  the arm, powdered wig, stern face.»

## Хром интерфейса

### `chrome/paper_frame.png` — 1024×1024, прозрачный фон

> A blank sheet of aged parchment paper with slightly ragged darkened
> edges, subtle stains, photographed flat. The CENTER of the sheet must
> be a uniform even parchment tone with no stains or texture features —
> the image will be stretched as a 9-patch with 96-pixel borders (в
> масштабе 1024: однородный центр начиная примерно с 25% от краёв).
> Transparent background outside the sheet.

### `chrome/seal.png` — 1024×1024, прозрачный фон

> A round red-brown wax seal with an embossed monogram letter «Д»
> (Cyrillic De) in the center, slightly irregular molten edges, small
> highlight. Transparent background. (Единственное исключение из
> правила «без текста» — одна буква Д.)

## Чек-лист приёмки каждого ассета

- [ ] Имя файла и папка точно из этой спеки
- [ ] Нет текста/букв (кроме «Д» на печати)
- [ ] Прозрачность там, где указана (проверь шахматку в просмотрщике)
- [ ] Стиль совпадает с уже принятыми ассетами (тёплый пергамент+сепия)
- [ ] Положил файл → перезапустил игру → фолбэк заменился картинкой
