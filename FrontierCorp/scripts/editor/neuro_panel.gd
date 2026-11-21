extends AcceptDialog
## Окно «Нейросеть и автоскелет» (редактор моделей):
##  • описание словами → нейросеть на этом компьютере рисует картинку и делает из неё 3D-модель;
##  • или готовая модель из файла (GLB: Blender, Sketchfab, сайты нейросетей);
##  • дальше автоскелет: модель делится на части по костям, монстр шагает и бьёт, герой ходит и копает,
##    у здания мигают огоньки в работе. Результат — обычная модель игры, её можно править дальше.
## Нейросеть — отдельная программа в папке neuro рядом с редактором (установщик: neuro/установить.bat).

var tab                       # model_tab
var kind_ob: OptionButton
var desc: TextEdit
var turn_ob: OptionButton
var size_sb: SpinBox
var tris_sb: SpinBox
var name_le: LineEdit
var status: Label
var bar: ProgressBar
var log_l: RichTextLabel
var run_btn: Button
var redo_btn: Button
var last_src := ""            # последний GLB (от нейросети или из файла)
var image_path := ""          # своя картинка вместо описания (нейросеть сделает 3D по ней)
var _thread: Thread
var _pid := -1
var _busy := false

const KINDS := [["monster", "Монстр (ходит, бьёт)"], ["hero", "Герой (ходит, бьёт, копает)"], ["building", "Здание (огоньки в работе)"]]


func _init(model_tab) -> void:
	tab = model_tab
	title = "Модель от нейросети и автоскелет"
	ok_button_text = "Закрыть"
	min_size = Vector2i(720, 620)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UI.small("Опишите модель словами — нейросеть на вашем компьютере нарисует её и сделает 3D-модель (1–5 минут).\nИли возьмите готовую модель из файла. Скелет и анимации добавятся сами."))
	kind_ob = OptionButton.new()
	for k in KINDS:
		kind_ob.add_item(k[1])
	kind_ob.item_selected.connect(func(_i): _kind_changed())
	v.add_child(_row("Что это", kind_ob))
	desc = TextEdit.new()
	desc.custom_minimum_size = Vector2(0, 80)
	desc.placeholder_text = "Например: ржавый робот-паук с шестью ногами и красными глазами"
	desc.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(UI.label("Описание", 14))
	v.add_child(desc)
	var h := HBoxContainer.new()
	run_btn = UI.button("Создать нейросетью", _run_neuro, "Описание → картинка → 3D-модель → скелет. Работает без интернета после установки нейросети")
	h.add_child(run_btn)
	h.add_child(UI.button("Взять готовую модель (GLB)…", _pick_glb, "Модель из Blender, Sketchfab, Meshy, Tripo и т.п.: скелет и анимации добавятся сами"))
	h.add_child(UI.button("По картинке…", func():
		EdForm.pick_file(self, "image", func(rel: String):
			image_path = DB.find_file(rel)
			_run_neuro()
			image_path = ""), "Своя картинка (рисунок, фото игрушки) — нейросеть сделает по ней 3D-модель"))
	redo_btn = UI.button("↻ Пересобрать скелет", func(): _rig_file(last_src), "Ещё раз разделить последнюю модель на части с новыми настройками (поворот, размер)")
	redo_btn.disabled = true
	h.add_child(redo_btn)
	v.add_child(h)
	turn_ob = OptionButton.new()
	for d in [0, 90, 180, 270]:
		turn_ob.add_item("%d°" % d, d)
	turn_ob.select(1)
	turn_ob.tooltip_text = "Если модель идёт боком или задом — поверните и нажмите «Пересобрать скелет»"
	v.add_child(_row("Повернуть", turn_ob))
	size_sb = SpinBox.new()
	size_sb.step = 0.1
	v.add_child(_row("Размер", size_sb))
	tris_sb = SpinBox.new()
	tris_sb.min_value = 1000
	tris_sb.max_value = 60000
	tris_sb.step = 500
	tris_sb.value = 9000
	tris_sb.tooltip_text = "Больше — подробнее, но тяжелее для игры (500 монстров на экране)"
	v.add_child(_row("Треугольников", tris_sb))
	name_le = LineEdit.new()
	name_le.placeholder_text = "Название новой модели"
	v.add_child(_row("Название", name_le))
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.max_value = 1.0
	bar.step = 0.001
	v.add_child(bar)
	status = UI.label("", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status)
	log_l = UI.rich("", 12)
	log_l.custom_minimum_size = Vector2(0, 110)
	log_l.scroll_following = true
	v.add_child(log_l)
	_kind_changed()
	_check_neuro()
	close_requested.connect(_stop)
	confirmed.connect(_stop)


func _row(t: String, c: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UI.label(t, 14)
	l.custom_minimum_size = Vector2(130, 0)
	h.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	return h


func _kind() -> String:
	return KINDS[kind_ob.selected][0]


func _kind_changed() -> void:
	var k := _kind()
	if k == "building":
		size_sb.min_value = 1
		size_sb.max_value = 12
		size_sb.step = 1
		size_sb.value = 2
		size_sb.suffix = "клеток"
		size_sb.tooltip_text = "Сторона здания в клетках (1 клетка = 2 м)"
	elif k == "hero":
		size_sb.min_value = 1.0
		size_sb.max_value = 4.0
		size_sb.step = 0.1
		size_sb.value = 2.0
		size_sb.suffix = "м"
		size_sb.tooltip_text = "Рост героя (в игре он ещё ×1,25)"
	else:
		size_sb.min_value = 0.3
		size_sb.max_value = 30.0
		size_sb.step = 0.1
		size_sb.value = 1.6
		size_sb.suffix = "м"
		size_sb.tooltip_text = "Высота монстра"


# ================================================================ нейросеть

## Где лежит нейросеть: «Настройки» → «Нейросеть: папка» или папка neuro рядом с редактором.
static func neuro_dir() -> String:
	var d := str(DB.setting("neuro_dir", ""))
	if d == "":
		d = OS.get_executable_path().get_base_dir().path_join("neuro")
	return d


static func neuro_python() -> String:
	var d := neuro_dir()
	for p in [d.path_join("venv/Scripts/python.exe"), d.path_join("venv/bin/python3"), d.path_join("venv/bin/python")]:
		if FileAccess.file_exists(p):
			return p
	return ""


func _check_neuro() -> void:
	var py := neuro_python()
	var script := neuro_dir().path_join("frontier_neuro.py")
	if py == "" or not FileAccess.file_exists(script):
		status.text = "Нейросеть ещё не установлена. Запустите один раз %s (нужен интернет, около 6 ГБ). Готовую модель из файла можно взять и без неё." % neuro_dir().path_join("установить.bat")
		run_btn.disabled = true
	else:
		status.text = "Нейросеть найдена: " + neuro_dir()
		run_btn.disabled = false


func _run_neuro() -> void:
	if _busy:
		return
	var text := desc.text.strip_edges()
	if text == "" and image_path == "":
		status.text = "Напишите описание модели"
		return
	var py := neuro_python()
	if py == "":
		_check_neuro()
		return
	var out := DB.edit_target.path_join("ai").path_join("job_%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(out)
	var args := [neuro_dir().path_join("frontier_neuro.py"), "--out", out]
	if image_path != "":
		args += ["--image", image_path]
	else:
		args += ["--prompt", text]
	var r := OS.execute_with_pipe(py, PackedStringArray(args))
	if r.is_empty():
		status.text = "Не удалось запустить нейросеть: " + py
		return
	_busy = true
	_pid = int(r.pid)
	bar.value = 0.02
	status.text = "Нейросеть работает…"
	log_l.text = ""
	run_btn.disabled = true
	_thread = Thread.new()
	_thread.start(_read_pipe.bind(r.stdio))


## Строки помощника: «PROGRESS 0.4 текст», «DONE путь.glb», «ERROR текст», остальное — в журнал.
func _read_pipe(pipe: FileAccess) -> void:
	while pipe.is_open() and pipe.get_error() == OK:
		var line := pipe.get_line()
		if line == "" and pipe.eof_reached():
			break
		call_deferred("_on_line", line)
	call_deferred("_on_exit")


func _on_line(line: String) -> void:
	line = line.strip_edges()
	if line == "":
		return
	if line.begins_with("PROGRESS "):
		var p := line.substr(9).split(" ", true, 1)
		bar.value = clampf(float(p[0]), 0.0, 1.0)
		if p.size() > 1:
			status.text = p[1]
	elif line.begins_with("DONE "):
		bar.value = 1.0
		_busy = false
		_rig_file(line.substr(5).strip_edges())
	elif line.begins_with("ERROR "):
		status.text = "Ошибка нейросети: " + line.substr(6)
		_busy = false
	else:
		log_l.append_text(line + "\n")


func _on_exit() -> void:
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	_pid = -1
	if _busy:
		_busy = false
		if not status.text.begins_with("Ошибка"):
			status.text = "Нейросеть закрылась без результата — смотрите журнал ниже"
	run_btn.disabled = false


func _stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1


# ================================================================ готовая модель и автоскелет

func _pick_glb() -> void:
	EdForm.pick_file(self, "glb", func(rel: String): _rig_file(rel))


func _rig_file(path: String) -> void:
	if path == "":
		return
	last_src = path
	redo_btn.disabled = false
	status.text = "Делаю скелет…"
	ModelLib._glb.clear()
	ModelLib._glb_states.clear()
	var src := AutoRig.load_mesh(path)
	if src.has("err"):
		status.text = "Модель не открылась: " + str(src.err)
		return
	var nm := name_le.text.strip_edges()
	if nm == "":
		nm = desc.text.strip_edges().left(40) if desc.text.strip_edges() != "" else path.get_file().get_basename()
	var mid := _new_id("ai_" + (DB.latin_id(nm) if DB.latin_id(nm) != "" else "model"))
	var opts := {"kind": _kind(), "turn": float(turn_ob.get_selected_id()), "tris": int(tris_sb.value), "id": mid, "dir": "ai",
		"name": nm, "src": path, "prompt": desc.text.strip_edges()}
	if _kind() == "building":
		opts["footprint"] = int(size_sb.value)
	else:
		opts["height"] = float(size_sb.value)
	var res := AutoRig.rig(src, opts)
	if res.has("err"):
		status.text = "Не получилось: " + str(res.err)
		return
	if not ModelGen.save(res, DB.edit_target):
		status.text = "Не удалось сохранить сетки в " + DB.edit_target
		return
	for rel in res.meshes:
		ModelLib.put_mesh(rel, res.meshes[rel])
	DB.save_object("models", mid, res.model)
	var info: Dictionary = res.info
	status.text = "Готово: модель «%s» (%s), %d треугольников, частей %d%s. Она открыта в окне моделей — проверьте «Ходьба» и «Удар»." % [
		nm, mid, info.tris, info.parts, (", " + str(info.note)) if str(info.note) != "" else ""]
	if _kind() == "hero":
		status.text += "\nЧтобы играть этим героем: «Данные» → «Настройки» → «Модель героя» → %s." % mid
	tab._fill_list()
	tab.open(mid)
	tab.ed.content_changed()


func _new_id(base: String) -> String:
	var id := base
	var i := 2
	while DB.data.models.has(id):
		id = "%s_%d" % [base, i]
		i += 1
	return id
