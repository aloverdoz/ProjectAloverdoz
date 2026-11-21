extends Node
## 1.3: язык игры (автозагрузка «Lang»). Тексты игры пишутся по-русски, а перевод лежит в lang.json
## ({"en": {"русский текст": "English text"}}) у ядра, игры, дополнений и модов. Ещё перевод берётся из полей
## name_en / desc_en / text_en у объектов и из «Тексты и языки» (@ключ с ru и en).
## Godot сам переводит надписи, кнопки и подсказки; строки с числами («Рюкзак: %d ячеек») узнаются по шаблону.

const SUPPORTED := ["ru", "en"]

var tr_obj: DictTranslation = null


class DictTranslation extends Translation:
	var dict := {}            # русский -> перевод
	var templates := {}       # первые 2 символа шаблона -> [[RegEx, en, [имена мест]]]
	var loose := []           # шаблоны, которые начинаются с подстановки
	var weak := []            # A-4 r4: шаблоны без своих слов («%s (%s)», «%s ×%d») — только когда ничего другого не подошло
	var cache := {}
	var rx_ph := RegEx.create_from_string("%[-+]?[0-9]*(?:\\.[0-9]+)?[dsf]|\\{[a-z_]+\\}")
	var rx_num := RegEx.create_from_string("^[\\s0-9.,:%+×x/()−-]*$")
	var rx_pre := RegEx.create_from_string("^([?✓✔★☆●•◆▶▸→←↑↓⚠✗✖]+\\s+)(.+)$")
	var rx_word := RegEx.create_from_string("[A-Za-zА-Яа-яЁё]{2,}")
	var rx_bb := RegEx.create_from_string("\\[/?(?:color|b|i|u|font_size|url|center|right|outline_color|outline_size|bgcolor|fgcolor|img|code|s)(?:=[^\\]]*)?\\]")

	func setup(d0: Dictionary) -> void:
		# A-4 r4: ключи с "\n"/пробелом по краям — добавляем и обрезанный вариант
		var d := d0.duplicate()
		for ru in d0:
			var k0 := str(ru)
			var ks := k0.strip_edges()
			if ks != k0 and ks != "" and not d.has(ks):
				d[ks] = str(d0[ru]).strip_edges()
			# «Нужен для: » → и «Нужен для» (строку «a: b» делим по ": ")
			if ks.ends_with(":") and ks.length() > 1 and ks.find("%") < 0:
				var kc := ks.trim_suffix(":").strip_edges()
				if not d.has(kc):
					d[kc] = str(d0[ru]).strip_edges().trim_suffix(":").strip_edges()
		dict = d
		templates.clear()
		loose.clear()
		weak.clear()
		cache.clear()
		for ru in d:
			var s := str(ru)
			if s.find("%") < 0 and s.find("{") < 0:
				continue
			var m := rx_ph.search_all(s)
			if m.is_empty():
				continue
			var pat := "^"
			var pos := 0
			var names := []
			for r in m:
				pat += _esc(s.substr(pos, r.get_start() - pos).replace("%%", "%"))
				var ph := r.get_string()
				if ph.ends_with("d"):
					pat += "([+\\-−]?[0-9]+)"
				elif ph.ends_with("f"):
					pat += "([+\\-−]?[0-9]+(?:[.,][0-9]+)?)"
				else:
					pat += "(.*?)"
				names.append(ph)
				pos = r.get_end()
			pat += _esc(s.substr(pos).replace("%%", "%")) + "$"
			var rx := RegEx.new()
			if rx.compile(pat) != OK:
				continue
			var pre := s.substr(0, m[0].get_start())
			var t := [rx, str(d[ru]), names, rx_ph.sub(s, "", true).length()]
			if pre.length() >= 2:
				var k := pre.substr(0, 2)
				if not templates.has(k):
					templates[k] = []
				templates[k].append(t)
			elif str(d[ru]) == s and not rx_word.search(s):
				weak.append(t)
			else:
				loose.append(t)
		# сначала шаблоны с более длинным текстом: «%s идёт %s! Стройте…» раньше, чем «%s %s»
		for k in templates:
			templates[k].sort_custom(func(x, y): return x[3] > y[3])
		loose.sort_custom(func(x, y): return x[3] > y[3])
		weak.sort_custom(func(x, y): return x[3] > y[3])

	static func _esc(s: String) -> String:
		var out := ""
		for c in s:
			if "\\^$.|?*+()[]{}".find(c) >= 0:
				out += "\\" + c
			else:
				out += c
		return out

	func _get_message(src_message: StringName, _context: StringName) -> StringName:
		var s := String(src_message)
		if s == "":
			return src_message
		var v = dict.get(s)
		if v != null:
			return StringName(v)
		if cache.has(s):
			return cache[s]
		var out := lookup(s, 0)
		if cache.size() > 30000:
			cache.clear()
		cache[s] = StringName(out)
		return cache[s]

	## Перевод строки: целиком, по шаблону, по строкам или по частям «a · b». Не нашли — как есть.
	func lookup(s: String, depth: int) -> String:
		var v = dict.get(s)
		if v != null:
			return str(v)
		if depth > 5 or rx_num.search(s) != null:
			return s
		var st := s.strip_edges()
		if st != s and st != "":
			var tv := lookup(st, depth + 1)
			if tv != st:
				return s.replace(st, tv)
		var r := _template(s, depth, false)
		if r != "" and r != s:
			return r
		var pm := rx_pre.search(s)   # «✓ Имя», «? Имя», «★ Редкий предмет»
		if pm != null:
			var rest := pm.get_string(2)
			var tr2 := lookup(rest, depth + 1)
			if tr2 != rest:
				return pm.get_string(1) + tr2
		if s.begins_with("(") and s.ends_with(")") and s.length() > 2:   # A-4 r4: «(Химзавод)»
			var inner := s.substr(1, s.length() - 2)
			var ti := lookup(inner, depth + 1)
			if ti != inner:
				return "(" + ti + ")"
		# A-7 r4: BBCode-разметка — переводим текст между тегами по отдельности
		if s.find("[") >= 0 and s.find("\n") < 0:
			var tags := rx_bb.search_all(s)
			if not tags.is_empty():
				var out := ""
				var pos := 0
				for m in tags:
					var seg := s.substr(pos, m.get_start() - pos)
					out += _seg(seg, depth) + m.get_string()
					pos = m.get_end()
				out += _seg(s.substr(pos), depth)
				return out
		for sep in ["\n", " · ", ": ", " — ", ", "]:
			if s.find(sep) > 0:
				var parts := s.split(sep)
				var changed := false
				for i in parts.size():
					var p := lookup(parts[i], depth + 1)
					if p != parts[i]:
						parts[i] = p
						changed = true
				if changed:
					return sep.join(parts)
		var rw := _template(s, depth, true)
		if rw != "":
			return rw
		return s

	func _seg(seg: String, depth: int) -> String:
		if seg.strip_edges() == "":
			return seg
		return lookup(seg, depth + 1)

	func _template(s: String, depth: int, use_weak := false) -> String:
		var lists := [weak] if use_weak else [loose]
		if not use_weak and s.length() >= 2 and templates.has(s.substr(0, 2)):
			lists.push_front(templates[s.substr(0, 2)])
		for l in lists:
			for t in l:
				var m: RegExMatch = t[0].search(s)
				if m == null:
					continue
				var en: String = t[1]
				var names: Array = t[2]
				var span := false   # A-4 r4: подстановка не должна глотать несколько строк или частей «a · b»
				for i in names.size():
					var g0 := m.get_string(i + 1)
					if g0.find("\n") >= 0 or g0.find(" · ") >= 0:
						span = true
				if span:
					continue
				# подстановки по порядку: %s/%d — по очереди, {ключ} — по имени
				var vals := []
				for i in names.size():
					var g := m.get_string(i + 1)
					if str(names[i]).ends_with("s") or str(names[i]).begins_with("{"):
						g = lookup(g, depth + 1)
					vals.append(g)
				var out := ""
				var pos := 0
				var k := 0
				var found := rx_ph.search_all(en)
				for r in found:
					out += en.substr(pos, r.get_start() - pos).replace("%%", "%")
					var ph := r.get_string()
					var idx := names.find(ph) if ph.begins_with("{") else k
					if not ph.begins_with("{"):
						k += 1
					out += str(vals[idx]) if idx >= 0 and idx < vals.size() else ph
					pos = r.get_end()
				out += en.substr(pos).replace("%%", "%")
				return out
		return ""


func _ready() -> void:
	tr_obj = DictTranslation.new()
	tr_obj.locale = "en"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):   # снимки и проверки: язык на один запуск, без записи в настройки
			Prefs.values["language"] = a.substr(7)
	rebuild()


func current() -> String:
	var l := str(Prefs.get_value("language", "ru"))
	return l if l in SUPPORTED else "ru"


## Собрать словарь из lang.json всех слоёв и полей *_en у объектов (вызывается после DB.load_all).
func rebuild() -> void:
	if tr_obj == null:
		return
	var d := {}
	var lang: Dictionary = DB.data.get("lang", {})
	for k in lang.get("en", {}):
		d[k] = lang.en[k]
	# поля name_en, desc_en… у предметов, зданий, монстров и прочего — так моды переводят свои объекты
	for t in DB.DICT_TYPES:
		for id in DB.data.get(t, {}):
			var o = DB.data[t][id]
			if not o is Dictionary:
				continue
			if t == "texts":
				if o.has("ru") and o.has("en"):
					d[str(o.ru)] = str(o.en)
				continue
			for key in o:
				var ks := str(key)
				if ks.ends_with("_en") and o[key] is String and o.has(ks.substr(0, ks.length() - 3)):
					var src = o[ks.substr(0, ks.length() - 3)]
					if src is String and src != "":
						d[src] = o[key]
	tr_obj.setup(d)
	apply_locale()


func apply_locale() -> void:
	# русский — исходный язык: перевод не подключён вовсе (иначе Godot берёт английский как запасной)
	if tr_obj != null:
		var has := TranslationServer.get_translation_object("en") == tr_obj
		if current() == "en" and not has:
			TranslationServer.add_translation(tr_obj)
		elif current() != "en" and has:
			TranslationServer.remove_translation(tr_obj)
	TranslationServer.set_locale(current())


## Перевести текст вручную (для строк, которые рисуются не через надписи): Lang.t("Сдать").
func t(s: String) -> String:
	if current() == "ru" or tr_obj == null:
		return s
	return String(tr_obj._get_message(StringName(s), &""))
