extends HSplitContainer
## Редактор моделей «как конструктор»: без навыков 3D.
## Модель собирается из готовых деталей и фигур, красится готовыми материалами,
## зеркалится и размножается, а кнопка «Сделать красиво» добавляет скосы, контур и оттенки.
##
## Управление в окне просмотра:
##   ЛКМ по детали — выбрать (Shift — добавить к выбору), ЛКМ+тянуть — двигать по горизонтали,
##   Alt+тянуть — вверх-вниз, Ctrl+тянуть — размер, ПКМ — крутить камеру, колесо — приблизить,
##   стрелки / PgUp / PgDn — сдвиг, Del — удалить, Ctrl+D — копия, Ctrl+Z / Ctrl+Y — отмена/повтор.

var ed
var cur_id := ""
var model: Dictionary = {}
var sel: Array = []            # индексы выбранных деталей
var undo: Array = []
var redo: Array = []
var snap := true
var snap_step := 0.05

# левая колонка
var list: ItemList
var ids: Array = []
var search: LineEdit
# просмотр
var vpc: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var sel_lines: MeshInstance3D
var sun: DirectionalLight3D
var env: Environment
var cam_yaw := 0.7
var cam_pitch := 0.5
var cam_dist := 6.0
var cam_target := Vector3(0, 0.8, 0)
var auto_spin := false
var hint: Label
# правая колонка
var props: VBoxContainer
var props_scroll: ScrollContainer

var _drag := ""
var _drag_from := Vector2.ZERO
var _drag_start: Array = []
var _orbit := false
var _changed_t := -1.0
var _rebuild_needed := false

const MATERIAL_PRESETS := [
	["Металл", {"mat": "metal", "color": "#9aa3ad"}],
	["Тёмный металл", {"mat": "dark", "color": "#3a3e45"}],
	["Ржавчина", {"mat": "paint", "color": "#8a4b2a", "roughness": 0.9, "metallic": 0.35}],
	["Краска", {"mat": "paint", "color": "#f2a81f"}],
	["Пластик", {"mat": "paint", "color": "#e6e6e6", "roughness": 0.35, "metallic": 0.0}],
	["Бетон", {"mat": "concrete", "color": "#c8c4b8"}],
	["Камень", {"mat": "stone", "color": "#8d8a84"}],
	["Дерево", {"mat": "wood", "color": "#a87a4a"}],
	["Кора", {"mat": "wood", "color": "#5a3d22"}],
	["Листва", {"mat": "leaf", "color": "#4f8a3a"}],
	["Стекло", {"mat": "glass", "color": "#a8d8ff"}],
	["Светится", {"mat": "glow", "color": "#ffd040"}],
	["Живое", {"mat": "flesh", "color": "#7a9a3a"}],
	["Грязь", {"mat": "stone", "color": "#5c4a36", "roughness": 1.0}],
	["Ткань", {"mat": "cloth", "color": "#3a4a5c"}],
]
const PALETTE := ["#f2a81f", "#ff7a2f", "#e04a3a", "#c23d6b", "#7a4ad1", "#3a6ad1", "#3aa8d1", "#3ad1a8", "#4f8a3a", "#8ac43a",
	"#e6d23a", "#ffffff", "#c0c4cc", "#8a9099", "#5a5f68", "#2a2d33", "#a87a4a", "#6b4a2b", "#d9c28c", "#ffd040"]


func _init(editor) -> void:
	ed = editor
	split_offset = 260
	# ---- левая колонка: список моделей
	var lv := VBoxContainer.new()
	lv.custom_minimum_size = Vector2(250, 0)
	add_child(lv)
	search = LineEdit.new()
	search.placeholder_text = "Поиск модели"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_t): _fill_list())
	lv.add_child(search)
	var sp := CheckBox.new()
	sp.text = "Показывать готовые детали"
	sp.focus_mode = Control.FOCUS_NONE
	sp.tooltip_text = "Детали из библиотеки тоже можно править и дополнять"
	sp.toggled.connect(func(on): show_parts = on; _fill_list())
	lv.add_child(sp)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(32, 32)
	list.item_selected.connect(func(i): open(ids[i]))
	lv.add_child(list)
	var lb := GridContainer.new()
	lb.columns = 2
	lv.add_child(lb)
	lb.add_child(UI.button("Новая из шаблона…", _new_from_template, "Начать с готовой модели: дерево, бур, монстр..."))
	lb.add_child(UI.button("Пустая", _new_empty))
	lb.add_child(UI.button("Копия", _duplicate_model))
	lb.add_child(UI.button("Удалить", _delete_model))
	lv.add_child(UI.button("Назначить модель…", _assign, "Сделать эту модель видом предмета, здания, дерева или монстра"))
	# ---- середина и правая часть
	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right_split)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(mid)
	mid.add_child(_toolbar())
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vpc.custom_minimum_size = Vector2(400, 300)
	vpc.gui_input.connect(_view_input)
	vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	mid.add_child(vpc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.positional_shadow_atlas_size = 1024
	vpc.add_child(vp)
	_build_scene()
	hint = UI.small("ЛКМ — выбрать и двигать · Alt — вверх/вниз · Ctrl — размер · Shift — несколько · ПКМ — камера · колесо — зум · Del, Ctrl+D, Ctrl+Z")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(hint)
	props_scroll = ScrollContainer.new()
	props_scroll.custom_minimum_size = Vector2(430, 0)
	props_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_split.add_child(props_scroll)
	props = VBoxContainer.new()
	props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	props_scroll.add_child(props)


func _ready() -> void:
	Icons.baked.connect(func(_k): list.queue_redraw())
	_fill_list()
	if cur_id == "" and not ids.is_empty():
		open(ids[0])


func refresh() -> void:
	_fill_list()
	if not DB.data.models.has(cur_id):
		cur_id = ""
		if not ids.is_empty():
			open(ids[0])
	else:
		open(cur_id)


# ---------------------------------------------------------------- панель кнопок

func _toolbar() -> Control:
	var v := HFlowContainer.new()
	v.add_theme_constant_override("h_separation", 4)
	v.add_theme_constant_override("v_separation", 4)
	var r1 := v
	var add := MenuButton.new()
	add.text = "+ Фигура"
	add.flat = false
	add.tooltip_text = "Добавить простую фигуру"
	for i in ModelLib.SHAPES.size():
		add.get_popup().add_item(ModelLib.SHAPE_NAMES[i], i)
	add.get_popup().id_pressed.connect(func(i): add_part({"shape": ModelLib.SHAPES[i]}))
	r1.add_child(add)
	r1.add_child(UI.button("+ Готовая деталь…", _add_library, "Трубы, баки, шестерни, окна, ветки, лапы, глаза..."))
	r1.add_child(UI.button("Нейросеть / автоскелет…", _neuro, "Модель по описанию (нейросеть на этом компьютере) или из готового файла GLB — скелет и анимации добавятся сами"))
	r1.add_child(UI.button("Копия", duplicate_sel, "Ctrl+D"))
	r1.add_child(UI.button("Удалить", delete_sel, "Del"))
	r1.add_child(UI.button("Зеркало ↔", func(): mirror_sel(0), "Повторить деталь с другой стороны (по оси X)"))
	r1.add_child(UI.button("Зеркало ↕", func(): mirror_sel(2), "Повторить деталь с другой стороны (по оси Z)"))
	r1.add_child(UI.button("По кругу…", _ask_ring, "Размножить выбранное по кругу (колёса, лопасти, шипы)"))
	r1.add_child(UI.button("В ряд…", _ask_row, "Размножить выбранное в ряд (окна, трубы, забор)"))
	var r2 := v
	r2.add_child(UI.button("↶ Отмена", do_undo, "Ctrl+Z"))
	r2.add_child(UI.button("↷ Повтор", do_redo, "Ctrl+Y"))
	r2.add_child(UI.button("✨ Сделать красиво", beautify, "Скосы на гранях, контур, лёгкие оттенки и износ, модель встаёт на землю"))
	r2.add_child(UI.button("На землю", ground, "Поставить модель ровно на землю"))
	r2.add_child(UI.button("В центр", center_model, "Сдвинуть модель в центр"))
	r2.add_child(UI.button("Сохранить группу как деталь", save_group_as_part, "Выделенные детали станут вашей готовой деталью"))
	var sc := CheckBox.new()
	sc.text = "Привязка"
	sc.button_pressed = snap
	sc.focus_mode = Control.FOCUS_NONE
	sc.tooltip_text = "Двигать по сетке 5 см и поворачивать по 15°"
	sc.toggled.connect(func(on): snap = on)
	r2.add_child(sc)
	var r3 := v
	r3.add_child(UI.small("Свет:"))
	for pr in [["День", 0], ["Закат", 1], ["Ночь", 2]]:
		var k: int = pr[1]
		r3.add_child(UI.button(pr[0], func(): _light(k)))
	var spin := CheckBox.new()
	spin.text = "Крутить"
	spin.focus_mode = Control.FOCUS_NONE
	spin.toggled.connect(func(on): auto_spin = on)
	r3.add_child(spin)
	var work := CheckBox.new()
	work.text = "Здание работает"
	work.button_pressed = true
	work.focus_mode = Control.FOCUS_NONE
	work.tooltip_text = "Показать анимации и дым, как у работающего здания"
	work.toggled.connect(func(on): _working = on; _rebuild_preview())
	r3.add_child(work)
	var mv := OptionButton.new()
	mv.focus_mode = Control.FOCUS_NONE
	mv.tooltip_text = "Проверить скелет: модель шагает на месте, бьёт или умирает (только у моделей со скелетом)"
	for nm in ["Покой", "Ходьба", "Бег", "Удар", "Смерть"]:
		mv.add_item(nm)
	mv.item_selected.connect(func(i): _motion = i; _rebuild_preview())
	r3.add_child(mv)
	r3.add_child(UI.button("Вид сбоку", func(): cam_yaw = 0.0; cam_pitch = 0.05))
	r3.add_child(UI.button("Сверху", func(): cam_pitch = 1.45))
	r3.add_child(UI.button("3/4", func(): cam_yaw = 0.7; cam_pitch = 0.5))
	return v


var _working := true
var _glb_playing := ""
var _motion := 0          # 0 покой, 1 ходьба, 2 бег, 3 удар, 4 смерть
var _rig_node: Node3D = null
var _rig_x := 0.0
var _rig_t := 0.0
const CreatureRig = preload("res://scripts/creature_rig.gd")


# ---------------------------------------------------------------- сцена просмотра

func _build_scene() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.55, 0.85)
	sm.sky_horizon_color = Color(0.75, 0.82, 0.9)
	sm.ground_bottom_color = Color(0.2, 0.22, 0.2)
	sm.ground_horizon_color = Color(0.6, 0.65, 0.65)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 45
	vp.add_child(cam)
	# земля с сеткой в 1 клетку (2 м)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(24, 24)
	g.mesh = pm
	var gm := ShaderMaterial.new()
	var gs := Shader.new()
	gs.code = """shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex(){ wp = VERTEX; }
void fragment(){
	vec2 c = abs(fract(wp.xz / 2.0 + 0.5) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.02, min(c.x, c.y));
	vec2 m = abs(fract(wp.xz * 2.0 + 0.5) - 0.5);
	float minor = 1.0 - smoothstep(0.0, 0.03, min(m.x, m.y));
	float fade = 1.0 - smoothstep(4.0, 11.0, length(wp.xz));
	ALBEDO = mix(vec3(0.32, 0.42, 0.28), vec3(0.85, 0.9, 1.0), (line * 0.5 + minor * 0.08) * fade);
	ROUGHNESS = 0.95;
}"""
	gm.shader = gs
	g.material_override = gm
	vp.add_child(g)
	holder = Node3D.new()
	vp.add_child(holder)
	sel_lines = MeshInstance3D.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 0.75, 0.2)
	lm.no_depth_test = true
	lm.vertex_color_use_as_albedo = true
	sel_lines.material_override = lm
	vp.add_child(sel_lines)


func _light(k: int) -> void:
	match k:
		0:
			sun.light_color = Color(1, 0.97, 0.92)
			sun.light_energy = 1.3
			sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
			env.ambient_light_energy = 0.8
			env.background_energy_multiplier = 1.0
		1:
			sun.light_color = Color(1, 0.6, 0.35)
			sun.light_energy = 1.1
			sun.rotation = Vector3(deg_to_rad(-12), deg_to_rad(-60), 0)
			env.ambient_light_energy = 0.45
			env.background_energy_multiplier = 0.6
		2:
			sun.light_color = Color(0.5, 0.6, 1.0)
			sun.light_energy = 0.25
			sun.rotation = Vector3(deg_to_rad(-60), deg_to_rad(20), 0)
			env.ambient_light_energy = 0.18
			env.background_energy_multiplier = 0.15


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if auto_spin and _drag == "" and not _orbit:
		cam_yaw += delta * 0.5
	var dir := Vector3(cos(cam_pitch) * sin(cam_yaw), sin(cam_pitch), cos(cam_pitch) * cos(cam_yaw))
	cam.position = cam_target + dir * cam_dist
	cam.look_at(cam_target, Vector3.UP)
	if _rebuild_needed:
		_rebuild_needed = false
		_rebuild_preview()
	_animate_rig(delta)
	if _changed_t >= 0.0:
		_changed_t -= delta
		if _changed_t < 0.0:
			_save()


## Просмотр скелета: модель идёт на месте (фаза шага считается от «пройденного» пути), бьёт или умирает.
func _animate_rig(delta: float) -> void:
	if _rig_node == null or not is_instance_valid(_rig_node):
		return
	_rig_t += delta
	var spd: float = [0.0, 3.0, 7.0, 0.0, 0.0][_motion]
	_rig_x += spd * delta
	var wind := 0.0
	if _motion == 3:
		var c := fmod(_rig_t, 1.6)
		wind = clampf(c / 0.9, 0.0, 1.0) if c < 0.9 else 0.0
		if c >= 0.9 and c - delta < 0.9:
			_rig_node.strike()
	if _motion == 4 and _rig_t > 5.0:
		_rebuild_preview()
		return
	_rig_node.animate(delta, Vector3(_rig_x, 0, 0), 0.0, float(model.get("scale", 1.0)), {"speed": maxf(spd, 3.0), "windup": wind, "flash": 0.0, "target_dir": Vector3.ZERO})
	_rig_node.position = Vector3.ZERO


# ---------------------------------------------------------------- открыть / сохранить

## Записать несохранённое прямо сейчас (перед закрытием редактора или запуском игры).
func flush() -> void:
	if _changed_t >= 0.0:
		_changed_t = -1.0
		_save()


var show_parts := false


func _fill_list() -> void:
	list.clear()
	ids.clear()
	var q := search.text.strip_edges().to_lower()
	var keys: Array = DB.data.models.keys()
	keys.sort_custom(func(a, b):
		var ca := str(DB.data.models[a].get("category", ""))
		var cb := str(DB.data.models[b].get("category", ""))
		if ca != cb:
			return ca < cb
		return str(DB.data.models[a].get("name", a)) < str(DB.data.models[b].get("name", b)))
	for id in keys:
		var m: Dictionary = DB.data.models[id]
		if not show_parts and str(m.get("library", "")) == "part" and id != cur_id:
			continue
		var nm := "%s · %s" % [m.get("category", ""), m.get("name", id)]
		if q != "" and not (q in str(id).to_lower() or q in nm.to_lower()):
			continue
		list.add_item(str(m.get("name", id)), Icons.get_icon("model:" + id))
		list.set_item_tooltip(list.item_count - 1, "%s\nid: %s" % [nm, id])
		ids.append(id)
		if id == cur_id:
			list.select(list.item_count - 1)


func open(id: String) -> void:
	if _changed_t >= 0.0:
		_changed_t = -1.0
		_save()
	if not DB.data.models.has(id):
		return
	cur_id = id
	model = DB.data.models[id]
	_glb_seen = str(model.get("glb", ""))
	if not model.get("parts") is Array:
		model["parts"] = []
	sel.clear()
	undo.clear()
	redo.clear()
	_fit_camera()
	_rebuild_preview()
	_show_props()
	var idx := ids.find(id)
	if idx >= 0:
		list.select(idx)


var _glb_seen := ""

## Выбрали готовую модель: проверяем файл, подгоняем размер (2 м высоты, если она огромная или крошечная),
## ставим на землю по центру, убираем стартовый кубик пустой модели и наводим камеру.
func _on_glb_set() -> void:
	var rel := str(model.get("glb", ""))
	_glb_seen = rel
	if rel == "":
		_fit_camera()
		return
	ModelLib._glb.erase(rel)
	ModelLib._glb.erase(rel + "|raw")
	var why := ModelLib.glb_problem(rel)
	if why != "":
		ed.info("Модель не загрузилась", "Файл «%s»: %s." % [rel.get_file(), why])
		ed.set_status("GLB не загрузился: " + why)
		return
	var parts: Array = model.get("parts", [])
	if parts.size() == 1 and str(parts[0].get("shape", "")) == "box" and str(parts[0].get("color", "")) == "#c0c4cc":
		model["parts"] = []
	ModelLib.glb_fit(model, rel)
	var note := str(model.get("note", ""))
	model.erase("note")
	if note == "bad":
		ed.info("Модель не загрузилась", "Файл «%s»: не удалось понять размер модели (сетка пустая или испорчена). Откройте её в Blender и сохраните заново как .glb." % rel.get_file())
		return
	var msg := "GLB-модель загружена" + note
	var raw_note := ""
	_fit_camera()
	_rebuild_needed = true
	ed.set_status(msg + raw_note)
	_show_props.call_deferred()


func _fit_camera() -> void:
	var box := _model_aabb()
	cam_target = box.get_center()
	cam_dist = clampf(box.size.length() * 1.6 + 1.5, 2.5, 30.0)


func _model_aabb() -> AABB:
	var box := AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	var first := true
	var gs := float(model.get("scale", 1.0))
	var glb := str(model.get("glb", ""))
	var raw := bool(model.get("glb_raw", false))
	if glb != "" and not ModelLib._glb_parts(glb, raw).is_empty():
		box = Transform3D(Basis.from_scale(Vector3.ONE * gs), Vector3.ZERO) * ModelLib.glb_offset(model) * ModelLib.glb_aabb(glb, raw)
		first = false
	for p in model.get("parts", []):
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * gs), Vector3.ZERO) * ModelLib.part_xform(p)
		var b := xf * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		box = b if first else box.merge(b)
		first = false
	return box


func _changed(push_undo := true) -> void:
	if push_undo:
		_push_undo()
	_rebuild_needed = true
	_changed_t = 0.5
	ed.set_status("Есть несохранённые правки…")


func _save() -> void:
	if cur_id == "":
		return
	DB.save_object("models", cur_id, model)
	ed.set_status("Модель сохранена")
	ed.content_changed()


func _push_undo() -> void:
	undo.append(JSON.stringify(_snapshot_before))
	if undo.size() > 80:
		undo.pop_front()
	redo.clear()
	_snapshot_before = model.duplicate(true)


var _snapshot_before: Dictionary = {}


func _begin_edit() -> void:
	_snapshot_before = model.duplicate(true)


func do_undo() -> void:
	if undo.is_empty():
		return
	redo.append(JSON.stringify(model))
	_restore(JSON.parse_string(undo.pop_back()))


func do_redo() -> void:
	if redo.is_empty():
		return
	undo.append(JSON.stringify(model))
	_restore(JSON.parse_string(redo.pop_back()))


func _restore(d) -> void:
	if not d is Dictionary:
		return
	model.clear()
	model.merge(d, true)
	sel = sel.filter(func(i): return i < model.parts.size())
	_snapshot_before = model.duplicate(true)
	_rebuild_needed = true
	_changed_t = 0.5
	_show_props()


# ---------------------------------------------------------------- просмотр

func _rebuild_preview() -> void:
	for c in holder.get_children():
		c.queue_free()
	if cur_id == "":
		return
	_rig_node = null
	if model.has("rig"):
		var r := CreatureRig.new()
		if r.build(cur_id):
			holder.add_child(r)
			_rig_node = r
			_rig_x = 0.0
			_rig_t = 0.0
			if _motion == 4:
				r.die(1.0)
			_draw_selection()
			return
		r.free()
	# готовая модель со своими анимациями: показываем файл целиком и проигрываем анимацию выбранного движения
	var gp := str(model.get("glb", ""))
	if gp != "" and bool(model.get("glb_animate", true)) and not ModelLib.glb_anims(gp).is_empty():
		var gn := ModelLib.glb_instance(gp)
		if gn:
			var gs := float(model.get("scale", 1.0))
			gn.transform = Transform3D(Basis.from_scale(Vector3.ONE * gs), Vector3.ZERO) * ModelLib.glb_offset(model)
			holder.add_child(gn)
			var ap := ModelLib.glb_player(gn)
			var st: String = ["idle", "walk", "run", "attack", "die"][_motion]
			var nm := ModelLib.glb_anim_for(model, st, ModelLib.glb_anims(gp))
			if nm == "" and st in ["walk", "run"]:
				nm = ModelLib.glb_anims(gp)[0]
			_glb_playing = nm
			if ap and nm != "":
				if st in ["idle", "walk", "run"]:
					ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
				ap.play(nm)
			# детали поверх файла (свои фигуры) показываем как обычно, сетки самого файла — уже есть выше
			var extra := ModelLib.make_node(cur_id)
			for c in extra.get_children():
				if str(c.get_meta("role", "")) == "glb":
					c.queue_free()
			holder.add_child(extra)
			_draw_selection()
			return
	_glb_playing = ""
	var n := ModelLib.make_node(cur_id)
	if not _working:
		for c in n.get_children():
			if c is MultiMeshInstance3D:
				c.multimesh.set_instance_custom_data(0, Color(0, 0.3, 0, 0))
	holder.add_child(n)
	# точки дыма и искр
	for e in model.get("emitters", []):
		var mk := MeshInstance3D.new()
		mk.mesh = ModelLib.unit_mesh("sphere", 1.0, 8)
		mk.scale = Vector3.ONE * 0.18
		mk.position = ModelLib.v3(e.get("pos", [0, 0, 0])) * float(model.get("scale", 1.0))
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.albedo_color = {"puff": Color(0.7, 0.7, 0.7), "steam": Color(0.9, 0.95, 1), "dust": Color(0.75, 0.6, 0.4), "sparks": Color(1, 0.7, 0.2)}.get(e.get("kind", "puff"), Color.WHITE)
		mm.no_depth_test = true
		mk.material_override = mm
		holder.add_child(mk)
	_draw_selection()


func _part_xf(i: int) -> Transform3D:
	var gs := float(model.get("scale", 1.0))
	return Transform3D(Basis.from_scale(Vector3.ONE * gs), Vector3.ZERO) * ModelLib.part_xform(model.parts[i])


func _draw_selection() -> void:
	var im := ImmediateMesh.new()
	if not sel.is_empty():
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in sel:
			if i >= model.parts.size():
				continue
			var xf := _part_xf(i)
			var c := [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, -0.5, 0.5),
				Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)]
			for e in [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]:
				im.surface_set_color(Color(1, 0.75, 0.2) if i == sel[0] else Color(0.4, 0.8, 1))
				im.surface_add_vertex(xf * c[e[0]])
				im.surface_set_color(Color(1, 0.75, 0.2) if i == sel[0] else Color(0.4, 0.8, 1))
				im.surface_add_vertex(xf * c[e[1]])
		im.surface_end()
	sel_lines.mesh = im


## Деталь под курсором: луч переводим в пространство детали и проверяем единичный куб.
func _pick(mp: Vector2) -> int:
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	var best := -1
	var bt := INF
	for i in model.get("parts", []).size():
		var inv := _part_xf(i).affine_inverse()
		var lo := inv * o
		var ld := inv.basis * d
		var t := _ray_box(lo, ld)
		if t >= 0.0:
			var wt := ((_part_xf(i) * (lo + ld * t)) - o).length()
			if wt < bt:
				bt = wt
				best = i
	return best


static func _ray_box(o: Vector3, d: Vector3) -> float:
	var tmin := -INF
	var tmax := INF
	for a in 3:
		if absf(d[a]) < 0.000001:
			if o[a] < -0.5 or o[a] > 0.5:
				return -1.0
		else:
			var t1 := (-0.5 - o[a]) / d[a]
			var t2 := (0.5 - o[a]) / d[a]
			tmin = max(tmin, min(t1, t2))
			tmax = min(tmax, max(t1, t2))
	if tmax < max(tmin, 0.0):
		return -1.0
	return tmin if tmin >= 0.0 else tmax


func _view_input(ev: InputEvent) -> void:
	var mp: Vector2 = vpc.get_local_mouse_position() * (Vector2(vp.size) / vpc.size)
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist = max(1.0, cam_dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist = min(60.0, cam_dist * 1.1)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbit = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				vpc.grab_focus()
				var hit := _pick(mp)
				if hit < 0:
					if not mb.shift_pressed:
						sel.clear()
				elif mb.shift_pressed:
					if hit in sel:
						sel.erase(hit)
					else:
						sel.append(hit)
				elif not hit in sel:
					sel = _with_group(hit)
				else:
					sel.erase(hit)
					sel.push_front(hit)
				_draw_selection()
				_show_props()
				if not sel.is_empty():
					_drag = "scale" if mb.ctrl_pressed else ("up" if mb.alt_pressed else "move")
					_drag_from = mp
					_drag_start = sel.map(func(i): return model.parts[i].duplicate(true))
					_begin_edit()
			else:
				if _drag != "" and _moved:
					_changed()
					_show_props()
				_drag = ""
				_moved = false
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _orbit:
			if mm.shift_pressed or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				var right := cam.global_transform.basis.x
				var up := cam.global_transform.basis.y
				cam_target += (-right * mm.relative.x + up * mm.relative.y) * cam_dist * 0.0015
			else:
				cam_yaw -= mm.relative.x * 0.008
				cam_pitch = clampf(cam_pitch + mm.relative.y * 0.006, -0.2, 1.5)
		elif _drag != "":
			_drag_move(mp)
	elif ev is InputEventKey and ev.pressed:
		_key(ev as InputEventKey)


var _moved := false


## Детали одной группы выбираются вместе.
func _with_group(i: int) -> Array:
	var g: String = str(model.parts[i].get("group", ""))
	if g == "":
		return [i]
	var out := [i]
	for k in model.parts.size():
		if k != i and str(model.parts[k].get("group", "")) == g:
			out.append(k)
	return out


func _drag_move(mp: Vector2) -> void:
	_moved = true
	var gs := float(model.get("scale", 1.0))
	match _drag:
		"move":
			# плоскость на высоте первой выбранной детали
			var y := ModelLib.v3(_drag_start[0].get("pos", [0, 0, 0])).y * gs
			var pl := Plane(Vector3.UP, y)
			var a = pl.intersects_ray(cam.project_ray_origin(_drag_from), cam.project_ray_normal(_drag_from))
			var b = pl.intersects_ray(cam.project_ray_origin(mp), cam.project_ray_normal(mp))
			if a == null or b == null:
				return
			var dlt: Vector3 = (b - a) / gs
			_apply_offset(dlt)
		"up":
			var dy := -(mp.y - _drag_from.y) * cam_dist * 0.0025 / gs
			_apply_offset(Vector3(0, dy, 0))
		"scale":
			var k := clampf(1.0 + (mp.x - _drag_from.x) * 0.005, 0.05, 20.0)
			for j in sel.size():
				var s0 := ModelLib.v3(_drag_start[j].get("size", [1, 1, 1]), Vector3.ONE)
				model.parts[sel[j]]["size"] = _arr(_snapv(s0 * k))
	_rebuild_needed = true


func _apply_offset(dlt: Vector3) -> void:
	for j in sel.size():
		var p0 := ModelLib.v3(_drag_start[j].get("pos", [0, 0, 0]))
		model.parts[sel[j]]["pos"] = _arr(_snapv(p0 + dlt))


func _snapv(v: Vector3) -> Vector3:
	if not snap:
		return Vector3(snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001))
	return Vector3(snappedf(v.x, snap_step), snappedf(v.y, snap_step), snappedf(v.z, snap_step))


static func _arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _key(k: InputEventKey) -> void:
	var step := snap_step if snap else 0.01
	if k.shift_pressed:
		step *= 5.0
	match k.keycode:
		KEY_DELETE:
			delete_sel()
		KEY_D:
			if k.ctrl_pressed:
				duplicate_sel()
		KEY_Z:
			if k.ctrl_pressed:
				do_undo()
		KEY_Y:
			if k.ctrl_pressed:
				do_redo()
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN:
			if sel.is_empty():
				return
			# стрелки двигают относительно камеры
			var f := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
			var r := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
			var dv := Vector3.ZERO
			match k.keycode:
				KEY_LEFT: dv = -r
				KEY_RIGHT: dv = r
				KEY_UP: dv = f
				KEY_DOWN: dv = -f
				KEY_PAGEUP: dv = Vector3.UP
				KEY_PAGEDOWN: dv = Vector3.DOWN
			if dv.y == 0.0:
				dv = Vector3(roundf(dv.x), 0, roundf(dv.z)) if absf(dv.x) > 0.7 or absf(dv.z) > 0.7 else dv
			_begin_edit()
			for i in sel:
				var p := ModelLib.v3(model.parts[i].get("pos", [0, 0, 0]))
				model.parts[i]["pos"] = _arr(p + dv * step)
			_changed()
			_show_props()


# ---------------------------------------------------------------- действия с деталями

func add_part(base: Dictionary) -> void:
	_begin_edit()
	var p := {"shape": "box", "size": [0.6, 0.6, 0.6], "pos": [0, 0.3, 0], "rot": [0, 0, 0], "color": "#c0c4cc", "mat": "paint"}
	p.merge(base, true)
	if not sel.is_empty():
		var sp := ModelLib.v3(model.parts[sel[0]].get("pos", [0, 0, 0]))
		var ss := ModelLib.v3(model.parts[sel[0]].get("size", [1, 1, 1]), Vector3.ONE)
		p["pos"] = _arr(sp + Vector3(0, ss.y * 0.5 + ModelLib.v3(p.size, Vector3.ONE).y * 0.5, 0))
	model.parts.append(p)
	sel = [model.parts.size() - 1]
	_changed()
	_show_props()


func duplicate_sel() -> void:
	if sel.is_empty():
		return
	_begin_edit()
	var new_sel := []
	var gid := "g%d" % randi()
	var off := Vector3(snap_step * 4, 0, 0)
	for i in sel:
		var p: Dictionary = model.parts[i].duplicate(true)
		p["pos"] = _arr(ModelLib.v3(p.get("pos", [0, 0, 0])) + off)
		if sel.size() > 1:
			p["group"] = gid
		else:
			p.erase("group")   # копия одной детали не ездит вместе со старой группой
		model.parts.append(p)
		new_sel.append(model.parts.size() - 1)
	sel = new_sel
	_changed()
	_show_props()


func delete_sel() -> void:
	if sel.is_empty():
		return
	_begin_edit()
	var s := sel.duplicate()
	s.sort()
	s.reverse()
	for i in s:
		model.parts.remove_at(i)
	sel.clear()
	_changed()
	_show_props()


## Зеркальная копия: деталь повторяется с другой стороны оси.
func mirror_sel(axis: int) -> void:
	if sel.is_empty():
		return
	_begin_edit()
	var new_sel := []
	for i in sel:
		var p: Dictionary = model.parts[i].duplicate(true)
		var pos := ModelLib.v3(p.get("pos", [0, 0, 0]))
		pos[axis] = -pos[axis]
		p["pos"] = _arr(pos)
		var rot := ModelLib.v3(p.get("rot", [0, 0, 0]))
		# отражение поворота: меняем знак у двух других осей
		for a in 3:
			if a != axis:
				rot[a] = -rot[a]
		p["rot"] = _arr(rot)
		p.erase("group")
		model.parts.append(p)
		new_sel.append(model.parts.size() - 1)
	sel = new_sel
	_changed()
	_show_props()
	ed.set_status("Зеркальная копия готова")


func _ask_ring() -> void:
	if sel.is_empty():
		ed.set_status("Сначала выберите деталь")
		return
	ed.ask_text("Сколько копий по кругу (вокруг центра модели)?", "6", func(t: String): ring_sel(clampi(int(t), 2, 64)))


func ring_sel(n: int) -> void:
	_begin_edit()
	var src := sel.map(func(i): return model.parts[i].duplicate(true))
	var gid := "ring%d" % randi()
	for i in sel:
		model.parts[i]["group"] = gid
	for k in range(1, n):
		var ang := TAU * k / n
		var b := Basis(Vector3.UP, ang)
		for p0 in src:
			var p: Dictionary = p0.duplicate(true)
			p["pos"] = _arr(b * ModelLib.v3(p.get("pos", [0, 0, 0])))
			var rot := ModelLib.v3(p.get("rot", [0, 0, 0]))
			rot.y += rad_to_deg(ang)
			p["rot"] = _arr(rot)
			p["group"] = gid
			model.parts.append(p)
	_changed()
	_show_props()


func _ask_row() -> void:
	if sel.is_empty():
		ed.set_status("Сначала выберите деталь")
		return
	ed.ask_text("Сколько копий и шаг, через пробел (например «4 0.5»):", "4 0.6", func(t: String):
		# «4 0,5» и «4 0.5» — одно и то же (русская запятая)
		var p := t.replace(";", " ").split(" ", false)
		var st := float(p[1].replace(",", ".")) if p.size() > 1 else 0.6
		row_sel(clampi(int(p[0]) if p.size() > 0 else 4, 2, 64), st if absf(st) > 0.001 else 0.6))


func row_sel(n: int, step: float) -> void:
	_begin_edit()
	var src := sel.map(func(i): return model.parts[i].duplicate(true))
	var gid := "row%d" % randi()
	for i in sel:
		model.parts[i]["group"] = gid
	for k in range(1, n):
		for p0 in src:
			var p: Dictionary = p0.duplicate(true)
			p["pos"] = _arr(ModelLib.v3(p.get("pos", [0, 0, 0])) + Vector3(step * k, 0, 0))
			p["group"] = gid
			model.parts.append(p)
	_changed()
	_show_props()


## «Сделать красиво»: скосы, контур, лёгкий разброс оттенков и затемнение низа, модель на земле.
func beautify() -> void:
	_begin_edit()
	var box := _model_aabb()
	var h := maxf(0.01, box.size.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cur_id)
	for p in model.parts:
		var size := ModelLib.v3(p.get("size", [1, 1, 1]), Vector3.ONE)
		if p.get("shape", "box") == "box" and p.get("mat", "") != "glow" and min(size.x, min(size.y, size.z)) > 0.08:
			p["bevel"] = clampf(0.05 / maxf(0.2, min(size.x, min(size.y, size.z))), 0.03, 0.18)
		if p.get("mat", "") == "glow":
			continue
		# повторное нажатие не темнит модель ещё раз: считаем от исходного цвета детали
		var cur_col := str(p.get("color", "#ffffff"))
		var bc = p.get("beauty", null)
		var base_col := cur_col
		if bc is Array and bc.size() == 2 and str(bc[1]) == cur_col:
			base_col = str(bc[0])
		var c := DB.color(base_col)
		var y := (ModelLib.v3(p.get("pos", [0, 0, 0])).y * float(model.get("scale", 1.0)) - box.position.y) / h
		var ao := lerpf(0.86, 1.0, clampf(y * 1.5, 0.0, 1.0))
		var jitter := rng.randf_range(-0.035, 0.035)
		c = Color.from_hsv(c.h, clampf(c.s * (1.0 + jitter), 0, 1), clampf(c.v * ao * (1.0 + jitter), 0, 1))
		p["color"] = "#" + c.to_html(false)
		p["beauty"] = [base_col, p.color]
	model["outline"] = true
	_ground_now()
	_changed()
	_show_props()
	ed.set_status("Готово: скосы, контур, оттенки, модель на земле. Не понравилось — Ctrl+Z")


func ground() -> void:
	_begin_edit()
	_ground_now()
	_changed()


func _ground_now() -> void:
	var box := _model_aabb()
	var gs := float(model.get("scale", 1.0))
	var dy := -box.position.y / gs
	if absf(dy) < 0.0005:
		return
	for p in model.parts:
		var pos := ModelLib.v3(p.get("pos", [0, 0, 0]))
		pos.y += dy
		p["pos"] = _arr(pos)


func center_model() -> void:
	_begin_edit()
	var c := _model_aabb().get_center() / float(model.get("scale", 1.0))
	for p in model.parts:
		var pos := ModelLib.v3(p.get("pos", [0, 0, 0]))
		pos.x -= c.x
		pos.z -= c.z
		p["pos"] = _arr(pos)
	_changed()


func save_group_as_part() -> void:
	if sel.is_empty():
		ed.set_status("Выделите детали (Shift+клик), которые станут вашей деталью")
		return
	ed.ask_text("Название новой детали:", "Моя деталь", func(nm: String):
		var parts := sel.map(func(i): return model.parts[i].duplicate(true))
		var c := Vector3.ZERO
		for p in parts:
			c += ModelLib.v3(p.get("pos", [0, 0, 0]))
		c /= parts.size()
		var miny := INF
		for p in parts:
			var pos := ModelLib.v3(p.get("pos", [0, 0, 0])) - Vector3(c.x, 0, c.z)
			p["pos"] = _arr(pos)
			p.erase("group")
			miny = min(miny, pos.y - ModelLib.v3(p.get("size", [1, 1, 1]), Vector3.ONE).y * 0.5)
		for p in parts:
			var pos := ModelLib.v3(p.pos)
			pos.y -= miny
			p["pos"] = _arr(pos)
		var id := "part_" + DB.latin_id(nm)
		while DB.data.models.has(id):
			id += "_2"
		DB.save_object("models", id, {"name": nm, "category": "Детали: мои", "library": "part", "parts": parts})
		ed.set_status("Деталь «%s» сохранена в библиотеку" % nm)
		ed.content_changed())


# ---------------------------------------------------------------- библиотека и шаблоны

func _library(kind: String) -> Array:
	var out := []
	for id in DB.data.models:
		var m: Dictionary = DB.data.models[id]
		var lib := str(m.get("library", ""))
		if kind == "part" and lib == "part":
			out.append(id)
		elif kind == "template" and lib != "part":
			out.append(id)
	out.sort_custom(func(a, b):
		var ca := ("0" if DB.data.models[a].get("library", "") == "template" else "1") + str(DB.data.models[a].get("category", ""))
		var cb := ("0" if DB.data.models[b].get("library", "") == "template" else "1") + str(DB.data.models[b].get("category", ""))
		return ca < cb if ca != cb else str(DB.data.models[a].get("name", a)) < str(DB.data.models[b].get("name", b)))
	return out


## Окно с карточками моделей (иконка + название), сгруппированными по категориям.
func _gallery(title: String, items: Array, cb: Callable, empty_text := "") -> void:
	var d := AcceptDialog.new()
	d.title = title
	d.ok_button_text = "Закрыть"
	var v := VBoxContainer.new()
	var s := LineEdit.new()
	s.placeholder_text = "Поиск"
	v.add_child(s)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(860, 520)
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	d.add_child(v)
	ed.add_child(d)
	var fill := func():
		for c in inner.get_children():
			c.queue_free()
		var q := s.text.strip_edges().to_lower()
		var last_cat := "§"
		var grid: GridContainer = null
		if empty_text != "" and q == "":
			var eb := UI.button(empty_text, func():
				cb.call("")
				d.hide())
			inner.add_child(eb)
		for id in items:
			var m: Dictionary = DB.data.models[id]
			var nm := str(m.get("name", id))
			if q != "" and not (q in nm.to_lower() or q in str(id).to_lower()):
				continue
			var cat := str(m.get("category", ""))
			if cat != last_cat:
				last_cat = cat
				inner.add_child(UI.title(cat if cat != "" else "Без категории", 15))
				grid = GridContainer.new()
				grid.columns = 6
				inner.add_child(grid)
			var b := Button.new()
			b.custom_minimum_size = Vector2(136, 120)
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = "%s\n%s" % [nm, id]
			var bv := VBoxContainer.new()
			bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bv.set_anchors_preset(Control.PRESET_FULL_RECT)
			var tr := TextureRect.new()
			tr.texture = Icons.get_icon("model:" + id)
			tr.custom_minimum_size = Vector2(0, 84)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bv.add_child(tr)
			var l := UI.label(nm, 12)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.clip_text = true
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bv.add_child(l)
			b.add_child(bv)
			var mid: String = id
			b.pressed.connect(func():
				cb.call(mid)
				d.hide())
			grid.add_child(b)
	s.text_changed.connect(func(_t): fill.call())
	fill.call()
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.popup_centered()


func _add_library() -> void:
	_gallery("Готовые детали", _library("part"), func(id):
		if id == "":
			return
		var lib: Dictionary = DB.data.models[id]
		_begin_edit()
		var base := Vector3.ZERO
		if not sel.is_empty():
			base = ModelLib.v3(model.parts[sel[0]].get("pos", [0, 0, 0]))
			base.y += ModelLib.v3(model.parts[sel[0]].get("size", [1, 1, 1]), Vector3.ONE).y * 0.5
		var gid := "g%d" % randi()
		var new_sel := []
		var ls := float(lib.get("scale", 1.0))
		for p0 in lib.get("parts", []):
			var p: Dictionary = p0.duplicate(true)
			p["pos"] = _arr(ModelLib.v3(p.get("pos", [0, 0, 0])) * ls + base)
			p["size"] = _arr(ModelLib.v3(p.get("size", [1, 1, 1]), Vector3.ONE) * ls)
			p["group"] = gid
			model.parts.append(p)
			new_sel.append(model.parts.size() - 1)
		sel = new_sel
		_changed()
		_show_props()
		ed.set_status("Деталь добавлена. Тяните её мышью; детали группы двигаются вместе (Shift+клик — по одной)."))


func _neuro() -> void:
	var d = preload("res://scripts/editor/neuro_panel.gd").new(self)
	add_child(d)
	d.popup_centered()


func _new_from_template() -> void:
	_gallery("Новая модель из шаблона", _library("template"), func(id):
		var nm := "Новая модель"
		var src: Dictionary = {"name": nm, "category": "Мои модели", "parts": []}
		if id != "":
			src = DB.data.models[id].duplicate(true)
			src["name"] = str(src.get("name", id)) + " (моя)"
			src["category"] = "Мои модели"
			src.erase("library")
		var nid := _new_id("my_" + (id if id != "" else "model"))
		DB.save_object("models", nid, src)
		_fill_list()
		open(nid)
		ed.content_changed(), "Пустая модель")


func _new_empty() -> void:
	var nid := _new_id("my_model")
	DB.save_object("models", nid, EdSchema.blank("models"))
	_fill_list()
	open(nid)
	ed.content_changed()


func _duplicate_model() -> void:
	if cur_id == "":
		return
	var src: Dictionary = model.duplicate(true)
	src["name"] = str(src.get("name", cur_id)) + " (копия)"
	src.erase("library")
	var nid := _new_id(cur_id + "_copy")
	DB.save_object("models", nid, src)
	_fill_list()
	open(nid)
	ed.content_changed()


func _delete_model() -> void:
	if cur_id == "":
		return
	var id := cur_id
	ed.confirm("Удалить модель «%s»? Если её используют здания или предметы, они станут розовыми кубами." % model.get("name", id), func():
		_changed_t = -1.0
		DB.save_object("models", id, null)
		cur_id = ""
		_fill_list()
		if not ids.is_empty():
			open(ids[0])
		ed.content_changed())


func _new_id(base: String) -> String:
	var b := DB.latin_id(base)
	if b == "":
		b = "new"
	var id := b
	var i := 2
	while DB.data.models.has(id):
		id = "%s_%d" % [b, i]
		i += 1
	return id


func _assign() -> void:
	if cur_id == "":
		return
	var pm := PopupMenu.new()
	var kinds := [["items", "Предмету…"], ["buildings", "Зданию…"], ["resources", "Дереву, кусту или камню…"], ["enemies", "Монстру…"]]
	for i in kinds.size():
		pm.add_item(kinds[i][1], i)
	ed.add_child(pm)
	pm.id_pressed.connect(func(i):
		var t: String = kinds[i][0]
		EdPicker.open_for(ed, t, func(oid):
			if oid == "":
				return
			var o: Dictionary = DB.data[t][oid]
			o["model"] = cur_id
			DB.save_object(t, oid, o)
			ed.content_changed()
			ed.set_status("Теперь «%s» выглядит как эта модель" % o.get("name", oid)), false))
	pm.popup_hide.connect(pm.queue_free)
	pm.popup_centered()


# ---------------------------------------------------------------- свойства

func _show_props() -> void:
	for c in props.get_children():
		c.queue_free()
	if cur_id == "":
		return
	props.add_child(UI.title("Модель", 17))
	if not model.has("scale"):
		model["scale"] = 1.0
	var mf := EdForm.make(model, [
		["name", "Название", "str", ""], ["category", "Категория", "str", "Группа в списке моделей"],
		["scale", "Общий масштаб", "float", "1 — как есть"], ["outline", "Контур", "bool", "Тонкая тёмная обводка"],
		["glb", "Готовая 3D-модель (GLB)", "file:glb", "Модель из Blender, Sketchfab, Mixamo и т.п. Размер и положение подгоняются сами"],
		["glb_pos", "Сдвиг GLB-модели", "vec3", "Если модель висит в воздухе или ушла вбок"],
		["glb_raw", "Поза без костей", "bool", "Показывать сетку «как в программе», не по костям. Включите, если модель свёрнута, лежит или перекручена"]], false, 150)
	mf.changed.connect(func():
		if str(model.get("glb", "")) != _glb_seen:
			_on_glb_set()
		_changed(false))
	props.add_child(mf)
	if sel.is_empty():
		props.add_child(UI.small("Щёлкните по детали в окне, чтобы её настроить.\nДеталей в модели: %d" % model.parts.size()))
		_glb_anim_ui()
		_emitters_ui()
		_rig_ui()
		return
	var p: Dictionary = model.parts[sel[0]]
	props.add_child(UI.title("Деталь" + (" (выбрано %d)" % sel.size() if sel.size() > 1 else ""), 17))
	# фигура
	var sh := OptionButton.new()
	sh.focus_mode = Control.FOCUS_NONE
	for i in ModelLib.SHAPES.size():
		sh.add_item(ModelLib.SHAPE_NAMES[i])
	sh.select(max(0, ModelLib.SHAPES.find(p.get("shape", "box"))))
	sh.item_selected.connect(func(i):
		_begin_edit()
		for k in sel:
			model.parts[k]["shape"] = ModelLib.SHAPES[i]
		_changed())
	props.add_child(_row("Фигура", sh))
	# числа
	for f in [["pos", "Положение", 0.05], ["rot", "Поворот, °", 15.0], ["size", "Размер", 0.05]]:
		props.add_child(_vec_row(p, f[0], f[1], f[2]))
	# материалы
	props.add_child(UI.label("Материал", 14, UI.ACCENT))
	var mg := GridContainer.new()
	mg.columns = 3
	for mp in MATERIAL_PRESETS:
		var preset: Dictionary = mp[1]
		var b := UI.button(mp[0], func():
			_begin_edit()
			for k in sel:
				var part: Dictionary = model.parts[k]
				for key in ["metallic", "roughness", "emission"]:
					part.erase(key)
				part.merge(preset, true)
			_changed()
			_show_props())
		b.add_theme_color_override("font_color", DB.color(preset.color).lightened(0.2))
		mg.add_child(b)
	props.add_child(mg)
	# цвет
	var cp := ColorPickerButton.new()
	cp.color = DB.color(p.get("color", "#ffffff"))
	cp.custom_minimum_size = Vector2(0, 28)
	cp.color_changed.connect(func(c):
		for k in sel:
			model.parts[k]["color"] = "#" + c.to_html(false)
		_rebuild_needed = true
		_changed_t = 0.6)
	cp.picker_created.connect(func(): cp.get_picker().color_changed.connect(func(_c): pass))
	cp.popup_closed.connect(func(): _push_undo())
	props.add_child(_row("Цвет", cp))
	var pg := GridContainer.new()
	pg.columns = 10
	for hex in PALETTE:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(26, 22)
		sw.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(hex)
		sb.set_corner_radius_all(3)
		sw.add_theme_stylebox_override("normal", sb)
		sw.add_theme_stylebox_override("hover", sb)
		sw.add_theme_stylebox_override("pressed", sb)
		var h: String = hex
		sw.pressed.connect(func():
			_begin_edit()
			for k in sel:
				model.parts[k]["color"] = h
			_changed()
			_show_props())
		pg.add_child(sw)
	props.add_child(pg)
	# анимация, скос, роль, текстура
	var an := OptionButton.new()
	an.focus_mode = Control.FOCUS_NONE
	var anims: Array = [""] + DB.data.animations.keys()
	for a in anims:
		an.add_item("нет" if a == "" else str(DB.data.animations[a].get("name", a)))
	an.select(max(0, anims.find(p.get("anim", ""))))
	an.item_selected.connect(func(i):
		_begin_edit()
		for k in sel:
			if anims[i] == "":
				model.parts[k].erase("anim")
			else:
				model.parts[k]["anim"] = anims[i]
		_changed())
	props.add_child(_row("Анимация", an))
	# рисунок поверхности: дерево, камень, металл... («как у материала» — по умолчанию)
	var sfc := OptionButton.new()
	sfc.focus_mode = Control.FOCUS_NONE
	sfc.add_item("как у материала")
	for nm in ModelLib.SURFACE_NAMES:
		sfc.add_item(nm)
	var cur_s := str(p.get("surface", ""))
	sfc.select(0 if cur_s == "" else ModelLib.SURFACES.find(cur_s) + 1)
	sfc.tooltip_text = "Рисунок без картинок: волокна дерева, трещины камня, швы металла, листва, ткань"
	sfc.item_selected.connect(func(i):
		_begin_edit()
		for k in sel:
			if i == 0:
				model.parts[k].erase("surface")
			else:
				model.parts[k]["surface"] = ModelLib.SURFACES[i - 1]
		_changed())
	props.add_child(_row("Поверхность", sfc))
	var bv := HSlider.new()
	bv.min_value = 0.0
	bv.max_value = 0.25
	bv.step = 0.01
	bv.value = float(p.get("bevel", 0.0))
	bv.custom_minimum_size = Vector2(160, 0)
	bv.drag_started.connect(_begin_edit)
	bv.drag_ended.connect(func(_c): _changed())
	bv.value_changed.connect(func(x):
		for k in sel:
			if x <= 0.001:
				model.parts[k].erase("bevel")
			else:
				model.parts[k]["bevel"] = x
		_rebuild_needed = true)
	props.add_child(_row("Скос рёбер (куб)", bv))
	var seg := SpinBox.new()
	seg.min_value = 0
	seg.max_value = 48
	seg.value = int(p.get("seg", 0))
	seg.tooltip_text = "Гладкость круглых фигур: 0 — обычная, 6 — шестигранник, 24 — очень гладко. У шестерни — число зубцов, у шнека — число витков"
	seg.value_changed.connect(func(x):
		_begin_edit()
		for k in sel:
			model.parts[k]["seg"] = int(x)
		_changed())
	props.add_child(_row("Грани / зубцы / витки", seg))
	var top := HSlider.new()
	top.min_value = 0.0
	top.max_value = 1.5
	top.step = 0.05
	top.value = float(p.get("top", 1.0))
	top.custom_minimum_size = Vector2(160, 0)
	top.tooltip_text = "Для цилиндра: верх уже или шире низа. У шестерни — глубина впадин (0.78 обычно), у шнека — толщина вала"
	top.drag_started.connect(_begin_edit)
	top.drag_ended.connect(func(_c): _changed())
	top.value_changed.connect(func(x):
		for k in sel:
			model.parts[k]["top"] = x
		_rebuild_needed = true)
	props.add_child(_row("Верх цилиндра / впадины / вал", top))
	var pf := EdForm.make(p, [["texture", "Текстура", "file:image", "Картинка на деталь"], ["tex_scale", "Масштаб текстуры", "float", ""],
		["role", "Роль", "str", "head — башня турели крутится к цели; stretch — тянется до ленты (в модели стыка); port_color — цвет входа/выхода; fluid_color — цвет жидкости в трубе или баке; stretch в модели отрезка трубы — тянется до соседа; b:имя — деталь привязана к кости скелета с таким именем и двигается с ней (у монстров и людей)"], ["tint", "Темнеет при уроне", "bool", ""]], false, 150)
	pf.changed.connect(func():
		_push_undo()
		_rebuild_needed = true
		_changed_t = 0.6)
	props.add_child(pf)
	props.add_child(UI.button("Разгруппировать", func():
		_begin_edit()
		for k in sel:
			model.parts[k].erase("group")
		_changed(), "Детали снова двигаются по одной"))
	_emitters_ui()


func _row(t: String, c: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UI.label(t, 14)
	l.custom_minimum_size = Vector2(130, 0)
	h.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	return h


func _vec_row(p: Dictionary, key: String, title: String, step: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UI.label(title, 14)
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	var def := Vector3.ONE if key == "size" else Vector3.ZERO
	var v := ModelLib.v3(p.get(key, [def.x, def.y, def.z]), def)
	var cols := [Color(1, 0.45, 0.4), Color(0.5, 1, 0.5), Color(0.45, 0.65, 1)]
	for a in 3:
		var s := SpinBox.new()
		s.allow_greater = true
		s.allow_lesser = true
		s.min_value = -1000
		s.max_value = 1000
		s.step = 0.001
		s.custom_arrow_step = step
		s.value = v[a]
		s.custom_minimum_size = Vector2(84, 0)
		s.get_line_edit().add_theme_color_override("font_color", cols[a])
		s.tooltip_text = ["X (вправо)", "Y (вверх)", "Z (вперёд)"][a]
		var ax := a
		s.value_changed.connect(func(x):
			_begin_edit()
			var first := ModelLib.v3(model.parts[sel[0]].get(key, [def.x, def.y, def.z]), def)
			var d: float = x - first[ax]
			for k in sel:
				var cur := ModelLib.v3(model.parts[k].get(key, [def.x, def.y, def.z]), def)
				cur[ax] = x if key == "size" and sel.size() == 1 else cur[ax] + d
				model.parts[k][key] = _arr(cur)
			_changed())
		h.add_child(s)
	return h


## Какая анимация из GLB-файла за что отвечает (герой: стойка, ходьба, бег, удар, выстрел, прыжок, смерть, ранение).
func _glb_anim_ui() -> void:
	var gp := str(model.get("glb", ""))
	if gp == "":
		return
	var names := ModelLib.glb_anims(gp)
	props.add_child(UI.title("Анимации из GLB", 16))
	if names.is_empty():
		props.add_child(UI.small("В файле нет анимаций — модель двигается целиком. Скачайте вариант со скелетом и анимациями (Rig / Animated)."))
		return
	props.add_child(UI.small("В файле %d анимаций. «Авто» — подбор по названию (idle, walk, run, attack, death...). Проверить — список «Покой / Ходьба / Бег / Удар / Смерть» над окном.\nСейчас играет: %s" % [names.size(), _glb_playing if _glb_playing != "" else "—"]))
	if not model.get("glb_anims") is Dictionary:
		model["glb_anims"] = {}
	if not model.has("glb_animate"):
		model["glb_animate"] = true
	var labels := {"idle": "Стоит", "walk": "Идёт", "run": "Бежит", "attack": "Бьёт", "shoot": "Стреляет", "jump": "Прыгает", "die": "Умирает", "hurt": "Ранен"}
	var grid := GridContainer.new()
	grid.columns = 2
	for st in ModelLib.GLB_STATES:
		var l := Label.new()
		l.text = labels[st]
		grid.add_child(l)
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		var auto := ModelLib.glb_anim_for({}, st, names)
		ob.add_item("Авто (%s)" % (auto if auto != "" else "нет"))
		for nm in names:
			ob.add_item(nm)
		var cur := str(model.glb_anims.get(st, ""))
		var idx := names.find(cur)
		ob.select(idx + 1 if idx >= 0 else 0)
		ob.item_selected.connect(func(i):
			_begin_edit()
			if i == 0:
				model.glb_anims.erase(st)
			else:
				model.glb_anims[st] = names[i - 1]
			_changed()
			_rebuild_needed = true)
		grid.add_child(ob)
	props.add_child(grid)
	var f := EdForm.make(model, [
		["glb_animate", "Играть анимации файла", "bool", "Выключите, если анимации в файле не подходят — тогда модель двигается целиком"],
		["glb_yaw", "Поворот модели, °", "float", "Если герой идёт боком или спиной — 90, 180 или −90"],
		["glb_walk_speed", "Скорость ходьбы в анимации, м/с", "float", "Если ноги скользят — подберите (обычно 1.5–2)"],
		["glb_run_speed", "Скорость бега в анимации, м/с", "float", "Обычно 4–6"],
		["glb_hand_bone", "Кость руки для инструмента", "str", "Пусто — найдётся сама (RightHand, hand_r...)"]], false, 150)
	f.changed.connect(func():
		_changed(false)
		_rebuild_needed = true)
	props.add_child(f)


func _rig_ui() -> void:
	props.add_child(UI.title("Скелет и походка", 16))
	if not model.has("rig"):
		props.add_child(UI.small("У модели нет скелета — она двигается целиком (простые анимации деталей).\nСкелет нужен монстрам и людям: лапы шагают, голова смотрит на цель, хвост виляет."))
		props.add_child(UI.button("+ Добавить скелет", func():
			_begin_edit()
			model["rig"] = {"bones": [{"name": "b:body", "parent": "", "pivot": [0, 0.8, 0]}], "body": "b:body", "legs": [], "arms": [], "jaws": [], "chains": [], "breath": [],
				"gait": {"stride": 1.2, "swing": 25.0, "lift": 20.0, "knee": 30.0, "duty": 0.6, "bob": 0.05, "roll": 4.0, "lean": 6.0}}
			_changed()
			_show_props(), "Пустой скелет с одной костью. Добавьте кости и укажите деталям роль, равную имени кости (b:…)"))
		return
	props.add_child(UI.small("Проверьте движение кнопками «Ходьба», «Бег», «Удар», «Смерть» над окном просмотра.\nДеталь двигается с костью, имя которой записано в её роли (b:…). Остальные — с корневой."))
	var f := EdForm.make(model.rig, EdSchema.sub("rig"), false, 120)
	f.changed.connect(func():
		_changed(false)
		_rebuild_needed = true)
	props.add_child(f)
	props.add_child(UI.button("Удалить скелет", func():
		_begin_edit()
		model.erase("rig")
		_changed()
		_show_props(), "Модель снова будет двигаться целиком"))


func _emitters_ui() -> void:
	props.add_child(UI.title("Дым, пар, пыль, искры", 16))
	props.add_child(UI.small("Точки, из которых идёт дым и т.п. Видны в окне цветными шариками."))
	var holder_obj := {"emitters": model.get("emitters", [])}
	var f := EdForm.make(holder_obj, [["emitters", "Источники", "list:emitter", ""]], false, 120)
	f.changed.connect(func():
		model["emitters"] = holder_obj.emitters
		_changed(false))
	props.add_child(f)


## Тест: скелет показывается в форме и модель шагает в окне просмотра.
func _test_rig() -> void:
	open("mech_spider")
	sel = []
	_show_props()
	_motion = 1
	_rebuild_preview()
	var ok := _rig_node != null
	var moved := 0.0
	if ok:
		var b0: Node3D = _rig_node.bones.values()[1]
		var q0 := b0.basis
		for i in 20:
			_animate_rig(1.0 / 30.0)
		moved = (b0.basis.x - q0.x).length() + (b0.basis.y - q0.y).length()
	print("RIGTEST rig=%s bones=%d legs=%d moved=%.3f %s" % [ok, model.rig.bones.size(), model.rig.legs.size(), moved, "OK" if ok and moved > 0.0 else "FAIL"])


## Тест: «Нейросеть / автоскелет» — сплошная модель из файла делится на части, у монстра находятся ноги и он шагает.
func _test_neuro() -> void:
	# сплошная сетка в GLB, как отдаёт нейросеть (перед — +Z)
	var r := ModelGen.generate("ржавый робот-паук с шестью ногами", {"seed": 2, "quality": 0})
	var root := Node3D.new()
	for rel in r.meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = r.meshes[rel]
		mi.rotation_degrees = Vector3(0, -90, 0)
		root.add_child(mi)
	var doc := GLTFDocument.new()
	var gs := GLTFState.new()
	doc.append_from_scene(root, gs)
	var path := OS.get_user_data_dir().path_join("neuro_test.glb")
	doc.write_to_filesystem(gs, path)
	root.free()
	var d = preload("res://scripts/editor/neuro_panel.gd").new(self)
	add_child(d)
	var before: int = DB.data.models.size()
	d._rig_file(path)
	var ok_model: bool = DB.data.models.size() == before + 1 and cur_id.begins_with("ai_")
	var all_mesh := true
	var files := true
	for p in model.parts:
		all_mesh = all_mesh and str(p.get("shape", "")) == "mesh"
		files = files and FileAccess.file_exists(DB.edit_target.path_join(str(p.get("mesh", ""))))
	var legs: int = model.get("rig", {}).get("legs", []).size()
	sel = []
	_motion = 1
	_rebuild_preview()
	var moved := 0.0
	if _rig_node != null:
		var b0: Node3D = _rig_node.bones.values()[1]
		var q0 := b0.basis
		for i in 20:
			_animate_rig(1.0 / 30.0)
		moved = (b0.basis.x - q0.x).length() + (b0.basis.y - q0.y).length()
	# герой и здание из той же сетки: кости героя и огоньки здания
	d.kind_ob.select(1)
	d._kind_changed()
	d._rig_file(path)
	var hero_ok: bool = model.has("bones") and model.bones.has("arm_r") and model.parts.size() >= 10
	d.kind_ob.select(2)
	d._kind_changed()
	d._rig_file(path)
	var bld_ok: bool = not model.has("rig") and model.parts.size() >= 1
	d.queue_free()
	var ok: bool = ok_model and all_mesh and files and legs >= 4 and moved > 0.0 and hero_ok and bld_ok
	print("NEUROTEST model=%s mesh=%s files=%s legs=%d moved=%.3f hero=%s building=%s %s" % [ok_model, all_mesh, files, legs, moved, hero_ok, bld_ok, "OK" if ok else "FAIL"])


## Тест: готовая GLB-модель видна в окне просмотра (путь — аргумент --glb=...).
func _test_glb() -> void:
	var src := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--glb="):
			src = a.substr(6)
	if src == "skin":
		# модель на скелете, где сетка в файле крошечная (0,018 м), а кость увеличивает её в 100 раз — как у части моделей из интернета
		var root2 := Node3D.new()
		root2.name = "Root"
		var sk := Skeleton3D.new()
		sk.name = "Skeleton"
		root2.add_child(sk)
		sk.add_bone("root")
		sk.set_bone_rest(0, Transform3D(Basis.from_scale(Vector3.ONE * 100.0), Vector3.ZERO))
		sk.reset_bone_poses()
		var mi2 := MeshInstance3D.new()
		mi2.name = "Body"
		var cap := CapsuleMesh.new()
		cap.height = 0.018
		cap.radius = 0.003
		var arrs := cap.get_mesh_arrays()
		var nvs: int = arrs[Mesh.ARRAY_VERTEX].size()
		var bn := PackedInt32Array()
		var wt := PackedFloat32Array()
		for i in nvs:
			bn.append_array([0, 0, 0, 0])
			wt.append_array([1.0, 0.0, 0.0, 0.0])
		for i in nvs:
			arrs[Mesh.ARRAY_VERTEX][i] += Vector3(0, 0.009, 0)
		arrs[Mesh.ARRAY_BONES] = bn
		arrs[Mesh.ARRAY_WEIGHTS] = wt
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
		mi2.mesh = am
		var skin := Skin.new()
		skin.add_named_bind("root", Transform3D.IDENTITY)
		mi2.skin = skin
		sk.add_child(mi2)
		mi2.skeleton = NodePath("..")
		var doc2 := GLTFDocument.new()
		var st2 := GLTFState.new()
		doc2.append_from_scene(root2, st2)
		src = OS.get_user_data_dir().path_join("test_skin.glb")
		doc2.write_to_filesystem(st2, src)
		root2.free()
	if src == "":
		# своя «огромная» модель (как из программ, где единица — сантиметр): куб 150×300×150
		var root := Node3D.new()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(150, 300, 150)
		mi.mesh = bm
		mi.position = Vector3(40, 150, 0)
		root.add_child(mi)
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		doc.append_from_scene(root, st)
		src = OS.get_user_data_dir().path_join("test_big.glb")
		doc.write_to_filesystem(st, src)
		root.free()
	_new_empty()
	var rel := EdForm.import_file(src, "glb")
	model["glb"] = rel
	_on_glb_set()
	_changed()
	_rebuild_preview()
	if "--inst" in OS.get_cmdline_user_args():
		# сравнение: как файл рисует сам движок со скелетом
		for c in holder.get_children():
			c.queue_free()
		var gi := ModelLib.glb_instance(rel)
		gi.transform = Transform3D(Basis.from_scale(Vector3.ONE * float(model.get("scale", 1.0))), Vector3.ZERO) * ModelLib.glb_offset(model)
		holder.add_child(gi)
	var meshes := 0
	var box := AABB()
	var first := true
	var stack: Array = holder.get_children()
	while not stack.is_empty():
		var n = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and n.mesh and not n.is_queued_for_deletion():
			meshes += 1
			var b: AABB = n.global_transform * n.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
	var cam_ok := box.grow(0.01).has_point(cam_target) and cam_dist > box.size.length() * 0.5
	var ok := meshes >= 1 and box.size.y > 0.25 and box.size.y < 6.1 and absf(box.position.y) < 0.05 and cam_ok
	print("GLBTEST ", "OK" if ok else "FAIL", " rel=", rel, " cam=", cam_ok, " scale=", model.get("scale"), " found=", FileAccess.file_exists(ModelLib.resolve_path(rel)), " raw=", model.get("glb_raw", false), " parts=", ModelLib._glb_parts(rel).size(), " meshes=", meshes, " box=", box)
