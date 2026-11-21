class_name ModCtor
extends RefCounted
## Конструктор модов в игре (14.6, клавиша N): свои здания и предметы прямо во время игры.
## Модель собирается из готовой основы и своих деталей, предмету можно дать рецепт.
## Всё пишется в папку мода (mods/<мод>) и сразу появляется в игре; «Поделиться» — один файл .fcmod для друга.

var hud
var game
var mod_id := ""
var kind := "buildings"     # buildings или items
var cur_id := ""            # правим уже сохранённый объект ("" — новый)
var rec := {}
var base_model := ""
var extra: Array = []
var recipe := {}            # у предмета: {in, n, time, stations}
var body: VBoxContainer
var preview: SubViewport
var pv_root: Node3D
var pv_cam: Camera3D
var status: Label
var _pv_dirty := true

const PREVIEW_ID := "__ctor_preview"


func _init(h) -> void:
	hud = h
	game = h.game


## Окно открылось или надо перерисовать.
func refresh(b: VBoxContainer) -> void:
	body = b
	if mod_id == "" or not DirAccess.dir_exists_absolute(ModKit.dir_of(mod_id)):
		var ms := ModKit.list_mods()
		mod_id = ms[0].id if not ms.is_empty() else ""
	if rec.is_empty():
		new_object(kind)
	_build()


func new_object(k: String) -> void:
	kind = k
	cur_id = ""
	if k == "buildings":
		rec = {"name": "Моё здание", "desc": "", "category": "decor", "behavior": "decor", "cost": {"iron_plate": 5}, "hp": 300, "size": 1, "params": {}, "blocks": []}
		base_model = "chest"
	else:
		rec = {"name": "Мой предмет", "desc": "", "category": "Моды", "color": "#ffa040", "stack": 50, "price": 5}
		base_model = "drop_box"
	extra = []
	recipe = {"in": {"iron_plate": 1}, "n": 1, "time": 2.0, "stations": ["hand"]}
	_pv_dirty = true


## «На основе…»: копия здания или предмета игры, дальше правится как своё.
func copy_from(id: String) -> void:
	var src: Dictionary = DB.data.get(kind, {}).get(id, {})
	if src.is_empty():
		return
	rec = src.duplicate(true)
	rec["name"] = str(src.get("name", id)) + " (моё)"
	rec.erase("script")   # чужой код не копируется
	cur_id = ""
	_take_model(str(src.get("model", id if kind == "buildings" else "drop_box")))
	recipe = {"in": {"iron_plate": 1}, "n": 1, "time": 2.0, "stations": ["hand"]}
	_pv_dirty = true


## Открыть свой сохранённый объект.
func edit(t: String, id: String) -> void:
	kind = t
	cur_id = id
	rec = DB.data.get(t, {}).get(id, {}).duplicate(true)
	_take_model(str(rec.get("model", "")))
	recipe = {"in": {}, "n": 1, "time": 2.0, "stations": ["hand"]}
	if t == "items":
		var r: Dictionary = DB.data.recipes.get(id + "_recipe", {})
		if not r.is_empty():
			recipe = {"in": r.get("in", {}).duplicate(), "n": int(r.get("out", {}).get(id, 1)), "time": float(r.get("time", 2.0)), "stations": r.get("stations", ["hand"]).duplicate()}
	_pv_dirty = true


func _take_model(mid: String) -> void:
	var md := DB.model_def(mid)
	if md.has("ctor"):
		base_model = str(md.ctor.get("base", ""))
		extra = md.ctor.get("extra", []).duplicate(true)
	else:
		base_model = mid
		extra = []


## Сохранить в мод. Возвращает id объекта.
func save() -> String:
	if mod_id == "":
		mod_id = ModKit.ensure("Мой мод")
	var nm := str(rec.get("name", "Без названия")).strip_edges()
	var id := cur_id if cur_id != "" else ModKit.free_id(kind, nm)
	if extra.is_empty() and base_model != "":
		rec["model"] = base_model
	else:
		var mid := id + "_model"
		ModKit.put(mod_id, "models", mid, ModKit.compose_model(nm, base_model, extra))
		rec["model"] = mid
	rec.erase("script")
	ModKit.put(mod_id, kind, id, rec)
	if kind == "items":
		var rid := id + "_recipe"
		if not recipe.get("in", {}).is_empty():
			ModKit.put(mod_id, "recipes", rid, {"name": nm, "in": recipe["in"].duplicate(), "out": {id: maxi(1, int(recipe.get("n", 1)))},
				"time": float(recipe.get("time", 2.0)), "stations": recipe.get("stations", ["hand"]).duplicate()})
		elif DB.data.recipes.has(rid):
			ModKit.remove(mod_id, "recipes", rid)
	cur_id = id
	return id


func remove(t: String, id: String) -> void:
	ModKit.remove(mod_id, t, id)
	var md := DB.model_def(id + "_model")
	if md.has("ctor"):
		ModKit.remove(mod_id, "models", id + "_model")
	if t == "items" and DB.data.recipes.has(id + "_recipe"):
		ModKit.remove(mod_id, "recipes", id + "_recipe")
	if cur_id == id:
		new_object(t)


# ---------------------------------------------------------------- окно

func _say(t: String, col := UI.DIM) -> void:
	if status:
		status.text = t
		status.add_theme_color_override("font_color", col)


func _build() -> void:
	UI.clear(body)
	# мод: выбор, новый, обмен
	var r1 := UI.hbox(8)
	r1.add_child(UI.label("Мод:", 15))
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	var ms := ModKit.list_mods()
	for i in ms.size():
		ob.add_item("%s  v%s" % [str(ms[i].get("name", ms[i].id)), str(ms[i].get("version", "1.0"))])
		ob.set_item_metadata(i, ms[i].id)
		if ms[i].id == mod_id:
			ob.select(i)
	if ms.is_empty():
		ob.add_item("— нет модов, создайте —")
		ob.disabled = true
	ob.item_selected.connect(func(i): mod_id = ob.get_item_metadata(i); new_object(kind); _build())
	r1.add_child(ob)
	var ne := LineEdit.new()
	ne.placeholder_text = "Название нового мода"
	ne.custom_minimum_size = Vector2(200, 0)
	r1.add_child(ne)
	r1.add_child(UI.button("Создать", func():
		if ne.text.strip_edges() != "":
			mod_id = ModKit.ensure(ne.text.strip_edges())
			new_object(kind)
			_build(), "Новая папка мода в mods"))
	body.add_child(r1)
	var r2 := UI.hbox(8)
	r2.add_child(UI.button("Поделиться файлом", func():
		if mod_id == "":
			return
		var res := ModKit.pack(mod_id)
		if res.ok:
			DisplayServer.clipboard_set(res.path)
		_say(res.msg + ("\nПуть скопирован. Отправьте файл другу: он кладёт его в папку обмена и жмёт «Забрать моды»." if res.ok else ""), UI.GOOD if res.ok else UI.BAD),
		"Упаковать мод в один файл .fcmod"))
	r2.add_child(UI.button("Забрать моды", func():
		var got := ModKit.install_from_share()
		var lines := []
		for g in got:
			lines.append(g.msg)
			if g.ok:
				ModKit.apply_now(g.id)
		_say("\n".join(lines) if not lines.is_empty() else "В папке обмена нет файлов .fcmod", UI.GOOD if not got.is_empty() else UI.DIM)
		if not got.is_empty():
			_build.call_deferred(), "Забрать файлы .fcmod из папки обмена — моды сразу подключаются"))
	r2.add_child(UI.button("Папка обмена", func(): OS.shell_open(ModKit.share_dir()), ModKit.share_dir()))
	r2.add_child(UI.button("Папка модов", func(): OS.shell_open(DB.mods_dir()), DB.mods_dir()))
	body.add_child(r2)
	status = UI.small("Свои здания и предметы. Сохраняются в мод и сразу появляются в игре.")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(900, 0)
	body.add_child(status)
	# что делаем
	var r3 := UI.hbox(8)
	for pair in [["buildings", "Здание"], ["items", "Предмет"]]:
		var k: String = pair[0]
		var b := UI.button(("● " if kind == k else "") + pair[1], func(): new_object(k); _build())
		r3.add_child(b)
	r3.add_child(UI.spacer())
	r3.add_child(UI.button("Новое", func(): new_object(kind); _build()))
	r3.add_child(UI.button("На основе…", func():
		EdPicker.open_for(body, kind, func(id): copy_from(id); _build(), false), "Скопировать здание или предмет игры и переделать"))
	body.add_child(r3)
	# объекты мода
	if mod_id != "":
		var mine: Dictionary = ModKit.contents(mod_id).get(kind, {})
		var fl := HFlowContainer.new()
		fl.add_child(UI.small("В моде:" if not mine.is_empty() else "В моде пока нет своих %s." % ("зданий" if kind == "buildings" else "предметов")))
		for id in mine:
			var oid: String = id
			var hb := UI.hbox(2)
			hb.add_child(UI.button(("✎ " if oid == cur_id else "") + str(mine[id].get("name", id)), func(): edit(kind, oid); _build()))
			hb.add_child(UI.button("✕", func(): remove(kind, oid); _build(), "Удалить из мода"))
			fl.add_child(hb)
		body.add_child(fl)
	# форма слева, модель справа
	var split := UI.hbox(14)
	var left := UI.vbox(6)
	left.custom_minimum_size = Vector2(560, 0)
	var flds: Array = []
	for f in EdSchema.fields(kind):
		if f[0] in ["script", "model", "icon", "port_model"]:
			continue
		flds.append(f)
	var form := EdForm.make(rec, flds, false, 190.0)
	form.changed.connect(func(): _pv_dirty = true)
	left.add_child(form)
	if kind == "items":
		left.add_child(UI.section("Как получить (рецепт)"))
		var rf := EdForm.make(recipe, [["in", "Что нужно", "amounts:items", "Пусто — без рецепта"], ["n", "Сколько получится", "int", ""],
			["time", "Время, сек", "float", ""], ["stations", "Где делается", "refs:stations", "hand — в руках"]], false, 190.0)
		left.add_child(rf)
	split.add_child(left)
	var right := UI.vbox(6)
	right.custom_minimum_size = Vector2(330, 0)
	right.add_child(_preview_box())
	var mr := UI.hbox(6)
	mr.add_child(UI.label("Основа:", 14))
	var mb := UI.button(_model_name(base_model), func():
		EdPicker.open_for(body, "models", func(id): base_model = id; _pv_dirty = true; _build(), true), "Готовая модель, на которую ставятся свои детали. Пусто — только свои детали")
	mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mr.add_child(mb)
	right.add_child(mr)
	right.add_child(UI.section("Свои детали (%d)" % extra.size()))
	var holder := {"extra": extra}
	var pf := EdForm.make(holder, [["extra", "Детали", "list:model_part", "Добавьте кубы, цилиндры, шары: размер, место, цвет"]], false, 110.0)
	pf.changed.connect(func(): extra = holder.extra; _pv_dirty = true)
	right.add_child(pf)
	split.add_child(right)
	body.add_child(split)
	# действия
	var r4 := UI.hbox(8)
	r4.add_child(UI.button("Сохранить в мод", func():
		var id := save()
		_say("Сохранено: «%s» в моде «%s». Уже есть в игре%s." % [str(rec.get("name", id)), str(ModKit.info(mod_id).get("name", mod_id)),
			" — меню строительства, раздел «%s»" % str(rec.get("category", "")) if kind == "buildings" else " — крафт и рюкзак"], UI.GOOD)
		_build.call_deferred()))
	if kind == "buildings":
		r4.add_child(UI.button("Сохранить и поставить", func():
			var id := save()
			hud.close("constructor")
			game.select_build(id)))
	elif game.flags.get("free_build", false) or DB.studio:
		r4.add_child(UI.button("Сохранить и взять 10", func():
			var id := save()
			game.player.inv.add(id, 10)
			_say("В рюкзаке: 10 × %s" % DB.item_name(id), UI.GOOD)
			_build.call_deferred()))
	body.add_child(r4)
	_pv_dirty = true
	_update_preview()


func _model_name(id: String) -> String:
	if id == "":
		return "— без основы —"
	return str(DB.model_def(id).get("name", id))


func _preview_box() -> Control:
	var c := SubViewportContainer.new()
	c.custom_minimum_size = Vector2(320, 240)
	c.stretch = true
	preview = SubViewport.new()
	preview.own_world_3d = true
	preview.transparent_bg = false
	preview.msaa_3d = Viewport.MSAA_4X
	c.add_child(preview)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.13, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	preview.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	preview.add_child(sun)
	pv_cam = Camera3D.new()
	preview.add_child(pv_cam)
	pv_root = Node3D.new()
	preview.add_child(pv_root)
	var t := Timer.new()
	t.wait_time = 0.03
	t.autostart = true
	t.timeout.connect(func():
		if is_instance_valid(pv_root):
			pv_root.rotation.y += 0.02
			if _pv_dirty:
				_update_preview())
	c.add_child(t)
	return c


## Собрать модель для просмотра (та же сборка, что пойдёт в мод).
func _update_preview() -> void:
	if pv_root == null or not is_instance_valid(pv_root):
		return
	_pv_dirty = false
	for ch in pv_root.get_children():
		ch.queue_free()
	var m := ModKit.compose_model("просмотр", base_model, extra)
	DB.data.models[PREVIEW_ID] = m
	ModelLib._merged.erase(PREVIEW_ID)
	var n := ModelLib.make_node(PREVIEW_ID)
	if kind == "items":
		n.scale = Vector3.ONE * float(rec.get("model_scale", 1.0))
	pv_root.add_child(n)
	# рамка по настоящим размерам деталей
	var box := AABB()
	var first := true
	for ch in n.get_children():
		var bb := AABB()
		if ch is MeshInstance3D and ch.mesh:
			bb = ch.transform * ch.mesh.get_aabb()
		elif ch is MultiMeshInstance3D and ch.multimesh and ch.multimesh.mesh:
			bb = ch.transform * ch.multimesh.mesh.get_aabb()
		else:
			continue
		box = bb if first else box.merge(bb)
		first = false
	if first:
		box = AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	box.position *= n.scale
	box.size *= n.scale
	var c := box.get_center()
	var rad := maxf(0.4, box.size.length() * 0.5)
	var dist := rad / tan(deg_to_rad(pv_cam.fov * 0.5)) * 1.05
	pv_cam.position = c + Vector3(0, 0.45, 1.0).normalized() * dist
	pv_cam.look_at(c)
