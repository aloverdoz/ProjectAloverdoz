class_name Hud
extends CanvasLayer

const Strategy = preload("res://scripts/strategy.gd")
## Интерфейс игры. Положение, прозрачность и видимость панелей берутся из ui.json,
## поэтому их можно менять в редакторе интерфейса. Там же задаются свои окна.

var game
var seat := 0             # 1.3: сплитскрин — чей это интерфейс (0 — первый игрок, 1 — второй)
var root: Control
var panels := {}          # id -> Control (панели на экране)
var windows := {}         # id -> Win (окна)
var refreshers := {}      # id -> Callable, обновляет содержимое окна
var acc := 0.0

# панели
var corp_lbl: RichTextLabel
var xp_bar: ProgressBar
var power_lbl: RichTextLabel
var hp_bar: ProgressBar
var hp_chunk: ProgressBar     # красный «кусок урона» за полоской здоровья
var _chunk_wait := 0.0
var _hp_prev := 0.0
var _xp_goal := -1.0
var _cr_shown := -1           # кредиты, которые сейчас показаны (досчитываются до настоящих)
var _corp_extra := ""
var _cr_tw: Tween
var food_bar: ProgressBar
var water_bar: ProgressBar
var fps_lbl: Label           # счётчик FPS (F3)
var _fps_t := 0.0
var clim_box: VBoxContainer   # сезоны и климат (climate.gd)
var clim_lbl: Label
var chill_bar: ProgressBar
var heat_bar: ProgressBar
var clothes_row: HBoxContainer
var rad_box: VBoxContainer    # 14.22: дозиметр (hazards.gd)
var rad_lbl: Label
var rad_bar: ProgressBar
var clothes_lbl: Label
var surv_box: Control
var hp_lbl: Label
var wave_lbl: Label
var clock_lbl: Label
var toast_box: VBoxContainer
var quest_lbl: RichTextLabel
var minimap: Minimap
var bigmap: Minimap
var info_lbl: RichTextLabel
var mode_lbl: Label
var hotbar: HBoxContainer
var hotbar_slots: Array = []
var sel_lbl: Label             # название выбранного в панели предмета
var hurt_rect: ColorRect
var alert_lbl: Label
var pause_lbl: Label
var effects_lbl: RichTextLabel
var craft_bar: ProgressBar
var craft_lbl: Label
var end_win: PanelContainer
var end_lbl: Label
var death_box: ColorRect
var death_title: Label
var death_text: Label
var saves_mode := "save"
var end_continue: Button

# окна
var inv_slots: Array = []
var inv_grid: GridContainer
var bag_row: HBoxContainer
var _bag_sig := ""
var info_box: PanelContainer
var info_key := ""
var inv_pick := -1     # 1.7: ячейка рюкзака, по которой щёлкнули (рамка выбора), -1 — та, что в руках
var bld: Factory.B = null            # открытое здание
var bld_slots: Array = []
var build_cat := ""
var build_search := ""
var station := "hand"
var station_b = null      # станция, у которой открыт крафт (окно закроется, если отойти)
var cargo_count: Label
var cargo_meter: ProgressBar
var selected_recipe := ""
var broadcast
var settings_sec := "graphics"


class Win extends PanelContainer:
	var hud
	var id := ""
	var body: VBoxContainer
	var scroll: ScrollContainer
	var title_lbl: Label
	var _drag := false
	var home_y := -1.0
	# 1.7: размер окна мышью, как у папок: за правый/нижний край или уголок справа внизу. Запоминается.
	var user_size := Vector2.ZERO   # 0 — по содержимому
	var base_w := 0.0
	var _rs := 0                    # что тянем: 1 — правый край, 2 — низ, 3 — угол
	const GRIP := 9.0

	func load_size() -> void:
		var v = Prefs.get_value("win_size_" + id, null)
		if v is Array and v.size() == 2:
			user_size = Vector2(float(v[0]), float(v[1]))
		_apply_w()

	func _apply_w() -> void:
		custom_minimum_size.x = user_size.x if user_size.x > 0.0 else base_w

	func reset_user_size() -> void:
		user_size = Vector2.ZERO
		Prefs.set_value("win_size_" + id, null)
		_apply_w()
		reset_size()

	## Потянули за край на rel пикселей (what: 1 — ширина, 2 — высота, 3 — обе).
	func resize_by(rel: Vector2, what: int) -> void:
		var vs := get_viewport_rect().size / get_tree().root.content_scale_factor
		if vs.x < 400.0:
			vs = Vector2(4096, 4096)   # окно без экрана (проверки)
		if what & 1:
			user_size.x = clampf(maxf(user_size.x, size.x) + rel.x, 220.0, maxf(220.0, vs.x - position.x - 4.0))
		if what & 2:
			user_size.y = clampf(maxf(user_size.y, size.y) + rel.y, 140.0, maxf(140.0, vs.y - position.y - 4.0))
		_apply_w()
		reset_size()

	func save_size() -> void:
		Prefs.set_value("win_size_" + id, [user_size.x, user_size.y])

	func _edge(p: Vector2) -> int:
		return (1 if p.x > size.x - GRIP else 0) + (2 if p.y > size.y - GRIP else 0)

	## Высокое окно не вылезает за экран: тело прокручивается колесом мыши.
	## bottom — верх панели быстрых слотов: окно её не перекрывает.
	func fit(vs: Vector2, bottom := -1.0) -> void:
		if scroll == null:
			return
		if bottom <= 0.0:
			bottom = vs.y
		var chrome := size.y - scroll.size.y
		# верх окна стоит на месте: если содержимое выросло, растёт прокрутка, а не окно уезжает вверх
		var top := home_y if home_y >= 0.0 else 8.0
		var room := bottom - 8.0 - maxf(top, 4.0) - chrome
		if room < 180.0:
			room = maxf(180.0, bottom - 16.0 - chrome)   # совсем мало места — тогда окно поднимается
		var want := minf(body.get_combined_minimum_size().y, room)
		if user_size.y > 0.0:
			want = clampf(user_size.y - chrome, 60.0, maxf(60.0, room))
		if absf(scroll.custom_minimum_size.y - want) > 1.0:
			scroll.custom_minimum_size.y = want
			reset_size()
		if home_y < 0.0:
			return  # окно ещё не поставлено на место (open() ставит его, когда размер известен)
		position.y = clampf(home_y, 4.0, maxf(4.0, bottom - size.y - 8.0))
		position.x = clampf(position.x, 4.0, maxf(4.0, vs.x - size.x - 4.0))

	## Поставить окно и запомнить место: дальше fit() держит его здесь, а не там, где оно было до открытия.
	func place(p: Vector2) -> void:
		position = p
		home_y = p.y
		if modulate.a < 0.99 and visible:
			_pop_in()
		else:
			modulate.a = 1.0

	var _tw: Tween

	## Появление окна: проявляется и чуть «выпрыгивает» из центра. Только картинка — логика уже открыта.
	func _pop_in() -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		pivot_offset = size * 0.5
		modulate.a = 0.0
		scale = Vector2.ONE * 0.94
		_tw = create_tween().set_parallel(true)
		_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		# прозрачность набирается почти сразу (EXPO), дальше окно лишь «дотягивается» масштабом
		_tw.tween_property(self, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Закрытие: окно скрывается сразу (is_open() и тесты видят это немедленно), анимация появления сбрасывается.
	func snap_closed() -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		visible = false
		scale = Vector2.ONE
		modulate.a = 1.0

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed and ev.double_click and ev.position.y < 40:
				reset_user_size()   # двойной клик по заголовку — обычный размер
				accept_event()
				return
			if ev.pressed and _edge(ev.position) > 0:
				_rs = _edge(ev.position)
				get_parent().move_child(self, -1)
				accept_event()
				return
			if not ev.pressed and _rs > 0:
				_rs = 0
				save_size()
				accept_event()
				return
			_drag = ev.pressed and ev.position.y < 40
			if ev.pressed:
				get_parent().move_child(self, -1)
		elif ev is InputEventMouseMotion and _rs > 0:
			resize_by(ev.relative, _rs)
			accept_event()
		elif ev is InputEventMouseMotion and _drag:
			position += ev.relative
			home_y = position.y
			accept_event()
		elif ev is InputEventMouseMotion:
			var e := _edge(ev.position)
			mouse_default_cursor_shape = [Control.CURSOR_ARROW, Control.CURSOR_HSIZE, Control.CURSOR_VSIZE, Control.CURSOR_FDIAGSIZE][e]


## 1.7: уголок справа внизу окна — тянуть, чтобы поменять размер.
class WinGrip extends Control:
	var win
	var _on := false

	func _init() -> void:
		custom_minimum_size = Vector2(14, 12)
		size_flags_horizontal = Control.SIZE_SHRINK_END
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
		tooltip_text = "Потяните, чтобы поменять размер окна. Двойной клик по заголовку — обычный размер"

	func _draw() -> void:
		var c := Color(1, 1, 1, 0.35)
		for k in 3:
			var o := 4.0 * k
			draw_line(Vector2(size.x - 1, size.y - 11 + o), Vector2(size.x - 11 + o, size.y - 1), c, 1.5)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			_on = ev.pressed
			if not ev.pressed:
				win.save_size()
			accept_event()
		elif ev is InputEventMouseMotion and _on:
			win.resize_by(ev.relative, 3)
			accept_event()


func build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.use_game_style(true)
	root.theme = UI.theme()
	add_child(root)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = "shader_type canvas_item;\nvoid fragment() { vec2 d = UV - 0.5; float v = smoothstep(0.35, 0.85, length(d * vec2(1.2, 1.0))); COLOR = vec4(0.0, 0.0, 0.02, v * 0.45); }"
	var vm := ShaderMaterial.new()
	vm.shader = vs
	vig.material = vm
	root.add_child(vig)
	hurt_rect = ColorRect.new()
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_rect)
	_build_panels()
	_build_windows()
	broadcast = preload("res://scripts/ui/dispatch_tv.gd").new()
	broadcast.hud = self
	root.add_child(broadcast)
	apply_layout()


# ---------------------------------------------------------------- 13.10: зловещая надпись перед событием
## Крупная надпись по центру сверху: плавно проявляется, висит hold секунд и тает.
## Текст, цвет, время и звук — у события в редакторе («Предупреждение: ...»), у волн — в «Волнах».
var omen_lbl: Label
var _omen_tw: Tween
var last_omen := ""

func omen(text: String, col: Color, hold := 5.0, sound := "omen") -> void:
	if text == "" or (game and game.flags.get("quiet", false)):
		return
	last_omen = text
	if omen_lbl == null or not is_instance_valid(omen_lbl):
		omen_lbl = Label.new()
		omen_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		omen_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		omen_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		omen_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		omen_lbl.add_theme_font_size_override("font_size", 40)
		omen_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.02))
		omen_lbl.add_theme_constant_override("outline_size", 12)
		omen_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		omen_lbl.add_theme_constant_override("shadow_offset_y", 4)
		omen_lbl.z_index = 60
		root.add_child(omen_lbl)
		# во всю ширину экрана, в верхней трети
		omen_lbl.anchor_left = 0.0
		omen_lbl.anchor_right = 1.0
		omen_lbl.anchor_top = 0.0
		omen_lbl.anchor_bottom = 0.0
		omen_lbl.offset_left = 60.0
		omen_lbl.offset_right = -60.0
		omen_lbl.offset_top = 150.0
		omen_lbl.offset_bottom = 270.0
	omen_lbl.text = text
	omen_lbl.add_theme_color_override("font_color", col)
	omen_lbl.modulate.a = 0.0
	omen_lbl.scale = Vector2.ONE
	omen_lbl.visible = true
	if _omen_tw and _omen_tw.is_valid():
		_omen_tw.kill()
	_omen_tw = create_tween()
	_omen_tw.tween_property(omen_lbl, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	_omen_tw.tween_interval(maxf(0.5, hold))
	_omen_tw.tween_property(omen_lbl, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	if sound != "" and game.sfx:
		game.sfx.play_ui(sound)


# ---------------------------------------------------------------- панели

func _panel(id: String, opacity := 0.82) -> PanelContainer:
	var p := UI.panel(opacity)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	panels[id] = p
	return p


var prof_row: HBoxContainer


## Значок профессии у названия корпорации (гость выбирает профессию уже в игре — значок меняется).
func refresh_prof_icon() -> void:
	if prof_row == null:
		return
	for c in prof_row.get_children():
		if c.has_meta("prof_icon"):
			c.queue_free()
	if game.module("professions") and DB.data.get("professions", {}).has(game.profession):
		var pi := UI.profession_icon(game.profession, 34)
		pi.set_meta("prof_icon", true)
		pi.mouse_filter = Control.MOUSE_FILTER_PASS
		pi.tooltip_text = "%s\n%s" % [DB.data.professions[game.profession].get("name", ""), DB.data.professions[game.profession].get("desc", "")]
		prof_row.add_child(pi)
		prof_row.move_child(pi, 0)


func _build_panels() -> void:
	# корпорация
	var corp := _panel("corp")
	corp.custom_minimum_size = Vector2(290, 0)
	var v := UI.vbox(4)
	corp.add_child(v)
	var th := UI.hbox(8)
	prof_row = th
	refresh_prof_icon()
	var tl := UI.title(DB.display_name().to_upper(), 20)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tl)
	v.add_child(th)
	corp_lbl = UI.rich("", 15)
	v.add_child(corp_lbl)
	xp_bar = UI.bar(v, Color(0.5, 0.85, 1.0), 8)
	xp_bar.step = 0.0
	power_lbl = UI.rich("", 13)
	v.add_child(power_lbl)
	# здоровье и выживание
	var surv := _panel("vitals")
	surv.custom_minimum_size = Vector2(250, 0)
	var sv := UI.vbox(3)
	surv.add_child(sv)
	hp_lbl = UI.small("Здоровье")
	sv.add_child(hp_lbl)
	# полоска здоровья поверх «куска урона»: красный хвост догоняет её через ~0,4 с после удара
	var hp_wrap := Control.new()
	hp_wrap.custom_minimum_size = Vector2(0, 12)
	hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(hp_wrap)
	hp_chunk = UI.bar(hp_wrap, Color(0.95, 0.22, 0.18), 12)
	hp_chunk.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_chunk.step = 0.0
	hp_bar = UI.bar(hp_wrap, Color(0.4, 0.95, 0.45), 12)
	hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	hp_bar.step = 0.0
	surv_box = UI.vbox(3)
	sv.add_child(surv_box)
	surv_box.add_child(UI.small("Сытость"))
	food_bar = UI.bar(surv_box, Color(0.95, 0.65, 0.25), 8)
	surv_box.add_child(UI.small("Вода"))
	water_bar = UI.bar(surv_box, Color(0.35, 0.7, 1.0), 8)
	clim_box = UI.vbox(2)
	sv.add_child(clim_box)
	clim_lbl = UI.small("")
	clim_box.add_child(clim_lbl)
	chill_bar = UI.bar(clim_box, Color(0.55, 0.8, 1.0), 6)
	heat_bar = UI.bar(clim_box, Color(1.0, 0.45, 0.2), 6)
	clothes_row = UI.hbox(6)
	clim_box.add_child(clothes_row)
	clothes_lbl = UI.small("")
	clothes_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clothes_row.add_child(clothes_lbl)
	var off_b := UI.button("Снять", func(): game.climate.take_off())
	off_b.add_theme_font_size_override("font_size", 12)
	clothes_row.add_child(off_b)
	rad_box = UI.vbox(2)
	sv.add_child(rad_box)
	rad_lbl = UI.small("")
	rad_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.45))
	rad_box.add_child(rad_lbl)
	rad_bar = UI.bar(rad_box, Color(0.45, 1.0, 0.35), 6)
	rad_bar.tooltip_text = "Доза облучения. На 100% — лучевая болезнь: здоровье тает, пока доза не спадёт."
	rad_box.visible = false
	effects_lbl = UI.rich("", 13)
	sv.add_child(effects_lbl)
	# волна и время
	var top := UI.vbox(2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size = Vector2(460, 0)
	root.add_child(top)
	panels["wave"] = top
	fps_lbl = UI.label("", 13)
	fps_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_lbl.add_theme_constant_override("outline_size", 4)
	fps_lbl.position = Vector2(8, 2)
	fps_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_lbl.z_index = 50
	root.add_child(fps_lbl)
	wave_lbl = UI.label("", 22)
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	wave_lbl.add_theme_constant_override("outline_size", 6)
	top.add_child(wave_lbl)
	clock_lbl = UI.label("", 15)
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	clock_lbl.add_theme_constant_override("outline_size", 5)
	top.add_child(clock_lbl)
	# осада: полоска здоровья босса и предупреждение
	boss_box = UI.vbox(2)
	boss_lbl = UI.label("", 17, Color(1.0, 0.55, 0.4))
	boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_lbl.add_theme_constant_override("outline_size", 5)
	boss_box.add_child(boss_lbl)
	boss_bar = UI.bar(boss_box, Color(0.9, 0.25, 0.2), 12)
	boss_box.visible = false
	top.add_child(boss_box)
	siege_lbl = UI.label("", 14, Color(1.0, 0.7, 0.45))
	siege_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	siege_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	siege_lbl.add_theme_constant_override("outline_size", 5)
	top.add_child(siege_lbl)
	toast_box = UI.vbox(2)
	top.add_child(toast_box)
	# миникарта
	var mmp := _panel("minimap")
	minimap = Minimap.new()
	var ms := float(DB.setting("minimap_size", 200))
	minimap.custom_minimum_size = Vector2(ms, ms)
	mmp.add_child(minimap)
	minimap.setup(game, false)
	# задачи
	var q := _panel("quests")
	q.custom_minimum_size = Vector2(330, 0)
	var qv := UI.vbox(4)
	q.add_child(qv)
	qv.add_child(UI.title("ЗАДАЧИ", 15))
	quest_lbl = UI.rich("", 14)
	quest_lbl.custom_minimum_size = Vector2(300, 0)
	quest_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	qv.add_child(quest_lbl)
	# подсказка о здании под курсором
	var info := _panel("info", 0.85)
	info.custom_minimum_size = Vector2(300, 0)
	info_lbl = UI.rich("", 14)
	info_lbl.custom_minimum_size = Vector2(280, 0)
	info.add_child(info_lbl)
	# быстрые слоты
	var hb := _panel("hotbar", 0.75)
	var hv := UI.vbox(4)
	hb.add_child(hv)
	sel_lbl = UI.label("", 15, UI.TEXT)
	sel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(sel_lbl)
	craft_lbl = UI.small("")
	craft_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(craft_lbl)
	craft_bar = UI.bar(hv, UI.ACCENT, 5)
	hotbar = UI.hbox(4)
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(hotbar)
	_build_hotbar()
	mode_lbl = UI.label("", 12, Color(UI.DIM, 0.85))
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(mode_lbl)
	# тревога и пауза
	alert_lbl = UI.label("", 30, Color(1, 0.35, 0.3))
	alert_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	alert_lbl.add_theme_constant_override("outline_size", 8)
	alert_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(alert_lbl)
	pause_lbl = UI.label("ПАУЗА", 44, Color.WHITE)
	pause_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	pause_lbl.add_theme_constant_override("outline_size", 10)
	pause_lbl.visible = false
	root.add_child(pause_lbl)
	_make_mode_hud()


# ---------------------------------------------------------------- 1.0.8: явные режимы
## Провода, разбор, стройка, участок, маршрут дрона: крупная надпись сверху и цветная подсветка краёв экрана.
## «Настройки» → «Режимы на экране» (цвета, сила подсветки, размер надписи); игрок выключает в «Настройки» → «Игра».
var mode_edge: ColorRect
var mode_box: PanelContainer
var mode_title: Label
var mode_sub: Label
var _mode_a := 0.0
var _mode_id := ""


static func mode_cfg() -> Dictionary:
	var c = DB.setting("mode_hud", {})
	return c if c is Dictionary else {}


func _make_mode_hud() -> void:
	mode_edge = ColorRect.new()
	mode_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	mode_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.25, 0.6, 1.0, 1.0);
uniform float strength = 0.5;
uniform float width = 0.11;
uniform float t = 0.0;
void fragment() {
	vec2 e = min(UV, 1.0 - UV);
	float d = min(e.x * 1.0, e.y * 1.6);
	float g = 1.0 - smoothstep(0.0, width, d);
	float pulse = 0.85 + 0.15 * sin(t * 2.4);
	COLOR = vec4(tint.rgb, g * g * strength * pulse);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	mode_edge.material = m
	mode_edge.visible = false
	root.add_child(mode_edge)
	root.move_child(mode_edge, 0)
	mode_box = PanelContainer.new()
	var st := UI.box(Color(0.03, 0.05, 0.08, 0.55), 10)
	st.set_content_margin_all(8)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.border_width_bottom = 3
	mode_box.add_theme_stylebox_override("panel", st)
	mode_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UI.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_box.add_child(v)
	mode_title = UI.label("", int(mode_cfg().get("title_size", 26)), Color.WHITE)
	mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	mode_title.add_theme_constant_override("outline_size", 6)
	mode_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mode_title)
	mode_sub = UI.label("", 13, Color(1, 1, 1, 0.8))
	mode_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mode_sub)
	mode_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mode_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mode_box.offset_top = float(mode_cfg().get("top", 92))
	mode_box.modulate.a = 0.0
	mode_box.visible = false
	root.add_child(mode_box)


func _update_mode_hud(delta: float) -> void:
	if mode_box == null:
		return
	var mi: Dictionary = game.mode_info() if bool(Prefs.get_value("show_modes", true)) and bool(mode_cfg().get("enabled", true)) and not game.photo_mode else {}
	var on := not mi.is_empty()
	if on:
		if str(mi.id) != _mode_id:
			_mode_id = str(mi.id)
			var col: Color = mi.color
			mode_title.text = str(mi.title)
			mode_title.add_theme_color_override("font_color", col.lightened(0.35))
			(mode_box.get_theme_stylebox("panel") as StyleBoxFlat).border_color = col
			(mode_edge.material as ShaderMaterial).set_shader_parameter("tint", col)
			(mode_edge.material as ShaderMaterial).set_shader_parameter("strength", float(mi.get("edge", 0.5)))
			(mode_edge.material as ShaderMaterial).set_shader_parameter("width", float(mode_cfg().get("edge_width", 0.11)))
		mode_sub.text = str(mi.get("hint", ""))
	_mode_a = move_toward(_mode_a, 1.0 if on else 0.0, delta * 6.0)
	mode_box.visible = _mode_a > 0.01 and mode_title.text != ""
	mode_edge.visible = _mode_a > 0.01 and bool(mode_cfg().get("edge", true))
	mode_box.modulate.a = _mode_a
	mode_edge.modulate.a = _mode_a
	if mode_edge.visible:
		(mode_edge.material as ShaderMaterial).set_shader_parameter("t", Time.get_ticks_msec() * 0.001)
	if not on and _mode_a <= 0.0:
		_mode_id = ""


## Положение панелей из ui.json (anchor: tl, tr, bl, br, top, bottom, center; pos — отступ).
func apply_layout() -> void:
	var cfg: Dictionary = DB.data.ui.get("panels", {})
	var defaults := {
		"corp": {"anchor": "tl", "pos": [16, 16]}, "vitals": {"anchor": "bl", "pos": [16, 16]},
		"wave": {"anchor": "top", "pos": [0, 12]}, "quests": {"anchor": "tr", "pos": [16, 232]}, "minimap": {"anchor": "tr", "pos": [16, 16]},
		"info": {"anchor": "br", "pos": [16, 130]}, "hotbar": {"anchor": "bottom", "pos": [0, 10]},
	}
	for id in panels:
		var c: Dictionary = defaults.get(id, {}).duplicate()
		c.merge(cfg.get(id, {}), true)
		var p: Control = panels[id]
		p.set_meta("anchor", c.get("anchor", "tl"))
		var pos: Array = c.get("pos", [16, 16])
		p.set_meta("off", Vector2(float(pos[0]), float(pos[1])))
		p.set_meta("on", bool(c.get("visible", true)))
		p.modulate.a = float(c.get("opacity", 1.0)) if id in ["wave"] else 1.0
		if p is PanelContainer and c.has("opacity"):
			var sb: StyleBoxFlat = UI.theme().get_stylebox("panel", "PanelContainer").duplicate()
			sb.bg_color.a = float(c.opacity)
			p.add_theme_stylebox_override("panel", sb)
		p.scale = Vector2.ONE * float(c.get("scale", 1.0))
		p.visible = p.get_meta("on")
	if panels.has("minimap") and not bool(DB.setting("minimap", true)):
		panels.minimap.set_meta("on", false)
		panels.minimap.visible = false
	_build_custom_windows()


func _place_panels() -> void:
	var vs := root.get_viewport_rect().size / root.get_tree().root.content_scale_factor
	for id in panels:
		var p: Control = panels[id]
		var a: String = p.get_meta("anchor", "tl")
		var o: Vector2 = p.get_meta("off", Vector2(16, 16))
		var sz := p.size * p.scale
		var pos := o
		match a:
			"tr": pos = Vector2(vs.x - sz.x - o.x, o.y)
			"bl": pos = Vector2(o.x, vs.y - sz.y - o.y)
			"br": pos = Vector2(vs.x - sz.x - o.x, vs.y - sz.y - o.y)
			"top": pos = Vector2((vs.x - sz.x) * 0.5 + o.x, o.y)
			"bottom": pos = Vector2((vs.x - sz.x) * 0.5 + o.x, vs.y - sz.y - o.y)
			"center": pos = (vs - sz) * 0.5 + o
		p.position = pos.round()
	alert_lbl.position = Vector2(vs.x * 0.5 - alert_lbl.size.x * 0.5, vs.y * 0.22)
	pause_lbl.position = (vs - pause_lbl.size) * 0.5


# ---------------------------------------------------------------- окна

## Нижняя граница для окон — верх панели быстрых слотов (если она видна).
func _windows_bottom(vs: Vector2) -> float:
	var hb: Control = panels.get("hotbar")
	if hb and hb.visible and hb.get_meta("on", true):
		return minf(vs.y, hb.position.y)
	return vs.y


func _win(id: String, title: String, w: float, refresher := Callable()) -> Win:
	var win := Win.new()
	win.hud = self
	win.id = id
	var vw: float = get_viewport().get_visible_rect().size.x if get_viewport() else 1600.0
	win.custom_minimum_size = Vector2(minf(UI.ws(w), maxf(minf(w, 480.0), vw - 24.0)), 0)   # 1.1.15: на узком экране окно не шире экрана
	win.visible = false
	var v := UI.vbox(10)
	win.add_child(v)
	var hb := UI.header_box()
	var head := UI.hbox(10)
	hb.add_child(head)
	var mark := ColorRect.new()
	mark.color = UI.header_text() if hb.get_meta("fill", false) else UI.ACCENT
	mark.custom_minimum_size = Vector2(5, UI.fs(22))
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	win.title_lbl = UI.title(title, 20)
	win.title_lbl.add_theme_color_override("font_color", UI.header_text())
	win.title_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(win.title_lbl)
	head.add_child(UI.spacer())
	var x := UI.button("✕", func(): close(id), "Закрыть (Esc)")
	x.custom_minimum_size = Vector2(UI.fs(36), UI.fs(30))
	if hb.get_meta("fill", false):
		var xs := UI.box(Color(0, 0, 0, 0.25), 4)
		xs.set_content_margin_all(2)
		var xh := UI.box(Color(0, 0, 0, 0.5), 4)
		xh.set_content_margin_all(2)
		x.add_theme_stylebox_override("normal", xs)
		x.add_theme_stylebox_override("hover", xh)
		x.add_theme_stylebox_override("pressed", xh)
	head.add_child(x)
	v.add_child(hb)
	win.body = UI.vbox(6)
	win.body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win.scroll = ScrollContainer.new()
	win.scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	win.scroll.add_child(win.body)
	v.add_child(win.scroll)
	var grip := WinGrip.new()
	grip.win = win
	v.add_child(grip)
	win.base_w = win.custom_minimum_size.x
	root.add_child(win)
	win.load_size()
	windows[id] = win
	if refresher.is_valid():
		refreshers[id] = refresher
	return win


func _build_windows() -> void:
	_win("inventory", "ЛИЧНЫЙ ИНВЕНТАРЬ", 630, _refresh_inventory)
	_win("build", "СТРОИТЕЛЬСТВО", 720, _refresh_build)
	_win("building", "ЗДАНИЕ", 520, _refresh_building)
	_win("craft", "ПРОИЗВОДСТВО", 760, _refresh_craft)
	_win("skills", "НАВЫКИ", 520, _refresh_skills)
	_win("trade", "ТОРГОВАЯ СТАНЦИЯ «ОРБИТА-7»", 720, _refresh_trade)
	_win("tech", "ДЕРЕВО ОТКРЫТИЙ", 1000, _refresh_tech)
	_win("records", "РЕКОРДЫ И МАСТЕРСТВО", 600, _refresh_records)
	_win("scan", "СКАНЕР РЕСУРСОВ", 600, _refresh_scan)
	_win("settings", "НАСТРОЙКИ", 640, _refresh_settings)
	_win("pause", "ПАУЗА", 320, _refresh_pause)
	_win("help", "КАК ИГРАТЬ", 620, _refresh_help)
	_win("saves", "СОХРАНЕНИЯ", 600)
	_win("blueprints", "ЧЕРТЕЖИ", 520, _refresh_blueprints)
	_win("npc", "ТОРГОВЛЯ", 560, _refresh_npc)
	_win("orders", "ЗАКАЗЫ НА СТАНЦИИ", 700, _refresh_orders)
	_win("constructor", "КОНСТРУКТОР МОДОВ", 960, _refresh_ctor)
	# большая карта (M)
	var mw := _win("map", "КАРТА", 980)
	bigmap = Minimap.new()
	bigmap.custom_minimum_size = Vector2(950, 600)
	mw.body.add_child(bigmap)
	bigmap.setup(game, true)
	# инвентарь героя строим один раз
	var inv_w: Win = windows.inventory
	inv_grid = GridContainer.new()
	inv_grid.columns = 9
	inv_grid.add_theme_constant_override("h_separation", 4)
	inv_grid.add_theme_constant_override("v_separation", 4)
	_build_inv_grid()
	var tip := UI.small("Перетащить — переложить · Ctrl — половину · Двойной клик — в открытое здание · ПКМ — использовать")
	tip.tooltip_text = "Управление рюкзаком\nПеретащить: переложить предмет мышью\nCtrl: перетащить половину стопки (разделить на любое число — в карточке предмета)\nДвойной клик: переложить стопку в открытое здание и обратно\nShift+клик: переложить весь такой предмет (все стопки)\nAlt+клик: стопку в мусорку · Shift+Alt+клик: все такие предметы в мусорку (кнопка «Вернуть» отменяет)\nКлик: карточка предмета\nПКМ: съесть или использовать\nЯчейки с цифрами: панель быстрого доступа, в неё можно перетащить здание из меню стройки"
	tip.mouse_filter = Control.MOUSE_FILTER_PASS
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(520, 0)
	var cargo := UI.hbox(16)
	var readout := UI.vbox(6)
	readout.add_child(UI.section("Занято ячеек"))
	cargo_count = UI.label("",24,UI.TEXT)
	readout.add_child(cargo_count)
	cargo_meter = UI.bar(null,UI.ACCENT,5)
	readout.add_child(cargo_meter)
	cargo.add_child(readout)
	cargo.add_child(VSeparator.new())
	cargo.add_child(inv_grid)
	inv_w.body.add_child(cargo)
	inv_w.body.add_child(tip)
	# 13.10: расширение рюкзака за ресурсы
	bag_row = UI.hbox(10)
	inv_w.body.add_child(bag_row)
	# сведения о предмете, по которому щёлкнули
	info_box = PanelContainer.new()
	var ist := StyleBoxFlat.new()
	ist.bg_color = Color(0.06, 0.08, 0.11, 0.9)
	ist.set_corner_radius_all(6)
	ist.set_content_margin_all(10)
	info_box.add_theme_stylebox_override("panel", ist)
	info_box.visible = false
	inv_w.body.add_child(info_box)
	var row := UI.hbox()
	row.add_child(UI.button("Сортировать", func(): _sort(game.player.inv)))
	row.add_child(UI.button("Сложить в штаб", func(): game.cmd("store_hq", {})))
	# 13.10: мусорка — перетащите предмет в ячейку, он исчезнет; последний выброшенный можно вернуть
	if bool(DB.setting("trash", true)):
		row.add_child(UI.spacer())
		var tr := TrashSlot.new()
		tr.hud = self
		tr.custom_minimum_size = Vector2(54, 54)
		tr.tooltip_text = "Мусорка: перетащите сюда предмет (Ctrl — половину стопки), и он исчезнет.\nКнопка «Вернуть» отдаёт последний выброшенный."
		row.add_child(tr)
		trash_undo = UI.button("Вернуть", func(): untrash())
		trash_undo.disabled = true
		row.add_child(trash_undo)
	inv_w.body.add_child(row)
	# конец игры (победа или поражение) — содержимое строится в show_result
	end_win = UI.panel(0.94)
	end_win.visible = false
	root.add_child(end_win)
	# экран гибели героя
	death_box = ColorRect.new()
	death_box.color = Color(0.25, 0.0, 0.0, 0.45)
	death_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_box.visible = false
	var dc := CenterContainer.new()
	dc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_box.add_child(dc)
	var dv := UI.vbox(8)
	dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dc.add_child(dv)
	death_title = UI.label("", 52, Color(1, 0.35, 0.3))
	death_title.add_theme_color_override("font_outline_color", Color.BLACK)
	death_title.add_theme_constant_override("outline_size", 12)
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(death_title)
	death_text = UI.label("", 22, Color.WHITE)
	death_text.add_theme_color_override("font_outline_color", Color.BLACK)
	death_text.add_theme_constant_override("outline_size", 8)
	death_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(death_text)
	root.add_child(death_box)


const HOT_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
var _hot_sig := ""


## Панель быстрого доступа: число ячеек и их размер — из настроек игрока (или правил игры в редакторе).
## Что выбрано в панели: «Каменный топор ×1 · прочность 40/50» или здание для быстрой стройки.
func _selected_text(p) -> String:
	var i: int = p.selected
	if i < 0 or i >= p.inv.slots.size():
		return ""
	var idx: int = p.hot_slot(i)
	var sl = p.inv.slots[idx] if idx >= 0 else null
	if sl == null:
		var bt: String = p.hot_builds.get(i, "")
		if bt != "" and DB.data.buildings.has(bt):
			return "%s (%s)" % [str(DB.data.buildings[bt].get("name", bt)), DB.tx("hot_build", "здание")]
		return ""
	var s := DB.item_name(str(sl.id))
	if int(sl.n) > 1:
		s += " ×%d" % int(sl.n)
	if sl.has("dur"):
		var mx := int(DB.data.items.get(str(sl.id), {}).get("durability", 0))
		if mx > 0:
			s += " · %s %d/%d" % [DB.tx("durability", "прочность"), int(sl.dur), mx]
	return s


func _build_hotbar() -> void:
	var n := Player.hot_n()
	var sz := clampi(int(Prefs.get_value("hotbar_size", 56)), 36, 110)
	_hot_sig = "%d|%d" % [n, sz]
	for c in hotbar.get_children():
		c.queue_free()
	hotbar_slots.clear()
	for i in n:
		var s := Slot.new()
		s.setup(game.player.inv, i, self, sz)
		s.hotkey = HOT_KEYS[i]
		s.shortcut = true
		hotbar.add_child(s)
		hotbar_slots.append(s)
	for s in inv_slots:
		s.hotkey = ""
	if game.player.selected >= n:
		game.player.selected = 0


## Закрепить здание в ячейке панели (id "" — убрать). from — откуда перетащили.
func pin_build(id: String, index: int, from := -1) -> void:
	var p = game.player
	if from >= 0 and from != index:
		var other: String = p.hot_builds.get(index, "")
		var other_item: String = p.hot_items.get(index, "")
		p.hot_builds.erase(from)
		if other != "":
			p.hot_builds[from] = other
		elif other_item != "":
			p.pin_item(from, other_item)
	p.hot_items.erase(index)
	if id == "":
		p.hot_builds.erase(index)
	else:
		p.hot_builds[index] = id
	p.inv.changed.emit()
	for s in hotbar_slots + inv_slots:
		s._shown = "?"
	game.sfx.play_ui("click")


## Здание — в первую свободную ячейку панели (ПКМ по карточке в меню стройки).
func pin_build_free(id: String) -> void:
	var p = game.player
	for i in Player.hot_n():
		if not p.hot_items.has(i) and not p.hot_builds.has(i):
			pin_build(id, i)
			game.notify("%s — в панели быстрого доступа (клавиша %s)" % [DB.building(id).get("name", id), HOT_KEYS[i]], Color(0.6, 1, 0.7))
			return
	game.notify("Нет свободной ячейки в панели. Перетащите здание на нужную ячейку.", Color(1, 0.7, 0.4))


func is_open(id: String) -> bool:
	return windows.has(id) and windows[id].visible


func open(id: String) -> void:
	if not windows.has(id):
		return
	var w: Win = windows[id]
	var was := w.visible
	w.visible = true
	root.move_child(w, -1)
	if refreshers.has(id):
		refreshers[id].call()
	game.sfx.play_ui("click")
	if not was:
		# сначала наполняем окно, потом ставим по центру над панелью быстрых слотов.
		# Пока размер не известен, окно прозрачное и fit() его не двигает — без мигания и прыжков.
		w.home_y = -1.0
		w.modulate.a = 0.0
		w.reset_size()
		# два кадра: часть окон дозаполняется после первого обновления
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(w) and w.visible:
			var vs := root.get_viewport_rect().size / root.get_tree().root.content_scale_factor
			var bottom := _windows_bottom(vs)
			w.fit(vs, bottom)
			w.reset_size()
			var p := ((vs - w.size) * 0.5).round()
			p.y = clampf(p.y - 50.0, 10.0, maxf(10.0, bottom - w.size.y - 8.0))
			# если рядом уже открыто окно — ставим два окна бок о бок (здание слева, рюкзак справа)
			var other: Win = null
			for k in windows:
				if k != id and windows[k].visible and windows[k] is Win:
					other = windows[k]
			if other != null and other.size.x + w.size.x + 30.0 < vs.x:
				var total := other.size.x + w.size.x + 20.0
				var left := ((vs.x - total) * 0.5)
				var right_one: Win = w if id == "inventory" or other.id != "inventory" else other
				var left_one: Win = other if right_one == w else w
				left_one.place(Vector2(round(left), left_one.position.y if left_one != w else p.y))
				right_one.place(Vector2(round(left + left_one.size.x + 20.0), right_one.position.y if right_one != w else p.y))
			else:
				w.place(p)


func close(id: String) -> void:
	if windows.has(id):
		_hide_win(windows[id])
	if id == "building":
		bld = null
	if id in ["building", "craft"] and _auto_inv:
		_auto_inv = false
		if windows.has("inventory"):
			_hide_win(windows.inventory)
	if id == "inventory":
		_auto_inv = false
	game.sfx.play_ui("click")


## Обновить все открытые окна сейчас (после сдачи ресурсов, открытия узла и т. п.).
func refresh_open() -> void:
	for id in windows:
		if windows[id].visible and refreshers.has(id):
			refreshers[id].call()


func toggle(id: String) -> void:
	if is_open(id):
		close(id)
	else:
		open(id)


## Скрыть окно сразу (логика не ждёт анимации); у Win заодно сбрасывается «выпрыгивание».
func _hide_win(w: Control) -> void:
	if w is Win:
		w.snap_closed()
	else:
		w.visible = false


func close_all() -> bool:
	var any := false
	for id in windows:
		if windows[id].visible:
			_hide_win(windows[id])
			any = true
	bld = null
	_auto_inv = false
	return any


func any_window_open() -> bool:
	for id in windows:
		if windows[id].visible:
			return true
	if game and game.coop and game.coop.panel_open():
		return true
	return end_win.visible


func modal_open() -> bool:
	return is_open("pause") or is_open("settings") or is_open("help") or is_open("saves") or end_win.visible


# ---------------------------------------------------------------- обновление

func update(delta: float) -> void:
	_update_offer(delta)
	_place_panels()
	hurt_rect.color.a = max(0.0, hurt_rect.color.a - delta * 1.5)
	var p = game.player
	_update_counters(delta, p)
	hp_lbl.text = "Здоровье %d / %d" % [int(maxf(0.0, p.hp)), int(p.maxhp)]
	fps_lbl.visible = bool(Prefs.get_value("show_fps", false))
	_fps_t -= delta
	if fps_lbl.visible and _fps_t <= 0.0:
		_fps_t = 0.5
		var fps := Engine.get_frames_per_second()
		fps_lbl.text = "FPS %d · кадр %.1f мс · объектов %d · вызовов отрисовки %d · монстров %d (живых %d)" % [fps, 1000.0 / maxf(1.0, fps),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			game.enemies.list.size(), game.enemies.rigs.size()]
		fps_lbl.add_theme_color_override("font_color", Color(0.5, 1, 0.5) if fps >= 50 else (Color(1, 0.85, 0.3) if fps >= 30 else Color(1, 0.4, 0.3)))
	surv_box.visible = game.module("survival")
	if game.strategy and panels.has("vitals"):
		panels.vitals.visible = false   # 1.1.15: в стратегии нет здоровья, голода и погоды у героя
	food_bar.value = p.food
	water_bar.value = p.water
	var cl = game.climate
	clim_box.visible = cl != null and cl.enabled() and bool(cl.cfg().get("show_temp", true))
	if clim_box.visible:
		clim_lbl.text = cl.text() + ("  · замерзает!" if cl.chill >= 100.0 else ("  · мёрзнет" if cl.chill > 20.0 else "")) + ("  · перегрев!" if cl.heat >= 100.0 else ("  · жарко" if cl.heat > 20.0 else ""))
		chill_bar.visible = cl.chill > 0.5
		chill_bar.value = cl.chill
		heat_bar.visible = cl.heat > 0.5
		heat_bar.value = cl.heat
		clothes_row.visible = p.clothes != ""
		if p.clothes != "":
			var ci: Dictionary = DB.item(p.clothes)
			clothes_lbl.text = "Одежда: %s%s%s" % [DB.item_name(p.clothes), (" +%d°" % int(ci.get("warmth", 0))) if float(ci.get("warmth", 0)) > 0 else "", (" −%d° в жару" % int(ci.get("cooling", 0))) if float(ci.get("cooling", 0)) > 0 else ""]
	var hz = game.hazards
	rad_box.visible = hz != null and hz.enabled() and bool(Hazards.rcfg().get("show_meter", true)) and (hz.raw > 0.02 or hz.dose > 0.5 or hz.acid_hit > 0.0)
	if rad_box.visible:
		rad_lbl.text = hz.text()
		rad_bar.value = hz.dose
	if _hot_sig != "%d|%d" % [Player.hot_n(), clampi(int(Prefs.get_value("hotbar_size", 56)), 36, 110)]:
		_build_hotbar()
	for i in hotbar_slots.size():
		hotbar_slots[i].selected = i == p.selected or (p.hot_builds.get(i, "") != "" and p.hot_builds.get(i, "") == game.build_type )
		hotbar_slots[i].refresh()
	sel_lbl.text = _selected_text(p)
	var w = game.enemies
	if w.wave_live > 0:
		wave_lbl.text = "ВОЛНА %d идёт!" % w.wave   # 1.3: без счётчика роботов — он мог расходиться с тем, что на экране
	elif w.rush_on() and w.rush_timer >= 0.0:
		wave_lbl.text = ("НАТИСК %d через %d с" % [w.rush_n + 1, int(w.rush_timer)]) if w.rush_n > 0 else ("Натиск через %s" % _rush_clock(w.rush_timer))
	elif not w.waves_on():
		wave_lbl.text = "Мирная игра: без волн" if game.module("monsters") else "Мирная игра: без монстров"
	else:
		wave_lbl.text = "Волна %d через %d с" % [w.wave + 1, int(w.wave_timer)]
	clock_lbl.text = game.clock_text()
	_update_boss()
	alert_lbl.text = "МОНСТРЫ НАСТУПАЮТ!" if w.wave_alert > 0.0 and int(w.wave_alert * 3.0) % 2 == 0 else ""
	pause_lbl.visible = game.paused and not modal_open()
	death_box.visible = not p.alive and not end_win.visible
	if death_box.visible:
		death_title.text = DB.t(DB.menu("death_title", "ГЕРОЙ ПОГИБ"))
		death_text.text = DB.t(DB.menu("death_text", "Возрождение у штаба через {t} с"), {"t": ceili(maxf(0.0, p.respawn))})
	mode_lbl.text = game.mode_text()
	_update_mode_hud(delta)
	var cq: Array = game.craft_queue
	craft_lbl.visible = not cq.is_empty()
	craft_bar.visible = not cq.is_empty()
	if not cq.is_empty():
		var r: Dictionary = DB.data.recipes.get(cq[0].rid, {})
		craft_lbl.text = "Крафт: %s%s" % [r.get("name", cq[0].rid), (" (+%d в очереди)" % (cq.size() - 1)) if cq.size() > 1 else ""]
		craft_bar.value = cq[0].t / max(0.01, float(r.get("time", 1))) * 100.0
	acc += delta
	if acc < 0.25:
		return
	acc = 0.0
	_corp_extra = "   ·   Уровень [b]%d[/b]%s" % [game.level, ("   ·   [color=#7fdcff]очков: %d[/color]" % (game.skill_points + game.attr_points)) if game.skill_points + game.attr_points > 0 else ""]
	_corp_text()
	if float(game.xp) < _xp_goal:
		xp_bar.value = 0.0   # новый уровень — полоска начинает заново
	xp_bar.max_value = game.xp_next()
	_xp_goal = float(game.xp)
	var f = game.factory
	var hq = f.hq
	var ni: Dictionary = f.net_info(hq)
	if ni.is_empty():
		power_lbl.text = ""
	else:
		var col := "#7dff9a" if ni.sat >= 0.999 else ("#ffd36b" if ni.sat > 0.5 else "#ff6b5a")
		# 15.6: выработка / потребление и сколько свободно (потребление ровное: подключённые машины едят всё время)
		power_lbl.text = "Энергия базы: [color=%s]%d / %d[/color] · свободно %d%s" % [col, int(ni.supply), int(ni.demand), maxi(0, int(ni.supply - ni.demand)), ("   аккумуляторы %d%%" % int(ni.stored / max(1.0, ni.cap) * 100)) if ni.cap > 0 else ""]
		power_lbl.tooltip_text = "Выработка / потребление сети штаба. Свободно — сколько ещё можно подключить."
	var qt: String = game.quest_text()
	if quest_lbl.text != qt:
		quest_lbl.text = qt
	quest_lbl.tooltip_text = game.quest_hint()
	effects_lbl.text = game.effects_text()
	var it: String = game.info_text()
	info_lbl.text = it
	panels.info.visible = it != "" and panels.info.get_meta("on", true)
	var vs := root.get_viewport_rect().size / root.get_tree().root.content_scale_factor
	# панели сжимаются, когда текст в них стал короче (иначе остаётся пустое место)
	for id in panels:
		var pn: Control = panels[id]
		if pn.visible and pn.size.y > pn.get_combined_minimum_size().y + 1.0:
			pn.reset_size()
			apply_layout()
			break
	var bottom := _windows_bottom(vs)
	for id in windows:
		if windows[id].visible and refreshers.has(id):
			refreshers[id].call()
		if windows[id].visible and windows[id] is Win:
			windows[id].fit(vs, bottom)
	_update_custom_windows()


## Плавные счётчики: здоровье и опыт подтягиваются, а не прыгают; кредиты досчитываются с золотой вспышкой.
func _update_counters(delta: float, p) -> void:
	var k := 1.0 - exp(-delta * 14.0)
	var mx := float(p.maxhp)
	var hp := clampf(float(p.hp), 0.0, mx)
	hp_bar.max_value = mx
	hp_chunk.max_value = mx
	hp_bar.value = hp if absf(hp_bar.value - hp) < mx * 0.002 else lerpf(hp_bar.value, hp, k)
	if hp >= hp_chunk.value:
		hp_chunk.value = hp
		_chunk_wait = 0.4
	elif _hp_prev - hp > mx * 0.01:
		_chunk_wait = 0.4   # новый удар — хвост снова ждёт
	elif _chunk_wait > 0.0:
		_chunk_wait -= delta
	else:
		hp_chunk.value = maxf(hp, hp_chunk.value - maxf(mx * 0.6, 20.0) * delta)
	_hp_prev = hp
	if _xp_goal >= 0.0:
		xp_bar.value = _xp_goal if absf(xp_bar.value - _xp_goal) < xp_bar.max_value * 0.002 else lerpf(xp_bar.value, _xp_goal, 1.0 - exp(-delta * 8.0))
	var cr := int(game.credits)
	if _cr_shown < 0:
		_cr_shown = cr
	elif _cr_shown != cr:
		var d := cr - _cr_shown
		if d > 0 and (_cr_tw == null or not _cr_tw.is_valid()):
			_cr_flash()
		var step := int(ceil(absf(d) * (1.0 - exp(-delta * 9.0))))
		_cr_shown += clampi(d, -maxi(1, step), maxi(1, step))
		_corp_text()


func _corp_text() -> void:
	var ht: String = game.hearts.text() if game.get("hearts") != null else ""
	if ht != "":
		ht = "   [color=%s]%s[/color]" % ["#ff6b7a" if game.hearts.used() >= game.hearts.cap() else "#ffb3bd", ht]
	corp_lbl.text = "[color=#ffd36b]%d кр[/color]%s%s" % [_cr_shown if _cr_shown >= 0 else int(game.credits), ht, _corp_extra]


## Короткая золотая вспышка строки с кредитами.
func _cr_flash() -> void:
	_cr_tw = corp_lbl.create_tween()
	_cr_tw.tween_property(corp_lbl, "modulate", Color(1.5, 1.3, 0.55), 0.08)
	_cr_tw.tween_property(corp_lbl, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


func hurt_flash() -> void:
	hurt_rect.color.a = 0.35


var _toast_re: RegEx

## 1.1.8: карточка «Как это работает» — при первой постройке особого здания (поле «explain» у здания). Один раз на профиль.
var _explain_card: Control = null


func explain_once(type: String) -> void:
	var tx := str(DB.building(type).get("explain", ""))
	if tx == "" or DisplayServer.get_name() == "headless":
		return
	var seen = Prefs.get_value("explained18", [])
	seen = seen.duplicate() if seen is Array else []
	if type in seen:
		return
	seen.append(type)
	Prefs.set_value("explained18", seen)
	show_explain(type)


func show_explain(type: String) -> void:
	if _explain_card != null and is_instance_valid(_explain_card):
		_explain_card.queue_free()
	var d := DB.building(type)
	var pnl := UI.panel(0.94)
	pnl.custom_minimum_size = Vector2(540, 0)
	var v := UI.vbox(8)
	pnl.add_child(v)
	var top := UI.hbox(10)
	top.add_child(UI.building_icon(type, 48))
	var hv := UI.vbox(2)
	hv.add_child(UI.label("Как это работает: %s" % str(d.get("name", type)), 17, UI.ACCENT))
	hv.add_child(UI.small("Это окно показывается один раз. Потом то же самое — в окне здания (E)."))
	top.add_child(hv)
	v.add_child(top)
	var r := UI.rich(str(d.get("explain", "")), 15)
	r.fit_content = true
	r.custom_minimum_size = Vector2(520, 0)
	v.add_child(r)
	v.add_child(UI.button("Понятно", func():
		if is_instance_valid(pnl):
			pnl.queue_free()))
	add_child(pnl)
	pnl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pnl.position = Vector2((pnl.get_viewport().get_visible_rect().size.x - 540.0) * 0.5, 90.0)
	_explain_card = pnl


## Всплывающая строка. Одинаковые подряд (за ~2 с) не плодятся: «+1 Бревно» ×5 → одна строка «+5 Бревно»,
## прочие повторы — «текст ×2». Строка въезжает сбоку и «подпрыгивает».
func toast(text: String, col := Color.WHITE) -> void:
	if game and game.flags.get("quiet", false):
		return
	if _toast_re == null:
		_toast_re = RegEx.create_from_string("^\\+(\\d+) (.+)$")
	var now := Time.get_ticks_msec()
	var m := _toast_re.search(text)
	var key := ("+" + m.get_string(2)) if m else text
	var add := int(m.get_string(1)) if m else 1
	for w in toast_box.get_children():
		if w.is_queued_for_deletion() or str(w.get_meta("key", "")) != key or now - int(w.get_meta("t", 0)) > 2000:
			continue
		var n: int = int(w.get_meta("n", 1)) + add
		w.set_meta("n", n)
		w.set_meta("t", now)
		var l0: Label = w.get_child(0)
		l0.text = ("+%d %s" % [n, m.get_string(2)]) if m else ("%s  ×%d" % [text, n])
		l0.add_theme_color_override("font_color", col)
		_toast_life(w, l0, false)
		return
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_meta("key", key)
	wrap.set_meta("n", add)
	wrap.set_meta("t", now)
	var l := UI.label(text, 17, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	wrap.add_child(l)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	# строка свободна внутри обёртки — её можно двигать, а столбик всплывашек не дёргается
	var fit_min := func(): wrap.custom_minimum_size = l.get_combined_minimum_size()
	l.minimum_size_changed.connect(fit_min)
	fit_min.call()
	l.resized.connect(func(): l.pivot_offset = l.size * 0.5)
	toast_box.add_child(wrap)
	if toast_box.get_child_count() > 5:
		toast_box.get_child(0).queue_free()
	_toast_life(wrap, l, true)


## Анимация строки: въезд (новая) или «подпрыгивание» (обновился счётчик), потом висит и тает.
func _toast_life(wrap: Control, l: Label, fresh: bool) -> void:
	var old = wrap.get_meta("tw") if wrap.has_meta("tw") else null
	if old is Tween and old.is_valid():
		old.kill()
	l.modulate.a = 1.0 if not fresh else 0.0
	l.pivot_offset = l.size * 0.5
	var tw := wrap.create_tween()
	wrap.set_meta("tw", tw)
	if fresh:
		l.position.x = 40.0
		l.scale = Vector2.ONE * 1.15
		tw.set_parallel(true)
		tw.tween_property(l, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 1.0, 0.15)
		tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
	else:
		l.position.x = 0.0
		l.scale = Vector2.ONE * 1.18
		tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(wrap.queue_free)


## Экран победы или поражения: заголовок и текст из редактора, статистика игры, кнопки.
func show_result(win: bool) -> void:
	UI.clear(end_win)
	var v := UI.vbox(12)
	v.custom_minimum_size = Vector2(440, 0)
	end_win.add_child(v)
	var t := UI.label(DB.t(DB.menu("victory_title" if win else "defeat_title", "ПОБЕДА!" if win else "ПОРАЖЕНИЕ")), 40, UI.GOOD if win else UI.BAD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var txt := DB.t(DB.menu("victory_text" if win else "defeat_text", ""))
	if txt != "":
		var l := UI.label(txt, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	if bool(DB.menu("show_stats", true)):
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 24)
		for row in game.stats():
			g.add_child(UI.label(str(row[0]), 15, UI.DIM))
			g.add_child(UI.label(str(row[1]), 15))
		var cc := CenterContainer.new()
		cc.add_child(g)
		v.add_child(cc)
	if win:
		end_continue = UI.button(DB.tx("continue_build", "Продолжить строить"), func(): end_win.visible = false; game.game_over = false)
		v.add_child(end_continue)
	else:
		var last := SavesUI.newest() if not Net.active() else ""   # A-7: в сетевой игре — только выйти в меню
		if last != "":
			v.add_child(UI.button(DB.tx("load_last", "Загрузить последнее сохранение"), func(): SavesUI.start_from(get_tree(), last)))
	v.add_child(UI.button(DB.tx("to_menu", "В главное меню"), func(): game.to_menu()))
	end_win.visible = true
	end_win.size = Vector2.ZERO
	_center_end.call_deferred()
	game.sfx.play("victory" if win else "defeat", game.player.position)


func _center_end() -> void:
	await get_tree().process_frame
	end_win.size = Vector2.ZERO
	end_win.reset_size()
	var vs := root.get_viewport_rect().size / root.get_tree().root.content_scale_factor
	end_win.position = ((vs - end_win.size) * 0.5).round()


## Старый вызов (моды и консоль): показать произвольный текст в окне итогов.
func show_end(text: String, win: bool) -> void:
	show_result(win)
	var v := end_win.get_child(0)
	var l := UI.label(text, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.move_child(l, 1)


# ---------------------------------------------------------------- инвентарь: перенос предметов

## Отделить n предметов стопки в первую свободную ячейку того же инвентаря.
func split_slot(inv: Inventory, i: int, n: int) -> bool:
	var a = inv.slots[i]
	if a == null or n <= 0 or n >= int(a.n):
		return false
	var free := -1
	for k in inv.slots.size():
		if inv.slots[k] == null:
			free = k
			break
	if free < 0:
		game.notify("Нет свободной ячейки, чтобы разделить стопку", Color(1, 0.7, 0.4))
		return false
	inv.slots[free] = a.duplicate()
	inv.slots[free].n = n
	a.n -= n
	inv.changed.emit()
	game.sfx.play_ui("click")
	if info_box and info_box.visible:
		show_item_info(inv, i)
	return true


var trash_undo: Button
var trashed = null      # [inv, slot] последнего выброшенного


## Выбросить стопку (или половину) из ячейки.
func trash(inv: Inventory, i: int, half := false) -> void:
	var s = inv.slots[i] if i < inv.slots.size() else null
	if s == null:
		return
	if Net.busy() and _bld_key(inv) == "":
		# B12-3: вещи команды в пути ещё в рюкзаке — выбросить (и «Вернуть») их до ответа хозяина значило удвоить
		game.notify("Подождите ответа хозяина", Color(1, 0.8, 0.5))
		return
	var n := int(s.n)
	if half and n > 1:
		n = n / 2
	var gone: Dictionary = s.duplicate()
	gone["n"] = n
	var bk := _bld_key(inv)
	if bk != "":
		var tr0 = game.cmd("btrash", {"b": _bld_of(inv), "k": bk, "idx": [i], "n": n, "ids": [str(s.id)]})   # B-4 r11: со сверкой предмета
		if Net.is_client() or tr0 == null:
			_trash_no_undo()   # B-3 r11 / B15-2: в сети выбросит хозяин, а при отказе «Вернуть» давало дюп
			return
	else:
		if n >= int(s.n):
			inv.slots[i] = null
		else:
			s.n = int(s.n) - n
		inv.changed.emit()
	trashed = [inv, gone]
	if trash_undo:
		trash_undo.disabled = false
		trash_undo.text = "Вернуть: %s ×%d" % [DB.item_name(str(gone.id)), n]
	game.sfx.play_ui("click")
	refresh_open()


## 1.3: Shift+Alt+клик — в мусорку все стопки этого предмета из этого инвентаря (вернуть можно разом).
func trash_all(inv: Inventory, i: int) -> void:
	var s = inv.slots[i] if i < inv.slots.size() else null
	if s == null:
		return
	if Net.busy() and _bld_key(inv) == "":
		# B12-3: вещи команды в пути ещё в рюкзаке — выбросить (и «Вернуть») их до ответа хозяина значило удвоить
		game.notify("Подождите ответа хозяина", Color(1, 0.8, 0.5))
		return
	var id := str(s.id)
	var gone := []
	var n := 0
	var bk := _bld_key(inv)
	var idx := []
	for k in inv.slots.size():
		var o = inv.slots[k]
		if o != null and str(o.id) == id:
			gone.append(o.duplicate())
			n += int(o.n)
			idx.append(k)
			if bk == "":
				inv.slots[k] = null
	if bk != "":
		var tr1 = game.cmd("btrash", {"b": _bld_of(inv), "k": bk, "idx": idx, "n": -1, "ids": idx.map(func(_k): return id)})
		if Net.is_client() or tr1 == null:
			_trash_no_undo()   # B-3 r11 / B15-2
			return
	inv.changed.emit()
	trashed = [inv, gone]
	if trash_undo:
		trash_undo.disabled = false
		trash_undo.text = "Вернуть: %s ×%d" % [DB.item_name(id), n]
	game.sfx.play_ui("click")
	refresh_open()


## B-3 r11: выброшенное из здания по сети вернуть нельзя (ячейку очищает хозяин, а не мы).
func _trash_no_undo() -> void:
	trashed = null
	if trash_undo:
		trash_undo.disabled = true
		trash_undo.text = "Вернуть"
	game.sfx.play_ui("click")
	refresh_open()


## Вернуть последний выброшенный предмет (что не влезло — к ногам героя).
func untrash() -> void:
	if trashed == null:
		return
	var inv: Inventory = game.player.inv
	var list: Array = trashed[1] if trashed[1] is Array else [trashed[1]]
	for gone in list:
		var put := false
		for i in inv.slots.size():
			if inv.slots[i] == null:
				inv.slots[i] = gone.duplicate()
				put = true
				break
		if not put:
			var left: int = inv.add(str(gone.id), int(gone.n))
			if left > 0:
				game.overflow(str(gone.id), left, game.player.position)
	inv.changed.emit()
	trashed = null
	if trash_undo:
		trash_undo.disabled = true
		trash_undo.text = "Вернуть"
	refresh_open()


func move_slot(src: Inventory, si: int, dst: Inventory, di: int, half := false) -> void:
	if src == dst and si == di:
		return
	# 1.5: перенос между героем и зданием — командой (в сетевой игре её выполняет хозяин мира;
	# раньше гость двигал предметы только у себя — они пропадали или появлялись снова)
	var pinv: Inventory = game.player.inv
	var sk := "p" if src == pinv else _bld_key(src)
	var dk := "p" if dst == pinv else _bld_key(dst)
	if sk != "" and dk != "" and (sk != "p" or dk != "p"):
		var sv = src.slots[si] if si >= 0 and si < src.slots.size() else null
		var ob = _bld_of(src) if sk != "p" else _bld_of(dst)
		if sk != "p" and dk != "p" and _bld_of(src) != _bld_of(dst):
			# B15-3: между частями составного (встроенный ящик ↔ основа) — одной командой «xmv» на составное
			game.cmd("xmv", {"b": _bld_of(src), "s": sk, "si": si, "b2": _bld_of(dst), "d": dk, "di": di, "half": half, "sid": str(sv.id) if sv != null else ""})
			game.sfx.play_ui("click")
			return
		game.cmd("mv", {"b": ob, "s": sk, "si": si, "d": dk, "di": di, "half": half, "sid": str(sv.id) if sv != null else ""})   # B-4 r11
		game.sfx.play_ui("click")
		return
	var why := Inventory.move_between(src, si, dst, di, half)
	if why != "":
		game.notify(why, Color(1, 0.7, 0.4))
		return
	game.sfx.play_ui("click")


## 1.5: какой это инвентарь открытого здания: "inv", "out" или "fuel"; "" — не инвентарь здания.
func _bld_key(inv: Inventory) -> String:
	var ob = _bld_of(inv)
	if ob == null:
		return ""
	for k in ["inv", "out", "fuel"]:
		if ob.get(k) == inv:
			return k
	return ""


## 1.1.20 B14-1: чей это инвентарь — открытого здания или его встроенного (ящик, машина составного).
func _bld_of(inv: Inventory):
	if bld == null or inv == null:
		return null
	for b in [bld] + (bld.subs if bld.subs is Array else []):
		for k in ["inv", "out", "fuel"]:
			if b.get(k) == inv:
				return b
	return null


## Shift+клик: из героя — в открытое здание; из здания — герою.
## 1.3: all — переносится весь такой предмет (все стопки), а не одна стопка.
func quick_move(inv: Inventory, i: int, all := false) -> void:
	var s = inv.slots[i]
	if s == null:
		return
	var pinv: Inventory = game.player.inv
	if inv == pinv:
		if bld != null and is_open("building"):
			game.cmd("put", {"b": bld, "id": s.id, "n": pinv.count(s.id) if all else s.n})
		else:
			for k in Player.hot_n():
				if not game.player.hot_items.has(k) and not game.player.hot_builds.has(k):
					game.player.pin_item(k, str(s.id))
					return
	else:
		var idx := [i]
		if all:
			for k in inv.slots.size():
				var o = inv.slots[k]
				if k != i and o != null and o.id == s.id:
					idx.append(k)
		var bk := _bld_key(inv)
		if bk != "":
			game.cmd("take_slots", {"b": _bld_of(inv), "k": bk, "idx": idx, "ids": idx.map(func(_k): return str(s.id))})   # B-4 r11
			game.sfx.play_ui("click")
			return
		for k in idx:
			var o = inv.slots[k]
			var left := pinv.add_slot(o)
			if left == 0:
				inv.slots[k] = null
			else:
				o.n = left
				break   # рюкзак полон
		inv.changed.emit()
		pinv.changed.emit()
	game.sfx.play_ui("click")


func use_slot(inv: Inventory, i: int) -> void:
	if inv == game.player.inv:
		game.player.use_item(i)


## Сортировка: панель быстрого доступа остаётся как есть, рюкзак — по категориям.
## Предметы с прочностью или свежестью не сливаются (их состояние сохраняется).
func _sort(inv: Inventory) -> void:
	var start := 0 if inv == game.player.inv else 0
	var keep := []
	var t := {}
	for i in range(start, inv.size()):
		var s = inv.slots[i]
		if s == null:
			continue
		if s.has("dur") or s.has("fresh"):
			keep.append(s)
		else:
			t[s.id] = t.get(s.id, 0) + int(s.n)
		inv.slots[i] = null
	var key := func(id): return str(DB.item(id).get("category", "")) + DB.item_name(id)
	keep.sort_custom(func(a, b): return key.call(a.id) < key.call(b.id))
	var ids := t.keys()
	ids.sort_custom(func(a, b): return key.call(a) < key.call(b))
	var k := start
	for s in keep:
		inv.slots[k] = s
		k += 1
	for id in ids:
		var n: int = t[id]
		var st := DB.stack_of(id)
		while n > 0 and k < inv.size():
			inv.slots[k] = {"id": id, "n": mini(st, n)}
			n -= mini(st, n)
			k += 1
	inv.changed.emit()


## Ячейки рюкзака (пересобираются, когда рюкзак расширили).
func _build_inv_grid() -> void:
	for c in inv_grid.get_children():
		c.queue_free()
	inv_slots.clear()
	for i in game.player.inv.size():
		var s := Slot.new()
		s.setup(game.player.inv, i, self, 54)
		inv_grid.add_child(s)
		inv_slots.append(s)


var _bag_have := ""
var _bag_cost: Control = null
var _bag_btn: Button = null

## Строка «Рюкзак: N ячеек · Расширить (+9): цена».
func _refresh_bag() -> void:
	if bag_row == null:
		return
	var p = game.player
	var st := Player.bag_next(p.bag_level)
	var cost: Dictionary = st.get("cost", {})
	var sig := "%d|%d|%d|%s" % [p.inv.size(), p.bag_level, DB.revision, ",".join(cost.keys())]
	var have_sig := ",".join(cost.keys().map(func(k): return "%d" % game.factory.available(k)))
	if sig == _bag_sig:
		# изменилось только «сколько есть» (крафт, перенос предмета) — обновляем цифры на месте, без пересборки строки:
		# пересборка на миг растягивала окно вниз и сдвигала его вверх
		if have_sig != _bag_have and _bag_cost != null and is_instance_valid(_bag_cost):
			_bag_have = have_sig
			UI.fill_cost(_bag_cost, cost, func(it): return game.factory.available(it))
			var ok2 := true
			for it in cost:
				if game.factory.available(it) < int(cost[it]):
					ok2 = false
			if _bag_btn and is_instance_valid(_bag_btn):
				_bag_btn.disabled = not ok2 and not game.flags.get("free_build", false)
		return
	_bag_sig = sig
	_bag_have = have_sig
	UI.clear(bag_row)
	bag_row.visible = bool(Player.bag_cfg().get("enabled", true))
	var lbl := UI.label("Рюкзак: %d ячеек" % p.inv.size(), 16)
	bag_row.add_child(lbl)
	if st.is_empty():
		bag_row.add_child(UI.small("· максимальный размер"))
		return
	var ok := true
	for it in cost:
		if game.factory.available(it) < int(cost[it]):
			ok = false
	var cb := UI.cost_box(cost, func(it): return game.factory.available(it))
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_row.add_child(cb)
	_bag_cost = cb
	var b := UI.button("Расширить (+%d)" % (Player.bag_size(p.bag_level + 1) - p.inv.size()), func(): game.cmd("bag_up", {}))
	b.disabled = not ok and not game.flags.get("free_build", false)
	b.tooltip_text = "Расширить рюкзак на %d ячеек.\nЦена берётся из рюкзака и склада штаба.\nШагов расширения осталось: %d" % [Player.bag_size(p.bag_level + 1) - p.inv.size(), Player.bag_cfg().get("steps", []).size() - p.bag_level]
	bag_row.add_child(b)
	_bag_btn = b


func _refresh_inventory() -> void:
	if inv_slots.size() != game.player.inv.size():
		_build_inv_grid()
	# 1.7: окно растянули — в ряд помещается больше ячеек
	var iw: Win = windows.get("inventory")
	if iw != null and iw.scroll != null:
		var sep := float(inv_grid.get_theme_constant("h_separation"))
		var cols := clampi(int((iw.scroll.size.x - 156.0 + sep) / (54.0 + sep)), 5, 24) if iw.user_size.x > 0.0 else 8
		if cols != inv_grid.columns:
			inv_grid.columns = cols
	var occupied: int = game.player.inv.slots.filter(func(slot): return slot != null).size()
	cargo_count.text = "%d / %d" % [occupied, game.player.inv.size()]
	cargo_meter.max_value = game.player.inv.size()
	cargo_meter.value = occupied
	_refresh_bag()
	var sel: int = inv_pick if inv_pick >= 0 and inv_pick < inv_slots.size() else game.player.hot_slot(game.player.selected)
	for s in inv_slots:
		s.selected = s.index == sel
		s.refresh()
	# предмет из карточки забрали или он кончился — карточку обновляем
	if info_box and info_box.visible and info_key != "":
		var p := info_key.split("|")
		var inv: Inventory = info_box.get_meta("inv", null)
		var i := int(p[1])
		var sl = inv.slots[i] if inv and i < inv.slots.size() else null
		var now := "" if sl == null else "%s|%d|%d|%s" % [sl.id, i, sl.n, sl.get("dur", -1)]
		if now != info_key:
			show_item_info(inv, i)


## Карточка предмета в инвентаре: что это, сколько чего даёт, где делается и куда идёт.
func show_item_info(inv: Inventory, i: int) -> void:
	if info_box == null:
		return
	var sl = inv.slots[i] if i < inv.slots.size() else null
	UI.clear(info_box)
	if sl == null:
		info_box.visible = false
		info_key = ""
		return
	var id: String = sl.id
	info_key = "%s|%d|%d|%s" % [id, i, sl.n, sl.get("dur", -1)]
	info_box.set_meta("inv", inv)
	info_box.visible = true
	var it := DB.item(id)
	var row := UI.hbox(12)
	info_box.add_child(row)
	var ic := UI.item_icon(id, 72)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var head := UI.hbox(8)
	head.add_child(UI.label(DB.t(str(it.get("name", id))), 18, UI.ACCENT))
	if str(it.get("category", "")) != "":
		head.add_child(UI.label("· " + str(it.category), 14, UI.DIM))
	var rar: String = {"rare": "★ Редкий", "epic": "★ Очень редкий", "legendary": "★ Легендарный"}.get(it.get("rarity", ""), "")
	if rar != "":
		head.add_child(UI.label(rar, 14, Color(1, 0.8, 0.3)))
	head.add_child(UI.spacer())
	head.add_child(UI.button("×", func(): info_box.visible = false; info_key = ""))
	v.add_child(head)
	if str(it.get("desc", "")) != "":
		var d := UI.label(Tutorial.keys(Lang.t(DB.t(str(it.desc)))), 14)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(380, 0)
		v.add_child(d)
	# свойства одной строкой
	var props := []
	props.append("В ячейке: %d из %d" % [int(sl.n), DB.stack_of(id)])
	if it.has("food"):
		props.append("Сытость +%d" % int(it.food))
	if it.has("water"):
		props.append("Вода +%d" % int(it.water))
	if it.has("heal"):
		props.append("Здоровье +%d" % int(it.heal))
	if it.has("damage"):
		props.append("Урон %d" % int(it.damage))
	if it.has("range"):
		props.append("Дальность %.1f м" % float(it.range))
	if it.has("durability"):
		props.append("Прочность %d / %d" % [int(sl.get("dur", it.durability)), int(it.durability)])
	if it.has("fuel"):
		props.append("Топливо: %d с" % int(it.fuel))
	if int(it.get("price", 0)) > 0:
		props.append("Цена ~%d кр" % int(it.price))
	var pl := UI.label("   ".join(props), 14, Color(0.75, 0.9, 1.0))
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pl)
	# откуда берётся и куда идёт
	var made := []
	var used := []
	for rid in DB.data.recipes:
		var r: Dictionary = DB.data.recipes[rid]
		if r.get("out", {}).has(id) and made.size() < 4:
			made.append(str(r.get("name", rid)))
		if r.get("in", {}).has(id) and used.size() < 6:
			for o in r.get("out", {}):
				var nm := DB.item_name(o)
				if not nm in used:
					used.append(nm)
	var from := []
	for res in DB.data.resources:
		for dr in DB.data.resources[res].get("drops", []):
			if str(dr.get("item", "")) == id and from.size() < 4:
				var rn := str(DB.data.resources[res].get("name", res))
				if not rn in from:
					from.append(rn)
	if not from.is_empty():
		v.add_child(UI.small("Добывается: " + ", ".join(from)))
	if not made.is_empty():
		v.add_child(UI.small("Делается: " + ", ".join(made)))
	if not used.is_empty():
		v.add_child(UI.small("Нужен для: " + ", ".join(used)))
	if it.has("food") or it.has("water") or it.has("heal") or it.has("boost") or it.has("on_use") or it.has("plant"):
		var br := UI.hbox()
		br.add_child(UI.button("Использовать (ПКМ)", func(): use_slot(inv, i)))
		v.add_child(br)
	var stk = inv.slots[i]
	if stk != null and int(stk.n) > 1 and bool(DB.setting("split_stacks", true)):
		# разделить стопку: часть уходит в свободную ячейку
		var sr := UI.hbox()
		sr.add_child(UI.small("Разделить:"))
		var sp := SpinBox.new()
		sp.min_value = 1
		sp.max_value = int(stk.n) - 1
		sp.value = int(stk.n) / 2
		sp.custom_minimum_size = Vector2(80, 0)
		sr.add_child(sp)
		sr.add_child(UI.button("Отделить", func(): split_slot(inv, i, int(sp.value)), "Отделить столько в свободную ячейку. Ещё: перетащить с Ctrl — половина стопки"))
		sr.add_child(UI.button("Пополам", func(): split_slot(inv, i, int(inv.slots[i].n) / 2 if inv.slots[i] != null else 0)))
		v.add_child(sr)


# ---------------------------------------------------------------- меню строительства

func _refresh_build() -> void:
	var w: Win = windows.build
	# 1.1.15: и открытия в дереве — новое здание видно сразу после изучения (раньше — только после смены вкладки)
	var scan_sig := int(game.world.orders_placed) + DB.known.size() * 1000 + DB.researched.size() + DB.locked.size() * 1000000 + Tech.lock_rev * 1000000000 + (1 if game.flags.get("free_build", false) else 0) * 500
	if w.body.get_child_count() > 0 and w.get_meta("rev", -1) == DB.revision and w.get_meta("cat", "") == build_cat and w.get_meta("q", "") == build_search and w.get_meta("scan", -1) == scan_sig:
		_update_build_costs()
		return
	w.set_meta("rev", DB.revision)
	w.set_meta("scan", scan_sig)
	w.set_meta("cat", build_cat)
	w.set_meta("q", build_search)
	UI.clear(w.body)
	var cats: Array = DB.data.categories.keys()
	cats.sort_custom(func(a, b): return int(DB.data.categories[a].get("order", 0)) < int(DB.data.categories[b].get("order", 0)))
	if build_cat == "" and not cats.is_empty():
		build_cat = cats[0]
	var top := HFlowContainer.new()   # разделы переносятся на 2-ю строку, окно не растягивается
	top.add_theme_constant_override("h_separation", 4)
	top.add_theme_constant_override("v_separation", 4)
	for c in cats:
		var cd: Dictionary = DB.data.categories[c]
		var b := UI.button(cd.get("name", c), func(): build_cat = c; build_search = ""; _refresh_build())
		if c == build_cat and build_search == "":
			b.add_theme_color_override("font_color", UI.theme().get_color("font_pressed_color", "Button"))
			b.add_theme_color_override("font_hover_color", UI.theme().get_color("font_pressed_color", "Button"))
			b.add_theme_stylebox_override("normal", UI.theme().get_stylebox("pressed", "Button"))
			b.add_theme_stylebox_override("hover", UI.theme().get_stylebox("pressed", "Button"))
		top.add_child(b)
	w.body.add_child(top)
	if not Net.active():
		var order := HBoxContainer.new()
		var ores := OptionButton.new()
		for i in game.world.deposits.size():
			if not game.world.deposit_hidden(i):
				ores.add_item(DB.item_name(str(game.world.deposits[i].item)), i)
		order.add_child(ores)
		var commit := UI.button("Заказать месторождение · %d кр." % game.world.order_price, func():
			if ores.selected >= 0:
				game.cancel_build()
				game.field_selection = ores.get_selected_id()
				close("build"))
		order.add_child(commit)
		w.body.add_child(order)
	var se := LineEdit.new()
	se.placeholder_text = "Поиск по названию..."
	se.text = build_search
	se.text_changed.connect(func(t): build_search = t; _refresh_build_soon())
	w.body.add_child(se)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	w.body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var ids: Array = []
	for id in DB.data.buildings:
		var d: Dictionary = DB.data.buildings[id]
		if not d.get("params", {}).get("buildable", true):
			continue
		if game.strategy and id in DB.PERSONAL_BUILDINGS:
			continue   # 1.1.16: медпункт и грядка — для героя
		# 13.10: не открытое в дереве в меню не показывается. 1.0.8: открытое, но из неизученных в сканере ресурсов —
		# показывается серым с замком и списком, что изучить (раньше просто пропадало — игроки не понимали, куда делось)
		if not game.flags.get("free_build", false) and Tech.building_locked(id):
			continue
		if build_search != "":
			if not str(d.get("name", id)).to_lower().contains(build_search.to_lower()):
				continue
		elif d.get("category", "") != build_cat:
			continue
		ids.append(id)
	# сначала доступные, потом закрытые сканером
	var ready_ids := ids.filter(func(i): return game.flags.get("free_build", false) or DB.cost_known(DB.building(i).get("cost", {})))
	var locked_ids := ids.filter(func(i): return not ready_ids.has(i))
	for id in ready_ids + locked_ids:
		grid.add_child(_build_card(id))
	if not locked_ids.is_empty():
		var lk := UI.small("Серые с замком — уже открыты, но в их цене есть ресурсы, не изученные в сканере (%s). Изучите их — и здание можно строить." % str(Prefs.get_value("key_scan", "I")))
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lk.custom_minimum_size = Vector2(600, 0)
		w.body.add_child(lk)
	if ids.is_empty():
		grid.add_child(UI.small("Ничего не найдено"))
	w.body.add_child(UI.small("Клик — выбрать здание. R — повернуть, ПКМ — отмена. Ленты и стены тяните мышью."))
	if se.text != "":
		se.grab_focus()
		se.caret_column = se.text.length()


var _soon := false
func _refresh_build_soon() -> void:
	if _soon:
		return
	_soon = true
	await get_tree().create_timer(0.15).timeout
	_soon = false
	_refresh_build()


func _build_card(id: String) -> Control:
	var d := DB.building(id)
	var card := BuildCard.new()
	card.bid = id
	card.hud = self
	card.custom_minimum_size = Vector2(UI.ws(340), UI.fs(96))
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = UI.building_tip(id) + "\n\nКлик — строить. ПКМ или перетащить на панель внизу — в быструю панель"
	card.pressed.connect(func(): game.select_build(id); close("build") if game.build_type == id else null)
	var scan_miss: Array = [] if game.flags.get("free_build", false) else DB.scan_missing(d.get("cost", {}))
	if not scan_miss.is_empty():
		card.modulate = Color(0.62, 0.64, 0.68, 0.85)
		card.tooltip_text = UI.building_tip(id) + "\n\n[закрыто сканером] Изучите в сканере (%s): %s" % [str(Prefs.get_value("key_scan", "I")), ", ".join(scan_miss.map(func(k): return DB.item_name(k)))]
	if Tech.building_locked(id):
		card.modulate = Color(1, 1, 1, 0.5)
		card.tooltip_text = UI.building_tip(id) + "\n\n[закрыто] Откройте «%s» в дереве открытий (J)" % game.tech.opener("b", id)
	var h := UI.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_top = 8
	h.offset_right = -10
	h.offset_bottom = -8
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	# значок крупный и по центру своей рамки; кнопка растёт по содержимому (крупный шрифт не вылезает)
	var ib := PanelContainer.new()
	var ibs := UI.box(Color(0, 0, 0, 0.28), 6)
	ibs.set_content_margin_all(4)
	ib.add_theme_stylebox_override("panel", ibs)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := UI.building_icon(id, 76)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ib.add_child(ic)
	h.add_child(ib)
	h.minimum_size_changed.connect(func():
		card.custom_minimum_size.y = maxf(UI.fs(96), h.get_combined_minimum_size().y + 16))
	var v := UI.vbox(2)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var n := UI.label(d.get("name", id), 15)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var c := UI.cost_box({}, null, 20)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("bid", id)
	v.add_child(c)
	var pw := float(d.get("params", {}).get("power", 0))
	if d.get("behavior", "") == "hq_link":
		pw = maxf(pw, float(Factory.link_cfg().get("power_min", pw)))   # 1.1.20 A14-8: канал штаба ест столько, сколько в правиле
	if pw > 0 and d.get("behavior", "") != "hq" and d.get("behavior", "") != "generator":
		v.add_child(UI.label("⚡ потребляет %d" % int(pw), 12, Color(1, 0.85, 0.3)))
	elif d.get("behavior", "") == "generator":
		v.add_child(UI.label("⚡ даёт %d" % int(pw), 12, Color(0.5, 1, 0.6)))
	var pm := float(d.get("params", {}).get("per_min", 0))
	var tier := int(d.get("params", {}).get("tier", 0))
	if pm > 0 or tier > 0:
		var tl := UI.label(("Mk%d" % tier if tier > 0 else "") + ("  ·  %d %s" % [int(pm), DB.tx("per_min", "в минуту")] if pm > 0 else ""), 12, Color(0.6, 0.8, 1.0))
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tl)
	if not scan_miss.is_empty():
		var lr := UI.hbox(5)
		lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var li := LockIcon.new()
		li.custom_minimum_size = Vector2(14, 16)
		li.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lr.add_child(li)
		var unk := scan_miss.filter(func(k): return not DB.is_known(k)).size()
		var nm := scan_miss.filter(func(k): return DB.is_known(k)).map(func(k): return DB.item_name(k))
		var txt := "Не изучено в сканере: %d %s" % [scan_miss.size(), plural(scan_miss.size(), "ресурс", "ресурса", "ресурсов")]
		if not nm.is_empty():
			txt += " — " + ", ".join(nm)
		if unk > 0:
			txt += (", " if not nm.is_empty() else " — ") + ("ещё не найден" if unk == 1 else "ещё не найдено: %d" % unk)
		var ll := UI.label(txt, 12, Color(1.0, 0.78, 0.45))
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size = Vector2(UI.ws(200), 0)
		ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lr.add_child(ll)
		v.add_child(lr)
	card.set_meta("cost_lbl", c)
	_card_cost(c, id)
	return card


func _card_cost(c: Control, id: String) -> void:
	var cost: Dictionary = DB.building(id).get("cost", {})
	var sig := "%s|%s" % [cost, cost.keys().map(func(k): return game.factory.available(k))]
	if c.get_meta("sig", "") == sig:
		return
	c.set_meta("sig", sig)
	UI.fill_cost(c, cost, func(k): return game.factory.available(k), 20, " (у героя и в штабе)")


func _update_build_costs() -> void:
	for n in windows.build.find_children("*", "HFlowContainer", true, false):
		if n.has_meta("bid"):
			_card_cost(n, n.get_meta("bid"))


# ---------------------------------------------------------------- окно здания

var _auto_inv := false   # инвентарь открыт вместе с окном здания — закроется вместе с ним

func open_building(b) -> void:
	bld = b
	windows.building.set_meta("built_for", null)
	open("building")
	_with_inventory()


## Окно здания или станции открывает рядом и инвентарь (правило «Инвентарь вместе со зданием»).
## 1.7: текст, который то длиннее, то короче, не дёргает окно: высота только растёт, пока окно открыто.
func _steady(l: Control) -> void:
	# 1.1.9: пока ширина не установилась, замер врёт (по слову в строке) — не мерить
	if l.size.x < 60.0:
		return
	var h := 0.0
	if l is RichTextLabel:
		h = (l as RichTextLabel).get_content_height()
	else:
		h = l.get_combined_minimum_size().y
	var now := Time.get_ticks_msec()
	if h > l.custom_minimum_size.y:
		l.custom_minimum_size.y = h
		l.set_meta("small_ms", -1)
	elif h < l.custom_minimum_size.y - 2.0:
		# текст стал короче: сжать, но не сразу — только если держится 4 с (иначе окно «дышит» каждую секунду)
		var since := int(l.get_meta("small_ms", -1))
		if since < 0:
			l.set_meta("small_ms", now)
		elif now - since > 4000:
			l.custom_minimum_size.y = h
			l.set_meta("small_ms", -1)
	else:
		l.set_meta("small_ms", -1)


func _with_inventory() -> void:
	if bld != null and bld.inv == null and bld.out == null and bld.fuel == null and bld.subs.is_empty():
		return   # нечего перекладывать (станция дронов, фонарь…) — рюкзак не нужен
	if bool(DB.setting("auto_inventory", true)) and not is_open("inventory"):
		_auto_inv = true
		open("inventory")


## Герой отошёл от здания дальше «Окно закрывается, если отойти» — окно закрывается само.
func _too_far(b) -> bool:
	var lim := float(DB.setting("ui_close_dist", 10.0))
	if lim <= 0.0 or b == null or not is_instance_valid(game.player) or game.strategy:
		return false
	return World.dist(game.player.position, b.center()) > lim + b.size * World.C * 0.5


func _refresh_building() -> void:
	var w: Win = windows.building
	if bld == null or bld.dead:
		w.visible = false
		bld = null
		return
	if _too_far(bld):
		close("building")
		return
	var d := DB.building(bld.type)
	w.title_lbl.text = Lang.t(game.factory.fz.title(bld)).to_upper()   # A-6 r4
	if not w.has_meta("built_for") or w.get_meta("built_for") != bld:
		w.set_meta("built_for", bld)
		_build_building_body(w)
	var st: RichTextLabel = w.get_meta("status")
	st.text = _building_status(bld).trim_prefix("Прочность: %d / %d\n" % [int(bld.hp), int(bld.maxhp)]).trim_prefix("Прочность: %d / %d" % [int(bld.hp), int(bld.maxhp)])
	if game.defense and bld.p("defense", "") != "":
		st.text += ("\n" if st.text != "" else "") + game.defense.info(bld)
	if Builders18.is_bay(bld) and game.builders:
		st.text += ("\n" if st.text != "" else "") + game.builders.info(bld)
	if bld.type == "drone_port":
		st.text += "\nГрузоподъёмность: %d ед. · %s" % [game.carriers.fleet_capacity(bld), "рейс выполняется" if game.carriers.airborne(bld) else "на площадке"]
	_steady(st)
	if w.has_meta("tune_ui") and Tuning.kind_of(bld) != "":
		(w.get_meta("tune_ui") as RichTextLabel).text = Tuning.info(bld)
	if w.has_meta("ufo_ui") and Starworks.is_pad(bld):
		(w.get_meta("ufo_ui") as Label).text = game.star.eta_text(bld) + " · на счету у НЛО: %d" % int(Starworks.st(bld).balance)
	if w.has_meta("mega_ui") and Starworks.is_mega(bld):
		(w.get_meta("mega_ui") as RichTextLabel).text = game.star.mega_text(bld)
	if w.has_meta("reactor_ui") and Nuclear.is_reactor(bld):
		var ru: Array = w.get_meta("reactor_ui")
		var rs := Nuclear.st(bld)
		ru[0].text = Nuclear.info(bld)
		ru[1].value = float(rs.T)
		ru[1].modulate = Color(0.5, 1, 0.5) if float(rs.T) < float(Nuclear.c("warn_t", 500.0)) else (Color(1, 0.85, 0.3) if float(rs.T) < float(Nuclear.c("crit_t", 800.0)) else Color(1, 0.35, 0.3))
		ru[2].value = float(rs.water)
	if w.has_meta("drone_ui"):
		for du in w.get_meta("drone_ui"):
			var dd: Dictionary = du[0]
			du[1].text = Drones.state_text(dd)
			du[2].value = dd.bat / Drones.battery() * 100.0
			du[3].value = dd.hp / float(Drones.c("hp", 60.0)) * 100.0 if dd.state != "dead" else 0.0
	var hpb: ProgressBar = w.get_meta("hp_bar")
	hpb.max_value = bld.maxhp
	hpb.value = bld.hp
	(w.get_meta("hp_lbl") as Label).text = "%d / %d" % [int(bld.hp), int(bld.maxhp)]
	if w.has_meta("recipe_box") and bld.beh == "crafter":
		_recipe_preview(w)
	for s in bld_slots:
		s.refresh()
	if w.has_meta("zone_btn") and is_instance_valid(w.get_meta("zone_btn")):
		var zb: Button = w.get_meta("zone_btn")
		var zwhy: String = game.zone.can_expand()
		zb.disabled = zwhy != ""
		zb.tooltip_text = zwhy
		var zcd: float = game.zone.cooldown_left()
		zb.text = "Расширить зону" + (" (через %d с)" % ceili(zcd) if zcd > 0.0 and not Net.is_client() else "")
	var pb: ProgressBar = w.get_meta("prog")
	pb.visible = bld.beh in ["crafter", "miner"] or (bld.blk and not Blocks.find(bld.type, "convert").is_empty())
	if bld.beh == "crafter" or bld.blk:
		pb.value = bld.prog * 100.0
	elif bld.beh == "miner":
		pb.value = bld.timer / maxf(0.1, game.factory.miner_period(bld)) * 100.0   # A16-7


## Окно штаба: размер открытой зоны и кнопка «Расширить» (13.10). Цены — «Настройки» → «Зона и буря».
func _zone_panel(w: Win) -> Control:
	var z = game.zone
	var pnl := UI.panel(0.35)
	var v := UI.vbox(6)
	pnl.add_child(v)
	v.add_child(UI.label("Зона: %d×%d блоков (%d×%d м)" % [z.blocks, z.blocks, int(z.blocks * z.block_m()), int(z.blocks * z.block_m())], 15, UI.ACCENT))
	if z.blocks >= z.max_blocks():
		v.add_child(UI.small("Зона максимальная."))
		return pnl
	v.add_child(UI.small("Расширить до %d×%d — буря отступит на %d м во все стороны:" % [z.blocks + 1, z.blocks + 1, int(z.block_m() * 0.5)]))
	v.add_child(UI.cost_box(z.next_cost(), func(k): return game.factory.available(k), 22, " у героя и в штабе"))
	var why: String = z.can_expand()
	var btn := UI.button("Расширить зону", func():
		game.cmd("zone_expand", {})
		_build_building_body(w), why)
	btn.disabled = why != ""
	v.add_child(btn)
	w.set_meta("zone_btn", btn)   # 1.1.15: кнопка оживает сама, когда пройдёт минута паузы
	if bool(z.cfg().get("patches", true)):
		# 15.5: участок по выбору игрока
		v.add_child(UI.small("Или откройте участок %d×%d блоков там, где нужно (у края открытой земли):" % [z.patch_n(), z.patch_n()]))
		v.add_child(UI.cost_box(z.patch_cost(), func(k): return game.factory.available(k), 22, " у героя и в штабе"))
		v.add_child(UI.button("Выбрать участок на карте", func():
			close_all()
			game.ui_action("zone_pick"), "Наведите рамку на тучи и щёлкните ЛКМ. ПКМ или Esc — отмена"))
	return pnl


func _cargo_controls(w: Win) -> void:
	if bld.type not in ["drone_port", "drone_dock"]:
		return
	var channel := SpinBox.new()
	channel.min_value = 1
	channel.max_value = 99
	var current := str(bld.cfg.get("cargo_channel", "A"))
	channel.value = 1 if current == "A" else float(current)
	var row := UI.hbox(8)
	row.add_child(UI.label("Канал доставки"))
	row.add_child(channel)
	channel.value_changed.connect(func(value): bld.cfg["cargo_channel"] = "A" if int(value) == 1 else str(int(value)))
	w.body.add_child(row)
	if bld.type == "drone_dock":
		var priority := SpinBox.new()
		priority.max_value = 9
		priority.value = int(bld.cfg.get("cargo_priority", 0))
		var pref := UI.hbox(8)
		pref.add_child(UI.label("Приоритет приёма · 0–9"))
		pref.add_child(priority)
		priority.value_changed.connect(func(n): bld.cfg["cargo_priority"] = int(n))
		w.body.add_child(pref)
		return
	var counts: Array = game.carriers.fleet(bld)
	var sizes: Array = DB.setting("cargo_capacities", [10, 20, 35, 60, 100])
	var batch := SpinBox.new()
	batch.min_value = 1
	batch.max_value = 1000000
	batch.allow_greater = true
	batch.value = 1
	var quantity := UI.hbox(8)
	quantity.add_child(UI.label("Назначить из штаба или рюкзака"))
	quantity.add_child(batch)
	w.body.add_child(quantity)
	for tier in 5:
		var i := tier
		var btn := UI.button("L%d · %d шт. · %d ед./рейс" % [i + 1, int(counts[i]), int(sizes[i])], func():
			if game.carriers.assign(bld, i, int(batch.value)) == 0:
				game.notify("Сначала соберите дрон этого уровня в мастерской", Color.ORANGE)
			else:
				w.remove_meta("built_for")
				_refresh_building())
		var fleet_row := UI.hbox(8)
		fleet_row.add_child(btn)
		var back := UI.button("Отозвать", func():
			if game.carriers.recall(bld, i, int(batch.value)) > 0:
				w.remove_meta("built_for")
				_refresh_building())
		back.disabled = game.carriers.airborne(bld) or int(counts[i]) <= (1 if i == 0 else 0)
		back.tooltip_text = "Дополнительные дроны возвращаются после завершения рейса"
		fleet_row.add_child(back)
		w.body.add_child(fleet_row)
	var filter := OptionButton.new()
	filter.add_item("Груз любого типа")
	filter.set_item_metadata(0, "")
	for key in DB.data.items:
		if not DB.is_fluid(key):
			filter.add_item(DB.item_name(key))
			filter.set_item_metadata(filter.item_count - 1, key)
			if key == bld.cfg.get("cargo_filter", ""):
				filter.select(filter.item_count - 1)
	filter.item_selected.connect(func(i): bld.cfg["cargo_filter"] = filter.get_item_metadata(i))
	w.body.add_child(filter)


func _build_building_body(w: Win) -> void:
	UI.clear(w.body)
	bld_slots.clear()
	var d := DB.building(bld.type)
	# шапка: иконка здания, описание, прочность и состояние
	var top := UI.hbox(14)
	var icp := UI.panel(0.5)
	icp.add_child(UI.building_icon(bld.type, 76))
	icp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(icp)
	var tv := UI.vbox(5)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var desc := UI.small(d.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(380, 0)
	tv.add_child(desc)
	if str(d.get("explain", "")) != "":
		# 1.1.8: подробное «как это работает» у особых зданий
		var ex := UI.rich("[color=#9fd8ff]Как это работает:[/color] " + str(d.explain), 13)
		ex.fit_content = true
		ex.custom_minimum_size = Vector2(380, 0)
		tv.add_child(ex)
	var hp_row := UI.hbox(8)
	hp_row.add_child(UI.label("♥", 14, UI.GOOD))
	var hpb := UI.bar(hp_row, Color(0.35, 0.85, 0.45), 10)
	hpb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hpb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hpl := UI.label("", 12, UI.DIM)
	hp_row.add_child(hpl)
	tv.add_child(hp_row)
	w.set_meta("hp_bar", hpb)
	w.set_meta("hp_lbl", hpl)
	var st := UI.rich("", 14)
	tv.add_child(st)
	w.set_meta("status", st)
	top.add_child(tv)
	w.body.add_child(top)
	_cargo_controls(w)
	_clock_panel(w)
	_fusion_panel(w)
	_drone_panel(w)
	_reactor_panel(w)
	_tuning_panel(w)
	_ufo_panel(w)
	_pattern_panel(w)
	if bld.type == "ruin_arch" and bld.bstate.has("cave_type") and DB.setting("cave_expeditions_enabled", false):
		w.body.add_child(UI.button("Войти в пещеру", func(): game.enter_cave(bld)))
	if bld.type == "research_lab":
		w.body.add_child(UI.button("Открыть исследования", func():
			tech_tab = 2
			open("tech")))
	_mega_panel(w)
	_link_panel(w)
	if game.coop:
		game.coop.building_panel(self, w, bld)   # 16: владелец, рынок игрока, энергия, надпись, краска
	var pb := UI.bar(null, UI.ACCENT, 8)
	w.set_meta("prog", pb)
	if bld.beh == "hq" and game.zone and game.zone.on():
		w.body.add_child(_zone_panel(w))
	if bld.beh == "crafter":
		var row := UI.hbox()
		row.add_child(UI.label("Рецепт:", 14))
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.add_item("Авто (по входящему сырью)")
		ob.set_item_metadata(0, "")
		var ids := DB.recipes_for(bld.p("station", ""))
		for i in ids.size():
			ob.add_item(_recipe_line(ids[i]))
			ob.set_item_metadata(i + 1, ids[i])
			if ids[i] == bld.recipe:
				ob.select(i + 1)
		ob.item_selected.connect(func(i): game.cmd("recipe", {"b": bld, "rid": ob.get_item_metadata(i)}))
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ob)
		w.body.add_child(row)
		var rb := UI.hbox(8)
		w.body.add_child(rb)
		w.set_meta("recipe_box", rb)
		w.set_meta("recipe_sig", "")
	if bld.p("smart", false) and bld.beh == "splitter":
		_smart_splitter_ui(w.body)
	elif bld.p("smart", false) and bld.beh == "merger":
		_smart_merger_ui(w.body)
	elif bld.beh in ["splitter", "merger"]:
		w.body.add_child(UI.small("Обычный: делит или собирает поток по очереди. Умный — с фильтрами и приоритетами."))
	var flow_row: HBoxContainer = null
	if bld.inv != null and bld.out != null:
		# вход → полоса работы → выход в одну строку
		flow_row = UI.hbox(12)
		w.body.add_child(flow_row)
	elif pb.get_parent() == null:
		w.body.add_child(pb)
	for pair in [["Вход", bld.inv], ["Топливо", bld.fuel], ["Выход", bld.out]]:
		var inv: Inventory = pair[1]
		if inv == null:
			continue
		var name: String = pair[0]
		if bld.beh in ["storage", "hq"]:
			name = "Содержимое"
		var holder: VBoxContainer = w.body
		if flow_row != null and inv != bld.fuel:
			holder = UI.vbox(4)
			flow_row.add_child(holder)
			if inv == bld.inv:
				var mid := UI.vbox(2)
				mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				mid.custom_minimum_size = Vector2(90, 0)
				var arrow := UI.label("➜", 26, UI.ACCENT)
				arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				mid.add_child(arrow)
				mid.add_child(pb)
				flow_row.add_child(mid)
				flow_row.move_child(mid, flow_row.get_child_count() - 1)
		holder.add_child(UI.section(name))
		var g := GridContainer.new()
		g.columns = 10 if inv.size() > 8 else max(4, inv.size())
		g.add_theme_constant_override("h_separation", 4)
		g.add_theme_constant_override("v_separation", 4)
		for i in inv.size():
			var s := Slot.new()
			s.setup(inv, i, self, 46)
			g.add_child(s)
			bld_slots.append(s)
		if flow_row != null and inv != bld.fuel:
			g.columns = mini(3, inv.size())
		if inv.size() > 30:
			var sc := ScrollContainer.new()
			sc.custom_minimum_size = Vector2(0, 260)
			sc.add_child(g)
			holder.add_child(sc)
		else:
			holder.add_child(g)
	if bld.beh == "generator" and bld.fuel != null:
		_fuel_table(w.body, bld)
	if game.factory.is_electric(bld):
		_power_panel(w)
	if bld.p("quantum_portal", false) and game.quantum != null:
		# 21: квантовый портал — состояние жил и возврат в суперпозицию
		var Q = game.quantum
		var open_now: bool = Q.is_open()
		var seen := 0
		for vid in Q.veins:
			if str(Q.veins[vid].item) != "":
				seen += 1
		w.body.add_child(UI.label(("Портал открыт" if open_now else "Портал закрыт — нужна энергия") + " · жил: %d, схлопнулось: %d" % [Q.veins.size(), seen], 15))
		w.body.add_child(UI.label("Жила в суперпозиции не добывается. Подойдите и посмотрите на неё — она выберет, чем стать. Тени двигаются, только пока на них не смотрят.", 13))
		w.body.add_child(UI.button("Вернуть свободные жилы в суперпозицию (осколок за жилу)", func():
			Q.reset_free()
			refresh_open()))
	if bld.p("entangled", false) and game.quantum != null:
		var pt = game.quantum.partner(bld)
		w.body.add_child(UI.label("Запутан с парой: " + ("%s (клетка %d, %d)" % [DB.building(pt.type).get("name", pt.type), pt.cell.x, pt.cell.y] if pt != null else "пары пока нет — поставьте второй такой же"), 14))
	if bld.p("teleport", false):
		var tb2 = bld
		w.body.add_child(UI.button("Перенестись к следующему телепорту", func():
			var to = game.next_teleporter(tb2)
			if to == null:
				game.notify("Нужен второй телепорт", Color(1, 0.8, 0.5))
			else:
				close("building")
				game.teleport_player(to.center() + Vector3(0, 0, to.size * World.C * 0.5 + 1.2))
				game.fx.magic(game.player.position, Color(0.5, 0.8, 1.0))))
	if (bld.inv != null or bld.out != null) and not bld.beh in ["splitter", "merger"]:
		# метка для дронов по маршруту (блок «route»): «со склада А на склад Б»
		var tag_row := UI.hbox(8)
		tag_row.add_child(UI.label("Метка для дронов:", 14))
		var te := LineEdit.new()
		te.placeholder_text = "например, А или руда"
		te.text = str(bld.cfg.get("tag", ""))
		te.custom_minimum_size = Vector2(160, 0)
		te.tooltip_text = "Дроны по маршруту возят отсюда или сюда, если в шаге маршрута указана эта метка"
		var tb = bld
		var set_tag := func(t: String):
			var c: Dictionary = tb.cfg.duplicate(true)
			if t.strip_edges() == "":
				c.erase("tag")
			else:
				c["tag"] = t.strip_edges()
			if c != tb.cfg:
				game.cmd("bcfg", {"b": tb, "cfg": c})
		te.text_submitted.connect(func(t): set_tag.call(t); te.release_focus())
		te.focus_exited.connect(func(): set_tag.call(te.text))
		tag_row.add_child(te)
		w.body.add_child(tag_row)
	var row2 := UI.hbox()
	if bld.out != null and bool(DB.setting("take_ready_button", true)):
		row2.add_child(UI.button(DB.tx("take_ready", "Забрать готовое"), func(): game.cmd("take_ready", {"b": bld}), DB.tx("take_ready_tip", "Только готовые предметы — в инвентарь героя. Сырьё и топливо остаются в здании")))
	if (bld.inv != null or bld.out != null) and (bld.out == null or bool(DB.setting("take_all_button", true))):
		row2.add_child(UI.button(DB.tx("take_all", "Забрать всё"), func(): game.cmd("take", {"b": bld}), DB.tx("take_all_tip", "Всё из здания, вместе с сырьём, — в инвентарь героя")))
	if bld.beh in ["crafter", "storage", "hq", "generator"] or (bld.beh == "turret" and bld.inv != null) or (bld.blk and (bld.inv != null or bld.fuel != null)):
		row2.add_child(UI.button("Положить", func(): game.cmd("put_all", {"b": bld}), "Положить из инвентаря всё, что подходит зданию"))
	if game.factory.is_pipe(bld):
		row2.add_child(UI.button("Слить жидкость", func(): game.cmd("drain", {"b": bld}), "Вылить всё из этой сети труб, чтобы пустить по ней другую жидкость"))
	if bld.beh == "station":
		row2.add_child(UI.button("Открыть крафт", func(): station = bld.p("station", "hand"); open("craft")))
	if bld.hp < bld.maxhp:
		row2.add_child(UI.small(tr("ПКМ (держать %d с) по зданию или развалинам — ремонт за полцены") % int(round(float(DB.setting("repair111", {}).get("time", 5.0))))))   # 1.1.20 A14-5
	w.body.add_child(row2)
	w.reset_size()


## Трубы: что течёт, сколько в сети, сколько проходит в минуту.
func _fluid_status(b) -> String:
	var fi: Dictionary = game.factory.fluid_info(b)
	if fi.is_empty():
		return "\n[color=#ffb14a]Не подключено к трубам[/color]" if game.factory.pipe_end(b) else ""
	var what := "[b]%s[/b]" % DB.item_name(fi.fluid) if fi.fluid != "" else "пусто"
	var t := "\nТрубы: %s · в сети %d / %d · течёт %d в минуту (максимум %d)" % [what, int(fi.amt), int(fi.cap), int(fi.flow), int(fi.rate)]
	t += "\nТруб и баков: %d · машин подключено: %d" % [fi.pipes, fi.ends]
	if fi.nets > 1:
		t += "\nПодключено сетей труб: %d" % fi.nets
	if game.factory.pipe_end(b):
		t += "\n[color=#9aa3ad]Жидкость выходит в трубу у передней стороны (стрелка), сырьё и топливо входят с остальных сторон[/color]" if b.beh == "crafter" else ""
	return t


## Энергосеть здания: выработка, потребление, запас, график, провода и рубильник.
func _power_panel(w: Win) -> void:
	var box := UI.vbox(4)
	w.body.add_child(UI.small(DB.tx("power_net", "Энергосеть")))
	var row := UI.hbox(10)
	var g := PowerGraph.new()
	g.custom_minimum_size = Vector2(240, 70)
	g.hud = self
	row.add_child(g)
	var lbl := UI.rich("", 13)
	lbl.custom_minimum_size = Vector2(220, 70)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	box.add_child(row)
	var r2 := UI.hbox(6)
	var rb := UI.button(DB.tx("net_reset", "Включить сеть (рубильник)"), func(): game.cmd("reset_net", {"b": bld}), DB.tx("net_reset_tip", "Сеть выключилась от перегрузки. Сначала добавьте генераторы или уберите лишние машины, иначе её выбьет снова"))
	r2.add_child(rb)
	if game.factory.stations_mode():
		r2.add_child(UI.button(DB.tx("pv_tool", "Карта энергии (V)"), func(): close_all(); game.ui_action("wire"), DB.tx("pv_tool_tip", "Показать круги станций и здания без энергии")))
	if game.factory.wired():
		r2.add_child(UI.button(DB.tx("w_tool", "Провода (V)"), func(): close_all(); game.ui_action("wire"), DB.tx("w_tool_tip", "Тянуть провода мышью от здания к зданию")))
		r2.add_child(UI.button(DB.tx("w_cut", "Снять провода"), func(): game.cmd("unwire", {"b": bld}), DB.tx("w_cut_tip", "Отключить это здание от всех проводов")))
	box.add_child(r2)
	w.body.add_child(box)
	g.set_meta("lbl", lbl)
	g.set_meta("reset", rb)


## Что сейчас делает машина: «[руда] 1 → [слиток] 1», или все варианты в режиме «Авто».
func _recipe_preview(w: Win) -> void:
	var rid: String = bld.crafting if bld.crafting != "" else bld.recipe
	var sig := "%s|%s" % [rid, bld.p("station", "")]
	if w.get_meta("recipe_sig", "") == sig:
		return
	w.set_meta("recipe_sig", sig)
	var rb: HBoxContainer = w.get_meta("recipe_box")
	UI.clear(rb)
	if rid != "" and DB.data.recipes.has(rid):
		var r: Dictionary = DB.data.recipes[rid]
		rb.add_child(UI.cost_box(r.get("in", {}), null, 26))
		rb.add_child(UI.label("→", 18, UI.ACCENT))
		rb.add_child(UI.cost_box(r.get("out", {}), null, 26))
		rb.add_child(UI.label("⏱ %.1f с" % float(r.get("time", 1)), 13, UI.DIM))
	else:
		rb.add_child(UI.small("Сам выберет рецепт по сырью. Умеет делать:"))
		var outs := {}
		for id in DB.recipes_for(bld.p("station", "")):
			for o in DB.data.recipes[id].get("out", {}):
				outs[o] = 1
		var f := UI.cost_box(outs, null, 24)
		for chip in f.get_children():
			if chip.get_child_count() > 1:
				(chip.get_child(1) as Label).text = DB.item_name(chip.get_meta("id", "")) if chip.has_meta("id") else (chip.get_child(1) as Label).text.trim_suffix(" ×1")
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.add_child(f)


## Сколько секунд горит каждое топливо в этом здании (с иконками, лучшее — первым).
func _fuel_table(body: Control, b) -> void:
	var list: Array = []
	var fl = b.p("fuels", [])
	var ids: Array = fl if fl is Array and not fl.is_empty() else DB.data.items.keys()
	for id in ids:
		if DB.data.items.has(id) and game.factory.fuel_ok(b, id):
			list.append(id)
	if list.is_empty():
		return
	list.sort_custom(func(x, y): return game.factory.burn_time(b, x) > game.factory.burn_time(b, y))
	body.add_child(UI.small("Сколько горит одна штука (электричество: %d)" % int(b.p("power", 0))))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 12)
	for id in list:
		var chip := UI.hbox(4)
		chip.add_child(UI.item_icon(id, 22))
		var have: int = game.player.inv.count(id)
		var l := UI.label("%s %d с" % [DB.item_name(id), int(game.factory.burn_time(b, id))], 13, UI.TEXT if have > 0 else UI.DIM)
		chip.add_child(l)
		chip.tooltip_text = "%s\nВ рюкзаке: %d" % [UI.item_tip(id), have]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		f.add_child(chip)
	body.add_child(f)


const OUT_NAMES := {0: "Вперёд", 3: "Влево", 1: "Вправо"}
const OUT_MODES := [["any", "Любое"], ["items", "Только выбранное"], ["rest", "Всё остальное"], ["overflow", "Лишнее (если другие заняты)"], ["none", "Закрыт"]]


## Окно умного разделителя (21): что едет по ленте — и куда каждый предмет отправить.
## Предмет, назначенный выходу, идёт только туда (ждёт, если там занято); остальные — в свободные выходы.
func _smart_splitter_ui(body: VBoxContainer) -> void:
	var b = bld
	var cfg: Dictionary = b.cfg.duplicate(true)
	if not cfg.has("outs"):
		cfg["outs"] = {}
	for rel in [0, 3, 1]:
		if not cfg.outs.has(str(rel)):
			cfg.outs[str(rel)] = {"mode": "any", "items": []}
	var save := func(): game.cmd("bcfg", {"b": b, "cfg": cfg.duplicate(true)})
	body.add_child(UI.small("Нажмите стрелку у предмета — он поедет только в этот выход. Что не назначено, идёт в свободные выходы."))
	var list := UI.vbox(4)
	body.add_child(list)
	var shown := []
	var rd := [null]   # лямбды захватывают значения — держим перерисовку в массиве
	# куда назначен предмет: rel или -1
	var where := func(id: String) -> int:
		for rel in [0, 3, 1]:
			var m: Dictionary = cfg.outs[str(rel)]
			if str(m.get("mode", "")) == "items" and id in m.get("items", []):
				return rel
		return -1
	var assign := func(id: String, rel: int):
		for r in [0, 3, 1]:
			var m: Dictionary = cfg.outs[str(r)]
			var its: Array = m.get("items", []).duplicate()
			its.erase(id)
			m["items"] = its
			if its.is_empty() and str(m.get("mode", "")) == "items":
				m["mode"] = "any"
		if rel >= 0:
			var m2: Dictionary = cfg.outs[str(rel)]
			var its2: Array = m2.get("items", []).duplicate()
			its2.append(id)
			m2["items"] = its2
			m2["mode"] = "items"
		save.call()
	rd[0] = func():
		UI.clear(list)
		var ids: Array = []
		for id in b.bstate.get("seen", {}):
			if not id in ids:
				ids.append(id)
		for rel in [0, 3, 1]:
			for id in cfg.outs[str(rel)].get("items", []):
				if not id in ids:
					ids.append(id)
		for id in shown:
			if not id in ids:
				ids.append(id)
		if ids.is_empty():
			list.add_child(UI.small("Пока по ленте ничего не ехало — добавьте предмет поиском ниже."))
		for id in ids:
			var row := UI.hbox(6)
			row.add_child(UI.item_icon(id, 28))
			var nl := UI.label(DB.item_name(id), 14)
			nl.custom_minimum_size = Vector2(150, 0)
			row.add_child(nl)
			var cur: int = where.call(id)
			for opt in [[3, "← Влево"], [0, "↑ Прямо"], [1, "Вправо →"], [-1, "Любой"]]:
				var on: bool = cur == opt[0]
				var bt := UI.button(("● " if on else "") + opt[1], func():
					assign.call(id, opt[0])
					rd[0].call())
				if on:
					bt.modulate = Color(1.0, 0.85, 0.35)
				row.add_child(bt)
			list.add_child(row)
	rd[0].call()
	# поиск предмета, которого ещё не было на ленте
	var srow := UI.hbox(6)
	var le := LineEdit.new()
	le.placeholder_text = "Найти предмет…"
	le.custom_minimum_size = Vector2(200, 0)
	srow.add_child(le)
	var found := UI.hbox(4)
	srow.add_child(found)
	body.add_child(srow)
	le.text_changed.connect(func(q: String):
		UI.clear(found)
		q = q.strip_edges().to_lower()
		if q.length() < 2:
			return
		var n := 0
		for id in DB.data.items:
			if n >= 6:
				break
			if DB.item_name(id).to_lower().contains(q):
				n += 1
				var id2: String = id
				found.add_child(UI.button(DB.item_name(id2), func():
					if not id2 in shown:
						shown.append(id2)
					le.text = ""
					UI.clear(found)
					rd[0].call())))
	# выходы целиком: открыт / только лишнее / закрыт
	var orow := UI.hbox(6)
	for rel in [3, 0, 1]:
		var m: Dictionary = cfg.outs[str(rel)]
		orow.add_child(UI.label(OUT_NAMES[rel] + ":", 13))
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		var modes := [["any", "Открыт"], ["overflow", "Только лишнее"], ["none", "Закрыт"]]
		var curm := str(m.get("mode", "any"))
		for i in modes.size():
			ob.add_item(modes[i][1])
			if modes[i][0] == curm or (curm == "items" and i == 0) or (curm == "rest" and i == 0):
				ob.select(i)
		ob.item_selected.connect(func(i):
			if modes[i][0] == "any":
				m["mode"] = "items" if not m.get("items", []).is_empty() else "any"
			else:
				m["mode"] = modes[i][0]
				m["items"] = []
			save.call()
			rd[0].call())
		orow.add_child(ob)
	body.add_child(orow)


## Окно умного соединителя: какой вход главный.
func _smart_merger_ui(body: VBoxContainer) -> void:
	var b = bld
	var row := UI.hbox()
	row.add_child(UI.label("Главный вход:", 14))
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	var opts := [[-1, "Нет — все по очереди"], [2, "Сзади"], [3, "Слева"], [1, "Справа"]]
	for i in opts.size():
		ob.add_item(opts[i][1])
		if int(b.cfg.get("prio", -1)) == opts[i][0]:
			ob.select(i)
	ob.item_selected.connect(func(i): game.cmd("bcfg", {"b": b, "cfg": {"prio": opts[i][0]}}))
	row.add_child(ob)
	body.add_child(row)
	body.add_child(UI.small("Главный вход всегда пропускается первым, остальные — когда на нём пусто."))


func _recipe_line(rid: String) -> String:
	var r: Dictionary = DB.data.recipes.get(rid, {})
	var ins := []
	for k in r.get("in", {}):
		ins.append("%d %s" % [int(r["in"][k]), Lang.t(DB.item_name(k))])
	var outs := []
	for k in r.get("out", {}):
		outs.append("%d %s" % [int(r["out"][k]), Lang.t(DB.item_name(k))])
	return "%s  (%s → %s)" % [Lang.t(str(r.get("name", rid))), ", ".join(ins), ", ".join(outs)]   # A-5 r4: имена переводим до склейки


func _building_status(b) -> String:
	var t := "Прочность: %d / %d" % [int(b.hp), int(b.maxhp)]
	var need := float(b.p("power", 0))
	var f = game.factory
	if not b.subs.is_empty() and b.has_gen and Fusion.role(b) != "power":
		# 15.3: составное со своим генератором — провода не нужны; свободное уходит в сеть, если провод есть
		var free := maxf(0.0, b.cgen - b.cneed)
		t += "\nСвоя энергия: выработка %s · потребление %s · свободно %s" % [Fusion._num(snappedf(b.cgen, 0.1)), Fusion._num(snappedf(b.cneed, 0.1)), Fusion._num(snappedf(free, 0.1))]
		if b.csat < 0.999:
			t += "\n[color=#ffd36b]Своей энергии не хватает: %d%%%s[/color]" % [int(b.csat * 100), " — добирается из сети" if b.net >= 0 else " — подключите провод или встройте ещё генератор"]
		elif free > 0.0 and (b.net >= 0 or f.wired()):   # A16-8: в режиме станций провод не нужен
			t += "\n[color=#7dff9a]%s[/color]" % ("Излишек %s уходит в сеть по проводам" % Fusion._num(snappedf(b.surplus, 0.1)) if b.net >= 0 else "Протяните провод — излишек пойдёт в сеть")
	elif need > 0 and not b.beh in ["generator", "hq"]:
		if b.net < 0:
			if f.stations_mode():
				if b.pw_state == 2:
					t += "\n[color=#ffa040]%s[/color]" % DB.tx("no_power_st2", "Нет энергии: станции рядом не хватило мощности. Поставьте ещё станцию или станцию выше уровнем (V — карта энергии)")
				else:
					t += "\n[color=#ff6b5a]%s[/color]" % DB.tx("no_power_st", "Нет энергии: рядом нет станции энергии. Поставьте станцию так, чтобы здание попало в её круг (V — карта энергии)")
			elif f.wired():
				t += "\n[color=#ff6b5a]%s[/color]" % DB.tx("no_power_w", "Нет энергии: протяните провод от опоры или генератора (клавиша V)")
			else:
				t += "\n[color=#ff6b5a]Нет энергии: поставьте генератор и опоры ЛЭП рядом[/color]"
		else:
			var ni: Dictionary = f.net_info(b)
			t += "\nЭнергия: %d%% (сеть %d / %d)" % [int(ni.sat * 100), int(ni.supply), int(ni.demand)]
			if b.feeder != null:
				t += "\nПитается от: %s" % DB.building(b.feeder.type).get("name", b.feeder.type)
	if need > 0 and not b.beh in ["generator", "hq", "battery"]:
		var k: float = Fusion.power_k(b)
		t += "\nПотребляет: %s ед.%s" % [Fusion._num(need * k), (" (×%s за объединение)" % Fusion._num(k)) if k > 1.0 else ""]
	if not b.subs.is_empty() and Fusion.role(b) != "power":
		t += "\nСборное здание ест всего: %s ед. (своя энергия %d%%)" % [Fusion._num(snappedf(f.fz._need(b), 0.1)), int(b.csat * 100)]
	if b.blk:
		var names := []
		for bl in Blocks.of(b.type):
			var bn := Lang.t(str(Blocks.TYPES.get(str(bl.get("type", "")), bl.get("type", "")))).to_lower()   # A-4 r4: перевод до to_lower
			if not bn in names:
				names.append(bn)
		if not names.is_empty():
			t += "\nУмеет: " + "; ".join(names)
		if not Blocks.find(b.type, "power_gen").is_empty():
			t += "\n%s" % ("Даёт энергию" if b.active else "Не работает: нужно топливо или солнце")
			if b.fuel != null:
				t += " · топливо: %d с" % int(b.fuel_t)
		else:
			t += "\n%s" % ("[color=#7dff5a]Работает[/color]" if b.active else "Ждёт")
	if b.beh in ["miner", "crafter"]:
		var mx: float = f.rate_max(b)
		var tier := int(b.p("tier", 0))
		if mx > 0.0:
			t += "\n%s: [b]%d[/b] / %d %s%s" % [DB.tx("tp_now", "Сейчас"), int(round(f.rate_now(b))), int(round(mx)), DB.tx("per_min", "в минуту"),
				(" · Mk%d" % tier) if tier > 0 else ""]
		var bn: String = f.bottleneck(b)
		if bn != "":
			t += "\n[color=#ffb14a]%s: %s[/color]" % [DB.tx("tp_why", "Мешает"), bn]
		else:
			t += "\n[color=#7dff5a]%s[/color]" % DB.tx("tp_ok", "Работает без помех")   # 1.7: строка есть всегда — окно не прыгает
		# 17.10: мастерство машины и связка с соседями
		var lv := Progress17.level(b)
		var nx := Progress17.next_step(b)
		var syn := float(b.bstate.get("syn", 0.0))
		t += "\n[color=#ffd75a]Мастерство %s[/color] · сделано %d%s%s" % [["0", "I", "II", "III", "IV", "V"][mini(lv, 5)], int(b.bstate.get("crafts", 0)),
			(" из %d до следующего" % nx) if nx > 0 else " (максимум)", (" · [color=#7dffb0]связка +%d%%[/color]" % int(syn * 100.0)) if syn > 0.0 else ""]
	if b.blk and not Blocks.find(b.type, "bmarket").is_empty():
		# 1.1.8: Чёрный рынок — сколько продано и сколько копится
		var bst: Dictionary = b.bstate
		var bmb := Blocks.find(b.type, "bmarket")
		t += "\nПринимает до [b]%d[/b] предметов в минуту · продано: %d · выручка: [color=#ffd36b]%d кр[/color]" % [
			int(bmb.get("per_min", Blocks.econ().get("bm_per_min", 30))), int(bst.get("sold", 0)), int(bst.get("paid", 0))]
		t += "\nКопится до целого кредита: %s кр" % game.fmt_cr(float(bst.get("cr", 0.0)))
		var last := str(bst.get("last", ""))
		var probe: String = last if last != "" else (b.inv.first_item() if b.inv != null else "")
		if probe != "":
			t += "\n%s — %s кр за штуку" % [DB.item_name(probe), game.fmt_cr(Blocks.bm_value(game, probe))]
	if b.beh == "generator" and float(b.p("water_per_min", 0.0)) > 0.0:
		var wv := float(b.bstate.get("water", 0.0))
		t += "\n%sВода: %d (нужно %d в минуту)%s" % ["[color=#ffb14a]" if wv < 1.0 else "", int(wv), int(float(b.p("water_per_min", 0.0))),
			" — подведите трубу от водяного насоса[/color]" if wv < 1.0 else ""]
	match b.beh:
		"miner":
			t += "\nДобывает: [b]%s[/b] · %s" % [DB.item_name(b.recipe), "работает" if b.active else "выход заполнен или нет энергии"]
			var pu: Dictionary = game.world.purity_of(game.factory.miner_cell(b.type, b.cell))
			if not pu.is_empty() and str(b.p("extracts", "solid")) != "fluid":
				t += "\nЗалежь: [color=%s][b]%s[/b][/color] (%d в минуту) × бур %s = [b]%d[/b] в минуту" % [str(pu.get("color", "#ffffff")), str(pu.get("name", "")),
					int(float(pu.get("per_min", 60))), "×%s" % str(snappedf(float(b.p("rate_mult", b.p("tier", 1))), 0.1)), int(round(f.miner_rate(b)))]
		"crafter":
			if b.crafting != "":
				t += "\nДелает: [b]%s[/b]" % DB.data.recipes.get(b.crafting, {}).get("name", b.crafting)
			if b.fuel != null and Fusion.heats_by_power(b):
				t += "\nГреется от встроенной энергии — топливо не нужно"
			elif b.fuel != null:
				t += "\nТопливо: %d с" % int(b.fuel_t)
		"generator":
			var why := DB.tx("need_fuel", "Нужно топливо — положите его в окошко ниже")
			if b.p("solar", false):
				why = DB.tx("wait_sun", "Ждёт солнца")
			elif b.p("wind", false):
				why = DB.tx("wait_wind", "Нет ветра")
			if b.tripped:
				why = DB.tx("is_tripped", "Выбило пробки — нажмите «Включить сеть»")
			t += "\n%s" % ("[color=#7dff5a]%s[/color]" % DB.tx("works", "Работает") if b.active else why)
			if b.p("wind", false):
				t += " · %s %d%%" % [Lang.t(DB.tx("wind", "ветер")), int(game.wind() * 100)]
		"hq":
			t += "\nСклад базы. Отсюда берутся ресурсы на стройку." if Factory.local_ammo() else "\nСклад базы. Отсюда берутся ресурсы на стройку и патроны для турелей."
		"turret":
			var ammo: String = b.p("ammo", "")
			if ammo != "" and b.inv != null:
				t += "\nПатронов в турели: %d · подвозите лентой, через канал штаба или кнопкой «Положить»" % b.inv.count(ammo)
			elif ammo != "":
				t += "\nПатронов в штабе: %d" % (f.hq.inv.count(ammo) if f.hq else 0)
		"hq_link":
			t += "\n%s · энергия %d" % ["Из штаба на ленту" if Factory.link_mode(b) == "take" else "Всё со входа — в штаб", int(b.p("power", 0))]
		"station":
			t += "\nОткройте крафт, чтобы делать предметы этой станции"
	if f.is_pipe(b) or f.pipe_end(b):
		t += _fluid_status(b)
	return t


# ---------------------------------------------------------------- крафт

func _refresh_craft() -> void:
	var w: Win = windows.craft
	if station != "hand" and station_b != null and (station_b.dead or _too_far(station_b)):
		station_b = null
		close("craft")
		return
	var key := "%s|%s|%d|%d|%d" % [station, selected_recipe, DB.revision, DB.locked.size(), Tech.lock_rev]   # 1.1.15: новые рецепты после изучения — сразу
	if w.get_meta("key", "") == key and w.body.get_child_count() > 0:
		for b in w.body.find_children("*", "Button", true, false):
			if b.has_meta("rid"):
				b.disabled = not game.can_craft(b.get_meta("rid"), b.get_meta("n"))
		for f in w.body.find_children("*", "HFlowContainer", true, false):
			if f.has_meta("rin"):
				var sig := str(f.get_meta("rin").keys().map(func(k): return game.player.inv.count(k)))
				if f.get_meta("sig", "") != sig:
					f.set_meta("sig", sig)
					UI.fill_cost(f, f.get_meta("rin"), func(k): return game.player.inv.count(k), 20, " в инвентаре")
		return
	w.set_meta("key", key)
	UI.clear(w.body)
	var names := {"hand": "в руках", "workbench": "верстак", "workshop": "мастерская"}
	var st_nm := func(s0: String) -> String:   # A-9 r4: имя станции из базы (кухня, магазин утилизации), с переводом
		return Lang.t(str(names[s0]) if names.has(s0) else game.station_name(s0))
	w.title_lbl.text = (Lang.t("Производство") + "  /  " + st_nm.call(station)).to_upper()
	var tabs := UI.hbox()
	var near_st: Array = game.near_stations()
	for s in ["hand"] + near_st:
		tabs.add_child(UI.button(str(st_nm.call(s)).left(1).to_upper() + str(st_nm.call(s)).substr(1), func(): station = s; _refresh_craft()))
	# 1.1.18: станции, которые открыты, но далеко или не построены, — серые вкладки с подсказкой (игроки не находили шестерни)
	for sb in ["workbench", "workshop", "kitchen"]:
		if sb in near_st or not DB.data.buildings.has(sb) or Tech.building_locked(sb):
			continue
		var built := false
		for b0 in game.factory.all:
			if b0.type == sb and not b0.dead:
				built = true
				break
		var nm: String = str(st_nm.call(sb))
		var gb := UI.button(nm.left(1).to_upper() + nm.substr(1), func(): pass)
		gb.disabled = true
		var some: Array = DB.recipes_for(sb).slice(0, 5).map(func(r0): return str(DB.data.recipes[r0].get("name", r0)))
		gb.tooltip_text = Lang.t("Подойдите к зданию «%s» — эта вкладка откроется." if built else "Постройте «%s» (B) и подойдите к нему.") % Lang.t(str(DB.building(sb).get("name", sb))) \
			+ ("\n" + Lang.t("Там делают:") + " " + ", ".join(some.map(func(x): return Lang.t(x))) + "…" if not some.is_empty() else "")
		tabs.add_child(gb)
	w.body.add_child(tabs)
	var bench := UI.hbox(16)
	w.body.add_child(bench)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bench.add_child(scroll)
	var list := UI.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	bench.add_child(VSeparator.new())
	var detail := UI.vbox(12)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bench.add_child(detail)
	var rlist := DB.recipes_for(station)
	if selected_recipe not in rlist:
		selected_recipe = "" if rlist.is_empty() else str(rlist[0])
	# 18: сколько рецептов скрыто и что изучить, чтобы они появились (друзья путались: «почему у меня список меньше?»)
	var hid: Dictionary = DB.hidden_by_scan(station)
	if int(hid.n) > 0:
		var names_need: Array = hid.need.keys().map(func(k): return DB.item_name(k))
		names_need.sort()
		var hl := UI.small("Ещё %d рецептов скрыто: сначала изучите сырьё в сканере (%s)%s" % [int(hid.n), Prefs.get_value("key_scan", "I"),
			(": " + ", ".join(names_need.slice(0, 6)) + ("…" if names_need.size() > 6 else "")) if not names_need.is_empty() else " — найдите и отсканируйте новые ресурсы"])
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size = Vector2(UI.ws(540), 0)
		hl.add_theme_color_override("font_color", UI.ACCENT)
		w.body.add_child(hl)
	if rlist.is_empty():
		var em := UI.label("Пока нечего делать.\n" + ("Отсканируйте найденные ресурсы (окно «Сканер», клавиша %s) — тогда появятся рецепты." % Prefs.get_value("key_scan", "I") if DB.discovery else "Для этой станции нет рецептов."), 15, UI.DIM)
		em.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		em.custom_minimum_size = Vector2(UI.ws(560), 120)
		em.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		list.add_child(em)
	for rid in rlist:
		var r: Dictionary = DB.data.recipes[rid]
		var choose := UI.button(str(r.get("name",rid)),func(): selected_recipe = rid; _refresh_craft())
		choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		list.add_child(choose)
		if rid != selected_recipe:
			continue
		choose.add_theme_color_override("font_color",UI.ACCENT)
		var out_id: String = r.get("out", {}).keys()[0] if not r.get("out", {}).is_empty() else ""
		detail.add_child(UI.item_icon(out_id,68))
		detail.add_child(UI.section("Рецептура"))
		var row := UI.vbox(10)
		detail.add_child(row)
		var v := UI.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label("%s ×%d" % [r.get("name", rid), int(r.get("out", {}).get(out_id, 1))], 15))
		var c := UI.cost_box(r.get("in", {}), func(k): return game.player.inv.count(k), 20, " в инвентаре")
		c.set_meta("rin", r.get("in", {}))
		c.add_child(UI.label("⏱ %.1f с" % float(r.get("time", 1)), 13, UI.DIM))
		v.add_child(c)
		detail.tooltip_text = UI.item_tip(out_id)
		row.add_child(v)
		var quantities := HFlowContainer.new()
		row.add_child(quantities)
		var qmax := int(DB.setting("craft_queue_max", 50))
		for n in [1, 5, 20, qmax]:
			# 1.0.8: последняя кнопка «Макс» — ставит в очередь сколько хватит ресурсов (до размера очереди)
			var all: bool = n == qmax
			var b := UI.button("Макс" if all else "×%d" % n, func(): game.cmd("craft", {"rid": rid, "n": n, "station": station}))
			b.set_meta("rid", rid)
			b.set_meta("n", 1 if all else n)
			b.disabled = not game.can_craft(rid, 1 if all else n)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.tooltip_text = ("Поставить в очередь сколько хватит ресурсов, до %d шт." % qmax) if all else "Сделать %d шт.\nВремя: %.1f с" % [n * int(r.get("out", {}).get(out_id, 1)), float(r.get("time", 1)) * n]
			quantities.add_child(b)
	w.body.add_child(UI.small("Нужные предметы берутся из инвентаря героя. Станции (верстак, мастерская) работают, когда вы рядом."))


# ---------------------------------------------------------------- навыки

func _refresh_skills() -> void:
	var w: Win = windows.skills
	# перестраиваем только когда что-то поменялось (иначе пропадают клики)
	var sig := "%d|%d|%d|%d|%s|%s|%d" % [game.level, int(game.xp), game.skill_points, game.attr_points, game.skills, game.attrs, DB.revision]
	if w.get_meta("sig", "") == sig and w.body.get_child_count() > 0:
		return
	w.set_meta("sig", sig)
	UI.clear(w.body)
	w.body.add_child(UI.rich("Уровень [b]%d[/b] · опыт %d / %d · [color=#7fdcff]очков: %d[/color]" % [game.level, int(game.xp), int(game.xp_next()), game.skill_points], 15))
	var xl := UI.small("Опыт даётся за добычу, стройку, крафт и убитых монстров. За уровень — очко навыка и очки характеристик.")
	xl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	xl.custom_minimum_size = Vector2(500, 0)
	w.body.add_child(xl)
	if not DB.data.get("attributes", {}).is_empty():
		w.body.add_child(UI.rich("[b]Характеристики[/b] · [color=#ffd36b]свободных очков: %d[/color]" % game.attr_points, 16))
		var ids: Array = DB.data.attributes.keys()
		ids.sort_custom(func(a, b): return int(DB.data.attributes[a].get("order", 0)) < int(DB.data.attributes[b].get("order", 0)))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		w.body.add_child(grid)
		if game.strategy:
			ids = ids.filter(func(x): return not Strategy.hero_only(DB.data.attributes[x].get("bonus", {})))
		for id in ids:
			var a: Dictionary = DB.data.attributes[id]
			var lv: int = game.attrs.get(id, 0)
			var amx := int(a.get("max", 20))
			var row := UI.hbox(6)
			row.custom_minimum_size = Vector2(380, 0)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var v := UI.vbox(0)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(UI.label("%s  %d / %d" % [a.get("name", id), lv, amx], 15, DB.color(a.get("color", "#ffffff"))))
			var dl := UI.small(a.get("desc", ""))
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.custom_minimum_size = Vector2(320, 0)
			v.add_child(dl)
			row.add_child(v)
			var b := UI.button("+", func(): game.upgrade_attr(id); _refresh_skills(), "Нужно свободное очко характеристик" if game.attr_points <= 0 else ("Максимум" if lv >= amx else "Вложить очко"))
			b.disabled = lv >= amx or game.attr_points <= 0
			b.custom_minimum_size = Vector2(40, 36)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
			grid.add_child(row)
		w.body.add_child(UI.rich("[b]Навыки[/b] · [color=#7fdcff]очков: %d[/color]" % game.skill_points, 16))
	for id in DB.data.skills:
		var s: Dictionary = DB.data.skills[id]
		if game.strategy and Strategy.hero_only(s.get("bonus", {})):
			continue   # 1.1.15: в стратегии нет навыков героя (здоровье, бег…)
		var lvl: int = game.skills.get(id, 0)
		var mx := int(s.get("max", 5))
		var row := UI.hbox(8)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label("%s  [%d/%d]" % [s.get("name", id), lvl, mx], 15))
		v.add_child(UI.small(s.get("desc", "")))
		var pb := UI.bar(v, UI.ACCENT, 6)
		pb.max_value = mx
		pb.value = lvl
		row.add_child(v)
		var b := UI.button("+", func(): game.upgrade_skill(id); _refresh_skills(), "Нужно очко навыка (даётся за новый уровень)" if game.skill_points <= 0 else ("Максимум" if lvl >= mx else "Вложить очко"))
		b.disabled = lvl >= mx or game.skill_points <= 0
		b.custom_minimum_size = Vector2(44, 36)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		w.body.add_child(row)


# ---------------------------------------------------------------- дерево открытий и задания станции

var tech_tab := 0

## 17.10: рекорды производства (награды за 100 / 1000 / 10000 штук) и лучшие машины по мастерству.
func _refresh_records() -> void:
	var w: Win = windows.records
	var P = game.progress17
	var sig := "%s|%d|%s" % [str(P.made.hash()), game.factory.all.size(), str(P.daily.hash())]
	if w.get_meta("sig", "") == sig and w.body.get_child_count() > 0:
		return
	w.set_meta("sig", sig)
	UI.clear(w.body)
	var intro := UI.small("Машины сами копят мастерство (+5% скорости за уровень) и работают быстрее рядом с соседями по цепочке (+10% за каждого, до +20%). За каждые 100 / 1000 / 10000 сделанных штук предмета — награда. Каждый день — «Заказ дня»: машины с этим предметом быстрее на 25%, за план — награда.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(560, 0)
	w.body.add_child(intro)
	var dl: Dictionary = P.daily
	if dl.has("item") and bool(Progress17.dcfg().get("enabled", true)):
		w.body.add_child(UI.title("Заказ дня", 16))
		var dtx := "%s: %d / %d — награда %d" % [DB.item_name(str(dl.item)), mini(int(dl.have), int(dl.need)), int(dl.need), int(dl.get("reward", 0))]
		if bool(dl.get("done", false)):
			dtx += " · выполнен, завтра новый"
		else:
			dtx += " · машины с ним +%d%% скорости" % int(float(Progress17.dcfg().get("speed_bonus", 0.25)) * 100.0)
		w.body.add_child(UI.small(dtx))
		var dpb := ProgressBar.new()
		dpb.max_value = maxi(1, int(dl.need))
		dpb.value = mini(int(dl.have), int(dl.need))
		dpb.custom_minimum_size = Vector2(540, 12)
		dpb.show_percentage = false
		w.body.add_child(dpb)
	w.body.add_child(UI.title("Рекорды производства", 16))
	var rows: Array = P.table()
	if rows.is_empty():
		w.body.add_child(UI.small("Пока ничего не сделано машинами."))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 260)
	w.body.add_child(sc)
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for r in rows.slice(0, 60):
		var h := UI.hbox(8)
		v.add_child(h)
		h.add_child(UI.item_icon(str(r[0]), 22))
		var nm := UI.label("%s — %d" % [DB.item_name(str(r[0])), int(r[1])], 14)
		nm.custom_minimum_size = Vector2(260, 0)
		h.add_child(nm)
		if int(r[2]) > 0:
			var rw: Dictionary = Progress17.reward_of(str(r[0]), int(r[2]))
			var bar := UI.bar(h, Color(0.5, 1.0, 0.7), 10)
			bar.custom_minimum_size = Vector2(120, 10)
			bar.value = 100.0 * float(r[1]) / float(r[2])
			h.add_child(UI.small("до %d: +%d денег%s" % [int(r[2]), int(rw.credits), (", +%d купонов" % int(rw.coupons)) if int(rw.coupons) > 0 else ""]))
		else:
			h.add_child(UI.small("все рекорды взяты"))
	w.body.add_child(UI.title("Лучшие машины", 16))
	var ms := []
	for b in game.factory.machines:
		if not b.dead and int(b.bstate.get("crafts", 0)) > 0:
			ms.append(b)
	ms.sort_custom(func(a, b): return int(a.bstate.get("crafts", 0)) > int(b.bstate.get("crafts", 0)))
	if ms.is_empty():
		w.body.add_child(UI.small("Пока ни одна машина ничего не сделала — поставьте бур или станок."))
	for b in ms.slice(0, 8):
		w.body.add_child(UI.small("%s — мастерство %s, сделано %d%s" % [DB.t(DB.building(b.type).get("name", b.type)), ["0", "I", "II", "III", "IV", "V"][mini(Progress17.level(b), 5)],
			int(b.bstate.get("crafts", 0)), (" · связка +%d%%" % int(float(b.bstate.get("syn", 0.0)) * 100.0)) if float(b.bstate.get("syn", 0.0)) > 0.0 else ""]))


func _refresh_tech() -> void:
	var w: Win = windows.tech
	var T: Tech = game.tech
	var sig := "%d|%d|%s|%s|%s|%d|%d|%s|%s|%d|%d|%d" % [tech_tab, tech_tier, T.done.keys(), T.paid, T.target, T.research, game.credits, T.c_done.keys(), T.c_paid, game.day_n, DB.revision,
		game.enemies.waves_survived + game.factory.all.size()] + ("|d" if contracts_done_show else "")
	if w.get_meta("sig", "") == sig and w.body.get_child_count() > 0:
		return
	w.set_meta("sig", sig)
	UI.clear(w.body)
	var top := UI.hbox(8)
	for i in 3:
		var nm: String = ["Чертежи", "Заказы колонии", "Технологии"][i]
		var b := UI.button(nm, func(): tech_tab = i; _refresh_tech())
		if i == tech_tab:
			b.add_theme_color_override("font_color", UI.theme().get_color("font_pressed_color", "Button"))
			b.add_theme_color_override("font_hover_color", UI.theme().get_color("font_pressed_color", "Button"))
			b.add_theme_stylebox_override("normal", UI.theme().get_stylebox("pressed", "Button"))
			b.add_theme_stylebox_override("hover", UI.theme().get_stylebox("pressed", "Button"))
		top.add_child(b)
	top.add_child(UI.spacer())
	top.add_child(UI.label("Очки исследований: %d" % T.research, 14, Color(0.5, 0.86, 1)))
	top.add_child(UI.label("%d кр" % game.credits, 14, Color(1, 0.83, 0.42)))
	for c in top.get_children():
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	w.body.add_child(top)
	if not T.enabled():
		w.body.add_child(UI.small("Дерево открытий выключено: всё открыто сразу (Правила игры → «Дерево открытий»)."))
		return
	if tech_tab != 1:
		_tech_tree_ui(w.body)
	else:
		_contracts_ui(w.body)


var tech_tier := -1   # 15.1: вкладка этапа (-1 — «Доступно сейчас»)


func _tech_tree_ui(body: VBoxContainer) -> void:
	# 15.1: вкладки по этапам, но изучать можно любой узел — порядок только подсказка
	var T: Tech = game.tech
	var tu: Dictionary = DB.setting("tech_ui", {})
	var free := bool(tu.get("free", true))
	var hint := UI.small((Lang.t("Изучайте в любом порядке: этапы — только подсказка, с чего удобнее начать.") + " " if free else "") + Lang.t("Сдавайте ресурсы в узел: кнопка «Сдать» берёт их со склада штаба, потом из рюкзака. Терминал открытий принимает их и с ленты — для узла со звёздочкой ★."))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(940, 0)
	body.add_child(hint)
	if Tech.demo_max() >= 0:
		var dm := UI.label("ДЕМО-ВЕРСИЯ: открываются этапы 1–%d. %s" % [Tech.demo_max(), Tech.demo_text()], 18, Color(1.0, 0.8, 0.35))
		dm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dm.custom_minimum_size = Vector2(940, 0)
		body.add_child(dm)
	var tiers := {}
	var domain_ids := T.sorted_ids().filter(func(id): return T.research_site(id) == ("tech_terminal" if tech_tab == 0 else "research_lab"))
	for id in domain_ids:
		var t := int(T.nodes()[id].get("tier", 0))
		if not tiers.has(t):
			tiers[t] = []
		tiers[t].append(id)
	var keys: Array = tiers.keys()
	keys.sort()
	if tech_tier != -1 and not tiers.has(tech_tier):
		tech_tier = -1
	var names: Array = tu.get("tier_names", [])
	var columns := UI.hbox(14)
	body.add_child(columns)
	var rail := ScrollContainer.new()
	rail.custom_minimum_size = Vector2(215,390)
	rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(rail)
	var tabs := UI.vbox(4)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_child(tabs)
	tabs.add_child(UI.section("Этапы"))
	var avail: Array = domain_ids.filter(func(i): return T.state(i) == "open")
	var tabs_def: Array = [[-1, "Доступно сейчас (%d)" % avail.size()]]
	for t in keys:
		var dn: int = tiers[t].filter(func(i): return T.state(i) == "done").size()
		var nm := ""
		if t < names.size():
			nm = str(names[t].get("name", "")) if names[t] is Dictionary else str(names[t])
		if nm == "":
			nm = "Начало" if t == 0 else "Этап %d" % t
		tabs_def.append([t, "%s  %d/%d" % [nm, dn, tiers[t].size()]])
	for td in tabs_def:
		var tid: int = td[0]
		var b := UI.button(td[1], func(): tech_tier = tid; _refresh_tech())
		if tid == tech_tier:
			b.add_theme_stylebox_override("normal", UI.theme().get_stylebox("pressed", "Button"))
			b.add_theme_stylebox_override("hover", UI.theme().get_stylebox("pressed", "Button"))
			b.add_theme_color_override("font_color", UI.theme().get_color("font_pressed_color", "Button"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tabs.add_child(b)
	columns.add_child(VSeparator.new())
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0,390)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(sc)
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.custom_minimum_size = Vector2(300, 0)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	var ids: Array = avail if tech_tier == -1 else tiers[tech_tier]
	if ids.is_empty():
		grid.add_child(UI.small("Выберите этап слева, чтобы увидеть чертежи и условия исследования." if tech_tier == -1 else "На этом этапе узлов нет."))
	for id in ids:
		var card := _tech_card(id)
		card.custom_minimum_size = Vector2(300, 0)
		grid.add_child(card)


func _tech_card(id: String) -> Control:
	var T: Tech = game.tech
	var n: Dictionary = T.nodes()[id]
	var st := T.state(id)
	var p := UI.panel(0.95)
	var sb: StyleBoxFlat = UI.theme().get_stylebox("panel", "PanelContainer").duplicate()
	sb.border_color = UI.GOOD if st == "done" else (UI.ACCENT if st == "open" else Color(0.3, 0.33, 0.38))
	sb.set_border_width_all(0)
	sb.border_width_left = 3
	sb.bg_color = Color("#1c3139")
	p.add_theme_stylebox_override("panel", sb)
	var v := UI.vbox(4)
	p.add_child(v)
	var head := UI.hbox(6)
	var ic := str(n.get("icon", ""))
	if DB.data.buildings.has(ic):
		head.add_child(UI.building_icon(ic, 40))
	elif DB.data.items.has(ic):
		head.add_child(UI.item_icon(ic, 40))
	var nm := UI.label(("✔ " if st == "done" else ("★ " if T.target == id else "")) + str(n.get("name", id)), 15, UI.GOOD if st == "done" else (UI.TEXT if st == "open" else UI.DIM))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	v.add_child(head)
	if str(n.get("desc", "")) != "":
		var d := UI.small(str(n.desc))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(270, 0)
		v.add_child(d)
	if st != "done" and bool(DB.setting("tech_ui", {}).get("free", true)):
		var rec := []
		for r in n.get("requires", []):
			if not T.done.has(r) and not bool(T.nodes().get(r, {}).get("start", false)):
				rec.append(str(T.nodes().get(r, {}).get("name", r)))
		if not rec.is_empty():
			var rl := UI.small("Обычно открывают после: " + ", ".join(rec))
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.custom_minimum_size = Vector2(270, 0)
			v.add_child(rl)
	# что откроет
	var u: Dictionary = n.get("unlocks", {})
	var opens := HFlowContainer.new()
	opens.add_theme_constant_override("h_separation", 4)
	for b in u.get("buildings", []):
		if DB.data.buildings.has(b):
			var bi := UI.building_icon(b, 30)
			bi.tooltip_text = "Здание: " + str(DB.building(b).get("name", b))
			opens.add_child(bi)
	for r in u.get("recipes", []):
		var out: Dictionary = DB.data.recipes.get(r, {}).get("out", {})
		for o in out:
			var ii := UI.item_icon(o, 30)
			ii.tooltip_text = "Рецепт: " + str(DB.data.recipes[r].get("name", r))
			opens.add_child(ii)
	for dp in u.get("deposits", []):
		var di := UI.item_icon(dp, 30)
		di.tooltip_text = "Новые залежи на карте: " + DB.item_name(dp)
		opens.add_child(di)
	if opens.get_child_count() > 0:
		v.add_child(UI.small("Откроет:"))
		v.add_child(opens)
	# 1.1.18: где делать то, что откроет узел (раньше «сталь открыл, а где варить — непонятно»)
	var where := []
	for r in u.get("recipes", []):
		var rr: Dictionary = DB.data.recipes.get(r, {})
		if rr.is_empty():
			continue
		var sts := []
		for s0 in rr.get("stations", []):
			sts.append(Lang.t("руками") if s0 == "hand" else "«%s»" % Lang.t(game.station_name(str(s0))))
		where.append("%s — %s" % [Lang.t(str(rr.get("name", r))), ", ".join(sts)])
	if not where.is_empty():
		var wl := UI.small(Lang.t("Где делать:") + "\n" + "\n".join(where.slice(0, 8)) + ("\n…" if where.size() > 8 else ""))
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.custom_minimum_size = Vector2(270, 0)
		v.add_child(wl)
	if st == "done":
		return p
	var cost: Dictionary = n.get("cost", {})
	if not cost.is_empty():
		var pd: Dictionary = T.paid.get(id, {})
		v.add_child(UI.cost_box(cost, func(k): return int(pd.get(k, 0)), 20, " сдано"))
	var extra := []
	if int(n.get("credits", 0)) > 0:
		extra.append("[color=%s]%d кр[/color]" % ["#7dff8c" if game.credits >= int(n.credits) else "#ff6b5a", int(n.credits)])
		if game.credits < int(n.credits):
			# 1.1.8: кредиты зарабатывает Чёрный рынок
			extra.append("[color=#ffb35a]не хватает %d кр — продавайте на Чёрном рынке[/color]" % (int(n.credits) - game.credits))
	if int(n.get("research", 0)) > 0:
		extra.append("[color=%s]%d очков исследований[/color]" % ["#7dff8c" if T.research >= int(n.research) else "#ff6b5a", int(n.research)])
	if not extra.is_empty():
		var xr := UI.rich("Ещё: " + " · ".join(extra), 13)
		xr.custom_minimum_size = Vector2(270, 0)
		v.add_child(xr)
	var why := T.why_not(id)
	if why != "":
		var wl := UI.label(why, 13, UI.BAD)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.custom_minimum_size = Vector2(270, 0)
		v.add_child(wl)
		return p
	var row := UI.hbox(6)
	var left := T.left_of(id)
	row.add_child(UI.button("Сдать" if not left.is_empty() else "Открыть", func(): game.cmd("donate", {"id": id}),
		"Сдать нужное со склада штаба и из рюкзака (можно частями)" if not left.is_empty() else "Заплатить и открыть"))
	if not left.is_empty():
		row.add_child(UI.button("★ Лентой" if T.target != id else "★ Сюда везут", func(): game.cmd("tech_target", {"id": id}),
			"Терминал открытий будет принимать с лент ресурсы для этого узла"))
	v.add_child(row)
	return p


var contracts_done_show := false   # 1.1.15: выполненные задания станции скрыты


func _contracts_ui(body: VBoxContainer) -> void:
	var T: Tech = game.tech
	var hint := UI.small("Станция на орбите присылает заказы. За выполнение — кредиты и очки исследований; некоторые узлы дерева открываются только после заданий.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(940, 0)
	body.add_child(hint)
	var ids: Array = T.contracts().keys()
	ids.sort_custom(func(a, b): return int(T.contracts()[a].get("order", 0)) < int(T.contracts()[b].get("order", 0)))
	# 1.1.15: сверху — актуальные, выполненные скрыты (по кнопке внизу — показать)
	var done_n := 0
	for id in ids:
		if T.c_state(id) == "done":
			done_n += 1
	ids.sort_custom(func(a, b):
		var da := 1 if T.c_state(a) == "done" else 0
		var db := 1 if T.c_state(b) == "done" else 0
		if da != db:
			return da < db
		return int(T.contracts()[a].get("order", 0)) < int(T.contracts()[b].get("order", 0)))
	var shown := 0
	for id in ids:
		var c: Dictionary = T.contracts()[id]
		var st := T.c_state(id)
		if st == "locked" or (st == "done" and not contracts_done_show):
			continue
		shown += 1
		var p := UI.panel(0.95)
		var row := UI.hbox(10)
		p.add_child(row)
		var ic := str(c.get("item", ""))
		if DB.data.items.has(ic):
			row.add_child(UI.item_icon(ic, 44))
		elif not c.get("buildings", []).is_empty() and DB.data.buildings.has(str(c.buildings[0])):
			row.add_child(UI.building_icon(str(c.buildings[0]), 44))
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(("✔ " if st == "done" else "") + str(c.get("name", id)), 15, UI.GOOD if st == "done" else UI.TEXT))
		var tl := UI.small(str(c.get("text", "")))
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(560, 0)
		v.add_child(tl)
		var pr := T.c_progress(id) if st != "done" else [1, 1]
		var pb := UI.bar(v, UI.GOOD if st == "done" else UI.ACCENT, 8)
		pb.max_value = maxi(1, pr[1])
		pb.value = mini(pr[0], pr[1])
		var rw := "Награда: %d кр" % int(c.get("reward", 0))
		if int(c.get("research", 0)) > 0:
			rw += " · %d очков исследований" % int(c.research)
		v.add_child(UI.label(("%d / %d · " % pr if st != "done" else "Выполнено · ") + rw, 13, UI.DIM))
		row.add_child(v)
		if st == "open" and str(c.get("goal", "deliver")) == "deliver":
			var b := UI.button("Сдать", func(): game.cmd("c_deliver", {"id": id}), "Сдать со склада штаба и из рюкзака (можно частями)")
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		body.add_child(p)
	if shown == 0:
		body.add_child(UI.small("Сейчас заданий нет — откройте новые узлы дерева." if done_n > 0 else "Пока заданий нет — откройте новые узлы дерева."))
	if done_n > 0:
		var tb := UI.button(("Скрыть выполненные (%d)" if contracts_done_show else "Показать выполненные (%d)") % done_n, func():
			contracts_done_show = not contracts_done_show
			_refresh_tech())
		tb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(tb)


# ---------------------------------------------------------------- торговля

## Сканер (13.10): найденное сырьё сканируют N штук — после этого оно доступно в рецептах и постройках.
var scan_tier := -2   # 1.0.8: открытый этап в сканере (-2 — первый незакрытый)


func _refresh_scan() -> void:
	var w: Win = windows.scan
	# 1.3: окно пересобирается после каждого скана — прокрутка остаётся на месте (раньше прыгала наверх,
	# и следующий быстрый клик попадал мимо кнопки)
	var keep_scroll := 0
	for c in w.body.get_children():
		if c is ScrollContainer:
			keep_scroll = (c as ScrollContainer).scroll_vertical
	UI.clear(w.body)
	var sc = game.scanner
	if not DB.discovery:
		w.body.add_child(UI.small("Сканирование выключено («Настройки» → «Сканирование»): все ресурсы изучены сразу."))
		return
	# всё содержимое — в одной прокрутке (этапов много, окно не должно вылезать за экран)
	var outer := ScrollContainer.new()
	outer.custom_minimum_size = Vector2(UI.ws(600), minf(UI.fs(560), get_viewport().get_visible_rect().size.y * 0.72))
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	w.body.add_child(outer)
	if keep_scroll > 0:
		outer.set_deferred("scroll_vertical", keep_scroll)
	var body := UI.vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var intro := UI.small("Новый ресурс сначала надо изучить: отдайте сканеру несколько штук. Пока ресурс не изучен, рецепты с ним скрыты, а здания с ним в цене — серые с замком. Ниже по этапам — сколько ещё изучить; «Неизвестный ресурс» — ещё не найден.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(UI.ws(560), 0)
	body.add_child(intro)
	# можно изучить прямо сейчас (найдено и есть у героя или в штабе)
	var list: Array = sc.pending()
	var now := list.filter(func(id): return game.factory.available(id) > 0)
	if not now.is_empty():
		var hr := UI.hbox(10)
		hr.add_child(UI.label("Можно изучить сейчас (%d):" % now.size(), 14, UI.ACCENT))
		var all_btn := UI.button("Сканировать всё", func():
			for id in now:
				game.cmd("scan", {"id": id})
			_scan_refresh_soon(), "Отдать сканеру всё, что есть у героя и в штабе, по всем найденным ресурсам")
		all_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		hr.add_child(all_btn)
		body.add_child(hr)
		for id in now:
			body.add_child(_scan_row(id))
	# этапы
	var stg: Array = sc.stages()
	if stg.is_empty():
		if list.is_empty():
			body.add_child(UI.label("Пока нечего сканировать — добудьте что-то новое.", 14, UI.DIM))
		return
	var total := 0
	var done_all := 0
	var first_open := -1
	for e in stg:
		var dn: int = e.items.filter(func(id): return DB.is_researched(id)).size()
		total += e.items.size()
		done_all += dn
		if first_open == -1 and dn < e.items.size():
			first_open = int(e.tier)
	var sel := scan_tier
	if sel == -2 or not stg.any(func(e): return int(e.tier) == sel):
		sel = first_open if first_open != -1 else int(stg[stg.size() - 1].tier)
	body.add_child(UI.label("Изучено %d из %d · по этапам:" % [done_all, total], 14))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 5)
	tabs.add_theme_constant_override("v_separation", 5)
	for e in stg:
		var dn: int = e.items.filter(func(id): return DB.is_researched(id)).size()
		var tid := int(e.tier)
		var left: int = e.items.size() - dn
		var short := str(e.name).get_slice(" · ", 0)
		var b := UI.button("%s: %s" % [short, ("✓" if left == 0 else "ещё %d" % left)], func(): scan_tier = tid; _refresh_scan(), "%s — осталось изучить %d из %d" % [str(e.name), left, e.items.size()])
		b.add_theme_font_size_override("font_size", UI.fs(13))
		if tid == sel:
			b.add_theme_stylebox_override("normal", UI.theme().get_stylebox("pressed", "Button"))
			b.add_theme_color_override("font_color", UI.theme().get_color("font_pressed_color", "Button"))
		elif left == 0:
			b.add_theme_color_override("font_color", UI.GOOD)
		tabs.add_child(b)
	body.add_child(tabs)
	for e in stg:
		if int(e.tier) == sel:
			body.add_child(UI.label("%s — изучено %d из %d" % [str(e.name), e.items.filter(func(id): return DB.is_researched(id)).size(), e.items.size()], 15, UI.ACCENT))
	var rows := UI.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rows)
	for e in stg:
		if int(e.tier) != sel:
			continue
		var items: Array = e.items.duplicate()
		# порядок: найдено, но не изучено → не найдено → изучено
		items.sort_custom(func(a, b):
			var ka := 0 if (DB.is_known(a) and not DB.is_researched(a)) else (1 if not DB.is_known(a) else 2)
			var kb := 0 if (DB.is_known(b) and not DB.is_researched(b)) else (1 if not DB.is_known(b) else 2)
			return ka < kb)
		for id in items:
			if DB.is_researched(id):
				var r := UI.hbox(8)
				var ic := UI.item_icon(id, 24)
				ic.tooltip_text = UI.item_tip(id)
				ic.mouse_filter = Control.MOUSE_FILTER_PASS
				r.add_child(ic)
				r.add_child(UI.label("%s — изучено ✓" % DB.item_name(id), 13, UI.GOOD))
				rows.add_child(r)
			elif DB.is_known(id):
				rows.add_child(_scan_row(id))
			else:
				var r := UI.hbox(8)
				var q := PanelContainer.new()
				q.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.35), 5))
				q.custom_minimum_size = Vector2(36, 36)
				var ql := UI.label("?", 20, UI.DIM)
				ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ql.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				q.add_child(ql)
				r.add_child(q)
				var v := UI.vbox(1)
				v.add_child(UI.label("Неизвестный ресурс", 14, UI.DIM))
				var hint: String = sc.source_hint(id)
				v.add_child(UI.small(("Где искать: %s · " % hint if hint != "" else "") + "изучить %d шт." % DB.scan_need(id)))
				r.add_child(v)
				rows.add_child(r)


## 1.3: пересобрать окно сканера после клика — не внутри сигнала нажатой кнопки, а после кадра
## (и ещё раз чуть позже: в сетевой игре ответ хоста приходит не сразу).
var _scan_pending := false

func _scan_refresh_soon() -> void:
	if _scan_pending:
		return
	_scan_pending = true
	await get_tree().process_frame
	_scan_pending = false
	if is_open("scan"):
		_refresh_scan()
	if Net.active() and not Net.is_host():
		await get_tree().create_timer(0.35).timeout
		if is_open("scan"):
			_refresh_scan()


## Строка «отсканировать»: значок, прогресс, сколько есть, кнопка.
func _scan_row(id: String) -> Control:
	var sc = game.scanner
	var row := UI.hbox(10)
	row.add_child(UI.item_icon(id, 36))
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var need: int = DB.scan_need(id)
	var have: int = game.factory.available(id)
	v.add_child(UI.label("%s — отсканировано %d / %d" % [DB.item_name(id), sc.progress(id), need], 14))
	var bar := UI.bar(v, UI.ACCENT, 8)
	bar.value = float(sc.progress(id)) / maxf(1.0, need) * 100.0
	v.add_child(UI.small("Есть у героя и в штабе: %d" % have))
	row.add_child(v)
	var btn := UI.button("Сканировать", func():
		game.cmd("scan", {"id": id})
		_scan_refresh_soon(), "Отдать сканеру до %d шт." % (need - sc.progress(id)))
	# 1.3: срабатывает на нажатие, а не на отпускание: окно пересобирается, и отпускание
	# над уже новой кнопкой раньше терялось (приходилось жать несколько раз)
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.disabled = have <= 0
	row.add_child(btn)
	return row


func _refresh_trade() -> void:
	var w: Win = windows.trade
	var hq = game.factory.hq
	# окно строится один раз, дальше только обновляются числа (список не прыгает наверх)
	if w.get_meta("rev", -1) != DB.revision or w.body.get_child_count() == 0 or w.get_meta("known", -1) != DB.known.size():
		w.set_meta("rev", DB.revision)
		w.set_meta("known", DB.known.size())
		UI.clear(w.body)
		var head := UI.rich("", 14)
		w.body.add_child(head)
		w.set_meta("head", head)
		if game.module("orders"):
			w.body.add_child(UI.button("Заказы: выставить свою цену, предложения торговцев, история сделок", func(): close("trade"); open("orders")))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 420)
		w.body.add_child(scroll)
		var g := GridContainer.new()
		g.columns = 6
		g.add_theme_constant_override("h_separation", 8)
		scroll.add_child(g)
		for h in ["", DB.tx("tr_item", "Товар"), DB.tx("tr_have", "Есть"), DB.tx("tr_price", "Цена за шт."), DB.tx("tr_sell", "Продать"), DB.tx("tr_buy", "Купить")]:
			g.add_child(UI.small(h))
		var rows := []
		for id in DB.data.items:
			if int(DB.item(id).get("price", 0)) <= 0 or not DB.is_known(id):
				continue
			var ic := UI.item_icon(id, 28)
			ic.mouse_filter = Control.MOUSE_FILTER_PASS
			ic.tooltip_text = UI.item_tip(id)
			g.add_child(ic)
			var nm := UI.label(DB.item_name(id), 14)
			nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			nm.size_flags_vertical = Control.SIZE_FILL
			nm.mouse_filter = Control.MOUSE_FILTER_PASS
			nm.tooltip_text = UI.item_tip(id)
			nm.custom_minimum_size = Vector2(170, 0)
			g.add_child(nm)
			var have_l := UI.label("", 14)
			have_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			have_l.size_flags_vertical = Control.SIZE_FILL
			have_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			have_l.custom_minimum_size = Vector2(60, 0)
			have_l.mouse_filter = Control.MOUSE_FILTER_PASS
			g.add_child(have_l)
			var price_l := UI.rich("", 14)
			price_l.custom_minimum_size = Vector2(80, 0)
			price_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			g.add_child(price_l)
			var sh := UI.hbox(2)
			sh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var s1 := UI.button("1", func(): game.cmd("sell", {"id": id, "n": 1}))
			var s2 := UI.button(DB.tx("tr_all", "всё"), func(): game.cmd("sell", {"id": id, "n": -1}))
			sh.add_child(s1)
			sh.add_child(s2)
			g.add_child(sh)
			var b := UI.button("", func(): game.cmd("buy", {"id": id, "n": 10}))
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			g.add_child(b)
			rows.append([id, have_l, price_l, s1, s2, b])
		w.set_meta("rows", rows)
	w.title_lbl.text = DB.tx("trade_title", "ТОРГОВАЯ СТАНЦИЯ «ОРБИТА-7»")
	var hd: RichTextLabel = w.get_meta("head")
	hd.text = DB.t(DB.tx("trade_head", "Кредиты: [color=#ffd36b]{credits}[/color]. Станция забирает товар сначала со склада штаба, потом из рюкзака, и присылает челнок."), {"credits": game.credits}) + (
		"\n[color=#ff8aa0]Станция платит вдвое меньше Чёрного рынка — продавать выгоднее там.[/color]" if Blocks.econ_on() else "")
	for r in w.get_meta("rows"):
		var id: String = r[0]
		var in_hq: int = hq.inv.count(id) if hq else 0
		var in_bag: int = game.player.inv.count(id)
		var have := in_hq + in_bag
		r[1].text = str(have)
		r[1].add_theme_color_override("font_color", UI.TEXT if have > 0 else UI.DIM)
		r[1].tooltip_text = "%s: %d\n%s: %d" % [DB.tx("in_hq", "В штабе"), in_hq, DB.tx("in_bag", "В рюкзаке"), in_bag]
		var tr: float = game.price_trend(id)
		var p: int = game.sell_price(id)
		var ps := str(p)
		var pall := str(p * have)
		if Blocks.econ_on():
			# 1.1.8: станция платит долю цены Чёрного рынка — дробные кредиты
			var pv: float = game.sell_value(id)
			ps = game.fmt_cr(pv)
			pall = str(int(floor(pv * have)))
		var why: Array = game.econ_reasons(id)
		r[2].text = "%s кр [color=%s]%s[/color]%s" % [ps, "#7dff9a" if tr > 0 else "#ff6b5a", "▲" if tr > 0.005 else ("▼" if tr < -0.005 else ""), " [color=#ffd36b]*[/color]" if not why.is_empty() else ""]
		r[2].tooltip_text = "\n".join(why) if not why.is_empty() else ""
		r[3].disabled = have < 1
		r[4].disabled = have < 1
		r[3].tooltip_text = DB.t(DB.tx("tr_sell1_tip", "Продать 1 шт. за {p} кр"), {"p": ps})
		r[4].tooltip_text = DB.t(DB.tx("tr_sell_all_tip", "Продать все {n} шт. за {p} кр"), {"n": have, "p": pall})
		var bp: int = game.buy_price(id) * 10
		r[5].text = DB.t(DB.tx("tr_buy10", "10 за {p}"), {"p": bp})
		r[5].disabled = game.credits < bp
		r[5].tooltip_text = DB.t(DB.tx("tr_buy_tip", "Купить 10 шт. Челнок привезёт их в штаб.")) + ("" if game.credits >= bp else "\n" + DB.t(DB.tx("tr_no_money", "Не хватает {n} кр"), {"n": bp - game.credits}))


# ---------------------------------------------------------------- пауза, настройки, помощь

## Кнопки паузы — по списку из редактора (Главное меню и экраны → Кнопки меню паузы).
var _bp_built := -1


## Окно заказов: форма нового заказа (строится один раз), мои заказы с предложениями, история.
func _refresh_orders() -> void:
	var w: Win = windows.orders
	var O = game.orders
	if w.body.get_child_count() == 0:
		w.body.add_child(UI.small("Выставьте заказ — через время торговцы пришлют предложения по рыночной цене. Слишком дорого — предложений не будет, дешевле рынка — придут быстрее."))
		var row := UI.hbox(6)
		var side := OptionButton.new()
		side.add_item("Продать", 0)
		side.add_item("Купить", 1)
		row.add_child(side)
		var item := OptionButton.new()
		var ids: Array = []
		for id in DB.data.items:
			if int(DB.item(id).get("price", 0)) > 0:
				ids.append(id)
		ids.sort_custom(func(a, b): return DB.item_name(a) < DB.item_name(b))
		for id in ids:
			item.add_item(DB.item_name(id))
			item.set_item_metadata(item.item_count - 1, id)
		item.custom_minimum_size = Vector2(200, 0)
		row.add_child(item)
		var n := SpinBox.new()
		n.min_value = 1
		n.max_value = 100000
		n.value = 50
		n.prefix = "×"
		row.add_child(n)
		var pr := SpinBox.new()
		pr.min_value = 1
		pr.max_value = 100000000
		pr.suffix = "кр"
		pr.custom_minimum_size = Vector2(130, 0)
		row.add_child(pr)
		var market := UI.small("")
		var upd := func():
			var id: String = item.get_item_metadata(item.selected) if item.selected >= 0 else ""
			if id != "":
				market.text = "По рынку: %d кр" % roundi(O.unit_price(id, "sell" if side.selected == 0 else "buy") * n.value)
		item.item_selected.connect(func(_i): upd.call())
		n.value_changed.connect(func(_v): upd.call())
		side.item_selected.connect(func(_i): upd.call())
		row.add_child(UI.button("По рынку", func():
			var id: String = item.get_item_metadata(item.selected) if item.selected >= 0 else ""
			if id != "":
				pr.value = maxi(1, roundi(O.unit_price(id, "sell" if side.selected == 0 else "buy") * n.value))))
		row.add_child(UI.button("Выставить", func():
			var id: String = item.get_item_metadata(item.selected) if item.selected >= 0 else ""
			if id != "":
				O.place("sell" if side.selected == 0 else "buy", id, int(n.value), int(pr.value))
				w.set_meta("sig", "")
				_refresh_orders()))
		w.body.add_child(row)
		w.body.add_child(market)
		var lst := UI.vbox(6)
		w.body.add_child(lst)
		w.set_meta("list", lst)
		if item.item_count > 0:
			item.select(0)
			upd.call()
			pr.value = maxi(1, roundi(O.unit_price(str(item.get_item_metadata(0)), "sell") * n.value))
	var sig := "%s|%d|%d" % [str(O.list), O.history.size(), game.credits]
	if w.get_meta("sig", "") == sig:
		return
	w.set_meta("sig", sig)
	var box: VBoxContainer = w.get_meta("list")
	UI.clear(box)
	box.add_child(UI.section("Мои заказы"))
	if O.list.is_empty():
		box.add_child(UI.small("Заказов нет"))
	for o in O.list:
		var r := UI.hbox(8)
		r.add_child(UI.item_icon(str(o.item), 26))
		var g: float = O.greed(o)
		var l := UI.rich("%s %d × %s за [color=#ffd36b]%d кр[/color] [color=#8a93a3](рынок %d кр%s)[/color]" % ["Продаю" if o.side == "sell" else "Куплю", o.n,
			DB.item_name(str(o.item)), o.price, roundi(O.market_total(o)), ", слишком дорого — никто не возьмётся" if g > float(DB.setting("order_max_ratio", 1.6)) else ""], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var oid := int(o.id)
		r.add_child(UI.button("Снять", func(): O.cancel(oid); w.set_meta("sig", ""); _refresh_orders()))
		box.add_child(r)
		for of in o.offers:
			var r2 := UI.hbox(8)
			var l2 := UI.label("    → " + O.offer_text(o, of), 13)
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			r2.add_child(l2)
			var oo = o
			var off = of
			r2.add_child(UI.button("Принять", func(): O.accept(oo, off); w.set_meta("sig", ""); _refresh_orders()))
			r2.add_child(UI.button("Отказ", func(): O.decline(oo, off); w.set_meta("sig", ""); _refresh_orders()))
			box.add_child(r2)
	box.add_child(UI.section("История сделок"))
	if O.history.is_empty():
		box.add_child(UI.small("Пока пусто"))
	for hst in O.history.slice(0, 12):
		box.add_child(UI.small("День %d: %s" % [int(hst.day), hst.text]))
var npc_e = null
var _npc_line := ""


func open_npc(e) -> void:
	npc_e = e
	_npc_line = game.npcs.next_line(e)
	windows.npc.set_meta("sig", "")
	open("npc")
	_with_inventory()


func _npc_traded(e, ok: bool) -> void:
	if ok:
		var tl: String = game.npcs.say(e, "trade")
		if tl != "":
			_npc_line = tl
	_refresh_npc()


## Окно торговли с НПС: товары, что он покупает, подарок, отношение группы.
func _refresh_npc() -> void:
	var w: Win = windows.npc
	var N = game.npcs
	var e = npc_e
	if e == null or not e.alive or World.dist(e.pos, game.player.position) > 9.0:
		close("npc")
		return
	game.npcs.talking(e)
	var d: Dictionary = DB.data.enemies.get(e.type, {})
	var f := str(d.get("faction", ""))
	if Net.is_client() and e.stock.is_empty():
		N.client_stock(e, d)   # A-9: у гостя торговец приходит без товара — берём начальный запас (хозяин всё равно проверит)
	var sig := "%s|%s|%d|%d|%s|%s|%s" % [e.type, str(e.stock), game.credits, N.rep_of(f), str(game.player.inv.totals()), str(N.person(e)), _npc_line]
	if w.get_meta("sig", "") == sig:
		return
	w.set_meta("sig", sig)
	UI.clear(w.body)
	w.title_lbl.text = Lang.t(N.display_name(e)).to_upper()
	var fd: Dictionary = N.factions().get(f, {})
	var r: int = N.rep_of(f)
	w.body.add_child(UI.rich("[i]«%s»[/i]\n%s: [color=%s]%d (%s)[/color] · цены ×%.2f · кредиты: [color=#ffd36b]%d[/color]" % [_npc_line,
		fd.get("name", "Группа"), fd.get("color", "#ffffff"), r, N.rep_word(r), N.price_for(e), game.credits], 14))
	var mem: String = N.memory_text(e)
	if mem != "":
		w.body.add_child(UI.small(mem + "  (характеры и реплики: «Настройки → Характеры НПС»)"))
	var refused: bool = N.refuses(e)
	var goods: Array = d.get("goods", []) if not refused else []
	if refused:
		w.body.add_child(UI.label("Не торгует с вами: слишком обижен. Подарок поможет помириться.", 14, Color(1, 0.6, 0.5)))
	if not goods.is_empty():
		w.body.add_child(UI.section("Продаёт"))
		for i in goods.size():
			if not e.stock.has(i):
				continue
			var g: Dictionary = goods[i]
			var row := UI.hbox(8)
			row.add_child(UI.item_icon(str(g.item), 28))
			var l := UI.label("%s — осталось %d" % [DB.item_name(str(g.item)), int(e.stock.get(i, 0))], 14)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var bi := i
			var b := UI.button("Купить за %d кр" % N.good_price(e, i), func(): _npc_traded(e, N.buy_from(e, bi)))
			b.disabled = int(e.stock.get(i, 0)) <= 0 or game.credits < N.good_price(e, i)
			row.add_child(b)
			w.body.add_child(row)
	var buys: Array = d.get("buys", []) if not refused else []
	if not buys.is_empty():
		w.body.add_child(UI.section("Покупает" + (" · у торговца %d кр" % N.cash_of(e) if Blocks.econ_on() else "")))
		for it in buys:
			var row := UI.hbox(8)
			row.add_child(UI.item_icon(str(it), 28))
			var bit := str(it)
			var have: int = game.player.inv.count(bit)
			var l := UI.label("%s — %d кр/шт · у вас %d" % [DB.item_name(bit), N.sell_price_to(e, bit), have], 14)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			# 1.1.8: продать 1, 50 или всё сразу
			for cnt in [1, 50, -1]:
				var cn: int = cnt
				var b := UI.button("Продать 1" if cn == 1 else ("Продать 50" if cn == 50 else "Продать всё"), func(): _npc_traded(e, N.sell_to(e, bit, cn)),
					"Получите %d кр" % (N.sell_price_to(e, bit) * (have if cn < 0 else mini(cn, have))))
				b.disabled = have <= 0 or (cn == 50 and have < 2)
				row.add_child(b)
			w.body.add_child(row)
	var held: String = game.player.selected_item()
	var gb := UI.button("Подарить: %s" % (DB.item_name(held) if held != "" else "возьмите предмет в руки"), func():
		var up: int = N.gift(e, game.player.selected_item())
		if up > 0:
			var gl: String = N.say(e, "gift")
			_npc_line = "%s (+%d к отношению)" % [gl if gl != "" else "Спасибо!", up]
		_refresh_npc())
	gb.disabled = held == ""
	w.body.add_child(gb)




## Окно «Чертежи» (G, когда чертёж в руке): сохранить текущий, взять или удалить сохранённый.
var boss_box: VBoxContainer
var boss_lbl: Label
var boss_bar: ProgressBar
var siege_lbl: Label
func _update_boss() -> void:
	var sg = game.sieges
	if sg == null:
		return
	var bs = sg.boss if sg.boss != null and sg.boss.alive else null
	if bs == null and Net.is_client():
		for e in game.enemies.list:
			if e.alive and bool(e.d.get("boss", false)):
				bs = e
				break
	boss_box.visible = bs != null
	if bs != null:
		boss_lbl.text = (Lang.t("Босс") + ": " + Lang.t(str(bs.d.get("name", bs.type)))).to_upper()
		boss_bar.max_value = bs.maxhp
		boss_bar.value = maxf(0.0, bs.hp)
	var t := ""
	if sg.enabled() and bs == null:
		if sg.announced_day == game.day_n and sg.fired_day != game.day_n and sg.boss_type != "":
			t = "Сегодня ночью осада: %s %s" % [str(DB.data.enemies.get(sg.boss_type, {}).get("name", sg.boss_type)), sg.side_name(sg.dir)]
		else:
			var nd: int = sg.next_day()
			if nd > game.day_n and nd - game.day_n <= 2:
				t = "Осада с боссом: через %d дн." % (nd - game.day_n)
	siege_lbl.text = t
	siege_lbl.visible = t != ""


## Конструктор модов (N): свои здания и предметы прямо в игре (scripts/ui/mod_ctor.gd).
var ctor: ModCtor
func _refresh_ctor() -> void:
	if ctor == null:
		ctor = ModCtor.new(self)
	ctor.refresh(windows.constructor.body)


func _refresh_blueprints() -> void:
	var B = game.blueprints
	var ver: int = B.saved.size() * 1000 + (B.cur.get("items", []).size() if B.mode == "paste" else -1)
	var w: Win = windows.blueprints
	if ver == _bp_built and w.body.get_child_count() > 0:
		return
	_bp_built = ver
	UI.clear(w.body)
	if B.mode == "paste" and not B.cur.is_empty():
		w.body.add_child(UI.section("Чертёж в руке: %d зданий, %d×%d клеток" % [B.cur.items.size(), int(B.cur.w), int(B.cur.h)]))
		w.body.add_child(UI.cost_box(B.total_cost(B.cur), game.factory.available))
		var row := UI.hbox(6)
		var name_e := LineEdit.new()
		name_e.placeholder_text = "Название чертежа"
		name_e.text = str(B.cur.get("name", ""))
		name_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_e)
		row.add_child(UI.button("Сохранить", func(): B.save_current(name_e.text); _bp_built = -1; _refresh_blueprints()))
		w.body.add_child(row)
	w.body.add_child(UI.section("Сохранённые"))
	if B.saved.is_empty():
		w.body.add_child(UI.small("Пока нет. Нажмите G, выделите здания мышью, затем G ещё раз — и сохраните."))
	var names: Array = B.saved.keys()
	names.sort()
	for nm in names:
		var bp: Dictionary = B.saved[nm]
		var row := UI.hbox(6)
		var l := UI.label("%s — %d зданий" % [nm, bp.get("items", []).size()])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.button("Взять", func(): close("blueprints"); B.start_paste(bp.duplicate(true))))
		row.add_child(UI.button("В файл", func():
			var f: String = B.export_file(nm)
			game.notify("Чертёж выгружен: " + f, Color(0.6, 1, 0.7))
			DisplayServer.clipboard_set(f), "Сохранить одним файлом .fcbp, чтобы отправить другу (путь копируется)"))
		row.add_child(UI.button("Удалить", func(): B.remove(nm); _bp_built = -1; _refresh_blueprints()))
		w.body.add_child(row)
	var sh := UI.hbox(6)
	sh.add_child(UI.button("Забрать чертежи из папки", func():
		var got: Array = B.import_all()
		game.notify("Добавлено чертежей: %d" % got.size() if not got.is_empty() else "В папке нет новых чертежей (*.fcbp)", Color(0.6, 1, 0.7))
		_bp_built = -1
		_refresh_blueprints(), "Положите файлы .fcbp в папку обмена"))
	sh.add_child(UI.button("Открыть папку", func(): OS.shell_open(B.share_dir())))
	w.body.add_child(sh)
	w.body.add_child(UI.small("Предел чертежа: %s" % ("%d×%d клеток" % [B.max_size(), B.max_size()] if B.max_size() > 0 else "нет")))
	w.body.add_child(UI.small("G — выделить здания мышью · R — повернуть · ЛКМ — поставить · ПКМ — убрать чертёж из руки"))


func _refresh_pause() -> void:
	var w: Win = windows.pause
	if w.body.get_child_count() > 0:
		return
	w.title_lbl.text = DB.tx("pause_title", "ПАУЗА")
	var list: Array = DB.menu("pause_buttons", [])
	if list.is_empty():
		list = [{"id": "resume"}, {"id": "save"}, {"id": "load"}, {"id": "settings"}, {"id": "help"}, {"id": "menu"}, {"id": "quit"}]
	var names := {"resume": "Продолжить", "save": "Сохранить", "load": "Загрузить", "settings": "Настройки", "help": "Как играть",
		"menu": "Выйти в главное меню", "quit": "Выйти из игры", "command": "Команда"}
	for e in list:
		if not e is Dictionary or not bool(e.get("show", true)):
			continue
		var id := str(e.get("id", ""))
		# 1.1.15: в сетевой игре «Загрузить» другой мир рассинхронизирует комнату — нельзя; гостю и «Сохранить» ни к чему
		if Net.active() and (id == "load" or (id == "save" and Net.is_client())):
			continue
		var txt := DB.t(e.get("text", "")) if str(e.get("text", "")) != "" else str(names.get(id, id))
		var cb := Callable()
		match id:
			"resume": cb = func(): close("pause")
			"save": cb = func(): close("pause"); open_saves("save")
			"load": cb = func(): close("pause"); open_saves("load")
			"settings": cb = func(): close("pause"); open("settings")
			"help": cb = func(): close("pause"); open("help")
			"menu":
				if DB.get_meta("from_editor", false):
					txt = "Вернуться в редактор"
				cb = func(): game.to_menu()
			"quit": cb = func(): game.quit_game()
			"command":
				var cmd := str(e.get("command", ""))
				cb = func(): close("pause"); game.console.run(cmd)
		if not cb.is_valid():
			continue
		var b := UI.button(txt, cb)
		b.custom_minimum_size = Vector2(0, 40)
		w.body.add_child(b)
	if not Net.active():
		w.body.add_child(UI.button("Сменить режим камеры · F6", func():
			close("pause")
			game.cycle_camera()))
	# 1.3: сплитскрин — второй игрок на геймпаде (Start на втором геймпаде делает то же самое)
	if game.split != null:
		var sb := UI.button("", func(): pass, "Второй игрок с геймпадом на правой половине экрана, в этой же игре: общий мир и база, у каждого свой герой и свои окна")
		var upd := func():
			sb.text = "Убрать второго игрока" if game.split.running() else ("Жду Start на геймпаде второго игрока…" if Pad.claim_next else "Добавить игрока (сплитскрин)")
		sb.pressed.connect(func():
			if game.split.running():
				close("pause")
				game.split.stop.call_deferred()
			else:
				Pad.claim_next = not Pad.claim_next
				if Pad.claim_next:
					game.notify("Второй игрок: нажмите Start на своём геймпаде", Color(0.6, 0.9, 1))
			upd.call())
		sb.visibility_changed.connect(upd)
		upd.call()
		sb.custom_minimum_size = Vector2(0, 40)
		w.body.add_child(sb)
	w.body.add_child(UI.flora_toggle(16))


## Окно ячеек сохранения: mode = "save" или "load".
func open_saves(mode: String) -> void:
	saves_mode = mode
	var w: Win = windows.saves
	w.title_lbl.text = DB.tx("save_title" if mode == "save" else "load_title", "СОХРАНИТЬ ИГРУ" if mode == "save" else "ЗАГРУЗИТЬ ИГРУ")
	UI.clear(w.body)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	w.body.add_child(sc)
	SavesUI.build(list, mode, func(slot):
		if saves_mode == "save":
			game.save_game(slot)
			close("saves")
		else:
			SavesUI.start_from(get_tree(), slot))
	open("saves")


func _refresh_settings() -> void:
	var w: Win = windows.settings
	if w.get_meta("sec", "") == settings_sec and w.body.get_child_count() > 0:
		return
	w.set_meta("sec", settings_sec)
	build_settings(w.body, func(s): settings_sec = s; _refresh_settings())


## Меню настроек строится по options.json — моды и редактор могут добавлять пункты.
func build_settings(body: Control, on_tab: Callable) -> void:
	UI.clear(body)
	var tabs := UI.hbox(4)
	for sec in DB.data.options.get("sections", []):
		var b := UI.button(sec.get("name", sec.id), on_tab.bind(sec.id))
		if sec.id == settings_sec:
			b.add_theme_stylebox_override("normal", UI.theme().get_stylebox("pressed", "Button"))
		tabs.add_child(b)
	body.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := UI.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for sec in DB.data.options.get("sections", []):
		if sec.id != settings_sec:
			continue
		for it in sec.get("items", []):
			list.add_child(_option_row(it))
	var row := UI.hbox()
	row.add_child(UI.button("Сбросить раздел", func(): Prefs.reset_section(settings_sec); UI.clear(body); on_tab.call(settings_sec)))
	body.add_child(row)


func _rush_clock(sec: float) -> String:
	var t := int(sec)
	return "%d:%02d" % [t / 60, t % 60]


func _option_row(it: Dictionary) -> Control:
	var key: String = it.key
	var row := UI.hbox(10)
	var l := UI.label(it.get("name", key), 14)
	l.custom_minimum_size = Vector2(280, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(l)
	var v = Prefs.get_value(key)
	match it.get("type", "check"):
		"check":
			var c := CheckBox.new()
			c.button_pressed = bool(v)
			c.focus_mode = Control.FOCUS_NONE
			c.toggled.connect(func(on): Prefs.set_value(key, on))
			row.add_child(c)
		"slider":
			var s := HSlider.new()
			s.min_value = float(it.get("min", 0))
			s.max_value = float(it.get("max", 1))
			s.step = float(it.get("step", 0.05))
			s.value = float(v)
			s.custom_minimum_size = Vector2(200, 0)
			s.focus_mode = Control.FOCUS_NONE
			var vl := UI.label(_fmt(s.value), 13, UI.DIM)
			s.value_changed.connect(func(x): vl.text = _fmt(x); Prefs.set_value(key, x))
			row.add_child(s)
			row.add_child(vl)
		"choice":
			var ob := OptionButton.new()
			ob.focus_mode = Control.FOCUS_NONE
			var ch: Array = it.get("choices", [])
			for i in ch.size():
				ob.add_item(str(ch[i][1]))
				if str(ch[i][0]) == str(v):
					ob.select(i)
			ob.item_selected.connect(func(i): Prefs.set_value(key, ch[i][0]))
			row.add_child(ob)
		"key":
			var b := Button.new()
			b.text = str(v)
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(140, 0)
			b.pressed.connect(func(): _wait_key(b, key))
			row.add_child(b)
	return row


func _fmt(x: float) -> String:
	return str(int(x)) if absf(x - roundf(x)) < 0.001 and absf(x) >= 2.0 else "%.2f" % x


var _key_btn: Button = null
var _key_name := ""

func _wait_key(b: Button, key: String) -> void:
	_key_btn = b
	_key_name = key
	b.text = "нажмите клавишу..."


func _input(ev: InputEvent) -> void:
	if _key_btn == null:
		return
	if (ev is InputEventKey and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index > 2):
		var n := Prefs.event_name(ev)
		if ev is InputEventKey and ev.physical_keycode == KEY_ESCAPE:
			n = str(Prefs.get_value(_key_name))
		Prefs.set_value(_key_name, n)
		_key_btn.text = n
		_key_btn = null
		get_viewport().set_input_as_handled()


func _refresh_help() -> void:
	var w: Win = windows.help
	if w.body.get_child_count() > 0:
		return
	var r := UI.rich(help_text(), 15)
	r.custom_minimum_size = Vector2(580, 0)
	w.body.add_child(r)
	var hr := UI.hbox(10)
	hr.add_child(UI.button("Играть!", func(): close("help")))
	if not Tutorial.steps().is_empty():
		hr.add_child(UI.button("Пройти обучение", func(): close("help"); game.tutorial.restart(), "Пошаговое обучение: ходьба, добыча, крафт, бур, конвейер, энергия, защита, зона"))
	w.body.add_child(hr)


## Текст «Как играть»: дополнение из редактора (Главное меню и экраны) + клавиши игрока.
static func help_text() -> String:
	var k := func(a: String) -> String: return str(Prefs.get_value("key_" + a, "?"))
	var t := ""
	var extra := DB.t(DB.menu("help_extra", ""))
	if extra.strip_edges() != "":
		t += extra + "\n\n"
	t += "[b]Цель:[/b] %s\n\n" % _goal_text()
	t += "[b]Начало.[/b] Рубите деревья и бейте камни (ЛКМ рядом с ними) — выпадут ветки, брёвна, камни. Предметы светятся и сами подбираются, когда проходите рядом.\n"
	t += "Сделайте каменный топор и кирку ([b]%s[/b] — крафт), затем верстак и печь. Плавьте руду, стройте бур, генератор и ленты.\n\n" % k.call("craft")
	t += "[b]%s %s %s %s[/b] — ходить, [b]%s[/b] — бег · [b]%s / %s[/b] — повернуть камеру · колесо — приблизить\n" % [k.call("move_up"), k.call("move_left"), k.call("move_down"), k.call("move_right"), k.call("sprint"), k.call("cam_left"), k.call("cam_right")]
	t += "[b]ЛКМ[/b] — добывать (рядом с деревом или камнем) или стрелять · [b]ПКМ[/b] (держать) — чинить здание\n"
	t += "[b]%s[/b] — меню строительства · [b]%s[/b] — повернуть здание · [b]%s[/b] — разобрать\n" % [k.call("build_menu"), k.call("rotate"), k.call("demolish")]
	if str(DB.setting("power_mode", "stations")) == "stations":
		t += "[b]%s[/b] — карта энергии: круги станций, кто питается (зелёный), кому не хватило мощности (оранжевый), где станции нет (красный). Станция отдаёт свою мощность зданиям в круге — ближним первыми; станции и генераторы связываются сами. Станцию выше уровнем ставьте прямо на старую\n" % k.call("wire")
	else:
		t += "[b]%s[/b] — провода: кликните по зданию (можно рядом, оно мигнёт жёлтым), потом по второму (зелёное — можно). ПКМ по зданию — снять провода. Если машинам не хватит энергии, выбьет пробки: включите сеть кнопкой в окне опоры или генератора\n" % k.call("wire")
	t += "[b]%s[/b] — прыжок: так залезают на крышу машины и переходят ряд печей поверху · Здание выше уровнем (Mk2…Mk5) ставьте прямо на старое — обновится, встроенное останется\n" % k.call("jump")
	t += "[b]Геймпад:[/b] левый стик — ходьба, правый — курсор (прицел и стройка), правый курок — действие/выстрел, левый — отмена/второе действие, A — прыжок (в окнах — щелчок), X — взаимодействие, B — назад, Y — стройка, Back — рюкзак, Start — пауза, LB/RB — быстрые слоты, крестовина — камера\n"
	t += "[b]Сплитскрин:[/b] второй игрок жмёт Start на своём геймпаде прямо в игре — экран делится пополам (или «Пауза → Добавить игрока»). Общая база или своя — в «Настройки → Игра». В сетевой игре и на сервере второй игрок входит туда же\n"
	t += "[b]Рюкзак:[/b] Shift+клик — весь такой предмет в открытый ящик или печь и обратно; Alt+клик — стопку в мусорку, Shift+Alt+клик — все такие предметы (кнопка «Вернуть» отменяет)\n"
	t += "[b]Ленты:[/b] «Кротовина» — лента через ленту крест-накрест; умный разделитель — откройте и нажмите стрелку у предмета (руда прямо, уголь вправо); на поворотах Mk1–Mk2 предметы иногда слетают — «Бортики» это убирают, дрон станции подбирает упавшее\n"
	t += "[b]%s[/b] — открыть здание (забрать, положить, рецепт) или попить у воды · [b]%s[/b] — инвентарь\n" % [k.call("interact"), k.call("inventory")]
	t += "[b]%s[/b] — навыки · [b]%s[/b] — торговля · [b]%s[/b] — дерево открытий и задания станции · [b]%s[/b] — пауза · [b]1–9[/b] — быстрые слоты\n" % [k.call("skills"), k.call("trade"), k.call("tech"), k.call("pause")]
	t += "[b]%s[/b] — чертёж (выделить здания мышью и поставить копию, R — повернуть) · [b]%s[/b] — фоторежим (F12 — снимок) · [b]%s[/b] — камера сверху · [b]%s[/b] — карта потоков (где стоит производство) · [b]%s[/b] — конструктор модов (свои здания и предметы, обмен файлом)\n" % [k.call("blueprint"), k.call("photo"), k.call("top_view"), k.call("flow_map"), k.call("constructor")]
	t += "[b]%s[/b] у вездехода — сесть или выйти · [b]%s[/b] у торговца — торговать, продать, подарить. Заказы на станции — кнопка в окне торговли\n" % [k.call("interact"), k.call("interact")]
	t += "\n[b]Поле зрения.[/b] Вы видите только то, что перед героем. Монстров за спиной не видно, а постройки там приглушены — оглядывайтесь!"
	t += "\n[b]Энергия.[/b] Буры, плавильни и сборщики работают от генератора. Ставьте опоры ЛЭП, чтобы дотянуть сеть."
	if bool(Fusion.cfg().get("enabled", true)):
		t += "\n\n[b]Объединение одинаковых.[/b] Поставьте два одинаковых здания вплотную (печь к печи, бур к буру, турель к турели). Вверху появится окошко «Объединить здания?» — нажмите «Объединить». Получится «Объединение 2» (в 2 раза сильнее). Две «Объединение 2» рядом дают 3, и так до %d. Пропустили окошко — откройте здание ([b]%s[/b]) и нажмите «Объединить с соседним…»." % [Fusion.max_level(), k.call("interact")]
	if bool(Fusion.cfg().get("combo", true)):
		t += "\n[b]Сборное здание (до %d в одном).[/b] Сначала поставьте основу (бур, печь или сборщик), потом вплотную к ней другое здание (ящик, генератор, батарею, сборщик, турель). Появится «Собрать в одно здание?» — нажмите «Встроить». Или откройте основу ([b]%s[/b]) и нажмите «Встроить „…“ (рядом)». Встроенное исчезнет с земли и станет частью основы; следующее ставьте снова вплотную к основе. Бур всегда основа, его нельзя встроить в другое. Внутри: бур → печь → сборщик → ящик, генераторы и батареи питают без проводов, турели и щиты стоят на крыше." % [Fusion.max_parts(), k.call("interact")]
		t += "\n[b]Топливо встроенной печи.[/b] Положите уголь в её ячейку (окно здания → «Сборная линия»), подведите ленту с углём к зданию, привезите дронами или положите во встроенный ящик — печь возьмёт сама."
		t += "\n[b]Ящик и лишнее.[/b] В окне сборного здания: «В ящик складывать» — только готовое, всё подряд или только выбранное; «Когда выход полон» — ждать или уничтожать лишнее."
	t += "\n[b]Станция дронов.[/b] Поставьте станцию, откройте её ([b]%s[/b]) → «+ Добавить маршрут» → кликните по зданию, откуда брать (А), потом куда везти (Б). Дроны летают сами, заряжаются и чинятся на станции. Объедините станции: уровень 2 — 2 дрона, 3 — 4, 4 — 8, 5 — 15." % k.call("interact")
	t += "\n[b]Тонкая настройка (по желанию).[/b] У печей, буров, насосов, сборщиков, генераторов, химзавода, центрифуги, турелей, панелей и ветряков в окне есть ручка. На 50 всё работает как обычно. Найдите «золотую зону» по индикатору эффективности: будет быстрее, с лишними предметами или больше энергии. Крайности вредят: перегрев изнашивает здание. Узел «Тонкая настройка» подсвечивает зону."
	t += "\n[b]Инженерный стол.[/b] Разложите предметы узором 4×4: подсказка считает совпавшие клетки. Верный узор навсегда открывает улучшенный рецепт (дуговая сталь, плотные платы, гелий из отходов…)."
	t += "\n[b]НЛО-торговля.[/b] Постройте посадочную площадку, сложите товары во «Вход», закажите экзотику (гелий-3, антиматерию, нейтроний…). НЛО прилетает по расписанию, забирает товары и в следующий раз привозит заказ. Курс меняется каждый день — ловите выгодный."
	t += "\n[b]Квантовое измерение (после атома).[/b] Квантовый портал (нужна энергия) создаёт жилы в суперпозиции: посмотрите на жилу вблизи — она выберет, чем стать; в окне портала свободные жилы можно вернуть в суперпозицию за осколок. Запутанные ящики делят одно содержимое на любом расстоянии, запутанные станции — одна сеть. Квантовые тени двигаются, только пока на них не смотрите — держите их в кадре."
	t += "\n[b]Звёздные врата.[/b] Вершина завода: сверхпроводники, звёздный сплав, термоядерные ячейки, квантовые ядра, антиматерия и линзы тёмной материи для 5 этапов мегапроекта."
	if bool(DB.setting("modules", {}).get("hazards", false)):
		t += "\n[b]Новые ресурсы по дереву открытий.[/b] «Химия» — селитра и порох (патроны теперь из пороха; кустарные — из слитков и угля). «Кислоты» — химзавод, серная кислота, кислотостойкие трубы. «Алюминий» — алунит → раствор глинозёма → лом → слитки. «Уран» и «Атомная энергия» — урановая руда, центрифуга, ТВЭЛы и АЭС."
		t += "\n[b]Опасно![/b] Кислота разъедает обычные трубы и баки (нужны кислотостойкие или Mk4), лопнувшая труба — жгучая лужа. Уран, залежи урана и ТВЭЛы фонят: следите за дозиметром слева, носите защитный костюм."
		t += "\n[b]АЭС.[/b] Подведите воду трубами, положите ТВЭЛы, в окне реактора задайте «ТВЭЛов в зоне», насосы 100% и понемногу поднимайте стержни. Энергия идёт, когда вода кипит. Перегрев — взрыв: всё рядом разрушено, земля заражена. АЗ-5 сбрасывает стержни. Заражённую землю чистят станция дезактивации (раствор) и баллоны (ПКМ)."
	return t


static func _goal_text() -> String:
	var v: Dictionary = DB.menu("victory", {})
	var n := int(v.get("value", 0))
	match str(v.get("mode", "nests")):
		"waves": return "построить завод и отбить %d волн монстров." % n
		"credits": return "построить завод и заработать %d кр." % n
		"day": return "построить завод и продержаться до %d-го дня." % n
		"level": return "построить завод и поднять героя до %d уровня." % n
		"none": return "строить завод и выживать сколько сможете."
	return "построить завод, отбиваться от волн монстров и уничтожить их гнёзда."


# ---------------------------------------------------------------- свои окна из ui.json

var custom := {}   # id -> {win, elems: [[node, def]]}

func _build_custom_windows() -> void:
	for id in custom:
		if is_instance_valid(custom[id].win):
			custom[id].win.queue_free()
		windows.erase(id)
	custom.clear()
	for id in DB.data.ui.get("windows", {}):
		var d: Dictionary = DB.data.ui.windows[id]
		var w := _win(id, Lang.t(str(d.get("title", id))).to_upper(), float(d.get("size", [340, 0])[0]))
		if d.has("opacity"):
			var sb: StyleBoxFlat = UI.theme().get_stylebox("panel", "PanelContainer").duplicate()
			sb.bg_color.a = float(d.opacity)
			w.add_theme_stylebox_override("panel", sb)
		var elems := []
		for e in d.get("elements", []):
			var n: Control
			match e.get("type", "label"):
				"label":
					n = UI.rich("", int(e.get("size", 14)))
				"bar":
					var bv := UI.vbox(2)
					bv.add_child(UI.small(e.get("text", "")))
					UI.bar(bv, DB.color(e.get("color", "#ffa040")), 10)
					n = bv
				"separator":
					n = HSeparator.new()
				"button":
					var act: String = e.get("action", "")
					n = UI.button(e.get("text", "Кнопка"), func(): game.ui_action(act))
				"image":
					var tr := TextureRect.new()
					tr.texture = ModelLib.texture(e.get("path", ""))
					tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tr.custom_minimum_size = Vector2(float(e.get("w", 64)), float(e.get("h", 64)))
					n = tr
				_:
					n = UI.small("?")
			w.body.add_child(n)
			elems.append([n, e])
		custom[id] = {"win": w, "elems": elems, "key": d.get("key", "")}
		if d.get("visible", false):
			w.visible = true


func _update_custom_windows() -> void:
	var vals: Dictionary = game.ui_values()
	for id in custom:
		var c: Dictionary = custom[id]
		if not c.win.visible:
			continue
		for pair in c.elems:
			var n: Control = pair[0]
			var e: Dictionary = pair[1]
			match e.get("type", "label"):
				"label":
					var t: String = e.get("text", "")
					for k in vals:
						t = t.replace("{%s}" % k, str(vals[k]))
					(n as RichTextLabel).text = t
				"bar":
					var pb: ProgressBar = n.get_child(1)
					pb.max_value = 1.0
					pb.value = float(vals.get(e.get("bind", ""), 0.0))


func custom_window_for_key(keyname: String) -> String:
	for id in custom:
		if str(custom[id].key) == keyname and keyname != "":
			return id
	return ""


## Мусорка: ячейка в окне инвентаря. Предмет, брошенный в неё, исчезает (кнопка «Вернуть» — последний).
class TrashSlot extends Panel:
	var hud

	func _ready() -> void:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.22, 0.07, 0.07, 0.9)
		st.border_color = Color(0.85, 0.3, 0.25)
		st.set_border_width_all(2)
		st.set_corner_radius_all(6)
		add_theme_stylebox_override("panel", st)
		var l := Label.new()
		l.text = "✕\nмусор"
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)

	func _can_drop_data(_p: Vector2, d) -> bool:
		return d is Dictionary and d.has("inv")

	func _drop_data(_p: Vector2, d) -> void:
		hud.trash(d.inv, int(d.index), bool(d.get("half", false)))


## Карточка здания в меню стройки: её можно перетащить в панель быстрого доступа, ПКМ — туда же.
static func plural(n: int, one: String, few: String, many: String) -> String:
	var m := n % 100
	if m >= 11 and m <= 14:
		return many
	match n % 10:
		1: return one
		2, 3, 4: return few
	return many


## 1.0.8: значок замка (рисуется сам — не зависит от шрифта с эмодзи).
class LockIcon extends Control:
	var col := Color(1.0, 0.78, 0.45)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_arc(Vector2(w * 0.5, h * 0.45), w * 0.3, PI, TAU, 10, col, 2.0, true)
		draw_line(Vector2(w * 0.2, h * 0.45), Vector2(w * 0.2, h * 0.55), col, 2.0)
		draw_line(Vector2(w * 0.8, h * 0.45), Vector2(w * 0.8, h * 0.55), col, 2.0)
		draw_rect(Rect2(w * 0.08, h * 0.52, w * 0.84, h * 0.46), col)
		draw_circle(Vector2(w * 0.5, h * 0.72), w * 0.09, Color(0.1, 0.1, 0.12))


class BuildCard extends Button:
	var bid := ""
	var hud

	func _make_custom_tooltip(for_text: String) -> Object:
		return UI.tip_panel(for_text, UI.building_icon(bid, 56)) if bool(UI.st("rich_tips")) else null

	func _get_drag_data(_p: Vector2):
		set_drag_preview(UI.building_icon(bid, 48))
		return {"build": bid}

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			hud.pin_build_free(bid)
			accept_event()



## График энергосети: выработка (зелёная), потребление (оранжевая), запас аккумуляторов (синяя).
class PowerGraph extends Control:
	var hud
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t < 0.25:
			return
		t = 0.0
		var b = hud.bld
		if b == null or b.dead:
			return
		var f = hud.game.factory
		var ni: Dictionary = f.net_info(b)
		var lbl: RichTextLabel = get_meta("lbl")
		var rb: Button = get_meta("reset")
		rb.visible = bool(ni.get("tripped", false))
		if ni.is_empty():
			lbl.text = "[color=#ff6b5a]%s[/color]" % DB.tx("not_in_net", "Не подключено к сети")
		else:
			var s := "%s: [color=#7dff5a]%d[/color] / %s %d\n%s: [color=#ffb14a]%d[/color]\n%s: [color=#6ab8ff]%d[/color] / %d" % [
				DB.tx("p_supply", "Выработка"), int(ni.supply), DB.tx("p_max", "макс."), int(ni.get("gen_max", 0)),
				DB.tx("p_demand", "Потребление"), int(ni.demand), DB.tx("p_stored", "Запас"), int(ni.stored), int(ni.cap)]
			if ni.get("tripped", false):
				s += "\n[color=#ff6b5a]%s[/color]" % DB.tx("p_tripped", "ВЫБИЛО ПРОБКИ")
			if f.wired():
				s += "\n%s: %d / %d" % [DB.tx("w_conn2", "Провода"), f.wire_count(b), f.connectors(b)]
			elif f.station_cap(b) > 0.0:
				s += "\n%s: [color=#ffe08a]%d[/color] / %d · %s %d" % [DB.tx("st_give", "Станция отдаёт"), int(b.bstate.get("st_load", 0.0)), int(f.station_cap(b)), DB.tx("st_rad", "радиус"), int(f.station_radius(b))]
				if int(b.bstate.get("st_short", 0)) > 0:
					s += "\n[color=#ffa040]%s: %d[/color]" % [DB.tx("st_short", "Не хватило мощности зданиям"), int(b.bstate.get("st_short", 0))]
			lbl.text = s
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.08, 0.9))
		var b = hud.bld
		if b == null:
			return
		var h: Array = hud.game.factory.net_info(b).get("hist", [])
		if h.size() < 2:
			draw_string(ThemeDB.fallback_font, Vector2(8, size.y * 0.5 + 5), DB.tx("p_wait", "Собираю данные..."), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
			return
		var top := 1.0
		for e in h:
			top = maxf(top, maxf(e[0], e[1]))
		top *= 1.15
		var top_s := 1.0
		for e in h:
			top_s = maxf(top_s, e[2])
		for k in [[2, Color(0.42, 0.72, 1.0, 0.8), top_s], [0, Color(0.49, 1.0, 0.35), top], [1, Color(1.0, 0.69, 0.29), top]]:
			var pts := PackedVector2Array()
			for i in h.size():
				var x := size.x * i / float(maxi(1, h.size() - 1))
				var y := size.y - 3.0 - (size.y - 6.0) * float(h[i][k[0]]) / float(k[2])
				pts.append(Vector2(x, y))
			draw_polyline(pts, k[1], 2.0, true)


# ---------------------------------------------------------------- 14.10: объединение зданий

var offer_box: PanelContainer
var _offer_cur = null


## 15.5: что составное отдаёт на ленту: «Всё готовое» или только отмеченные предметы.
func _out_filter(v: VBoxContainer, b) -> void:
	var fz = game.factory.fz
	var cands: Array = fz.out_candidates(b)
	if cands.is_empty():
		return
	v.add_child(UI.section("На ленту выходит"))
	var cur: Array = Fusion.out_filter(b)
	var row := UI.hbox(8)
	var all := UI.button("✔ Всё готовое" if cur.is_empty() else "Всё готовое", func():
		var nc: Dictionary = b.cfg.duplicate(true)
		nc.erase("out_items")
		game.cmd("bcfg", {"b": b, "cfg": nc})
		open_building(b), "То, что не нужно машинам дальше по цепочке")
	row.add_child(all)
	row.add_child(UI.small("или отметьте только нужное:"))
	v.add_child(row)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	for id in cands:
		var on: bool = id in cur
		var bt := Button.new()
		bt.toggle_mode = true
		bt.button_pressed = on
		bt.focus_mode = Control.FOCUS_NONE
		bt.icon = ModelLib.item_icon(id)
		bt.add_theme_constant_override("icon_max_width", 24)
		bt.text = ("✔ " if on else "") + DB.item_name(id)
		bt.tooltip_text = "Отдавать «%s» на ленту" % DB.item_name(id)
		var iid: String = id
		bt.toggled.connect(func(pressed):
			var nc: Dictionary = b.cfg.duplicate(true)
			var l: Array = (nc.get("out_items", []) as Array).duplicate()
			if pressed and not iid in l:
				l.append(iid)
			elif not pressed:
				l.erase(iid)
			if l.is_empty():
				nc.erase("out_items")
			else:
				nc["out_items"] = l
			game.cmd("bcfg", {"b": b, "cfg": nc})
			open_building(b))
		fl.add_child(bt)
	v.add_child(fl)
	if not cur.is_empty():
		v.add_child(_wrap(UI.small("Остальное готовое идёт во встроенный ящик, а если ящика нет — ждёт (или уничтожается, если «Лишнее: уничтожать»).")))


## Окошко «Объединить?» над экраном: появилось после постройки рядом с подходящим зданием.
func _update_offer(delta: float) -> void:
	var fz = game.factory.fz
	if fz == null:
		return
	if _offer_cur != null and (not _offer_cur in fz.offers or _offer_cur.a.dead or _offer_cur.b.dead):
		fz.offers.erase(_offer_cur)
		_offer_cur = null
		if offer_box:
			offer_box.visible = false
	if _offer_cur == null and not fz.offers.is_empty():
		_offer_cur = fz.offers[0]
		_build_offer(_offer_cur)
	if _offer_cur != null:
		_offer_cur.t += delta
		if _offer_cur.t > float(Fusion.cfg().get("ask_time", 20.0)):
			fz.decline(_offer_cur)


func _build_offer(o: Dictionary) -> void:
	if offer_box == null:
		offer_box = PanelContainer.new()
		var st := UI.theme().get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
		st.border_color = UI.ACCENT
		st.set_border_width_all(2)
		st.border_width_top = 5
		offer_box.add_theme_stylebox_override("panel", st)
		root.add_child(offer_box)
	UI.clear(offer_box)
	offer_box.visible = true
	var v := UI.vbox(8)
	offer_box.add_child(v)
	var head := UI.hbox(10)
	var ia := UI.building_icon(o.a.type, 48)
	head.add_child(ia)
	head.add_child(UI.title("+", 26))
	head.add_child(UI.building_icon(o.b.type, 48))
	var tl := UI.title("ОБЪЕДИНИТЬ ЗДАНИЯ?" if o.kind in ["level", "sub"] else "СОБРАТЬ В ОДНО ЗДАНИЕ?", 19)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tl)
	v.add_child(head)
	var txt := UI.label(game.factory.fz.offer_text(o), 15)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(UI.ws(460), 0)
	v.add_child(txt)
	var row := UI.hbox(10)
	row.add_child(UI.spacer())
	if o.kind == "choice":
		# 15.4: вторая такая же — встроить отдельно или объединить с уже встроенной
		var sep := UI.button("Две отдельные", func():
			game.cmd("fuse", {"a": o.a, "b": o.b, "kind": "combo"})
			game.factory.fz.offers.erase(o), "Встроить вторую: займёт место в здании, у каждой свой рецепт")
		row.add_child(sep)
	var yes := UI.button("Объединить" if o.kind == "level" else ("Одна объединённая" if o.kind in ["choice", "sub"] else "Встроить"), func():
		game.cmd("fuse", {"a": o.a, "b": o.b, "kind": "sub" if o.kind == "choice" else o.kind})
		game.factory.fz.offers.erase(o))
	yes.add_theme_stylebox_override("normal", UI.theme().get_stylebox("pressed", "Button"))
	yes.add_theme_color_override("font_color", UI.theme().get_color("font_pressed_color", "Button"))
	row.add_child(yes)
	row.add_child(UI.button("Не надо", func(): game.factory.fz.decline(o)))
	v.add_child(row)
	offer_box.reset_size()
	var vs := root.get_viewport_rect().size
	offer_box.position = Vector2((vs.x - offer_box.size.x) * 0.5, 96)


## В окне здания: уровень объединения, с кем можно объединиться, что встроено (с рецептами и ячейками).
func _fusion_panel(w: Win) -> void:
	var fz = game.factory.fz
	if fz == null:
		return
	var b = bld
	var v := UI.vbox(6)
	if b.lvl > 1:
		var lv := UI.hbox(8)
		lv.add_child(UI.label("Объединение %d из %d" % [b.lvl, Fusion.max_level()], 16, UI.ACCENT))
		lv.add_child(UI.small("· сила ×%s · прочность ×%s" % [Fusion._num(b.mult), Fusion._num(1.0 + 0.5 * (b.lvl - 1))]))
		v.add_child(lv)
	# с кем рядом можно объединиться
	var opts := []
	for n in fz.neighbors(b):
		if fz.level_why(b, n) == "":
			opts.append([n, "level"])
		elif n.type != b.type and fz.combo_why(b, n) == "":
			opts.append([n, "combo"])
		if n.type != b.type and not b.subs.is_empty() and fz.sub_twin(b, n) != null:
			opts.append([n, "sub"])
	for op in opts:
		var n = op[0]
		var kind: String = op[1]
		var txt := ("Объединить с соседним «%s» → Объединение %d" % [fz.name_of(n), b.lvl + 1]) if kind == "level" else ("Встроить «%s» (рядом)" % fz.name_of(n) if fz.pick_host(b, n) == b else "Встроить в «%s» (рядом)" % fz.name_of(n))
		if kind == "sub":
			txt = "Объединить «%s» (рядом) с уже встроенной → Объединение %d" % [fz.name_of(n), fz.sub_twin(b, n).lvl + 1]
		elif kind == "combo" and fz.sub_twin(b, n) != null:
			txt = "Встроить «%s» (рядом) второй отдельной" % fz.name_of(n)
		var bt := UI.button(txt, func():
			game.cmd("fuse", {"a": b, "b": n, "kind": kind})
			if not b.dead:
				w.set_meta("built_for", null)
			else:
				close("building"), Fusion.module_hint(n) if kind == "combo" else "Сила ×%s" % Fusion._num(Fusion.mult_for(b.lvl + 1)))
		v.add_child(bt)
	if opts.is_empty() and b.lvl < Fusion.max_level() and fz.levels_on() and fz.can_level(b) and b.subs.is_empty() and not Drones.is_station(b):
		var hint := UI.small("Поставьте рядом ещё «%s»%s — их можно объединить в одно, в %s раза сильнее." % [DB.building(b.type).get("name", b.type), (" (тоже «Объединение %d»)" % b.lvl) if b.lvl > 1 else "", Fusion._num(Fusion.mult_for(b.lvl + 1))])
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(UI.ws(460), 0)
		v.add_child(hint)
	# встроенные
	if not b.subs.is_empty():
		v.add_child(UI.section("Сборная линия · %d из %d зданий" % [fz.parts(b), Fusion.max_parts()]))
		var ch := UI.label(fz.chain_text(b), 14, Color(0.7, 0.9, 1.0))
		ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch.custom_minimum_size = Vector2(UI.ws(460), 0)
		v.add_child(ch)
		if Fusion.role(b) != "power":
			var er := UI.hbox(8)
			er.add_child(UI.small("Энергия"))
			var eb := UI.bar(er, Color(1, 0.85, 0.3), 8)
			eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			eb.value = b.csat * 100.0
			v.add_child(er)
		for s in b.subs:
			var card := TipCard.new()
			card.tip_building = s.type
			card.tooltip_text = UI.building_tip(s.type)
			var row := UI.hbox(10)
			card.add_child(row)
			row.add_child(UI.building_icon(s.type, 44))
			var cv := UI.vbox(3)
			cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var nr := UI.hbox(8)
			var nl := UI.label(fz.name_of(s), 15)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nr.add_child(nl)
			var sub_d = s
			nr.add_child(UI.button("Убрать", func():
				game.cmd("detach", {"h": b, "s": sub_d})
				open_building(b), "Убрать только это встроенное здание: стоимость и содержимое вернутся в рюкзак, остальное продолжит работать"))
			cv.add_child(nr)
			cv.add_child(UI.small(Fusion.module_hint(s)))
			if s.beh == "crafter":
				var ob := OptionButton.new()
				ob.focus_mode = Control.FOCUS_NONE
				ob.add_item("Авто (по входящему сырью)")
				ob.set_item_metadata(0, "")
				var ids := DB.recipes_for(s.p("station", ""))
				for i in ids.size():
					ob.add_item(_recipe_line(ids[i]))
					ob.set_item_metadata(i + 1, ids[i])
					if ids[i] == s.recipe:
						ob.select(i + 1)
				var sub = s
				ob.item_selected.connect(func(i): game.cmd("recipe", {"b": sub, "rid": ob.get_item_metadata(i)}))
				cv.add_child(ob)
			# 1.1.20: встроенный ящик — все ячейки (раньше видно было только 8 из 20, и казалось, что в ящике мало)
			var sl = HFlowContainer.new() if s.beh == "storage" else UI.hbox(4)
			if sl is HFlowContainer:
				sl.add_theme_constant_override("h_separation", 4)
				sl.add_theme_constant_override("v_separation", 4)
			for k in ["inv", "fuel", "out"]:
				var inv: Inventory = s.get(k)
				if inv == null:
					continue
				for i in (inv.size() if s.beh == "storage" else mini(inv.size(), 8)):
					var slot := Slot.new()
					slot.setup(inv, i, self, 40)
					sl.add_child(slot)
					bld_slots.append(slot)
				sl.add_child(UI.label("·", 14, UI.DIM))
			if sl.get_child_count() > 0:
				cv.add_child(sl)
			row.add_child(cv)
			v.add_child(card)
		if Fusion.chest_of(b) != null:
			_chest_filter(v, b, w)
		_out_filter(v, b)
		var tip := UI.small("Разобрать (X) — вернутся все ресурсы и содержимое всех встроенных.")
		v.add_child(tip)
	if b.out != null and b.beh in ["miner", "crafter"] or not b.subs.is_empty():
		_overflow_row(v, b, w)
	if v.get_child_count() > 0:
		var pnl := UI.panel(0.35)
		pnl.add_child(v)
		w.body.add_child(pnl)


## Изменить одну настройку здания (cfg) и перестроить окно.
func _set_bcfg(b, key: String, val, w: Win) -> void:
	var c: Dictionary = b.cfg.duplicate(true)
	if val == null:
		c.erase(key)
	else:
		c[key] = val
	game.cmd("bcfg", {"b": b, "cfg": c})
	w.set_meta("built_for", null)


## Встроенный ящик: что в него складывать.
func _chest_filter(v: VBoxContainer, b, w: Win) -> void:
	var row := UI.hbox(8)
	row.add_child(UI.label("В ящик складывать:", 14))
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	var modes := [["auto", "Только готовое (авто)"], ["all", "Всё подряд"], ["list", "Только выбранное"]]
	for i in modes.size():
		ob.add_item(modes[i][1])
		if modes[i][0] == Fusion.chest_mode(b):
			ob.select(i)
	ob.tooltip_text = "Только готовое — то, что машинам дальше не нужно (руда, которую печь не успела переплавить, остаётся в буре).\nВсё подряд — как раньше.\nТолько выбранное — отметьте предметы ниже."
	ob.item_selected.connect(func(i): _set_bcfg(b, "chest", modes[i][0], w))
	row.add_child(ob)
	v.add_child(row)
	if Fusion.chest_mode(b) != "list":
		return
	var chosen: Array = b.cfg.get("chest_items", []) if b.cfg.get("chest_items", []) is Array else []
	var cand: Array = chosen.duplicate()
	var add := func(id: String):
		if id != "" and not id in cand and DB.data.items.has(id):
			cand.append(id)
	if b.beh == "miner":
		add.call(b.recipe)
	for inv in [b.out, Fusion.chest_of(b).inv]:
		if inv != null:
			for sl in inv.slots:
				if sl != null:
					add.call(sl.id)
	for st in [b] + b.subs:
		for rid in [st.recipe, st.last_rid, st.crafting]:
			var r: Dictionary = DB.data.recipes.get(str(rid), {})
			for k in r.get("out", {}):
				add.call(k)
	if cand.is_empty():
		v.add_child(_wrap(UI.small("Пусть линия немного поработает — здесь появятся предметы, которые она делает.")))
		return
	var fl := HFlowContainer.new()
	for id in cand:
		var on: bool = id in chosen
		var bt := Button.new()
		bt.toggle_mode = true
		bt.button_pressed = on
		bt.focus_mode = Control.FOCUS_NONE
		bt.text = ("✓ " if on else "") + DB.item_name(id)
		bt.tooltip_text = "Нажмите, чтобы %s" % ("убрать" if on else "складывать это в ящик")
		bt.toggled.connect(func(pressed):
			var l: Array = chosen.duplicate()
			if pressed and not id in l:
				l.append(id)
			elif not pressed:
				l.erase(id)
			_set_bcfg(b, "chest_items", l, w))
		fl.add_child(bt)
	v.add_child(fl)
	v.add_child(_wrap(UI.small("Не отмеченное идёт на ленту перед зданием (или его заберут дроны), а если некуда — см. «Когда выход полон».")))


## Что делать с лишним: ждать (здание встаёт) или уничтожать.
func _overflow_row(v: VBoxContainer, b, w: Win) -> void:
	var row := UI.hbox(8)
	row.add_child(UI.label("Когда выход полон:", 14))
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	var modes := [["wait", "Ждать — здание встаёт"], ["trash", "Уничтожать лишнее"]]
	for i in modes.size():
		ob.add_item(modes[i][1])
		if modes[i][0] == Fusion.overflow_of(b):
			ob.select(i)
	ob.tooltip_text = "Ждать — как обычно: здание остановится, пока не заберут готовое.\nУничтожать — лишнее исчезает, здание работает дальше.\nЛучше всего — поставить ленту или станцию дронов, чтобы лишнее увозили."
	ob.item_selected.connect(func(i): _set_bcfg(b, "overflow", modes[i][0], w))
	row.add_child(ob)
	if int(b.trashed) > 0:
		row.add_child(UI.small("уничтожено: %d" % int(b.trashed)))
	v.add_child(row)


## Станция дронов (или составное со станцией на крыше): дроны и маршруты.
## 14.23: тонкая настройка (необязательно): ручка 0..100 и индикатор эффективности.
func _tuning_panel(w: Win) -> void:
	for m in ["tune_ui", "ufo_ui", "mega_ui"]:
		if w.has_meta(m):
			w.remove_meta(m)
	if bld == null or not Tuning.on():
		return
	# 1.3: у составного здания — ручка у каждой встроенной машины со своей настройкой (ветряк, печь…)
	var list := [bld] + (bld.subs if bld.subs is Array else [])
	var first := true
	for b in list:
		if Tuning.kind_of(b) == "":
			continue
		_tuning_one(w, b, first, b != bld)
		first = false


func _tuning_one(w: Win, b, first: bool, sub: bool) -> void:
	var kid := Tuning.kind_of(b)
	var kd := Tuning.kind(kid)
	var v := UI.vbox(4)
	var head := "Тонкая настройка: " + str(kd.get("name", kid))
	if sub:
		head += " (" + str(DB.building(b.type).get("name", b.type)) + ")"
	v.add_child(UI.section(head))
	v.add_child(_wrap(UI.small(Lang.t(str(kd.get("desc", ""))) + " " + Lang.t("Не обязательно: на 50 здание работает как обычно."))))
	var r := UI.hbox(8)
	r.add_child(UI.label(str(kd.get("lo", "")), 12, UI.DIM))
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 1
	sl.value = Tuning.value(b)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(UI.ws(240), 0)
	sl.tooltip_text = str(kd.get("knob", "Настройка"))
	r.add_child(sl)
	r.add_child(UI.label(str(kd.get("hi", "")), 12, UI.DIM))
	var vl := UI.label("%d" % int(sl.value), 14)
	vl.custom_minimum_size = Vector2(36, 0)
	r.add_child(vl)
	v.add_child(r)
	var info := UI.rich(Tuning.info(b), 13)
	info.fit_content = true
	sl.value_changed.connect(func(x):
		var nc: Dictionary = b.cfg.duplicate(true)
		nc["tune"] = x
		game.cmd("bcfg", {"b": b, "cfg": nc})
		vl.text = "%d" % int(x)
		info.text = Tuning.info(b))
	if game.tech.done.has("calibration_" + str(b.type)):
		v.add_child(UI.small("Заводская калибровка изучена для этого типа"))
	elif Tuning.hinted():
		var price := int(Tuning.cfg().get("calibration_credits", 600))
		var points := int(Tuning.cfg().get("calibration_research", 18))
		var study := UI.button("Изучить калибровку · %d ОИ · %d кр" % [points, price], func():
			if game.tech.study_calibration(b):
				sl.value = Tuning.value(b)
				open_building(bld))
		study.disabled = game.tech.research < points or game.credits < price
		study.tooltip_text = "Новые здания этого типа начинают работу в золотой зоне"
		v.add_child(study)
	v.add_child(info)
	if first and not sub:
		w.set_meta("tune_ui", info)
	w.body.add_child(v)


## 1.1.15: канал штаба — направление («В штаб» / «Из штаба») и какие предметы забирать из штаба.
func _link_panel(w: Win) -> void:
	var b = bld
	if b == null or b.beh != "hq_link":
		return
	var f = game.factory
	var lc: Dictionary = Factory.link_cfg()
	var v := UI.vbox(4)
	v.add_child(UI.section("Канал штаба"))
	var take: bool = Factory.link_mode(b) == "take"
	var row := UI.hbox(6)
	var set_mode := func(m: String):
		var nc: Dictionary = b.cfg.duplicate(true)
		nc["mode"] = m
		game.cmd("bcfg", {"b": b, "cfg": nc})
		_build_building_body(w)
	var bs := UI.button("В штаб", func(): set_mode.call("send"), "Всё, что приходит на вход, сразу появляется в штабе")
	var bt := UI.button("Из штаба", func(): set_mode.call("take"), "Выбранные предметы забираются из штаба и выходят на ленту")
	for pair in [[bs, not take], [bt, take]]:
		if pair[1]:
			pair[0].add_theme_stylebox_override("normal", UI.theme().get_stylebox("pressed", "Button"))
			pair[0].add_theme_color_override("font_color", UI.theme().get_color("font_pressed_color", "Button"))
	row.add_child(bs)
	row.add_child(bt)
	v.add_child(row)
	var every := int(lc.get("loss_every", 2))
	if float(lc.get("power_per_cell", 3)) <= 0.0:
		v.add_child(_wrap(UI.small("Теряется каждый %d-й предмет. Энергия: %d. %s" % [every, int(b.p("power", 0)),
			"Скорость: до %d в минуту." % int(lc.get("take_per_min", 60)) if take else "Скорость — как у подводящей ленты."])))
	else: v.add_child(_wrap(UI.small("Теряется каждый %d-й предмет. Энергия: %d (клеток до штаба × %d). %s" % [every, int(b.p("power", 0)), int(lc.get("power_per_cell", 3)),
		"Скорость: до %d в минуту." % int(lc.get("take_per_min", 60)) if take else "Скорость — как у подводящей ленты."])))
	if take:
		var items: Array = (b.cfg.get("items", []) as Array).duplicate() if b.cfg.get("items") is Array else []
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 4)
		for it in items:
			var cb := UI.button("%s ✕" % DB.item_name(str(it)), func():
				var nc: Dictionary = b.cfg.duplicate(true)
				var arr: Array = (nc.get("items", []) as Array).duplicate()
				arr.erase(it)
				nc["items"] = arr
				game.cmd("bcfg", {"b": b, "cfg": nc})
				_build_building_body(w), "Убрать из списка")
			chips.add_child(cb)
		if items.is_empty():
			chips.add_child(UI.small("Выберите, что забирать из штаба:"))
		v.add_child(chips)
		var home: Inventory = f.link_home(b)[0]   # 1.1.15: в «отдельных базах» — склад своей базы
		if items.size() < int(lc.get("max_items", 5)) and home != null:
			var ob := OptionButton.new()
			ob.add_item("+ добавить предмет из штаба…")
			var ids: Array = home.totals().keys()
			ids.sort_custom(func(a1, b1): return DB.item_name(a1) < DB.item_name(b1))
			for id in ids:
				if not id in items:
					ob.add_item("%s (%d)" % [DB.item_name(id), home.count(id)])
					ob.set_item_metadata(ob.item_count - 1, id)
			ob.item_selected.connect(func(i):
				if i <= 0:
					return
				var nc: Dictionary = b.cfg.duplicate(true)
				var arr: Array = (nc.get("items", []) as Array).duplicate() if nc.get("items") is Array else []
				arr.append(str(ob.get_item_metadata(i)))
				nc["items"] = arr
				nc["mode"] = "take"
				game.cmd("bcfg", {"b": b, "cfg": nc})
				_build_building_body(w))
			v.add_child(ob)
	w.body.add_child(v)


## B-11: машины, которые едят энергию только пока работают (канал штаба, блочные здания).
func _eat_text(b) -> String:
	var always: bool = (Factory.power_constant() and b.beh in ["miner", "crafter"]) or b.beh == "turret" or (not b.blk and b.beh in ["decor", "storage"]) \
		or float(b.p("shield_radius", 0)) > 0.0 or float(b.p("heat", 0)) != 0.0 or b.p("defense", "") != ""
	return "Ест %s ед. энергии всё время, пока подключено и включено." if always else "Ест %s ед. энергии, пока работает."


## 15.6: рабочая мощность 0–100% и кнопка «Выключить»: меньше мощность — меньше энергии и продукции.
func _clock_panel(w: Win) -> void:
	var b = bld
	if b == null or b.host != null or b.beh in ["hq", "battery", "belt", "pole"] or float(b.p("power", 0)) <= 0.0 and b.beh != "generator":
		return
	if not bool(DB.setting("power_clock", true)):
		return
	var gen: bool = b.beh == "generator"
	var v := UI.vbox(4)
	v.add_child(UI.section("Рабочая мощность"))
	var r := UI.hbox(8)
	var sl := HSlider.new()
	sl.visible = not Factory.on_off_only(b)   # такие здания работают только целиком
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = float(b.cfg.get("clock", 100.0))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(UI.ws(220), 0)
	sl.tooltip_text = "Выработка и расход топлива пропорциональны" if gen else "Потребление энергии и выход продукции пропорциональны"
	r.add_child(sl)
	var vl := UI.label("%d%%" % int(sl.value), 14)
	vl.visible = sl.visible
	vl.custom_minimum_size = Vector2(48, 0)
	r.add_child(vl)
	var off: bool = b.cfg.get("off", false)
	var ob := UI.button("Включить" if off else "Выключить", func():
		var nc: Dictionary = b.cfg.duplicate(true)
		if nc.get("off", false):
			nc.erase("off")
		else:
			nc["off"] = true
		game.cmd("bcfg", {"b": b, "cfg": nc})
		open_building(b), "Выключенное здание не ест энергию и не работает")
	r.add_child(ob)
	v.add_child(r)
	var hint := "Выключено: не работает и не ест энергию." if off else ("Даёт %s ед. энергии." % Fusion._num(snappedf(float(b.p("power", 0)) * b.mult * Factory.clock(b), 0.1)) if gen else (_eat_text(b) % Fusion._num(snappedf(float(b.p("power", 0)) * Fusion.power_k(b) * Factory.clock(b), 0.1))))
	var hl := UI.small(hint)
	v.add_child(hl)
	sl.value_changed.connect(func(x):
		var nc: Dictionary = b.cfg.duplicate(true)
		nc["clock"] = x
		game.cmd("bcfg", {"b": b, "cfg": nc})
		vl.text = "%d%%" % int(x)
		if not gen:
			hl.text = _eat_text(b) % Fusion._num(snappedf(float(b.p("power", 0)) * Fusion.power_k(b) * x / 100.0, 0.1)))
	w.body.add_child(v)


## 14.23: посадочная площадка НЛО: курс на сегодня, заказ, журнал.
func _ufo_panel(w: Win) -> void:
	var b = bld
	if not Starworks.is_pad(b) or game.star == null:
		return
	var sw = game.star
	var s := Starworks.st(b)
	var v := UI.vbox(6)
	v.add_child(UI.section("Обмен с НЛО · день %d" % sw.day()))
	var eta := UI.label(sw.eta_text(b), 14, UI.ACCENT)
	v.add_child(eta)
	w.set_meta("ufo_ui", eta)
	v.add_child(_wrap(UI.small("«Вход» — товары на обмен (НЛО заберёт до %d шт.). «Выход» — что привёз НЛО. Курс меняется каждый день: ловите выгодный." % int(Starworks.ucfg().get("capacity", 400)))))
	var grid := GridContainer.new()
	grid.columns = 3
	for id in Starworks.goods():
		var q: Array = sw.quote(id)
		var y: Array = sw.quote(id, maxi(1, sw.day() - 1))
		grid.add_child(UI.label(DB.item_name(id), 14))
		grid.add_child(UI.label("= %d %s" % [int(q[1]), DB.item_name(str(q[0]))], 14))
		var tr := "▲" if int(q[1]) > int(y[1]) else ("▼" if int(q[1]) < int(y[1]) else "•")
		grid.add_child(UI.label(tr, 14, Color(1, 0.5, 0.4) if tr == "▲" else (Color(0.5, 1, 0.5) if tr == "▼" else UI.DIM)))
	v.add_child(grid)
	v.add_child(UI.section("Заказ (что привезти)"))
	var ids: Array = Starworks.goods().keys()
	var orders: Array = (s.orders as Array).duplicate(true)
	var push := func(): game.cmd("bstate", {"b": b, "key": "orders", "val": orders.duplicate(true)})
	for i in orders.size():
		var o: Dictionary = orders[i]
		var r := UI.hbox(6)
		var ob := OptionButton.new()
		for gi in ids.size():
			ob.add_item(DB.item_name(ids[gi]), gi)
		ob.selected = maxi(0, ids.find(str(o.get("id", ""))))
		ob.item_selected.connect(func(ix):
			o["id"] = ids[ix]
			push.call())
		r.add_child(ob)
		var sb := SpinBox.new()
		sb.min_value = 0
		sb.max_value = 9999
		sb.value = int(o.get("n", 1))
		sb.value_changed.connect(func(x):
			o["n"] = int(x)
			push.call())
		r.add_child(sb)
		r.add_child(UI.button("✕", func():
			orders.erase(o)
			push.call()
			w.set_meta("built_for", null)))
		v.add_child(r)
	v.add_child(UI.button("+ Добавить заказ", func():
		orders.append({"id": ids[0] if not ids.is_empty() else "", "n": 10})
		push.call()
		w.set_meta("built_for", null)))
	var lg: Array = s.get("log", [])
	if not lg.is_empty():
		var e: Dictionary = lg[0]
		v.add_child(_wrap(UI.small("Последний прилёт (день %d): привёз %s; забрал %s; купил %s." % [int(e.day), Starworks._list(e.got), Starworks._list(e.took), Starworks._list(e.bought)])))
	w.body.add_child(v)


## 14.23: инженерный стол — сетка 4×4 из предметов рюкзака.
func _pattern_panel(w: Win) -> void:
	var b = bld
	if not b.p("eng_table", false) or game.star == null:
		return
	var v := UI.vbox(6)
	v.add_child(UI.section("Узор 4×4"))
	v.add_child(_wrap(UI.small("Выберите предмет для каждой клетки (берутся из рюкзака). Индикатор показывает, насколько раскладка похожа на лучший из узоров. Верный узор навсегда открывает улучшенный рецепт.")))
	var cells: Array = b.cfg.get("cells", [])
	while cells.size() < 16:
		cells.append("")
	b.cfg["cells"] = cells
	var have := {}
	for sl in game.player.inv.slots:
		if sl != null:
			have[sl.id] = true
	for c in cells:
		if str(c) != "":
			have[str(c)] = true
	var ids: Array = have.keys()
	ids.sort()
	var grid := GridContainer.new()
	grid.columns = 4
	var hint := UI.label("", 14, UI.ACCENT)
	var upd := func():
		var best := 0
		var bp := {}
		for p in Starworks.patterns():
			if game.tech.patterns.has(str(p.id)):
				continue
			var m := Starworks.match_count(p, cells)
			if m > best:
				best = m
				bp = p
		hint.text = ("Совпало %d из %d клеток" % [best, Starworks.filled(bp)]) if not bp.is_empty() else "Все узоры собраны!"
	for i in 16:
		var ob := OptionButton.new()
		ob.add_item("—", 0)
		for j in ids.size():
			ob.add_item(DB.item_name(ids[j]), j + 1)
		ob.selected = ids.find(str(cells[i])) + 1
		ob.custom_minimum_size = Vector2(UI.ws(120), 0)
		ob.clip_text = true
		ob.item_selected.connect(func(ix):
			cells[i] = "" if ix == 0 else ids[ix - 1]
			upd.call())
		grid.add_child(ob)
	v.add_child(grid)
	v.add_child(hint)
	upd.call()
	var msg := UI.label("", 13, Color(1, 0.6, 0.4))
	v.add_child(UI.button("Собрать узор", func():
		var rr = game.cmd("pattern", {"cells": cells.duplicate()})
		var res: String = str(rr) if rr != null else ("Отправлено хозяину игры: если узор верный, рецепт откроется у всех." if Net.is_client() else "")
		msg.text = res
		if res == "" and not Net.is_client():
			w.set_meta("built_for", null), "Тратит по одному предмету с каждой заполненной клетки"))
	v.add_child(msg)
	var known := []
	for p in Starworks.patterns():
		var on: bool = game.tech.patterns.has(str(p.id))
		known.append(("✓ " if on else "? ") + Lang.t(str(p.get("name", p.id))) + ("" if on else " — " + Lang.t(str(p.get("hint", "")))))   # A-4 r4: части переводим до склейки
	v.add_child(_wrap(UI.small("\n".join(known))))
	w.body.add_child(v)


## 14.23: мегапроект «Звёздные врата».
func _mega_panel(w: Win) -> void:
	var b = bld
	if not Starworks.is_mega(b) or game.star == null:
		return
	var v := UI.vbox(6)
	v.add_child(UI.section("Орбитальный терминал" if b.type == "orbital_elevator" else "Мегапроект"))
	var t := UI.rich(game.star.mega_text(b), 14)
	t.fit_content = true
	v.add_child(t)
	w.set_meta("mega_ui", t)
	if b.type == "orbital_elevator":
		if not b.bstate.get("surveyed", false):
			v.add_child(UI.button("Обследовать терминал", func():
				b.bstate["surveyed"] = true
				open_building(b)))
		elif game.star.orbital_order(b).is_empty():
			var missions: Array = DB.setting("orbital_terminal", {}).get("missions", [])
			for i in missions.size():
				var mission: Dictionary = missions[i]
				v.add_child(UI.button("%s · %d кр" % [mission.name, int(mission.credits)], func():
					b.bstate["mission"] = i
					open_building(b)))
	v.add_child(_wrap(UI.small("Подайте компоненты через грузовой вход или положите в склад терминала.")))
	w.body.add_child(v)


## 14.22: пульт АЭС — стержни, загрузка ТВЭЛов, насосы, АЗ-5.
func _reactor_panel(w: Win) -> void:
	if w.has_meta("reactor_ui"):
		w.remove_meta("reactor_ui")
	var b = bld
	if not Nuclear.is_reactor(b):
		return
	var s := Nuclear.st(b)
	var v := UI.vbox(6)
	v.add_child(UI.section("Пульт АЭС"))
	var info := UI.rich("", 14)
	info.fit_content = true
	v.add_child(info)
	var tb := UI.bar(v, Color(1, 0.6, 0.3), 10)
	tb.max_value = float(Nuclear.c("melt_t", 1100.0))
	tb.tooltip_text = "Температура активной зоны"
	v.add_child(UI.small("Вода в контуре"))
	var wb := UI.bar(v, Color(0.35, 0.7, 1.0), 6)
	wb.max_value = Nuclear.water_buf()
	w.set_meta("reactor_ui", [info, tb, wb])
	var slider := func(title: String, key: String, tip: String) -> HBoxContainer:
		var r := UI.hbox(8)
		var l := UI.label(title, 14)
		l.custom_minimum_size = Vector2(UI.ws(190), 0)
		r.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.step = 1
		sl.value = roundf(float(s[key]) * 100.0)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size = Vector2(UI.ws(200), 0)
		sl.tooltip_text = tip
		r.add_child(sl)
		var vl := UI.label("%d%%" % int(sl.value), 14)
		vl.custom_minimum_size = Vector2(48, 0)
		r.add_child(vl)
		sl.value_changed.connect(func(x):
			game.cmd("bstate", {"b": b, "key": key, "val": x / 100.0})
			vl.text = "%d%%" % int(x))
		return r
	v.add_child(slider.call("Стержни опущены", "rods_set", "100% — стержни полностью в зоне: реакция заглушена. Чем выше поднимаете, тем больше тепла и энергии — и тем горячее."))
	v.add_child(slider.call("Насосы охлаждения", "pump", "Сколько воды гнать через зону. Больше воды — сильнее охлаждение и больше пара для турбин, но и расход воды больше."))
	var lr := UI.hbox(8)
	var ll := UI.label("ТВЭЛов в зоне", 14)
	ll.custom_minimum_size = Vector2(UI.ws(190), 0)
	lr.add_child(ll)
	var sb := SpinBox.new()
	sb.min_value = 0
	sb.max_value = Nuclear.slots(b)
	sb.value = int(s.load)
	sb.tooltip_text = "Сколько ТВЭЛов опустить в активную зону (каждый греет). Сами ТВЭЛы кладите в реактор: руками, лентой или дронами."
	sb.value_changed.connect(func(x): game.cmd("bstate", {"b": b, "key": "load", "val": int(x)}))
	lr.add_child(sb)
	lr.add_child(UI.small("из %d" % Nuclear.slots(b)))
	v.add_child(lr)
	var ar := CheckBox.new()
	ar.text = "Автоматическая защита (АЗ-5 сама при %d°)" % int(Nuclear.c("warn_t", 500.0))
	ar.button_pressed = bool(s.auto)
	ar.toggled.connect(func(on): game.cmd("bstate", {"b": b, "key": "auto", "val": on}))
	v.add_child(ar)
	var br := UI.hbox(8)
	var az := UI.button("АЗ-5 (аварийная защита)", func():
		game.cmd("bstate", {"b": b, "key": "scram", "val": true})
		game.sfx.play("alarm", b.center()), "Все стержни быстро падают в зону — реакция гаснет. Температура спадает, если есть вода.")
	az.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
	br.add_child(az)
	br.add_child(UI.button("Снять АЗ", func(): game.cmd("bstate", {"b": b, "key": "scram", "val": false}), "Вернуть управление стержнями (они поедут к заданному положению)."))
	v.add_child(br)
	v.add_child(_wrap(UI.small("Как запустить: подведите воду по трубам (насос на воде → трубы → реактор), положите ТВЭЛы, задайте «ТВЭЛов в зоне», включите насосы на 100% и медленно поднимайте стержни, следя за температурой. Энергия идёт, когда вода закипает (выше %d°). Если тепла больше, чем уносит вода, — перегрев и авария." % int(Nuclear.c("steam_t", 100.0)))))
	w.body.add_child(v)


func _drone_panel(w: Win) -> void:
	var dr = game.drones
	w.set_meta("drone_ui", [])
	if dr == null:
		return
	var b = bld
	var stn = b if Drones.is_station(b) else null
	if stn == null:
		for s in b.subs:
			if Drones.is_station(s):
				stn = s
				break
	if stn == null:
		return
	dr.sync()
	var v := UI.vbox(6)
	var list: Array = dr.drones_of(stn)
	v.add_child(UI.section("Дроны · %d (уровень станции %d)" % [list.size(), stn.lvl]))
	var nxt: int = Drones.count_for(stn) if stn.lvl >= Fusion.max_level() else 0
	if stn.lvl < Fusion.max_level():
		var tmp_lvl: int = stn.lvl
		stn.lvl = tmp_lvl + 1
		nxt = Drones.count_for(stn)
		stn.lvl = tmp_lvl
		v.add_child(_wrap(UI.small("Поставьте рядом такую же станцию и объедините — «Объединение %d» вмещает %d дронов." % [stn.lvl + 1, nxt])))
	var drows := UI.vbox(3)
	for d in list:
		var r := UI.hbox(8)
		r.add_child(UI.label("Дрон %d" % (d.i + 1), 14))
		var stl := UI.label(Drones.state_text(d), 13, UI.DIM if d.state == "dock" else (Color(1, 0.5, 0.4) if d.state == "dead" else UI.TEXT))
		stl.custom_minimum_size = Vector2(UI.ws(220), 0)
		r.add_child(stl)
		var bb := UI.bar(r, Color(1, 0.85, 0.3), 8)
		bb.custom_minimum_size = Vector2(70, 8)
		bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bb.value = d.bat / Drones.battery() * 100.0
		bb.tooltip_text = "Батарея"
		var hb := UI.bar(r, Color(0.4, 0.9, 0.5), 8)
		hb.custom_minimum_size = Vector2(50, 8)
		hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.value = d.hp / float(Drones.c("hp", 60.0)) * 100.0 if d.state != "dead" else 0.0
		hb.tooltip_text = "Прочность"
		drows.add_child(r)
		w.get_meta("drone_ui").append([d, stl, bb, hb])
	v.add_child(drows)
	v.add_child(UI.section("Маршруты"))
	var rs: Array = Drones.routes(stn).duplicate(true)
	if rs.is_empty():
		v.add_child(_wrap(UI.small("Маршрутов нет. Нажмите «Добавить маршрут», потом укажите на карте, откуда брать (А) и куда везти (Б).")))
	var save := func(nr: Array):
		dr.set_routes(stn, nr)
		w.set_meta("built_for", null)
	for i in rs.size():
		var rr: Dictionary = rs[i]
		var card := UI.panel(0.25)
		var cv := UI.vbox(4)
		card.add_child(cv)
		var top := UI.hbox(8)
		top.add_child(UI.label("%d." % (i + 1), 15, UI.ACCENT))
		var a = dr.bld_at(rr.get("from"))
		var z = dr.bld_at(rr.get("to"))
		var idx: int = i
		top.add_child(UI.button("А: " + (game.factory.fz.name_of(a) if a != null else "выбрать…"), func():
			close("building")
			dr.start_pick("Кликните по зданию, ОТКУДА дроны берут груз", func(o):
				var nr: Array = Drones.routes(stn).duplicate(true)
				if idx < nr.size():
					nr[idx]["from"] = [o.cell.x, o.cell.y]
					dr.set_routes(stn, nr)
				game.notify("Откуда: %s" % game.factory.fz.name_of(o), Color(1, 0.85, 0.4))
				open_building(b)), "Указать на карте здание, из которого брать"))
		top.add_child(UI.label("→", 16))
		top.add_child(UI.button("Б: " + (game.factory.fz.name_of(z) if z != null else "выбрать…"), func():
			close("building")
			dr.start_pick("Кликните по зданию, КУДА дроны везут груз", func(o):
				var nr: Array = Drones.routes(stn).duplicate(true)
				if idx < nr.size():
					nr[idx]["to"] = [o.cell.x, o.cell.y]
					dr.set_routes(stn, nr)
				game.notify("Куда: %s" % game.factory.fz.name_of(o), Color(0.5, 1, 0.6))
				open_building(b)), "Указать на карте здание, в которое везти"))
		top.add_child(UI.spacer())
		var on: bool = bool(rr.get("on", true))
		top.add_child(UI.button("Пауза" if on else "Включить", func():
			var nr: Array = Drones.routes(stn).duplicate(true)
			nr[idx]["on"] = not on
			save.call(nr), "Временно остановить этот маршрут"))
		top.add_child(UI.button("✕", func():
			var nr: Array = Drones.routes(stn).duplicate(true)
			nr.remove_at(idx)
			save.call(nr), "Удалить маршрут"))
		cv.add_child(top)
		var mid := UI.hbox(8)
		mid.add_child(UI.label("Что везти:", 13))
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.add_item("Всё, что примет Б")
		ob.set_item_metadata(0, "")
		var cand: Array = []
		if a != null:
			for inv in dr.src_invs(a):
				for sl in inv.slots:
					if sl != null and not sl.id in cand:
						cand.append(sl.id)
		var cur := str(rr.get("item", ""))
		if cur != "" and not cur in cand:
			cand.insert(0, cur)
		for id in cand:
			ob.add_item(DB.item_name(id))
			ob.set_item_metadata(ob.item_count - 1, id)
			if id == cur:
				ob.select(ob.item_count - 1)
		ob.item_selected.connect(func(k):
			var nr: Array = Drones.routes(stn).duplicate(true)
			nr[idx]["item"] = ob.get_item_metadata(k)
			save.call(nr))
		mid.add_child(ob)
		mid.add_child(UI.label("Оставлять в А:", 13))
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = 999
		sp.value = int(rr.get("keep", 0))
		sp.tooltip_text = "Сколько не трогать в здании А (например, оставить 20 угля для печи)"
		sp.value_changed.connect(func(val):
			var nr: Array = Drones.routes(stn).duplicate(true)
			nr[idx]["keep"] = int(val)
			dr.set_routes(stn, nr))
		mid.add_child(sp)
		cv.add_child(mid)
		var err: String = dr.route_err(stn, i)
		if err != "":
			cv.add_child(UI.label("Не работает: " + err, 13, Color(1, 0.55, 0.45)))
		elif not on:
			cv.add_child(_wrap(UI.small("На паузе")))
		v.add_child(card)
	v.add_child(UI.button("+ Добавить маршрут", func():
		var nr: Array = Drones.routes(stn).duplicate(true)
		nr.append({"from": [], "to": [], "item": "", "keep": 0, "on": true})
		dr.set_routes(stn, nr)
		var ni: int = nr.size() - 1
		close("building")
		dr.start_pick("Маршрут %d: кликните по зданию, ОТКУДА брать груз" % (ni + 1), func(o):
			var r1: Array = Drones.routes(stn).duplicate(true)
			r1[ni]["from"] = [o.cell.x, o.cell.y]
			dr.set_routes(stn, r1)
			dr.start_pick("Теперь кликните по зданию, КУДА везти", func(o2):
				var r2: Array = Drones.routes(stn).duplicate(true)
				r2[ni]["to"] = [o2.cell.x, o2.cell.y]
				dr.set_routes(stn, r2)
				game.notify("Маршрут готов: %s → %s" % [game.factory.fz.name_of(o), game.factory.fz.name_of(o2)], Color(0.5, 1, 0.6))
				open_building(b))), "Дроны будут возить груз из одного здания в другое"))
	v.add_child(_wrap(UI.small("Дрон берёт до %d шт. за рейс, летит, только если батареи хватит туда и обратно; заряжается и чинится на станции. Монстры-стрелки и летуны могут его сбить — станция соберёт нового за ресурсы из штаба." % dr.capacity(stn))))
	var pnl := UI.panel(0.35)
	pnl.add_child(v)
	w.body.add_child(pnl)


static func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(UI.ws(460), 0)
	return l
