extends RefCounted
## 1.0.9: настройки сервера (сетевой комнаты). Почти все правила игры из редактора («Настройки», «Волны», «Мир»,
## «События»), которые имеют смысл для одного мира, можно поменять при создании комнаты или в server.cfg выделенного сервера.
## Подписи, виды полей и подсказки берутся из схемы редактора (scripts/editor/schema.gd) — список ниже только
## говорит, какие поля показывать и в какой вкладке.
##
## Путь поля: «тип/ключ[/подключ]», например settings/hunger_rate, waves/interval, settings/death/mode, events/meteor_shower/chance.
##   «тип/группа/*» — все простые поля группы (да/нет, числа, выбор из списка);  «events/*/chance» — шанс каждого события.
## Изменённые значения хранятся в комнате (room.ov) и применяются к DB.data у хозяина и у каждого гостя, пока идёт мир
## (main.gd: apply в начале _ready, restore при выходе), поэтому все считают игру по одинаковым правилам.

const Schema = preload("res://scripts/editor/schema.gd")

const TABS := [
	["Монстры и волны", ["settings/difficulty", "waves/first_delay", "waves/interval", "waves/interval_min", "waves/interval_step",
		"waves/base_count", "waves/growth", "waves/night_mult", "waves/hp_growth", "waves/spawn_dist",
		"waves/roaming/*", "waves/sieges/*", "waves/rush/base_count", "waves/rush/count_growth", "waves/rush/hp_growth",
		"waves/rush/dmg_growth", "waves/rush/max_count", "waves/rush/max_alive", "settings/bosses/*",
		"settings/monster_chase_time", "settings/monster_calm_time", "settings/monster_escape_dist", "settings/monster_escape_time",
		"settings/monster_attack_buildings", "settings/monster_building_cells", "settings/maze_radius",
		"settings/pollution_k", "settings/pollution_cap", "settings/dungeons/*"]],
	["Экономика", ["world/start_credits", "settings/coop/start_credits", "settings/world_bonus/sell",
		"settings/market_recover", "settings/market_sell_drop",
		"settings/econ_abundance", "settings/econ_abundance_top", "settings/econ_abundance_drop", "settings/econ_abundance_min",
		"settings/order_check", "settings/order_spread", "settings/order_max_ratio", "settings/order_life",
		"settings/rep_trade", "settings/rep_gift_per", "settings/npc_max", "settings/npc_return_chance", "settings/npc_rel_hurt",
		"settings/daily/*", "settings/milestones/*", "settings/ufo/*"]],
	["Производство", ["settings/world_bonus/gather", "settings/world_bonus/craft_speed", "settings/world_bonus/machine_speed",
		"settings/world_bonus/build_cost", "settings/world_bonus/build_hp", "settings/belt_speed",
		"settings/big_buildings", "settings/power_mode", "settings/belt_spill_pct", "settings/hq_transfer", "settings/hq_station_radius", "settings/auto_wire", "settings/wire_length", "settings/wire_machines", "settings/fuses", "settings/fuse_delay",
		"settings/power_constant", "settings/power_clock", "settings/wind_min", "settings/wind_max",
		"settings/tech_tree", "settings/tech_ui/free", "settings/scan/*", "settings/mastery/*", "settings/fusion/*", "settings/tuning/*",
		"settings/craft_queue_max", "settings/blueprint_max", "settings/need_flat", "settings/nodes_block_build",
		"settings/builders/*", "settings/drones/*"]],
	["Выживание", ["settings/player_hp", "settings/player_speed", "settings/player_sprint", "settings/jump_height",
		"settings/world_bonus/damage", "settings/world_bonus/max_hp", "settings/world_bonus/regen", "settings/world_bonus/xp",
		"settings/world_bonus/move", "settings/world_bonus/hunger",
		"settings/hunger_rate", "settings/thirst_rate", "settings/starve_damage", "settings/death/*", "settings/bag/*",
		"settings/drop_lifetime", "settings/pickup_radius", "settings/wade", "settings/wade_speed", "settings/climb_roofs", "settings/climb_roof_max",
		"settings/physics/*"]],
	["Мир и погода", ["world/day_length", "settings/climate/*", "settings/zone/*", "settings/fog_reveal_radius", "settings/fog_start_radius",
		"world/biome_scale", "world/forest", "world/dry", "world/rocky", "world/snow", "world/lakes", "world/rivers",
		"world/relief", "world/hills", "world/deposit_rock_chance", "world/start_clear_radius", "world/start_flat_radius", "world/wrap"]],
	["События и опасности", ["events/*/chance", "settings/radiation/*", "settings/acid/*", "settings/quantum/*"]],
	["Сервер", ["settings/coop/autosave_min", "settings/coop/near_dist", "settings/coop/far_dist", "settings/coop/vote_time",
		"settings/coop/flag_radius", "settings/net_sync_every", "settings/net_chat_time", "settings/cheats"]],
]

## Поля групп, которые к правилам мира не относятся (оформление, звук, служебное).
## 1.3: главное о «Натиске» — сразу над вкладками (menu._room_rules), подробности — во вкладке «Монстры и волны».
const QUICK := ["settings/season_look", "waves/rush/enabled", "waves/rush/start_min", "waves/rush/every_min"]

const SKIP_SUB := ["cloud_height", "cloud_layers", "cloud_density", "cloud_far", "cloud_speed", "lightning_every", "flicker", "corner",
	"wobble", "shape_seed", "soft", "show_meter", "geiger", "warn_at", "ask", "ask_time", "show_temp", "hint_tech", "show_ruins",
	"height", "golden_min", "patch_cost_k"]

## Заготовки. Число — само значение; строка «*1.5» — во столько раз от обычного. modules — какие модули включить/выключить.
const PRESETS := {
	"Мирный": {"ov": {"settings/difficulty": 0.25, "settings/hunger_rate": "*0.3", "settings/thirst_rate": "*0.3",
		"settings/death/mode": "keep", "settings/death/lose_credits": 0.0, "settings/death/respawn_time": 2.0,
		"settings/world_bonus/gather": 0.75, "settings/world_bonus/craft_speed": 0.75, "settings/world_bonus/build_cost": -0.35,
		"world/start_credits": "*4", "settings/coop/start_credits": "*4"}, "modules": {"waves": false}},
	"Очень лёгкий": {"ov": {"settings/difficulty": 0.4, "waves/first_delay": "*2", "waves/interval": "*2", "waves/base_count": "*0.5",
		"waves/growth": "*0.5", "waves/hp_growth": "*0.4", "settings/hunger_rate": "*0.4", "settings/thirst_rate": "*0.4",
		"settings/death/mode": "keep", "settings/death/lose_credits": 0.0, "settings/death/respawn_time": 3.0,
		"settings/world_bonus/gather": 0.6, "settings/world_bonus/craft_speed": 0.6, "settings/world_bonus/build_cost": -0.3,
		"world/start_credits": "*3", "settings/coop/start_credits": "*3"}, "modules": {}},
	"Обычный": {"ov": {}, "modules": {}},
	"Лёгкий": {"ov": {"settings/difficulty": 0.6, "waves/first_delay": "*1.5", "waves/interval": "*1.5", "waves/base_count": "*0.6",
		"waves/growth": "*0.6", "waves/hp_growth": "*0.5", "settings/hunger_rate": "*0.5", "settings/thirst_rate": "*0.5",
		"settings/death/mode": "keep", "settings/death/lose_credits": 0.0, "settings/death/respawn_time": 3.0,
		"settings/world_bonus/gather": 0.5, "settings/world_bonus/craft_speed": 0.5, "settings/world_bonus/build_cost": -0.25,
		"world/start_credits": "*3", "settings/coop/start_credits": "*3"}, "modules": {}},
	"Хардкор": {"ov": {"settings/difficulty": 2.2, "waves/first_delay": "*0.5", "waves/interval": "*0.7", "waves/interval_min": "*0.7",
		"waves/base_count": "*1.5", "waves/growth": "*1.5", "waves/hp_growth": "*1.5", "settings/hunger_rate": "*1.5", "settings/thirst_rate": "*1.5",
		"settings/starve_damage": "*2", "settings/death/mode": "lose", "settings/death/lose_credits": 0.25, "settings/death/respawn_time": 15.0,
		"settings/world_bonus/sell": -0.25, "settings/world_bonus/build_cost": 0.25, "world/start_credits": 0, "settings/coop/start_credits": 0},
		"modules": {"survival": true, "climate": true, "hazards": true, "durability": true, "finite_ammo": true, "waves": true, "monsters": true}},
	"Сложный": {"ov": {"settings/difficulty": 1.5, "waves/first_delay": "*0.8", "waves/interval": "*0.85", "waves/base_count": "*1.2",
		"waves/growth": "*1.2", "waves/hp_growth": "*1.2", "settings/death/lose_credits": 0.15, "settings/world_bonus/build_cost": 0.1}, "modules": {}},
	"Безумие": {"ov": {"settings/difficulty": 3.0, "waves/first_delay": "*0.4", "waves/interval": "*0.55", "waves/interval_min": "*0.55",
		"waves/base_count": "*2", "waves/growth": "*2", "waves/hp_growth": "*2", "settings/hunger_rate": "*2", "settings/thirst_rate": "*2",
		"settings/starve_damage": "*2", "settings/death/mode": "lose", "settings/death/lose_credits": 0.4, "settings/death/respawn_time": 25.0,
		"settings/world_bonus/sell": -0.4, "settings/world_bonus/build_cost": 0.5, "world/start_credits": 0, "settings/coop/start_credits": 0,
		"waves/sieges/every_days": 3, "waves/sieges/first_day": 3},
		"modules": {"survival": true, "climate": true, "hazards": true, "durability": true, "finite_ammo": true, "waves": true, "monsters": true}},
	"Песочница": {"ov": {"world/start_credits": 100000, "settings/coop/start_credits": 100000, "settings/death/mode": "keep",
		"settings/world_bonus/gather": 2.0, "settings/world_bonus/craft_speed": 2.0, "settings/world_bonus/machine_speed": 1.0,
		"settings/world_bonus/build_cost": -0.75, "settings/tech_tree": false, "settings/zone/enabled": false, "settings/scan/enabled": false,
		"settings/bag/start": 81},
		"modules": {"waves": false, "monsters": false, "survival": false, "hazards": false, "climate": false, "durability": false, "finite_ammo": false}},
}

const MISSING := "__нет_значения__"
static var _backup := {}      # «тип/ключ» → прежнее значение верхнего ключа (или MISSING)
static var _rev := -1


# ---------------------------------------------------------------- поля

## Все поля вкладки: [{path, label, kind, hint}] и заголовки групп [{header}].
static func entries(paths: Array) -> Array:
	var out := []
	for p in paths:
		var parts: PackedStringArray = str(p).split("/")
		if parts.size() == 3 and parts[0] == "events" and parts[1] == "*":
			var ids: Array = DB.data.get("events", {}).keys()
			ids.sort_custom(func(a, b): return str(DB.data.events[a].get("name", a)) < str(DB.data.events[b].get("name", b)))
			if not ids.is_empty():
				out.append({"header": "События мира: шанс в день (0.25 — в среднем раз в 4 дня, 0 — никогда)"})
			for id in ids:
				var f := field("events/%s/%s" % [id, parts[2]])
				if not f.is_empty():
					out.append(f)
		elif parts.size() == 3 and parts[2] == "*":
			var top := _top_field(parts[0], parts[1])
			if top.is_empty() or not str(top[2]).begins_with("group:"):
				continue
			var subs := []
			for sf in Schema.sub(str(top[2]).substr(6)):
				if sf[0] in SKIP_SUB:
					continue
				var f := field("%s/%s/%s" % [parts[0], parts[1], sf[0]])
				if not f.is_empty():
					subs.append(f)
			if not subs.is_empty():
				out.append({"header": str(top[1])})
				out.append_array(subs)
		else:
			var f := field(str(p))
			if not f.is_empty():
				if f.has("group"):
					f.label = "%s: %s" % [f.group, f.label]
				out.append(f)
	return out


## Все пути всех вкладок (для server.cfg).
static func all_paths() -> Array:
	var out := []
	for t in TABS + [["", QUICK]]:
		for e in entries(t[1]):
			if e.has("path"):
				out.append(e.path)
	return out


static func _top_field(t: String, key: String) -> Array:
	for f in Schema.fields(t):
		if f[0] == key:
			return f
	return []


static func _simple(kind: String) -> bool:
	return kind in ["bool", "int", "float"] or (kind.begins_with("enum:") and not kind.begins_with("enum:@"))


## Описание поля по пути: {path, label, kind, hint}. Пусто — поле не простое или его нет в схеме.
static func field(path: String) -> Dictionary:
	var parts: PackedStringArray = path.split("/")
	if parts.size() < 2:
		return {}
	if parts[0] == "events":
		if parts.size() != 3 or not DB.data.get("events", {}).has(parts[1]):
			return {}
		var ef := _top_field("events", parts[2])
		if ef.is_empty() or not _simple(str(ef[2])):
			return {}
		var en := str(DB.data.events[parts[1]].get("name", parts[1]))
		return {"path": path, "label": en if parts[2] == "chance" else "%s: %s" % [en, ef[1]], "kind": str(ef[2]), "hint": str(DB.data.events[parts[1]].get("text", ""))}
	var top := _top_field(parts[0], parts[1])
	if top.is_empty():
		return {}
	if parts.size() == 2:
		return {"path": path, "label": str(top[1]), "kind": str(top[2]), "hint": str(top[3])} if _simple(str(top[2])) else {}
	if not str(top[2]).begins_with("group:"):
		return {}
	for sf in Schema.sub(str(top[2]).substr(6)):
		if sf[0] == parts[2]:
			if not _simple(str(sf[2])):
				return {}
			return {"path": path, "label": str(sf[1]), "kind": str(sf[2]), "hint": str(sf[3]) if sf.size() > 3 else "", "group": str(top[1])}
	return {}


## Подписи вариантов списка выбора: [[значение, подпись]].
static func enum_items(kind: String) -> Array:
	var out := []
	for v in kind.substr(5).split("|"):
		out.append([v, Schema.enum_label(v) if v != "" else "—"])
	return out


# ---------------------------------------------------------------- значения

## Обычное значение (из правил игры, без настроек сервера).
static func base(path: String):
	var parts: PackedStringArray = path.split("/")
	var bk := "%s/%s" % [parts[0], parts[1]]
	var cur = null
	if _backup.has(bk):
		cur = _backup[bk]
		if typeof(cur) == TYPE_STRING and cur == MISSING:
			cur = null
	else:
		cur = DB.data.get(parts[0], {}).get(parts[1]) if DB.data.get(parts[0]) is Dictionary else null
	for i in range(2, parts.size()):
		cur = cur.get(parts[i]) if cur is Dictionary else null
	var f := field(path)
	return coerce(str(f.get("kind", "")), cur)


## Значение нужного вида (пусто — ноль, «нет» или первый вариант списка).
static func coerce(kind: String, v):
	match kind:
		"bool":
			if typeof(v) == TYPE_STRING:
				return str(v).to_lower() in ["true", "1", "да", "yes", "on"]
			return bool(v) if v != null else false
		"int":
			return int(v) if v != null else 0
		"float":
			return float(v) if v != null else 0.0
	if kind.begins_with("enum:"):
		if v == null:
			return str(kind.substr(5).split("|")[0])
		return str(v)
	return v


## Заготовка → {ov, modules}: «*k» пересчитывается от обычного значения.
static func preset(name: String) -> Dictionary:
	var p: Dictionary = PRESETS.get(name, {})
	var ov := {}
	for path in p.get("ov", {}):
		var f := field(path)
		if f.is_empty():
			continue
		var v = p.ov[path]
		if typeof(v) == TYPE_STRING and str(v).begins_with("*"):
			var b = base(path)
			v = b * float(str(v).substr(1))
			if f.kind == "int":
				v = int(round(v))
		ov[path] = coerce(f.kind, v)
	return {"ov": ov, "modules": p.get("modules", {}).duplicate()}


## Только то, что отличается от обычного (чтобы в комнате и в server.cfg не хранились лишние значения).
static func changed(values: Dictionary) -> Dictionary:
	var out := {}
	for path in values:
		var f := field(path)
		if f.is_empty():
			continue
		var v = coerce(f.kind, values[path])
		var b = base(path)
		if f.kind == "float" and absf(float(v) - float(b)) < 0.00001:
			continue
		if f.kind != "float" and v == b:
			continue
		out[path] = v
	return out


# ---------------------------------------------------------------- применить к миру

## Применить настройки сервера к правилам игры (до создания мира). Повторный вызов сначала откатывает прошлые.
static func apply(ov) -> void:
	restore()
	if not ov is Dictionary or ov.is_empty():
		return
	for path in ov:
		var f := field(str(path))
		if f.is_empty():
			continue
		var parts: PackedStringArray = str(path).split("/")
		var t: Dictionary = DB.data.get(parts[0], {})
		var bk := "%s/%s" % [parts[0], parts[1]]
		if not _backup.has(bk):
			_backup[bk] = t[parts[1]].duplicate(true) if t.get(parts[1]) is Dictionary or t.get(parts[1]) is Array else (t[parts[1]] if t.has(parts[1]) else MISSING)
		var v = coerce(f.kind, ov[path])
		if parts.size() == 2:
			t[parts[1]] = v
		else:
			if not t.get(parts[1]) is Dictionary:
				t[parts[1]] = {}
			else:
				t[parts[1]] = (t[parts[1]] as Dictionary).duplicate(true)   # не трогаем словарь правил игры
			var d: Dictionary = t[parts[1]]
			for i in range(2, parts.size() - 1):
				if not d.get(parts[i]) is Dictionary:
					d[parts[i]] = {}
				d = d[parts[i]]
			d[parts[parts.size() - 1]] = v
		if parts[0] == "settings":
			DB.ov_keys[parts[1]] = true
	_rev = DB.revision


## Вернуть обычные правила (выход из сетевого мира).
static func restore() -> void:
	if not _backup.is_empty():   # A-9 r6: возвращаем всегда (ревизию поднимают и обычные действия — узор, конструктор)
		for bk in _backup:
			var parts: PackedStringArray = str(bk).split("/")
			var t: Dictionary = DB.data.get(parts[0], {})
			var v = _backup[bk]
			if typeof(v) == TYPE_STRING and v == MISSING:
				t.erase(parts[1])
			else:
				t[parts[1]] = v
	_backup.clear()
	DB.ov_keys.clear()


## Модули: [[id, подпись, подсказка]] из схемы «Игровые модули».
static func module_list() -> Array:
	var out := []
	var have: Dictionary = DB.data.settings.get("modules", {})
	for f in Schema.sub("modules"):
		if f[2] == "bool" and (have.has(f[0]) or f[0] in ["waves", "monsters"]):
			out.append([str(f[0]), str(f[1]), str(f[3]) if f.size() > 3 else ""])
	return out


static func module_default(id: String) -> bool:
	return bool(DB.data.settings.get("modules", {}).get(id, id in ["waves", "monsters", "professions"]))
