extends HSplitContainer
## Вкладка «Карта»: рисование готовой карты кистями и настройка случайной (процедурной) карты.
## Карта сохраняется в папку maps игры (или дополнения) и может стать картой игры по умолчанию.

var ed
var vpc: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var world: World
var world_root: Node3D
var brush_ring: MeshInstance3D
var hq_marker: Node3D
var side: VBoxContainer
var info_lbl: Label
var name_edit: LineEdit
var gen := {}
var map_name := "моя_карта"
var tool := "dirt"
var tool_btns := {}
var radius := 4.0
var strength := 0.5
var density := 0.25
var res_id := "tree_pine"
var dep_idx := 0
var res_btn: Button
var dep_opt: OptionButton
var pur_opt: OptionButton
var pur_id := ""          # качество для «Залежь под бур»: "" — случайное

var target := Vector3.ZERO
var dist := 120.0
var yaw := 0.6
var pitch := 0.95
var _cursor_cell := Vector2i.ZERO
var _cursor_ok := false
var _painting := false
var _pan := false
var _orbit := false
var _paint_t := 0.0
var _level := 0.0   # высота, до которой ровняет кисть «Выровнять»
var _stroke := {}
var undo: Array = []
var redo: Array = []
var modified := false
var rng := RandomNumberGenerator.new()

const TOOLS := [
	["dirt", "Грунт", "Сухая земля"], ["sand", "Песок", ""], ["rock", "Камень", "Каменистая земля"], ["snow", "Снег", ""],
	["grass", "Трава", "Стереть грунт, песок, камень и снег — останется трава"],
	["water", "Вода", "Озёра и реки"], ["land", "Осушить", "Убрать воду"],
	["objects", "Деревья и камни", "Сажать выбранный объект кистью"], ["erase_obj", "Убрать объекты", ""],
	["dep_one", "Залежь под бур", "Щелчок — одна залежь выбранной руды ровно под бур"],
	["deposit", "Месторождение кистью", "Руда для буров: закрасить кистью"], ["erase_dep", "Убрать руду", ""],
	["start", "Место штаба", "Щелчок — здесь игрок начнёт игру"],
	["raise", "Поднять землю", "Холм: держите кнопку мыши"], ["lower", "Опустить землю", "Низина"],
	["flatten", "Выровнять", "Ровняет до высоты, где начали мазок"], ["smooth", "Сгладить", "Убирает резкие склоны"],
]
const CHANNEL := {"dirt": 0, "sand": 1, "rock": 2, "snow": 3, "grass": -1}
const GEN_KEYS := ["size", "wrap", "seed", "biome_scale", "forest", "dry", "rocky", "snow", "lakes", "lake_size", "rivers",
	"river_width", "sand_beaches", "start_clear_radius", "deposit_rock_chance", "relief", "relief_scale", "hills", "start_flat_radius", "shore_flat", "rocky_slopes"]


func _init(editor) -> void:
	ed = editor
	split_offset = 330
	rng.randomize()
	# ---- левая панель
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(340, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	sc.add_child(side)
	# ---- вид
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(mid)
	var top := HFlowContainer.new()
	mid.add_child(top)
	top.add_child(UI.button("↶ Отмена", do_undo, "Ctrl+Z"))
	top.add_child(UI.button("↷ Повтор", do_redo, "Ctrl+Y"))
	top.add_child(UI.button("Вся карта", func(): dist = world.W * World.C * 0.75 if world else 300.0; target = _map_center(), "Показать карту целиком"))
	top.add_child(UI.button("К штабу", func(): target = World.cell_to_world(world.center); dist = 90.0))
	top.add_child(UI.button("Сверху", func(): pitch = 1.5))
	top.add_child(UI.button("Наклон", func(): pitch = 0.95))
	info_lbl = UI.small("")
	top.add_child(info_lbl)
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vpc.custom_minimum_size = Vector2(400, 300)
	vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	vpc.gui_input.connect(_view_input)
	mid.add_child(vpc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vpc.add_child(vp)
	_build_scene()
	var hint := UI.small("ЛКМ — рисовать · ПКМ — двигать карту · колесо — ближе/дальше · средняя кнопка — повернуть · [ ] — размер кисти · WASD — двигаться")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(hint)


func _ready() -> void:
	_init_gen()
	_build_side()


var _started := false


func _first_world() -> void:
	var wd: Dictionary = DB.data.world
	if str(wd.get("map_mode", "")) == "fixed" and str(wd.get("map_file", "")) != "":
		if open_map(str(wd.map_file)):
			return
	generate()


func refresh() -> void:
	_init_gen()
	_build_side()


var _was_visible := false
var _gen_rev := -1


func _init_gen() -> void:
	_gen_rev = DB.revision
	gen = {}
	for k in GEN_KEYS:
		if DB.data.world.has(k):
			gen[k] = DB.data.world[k]
	gen["seed"] = int(gen.get("seed", 0))


# ---------------------------------------------------------------- сцена

func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.5, 0.78)
	sm.sky_horizon_color = Color(0.7, 0.78, 0.86)
	sm.ground_horizon_color = Color(0.5, 0.55, 0.5)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.86)
	env.fog_density = 0.0004
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-30), 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = 50.0
	vp.add_child(cam)
	world_root = Node3D.new()
	vp.add_child(world_root)
	brush_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.93
	tm.outer_radius = 1.0
	tm.rings = 48
	brush_ring.mesh = tm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.0, 0.8, 0.2)
	bm.no_depth_test = true
	brush_ring.material_override = bm
	brush_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(brush_ring)
	# в редакторе карты конус обзора не нужен
	RenderingServer.global_shader_parameter_set("view_on", 0.0)
	RenderingServer.global_shader_parameter_set("zone_on", 0.0)


func _new_world() -> void:
	if world:
		world.queue_free()
	if hq_marker:
		hq_marker.queue_free()
		hq_marker = null
	world = World.new()
	world_root.add_child(world)


func _after_world() -> void:
	hq_marker = ModelLib.make_node("hq")
	vp.add_child(hq_marker)
	_place_hq_marker()
	world.update_visuals(target)
	_update_info()
	_fill_deps()


## Список руды для кисти — из открытой карты.
func _fill_deps() -> void:
	if dep_opt == null or not is_instance_valid(dep_opt):
		return
	dep_opt.clear()
	var deps: Array = world.deposits if world != null and not world.deposits.is_empty() else DB.data.world.get("deposits", [])
	for i in deps.size():
		dep_opt.add_item(DB.item_name(str(deps[i].get("item", "?"))), i)
	if deps.size() > 0:
		dep_opt.select(clampi(dep_idx, 0, deps.size() - 1))


func _place_hq_marker() -> void:
	if hq_marker and world:
		hq_marker.position = World.cell_to_world(world.center - Vector2i(1, 1)) + Vector3(World.C * 0.5, 0, World.C * 0.5)


func _map_center() -> Vector3:
	return Vector3(world.W * World.C * 0.5, 0, world.W * World.C * 0.5) if world else Vector3.ZERO


func _update_info() -> void:
	if world == null:
		return
	info_lbl.text = "  Карта %d×%d клеток (%d м)%s · объектов %d · гнёзд %d%s" % [world.W, world.W, int(world.W * World.C),
		", без краёв" if world.wrap else ", с краями", world.nodes.size(), world.nests.size(), "  · есть несохранённые правки" if modified else ""]


# ---------------------------------------------------------------- левая панель

func _section(t: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	side.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	pc.add_child(v)
	v.add_child(UI.title(t, 16))
	return v


func _build_side() -> void:
	for c in side.get_children():
		c.queue_free()
	tool_btns.clear()
	# --- файл
	var f := _section("Файл карты")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Название карты"
	name_edit.text = map_name
	name_edit.text_changed.connect(func(t): map_name = t)
	f.add_child(name_edit)
	var g1 := GridContainer.new()
	g1.columns = 2
	f.add_child(g1)
	g1.add_child(UI.button("Сохранить", func(): _with_save(func(_r): pass), "Ctrl+S"))
	g1.add_child(UI.button("Открыть…", _ask_open))
	g1.add_child(UI.button("▶ Играть на ней", play_here, "Сохранить и сразу начать игру на этой карте"))
	g1.add_child(UI.button("Карта игры", set_default, "Новая игра будет начинаться на этой карте"))
	# --- инструменты
	var t := _section("Кисть")
	var tg := GridContainer.new()
	tg.columns = 2
	t.add_child(tg)
	for tl in TOOLS:
		var id: String = tl[0]
		var b := Button.new()
		b.text = tl[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tl[2]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = id == tool
		b.pressed.connect(func(): set_tool(id))
		tg.add_child(b)
		tool_btns[id] = b
	t.add_child(_slider("Размер кисти", 1, 30, radius, 0.5, func(v): radius = v))
	t.add_child(_slider("Сила", 0.05, 1.0, strength, 0.05, func(v): strength = v))
	t.add_child(_slider("Густота объектов", 0.01, 1.0, density, 0.01, func(v): density = v))
	var rh := HBoxContainer.new()
	rh.add_child(UI.small("Объект:"))
	res_btn = Button.new()
	res_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_btn.clip_text = true
	res_btn.text = EdPicker.label_of("resources", res_id)
	res_btn.pressed.connect(func():
		EdPicker.open_for(res_btn, "resources", func(nid):
			if nid != "":
				res_id = nid
				res_btn.text = EdPicker.label_of("resources", nid)
				set_tool("objects")))
	rh.add_child(res_btn)
	t.add_child(rh)
	var dh := HBoxContainer.new()
	dh.add_child(UI.small("Руда:"))
	dep_opt = OptionButton.new()
	dep_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dep_opt.focus_mode = Control.FOCUS_NONE
	# список руды — из открытой карты (у готовой карты свой список месторождений)
	var deps: Array = world.deposits if world != null and not world.deposits.is_empty() else DB.data.world.get("deposits", [])
	for i in deps.size():
		dep_opt.add_item(DB.item_name(str(deps[i].get("item", "?"))), i)
	if deps.size() > 0:
		dep_opt.select(clampi(dep_idx, 0, deps.size() - 1))
	dep_opt.item_selected.connect(func(i): dep_idx = i; set_tool("dep_one"))
	dh.add_child(dep_opt)
	t.add_child(dh)
	# качество залежи (бедная / нормальная / богатая / легендарная) — «Настройки» → «Качество залежей»
	var ph := HBoxContainer.new()
	ph.add_child(UI.small("Качество:"))
	pur_opt = OptionButton.new()
	pur_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pur_opt.focus_mode = Control.FOCUS_NONE
	pur_opt.add_item("Случайное", 0)
	pur_opt.set_item_metadata(0, "")
	var lv = DB.data.settings.get("purity", [])
	for i in (lv.size() if lv is Array else 0):
		pur_opt.add_item("%s — %d/мин" % [str(lv[i].get("name", lv[i].get("id", "?"))), int(float(lv[i].get("per_min", 0)))], i + 1)
		pur_opt.set_item_metadata(i + 1, str(lv[i].get("id", "")))
	pur_opt.item_selected.connect(func(i): pur_id = str(pur_opt.get_item_metadata(i)); set_tool("dep_one"))
	ph.add_child(pur_opt)
	t.add_child(ph)
	# --- новая карта
	var n := _section("Новая карта")
	var nl := UI.small("Случайная карта строится по этим настройкам. Потом её можно дорисовать кистями. Эти же настройки — для случайной карты в игре.")
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_child(nl)
	var flds := []
	for fd in EdSchema.fields("world"):
		if fd[0] in GEN_KEYS:
			flds.append(fd)
	var form := EdForm.make(gen, flds, false, 150)
	n.add_child(form)
	var g2 := GridContainer.new()
	g2.columns = 2
	n.add_child(g2)
	g2.add_child(UI.button("Сгенерировать", func(): _confirm_lose(generate), "Новая случайная карта (с другим зерном, если зерно 0)"))
	g2.add_child(UI.button("Пустая карта", func(): _confirm_lose(new_empty), "Только трава — рисуйте всё сами"))
	var ap := UI.button("Сделать случайной картой игры", func():
		var wd: Dictionary = DB.data.world.duplicate(true)
		wd.merge(gen, true)
		wd["map_mode"] = "procedural"
		DB.save_object("world", "", wd)
		ed.content_changed()
		ed.set_status("Новая игра будет на случайной карте с этими настройками"), "Сохранить настройки в игру")
	n.add_child(ap)


func _slider(t: String, lo: float, hi: float, v: float, step: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := UI.small(t)
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	var vl := UI.small(str(v))
	vl.custom_minimum_size = Vector2(36, 0)
	s.value_changed.connect(func(x):
		vl.text = str(snappedf(x, 0.01))
		cb.call(x))
	h.add_child(s)
	h.add_child(vl)
	h.set_meta("slider", s)
	return h


func set_tool(id: String) -> void:
	tool = id
	for k in tool_btns:
		tool_btns[k].button_pressed = k == id
	var col := Color(1.0, 0.8, 0.2)
	if id.begins_with("erase"):
		col = Color(1.0, 0.35, 0.3)
	elif id == "water":
		col = Color(0.3, 0.7, 1.0)
	(brush_ring.material_override as StandardMaterial3D).albedo_color = col


func _confirm_lose(cb: Callable) -> void:
	if modified:
		ed.confirm("На карте есть несохранённые правки. Продолжить без сохранения?", cb)
	else:
		cb.call()


# ---------------------------------------------------------------- создание и файлы

func generate() -> void:
	ed.set_status("Строю карту…")
	_new_world()
	var ov := gen.duplicate()
	var sd := int(ov.get("seed", 0))
	ov["seed"] = sd if sd != 0 else rng.randi_range(1, 999999)
	world.generate(int(ov.seed), ov)
	_bound_file = ""
	undo.clear()
	redo.clear()
	modified = false
	target = World.cell_to_world(world.center)
	dist = 140.0
	_after_world()
	ed.set_status("Карта готова (зерно %d)" % int(ov.seed))


func new_empty() -> void:
	_new_world()
	world.make_empty(int(gen.get("size", 384)), bool(gen.get("wrap", true)))
	_bound_file = ""
	undo.clear()
	redo.clear()
	modified = false
	target = _map_center()
	dist = 140.0
	_after_world()
	ed.set_status("Пустая карта %d×%d" % [world.W, world.W])


func _maps_dir() -> String:
	return DB.edit_target.path_join("maps")


func _map_rel() -> String:
	var nm := map_name.strip_edges().validate_filename().replace(" ", "_")
	if nm == "":
		nm = "моя_карта"
	return "maps/" + nm + ".json"


func save_map() -> String:
	if world == null:
		return ""
	DirAccess.make_dir_recursive_absolute(_maps_dir())
	var rel := _map_rel()
	var m := world.to_map()
	m["name"] = map_name
	DB.write_file(DB.edit_target.path_join(rel), m)
	_bound_file = rel
	modified = false
	_update_info()
	ed.set_status("Карта сохранена: " + rel)
	return rel


func open_map(rel: String) -> bool:
	var m = DB.read_file(DB.find_file(rel))
	if not m is Dictionary:
		ed.set_status("Не удалось открыть карту " + rel)
		return false
	_load_world(m)
	map_name = rel.get_file().get_basename()
	_bound_file = _map_rel()
	if name_edit:
		name_edit.text = map_name
	undo.clear()
	redo.clear()
	modified = false
	target = World.cell_to_world(world.center)
	dist = 140.0
	_update_info()
	ed.set_status("Открыта карта " + rel)
	return true


func _load_world(m: Dictionary) -> void:
	_new_world()
	world.load_map(m)
	_after_world()


func _list_maps() -> Array:
	var out := []
	var seen := {}
	for l in DB.layers:
		var d := DirAccess.open(str(l.path).path_join("maps"))
		if d == null:
			continue
		for fn in d.get_files():
			if fn.ends_with(".json") and not seen.has(fn):
				seen[fn] = true
				out.append("maps/" + fn)
	var d2 := DirAccess.open(_maps_dir())
	if d2:
		for fn in d2.get_files():
			if fn.ends_with(".json") and not seen.has(fn):
				out.append("maps/" + fn)
	return out


func _ask_open() -> void:
	var maps := _list_maps()
	if maps.is_empty():
		ed.info("Карт пока нет", "Сохраните карту — она появится здесь.")
		return
	var d := ConfirmationDialog.new()
	d.title = "Открыть карту"
	d.ok_button_text = "Открыть"
	d.cancel_button_text = "Отмена"
	var il := ItemList.new()
	il.custom_minimum_size = Vector2(420, 300)
	for m in maps:
		il.add_item(str(m).get_file().get_basename())
	il.select(0)
	d.add_child(il)
	add_child(d)
	var go := func():
		var s := il.get_selected_items()
		if s.size() > 0:
			var rel: String = maps[s[0]]
			_confirm_lose(func(): open_map(rel))
		d.queue_free()
	d.confirmed.connect(go)
	il.item_activated.connect(func(_i): go.call())
	d.canceled.connect(d.queue_free)
	d.popup_centered()


func set_default() -> void:
	_with_save(_set_default_rel)


func _set_default_rel(rel: String) -> void:
	var wd: Dictionary = DB.data.world.duplicate(true)
	wd["map_mode"] = "fixed"
	wd["map_file"] = rel
	DB.save_object("world", "", wd)
	ed.content_changed()
	ed.set_status("Теперь новая игра начинается на карте «%s»" % map_name)


func play_here() -> void:
	_with_save(func(rel): ed.play_test({"map_mode": "fixed", "map_file": rel}))


## Сохранить и продолжить. Если файл с таким названием уже есть и это другая карта — сначала спросить.
var _bound_file := ""


func _with_save(then: Callable) -> void:
	if world == null:
		return
	var rel := _map_rel()
	if rel != _bound_file and FileAccess.file_exists(DB.edit_target.path_join(rel)):
		ed.confirm("Карта «%s» уже есть. Заменить её этой картой?\n(Чтобы сохранить обе — поменяйте название сверху.)" % map_name, func():
			var r := save_map()
			if r != "":
				then.call(r))
		return
	var r2 := save_map()
	if r2 != "":
		then.call(r2)


# ---------------------------------------------------------------- отмена

func _push_undo() -> void:
	undo.append(world.to_map())
	if undo.size() > 15:
		undo.pop_front()
	redo.clear()


func do_undo() -> void:
	if undo.is_empty() or world == null:
		return
	redo.append(world.to_map())
	var t := target
	_load_world(undo.pop_back())
	target = t
	ed.set_status("Отменено")


func do_redo() -> void:
	if redo.is_empty() or world == null:
		return
	undo.append(world.to_map())
	var t := target
	_load_world(redo.pop_back())
	target = t


# ---------------------------------------------------------------- ввод и кисти

func _process(delta: float) -> void:
	if cam == null:
		return
	if not _started and is_visible_in_tree():
		# карта строится только когда вкладку открыли — редактор запускается быстрее
		_started = true
		_first_world()
	# вкладку снова открыли — берём свежие настройки мира (их могли поменять во вкладке «Данные»)
	var vis := is_visible_in_tree()
	if vis and not _was_visible and _started and _gen_rev != DB.revision:
		refresh()
	_was_visible = vis
	if is_visible_in_tree() and vpc.get_global_rect().has_point(get_global_mouse_position()) and not get_viewport().gui_get_focus_owner() is LineEdit:
		var mv := Vector3.ZERO
		if Input.is_key_pressed(KEY_W): mv.z -= 1
		if Input.is_key_pressed(KEY_S): mv.z += 1
		if Input.is_key_pressed(KEY_A): mv.x -= 1
		if Input.is_key_pressed(KEY_D): mv.x += 1
		if mv != Vector3.ZERO:
			target += mv.normalized().rotated(Vector3.UP, yaw) * dist * delta * 0.8
	pitch = clampf(pitch, 0.25, 1.52)
	dist = clampf(dist, 12.0, 3000.0)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP if pitch < 1.5 else Vector3(-sin(yaw), 0, -cos(yaw)))
	if world:
		world.update_visuals(target)
	brush_ring.visible = _cursor_ok
	if _cursor_ok:
		var r := radius * World.C if not tool in ["erase_nest", "start", "dep_one"] else 7.0 * World.C * 0.5
		brush_ring.position = World.cell_to_world(_cursor_cell) + Vector3(0, 0.3 + world.h_cell(_cursor_cell), 0)
		brush_ring.scale = Vector3(r, 1.0, r)
	if _painting:
		_paint_t -= delta
		if _paint_t <= 0.0:
			_paint_t = 0.06
			_apply()


func _ray_cell(mp: Vector2) -> bool:
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return false
	var t := -o.y / d.y
	if t < 0:
		return false
	var p := o + d * t
	if world:
		for i in 6:
			t = (world.height_at(p) - o.y) / d.y
			if t <= 0.0:
				break
			p = o + d * t
	_cursor_cell = World.world_to_cell(p)
	if world and not world.in_bounds(_cursor_cell):
		return false
	return true


func _view_input(ev: InputEvent) -> void:
	if world == null:
		return
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		_cursor_ok = _ray_cell(mm.position)
		if _pan:
			var k := dist * 0.0016
			target += Vector3(-mm.relative.x * k, 0, -mm.relative.y * k / maxf(0.4, sin(pitch))).rotated(Vector3.UP, yaw)
		elif _orbit:
			yaw -= mm.relative.x * 0.008
			pitch += mm.relative.y * 0.006
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed and _cursor_ok:
					_begin_stroke()
				elif not mb.pressed and _painting:
					_painting = false
					_update_info()
			MOUSE_BUTTON_RIGHT:
				_pan = mb.pressed
			MOUSE_BUTTON_MIDDLE:
				_orbit = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					dist *= 0.88
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					dist *= 1.13
	elif ev is InputEventKey and ev.pressed:
		var k := ev as InputEventKey
		if k.ctrl_pressed and k.keycode == KEY_Z:
			do_undo()
		elif k.ctrl_pressed and k.keycode == KEY_Y:
			do_redo()
		elif k.ctrl_pressed and k.keycode == KEY_S:
			_with_save(func(_r): pass)
		elif k.keycode == KEY_BRACKETLEFT:
			radius = maxf(1.0, radius - 1.0)
		elif k.keycode == KEY_BRACKETRIGHT:
			radius = minf(30.0, radius + 1.0)


func _begin_stroke() -> void:
	_push_undo()
	world.edited = true
	_stroke.clear()
	modified = true
	if tool in ["erase_nest", "start", "dep_one"]:
		_apply()
		_update_info()
		return
	_level = world.h_cell(_cursor_cell)
	_painting = true
	_paint_t = 0.0


## Применить кисть в точке курсора.
func _apply() -> void:
	if not _cursor_ok:
		return
	var c := _cursor_cell
	match tool:
		"dirt", "sand", "rock", "snow", "grass":
			world.paint_splat(c, radius, CHANNEL[tool], strength * 0.5)
		"raise", "lower", "flatten", "smooth":
			world.paint_height(c, radius, tool, strength, _level)
		"water", "land":
			world.paint_water(c, radius, tool == "water")
			if tool == "water":
				for p in _cells(c, radius):
					world.set_deposit(p, -1)
		"objects", "erase_obj", "deposit", "erase_dep":
			for p in _cells(c, radius):
				var w := World.wc(p)
				if _stroke.has(w):
					continue
				_stroke[w] = true
				match tool:
					"objects":
						if rng.randf() < density and not world.water_at(w) and not world.deposit.has(w) and not world.nest_cells.has(w):
							world.add_node(res_id, w)
					"erase_obj":
						world.remove_node(w)
					"deposit":
						if not world.water_at(w) and dep_idx < world.deposits.size():
							world.set_deposit(w, dep_idx)
					"erase_dep":
						world.set_deposit(w, -1)
			if tool == "deposit" and dep_idx >= world.deposits.size():
				ed.set_status("Такого месторождения нет в настройках мира (вкладка «Данные» → Мир)")
		"dep_one":
			if dep_idx < world.deposits.size() and not world.water_at(c):
				var fp := maxi(1, int(world.deposits[dep_idx].get("cells", 1)))
				var pu := pur_id if pur_id != "" else world._pick_purity(c, world.deposits[dep_idx], false)
				for dx in fp:
					for dz in fp:
						world.remove_node(c + Vector2i(dx, dz))
						world.set_deposit(c + Vector2i(dx, dz), dep_idx)
						if not DB.is_fluid(str(world.deposits[dep_idx].get("item", ""))):
							world.set_purity(c + Vector2i(dx, dz), pu)
		"erase_nest":
			var best := -1
			var bd := 8.0
			for i in world.nests.size():
				var d := World.dist(World.cell_to_world(world.nests[i].cell), World.cell_to_world(c)) / World.C
				if d < bd:
					bd = d
					best = i
			world.remove_nest(best)
		"start":
			world.center = c
			for p in _cells(c, 4):
				world.remove_node(p)
			_place_hq_marker()


func _cells(c: Vector2i, r: float) -> Array:
	var out := []
	var ri := ceili(r)
	for dx in range(-ri, ri + 1):
		for dz in range(-ri, ri + 1):
			if Vector2(dx, dz).length() <= r:
				out.append(c + Vector2i(dx, dz))
	return out


## Проверка: рисует всеми кистями возле штаба, сохраняет и открывает карту заново.
func _test_paint() -> void:
	var c0 := world.center
	var plan := [["water", Vector2i(14, 0), 4.0], ["sand", Vector2i(14, 6), 5.0], ["rock", Vector2i(-12, 8), 4.0],
		["snow", Vector2i(-12, -10), 4.0], ["objects", Vector2i(0, -14), 6.0], ["dep_one", Vector2i(8, -8), 1.0],
		["erase_obj", Vector2i(0, -14), 2.0]]
	for st in plan:
		set_tool(st[0])
		radius = st[2]
		density = 0.6
		_cursor_cell = c0 + st[1]
		_cursor_ok = true
		_begin_stroke()
		for i in 4:
			_apply()
		_painting = false
	var objs := world.nodes.size()
	var nests := world.nests.size()
	map_name = "test_map"
	var rel := save_map()
	open_map(rel)
	var dep_ok := world.deposit_item(c0 + Vector2i(8, -8)) != "" and world.deposit_item(c0 + Vector2i(9, -8)) == ""
	print("MAPTEST objects ", objs, " -> ", world.nodes.size(), " nests ", nests, " -> ", world.nests.size(), " water ", world.water_at(c0 + Vector2i(14, 0)),
		" deposit ", world.deposit_item(c0 + Vector2i(8, -8)), " one_cell ", dep_ok, " ", "OK" if objs == world.nodes.size() and nests == 0 and dep_ok and world.water_at(c0 + Vector2i(14, 0)) else "FAIL")
	target = World.cell_to_world(c0)
	dist = 70.0
	_cursor_ok = false


## Для снимка: кистью рельефа насыпать холм у штаба и выровнять площадку.
func _demo_relief() -> void:
	if world == null:
		_started = true
		_first_world()
	var c0 := world.center + Vector2i(14, -6)
	_cursor_ok = true
	for st in [["raise", 9.0, 10], ["raise", 5.0, 6], ["flatten", 3.0, 6], ["smooth", 10.0, 2]]:
		set_tool(st[0])
		radius = st[1]
		_cursor_cell = c0
		_begin_stroke()
		for i in st[2]:
			_apply()
		_painting = false
	set_tool("raise")
	radius = 9.0
	target = World.cell_to_world(c0)
	dist = 70.0
	pitch = 0.5
	_cursor_cell = c0
