extends Node
## База контента (автозагрузка «DB»).
##
## Слои контента, каждый следующий может добавить, заменить ("_patch": true — дополнить)
## или удалить ("_delete": true) объекты предыдущего:
##   Редактор:        res://core  →  projects/<игра>/  →  её дополнения (dlc)  →  моды
##   Собранная игра:  контент игры (content.zip)  →  дополнения из папки dlc  →  моды игроков
##
## Папки projects, builds, mods, runtime лежат рядом с программой.

const DICT_TYPES := ["items", "resources", "recipes", "buildings", "categories", "skills", "enemies", "models", "animations", "sounds", "professions", "commands", "attributes", "texts", "quests", "tech", "contracts", "events", "factions"]
const SINGLE_TYPES := ["waves", "world", "settings", "levels", "ui", "music", "options", "menu"]
const TYPE_NAMES := {
	"items": "Предметы", "resources": "Ресурсы и флора", "recipes": "Рецепты", "buildings": "Здания",
	"categories": "Разделы меню", "skills": "Навыки", "enemies": "Монстры и НПС", "models": "Модели",
	"animations": "Анимации", "sounds": "Звуки", "waves": "Волны", "world": "Мир и генератор карты",
	"settings": "Правила игры", "levels": "Уровни", "ui": "Интерфейс", "music": "Музыка и фон",
	"options": "Меню настроек", "professions": "Профессии", "commands": "Команды консоли", "attributes": "Характеристики героя",
	"menu": "Главное меню и экраны", "texts": "Тексты и языки", "quests": "Задачи (обучение)", "tech": "Дерево открытий", "contracts": "Задания станции", "events": "События мира", "factions": "Группы НПС и репутация",
}

var data := {}
var layers: Array = []        # [{kind, id, path}] в порядке загрузки
var mods: Array = []          # [{id, name, version, author, desc, path, enabled}]
var dlcs: Array = []          # дополнения текущей игры
var errors: Array = []
var sources := {}             # "тип/id" -> откуда объект (core, project, dlc, mod)
var revision := 0
var use_mods := true          # редактор отключает моды, чтобы не смешивать их с игрой
var studio := true            # true — редактор, false — собранная игра
var project_id := "my_game"   # игра, открытая в редакторе
var project := {}             # project.json: name, version, changelog...
var edit_target := ""         # папка, куда редактор сохраняет правки
var mod_state := {}
var _mounted := false


var _base_override := ""
var saves_override := ""   # 1.0.9: выделенный сервер хранит миры рядом с собой (server.cfg → saves_dir)
var ov_keys := {}           # 1.0.9: ключи правил, которые сейчас задал сервер (server_settings.gd)

func _ready() -> void:
	studio = not OS.has_feature("game")
	if OS.has_feature("colony_suite"):
		studio = OS.get_executable_path().get_file().get_basename().to_lower() == "frontiereditor"
	# для проверок: запустить как собранную игру из папки сборки
	for a in OS.get_cmdline_user_args():
		if a == "--as-game":
			studio = false
		elif a.begins_with("--base-dir="):
			_base_override = a.substr(11)
	_load_state()
	load_all()


# ---------------------------------------------------------------- пути

func base_dir() -> String:
	if _base_override != "":
		return _base_override
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	return OS.get_executable_path().get_base_dir()


func _dir(name: String) -> String:
	# Steam-версия ничего не пишет в папку игры (её обновляет и проверяет Steam): моды и прочее — в папке игрока
	if OS.has_feature("steam") and _base_override == "":
		var u := ProjectSettings.globalize_path("user://").path_join(name)
		DirAccess.make_dir_recursive_absolute(u)
		return u
	var p := base_dir().path_join(name)
	if not DirAccess.dir_exists_absolute(p):
		if DirAccess.make_dir_recursive_absolute(p) != OK:
			p = ProjectSettings.globalize_path("user://").path_join(name)
			DirAccess.make_dir_recursive_absolute(p)
	return p


## Папка сохранений. У каждой собранной игры своя, чтобы игры не путали сохранения друг друга.
func saves_dir() -> String:
	if saves_override != "":
		DirAccess.make_dir_recursive_absolute(saves_override)
		return saves_override
	var p := "user://saves"
	if not studio:
		p = "user://games".path_join(game_name().validate_filename().replace(" ", "_")).path_join("saves")
	DirAccess.make_dir_recursive_absolute(p)
	return p


func mods_dir() -> String:
	return _dir("mods")


func projects_dir() -> String:
	return _dir("projects")


func builds_dir() -> String:
	return _dir("builds")


func project_path(id := "") -> String:
	return projects_dir().path_join(id if id != "" else project_id)


func runtime_exe() -> String:
	for n in ["Game.exe", "Game.x86_64", "Game"]:
		var p := base_dir().path_join("runtime").path_join(n)
		if FileAccess.file_exists(p):
			return p
	return ""


# ---------------------------------------------------------------- загрузка

func load_all() -> void:
	data = {}
	errors = []
	layers = []
	sources = {}
	for t in DICT_TYPES:
		data[t] = {}
	for t in SINGLE_TYPES:
		data[t] = {}
	data["lang"] = {}
	if not studio and not _mounted:
		_mounted = true
		_mount_content()
	if not studio and FileAccess.file_exists("res://game/project.json"):
		project = _read_json("res://game/project.json")
		_layer("game", "game", "res://game")
		dlcs = _scan(_packed_dirs("res://dlc"), "dlc")
	else:
		_layer("core", "core", "res://core")
		var pp := project_path()
		project = {"name": "Frontier Corp" if project_id == "my_game" else project_id.capitalize(), "version": "1.1.20"}
		if DirAccess.dir_exists_absolute(pp):
			var pj = _read_json(pp.path_join("project.json"))
			if pj is Dictionary:
				project.merge(pj, true)
			_layer("project", project_id, pp)
		dlcs = _scan(pp.path_join("dlc"), "dlc")
	for d in dlcs:
		if d.enabled or d.path == edit_target:
			_layer("dlc", d.id, d.path)
	mods = _scan(mods_dir(), "mod")
	for m in mods:
		# мод, который сейчас правится в редакторе, загружается всегда — иначе правки «пропадают»
		if (m.enabled and use_mods) or (studio and m.path == edit_target):
			_layer("mod", m.id, m.path)
	if edit_target == "" or not DirAccess.dir_exists_absolute(edit_target):
		edit_target = project_path()
	var balance_path := base_dir().path_join("balance.frontier.json")
	if not studio and FileAccess.file_exists(balance_path):
		var balance = _read_json(balance_path)
		var service := preload("res://scripts/balance_preset.gd")
		var problem := service.issue(balance)
		if problem == "":
			for table in service.TABLES:
				data[table] = balance.tables[table]
		else:
			errors.append("Пресет баланса · " + problem)
	UI.set_accent(Color.from_string(str(data.get("ui", {}).get("accent", "#ffa040")), UI.ACCENT))
	UI.set_style(data.get("ui", {}).get("theme", {}))
	revision += 1
	Lang.rebuild()


## Собранная игра: подключить контент и дополнения, лежащие рядом с .exe.
func _mount_content() -> void:
	var dir := base_dir()
	for f in ["content.zip", "content.pck"]:
		if FileAccess.file_exists(dir.path_join(f)):
			ProjectSettings.load_resource_pack(dir.path_join(f), true)
	var dd := DirAccess.open(dir.path_join("dlc"))
	if dd:
		for f in dd.get_files():
			if f.get_extension() in ["zip", "pck"]:
				ProjectSettings.load_resource_pack(dir.path_join("dlc").path_join(f), true)


func _packed_dirs(root: String) -> String:
	return root


func _layer(kind: String, id: String, path: String) -> void:
	layers.append({"kind": kind, "id": id, "path": path})
	_load_dir(path, "%s %s" % [kind, id])


func _scan(root: String, kind: String) -> Array:
	var out := []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for name in dir.get_directories():
		var p := root.path_join(name)
		var info := {"id": name, "name": name, "version": "1.0", "author": "", "desc": "", "order": 100, "kind": kind}
		var mj = _read_json(p.path_join("mod.json"))
		if mj is Dictionary:
			info.merge(mj, true)
		info["id"] = name
		info["path"] = p
		info["enabled"] = mod_state.get(kind + ":" + name, true)
		info["order"] = int(mod_state.get("order:%s:%s" % [kind, name], info.order))
		out.append(info)
	out.sort_custom(func(a, b): return a.order < b.order if a.order != b.order else a.id < b.id)
	return out


func _load_dir(path: String, source: String) -> void:
	for t in DICT_TYPES + SINGLE_TYPES:
		var f := path.path_join(t + ".json")
		if not FileAccess.file_exists(f):
			continue
		var v = _read_json(f)
		if v == null:
			errors.append("%s: не удалось прочитать %s.json (ошибка в JSON?)" % [source, t])
			continue
		if not v is Dictionary:
			errors.append("%s: %s.json должен быть объектом { }" % [source, t])
			continue
		if t in DICT_TYPES:
			for id in v:
				var obj = v[id]
				if obj is Dictionary and obj.get("_delete", false):
					data[t].erase(id)
				elif obj is Dictionary and obj.get("_patch", false) and data[t].has(id):
					_deep_merge(data[t][id], obj)
					sources[t + "/" + id] = source
				elif obj is Dictionary:
					data[t][id] = obj
					sources[t + "/" + id] = source
				else:
					errors.append("%s: %s/%s — ожидается объект" % [source, t, id])
		else:
			_deep_merge(data[t], v)
	# 1.3: перевод {"en": {"русский текст": "English text"}} — у ядра, игры, дополнений и модов
	var lf := path.path_join("lang.json")
	if FileAccess.file_exists(lf):
		var lv = _read_json(lf)
		if lv is Dictionary:
			_deep_merge(data["lang"], lv)
		else:
			errors.append("%s: lang.json должен быть объектом {\"en\": {...}}" % source)


func _deep_merge(a: Dictionary, b: Dictionary) -> void:
	for k in b:
		if k == "_patch":
			continue
		# 1.3: «ключ_add» дописывает в список, а не заменяет его — мод добавляет свою залежь
		# (world.json: {"deposits_add": [...]}), волну, кнопку меню или здание в узел дерева
		if str(k).ends_with("_add") and b[k] is Array:
			var base := str(k).substr(0, str(k).length() - 4)
			if a.has(base) and a[base] is Array:
				for x in b[k]:
					a[base].append(x.duplicate(true) if x is Dictionary or x is Array else x)
			else:
				a[base] = b[k].duplicate(true)
			continue
		if a.has(k) and a[k] is Dictionary and b[k] is Dictionary:
			_deep_merge(a[k], b[k])
		else:
			a[k] = b[k]


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var txt := FileAccess.get_file_as_string(path)
	var j := JSON.new()
	if j.parse(txt) != OK:
		errors.append("%s: строка %d — %s" % [path.get_file(), j.get_error_line(), j.get_error_message()])
		return null
	return j.data


## Найти файл (картинку, звук, модель) по относительному пути:
## ищем в слоях с конца — мод может заменить файл игры.
func find_file(rel: String) -> String:
	for i in range(layers.size() - 1, -1, -1):
		var p: String = layers[i].path.path_join(rel)
		if FileAccess.file_exists(p):
			return p
	return edit_target.path_join(rel)


# ---------------------------------------------------------------- доступ

func get_type(t: String) -> Dictionary:
	return data.get(t, {})


func item(id: String) -> Dictionary:
	return data.items.get(id, {})


func item_name(id: String) -> String:
	if discovery and not is_known(id):
		return "Неизвестный ресурс"
	return data.items.get(id, {}).get("name", id)


func item_color(id: String) -> Color:
	return Color.from_string(str(data.items.get(id, {}).get("color", "#ffffff")), Color.WHITE)


## Жидкость: течёт по трубам, на ленты и в рюкзак не попадает (поле «Жидкость» у предмета).
func is_fluid(id: String) -> bool:
	return bool(data.items.get(id, {}).get("fluid", false))


func stack_of(id: String) -> int:
	return int(data.items.get(id, {}).get("stack", 50))


func building(id: String) -> Dictionary:
	return data.buildings.get(id, {})


func bparam(id: String, key: String, def = null):
	return data.buildings.get(id, {}).get("params", {}).get(key, def)


func setting(key: String, def = null):
	# 1.0.9: правило, заданное сервером (комнатой), важнее личной настройки игрока
	if Prefs.has(key) and not ov_keys.has(key):
		return Prefs.get_value(key, def)
	return data.settings.get(key, def)


## Перевод текста. "@id" — взять из «Тексты и языки» на языке игрока (иначе по-русски).
## Обычный текст возвращается как есть. vars подставляются вместо {ключ}.
func t(s, vars := {}) -> String:
	var out := str(s)
	if out.begins_with("@"):
		var e = data.get("texts", {}).get(out.substr(1))
		if e is Dictionary:
			var lang := str(Prefs.get_value("language", "ru"))
			out = str(e.get(lang, e.get("ru", out.substr(1))))
		else:
			out = out.substr(1)
	for k in vars:
		out = out.replace("{%s}" % k, str(vars[k]))
	return out


## То же для ключа без «@»: DB.tx("st_kills", "Монстров убито").
func tx(id: String, def := "") -> String:
	var e = data.get("texts", {}).get(id)
	if e is Dictionary:
		var lang := str(Prefs.get_value("language", "ru"))
		return str(e.get(lang, e.get("ru", def)))
	return def if def != "" else id


func menu(key: String, def = null):
	return data.get("menu", {}).get(key, def)


## Что ещё не открыто в дереве открытий: "b:здание", "r:рецепт", "d:предмет месторождения" -> узел. Пусто в редакторе.
var locked := {}


func station_recipe_open(id: String, station: String) -> bool:
	return station in data.recipes.get(id,{}).get("stations",[]) and not locked.has("r:"+id) and recipe_known(id)

func recipes_for(station: String) -> Array:
	var out := []
	var strat := bool(setting("strategy", false))
	for id in data.recipes:
		if station_recipe_open(id,station):
			if strat and personal_recipe(id):
				continue
			out.append(id)
	return out


## 1.1.16: вещи только для героя (оружие, еда, питьё, аптечки, одежда, стимуляторы, подколы).
## В «Стратегии» их нет: не крафтятся, не падают, не лежат в рюкзаке. Кирки и топоры остаются.
const PERSONAL_IDS := ["grenade", "recall", "gas_mask", "antirad", "acid_umbrella", "decon_spray", "stimulant"]
const PERSONAL_BUILDINGS := ["medbay", "garden_bed"]

func personal_item(id: String) -> bool:
	var it: Dictionary = data.items.get(id, {})
	if it.is_empty() or it.has("tool"):
		return false
	if it.has("weapon") or it.has("clothes") or it.has("boost") or str(it.get("category", "")) == "Подколы":
		return true
	if float(it.get("food", 0)) > 0.0 or float(it.get("heal", 0)) > 0.0:
		return true
	if float(it.get("water", 0)) > 0.0 and str(it.get("category", "")) == "Еда":
		return true
	return id in PERSONAL_IDS


func personal_recipe(rid: String) -> bool:
	var outs: Dictionary = data.recipes.get(rid, {}).get("out", {})
	if outs.is_empty():
		return false
	for o in outs:
		if not personal_item(o):
			return false
	return true


## 18: рецепты станции, скрытые только потому, что не изучено сырьё → {"n": сколько, "need": {предмет: true}}.
func hidden_by_scan(station: String) -> Dictionary:
	var n := 0
	var need := {}
	if not discovery:
		return {"n": 0, "need": need}
	for id in data.recipes:
		if station in data.recipes[id].get("stations", []) and not locked.has("r:" + id) and not recipe_known(id):
			n += 1
			for k in data.recipes[id].get("in", {}):
				if not is_researched(k) and is_known(k):
					need[k] = true
	return {"n": n, "need": need}


# ---------------------------------------------------------------- 13.10: находки и сканирование
## Пока ресурс не найден, игрок не знает о нём (имя «Неизвестный ресурс», в торговле и меню его нет).
## Найденный, но не отсканированный ресурс нельзя использовать в рецептах: его надо отсканировать N штук
## (поле предмета «Сканировать штук»). В редакторе всё открыто.
var discovery := false
var known := {}         # id -> true: игрок держал этот предмет
var researched := {}    # id -> true: отсканирован


func scan_need(id: String) -> int:
	return int(item(id).get("scan", 0))


func is_known(id: String) -> bool:
	return not discovery or known.has(id) or not data.items.has(id) or str(item(id).get("category", "")) == "Жидкости"


func is_researched(id: String) -> bool:
	if not discovery or researched.has(id) or not data.items.has(id):
		return true
	return is_known(id) and scan_need(id) <= 0


## Рецепт виден, когда все его входы изучены.
func recipe_known(rid: String) -> bool:
	if data.recipes.get(rid, {}).get("basic_process", false): return true
	if not discovery:
		return true
	for k in data.recipes.get(rid, {}).get("in", {}):
		if not is_researched(k):
			return false
	return true


## Цена (здания, расширения) из изученных предметов?
func cost_known(cost: Dictionary) -> bool:
	if not discovery:
		return true
	for k in cost:
		if not is_researched(k):
			return false
	return true


## 1.0.8: какие предметы цены ещё не изучены в сканере (по порядку цены).
func scan_missing(cost: Dictionary) -> Array:
	var out := []
	if not discovery:
		return out
	for k in cost:
		if not is_researched(k):
			out.append(k)
	return out


func color(v, def := Color.WHITE) -> Color:
	if v is Color:
		return v
	if v is String:
		# «@имя» — цвет из палитры («Настройки» → «Палитра персонажей»): поменяли там — поменялось везде
		if v.begins_with("@"):
			var pal = data.get("settings", {}).get("palette", {})
			if pal is Dictionary and pal.has(v.substr(1)):
				return Color.from_string(str(pal[v.substr(1)]), def)
			return def
		return Color.from_string(v, def)
	if v is Array and v.size() >= 3:
		return Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0)
	return def


func game_name() -> String:
	return str(project.get("name", "Frontier Corp"))


## 1.3: название игры для игрока (меню, заставка, панель): «Название» в главном меню, иначе название окна.
## game_name() остаётся внутренним (папки сохранений, поиск комнат) — его не трогаем, чтобы не потерять сохранения.
func display_name() -> String:
	var nm := str(t(menu("title", "")))
	if nm == "":
		nm = window_title()
	return nm


## Заголовок окна игры («Главное меню» → «Название окна»).
func window_title() -> String:
	var t := str(menu("window_title", ""))
	return t if t != "" else game_name()


func game_version() -> String:
	return str(project.get("version", "1.1.20"))


# ---------------------------------------------------------------- сохранение (редактор)

func ensure_dir_info(path: String, info: Dictionary, file := "mod.json") -> String:
	DirAccess.make_dir_recursive_absolute(path)
	var mj := path.path_join(file)
	if not FileAccess.file_exists(mj):
		_write_json(mj, info)
	return path


## Записывает объект (или раздел настроек целиком) в папку правок и в память.
func save_object(t: String, id: String, value) -> void:
	var p := edit_target
	if p == project_path():
		ensure_dir_info(p, {"name": project_id, "version": "1.0", "changelog": ""}, "project.json")
	DirAccess.make_dir_recursive_absolute(p)
	var f := p.path_join(t + ".json")
	var cur = _read_json(f)
	if not cur is Dictionary:
		cur = {}
	if t in DICT_TYPES:
		if value == null:
			cur[id] = {"_delete": true}
			data[t].erase(id)
		else:
			var stored = value
			# дополнение и мод хранят только свои изменения чужих объектов (обновления игры не затираются)
			if editing_addon() and value is Dictionary:
				var base: Dictionary = _base_without_target(t)
				if base.has(id) and base[id] is Dictionary:
					stored = diff(base[id], value)
					stored["_patch"] = true
			if stored is Dictionary and stored.get("_patch", false) and stored.size() == 1:
				cur.erase(id)
			else:
				cur[id] = stored
			data[t][id] = value
	else:
		if editing_addon() and value is Dictionary:
			cur = diff(_base_without_target(t), value)
		else:
			cur = value
		data[t] = value
	_write_json(f, cur)
	revision += 1


## ---------------------------------------------------------------- каталог готового контента (только в редакторе)
const CATALOG_TYPES := ["items", "buildings", "resources", "models", "recipes"]
var catalog := {}


## Каталог грузится при первом обращении: предметы, здания, растения, модели и рецепты, которые можно взять в игру.
func catalog_data() -> Dictionary:
	if catalog.is_empty():
		for t in CATALOG_TYPES:
			var v = _read_json("res://catalog/%s.json" % t) if studio else null
			catalog[t] = v if v is Dictionary else {}
	return catalog


## Модель по id: из игры, а в редакторе — ещё и из каталога (для просмотра).
func model_def(id: String) -> Dictionary:
	if data.get("models", {}).has(id):
		return data.models[id]
	if studio and not id.is_empty():
		return catalog_data().models.get(id, {})
	return {}


## Взять объект из каталога в свою игру вместе со всем, что ему нужно (модель, рецепты, материалы, станции).
## Возвращает список добавленного: ["items/bread", "recipes/cook_bread", ...]. Уже существующее не трогается.
func add_from_catalog(t: String, id: String, added: Array = []) -> Array:
	var key := t + "/" + id
	if key in added or id.is_empty():
		return added
	if data.get(t, {}).has(id):
		return added
	var src = catalog_data().get(t, {}).get(id)
	if not src is Dictionary:
		return added
	added.append(key)
	var v: Dictionary = src.duplicate(true)
	v.erase("catalog")
	save_object(t, id, v)
	var c := catalog_data()
	match t:
		"items":
			add_from_catalog("models", str(v.get("model", "")), added)
			for rid in c.recipes:
				if c.recipes[rid].get("out", {}).has(id):
					add_from_catalog("recipes", rid, added)
		"recipes":
			for i in v.get("in", {}):
				add_from_catalog("items", i, added)
			for i in v.get("out", {}):
				add_from_catalog("items", i, added)
			for st in v.get("stations", []):
				if st == "hand" or _has_station(st):
					continue
				for bid in c.buildings:
					if str(c.buildings[bid].get("params", {}).get("station", "")) == st:
						add_from_catalog("buildings", bid, added)
						break
		"buildings":
			add_from_catalog("models", str(v.get("model", "")), added)
			for i in v.get("cost", {}):
				add_from_catalog("items", i, added)
			for f in v.get("params", {}).get("fuels", []):
				add_from_catalog("items", str(f), added)
			for b in v.get("blocks", []):
				if b is Dictionary:
					add_from_catalog("items", str(b.get("item", "")), added)
					for k in ["in", "out"]:
						for i in b.get(k, {}):
							add_from_catalog("items", i, added)
		"resources":
			add_from_catalog("models", str(v.get("model", "")), added)
			for d in v.get("drops", []):
				add_from_catalog("items", str(d.get("item", "")), added)
			if str(v.get("stump", "")) != "":
				add_from_catalog("resources", str(v.stump), added)
	return added


func _has_station(st: String) -> bool:
	for bid in data.buildings:
		if str(data.buildings[bid].get("params", {}).get("station", "")) == st:
			return true
	return false


## Убрать правку объекта из папки правок (вернуть как было в игре или ядре).
func revert_object(t: String, id: String) -> void:
	var f := edit_target.path_join(t + ".json")
	var cur = _read_json(f)
	if cur is Dictionary:
		if t in DICT_TYPES:
			cur.erase(id)
		else:
			cur = {}
		_write_json(f, cur)
	load_all()


func source_of(t: String, id: String) -> String:
	return str(sources.get(t + "/" + id, ""))


var write_failed := ""   # B-1 r7: последний файл, который не удалось записать


func _write_json(path: String, v) -> void:
	# B-2 r6: пишем во временный файл и подменяем — оборванная запись не портит прежний файл
	var tmp := path + ".tmp"
	var fa := FileAccess.open(tmp, FileAccess.WRITE)
	if fa == null:
		fa = FileAccess.open(path, FileAccess.WRITE)
		if fa:
			fa.store_string(JSON.stringify(v, " ", false))
		return
	var txt := JSON.stringify(v, " ", false)
	fa.store_string(txt)
	var bad := fa.get_error() != OK
	fa.close()
	# B-1 r7: запись оборвалась (нет места на диске) — прежний файл остаётся целым
	if bad or FileAccess.get_file_as_bytes(tmp).size() != txt.to_utf8_buffer().size():
		DirAccess.remove_absolute(tmp)
		write_failed = path
		push_warning("Не удалось записать %s — не хватает места на диске?" % path)
		return
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(path)
		if DirAccess.rename_absolute(tmp, path) != OK:
			DirAccess.copy_absolute(tmp, path)
			DirAccess.remove_absolute(tmp)


func write_file(path: String, v) -> void:
	_write_json(path, v)


func read_file(path: String):
	return _read_json(path)


func save_project_info(info: Dictionary) -> void:
	project.merge(info, true)
	ensure_dir_info(project_path(), {}, "project.json")
	_write_json(project_path().path_join("project.json"), project)


## Поменять название или версию дополнения или мода (файл mod.json).
func update_addon_info(path: String, info: Dictionary) -> void:
	var f := path.path_join("mod.json")
	var cur = _read_json(f)
	if not cur is Dictionary:
		cur = {}
	cur.merge(info, true)
	_write_json(f, cur)


static func bump_version(v: String) -> String:
	var p := v.split(".")
	return "%d.%d" % [int(p[0]) if p.size() > 0 else 1, (int(p[1]) if p.size() > 1 else 0) + 1]


func list_projects() -> Array:
	var d := DirAccess.open(projects_dir())
	return Array(d.get_directories()) if d else []


func open_project(id: String) -> void:
	project_id = id
	edit_target = project_path()
	_save_state()
	load_all()


func set_enabled(kind: String, id: String, on: bool) -> void:
	mod_state[kind + ":" + id] = on
	_save_state()


## Меню «Моды»: поднять или опустить мод в порядке загрузки (позже загруженный главнее).
func move_mod(kind: String, id: String, delta: int) -> void:
	var lst: Array = _scan(mods_dir() if kind == "mod" else (project_path().path_join("dlc") if studio else "res://dlc"), kind)
	var ids: Array = lst.map(func(m): return m.id)
	var i := ids.find(id)
	var j := i + delta
	if i < 0 or j < 0 or j >= ids.size():
		return
	ids[i] = ids[j]
	ids[j] = id
	for k in ids.size():
		mod_state["order:%s:%s" % [kind, ids[k]]] = k * 10
	_save_state()


func _save_state() -> void:
	var cfg := ConfigFile.new()
	for k in mod_state:
		cfg.set_value("enabled", k.replace(":", "__"), mod_state[k])
	cfg.set_value("editor", "project", project_id)
	cfg.save("user://content.cfg")


func _load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://content.cfg") == OK:
		if cfg.has_section("enabled"):
			for k in cfg.get_section_keys("enabled"):
				mod_state[k.replace("__", ":")] = cfg.get_value("enabled", k)
		project_id = cfg.get_value("editor", "project", project_id)


# ---------------------------------------------------------------- сборка игры, дополнений и модов

## Собирает слитый контент (ядро + игра) в папку, без модов и дополнений.
func _merged_layers(upto_kind := "project") -> Dictionary:
	var keep_layers := layers
	var saved := data
	var saved_src := sources.duplicate()
	var saved_err := errors.duplicate()
	data = {}
	for t in DICT_TYPES:
		data[t] = {}
	for t in SINGLE_TYPES:
		data[t] = {}
	data["lang"] = {}
	for l in keep_layers:
		if l.kind in ["core", "game", "project"]:
			_load_dir(l.path, l.id)
	var merged := data
	data = saved
	sources = saved_src
	errors = saved_err
	return merged


## Значение без слоя, который сейчас правится (для дополнений и модов: что было бы без них).
func _base_without_target(t: String) -> Dictionary:
	var saved := data
	var saved_src := sources.duplicate()
	var saved_err := errors.duplicate()
	data = {}
	for k in DICT_TYPES + SINGLE_TYPES:
		data[k] = {}
	data["lang"] = {}
	for l in layers:
		if l.path != edit_target:
			_load_dir(l.path, l.id)
	var out: Dictionary = data[t]
	data = saved
	sources = saved_src
	errors = saved_err
	return out


## Что изменилось в b по сравнению с a (вложенные разделы — тоже только изменения).
static func diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for k in b:
		if not a.has(k):
			out[k] = b[k]
		elif a[k] is Dictionary and b[k] is Dictionary:
			var d := diff(a[k], b[k])
			if not d.is_empty():
				out[k] = d
		elif str(a[k]) != str(b[k]):
			out[k] = b[k]
	return out


## Идёт правка дополнения или мода (а не самой игры).
func editing_addon() -> bool:
	return edit_target != project_path() and edit_target != ""


## Кнопка «Собрать игру»: готовая игра без редактора в builds/<игра>_v<версия>/.
## Возвращает {ok, path, msg}.
func build_game(changelog := "") -> Dictionary:
	var exe := runtime_exe()
	if exe == "":
		return {"ok": false, "msg": "Не найден движок игры (папка runtime рядом с редактором). Распакуйте архив редактора целиком."}
	var name := game_name().validate_filename().replace(" ", "_")
	var out := builds_dir().path_join("%s_v%s" % [name, game_version()])
	DirAccess.make_dir_recursive_absolute(out.path_join("dlc"))
	DirAccess.make_dir_recursive_absolute(out.path_join("mods"))
	var ext := exe.get_extension()
	var dst := out.path_join(name + ("." + ext if ext != "" else ""))
	if DirAccess.copy_absolute(exe, dst) != OK:
		return {"ok": false, "msg": "Не удалось скопировать движок в " + dst}
	if ext == "" or ext == "x86_64":
		OS.execute("chmod", ["+x", dst])
	var merged := _merged_layers()
	var zip := ZIPPacker.new()
	if zip.open(out.path_join("content.zip")) != OK:
		return {"ok": false, "msg": "Не удалось создать content.zip"}
	for t in merged:
		_zip_text(zip, "game/%s.json" % t, JSON.stringify(merged[t], " ", false))
	var info := project.duplicate()
	info["built"] = Time.get_datetime_string_from_system()
	info["changelog"] = changelog if changelog != "" else str(project.get("changelog", ""))
	_zip_text(zip, "game/project.json", JSON.stringify(info, " ", false))
	# картинки, звуки, модели и карты игры
	if DirAccess.dir_exists_absolute(project_path()):
		_zip_dir(zip, project_path(), "game", ["dlc"], ["json"])
	zip.close()
	_write_text(out.path_join("ЧИТАЙ_МЕНЯ.txt"), "%s, версия %s\n\nЗапуск: %s\nПапка dlc — сюда кладутся дополнения (.zip).\nПапка mods — моды игроков.\n\nИзменения:\n%s\n" % [game_name(), game_version(), dst.get_file(), info.changelog])
	return {"ok": true, "path": out, "msg": "Игра собрана: " + out}


## Кнопка «Собрать дополнение»: один файл для папки dlc собранной игры.
func build_dlc(id: String) -> Dictionary:
	var src := project_path().path_join("dlc").path_join(id)
	if not DirAccess.dir_exists_absolute(src):
		return {"ok": false, "msg": "Нет дополнения " + id}
	var name := game_name().validate_filename().replace(" ", "_")
	var out_dir := builds_dir().path_join("%s_DLC" % name)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var info = _read_json(src.path_join("mod.json"))
	var ver: String = str(info.get("version", "1.0")) if info is Dictionary else "1.0"
	var out := out_dir.path_join("%s_v%s.zip" % [id, ver])
	var zip := ZIPPacker.new()
	if zip.open(out) != OK:
		return {"ok": false, "msg": "Не удалось создать " + out}
	_zip_dir(zip, src, "dlc/" + id)
	zip.close()
	return {"ok": true, "path": out, "msg": "Дополнение собрано: %s\nПоложите этот файл в папку dlc собранной игры." % out}


## Мод (для игроков): обычный zip с папкой мода.
func pack_mod(id: String) -> Dictionary:
	var src := mods_dir().path_join(id)
	var out_dir := _dir("mods_export")
	var info = _read_json(src.path_join("mod.json"))
	var ver: String = str(info.get("version", "1.0")) if info is Dictionary else "1.0"
	var out := out_dir.path_join("%s_v%s.zip" % [id, ver])
	var zip := ZIPPacker.new()
	if zip.open(out) != OK:
		return {"ok": false, "msg": "Не удалось создать " + out}
	_zip_dir(zip, src, id)
	zip.close()
	return {"ok": true, "path": out, "msg": "Мод упакован: " + out}


const _TR := {"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z", "и": "i", "й": "y",
	"к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h",
	"ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya"}


## Латинский id из русского названия: «Мой взрыв» → moy_vzryv.
static func latin_id(nm: String) -> String:
	var out := ""
	for ch in nm.to_lower():
		if _TR.has(ch):
			out += _TR[ch]
		elif (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		else:
			out += "_"
	while "__" in out:
		out = out.replace("__", "_")
	out = out.strip_edges().trim_prefix("_").trim_suffix("_")
	if out != "" and out[0] >= "0" and out[0] <= "9":
		out = "s_" + out
	return out


## Имя папки из названия (одно правило для игр, дополнений и модов).
static func make_id(nm: String) -> String:
	return nm.strip_edges().validate_filename().replace(" ", "_").to_lower()


## Свободное имя папки: если занято — добавляем _2, _3...
static func unique_id(root: String, id: String) -> String:
	var out := id
	var i := 2
	while DirAccess.dir_exists_absolute(root.path_join(out)):
		out = "%s_%d" % [id, i]
		i += 1
	return out


## Кнопка «Открыть сборку»: загрузить собранную игру в редактор как проект.
func open_build(build_dir: String) -> Dictionary:
	var cz := build_dir.path_join("content.zip")
	var r := ZIPReader.new()
	if r.open(cz) != OK:
		return {"ok": false, "msg": "В папке нет content.zip — это не сборка игры"}
	var pj = JSON.parse_string(r.read_file("game/project.json").get_string_from_utf8()) if r.file_exists("game/project.json") else {}
	# сборка открывается в НОВУЮ папку — текущая работа никогда не перезаписывается
	var nm := str(pj.get("name", "game")) if pj is Dictionary else "game"
	var ver := str(pj.get("version", "1.0")) if pj is Dictionary else "1.0"
	var id := unique_id(projects_dir(), "%s_v%s" % [make_id(nm), ver.replace(".", "_")])
	var dst := project_path(id)
	for f in r.get_files():
		if not f.begins_with("game/") or f.ends_with("/"):
			continue
		var rel := f.substr(5)
		var path := safe_join(dst, rel)
		if path == "":
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var fa := FileAccess.open(path, FileAccess.WRITE)
		if fa:
			fa.store_buffer(r.read_file(f))
	r.close()
	# дополнения, лежащие в сборке, тоже возвращаем в проект
	var dd := DirAccess.open(build_dir.path_join("dlc"))
	if dd:
		for f in dd.get_files():
			if f.get_extension() == "zip":
				_unzip_prefix(build_dir.path_join("dlc").path_join(f), "dlc/", dst.path_join("dlc"))
	open_project(id)
	return {"ok": true, "msg": "Сборка открыта как проект «%s». Поднимите версию и соберите обновление." % id}


## A-2 r6: путь из архива внутри папки dst ("" — если он уводит наружу: «..», «\», абсолютный, «C:»).
static func safe_join(dst: String, rel: String) -> String:
	rel = rel.replace("\\", "/")
	if rel == "" or rel.begins_with("/") or ":" in rel or ".." in rel.split("/"):
		return ""
	var base := dst.simplify_path()
	var to := base.path_join(rel).simplify_path()
	return to if to.begins_with(base + "/") else ""


func _unzip_prefix(zip_path: String, prefix: String, dst: String) -> void:
	var r := ZIPReader.new()
	if r.open(zip_path) != OK:
		return
	for f in r.get_files():
		if not f.begins_with(prefix) or f.ends_with("/"):
			continue
		var path := safe_join(dst, f.substr(prefix.length()))
		if path == "":
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var fa := FileAccess.open(path, FileAccess.WRITE)
		if fa:
			fa.store_buffer(r.read_file(f))
	r.close()


func install_mod_zip(zip_path: String) -> String:
	var r := ZIPReader.new()
	if r.open(zip_path) != OK:
		return ""
	var first := ""
	for f in r.get_files():
		var dest := safe_join(mods_dir(), f)
		if dest == "":
			continue
		if f.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(dest)
			continue
		if first == "":
			first = f.split("/")[0]
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var fa := FileAccess.open(dest, FileAccess.WRITE)
		if fa:
			fa.store_buffer(r.read_file(f))
	r.close()
	return first


func _zip_text(zip: ZIPPacker, name: String, txt: String) -> void:
	zip.start_file(name)
	zip.write_file(txt.to_utf8_buffer())
	zip.close_file()


func _write_text(path: String, txt: String) -> void:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa:
		fa.store_string(txt)


func _zip_dir(zip: ZIPPacker, path: String, rel: String, skip_dirs := [], skip_ext := []) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension() in skip_ext and rel.count("/") == 0:
			continue
		zip.start_file(rel.path_join(f))
		zip.write_file(FileAccess.get_file_as_bytes(path.path_join(f)))
		zip.close_file()
	for sub in d.get_directories():
		if sub in skip_dirs:
			continue
		_zip_dir(zip, path.path_join(sub), rel.path_join(sub), [], [])
