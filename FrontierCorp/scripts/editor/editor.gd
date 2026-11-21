extends Control
## Редактор игры (отдельная программа). В собранную игру не попадает.
## Вкладки: Проект и сборка, Данные, Модели, Карта, Звуки и музыка, Интерфейс.

var tabs: TabContainer
var status: Label
var title_lbl: Label
var data_tab: EdDataTab
var project_tab: EdProjectTab
var model_tab: Control
var sound_tab: Control
var ui_tab: Control
var map_tab: Control
var _status_t := 0.0


func _ready() -> void:
	DB.locked = {}   # в редакторе всё открыто
	UI.use_game_style(false)
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_window().title = "Редактор — %s" % DB.window_title()
	DB.use_mods = false
	DB.load_all()
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.085, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 6
	root.offset_right = -8
	root.offset_bottom = -6
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	title_lbl = UI.label("", 20, UI.ACCENT)
	top.add_child(title_lbl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	status = UI.label("", 14, UI.DIM)
	top.add_child(status)
	top.add_child(UI.button("▶  Играть", play_test, "Запустить игру с текущими правками (F5)"))
	top.add_child(UI.button("Собрать игру…", func(): tabs.current_tab = 0; project_tab.ask_build(), "Сделать готовую игру без редактора"))
	top.add_child(UI.button("В главное меню", func(): flush_all(); get_tree().change_scene_to_file("res://scenes/menu.tscn")))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	project_tab = EdProjectTab.new(self)
	project_tab.name = "Проект и сборка"
	tabs.add_child(project_tab)
	data_tab = EdDataTab.new(self)
	data_tab.name = "Данные"
	tabs.add_child(data_tab)
	model_tab = _optional("res://scripts/editor/model_tab.gd", "Модели")
	map_tab = _optional("res://scripts/editor/map_tab.gd", "Карта")
	sound_tab = _optional("res://scripts/editor/sound_tab.gd", "Звуки и музыка")
	ui_tab = _optional("res://scripts/editor/ui_tab.gd", "Интерфейс")
	tabs.current_tab = 1
	_update_title()
	set_status("Готово. Все правки сохраняются сами.")
	_check_args()


func _optional(path: String, nm: String) -> Control:
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	var c: Control = s.new(self)
	c.name = nm
	tabs.add_child(c)
	return c


func _check_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frame = int(a.substr(9))
		elif a.begins_with("--ed-tab="):
			tabs.current_tab = int(a.substr(9))
		elif a.begins_with("--ed-type="):
			data_tab.open(a.substr(10))
		elif a.begins_with("--ed-model="):
			open_model(a.substr(11))
		elif a.begins_with("--ed-call="):
			_calls = a.substr(10).split(",")


var _frame := 0
var _shot_frame := 0
var _shot_path := ""
var _calls: PackedStringArray = []

func _process(delta: float) -> void:
	_status_t -= delta
	_frame += 1
	if _frame == 4 and not _calls.is_empty():
		_run_calls()
	if _shot_frame > 0 and _frame == _shot_frame:
		if _shot_path != "" and DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png(_shot_path)
		print("SHOT saved ", _shot_path)
		flush_all()
		get_tree().quit()


## Для проверок: --ed-call=sel:0,beautify,templates ...
func _run_calls() -> void:
	var t: Control = tabs.get_current_tab_control()
	for c in _calls:
		if c.begins_with("sel:") and t == model_tab:
			model_tab.sel = Array(c.substr(4).split(",")).map(func(x): return int(x))
			model_tab._draw_selection()
			model_tab._show_props()
		elif c.begins_with("data:"):
			var p := c.substr(5).split("/")
			open_data(p[0], p[1] if p.size() > 1 else "")
		elif c.begins_with("scroll:"):
			await get_tree().process_frame
			await get_tree().process_frame
			data_tab.form_holder.scroll_vertical = int(c.substr(7))
		elif c.begins_with("show:"):
			# прокрутить форму к подписи с этим текстом
			await get_tree().process_frame
			await get_tree().process_frame
			var want := c.substr(5)
			for n in data_tab.form_holder.find_children("*", "Label", true, false):
				if (n as Label).text.strip_edges() == want:
					data_tab.form_holder.scroll_vertical = int((n as Control).global_position.y - data_tab.form_holder.global_position.y) + data_tab.form_holder.scroll_vertical - 10
					break
		elif t.has_method(c):
			t.call(c)
		elif has_method(c):
			call(c)
		print("ED call ", c)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F5:
		play_test()


func _update_title() -> void:
	var tgt := "игра"
	if DB.edit_target != DB.project_path():
		tgt = "правка: " + DB.edit_target.get_file()
	title_lbl.text = "%s  v%s   ·   %s" % [DB.game_name(), DB.game_version(), tgt]


func set_status(t: String) -> void:
	if status:
		status.text = t
	_status_t = 4.0


## Вызывается после любых изменений данных: обновить иконки и списки.
func content_changed() -> void:
	DB.revision += 1
	_update_title()


func refresh_all() -> void:
	_update_title()
	data_tab.refresh()
	for t in [model_tab, map_tab, sound_tab, ui_tab, project_tab]:
		if t and t.has_method("refresh"):
			t.refresh()


func open_model(id: String) -> void:
	if model_tab:
		tabs.current_tab = model_tab.get_index()
		model_tab.open(id)


func open_data(t: String, id := "") -> void:
	tabs.current_tab = data_tab.get_index()
	data_tab.open(t, id)


## Запуск игры прямо из редактора.
## Сохранить все несохранённые правки во всех вкладках.
func flush_all() -> void:
	for t in [data_tab, model_tab, map_tab, sound_tab, ui_tab]:
		if t and t.has_method("flush"):
			t.flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		flush_all()


func play_test(extra := {}) -> void:
	flush_all()
	DB.use_mods = true
	DB.load_all()
	var ng := {"profession": DB.data.professions.keys()[0] if not DB.data.professions.is_empty() else "engineer"}
	ng.merge(extra, true)
	DB.set_meta("new_game", ng)
	DB.set_meta("from_editor", true)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ---------------------------------------------------------------- диалоги

func confirm(text: String, yes: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = text
	d.ok_button_text = "Да"
	d.cancel_button_text = "Отмена"
	add_child(d)
	d.confirmed.connect(func():
		yes.call()
		d.queue_free())
	d.canceled.connect(d.queue_free)
	d.popup_centered(Vector2i(460, 140))


func ask_text(text: String, def: String, cb: Callable, multiline := false) -> void:
	var d := ConfirmationDialog.new()
	d.title = text
	d.ok_button_text = "OK"
	d.cancel_button_text = "Отмена"
	var v := VBoxContainer.new()
	v.add_child(UI.label(text, 14))
	var le: Control
	if multiline:
		var te := TextEdit.new()
		te.text = def
		te.custom_minimum_size = Vector2(520, 160)
		le = te
	else:
		var l := LineEdit.new()
		l.text = def
		l.select_all()
		l.custom_minimum_size = Vector2(420, 0)
		le = l
	v.add_child(le)
	d.add_child(v)
	add_child(d)
	d.confirmed.connect(func():
		cb.call(le.text)
		d.queue_free())
	d.canceled.connect(d.queue_free)
	d.popup_centered()
	le.grab_focus()


func info(title: String, text: String) -> void:
	var d := AcceptDialog.new()
	d.title = title
	d.dialog_text = text
	d.ok_button_text = "OK"
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.popup_centered(Vector2i(520, 200))
