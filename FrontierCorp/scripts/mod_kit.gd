class_name ModKit
extends RefCounted
## Моды игроков прямо из игры (14.6): конструктор сохраняет здания, предметы, рецепты и модели в папку мода,
## мод упаковывается в один файл .fcmod (обычный zip), чужой файл забирается обратно в папку mods.
## Из чужих модов берутся только данные (json, картинки, звуки, модели glb) — скрипты .gd не берутся.

const EXT := "fcmod"
const SAFE_EXT := ["json", "png", "jpg", "webp", "ogg", "wav", "mp3", "glb", "txt"]
const TYPES := ["items", "buildings", "recipes", "models"]


static func dir_of(mod_id: String) -> String:
	return DB.mods_dir().path_join(mod_id)


## Папка для обмена: сюда кладутся упакованные моды, отсюда же забираются чужие.
static func share_dir() -> String:
	var p := DB.base_dir().path_join("mods_share")
	if OS.has_feature("steam"):
		p = ProjectSettings.globalize_path("user://mods_share")
	if not DirAccess.dir_exists_absolute(p) and DirAccess.make_dir_recursive_absolute(p) != OK:
		p = ProjectSettings.globalize_path("user://mods_share")
		DirAccess.make_dir_recursive_absolute(p)
	return p


## Создать мод (или взять существующий с таким названием). Возвращает id папки.
static func ensure(name: String, author := "") -> String:
	var id := DB.latin_id(name)
	if id == "":
		id = "my_mod"
	var p := dir_of(id)
	DirAccess.make_dir_recursive_absolute(p)
	if not FileAccess.file_exists(p.path_join("mod.json")):
		DB._write_json(p.path_join("mod.json"), {"name": name, "version": "1.0", "author": author, "desc": "Сделано в конструкторе игры", "uid": _new_uid()})
	else:
		# A-2 r7: свой мод получает метку, чтобы чужой мод с тем же названием его не затёр
		var mi = DB._read_json(p.path_join("mod.json"))
		if mi is Dictionary and str(mi.get("uid", "")) == "":
			mi["uid"] = _new_uid()
			DB._write_json(p.path_join("mod.json"), mi)
	return id


static func _new_uid() -> String:
	return "%08x%08x" % [randi(), Time.get_ticks_usec() & 0xffffffff]


static func info(mod_id: String) -> Dictionary:
	var v = DB._read_json(dir_of(mod_id).path_join("mod.json"))
	return v if v is Dictionary else {"name": mod_id, "version": "1.0"}


static func list_mods() -> Array:
	var out := []
	var d := DirAccess.open(DB.mods_dir())
	if d == null:
		return out
	for n in d.get_directories():
		var i := info(n)
		i["id"] = n
		out.append(i)
	out.sort_custom(func(a, b): return str(a.get("name", a.id)) < str(b.get("name", b.id)))
	return out


static func _file(mod_id: String, t: String) -> Dictionary:
	var v = DB._read_json(dir_of(mod_id).path_join(t + ".json"))
	return v if v is Dictionary else {}


## Что лежит в моде: {тип: {id: запись}}.
static func contents(mod_id: String) -> Dictionary:
	var out := {}
	for t in TYPES:
		out[t] = _file(mod_id, t)
	return out


## Записать объект в мод и сразу включить его в игре (без перезапуска).
static func put(mod_id: String, t: String, id: String, rec: Dictionary) -> void:
	var cur := _file(mod_id, t)
	cur[id] = rec.duplicate(true)
	DB._write_json(dir_of(mod_id).path_join(t + ".json"), cur)
	DB.data[t][id] = rec.duplicate(true)
	DB.sources["%s/%s" % [t, id]] = "mod " + mod_id
	DB.revision += 1


static func remove(mod_id: String, t: String, id: String) -> void:
	var cur := _file(mod_id, t)
	cur.erase(id)
	DB._write_json(dir_of(mod_id).path_join(t + ".json"), cur)
	if str(DB.sources.get("%s/%s" % [t, id], "")) == "mod " + mod_id:
		DB.data[t].erase(id)
	DB.revision += 1


## Свободный id для нового объекта: из названия латиницей, без совпадений с игрой.
static func free_id(t: String, name: String) -> String:
	var base := DB.latin_id(name)
	if base == "":
		base = "my_" + t.trim_suffix("s")
	var id := base
	var i := 2
	while DB.data.get(t, {}).has(id):
		id = "%s_%d" % [base, i]
		i += 1
	return id


## Модель из конструктора: готовая модель-основа + свои детали сверху. В файл пишется целиком (без ссылок),
## а в "ctor" — из чего собрана, чтобы конструктор открыл её снова.
static func compose_model(name: String, base: String, extra: Array) -> Dictionary:
	var parts: Array = []
	if base != "":
		for p in ModelLib.model(base).get("parts", []):
			parts.append(p.duplicate(true))
	for p in extra:
		parts.append(p.duplicate(true))
	if parts.is_empty():
		parts.append({"shape": "box", "size": [1, 1, 1], "pos": [0, 0.5, 0], "rot": [0, 0, 0], "color": "#c0c4cc", "mat": "paint"})
	var m := {"name": name, "category": "Моды", "parts": parts, "ctor": {"base": base, "extra": extra.duplicate(true)}}
	var bm := ModelLib.model(base) if base != "" else {}
	for k in ["rig", "size_hint"]:
		if bm.has(k):
			m[k] = bm[k].duplicate(true) if bm[k] is Dictionary or bm[k] is Array else bm[k]
	return m


## Упаковать мод в один файл для обмена. Возвращает {ok, path, msg}.
static func pack(mod_id: String) -> Dictionary:
	var src := dir_of(mod_id)
	if not DirAccess.dir_exists_absolute(src):
		return {"ok": false, "msg": "Нет мода " + mod_id}
	var inf := info(mod_id)
	var out := share_dir().path_join("%s_v%s.%s" % [mod_id, str(inf.get("version", "1.0")), EXT])
	var zip := ZIPPacker.new()
	if zip.open(out) != OK:
		return {"ok": false, "msg": "Не удалось создать " + out}
	DB._zip_dir(zip, src, mod_id)
	zip.close()
	return {"ok": true, "path": out, "msg": "Мод упакован в один файл: " + out}


## Забрать мод из файла .fcmod (или .zip) в папку mods. Берутся только данные; пути «наружу» отбрасываются.
## Возвращает {ok, id, msg, files, skipped}.
static func install(path: String) -> Dictionary:
	var r := ZIPReader.new()
	if r.open(path) != OK:
		return {"ok": false, "msg": "Не удалось открыть файл " + path.get_file()}
	var files := r.get_files()
	# корень архива: одна папка мода или файлы сразу
	var root := ""
	# A-3 r6: корень — папка mod.json (если есть), иначе папка первого .json
	var pick := ""
	for f in files:
		if f.replace("\\", "/").get_file() == "mod.json" and (pick == "" or f.length() < pick.length()):
			pick = f
	if pick == "":
		for f in files:
			if f.get_extension() == "json":
				pick = f
				break
	if pick != "":
		var parts := pick.replace("\\", "/").split("/", false)
		root = parts[0] + "/" if parts.size() > 1 else ""
		if root != "" and not pick.begins_with(root):
			root = ""
	var name := root.trim_suffix("/") if root != "" else path.get_file().get_basename()
	var id := DB.latin_id(name)
	if id == "":
		id = "mod"
	var dst := dir_of(id)
	if DirAccess.dir_exists_absolute(dst):
		# тот же мод другой версии — заменяем данные; иначе новое имя
		var old := info(id)
		var newi = JSON.parse_string(r.read_file(root + "mod.json").get_string_from_utf8()) if r.file_exists(root + "mod.json") else null
		# A-4 r6: «новая версия» — только того же автора; иначе ставим рядом под новым именем
		# A-2 r7: и та же метка uid (автора конструктор не спрашивает, поэтому сравнения автора мало)
		if not (newi is Dictionary and str(newi.get("name", "")) == str(old.get("name", "")) and str(newi.get("author", "")) == str(old.get("author", "")) \
				and str(newi.get("uid", "")) == str(old.get("uid", ""))):
			id = DB.unique_id(DB.mods_dir(), id)
			dst = dir_of(id)
	var n := 0
	var skipped := 0
	for f in files:
		if f.ends_with("/") or not f.begins_with(root):
			continue
		# A-2 r6: «\» Godot считает разделителем — нормализуем до проверки и проверяем итоговый путь
		var rel := f.substr(root.length()).replace("\\", "/")
		var to := dst.path_join(rel).simplify_path()
		if rel == "" or ".." in rel.split("/") or rel.begins_with("/") or ":" in rel or not rel.get_extension().to_lower() in SAFE_EXT \
				or not to.begins_with(dst.simplify_path() + "/"):
			skipped += 1
			continue
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		var fa := FileAccess.open(to, FileAccess.WRITE)
		if fa:
			fa.store_buffer(r.read_file(f))
			n += 1
	r.close()
	if n == 0:
		return {"ok": false, "msg": "В файле нет данных мода", "skipped": skipped}
	if not FileAccess.file_exists(dst.path_join("mod.json")):
		DB._write_json(dst.path_join("mod.json"), {"name": name, "version": "1.0", "author": "", "desc": ""})
	var msg := "Мод «%s» добавлен (%d файлов)." % [str(info(id).get("name", id)), n]
	if skipped > 0:
		msg += " Пропущено файлов: %d (скрипты и неизвестные файлы не берутся)." % skipped
	return {"ok": true, "id": id, "msg": msg, "files": n, "skipped": skipped}


## Забрать все файлы .fcmod из папки обмена. Возвращает список сообщений.
static func install_from_share() -> Array:
	var out := []
	var d := DirAccess.open(share_dir())
	if d == null:
		return out
	var done_dir := share_dir().path_join("забрано")
	for f in d.get_files():
		if not f.get_extension().to_lower() in [EXT, "zip"]:
			continue
		var res := install(share_dir().path_join(f))
		out.append(res)
		if res.ok:
			DirAccess.make_dir_recursive_absolute(done_dir)
			DirAccess.rename_absolute(share_dir().path_join(f), done_dir.path_join(f))
	return out


## Подключить только что забранный мод в идущей игре: его данные ложатся поверх (как при запуске).
static func apply_now(mod_id: String) -> void:
	var p := dir_of(mod_id)
	for t in DB.DICT_TYPES:
		var v = DB._read_json(p.path_join(t + ".json"))
		if not v is Dictionary:
			continue
		for id in v:
			if v[id] is Dictionary and not v[id].get("_delete", false) and not v[id].get("_patch", false):
				DB.data[t][id] = v[id]
				DB.sources["%s/%s" % [t, id]] = "mod " + mod_id
	DB.mods = DB._scan(DB.mods_dir(), "mod")
	DB.revision += 1
