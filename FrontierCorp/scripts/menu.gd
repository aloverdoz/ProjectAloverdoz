extends Control
## Главное меню: новая игра (выбор профессии, карты), продолжить, редактор, моды, настройки, выход.
## В собранной игре кнопки «Редактор» нет.

var box: VBoxContainer
var page: Control
var bg_t := 0.0
var sel_prof := "engineer"
var difficulty := 1.0
var seed_edit: LineEdit
var mode := "procedural"
var map_size := 0
var res_amount := "normal"   # 1.0.8: сколько ресурсов на карте
const MODULE_NAMES := {"survival": "Голод и жажда", "durability": "Прочность вещей", "finite_ammo": "Конечные патроны",
	"melee": "Ближний бой", "boosters": "Бустеры", "professions": "Профессии", "events": "События мира", "pollution": "Загрязнение", "npcs": "НПС", "orders": "Заказы на станции",
	"zone": "Зона за бурей", "fusion": "Объединение зданий", "combo": "Составные здания (эксперимент)",
	"waves": "Волны роботов", "monsters": "Монстры на карте", "fog": "Туман войны", "climate": "Климат", "hazards": "Опасные события", "tuning": "Настройка машин", "ufo": "НЛО и звёзды"}
var ng_modules := {}
const DIFFS := [["Мирная", 0.25, "без волн и боссов"], ["Очень лёгкая", 0.4, "редкие слабые волны"], ["Лёгкая", 0.6, "роботы ×0.6"],
	["Обычная", 1.0, "роботы ×1"], ["Сложная", 1.5, "роботы ×1.5"], ["Кошмар", 2.2, "роботы ×2.2"], ["Безумие", 3.0, "роботы ×3, волны часто"],
	["Ад", 4.0, "роботы ×4, волны очень часто"]]
var _shot_path := ""
var _shot_frame := 0
var _frame := 0


func _process(_d: float) -> void:
	_frame += 1
	_hero_spin(_d)
	if _shot_frame > 0 and _frame == _shot_frame:
		if _shot_path != "":
			get_viewport().get_texture().get_image().save_png(_shot_path)
		print("SHOT saved ", _shot_path)
		get_tree().quit()


var _built_lang := ""
var background_ready := false


func _ready() -> void:
	if OS.has_feature("balance_editor") or (OS.has_feature("colony_suite") and DB.studio):
		get_tree().change_scene_to_file.call_deferred("res://scenes/editor.tscn")
		return
	_built_lang = Lang.current()
	UI.use_game_style(true)
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Prefs.apply_all()
	_make_bg()
	background_ready = true
	# 1.1.15: кнопки в прокрутке — на низком экране (1280×720) нижние кнопки больше не уходят за край
	var mscroll := ScrollContainer.new()
	mscroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	mscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mscroll.visible = not "--menu_bg_only" in OS.get_cmdline_user_args()   # снимки живого фона без кнопок
	add_child(mscroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mscroll.add_child(center)
	var v := UI.vbox(18)
	center.add_child(v)
	get_window().title = DB.window_title() + (" (Demo)" if Tech.demo_max() >= 0 else "")
	call_deferred("_splash")
	UI.apply_game_icon()
	var logo: String = str(DB.menu("logo", ""))
	if logo != "":
		var tex = ModelLib.texture(logo)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(0, 140)
			v.add_child(tr)
	var tt := DB.t(DB.menu("title", ""))
	var title := UI.label((tt if tt != "" else DB.display_name()).to_upper(), 64, UI.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("outline_size", 12)
	v.add_child(title)
	var st := DB.t(DB.menu("subtitle", ""))
	var sub := UI.label(st if st != "" else "%s %s" % [DB.tx("version", "версия"), DB.game_version()], 15, UI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if Tech.demo_max() >= 0:
		var dl := UI.label("ДЕМО-ВЕРСИЯ · %s" % Tech.demo_text(), 20, Color(1.0, 0.8, 0.35))
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dl)
	var h := UI.hbox(24)
	v.add_child(h)
	box = UI.vbox(10)
	box.custom_minimum_size = Vector2(300, 0)
	h.add_child(box)
	page = UI.panel()
	page.custom_minimum_size = Vector2(620, 460)
	page.visible = false
	h.add_child(page)
	# галочка «Меньше растительности» — первой, чтобы игрок сразу её видел, если игра лагает
	var ft := UI.flora_toggle(18)
	ft.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ft)
	_make_buttons()
	_make_flags(mscroll.visible)
	if not DB.errors.is_empty():
		var e := UI.rich("[color=#ff6b5a]Ошибки в модах:[/color]\n" + "\n".join(DB.errors.slice(0, 6)), 13)
		e.custom_minimum_size = Vector2(600, 0)
		v.add_child(e)
	# автотесты и скриншоты сразу запускают игру
	var args := OS.get_cmdline_user_args()
	var menu_test: bool = Array(args).any(func(x): return str(x).begins_with("--menu") or str(x) == "--editor" or str(x).begins_with("--net_join") or str(x) == "--net_find" or str(x).begins_with("--server") or str(x).begins_with("--dserver"))
	for a in args:
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frame = int(a.substr(9))
		if a.begins_with("--") and not menu_test:
			_start({"profession": "engineer"})
			return
		if a == "--menu-new":
			_page_new.call_deferred()
		if a == "--menu-settings":
			_page_settings.call_deferred()
		if a == "--menu-prefs-test":
			_prefs_test.call_deferred()
		if a == "--menu-mods":
			_page_mods.call_deferred()
		if a == "--menu-load":
			_page_load.call_deferred()
		if a == "--menu-credits":
			_page_credits.call_deferred()
		if a == "--menu-net":
			_page_net.call_deferred()
		if a == "--menu-room":
			_page_room.call_deferred()
		if a == "--menu-hero":
			_page_hero.call_deferred()
		if a.begins_with("--menu-admin="):   # снимки: --menu-admin=адрес[,пароль[,new|claim]]
			var pp := a.substr(13).split(",")
			_adm_node()
			_adm.addr = preload("res://scripts/admin_client.gd").norm_addr(pp[0])
			_adm.pw = pp[1] if pp.size() > 1 else ""
			if pp.size() > 2 and pp[2] == "claim":
				(func():
					_page_admin_claim(await _adm.api("info"))).call_deferred()
			elif pp.size() > 2 and pp[2] == "new":
				(func():
					await _admin_refresh()
					_page_room(true)).call_deferred()
			elif _adm.pw != "":
				_admin_refresh.call_deferred()
			else:
				_page_admin.call_deferred()
		if a == "--menu-help":
			_page_help.call_deferred()
		if a == "--menu-loading":
			LoadingScreen.go.call_deferred(get_tree(), "res://scenes/menu.tscn")
		if a == "--editor":
			_editor.call_deferred()
	var md: Dictionary = DB.data.get("music", {})
	var mm: Array = md.get("menu", [])
	if not mm.is_empty():
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = load(mm[0]) if ResourceLoader.exists(mm[0]) else null
		if p.stream is AudioStreamWAV:
			p.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			p.stream.loop_end = p.stream.data.size() / 2
		p.volume_db = float(md.get("volume", -8))
		add_child(p)
		p.play()


## Фон: картинка из редактора или рисованный «дым» двух цветов.
## Заставка при запуске: картинка на весь экран, плавно появляется и гаснет.
## Один раз за запуск; клик или клавиша — пропустить. «Главное меню» → «Заставка при запуске».
static var _splash_done := false
var _splash_node: Control = null

func _splash() -> void:
	if _splash_done or not bool(DB.menu("splash_on", true)) or "--nosplash" in OS.get_cmdline_user_args() or (_shot_path != "" and not "--splash_test" in OS.get_cmdline_user_args()):
		return
	_splash_done = true
	if live_view != null:
		_splash_live()
		return
	var tex = ModelLib.texture(str(DB.menu("splash_image", "res://ui/splash.png")))
	if tex == null:
		return
	var c := ColorRect.new()
	c.color = Color.BLACK
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tr)
	add_child(c)
	_splash_node = c
	var hold := maxf(0.3, float(DB.menu("splash_time", 2.5)))
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(c, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(c.queue_free)
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_skip_splash())


## 1.3: живая заставка: база проявляется из темноты, буквы названия падают на место со вспышкой,
## по ним пробегает блик, ниже — «FRONTIER CORP» и линия; потом заставка тает и появляется меню.
func _splash_live() -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	_splash_node = c
	var ui_nodes := []
	for ch in get_children():
		if ch is CenterContainer:
			ch.modulate.a = 0.0
			ui_nodes.append(ch)
	_splash_ui = ui_nodes
	var title := DB.display_name()
	title = title.to_upper()
	var vs := get_viewport_rect().size
	var fs := int(clampf(vs.x / maxf(8.0, float(title.length())) * 0.95, 40.0, 120.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(fs * 0.04))
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.anchor_top = 0.62
	row.anchor_bottom = 0.62
	row.offset_top = -fs * 0.7
	row.offset_bottom = fs * 0.7
	c.add_child(row)
	var letters := []
	for i in title.length():
		var l := Label.new()
		l.text = title[i]
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", Color(1.0, 0.93, 0.82))
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
		l.add_theme_constant_override("outline_size", int(fs * 0.12))
		l.add_theme_color_override("font_shadow_color", Color(1.0, 0.5, 0.15, 0.55))
		l.add_theme_constant_override("shadow_outline_size", int(fs * 0.3))
		l.modulate.a = 0.0
		l.pivot_offset = Vector2(fs * 0.3, fs * 0.6)
		row.add_child(l)
		letters.append(l)
	var line := ColorRect.new()
	line.color = Color(1.0, 0.66, 0.28, 0.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(0, 3)
	line.position = Vector2(vs.x * 0.5, vs.y * 0.62 + fs * 0.85)
	c.add_child(line)
	var sub := Label.new()
	sub.text = "·  %s  ·" % DB.game_version()   # 1.3: только название игры, без «Frontier Corp»
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", int(fs * 0.28))
	sub.add_theme_color_override("font_color", Color(1.0, 0.7, 0.32))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	sub.add_theme_constant_override("outline_size", 6)
	sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.anchor_top = 0.62
	sub.anchor_bottom = 0.62
	sub.offset_top = fs * 0.95
	sub.offset_bottom = fs * 1.5
	sub.modulate.a = 0.0
	c.add_child(sub)
	# буквы по очереди: сверху, крупнее и прозрачные → на место
	var lt := create_tween().set_parallel(true)
	lt.tween_interval(0.9)
	for i in letters.size():
		var l: Label = letters[i]
		var d := 0.9 + i * 0.05
		l.scale = Vector2(1.8, 1.8)
		lt.tween_property(l, "modulate:a", 1.0, 0.35).set_delay(d)
		lt.tween_property(l, "scale", Vector2.ONE, 0.45).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var after := 0.9 + letters.size() * 0.05 + 0.4
	# блик бежит по буквам
	for i in letters.size():
		var l: Label = letters[i]
		lt.tween_property(l, "modulate", Color(1.6, 1.4, 1.1, 1.0), 0.12).set_delay(after + i * 0.035)
		lt.tween_property(l, "modulate", Color(1, 1, 1, 1), 0.3).set_delay(after + i * 0.035 + 0.12)
	lt.tween_property(line, "color:a", 1.0, 0.4).set_delay(after)
	lt.tween_property(line, "size:x", vs.x * 0.5, 0.7).set_delay(after).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lt.tween_property(line, "position:x", vs.x * 0.25, 0.7).set_delay(after).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lt.tween_property(sub, "modulate:a", 1.0, 0.6).set_delay(after + 0.3)
	var hold := after + maxf(1.2, float(DB.menu("splash_time", 2.5)) - 0.6)
	lt.tween_property(c, "modulate:a", 0.0, 0.8).set_delay(hold)
	for n in ui_nodes:
		lt.tween_property(n, "modulate:a", 1.0, 0.8).set_delay(hold + 0.3)
	lt.chain().tween_callback(func():
		_splash_ui = []
		if is_instance_valid(c):
			c.queue_free())
	_splash_tw = lt
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			lt.kill()
			_skip_splash())


var _splash_ui := []
var _splash_tw: Tween = null

func _skip_splash() -> void:
	if _splash_tw and _splash_tw.is_valid():
		_splash_tw.kill()
	for n in _splash_ui:
		if is_instance_valid(n):
			create_tween().tween_property(n, "modulate:a", 1.0, 0.3)
	_splash_ui = []
	if _splash_node and is_instance_valid(_splash_node):
		var n := _splash_node
		_splash_node = null
		var tw := create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.25)
		tw.tween_callback(n.queue_free)


func _make_bg() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ca := DB.color(DB.menu("bg_color_a", "#080d17"))
	var cb := DB.color(DB.menu("bg_color_b", "#29170a"))
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 ca : source_color; uniform vec4 cb : source_color; uniform float moving = 1.0;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),u.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),u.x),u.y);}
void fragment(){
	vec2 uv=UV*vec2(1.78,1.0);
	float t=TIME*0.03*moving;
	float c=n(uv*3.0+t)*0.5+n(uv*7.0-t*1.3)*0.3+n(uv*15.0+t*2.0)*0.2;
	vec3 col=mix(ca.rgb,cb.rgb,smoothstep(0.35,0.9,c)*(1.0-UV.y*0.6));
	float g=smoothstep(0.92,1.0,n(uv*40.0+vec2(0,TIME*0.2*moving)));
	col+=vec3(1.0,0.6,0.2)*g*0.25*moving;
	COLOR=vec4(col,1.0);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("ca", ca)
	sm.set_shader_parameter("cb", cb)
	sm.set_shader_parameter("moving", 1.0 if bool(DB.menu("bg_animated", true)) else 0.0)
	bg.material = sm
	add_child(bg)
	if _live_on():
		_make_live_bg()
		return
	var img: String = str(DB.menu("bg_image", ""))
	if img != "":
		var tex = ModelLib.texture(img)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			add_child(tr)


## 1.3: живой фон — 3D-база (scripts/menu_scene.gd) в своём мире за интерфейсом.
## Выключается в «Настройки → Графика → Живой фон меню» или у игры в редакторе («Главное меню»).
var live_view: SubViewport = null
var _live_shade: ColorRect = null

func _live_on() -> bool:
	if not bool(DB.menu("bg_live", true)) or not bool(Prefs.get_value("menu_live", true)):
		return false
	if "--menu_static" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return false
	return ResourceLoader.exists("res://scripts/menu_scene.gd")


## 1.3: настройка поменялась в меню — графика фона меняется сразу, «Живой фон меню» включается и выключается без перезапуска.
func on_pref_changed(key: String) -> void:
	if key == "language":
		# надписи Godot переводит сам, но заголовки и тексты из «Тексты и языки» строятся при создании меню
		if Lang.current() != _built_lang:
			_built_lang = Lang.current()
			get_tree().reload_current_scene.call_deferred()
		return
	if key == "menu_live":
		if not background_ready:
			return
		if live_view == null and _live_on():
			var n := get_child_count()
			_make_live_bg()
			for c in get_children():
				if c is TextureRect:
					c.queue_free()   # статичная картинка фона больше не нужна
			for i in range(get_child_count() - 1, n - 1, -1):   # живой фон — сразу над заливкой, под кнопками
				move_child(get_child(get_child_count() - 1), 1)
		elif live_view != null and not _live_on():
			live_view.get_parent().queue_free()
			if _live_shade:
				_live_shade.queue_free()
			live_view = null
			_live_shade = null
		return
	if key == "quality" and page and page.visible and _set_hud != null:
		_page_settings.call_deferred()   # пресет качества поменял ползунки — показать новые значения
	if live_view == null:
		return
	match key:
		"msaa":
			live_view.msaa_3d = Viewport.MSAA_2X if str(Prefs.get_value("msaa", "4x")) != "off" else Viewport.MSAA_DISABLED
		"render_scale":
			live_view.scaling_3d_scale = clampf(float(Prefs.get_value("render_scale", 1.0)), 0.5, 1.0)
		"fxaa":
			live_view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if bool(Prefs.get_value("fxaa", false)) else Viewport.SCREEN_SPACE_AA_DISABLED
		"lod_px":
			live_view.mesh_lod_threshold = clampf(float(Prefs.get_value("lod_px", 2.0)), 0.0, 16.0)
	for c in live_view.get_children():
		if c.has_method("apply_pref"):
			c.apply_pref(key)


func _make_live_bg() -> void:
	var box := SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	live_view = SubViewport.new()
	live_view.own_world_3d = true
	live_view.msaa_3d = Viewport.MSAA_2X if str(Prefs.get_value("msaa", "4x")) != "off" else Viewport.MSAA_DISABLED
	live_view.scaling_3d_scale = clampf(float(Prefs.get_value("render_scale", 1.0)), 0.5, 1.0)
	box.add_child(live_view)
	live_view.add_child(load("res://scripts/menu_scene.gd").new())
	# мягкое затемнение по центру, где заголовок и кнопки, — текст читается на любом кадре
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment(){
	vec2 d=(UV-vec2(0.5,0.5))*vec2(1.0/0.42,1.0/0.6);
	float m=exp(-dot(d,d));
	float v=smoothstep(0.45,1.0,length((UV-0.5)*vec2(1.3,1.0)));
	COLOR=vec4(0.0,0.01,0.03,clamp(m*0.42+v*0.55,0.0,0.85));
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	shade.material = mat
	add_child(shade)
	_live_shade = shade


## Кнопки главного меню — по списку из редактора (порядок, тексты, какие показывать).
func _make_buttons() -> void:
	var list: Array = DB.menu("buttons", [])
	if list.is_empty():
		list = [{"id": "continue"}, {"id": "new"}, {"id": "load"}, {"id": "editor"}, {"id": "mods"}, {"id": "settings"}, {"id": "quit"}]
	var names := {"continue": "Продолжить", "new": "Новая игра", "load": "Загрузить", "net": "Сетевая игра", "editor": "Редактор", "mods": "Моды и дополнения",
		"settings": "Настройки", "hero": "Герой", "help": "Как играть", "credits": "Авторы", "quit": "Выход", "command": "Команда"}
	var seen := {}
	for e in list:
		if not e is Dictionary or not bool(e.get("show", true)):
			continue
		var id := str(e.get("id", ""))
		seen[id] = true
		var txt := DB.t(e.get("text", "")) if str(e.get("text", "")) != "" else str(names.get(id, id))
		match id:
			"continue":
				if SavesUI.newest() != "":
					_btn(txt, _continue)
			"new": _btn(txt, _page_new)
			"load":
				if SavesUI.newest() != "":
					_btn(txt, _page_load)
			"editor":
				if DB.studio:
					_btn(txt, _editor)
			"net": _btn(txt, _page_net)
			"mods": _btn(txt, _page_mods)
			"settings": _btn(txt, _page_settings)
			"hero": _btn(txt, _page_hero)
			"help": _btn(txt, _page_help)
			"credits": _btn(txt, _page_credits)
			"quit": _btn(txt, func(): get_tree().quit())
			"command":
				var cmd := str(e.get("command", ""))
				_btn(txt, func(): _menu_command(cmd))
	# A13-1: мод не может убрать «Моды» и «Настройки» — иначе его не выключить из игры
	if not seen.has("mods"):
		_btn(str(names.get("mods", "Моды")), _page_mods)
	if not seen.has("settings"):
		_btn(str(names.get("settings", "Настройки")), _page_settings)


## 1.3: флаги языка в правом верхнем углу — клик сразу переключает игру на английский или русский.
func _make_flags(show := true) -> void:
	var h := HBoxContainer.new()
	h.name = "Flags"
	h.visible = show
	h.add_theme_constant_override("separation", 10)
	h.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	h.offset_left = -150
	h.offset_top = 16
	h.offset_right = -18
	h.alignment = BoxContainer.ALIGNMENT_END
	add_child(h)
	for e in [["en", "res://ui/flag_us.png", "English"], ["ru", "res://ui/flag_ru.png", "Русский"]]:
		var b := TextureButton.new()
		b.texture_normal = load(e[1])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(48, 32)
		b.tooltip_text = e[2]
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var on: bool = Lang.current() == e[0]
		b.modulate = Color.WHITE if on else Color(1, 1, 1, 0.45)
		b.scale = Vector2.ONE
		var code: String = e[0]
		b.mouse_entered.connect(func(): b.modulate.a = 1.0)
		b.mouse_exited.connect(func(): b.modulate.a = 1.0 if Lang.current() == code else 0.45)
		b.pressed.connect(func(): _set_language(code))
		h.add_child(b)


func _set_language(code: String) -> void:
	if Lang.current() == code:
		return
	Prefs.set_value("language", code)   # Prefs.apply → Lang.apply_locale, on_pref_changed перестроит меню


## Своя кнопка меню: открыть ссылку (open https://...) или начать игру с консольной командой.
func _menu_command(cmd: String) -> void:
	if cmd.begins_with("open "):
		# A13-1: только веб-ссылки (раньше мод открывал любой файл или программу: file:///…/setup.exe)
		var url := cmd.substr(5).strip_edges()
		if url.begins_with("https://") or url.begins_with("http://"):
			OS.shell_open(url)
		return
	_start({"profession": sel_prof, "command": cmd})


func _btn(t: String, cb: Callable) -> void:
	var b := UI.button(t, cb)
	b.custom_minimum_size = Vector2(300, 52)
	b.add_theme_font_size_override("font_size", 20)
	box.add_child(b)


func _page_new() -> void:
	var pv: Array = _scroll_page(DB.tx("new_game", "НОВАЯ ИГРА"), 680.0, 300.0)
	var outer: VBoxContainer = pv[0]
	var v: VBoxContainer = pv[1]
	if not _strat_read:
		_strat_read = true
		strat_on = true
	_mode_pick(v)
	if _module_on("professions") and not DB.data.professions.is_empty():
		v.add_child(UI.label(DB.tx("profession", "Профессия"), 16))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		var ids: Array = DB.data.professions.keys()
		ids.sort_custom(func(a, b): return int(DB.data.professions[a].get("order", 0)) < int(DB.data.professions[b].get("order", 0)))
		if not sel_prof in ids:
			sel_prof = ids[0]
		for id in ids:
			var p: Dictionary = DB.data.professions[id]
			var b := Button.new()
			b.custom_minimum_size = Vector2(200, 132)
			b.focus_mode = Control.FOCUS_NONE
			b.toggle_mode = true
			b.button_pressed = id == sel_prof
			# 1.0.9: выбранная карточка — тёмная с рамкой цвета акцента (на оранжевой заливке не было видно названия)
			var sel_box := UI.box(Color(0.17, 0.14, 0.09))
			sel_box.set_border_width_all(3)
			sel_box.border_color = UI.ACCENT
			b.add_theme_stylebox_override("pressed", sel_box)
			b.add_theme_stylebox_override("hover_pressed", sel_box)
			b.pressed.connect(func(): sel_prof = id; _page_new())
			var bv := UI.vbox(2)
			bv.set_anchors_preset(Control.PRESET_FULL_RECT)
			bv.offset_left = 8
			bv.offset_top = 6
			bv.offset_right = -8
			bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(bv)
			var hrow := UI.hbox(6)
			hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hrow.add_child(UI.profession_icon(id, 40))
			var nl := UI.label(p.get("name", id), 16, DB.color(p.get("color", "#ffffff")))
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hrow.add_child(nl)
			bv.add_child(hrow)
			var r := UI.rich(_bonus_text(p.get("bonus", {})), 12)
			bv.add_child(r)
			b.tooltip_text = p.get("desc", "")
			grid.add_child(b)
		var pd: Dictionary = DB.data.professions[sel_prof]
		v.add_child(UI.small(pd.get("desc", "")))
	var wd: Dictionary = DB.data.world
	var row := UI.hbox(8)
	row.add_child(UI.label(DB.tx("map", "Карта") + ":", 15))
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_item(DB.tx("map_random", "Случайная (процедурная)"))
	ob.add_item(DB.tx("map_fixed", "Готовая карта игры"))
	ob.set_item_disabled(1, str(wd.get("map_file", "")) == "")
	mode = "fixed" if wd.get("map_mode", "procedural") == "fixed" and str(wd.get("map_file", "")) != "" else mode
	ob.select(1 if mode == "fixed" else 0)
	ob.item_selected.connect(func(i): mode = "fixed" if i == 1 else "procedural")
	row.add_child(ob)
	row.add_child(UI.label(DB.tx("seed", "Зерно") + ":", 15))
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = DB.tx("random_seed", "случайное")
	seed_edit.custom_minimum_size = Vector2(130, 0)
	row.add_child(seed_edit)
	v.add_child(row)
	var row2 := UI.hbox(8)
	row2.add_child(UI.label(DB.tx("difficulty", "Сложность") + ":", 15))
	var dob := OptionButton.new()
	dob.focus_mode = Control.FOCUS_NONE
	# 1.5: больше ступеней — от мирной (волн и боссов нет) до «Ада»
	var diffs := DIFFS
	var cur := float(DB.setting("difficulty", 1.0))
	for i in diffs.size():
		dob.add_item("%s — %s" % [diffs[i][0], diffs[i][2]])
		dob.set_item_tooltip(i, "Сила роботов ×%s. Волны чаще или реже и больше или меньше роботов — по сложности и по тому, как далеко продвинулся завод." % diffs[i][1])
		if is_equal_approx(float(diffs[i][1]), cur):
			dob.select(i)
			difficulty = cur
	dob.item_selected.connect(func(i): difficulty = float(diffs[i][1]))
	row2.add_child(dob)
	v.add_child(row2)
	row2 = UI.hbox(8)
	# размер карты (для случайной карты)
	row2.add_child(UI.label(DB.tx("map_size", "Размер карты") + ":", 15))
	var sob := OptionButton.new()
	sob.focus_mode = Control.FOCUS_NONE
	var base_size := int(wd.get("size", 384))
	var sizes := map_sizes()
	if map_size == 0:
		map_size = base_size
	var found := false
	for i in sizes.size():
		sob.add_item("%s (%d)" % sizes[i])
		if int(sizes[i][1]) == map_size:
			sob.select(i)
			found = true
	if not found:
		sob.add_item("%d" % map_size)
		sizes.append(["", map_size])
		sob.select(sizes.size() - 1)
	sob.item_selected.connect(func(i): map_size = int(sizes[i][1]))
	row2.add_child(sob)
	# 1.0.8: сколько ресурсов на карте — меньше / обычно / больше месторождений
	row2.add_child(UI.label("   " + DB.tx("res_amount", "Ресурсы") + ":", 15))
	var rob := OptionButton.new()
	rob.focus_mode = Control.FOCUS_NONE
	var rl := res_levels()
	for i in rl.size():
		rob.add_item(str(rl[i][1]))
		if str(rl[i][0]) == res_amount:
			rob.select(i)
	rob.item_selected.connect(func(i): res_amount = str(rl[i][0]))
	row2.add_child(rob)
	v.add_child(row2)
	# 21: модули и все правила мира — те же вкладки и заготовки, что у сервера (запоминаются до следующей игры)
	var SrvSet = preload("res://scripts/server_settings.gd")
	var last = Prefs.get_value("sp_rules", {})
	room_ov = (last.get("ov", {}) as Dictionary).duplicate() if last is Dictionary and last.get("ov") is Dictionary else {}
	if strat_on:
		room_ov["settings/strategy"] = true
	else:
		room_ov.erase("settings/strategy")
	room_mods = {}
	for m in SrvSet.module_list():
		room_mods[m[0]] = SrvSet.module_default(m[0])
	if last is Dictionary and last.get("modules") is Dictionary:
		room_mods.merge(last.modules, true)
	for m in ng_modules:
		room_mods[m] = ng_modules[m]
	_room_rules(v, SrvSet, "Правила мира")
	var go := UI.button(DB.tx("start", "Начать"), func():
		var ov: Dictionary = SrvSet.changed(room_ov)
		Prefs.set_value("sp_rules", {"ov": ov, "modules": room_mods.duplicate()})
		_start({"profession": sel_prof, "map_mode": mode, "difficulty": difficulty, "size": map_size, "res": res_amount, "modules": room_mods.duplicate(), "ov": ov,
			"seed": int(seed_edit.text) if seed_edit.text.is_valid_int() else randi() % 999999 + 1}))
	go.custom_minimum_size = Vector2(0, 48)
	outer.add_child(go)


## Размеры карты на выбор: [[название, сторона]] («Мир» → «Размеры на выбор в новой игре»).
static func map_sizes() -> Array:
	var out := []
	for e in DB.data.world.get("map_sizes", [{"name": "Маленькая", "size": 256}, {"name": "Средняя", "size": 384}, {"name": "Большая", "size": 512}, {"name": "Огромная", "size": 768}]):
		if e is Dictionary:
			out.append([str(e.get("name", "")), int(e.get("size", 384))])
	return out


## 1.0.8: сколько ресурсов: [[id, название, множитель месторождений]] («Мир» → «Количество ресурсов на выбор»).
static func res_levels() -> Array:
	var out := []
	for e in DB.data.world.get("res_levels", [{"id": "few", "name": "Мало", "k": 0.5}, {"id": "normal", "name": "Обычно", "k": 1.0}, {"id": "many", "name": "Много", "k": 1.8}]):
		if e is Dictionary:
			out.append([str(e.get("id", "")), str(e.get("name", "")), float(e.get("k", 1.0))])
	return out


func _module_on(id: String) -> bool:
	if ng_modules.has(id):
		return bool(ng_modules[id])
	return bool(DB.data.settings.get("modules", {}).get(id, id == "professions"))


static func _bonus_text(b: Dictionary) -> String:
	var names := {"gather": "добыча", "belt_speed": "скорость лент", "build_cost": "цена зданий", "build_hp": "прочность зданий",
		"move": "скорость бега", "damage": "урон", "max_hp": "здоровье", "craft_speed": "скорость крафта", "sell": "цена продажи",
		"hunger": "голод", "regen": "лечение", "machine_speed": "скорость машин", "repair": "ремонт"}
	var parts := []
	for k in b:
		var v := float(b[k])
		var good := v > 0.0
		if k in ["build_cost", "hunger"]:
			good = not good
		var txt := ("%+d%%" % int(v * 100)) if absf(v) < 5 else ("%+d" % int(v))
		parts.append("[color=%s]%s %s[/color]" % ["#7dff9a" if good else "#ff6b5a", txt, names.get(k, k)])
	return "\n".join(parts) if not parts.is_empty() else "[color=#8a93a3]без бонусов[/color]"


func _start(ng: Dictionary) -> void:
	DB.set_meta("new_game", ng)
	LoadingScreen.go(get_tree(), "res://scenes/main.tscn")


func _continue() -> void:
	var s := SavesUI.newest()
	if s != "":
		SavesUI.start_from(get_tree(), s)


func _page_load() -> void:
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(10)
	page.add_child(v)
	v.add_child(UI.title(DB.tx("load_title", "ЗАГРУЗИТЬ ИГРУ"), 22))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, 400)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	v.add_child(sc)
	SavesUI.build(list, "load", func(slot): SavesUI.start_from(get_tree(), slot))


## Сетевая игра: ник и цвет героя, комнаты в вашей сети, вход по коду, создание своей комнаты.
func _page_net() -> void:
	page.visible = true
	UI.clear(page)
	Net.lan_listen(true)
	var v := UI.vbox(8)
	page.add_child(v)
	v.add_child(UI.title(DB.tx("net_title", "СЕТЕВАЯ ИГРА"), 22))
	var r1 := UI.hbox(8)
	r1.add_child(UI.label("Ваш ник"))
	var nick_e := LineEdit.new()
	nick_e.text = str(Prefs.get_value("net_nick", "Игрок"))
	nick_e.custom_minimum_size = Vector2(220, 0)
	r1.add_child(nick_e)
	var cp := ColorPickerButton.new()
	cp.color = DB.color(str(Prefs.get_value("net_color", "#ffa040")))
	cp.custom_minimum_size = Vector2(60, 30)
	r1.add_child(UI.label("Цвет"))
	r1.add_child(cp)
	r1.add_child(UI.button("Создать комнату…", func():
		_net_save_me(nick_e, cp)
		Net.lan_listen(false)
		_page_room()))
	# 1.6: выделенный сервер на VDS — миры создаются и настраиваются отсюда
	r1.add_child(UI.button("Управление сервером…", func():
		_net_save_me(nick_e, cp)
		Net.lan_listen(false)
		_page_admin()))
	v.add_child(r1)
	var st := UI.small("")
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(640, 0)
	# 18: общий список комнат в интернете, с поиском
	var lb = Net.lobby
	v.add_child(UI.section("Комнаты в интернете"))
	var rs := UI.hbox(8)
	var q_e := LineEdit.new()
	q_e.placeholder_text = "Поиск по названию или нику"
	q_e.custom_minimum_size = Vector2(280, 0)
	q_e.clear_button_enabled = true
	rs.add_child(q_e)
	var c_np := CheckBox.new()
	c_np.text = "без пароля"
	c_np.focus_mode = Control.FOCUS_NONE
	rs.add_child(c_np)
	var c_fr := CheckBox.new()
	c_fr.text = "есть места"
	c_fr.focus_mode = Control.FOCUS_NONE
	rs.add_child(c_fr)
	v.add_child(rs)
	var isc := ScrollContainer.new()
	isc.custom_minimum_size = Vector2(660, 150)
	isc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var ilist := UI.vbox(4)
	ilist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	isc.add_child(ilist)
	v.add_child(isc)
	var ishown := [""]
	var irefill := func(force := false):
		if lb == null:
			return
		var found: Array = lb.search(q_e.text, c_np.button_pressed, c_fr.button_pressed)
		var sig: String = str(found.map(func(d): return [d.id, d.get("players", 0)])) + q_e.text + str(c_np.button_pressed) + str(c_fr.button_pressed) + lb.msg + str(lb.updated_at > 0)
		if sig == ishown[0] and not force:
			return
		ishown[0] = sig
		UI.clear(ilist)
		if found.is_empty():
			var t: String = lb.msg if lb.msg != "" else ("Ищем комнаты…" if lb.updated_at == 0 else ("Ничего не найдено." if q_e.text.strip_edges() != "" else "Сейчас открытых комнат нет. Создайте свою — её увидят все."))
			ilist.add_child(UI.small(t))
		var starts := {"together": "все у одного штаба", "nearby": "свои базы рядом", "far": "свои базы далеко"}
		for d in found:
			var row := UI.hbox(8)
			var full: bool = int(d.get("players", 0)) >= int(d.get("max", 8))
			var lbl := UI.label("%s — %s · %d/%d · %s%s" % [str(d.get("name", "")), str(d.get("host", "")), int(d.get("players", 0)), int(d.get("max", 8)),
				starts.get(str(d.get("start", "")), ""), (" · с паролем" if d.get("pass", false) else "") + (" · выделенный сервер" if d.get("ded", false) else "")], 15)
			lbl.tooltip_text = "Адрес %s:%d%s" % [str(d.get("ip", "")), int(d.get("port", Net.PORT)), "" if bool(d.get("upnp", false)) else "\nРоутер хозяина не открыл порт сам — игра попробует «пробить» его. Если не пустит: хозяину открыть порт %d UDP или играть через Radmin VPN / ZeroTier." % int(d.get("port", Net.OPEN_PORT))]
			lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
			var pe := LineEdit.new()
			pe.placeholder_text = "пароль"
			pe.secret = true
			pe.custom_minimum_size = Vector2(110, 0)
			pe.visible = bool(d.get("pass", false))
			row.add_child(pe)
			var bt := UI.button("Войти", func():
				_net_save_me(nick_e, cp)
				var err: String = Net.join(str(d.ip), int(d.get("port", 0)), pe.text)
				st.text = err if err != "" else Net.status)
			bt.disabled = full or str(d.get("ver", "")) != DB.game_version()
			bt.tooltip_text = "Комната заполнена" if full else ("Другая версия игры: %s" % str(d.get("ver", "")) if bt.disabled else "")
			row.add_child(bt)
			ilist.add_child(row)
	q_e.text_changed.connect(func(_t): irefill.call())
	c_np.toggled.connect(func(_b): irefill.call())
	c_fr.toggled.connect(func(_b): irefill.call())
	var ir := UI.hbox(8)
	ir.add_child(UI.button("Обновить", func(): if lb: lb.refresh()))
	var ihint := UI.small("Открытые комнаты всех игроков. Список обновляется сам. Порт у хозяина открывать не обязательно: игра сама «пробивает» роутер через сервер объявлений. Не вышло (мобильный интернет, строгий роутер) — хозяину включить UPnP или открыть порт комнаты (UDP), или играть через Radmin VPN / ZeroTier.")
	ihint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ihint.custom_minimum_size = Vector2(540, 0)
	ir.add_child(ihint)
	v.add_child(ir)
	if lb:
		lb.listing = true
		lb.refresh()
	v.add_child(UI.section("Комнаты в вашей сети"))
	v.add_child(UI.small("Дома по Wi-Fi, в компьютерном клубе или вместе в Radmin VPN / ZeroTier — комнаты видны сами."))
	var list := UI.vbox(4)
	v.add_child(list)
	var shown := [""]
	var refill := func():
		var keys: Array = Net.lan_rooms.keys()
		keys.sort()
		var sig := str(keys) + str(keys.map(func(k): return Net.lan_rooms[k].players))
		if sig == shown[0]:
			return
		shown[0] = sig
		UI.clear(list)
		if keys.is_empty():
			list.add_child(UI.small(Net.lan_msg if Net.lan_msg != "" else "Пока никого. Комната появится здесь, как только кто-то в вашей сети её создаст."))
		for k in keys:
			var d: Dictionary = Net.lan_rooms[k]
			var row := UI.hbox(8)
			var starts := {"together": "все у одного штаба", "nearby": "свои базы рядом", "far": "свои базы далеко"}
			row.add_child(UI.label("%s — %s · %d/%d · %s%s" % [str(d.get("name", "")), str(d.get("host", "")), int(d.get("players", 0)), int(d.get("max", 8)),
				starts.get(str(d.get("start", "")), ""), (" · с паролем" if d.get("pass", false) else "") + (" · выделенный сервер" if d.get("ded", false) else "")], 15))
			var pe := LineEdit.new()
			pe.placeholder_text = "пароль"
			pe.secret = true
			pe.custom_minimum_size = Vector2(110, 0)
			pe.visible = bool(d.get("pass", false))
			row.add_child(pe)
			var full: bool = int(d.get("players", 0)) >= int(d.get("max", 8))
			var bt := UI.button("Войти", func():
				_net_save_me(nick_e, cp)
				var err: String = Net.join(str(d.ip), int(d.get("port", 0)), pe.text)
				st.text = err if err != "" else Net.status)
			bt.disabled = full or str(d.get("ver", "")) != DB.game_version()
			bt.tooltip_text = "Комната заполнена" if full else ("Другая версия игры: %s" % str(d.get("ver", "")) if bt.disabled else "")
			row.add_child(bt)
			list.add_child(row)
	refill.call()
	v.add_child(UI.section("Войти по коду комнаты"))
	v.add_child(UI.small("Код показывает хозяин (в меню комнаты и в игре справа), в нём уже есть порт. Подойдёт и адрес вида 192.168.1.5 или 192.168.1.5:443 (адрес:порт)."))
	var r3 := UI.hbox(8)
	var code_e := LineEdit.new()
	code_e.placeholder_text = "Код, например K7Q2M-9XAB3"
	code_e.text = str(Prefs.get_value("net_last_ip", ""))
	code_e.custom_minimum_size = Vector2(260, 0)
	r3.add_child(code_e)
	var pass_e := LineEdit.new()
	pass_e.placeholder_text = "пароль (если есть)"
	pass_e.secret = true
	pass_e.custom_minimum_size = Vector2(170, 0)
	r3.add_child(pass_e)
	r3.add_child(UI.button("Войти", func():
		_net_save_me(nick_e, cp)
		Prefs.set_value("net_last_ip", code_e.text.strip_edges())
		var err: String = Net.join(code_e.text, 0, pass_e.text)
		st.text = err if err != "" else Net.status))
	v.add_child(r3)
	v.add_child(st)
	var tm := Timer.new()
	tm.wait_time = 0.4
	tm.autostart = true
	tm.timeout.connect(func():
		refill.call()
		irefill.call()
		if Net.status != "":
			st.text = Net.status)
	v.add_child(tm)


func _net_save_me(nick_e: LineEdit, cp: ColorPickerButton) -> void:
	Prefs.set_value("net_nick", nick_e.text.strip_edges() if nick_e.text.strip_edges() != "" else "Игрок")
	Prefs.set_value("net_color", "#" + cp.color.to_html(false))
	Net.nick = str(Prefs.get_value("net_nick", "Игрок"))
	Net.color = str(Prefs.get_value("net_color", "#ffa040"))


## Высота прокручиваемой части страницы: страница не вылезает за экран (1280×720 и меньше).
func _page_h(reserve := 330.0) -> float:
	return clampf(get_viewport_rect().size.y - reserve, 260.0, 900.0)


## Страница с прокруткой: [внешний столбец, прокручиваемый столбец].
func _scroll_page(title: String, w := 700.0, reserve := 330.0) -> Array:
	page.visible = true
	UI.clear(page)
	var outer := UI.vbox(6)
	page.add_child(outer)
	outer.add_child(UI.title(title, 22))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(minf(w, get_viewport_rect().size.x - 380.0), _page_h(reserve))
	var v := UI.vbox(7)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	outer.add_child(sc)
	return [outer, v, sc]


## Своя комната (сервер): название, видимость, пароль, игроки, порт, карта, старт, права, деньги
## и 1.0.9 «Настройки сервера» — почти все правила игры из редактора по вкладкам (server_settings.gd), с заготовками.
var room_ov := {}        # путь правила → значение (что задано на странице)
var _strat_read := false
var strat_on := false    # 1.1.15: режим «Стратегия» (settings/strategy) — первая большая галочка
var room_mods := {}      # модуль → вкл/выкл
var _room_set := {}      # путь → Callable(значение): обновить поле на странице (заготовки)

func _page_room(adm := false) -> void:
	if Net.lobby:
		Net.lobby.listing = false
	var SrvSet = preload("res://scripts/server_settings.gd")
	var pv: Array = _scroll_page("НОВЫЙ МИР НА СЕРВЕРЕ" if adm else "СОЗДАТЬ КОМНАТУ (СЕРВЕР)", 720.0, 300.0)
	var outer: VBoxContainer = pv[0]
	var v: VBoxContainer = pv[1]
	var rm: Dictionary = Net.room_defaults()
	var last = Prefs.get_value("net_room", {})
	if last is Dictionary:
		rm.merge(last, true)
	room_ov = (rm.get("ov", {}) as Dictionary).duplicate() if rm.get("ov") is Dictionary else {}
	room_mods = {}
	for m in SrvSet.module_list():
		room_mods[m[0]] = SrvSet.module_default(m[0])
	if rm.get("modules") is Dictionary:
		room_mods.merge(rm.modules, true)
	room_ov.erase("settings/strategy")   # 1.1.17: новый мир или комната — всегда с героем, пока не отметят «Стратегию»
	strat_on = false
	_mode_pick(v)
	v.add_child(UI.section("Комната"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	v.add_child(g)
	var row := func(t: String, c: Control, tip := ""):
		var l := UI.label(t, 15)
		l.tooltip_text = tip
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		g.add_child(l)
		c.custom_minimum_size = Vector2(380, 0)
		c.tooltip_text = tip
		g.add_child(c)
	var world_e := LineEdit.new()
	world_e.placeholder_text = "Мир"
	world_e.max_length = 40
	if adm:
		# 1.6: мир создаётся на выделенном сервере, у мира своё имя (в списке миров сервера)
		var ad: Dictionary = _adm_info.get("defaults", {})
		for k in ["size", "res", "start", "access", "wallets"]:
			if ad.has(k) and not (last is Dictionary and last.has(k)):
				rm[k] = ad[k]
		world_e.text = "Мир %d" % (_adm_info.get("worlds", []).size() + 1)
		row.call("Название мира", world_e, "Под этим именем мир будет в списке миров сервера")
	var name_e := LineEdit.new()
	name_e.text = str(rm.get("name", ""))
	name_e.placeholder_text = str(_adm_info.get("name", "")) if adm else "Комната %s" % Net.nick
	row.call("Название сервера" if adm else "Название", name_e)
	var opt := func(items: Array, cur: String) -> OptionButton:
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		for i in items.size():
			ob.add_item(str(items[i][1]), i)
			if str(items[i][0]) == cur:
				ob.select(i)
		return ob
	var vis_l := [["public", "Открытая: видна в списке комнат"], ["private", "Закрытая: только по коду"]]
	var vis := opt.call(vis_l, "public" if bool(rm.get("public", true)) else "private")
	row.call("Кто видит", vis)
	var pass_e := LineEdit.new()
	pass_e.placeholder_text = "без пароля"
	pass_e.text = str(rm.get("password", ""))
	row.call("Пароль", pass_e)
	var mx := SpinBox.new()
	mx.min_value = 2
	mx.max_value = 64
	mx.value = int(rm.get("max_players", 8))
	row.call("Игроков до", mx)
	# 1.0.8: порт, размер карты и сколько ресурсов
	var port_s := SpinBox.new()
	port_s.min_value = 1
	port_s.max_value = 65535
	port_s.value = int(rm.get("port", Net.default_port()))
	row.call("Порт (UDP)", port_s, "UDP-порт комнаты. 443 — по умолчанию: исходящие на него пускают почти все сети. Занят — игра сама возьмёт 24680.")
	if adm:
		# порт сервера задаётся в server.cfg на самом сервере
		g.get_child(g.get_child_count() - 1).visible = false
		g.get_child(g.get_child_count() - 2).visible = false
	var sizes := map_sizes()
	var size_ob := OptionButton.new()
	size_ob.focus_mode = Control.FOCUS_NONE
	var want_size := int(rm.get("size", int(DB.data.world.get("size", 384))))
	for i in sizes.size():
		size_ob.add_item("%s (%d)" % sizes[i])
		if int(sizes[i][1]) == want_size:
			size_ob.select(i)
	row.call("Размер карты", size_ob)
	var res_l := res_levels()
	var res_ob := opt.call(res_l.map(func(e): return [e[0], e[1]]), str(rm.get("res", "normal")))
	row.call("Ресурсов на карте", res_ob)
	var seed_e := LineEdit.new()
	seed_e.placeholder_text = "случайное"
	seed_e.text = str(rm.get("seed", "")) if int(rm.get("seed", 0)) > 0 else ""
	row.call("Зерно карты", seed_e, "Одинаковое зерно — одинаковая карта. Пусто — случайная")
	var start_l := [["together", "Все вместе у одного штаба"], ["nearby", "Свои базы недалеко друг от друга"], ["far", "Свои базы далеко (торговать выгоднее)"]]
	var start := opt.call(start_l, str(rm.get("start", "together")))
	row.call("Старт", start)
	var acc_l := [["all", "Можно брать и класть (как общий завод)"], ["put", "Можно только класть (подарки, торговля)"], ["none", "Чужое трогать нельзя"]]
	var acc := opt.call(acc_l, str(rm.get("access", "put")))
	row.call("Чужие ящики, печи…", acc)
	var wal_l := [["shared", "Общие на всех"], ["own", "У каждого свои (торговля за кредиты)"]]
	var wal := opt.call(wal_l, str(rm.get("wallets", "own")))
	row.call("Деньги", wal)
	var chk := func(t: String, on: bool) -> CheckBox:
		var cb := CheckBox.new()
		cb.text = t
		cb.button_pressed = on
		cb.focus_mode = Control.FOCUS_NONE
		return cb
	var ct := chk.call("Торговля между игроками (рынки, энергия, переводы)", bool(rm.get("trade", true)))
	var cpk := chk.call("Подколы (снежки, краска, подушки, кирпичи…)", bool(rm.get("pranks", true)))
	var cu := chk.call("Открыть порт на роутере сам (UPnP) — для игры через интернет", bool(rm.get("upnp", true)))
	var cph := chk.call("Пробивать роутер для друзей из интернета (без UPnP и ручного порта)", bool(rm.get("punch", true)))
	var csc := chk.call("Изученное в сканере — общее для всех (выключите — каждый изучает сам)", bool(rm.get("shared_scan", true)))
	for cb in [ct, cpk, cu, cph, csc]:
		v.add_child(cb)
	csc.visible = bool(DB.data.settings.get("scan", {}).get("enabled", false))   # 1.5: сканера нет
	if adm:
		cu.visible = false
		cph.visible = false
	_room_rules(v, SrvSet)
	var hint := UI.small("Сервер сохранит прежний мир, перезапустится и создаст новый — это займёт около минуты. Все игроки на сервере увидят предупреждение в чате и смогут зайти снова." if adm else "Мир комнаты сохраняется сам (по умолчанию каждые 2 минуты), когда кто-то входит или выходит и когда вы выходите из игры, — потом его можно продолжить («Продолжить мир»). Вещи, уровень и навыки друзей хранятся в этом же мире по их никам. Настройки сервера получают все игроки при входе. Сервер без своего героя (на VPS, круглые сутки) — папка «FrontierCorp_Server» и файл ЧИТАЙ_МЕНЯ.txt в ней.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(560, 0)
	v.add_child(hint)
	var st := UI.small("")
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(560, 0)
	var make := func() -> String:
		var ov: Dictionary = SrvSet.changed(room_ov)
		var r := {"name": name_e.text.strip_edges(), "public": vis.selected == 0, "password": pass_e.text, "max_players": int(mx.value),
			"start": start_l[start.selected][0], "access": acc_l[acc.selected][0], "wallets": wal_l[wal.selected][0],
			"trade": ct.button_pressed, "pranks": cpk.button_pressed, "upnp": cu.button_pressed, "shared_scan": csc.button_pressed,
			"punch": cph.button_pressed, "port": int(port_s.value), "size": int(sizes[maxi(0, size_ob.selected)][1]), "res": str(res_l[maxi(0, res_ob.selected)][0]),
			"seed": int(seed_e.text) if seed_e.text.strip_edges().is_valid_int() else 0, "modules": room_mods.duplicate(), "ov": ov}
		var keep := r.duplicate(true)
		Prefs.set_value("net_room", keep)
		Prefs.set_value("net_port", int(port_s.value))
		return Net.host(int(port_s.value), int(mx.value), r)
	var r2 := UI.hbox(8)
	if adm:
		r2.add_child(UI.button("Создать мир на сервере", func():
			var r := {"name": name_e.text.strip_edges() if name_e.text.strip_edges() != "" else str(_adm_info.get("name", "")),
				"public": vis.selected == 0, "password": pass_e.text, "max_players": int(mx.value),
				"start": start_l[start.selected][0], "access": acc_l[acc.selected][0], "wallets": wal_l[wal.selected][0],
				"trade": ct.button_pressed, "pranks": cpk.button_pressed, "size": int(sizes[maxi(0, size_ob.selected)][1]),
				"res": str(res_l[maxi(0, res_ob.selected)][0]), "seed": int(seed_e.text) if seed_e.text.strip_edges().is_valid_int() else 0,
				"modules": room_mods.duplicate(), "ov": SrvSet.changed(room_ov)}
			var keep := r.duplicate(true)
			Prefs.set_value("net_room", keep)
			st.text = "Отправляю на сервер…"
			var ans: Dictionary = await _adm.api("create", {"title": world_e.text, "room": r})
			if not bool(ans.get("ok", false)):
				st.text = str(ans.get("err", "Ошибка"))
				return
			_admin_wait("Сервер создаёт мир «%s»…" % world_e.text, str(ans.slot))))
		r2.add_child(UI.button("Назад", _admin_refresh))
		outer.add_child(r2)
		outer.add_child(st)
		return
	r2.add_child(UI.button("Новый мир", func():
		var err: String = make.call()
		if err != "":
			st.text = err
			return
		var sd := int(seed_e.text) if seed_e.text.strip_edges().is_valid_int() and int(seed_e.text) > 0 else randi() % 999999 + 1
		_start({"profession": sel_prof, "modules": room_mods.duplicate(), "seed": sd,
			"size": int(sizes[maxi(0, size_ob.selected)][1]), "res": str(res_l[maxi(0, res_ob.selected)][0])})))
	# 18: продолжить сохранённый мир — сетевые миры сверху, самые свежие первыми
	var slots: Array = SavesUI.slot_ids(true).filter(func(sl): return SavesUI.exists(sl))
	slots.sort_custom(func(x, y):
		var nx: bool = str(x).begins_with("net_")
		var ny: bool = str(y).begins_with("net_")
		if nx != ny:
			return nx
		return int(SavesUI.info(x).get("mtime", 0)) > int(SavesUI.info(y).get("mtime", 0)))
	if not slots.is_empty():
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		for sl in slots:
			pick.add_item("%s — %s" % [SavesUI.slot_name(sl), SavesUI.describe(SavesUI.info(sl))])
		pick.custom_minimum_size = Vector2(300, 0)
		pick.clip_text = true
		r2.add_child(UI.button("Продолжить мир:", func():
			var err: String = make.call()
			if err != "":
				st.text = err
				return
			var sl: String = slots[maxi(0, pick.selected)]
			Net.slot_override = sl if sl.begins_with("net_") else ""
			SavesUI.start_from(get_tree(), sl)))
		r2.add_child(pick)
	r2.add_child(UI.button("Назад", _page_net))
	outer.add_child(r2)
	outer.add_child(st)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room_scroll="):   # для скриншотов
			var sc: ScrollContainer = pv[2]
			var y := int(a.substr(14))
			get_tree().create_timer(0.3).timeout.connect(func(): sc.scroll_vertical = y)


## «Настройки сервера»: заготовки и вкладки с правилами мира (поля строятся по схеме редактора).
## 1.1.15: первая большая галочка новой игры и сервера — играть героем или как стратегию (без героя).
func _mode_pick(v: VBoxContainer) -> void:
	var pn := PanelContainer.new()
	var sb := UI.box(Color(0.12, 0.11, 0.09))
	sb.set_border_width_all(2)
	sb.border_color = UI.ACCENT
	sb.set_content_margin_all(10)
	pn.add_theme_stylebox_override("panel", sb)
	var pv := UI.vbox(4)
	pn.add_child(pv)
	var cb := CheckBox.new()
	cb.text = DB.tx("strat_mode", "Стратегия — играть без героя")
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 24)
	cb.custom_minimum_size = Vector2(0, 52)
	cb.button_pressed = strat_on
	pv.add_child(cb)
	var hint := UI.small("")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(560, 0)
	pv.add_child(hint)
	var show := func():
		hint.text = DB.tx("strat_on_hint", "Героя нет: камера свободно летает над картой (WASD или край экрана). Щёлкните по зданию — откроется его окно, по камню или дереву — добыча лучшим инструментом из рюкзака. Монстры идут сразу на здания, оборона — турели, стены и щиты. Нет здоровья и голода.") if strat_on \
			else DB.tx("strat_off_hint", "Обычная игра: вы управляете героем — он ходит, добывает, сражается, ест и пьёт. Поставьте галочку, чтобы играть как в стратегии, без героя.")
	show.call()
	cb.toggled.connect(func(on: bool):
		strat_on = on
		if on:
			room_ov["settings/strategy"] = true
		else:
			room_ov.erase("settings/strategy")
		show.call())
	v.add_child(pn)


func _room_rules(v: VBoxContainer, SrvSet, title := "Настройки сервера") -> void:
	_room_set = {}
	v.add_child(UI.section(title))
	var info := UI.small("")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(560, 0)
	var count_changed := func():
		var n: int = SrvSet.changed(room_ov).size()
		var off := 0
		for m in room_mods:
			if bool(room_mods[m]) != SrvSet.module_default(m):
				off += 1
		info.text = "Изменено правил: %d, модулей: %d. Наведите на подпись — подсказка и обычное значение. Оранжевым — изменённые." % [n, off]
	var pr := HFlowContainer.new()
	pr.add_theme_constant_override("h_separation", 6)
	pr.add_theme_constant_override("v_separation", 6)
	pr.add_child(UI.label("Заготовки:", 15))
	var apply_preset := func(name: String):
		var p: Dictionary = SrvSet.preset(name) if name != "" else {"ov": {}, "modules": {}}
		room_ov = p.ov.duplicate()
		if strat_on:
			room_ov["settings/strategy"] = true   # режим игры заготовки не меняют
		for m in room_mods:
			room_mods[m] = bool(p.modules.get(m, SrvSet.module_default(m)))
		for path in _room_set:
			var val = room_ov.get(path) if room_ov.has(path) else (room_mods.get(path.substr(8)) if path.begins_with("modules/") else SrvSet.base(path))
			_room_set[path].call(val)
		count_changed.call()
	for nm in ["Мирный", "Очень лёгкий", "Лёгкий", "Обычный", "Сложный", "Хардкор", "Безумие", "Песочница"]:
		var tip: String = {"Мирный": "Без волн и боссов, бродячие роботы слабые, голод медленный, вещи не теряются",
			"Очень лёгкий": "Волны вдвое реже и меньше, роботы слабые, быстрее добыча и крафт, много денег",
			"Обычный": "Правила игры как есть", "Лёгкий": "Слабее и реже монстры, вещи не теряются, быстрее добыча и крафт, больше денег",
			"Сложный": "Роботы ×1.5, волны чуть чаще и больше, при гибели теряется часть денег",
			"Хардкор": "Сложность «Кошмар», частые волны, голод и климат, вещи пропадают при гибели, дороже стройка, нет стартовых кредитов",
			"Безумие": "Роботы ×3, волны очень часто, боссы каждые 3 дня, голод и климат, вещи пропадают при гибели, нет стартовых кредитов",
			"Песочница": "Без монстров и голода, всё открыто, много денег, быстрая добыча и крафт"}[nm]
		pr.add_child(UI.button(nm, apply_preset.bind(nm), tip))
	pr.add_child(UI.button("Сбросить", apply_preset.bind(""), "Все правила и модули — как в игре"))
	v.add_child(pr)
	v.add_child(info)
	# 1.3: «Натиск» — галочка и два времени на виду
	for e in SrvSet.entries(SrvSet.QUICK):
		if not e.has("header"):
			v.add_child(_rule_row(e, SrvSet, count_changed))
	# вкладки: кнопки в несколько рядов (все видны сразу), под ними — поля выбранной вкладки
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	v.add_child(tabs)
	var bg := ButtonGroup.new()
	var pages := []
	var tab_list: Array = [["Модули", []]] + SrvSet.TABS
	var cur_tab := int(Prefs.get_value("net_room_tab", 0))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room_tab="):   # для скриншотов
			cur_tab = int(a.substr(11))
	for ti in tab_list.size():
		var tb := Button.new()
		tb.text = str(tab_list[ti][0])
		tb.toggle_mode = true
		tb.button_group = bg
		tb.focus_mode = Control.FOCUS_NONE
		tabs.add_child(tb)
		var pg := UI.vbox(4)
		pg.visible = false
		v.add_child(pg)
		pages.append(pg)
		var idx := ti
		tb.toggled.connect(func(on):
			pg.visible = on
			if on:
				Prefs.values["net_room_tab"] = idx)
		if ti == clampi(cur_tab, 0, tab_list.size() - 1):
			tb.button_pressed = true
			pg.visible = true
	# модули
	var mg := GridContainer.new()
	mg.columns = 2
	mg.add_theme_constant_override("h_separation", 16)
	pages[0].add_child(UI.small("Целые системы игры: включите или выключите для этого мира."))
	pages[0].add_child(mg)
	for m in SrvSet.module_list():
		var c := CheckBox.new()
		c.text = str(m[1])
		c.tooltip_text = str(m[2])
		c.focus_mode = Control.FOCUS_NONE
		c.button_pressed = bool(room_mods.get(m[0], SrvSet.module_default(m[0])))
		c.custom_minimum_size = Vector2(330, 0)
		var mid: String = m[0]
		c.toggled.connect(func(on):
			room_mods[mid] = on
			count_changed.call())
		_room_set["modules/" + mid] = func(val): c.set_pressed_no_signal(bool(val))
		mg.add_child(c)
	# правила по вкладкам
	for ti in range(1, tab_list.size()):
		var pg: VBoxContainer = pages[ti]
		for e in SrvSet.entries(tab_list[ti][1]):
			if e.has("header"):
				var hl := UI.label(str(e.header), 15, UI.ACCENT)
				hl.add_theme_font_override("font", UI.bold())
				hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				hl.custom_minimum_size = Vector2(540, 0)
				pg.add_child(hl)
				continue
			pg.add_child(_rule_row(e, SrvSet, count_changed))
	count_changed.call()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room_preset="):   # для скриншотов и проверки
			apply_preset.call(a.substr(14))


## Строка правила: подпись (оранжевая, если изменено) и поле нужного вида.
func _rule_row(e: Dictionary, SrvSet, on_change: Callable) -> Control:
	var path: String = e.path
	var kind: String = e.kind
	var b = SrvSet.base(path)
	var h := UI.hbox(8)
	var l := UI.label(str(e.label), 14)
	l.custom_minimum_size = Vector2(330, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	var bt := str(b) if kind != "bool" else ("да" if b else "нет")
	if kind.begins_with("enum:"):
		for it in SrvSet.enum_items(kind):
			if str(it[0]) == str(b):
				bt = str(it[1])
	l.tooltip_text = ((str(e.hint) + "\n") if str(e.hint) != "" else "") + "Обычно: " + bt
	h.add_child(l)
	var cur = room_ov.get(path, b)
	var mark := func(val):
		var diff: bool = not SrvSet.changed({path: val}).is_empty()
		l.add_theme_color_override("font_color", UI.ACCENT if diff else UI.TEXT)
	var set_v := func(val):
		room_ov[path] = val
		mark.call(val)
		on_change.call()
	var c: Control
	if kind == "bool":
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = bool(cur)
		cb.toggled.connect(func(on): set_v.call(on))
		_room_set[path] = func(val):
			cb.set_pressed_no_signal(bool(val))
			mark.call(bool(val))
		c = cb
	elif kind == "int":
		var sp := SpinBox.new()
		sp.min_value = -1000000
		sp.max_value = 100000000
		sp.step = 1
		sp.rounded = true
		sp.value = int(cur)
		sp.value_changed.connect(func(x): set_v.call(int(x)))
		_room_set[path] = func(val):
			sp.set_value_no_signal(int(val))
			mark.call(int(val))
		c = sp
	elif kind == "float":
		var le := LineEdit.new()
		le.text = _num(float(cur))
		le.text_changed.connect(func(t):
			var tt: String = str(t).strip_edges().replace(",", ".")
			if tt.is_valid_float():
				le.remove_theme_color_override("font_color")
				set_v.call(float(tt))
			else:
				le.add_theme_color_override("font_color", UI.BAD))
		_room_set[path] = func(val):
			le.text = _num(float(val))
			mark.call(float(val))
		c = le
	else:
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		var items: Array = SrvSet.enum_items(kind)
		for i in items.size():
			ob.add_item(str(items[i][1]))
			if str(items[i][0]) == str(cur):
				ob.select(i)
		ob.item_selected.connect(func(i): set_v.call(str(items[i][0])))
		_room_set[path] = func(val):
			for i in items.size():
				if str(items[i][0]) == str(val):
					ob.select(i)
			mark.call(str(val))
		c = ob
	c.custom_minimum_size = Vector2(200, 0)
	c.tooltip_text = l.tooltip_text
	h.add_child(c)
	mark.call(cur)
	return h


static func _num(x: float) -> String:
	var t := ("%.4f" % x).rstrip("0").rstrip(".")
	return t if t != "" and t != "-0" else "0"


## 1.3: выбор героя — список моделей «Герои» слева, живая модель справа (крутится, держит бластер).
## Выбор сохраняется в настройках (hero_look) и виден другим игрокам в сетевой игре.
## 1.6: «Управление сервером» — выделенный сервер на VDS, как в Satisfactory: вход по адресу и паролю администратора,
## создание мира с настройками, список миров (загрузить, пересоздать, удалить), сохранить, остановить, перезапустить.
var _adm: Node = null
var _adm_info := {}


func _adm_node() -> Node:
	if _adm == null or not is_instance_valid(_adm):
		_adm = preload("res://scripts/admin_client.gd").new()
		add_child(_adm)
	return _adm


func _page_admin(msg := "") -> void:
	_adm_node()
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(8)
	page.add_child(v)
	v.add_child(UI.title("УПРАВЛЕНИЕ СЕРВЕРОМ", 22))
	var hint := UI.small("Свой выделенный сервер (VDS, круглосуточно): программа сервера ставится на него один раз (install_server.sh), а миры создаются и настраиваются отсюда. "
		+ "Адрес — как для входа в игру: IP или IP:порт. Пароль администратора задаёт первый, кто зайдёт сюда.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(620, 0)
	v.add_child(hint)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	v.add_child(g)
	var addr_e := LineEdit.new()
	addr_e.placeholder_text = "например 212.57.118.204 или 212.57.118.204:443"
	addr_e.text = str(Prefs.get_value("admin_addr", ""))
	addr_e.custom_minimum_size = Vector2(380, 0)
	g.add_child(UI.label("Адрес сервера"))
	g.add_child(addr_e)
	var pw_e := LineEdit.new()
	pw_e.secret = true
	pw_e.placeholder_text = "пароль администратора"
	pw_e.custom_minimum_size = Vector2(380, 0)
	pw_e.text = _adm.pw
	g.add_child(UI.label("Пароль"))
	g.add_child(pw_e)
	var st := UI.small(msg)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(620, 0)
	var r := UI.hbox(8)
	var go := func():
		var a: String = preload("res://scripts/admin_client.gd").norm_addr(addr_e.text)
		if a == "":
			st.text = "Впишите адрес сервера"
			return
		Prefs.set_value("admin_addr", addr_e.text.strip_edges())
		_adm.addr = a
		_adm.pw = pw_e.text
		st.text = "Подключаюсь к %s…" % a
		var inf: Dictionary = await _adm.api("info")
		if not bool(inf.get("ok", false)):
			st.text = str(inf.get("err", "Ошибка"))
			return
		if not bool(inf.get("claimed", true)):
			_page_admin_claim(inf)
			return
		if _adm.pw == "":
			st.text = "Сервер «%s» на связи (версия %s). Впишите пароль администратора." % [str(inf.get("name", "")), str(inf.get("version", ""))]
			return
		_admin_refresh()
	r.add_child(UI.button("Подключиться", go))
	r.add_child(UI.button("Назад", _page_net))
	v.add_child(r)
	v.add_child(st)
	pw_e.text_submitted.connect(func(_t): go.call())


## Первый вход: у сервера ещё нет администратора — задать пароль.
func _page_admin_claim(inf: Dictionary) -> void:
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(8)
	page.add_child(v)
	v.add_child(UI.title("НОВЫЙ СЕРВЕР", 22))
	var t := UI.label("Сервер «%s» (версия %s) ещё без администратора. Придумайте пароль администратора — с ним вы будете создавать и менять миры. Запишите его: сбросить его можно только на самом сервере (команда admin_reset)." % [
		str(inf.get("name", "")), str(inf.get("version", ""))], 15)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(620, 0)
	v.add_child(t)
	var p1 := LineEdit.new()
	p1.secret = true
	p1.placeholder_text = "пароль (хотя бы 4 знака)"
	p1.custom_minimum_size = Vector2(300, 0)
	var p2 := LineEdit.new()
	p2.secret = true
	p2.placeholder_text = "ещё раз"
	p2.custom_minimum_size = Vector2(300, 0)
	v.add_child(p1)
	v.add_child(p2)
	var st := UI.small("")
	var r := UI.hbox(8)
	r.add_child(UI.button("Задать пароль", func():
		if p1.text != p2.text:
			st.text = "Пароли не совпадают"
			return
		var ans: Dictionary = await _adm.api("claim", {"new_pass": p1.text})
		if not bool(ans.get("ok", false)):
			st.text = str(ans.get("err", "Ошибка"))
			return
		_adm.pw = p1.text
		_admin_refresh()))
	r.add_child(UI.button("Назад", _page_admin))
	v.add_child(r)
	v.add_child(st)


## Обновить сведения с сервера и показать панель.
func _admin_refresh() -> void:
	var ans: Dictionary = await _adm.api("auth")
	if not bool(ans.get("ok", false)):
		if bool(ans.get("need_claim", false)):
			_page_admin_claim(ans)
			return
		_page_admin(str(ans.get("err", "Ошибка")))
		return
	_adm_info = ans
	_page_admin_panel()


func _page_admin_panel() -> void:
	var inf := _adm_info
	var pv: Array = _scroll_page("СЕРВЕР «%s»" % str(inf.get("name", "")), 760.0, 260.0)
	var outer: VBoxContainer = pv[0]
	var v: VBoxContainer = pv[1]
	var st := UI.small("")
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(620, 0)
	var state := str(inf.get("state", ""))
	var players: Array = inf.get("players", [])
	var line := ""
	match state:
		"idle":
			line = "Мира нет — создайте новый или загрузите сохранённый."
		"loading", "restarting":
			line = "Сервер запускает мир «%s»…" % str(inf.get("world_title", ""))
		_:
			line = "Идёт мир «%s» · день %d · игроков %d из %d%s%s" % [str(inf.get("world_title", "")), int(inf.get("day", 0)), players.size(),
				int(inf.get("max_players", 0)), (": " + ", ".join(players)) if not players.is_empty() else "", " · пауза (никого нет)" if bool(inf.get("paused", false)) else ""]
	var head := UI.label("%s · %s · версия %s" % [_adm.addr, line, str(inf.get("version", ""))], 15)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(620, 0)
	v.add_child(head)
	if str(inf.get("version", "")) != DB.game_version():
		var w := UI.small("Версия сервера отличается от вашей (%s) — обновите сервер (install_server.sh) или игру." % DB.game_version())
		w.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
		v.add_child(w)
	var act := func(cmd: String, args := {}, wait_msg := ""):
		st.text = "…"
		var ans: Dictionary = await _adm.api(cmd, args)
		if not bool(ans.get("ok", false)):
			st.text = str(ans.get("err", "Ошибка"))
			return
		if wait_msg != "":
			_admin_wait(wait_msg, str(args.get("slot", "")))
			return
		if cmd == "delete":
			_admin_refresh()
			return
		st.text = str(ans.get("msg", "Готово"))
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 8)
	r.add_theme_constant_override("v_separation", 6)
	if state == "running":
		r.add_child(UI.button("Играть на сервере", func():
			Prefs.set_value("net_last_ip", "%s:%d" % [_adm.host(), _adm.port()])
			var err: String = Net.join(_adm.host(), _adm.port(), str(inf.get("room_pass", "")))
			st.text = err if err != "" else "Подключаюсь…"))
		r.add_child(UI.button("Сохранить мир", func(): act.call("save")))
		r.add_child(UI.button("Остановить мир", func(): act.call("stop_world", {}, "Сервер сохраняет и останавливает мир…")))
	r.add_child(UI.button("Создать новый мир…", func(): _page_room(true)))
	r.add_child(UI.button("Перезапустить сервер", func(): act.call("restart", {}, "Сервер перезапускается…")))
	r.add_child(UI.button("Обновить", _admin_refresh))
	v.add_child(r)
	if state == "running":
		var rs := UI.hbox(8)
		var say_e := LineEdit.new()
		say_e.placeholder_text = "Сообщение всем игрокам"
		say_e.custom_minimum_size = Vector2(380, 0)
		rs.add_child(say_e)
		rs.add_child(UI.button("Сказать", func():
			act.call("say", {"arg": say_e.text})
			say_e.text = ""))
		v.add_child(rs)
		for pn in players:
			var pr := UI.hbox(8)
			pr.add_child(UI.label(str(pn), 15))
			pr.add_child(UI.button("Выгнать", func(): act.call("kick", {"arg": str(pn)})))
			v.add_child(pr)
	v.add_child(UI.section("Миры на сервере"))
	var worlds: Array = inf.get("worlds", [])
	if worlds.is_empty():
		v.add_child(UI.small("Пока ни одного — нажмите «Создать новый мир…»."))
	for w in worlds:
		var row := UI.hbox(8)
		var col := UI.vbox(0)
		col.custom_minimum_size = Vector2(340, 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := UI.label("%s%s" % ["▶ " if bool(w.get("active", false)) else "", str(w.get("title", ""))], 16)
		l.tooltip_text = "Файл: %s.json%s" % [str(w.slot), "" if bool(w.get("from_game", false)) else " (мир из server.cfg)"]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(l)
		var dl := UI.small(("сейчас идёт · " if bool(w.get("active", false)) else "") + str(w.get("desc", "")))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(dl)
		row.add_child(col)
		var sl := str(w.slot)
		var title := str(w.get("title", sl))
		if not bool(w.get("active", false)):
			row.add_child(UI.button("Загрузить", func(): act.call("load", {"slot": sl}, "Сервер загружает мир «%s»…" % title)))
		var rb := UI.button("Пересоздать", func(): pass)
		rb.tooltip_text = "Удалить этот мир и создать новый с теми же настройками (карта будет другой, если зерно случайное)"
		rb.pressed.connect(func():
			if rb.text != "Точно пересоздать?":
				rb.text = "Точно пересоздать?"
				return
			act.call("recreate", {"slot": sl}, "Сервер создаёт мир «%s» заново…" % title))
		row.add_child(rb)
		var db := UI.button("Удалить", func(): pass)
		db.pressed.connect(func():
			if db.text != "Точно удалить?":
				db.text = "Точно удалить?"
				return
			act.call("delete", {"slot": sl}, "Сервер удаляет мир «%s»…" % title if bool(w.get("active", false)) else ""))
		row.add_child(db)
		v.add_child(row)
	# 1.7: текст, который игроки видят в лаунчере (news.txt в папке обновлений сервера)
	v.add_child(UI.section("Новости лаунчера"))
	if not bool(inf.get("news_ok", false)):
		v.add_child(UI.small("На сервере нет папки обновлений лаунчера — она появляется после install_server.sh с архивом Launcher_Updates."))
	else:
		var ne := TextEdit.new()
		ne.text = str(inf.get("news", ""))
		ne.custom_minimum_size = Vector2(620, 120)
		ne.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		ne.placeholder_text = "Что увидят игроки в лаунчере: что нового, когда рестарт, правила сервера…"
		v.add_child(ne)
		var nr := UI.hbox(8)
		var save_b := UI.button("Сохранить", func(): pass)
		var rv := UI.button("Вернуть описание версии", func(): pass)
		rv.tooltip_text = "Убрать свой текст: лаунчер покажет описание из обновления"
		rv.disabled = not bool(inf.get("news_custom", false))
		save_b.pressed.connect(func():
			var ans: Dictionary = await _adm.api("news", {"text": ne.text})
			if bool(ans.get("ok", false)):
				st.text = str(ans.get("msg", ""))
				rv.disabled = not bool(ans.get("custom", false))
			else:
				st.text = str(ans.get("err", "Ошибка")))
		rv.pressed.connect(func():
			var ans: Dictionary = await _adm.api("news", {"text": ""})
			if bool(ans.get("ok", false)):
				ne.text = str(ans.get("news", ""))
				rv.disabled = true
				st.text = "Лаунчер снова показывает описание версии"
			else:
				st.text = str(ans.get("err", "Ошибка")))
		nr.add_child(save_b)
		nr.add_child(rv)
		v.add_child(nr)
		v.add_child(UI.small("Лаунчер показывает этот текст при запуске, у всех игроков сразу."))
	v.add_child(UI.section("Пароль администратора"))
	var rp := UI.hbox(8)
	var np := LineEdit.new()
	np.secret = true
	np.placeholder_text = "новый пароль"
	np.custom_minimum_size = Vector2(220, 0)
	rp.add_child(np)
	rp.add_child(UI.button("Сменить", func():
		var ans: Dictionary = await _adm.api("set_pass", {"new_pass": np.text})
		if bool(ans.get("ok", false)):
			_adm.pw = np.text
			st.text = "Пароль администратора изменён"
		else:
			st.text = str(ans.get("err", "Ошибка"))))
	v.add_child(rp)
	var rb2 := UI.hbox(8)
	rb2.add_child(UI.button("Назад", func(): _page_admin()))
	outer.add_child(rb2)
	outer.add_child(st)


## Сервер перезапускается: ждём, пока он снова ответит и (если создаётся/грузится мир) мир будет готов.
func _admin_wait(msg: String, want_slot := "") -> void:
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(8)
	page.add_child(v)
	v.add_child(UI.title("УПРАВЛЕНИЕ СЕРВЕРОМ", 22))
	var l := UI.label(msg, 16)
	v.add_child(l)
	var sub := UI.small("Обычно это занимает до минуты. Игроки на сервере получили предупреждение в чате.")
	v.add_child(sub)
	v.add_child(UI.button("Назад", func(): _page_admin()))
	var t0 := Time.get_ticks_msec()
	var old_boot := str(_adm_info.get("boot", ""))
	await get_tree().create_timer(2.0).timeout
	while is_instance_valid(l) and Time.get_ticks_msec() - t0 < 240000:
		var inf: Dictionary = await _adm.api("info")
		if not is_instance_valid(l):
			return
		var stt := str(inf.get("state", ""))
		if bool(inf.get("ok", false)) and str(inf.get("boot", "")) != old_boot and stt in ["idle", "running"]:
			_admin_refresh()
			return
		sub.text = ("Сервер запускает мир… %d с" if stt == "loading" else "Ждём сервер… %d с") % ((Time.get_ticks_msec() - t0) / 1000)
		await get_tree().create_timer(2.0).timeout
	if is_instance_valid(l):
		l.text = "Сервер долго не отвечает. Посмотрите журнал на сервере: journalctl -u frontiercorp -n 50"


var _hero_view: SubViewport
var _hero_pl: Node3D
var _hero_pivot: Node3D

func _page_hero() -> void:
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(8)
	page.add_child(v)
	v.add_child(UI.title(DB.tx("hero_title", "ВЫБОР ГЕРОЯ"), 22))
	var row := UI.hbox(14)
	v.add_child(row)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(250, minf(_page_h(300.0), 520.0))
	var list := UI.vbox(5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	row.add_child(sc)
	var cur := Player.my_look()
	for ua in OS.get_cmdline_user_args():
		if ua.begins_with("--hero="):   # снимки страницы
			cur = ua.substr(7)
	var looks := Player.looks()
	if cur == "" or not cur in looks:
		cur = str(DB.setting("hero_model", "hero"))
	var group := ButtonGroup.new()
	for id in looks:
		var md: Dictionary = DB.data.models[id]
		var nm := {"hero_robot": "Робот-инженер", "hero": "Классический герой"}.get(id, str(md.get("name", id)))
		var b := UI.button(nm, func(): _hero_pick(id))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == cur
		if id == cur:
			sc.ensure_control_visible.call_deferred(b)
		b.custom_minimum_size = Vector2(230, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(b)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	var hh := minf(_page_h(300.0), 520.0)
	svc.custom_minimum_size = Vector2(hh * 0.72, hh)
	row.add_child(svc)
	_hero_view = SubViewport.new()
	_hero_view.own_world_3d = true
	_hero_view.transparent_bg = true
	_hero_view.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_hero_view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.75)
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_hero_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_hero_view.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.4, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.7, 0.8, 1.0)
	_hero_view.add_child(rim)
	var floor_mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.95
	cyl.height = 0.06
	floor_mi.mesh = cyl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.17, 0.2)
	fm.metallic = 0.4
	fm.roughness = 0.5
	floor_mi.material_override = fm
	floor_mi.position.y = -0.03
	_hero_view.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 1.45, 6.0)
	_hero_view.add_child(cam)
	cam.look_at(Vector3(0, 1.2, 0))
	_hero_pivot = Node3D.new()
	_hero_view.add_child(_hero_pivot)
	v.add_child(UI.small("Герой виден другим игрокам в сетевой игре. Робот красится в цвет профессии, люди — нет."))
	_hero_show(cur)


func _hero_pick(id: String) -> void:
	Prefs.set_value("hero_look", id)
	_hero_show(id)


func _hero_show(id: String) -> void:
	if _hero_pivot == null or not is_instance_valid(_hero_pivot):
		return
	for c in _hero_pivot.get_children():
		c.queue_free()
	var p := Player.new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.look = id
	_hero_pivot.add_child(p)
	p.build()
	p.rotation.y = -PI / 2      # герой смотрит вдоль +X — разворачиваем лицом к камере
	if p.flashlight != null:
		p.flashlight.visible = false
	_hero_pl = p


func _hero_spin(d: float) -> void:
	if _hero_pivot != null and is_instance_valid(_hero_pivot) and _hero_pivot.is_inside_tree():
		_hero_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.0005) * 0.9


func _page_help() -> void:
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(10)
	page.add_child(v)
	v.add_child(UI.title(DB.tx("help_title", "КАК ИГРАТЬ"), 22))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var r := UI.rich(Hud.help_text(), 15)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(r)
	v.add_child(sc)


func _page_credits() -> void:
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(10)
	page.add_child(v)
	v.add_child(UI.title(DB.tx("credits_title", "АВТОРЫ"), 22))
	var r := UI.rich("[center]%s[/center]" % DB.t(DB.menu("credits", "")), 17)
	r.custom_minimum_size = Vector2(600, 0)
	v.add_child(r)


func _editor() -> void:
	if ResourceLoader.exists("res://scenes/editor.tscn"):
		get_tree().change_scene_to_file("res://scenes/editor.tscn")


var _mods_msg := ""
func _page_mods() -> void:
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(8)
	page.add_child(v)
	v.add_child(UI.title(DB.tx("mods_title", "МОДЫ И ДОПОЛНЕНИЯ"), 22))
	v.add_child(UI.small("Моды лежат в папке mods рядом с игрой: %s\nНижний в списке загружается последним и может менять то, что сделали верхние." % DB.mods_dir()))
	for pair in [["Дополнения (DLC)", DB.dlcs, "dlc"], ["Моды", DB.mods, "mod"]]:
		v.add_child(UI.label(pair[0], 16))
		if pair[1].is_empty():
			v.add_child(UI.small("  нет"))
		for m in pair[1]:
			var row := UI.hbox()
			var c := CheckBox.new()
			c.button_pressed = m.enabled
			c.focus_mode = Control.FOCUS_NONE
			var kind: String = pair[2]
			var mid: String = m.id
			c.toggled.connect(func(on): DB.set_enabled(kind, mid, on))
			row.add_child(c)
			row.add_child(UI.label("%s  v%s" % [m.name, m.version], 15))
			row.add_child(UI.small(m.desc))
			row.add_child(UI.spacer())
			row.add_child(UI.button("↑", func(): DB.move_mod(kind, mid, -1); DB.load_all(); _page_mods(), "Загружать раньше"))
			row.add_child(UI.button("↓", func(): DB.move_mod(kind, mid, 1); DB.load_all(); _page_mods(), "Загружать позже (главнее)"))
			v.add_child(row)
	# обмен модами одним файлом .fcmod (делаются в игре: конструктор, клавиша N)
	v.add_child(UI.label("Обмен модами", 16))
	v.add_child(UI.small("Мод друга — один файл .fcmod. Положите его в папку обмена и нажмите «Забрать моды». Берутся только данные, без скриптов.\nПапка обмена: %s" % ModKit.share_dir()))
	var sh := UI.hbox()
	var msg := UI.small(_mods_msg)
	_mods_msg = ""
	sh.add_child(UI.button("Забрать моды", func():
		var got := ModKit.install_from_share()
		msg.text = "\n".join(got.map(func(g): return g.msg)) if not got.is_empty() else "В папке обмена нет файлов .fcmod"
		if not got.is_empty():
			_mods_msg = msg.text
			DB.load_all()
			_page_mods.call_deferred()))
	sh.add_child(UI.button("Папка обмена", func(): OS.shell_open(ModKit.share_dir())))
	sh.add_child(UI.button("Папка модов", func(): OS.shell_open(DB.mods_dir())))
	v.add_child(sh)
	v.add_child(msg)
	v.add_child(UI.button("Перезагрузить контент", func(): DB.load_all(); get_tree().reload_current_scene()))


var _set_sec := "graphics"
var _set_hud: Hud = null   # 1.0.8: живёт, пока открыта страница — иначе кнопки настроек (лямбды Hud) переставали работать
func _page_settings() -> void:
	page.visible = true
	UI.clear(page)
	var v := UI.vbox(8)
	page.add_child(v)
	v.add_child(UI.title(DB.tx("settings_title", "НАСТРОЙКИ"), 22))
	var body := UI.vbox(6)
	v.add_child(body)
	if _set_hud != null:
		_set_hud.call_deferred("free")
	var h := Hud.new()
	_set_hud = h
	h.settings_sec = _set_sec
	h.build_settings(body, func(s): _set_sec = s; _page_settings())


func _unhandled_key_input(ev: InputEvent) -> void:
	if _splash_node and ev.is_pressed():
		_skip_splash()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _set_hud != null and is_instance_valid(_set_hud):
		_set_hud.free()
		_set_hud = null


## 1.0.8: проверка — ползунок громкости в главном меню сразу меняет звук (и после смены вкладки тоже).
func _prefs_test() -> void:
	var had := Prefs.values.has("vol_master")
	var old = Prefs.values.get("vol_master")
	var bus := AudioServer.get_bus_index("Master")
	var res := []
	for k in [0.3, 0.6]:
		_set_sec = "audio"
		_page_settings()
		await get_tree().process_frame
		var sl: Array = page.find_children("*", "HSlider", true, false)
		if sl.is_empty():
			res.append(false)
			continue
		(sl[0] as HSlider).value = k
		await get_tree().process_frame
		res.append(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(k)) < 0.2)
	if had:
		Prefs.set_value("vol_master", old)
	else:
		Prefs.values.erase("vol_master")
		Prefs.save_file()
		Prefs.apply("vol_master")
	# 1.3: графика живого фона и сам живой фон меняются сразу (проверяется только с видеокартой)
	var live := "skip"
	if live_view != null:
		var sc = live_view.get_child(0)
		var ss_old = Prefs.values.get("ssao", null)
		Prefs.set_value("ssao", false)
		var ok1: bool = sc.env.ssao_enabled == false
		Prefs.set_value("ssao", true)
		ok1 = ok1 and sc.env.ssao_enabled
		Prefs.set_value("menu_live", false)
		var ok2 := live_view == null
		Prefs.set_value("menu_live", true)
		ok2 = ok2 and live_view != null
		if ss_old == null: Prefs.values.erase("ssao")
		Prefs.values.erase("menu_live")
		Prefs.save_file()
		live = str(ok1 and ok2)
		if not (ok1 and ok2): res.append(false)
	print("TEST menu_prefs19 vol=", res, " live=", live, " ", "OK" if res == [true, true] else "FAIL")
	get_tree().quit()
