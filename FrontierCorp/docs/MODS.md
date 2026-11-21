# Моды для Project Aloverdoz / Modding guide

Мод — это папка в `mods/` рядом с игрой (в Steam-версии — в папке данных игрока: `%APPDATA%\Godot\app_userdata\<игра>\mods`).
Внутри — `mod.json` и файлы данных в том же формате, что у самой игры. Скрипты `.gd` из чужих модов не загружаются: только данные, картинки, звуки и модели `.glb`.

Проще всего начать из игры: «Моды» → конструктор (здания, предметы, модели) или редактор FrontierEditor → «Создать мод».

## Что можно добавить

| Что | Файл | Как |
|---|---|---|
| Предмет, руда, слиток | `items.json` | `{"my_ore": {"name": "Кобальтовая руда", "name_en": "Cobalt ore", "color": "#3a6aff", ...}}` |
| Залежь руды на карте | `world.json` | `{"deposits_add": [{"item": "my_ore", "resource": "ore_iron", "patches": 20, ...}]}` |
| Здание | `buildings.json` | новый id; поведение (`behavior`) — любое из существующих: miner, crafter, furnace, turret, chest… |
| Здание в дерево открытий | `tech.json` | `{"t_mining": {"_patch": true, "unlocks": {"buildings_add": ["my_building"]}}}` или свой узел с `tier` |
| Рецепт | `recipes.json` | `{"my_recipe": {"stations": ["workshop"], "in": {...}, "out": {...}, "time": 2}}` |
| Монстр | `enemies.json` | `"spawn_weight": 5` — сам приходит в волны начиная с `from_day`; `name_en` — английское имя |
| Модель героя | `models.json` | модель с `"category": "Герои"` появится в «Герой» главного меню |
| Модель из Blender | `models/*.glb` + `models.json` | `{"my_model": {"glb": "models/my.glb"}}` |
| Звуки, музыка | `sounds.json`, `music.json` | файлы `.ogg/.wav` в папке мода |
| Событие мира | `events.json` | кислотный дождь, метеориты и т. п. — смотрите `core/events.json` |
| Кнопка меню, совет | `menu.json` | `{"tips_add": [{"text": "Мой совет"}]}` |

## Правила слияния

- Объект с тем же id **заменяет** объект игры. `"_patch": true` — **дополняет** (меняются только указанные поля). `"_delete": true` — убирает.
- Любой список можно **дописать**, а не заменить: ключ с окончанием `_add` (`deposits_add`, `groups_add`, `buildings_add`, `tips_add`).
- Моды грузятся по порядку из окна «Моды»; более поздний мод главнее.

## Перевод / Translation

Игра написана по-русски, английский включается флагом в главном меню. Мод может перевести свои тексты двумя способами:

1. Поля `name_en`, `desc_en`, `text_en` рядом с `name`, `desc`, `text` у любого объекта.
2. Файл `lang.json`: `{"en": {"Мой текст": "My text", "Добыто: %d": "Mined: %d"}}`. Строки с `%d`, `%s`, `{ключ}` работают как шаблоны.

The game is authored in Russian; English is switched by the flag in the main menu. A mod translates its texts with `name_en` / `desc_en` fields or a `lang.json` file (`{"en": {"Russian text": "English text"}}`).

## Поделиться

Конструктор модов → «Упаковать мод в один файл .fcmod» (обычный zip). Друг кладёт файл в папку обмена (`mods_share`) и нажимает «Забрать моды».
