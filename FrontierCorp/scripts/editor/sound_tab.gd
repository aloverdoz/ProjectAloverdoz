extends HSplitContainer
## Вкладка «Звуки и музыка»: список звуков игры с прослушиванием, настройка каждого звука,
## генератор звуков без файлов и музыка (меню, день, ночь, волна).

var ed
var list: ItemList
var search: LineEdit
var ids: Array = []
var cur_id := ""
var body: VBoxContainer
var synth := {}
var wave_view: Control
var _peaks := PackedFloat32Array()
var _preview: AudioStreamWAV
var _player: AudioStreamPlayer
var _save_t := 0.0


func _init(editor) -> void:
	ed = editor
	split_offset = 280
	var lv := VBoxContainer.new()
	lv.custom_minimum_size = Vector2(270, 0)
	add_child(lv)
	search = LineEdit.new()
	search.placeholder_text = "Поиск звука"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_t): _fill())
	lv.add_child(search)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(i): open(ids[i]))
	list.item_activated.connect(func(i): EdAudio.play_id(ids[i]))
	lv.add_child(list)
	var g := GridContainer.new()
	g.columns = 2
	lv.add_child(g)
	g.add_child(UI.button("+ Новый звук", _new_sound))
	g.add_child(UI.button("Удалить", _delete))
	g.add_child(UI.button("▶ Прослушать", func(): EdAudio.play_id(cur_id), "Двойной щелчок по звуку — тоже"))
	g.add_child(UI.button("■ Стоп", EdAudio.stop))
	lv.add_child(UI.button("Музыка и фон", func(): open("@music"), "Музыка меню, дня, ночи и волны"))
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	sc.add_child(body)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	synth = EdSynth.preset("shot", 0.0)


func _ready() -> void:
	_fill()
	if not ids.is_empty():
		open(ids[0])


func refresh() -> void:
	_fill()
	if cur_id != "":
		open(cur_id)


func _fill() -> void:
	list.clear()
	ids.clear()
	var q := search.text.strip_edges().to_lower()
	var keys: Array = DB.data.sounds.keys()
	keys.sort_custom(func(a, b): return str(DB.data.sounds[a].get("name", a)) < str(DB.data.sounds[b].get("name", b)))
	for id in keys:
		var nm := str(DB.data.sounds[id].get("name", id))
		if q != "" and not (q in nm.to_lower() or q in str(id)):
			continue
		list.add_item("♪  " + nm)
		list.set_item_tooltip(list.item_count - 1, "id: %s\nДвойной щелчок — прослушать" % id)
		ids.append(id)
		if id == cur_id:
			list.select(list.item_count - 1)


func _process(delta: float) -> void:
	if _save_t > 0.0:
		_save_t -= delta
		if _save_t <= 0.0:
			_flush()


var _pending: Array = []

func flush() -> void:
	_flush()


func _flush() -> void:
	for pr in _pending:
		DB.save_object(pr[0], pr[1], pr[2])
	if not _pending.is_empty():
		ed.content_changed()
		ed.set_status("Сохранено")
	_pending.clear()


func _queue_save(t: String, id: String, v) -> void:
	_pending = _pending.filter(func(pr): return not (pr[0] == t and pr[1] == id))
	_pending.append([t, id, v])
	_save_t = 0.6


# ---------------------------------------------------------------- правая часть

func open(id: String) -> void:
	_flush()
	cur_id = id
	for c in body.get_children():
		c.queue_free()
	if id == "@music":
		_music_ui()
		return
	if not DB.data.sounds.has(id):
		return
	var snd: Dictionary = DB.data.sounds[id]
	# звук сделан в генераторе — открываем его ползунки, чтобы можно было подправить
	if snd.get("synth") is Dictionary:
		synth = snd.synth.duplicate()
	var pc := _section("Звук «%s»" % snd.get("name", id),
		"Звук звучит в игре по своему id (%s). Можно дать несколько файлов — каждый раз будет играть случайный, так звук не надоедает." % id)
	var h := HBoxContainer.new()
	pc.add_child(h)
	h.add_child(UI.button("▶ Прослушать как в игре", func(): EdAudio.play_id(id)))
	h.add_child(UI.button("Где звучит", func(): ed.info("Где звучит «%s»" % snd.get("name", id), _usages(id))))
	var f := EdForm.make(snd, EdSchema.fields("sounds"), false, 200)
	f.changed.connect(func(): _queue_save("sounds", id, snd))
	pc.add_child(f)
	_synth_ui()


func _section(t: String, tip := "") -> VBoxContainer:
	var pc := PanelContainer.new()
	body.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	v.add_child(UI.title(t, 17))
	if tip != "":
		var l := UI.small(tip)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v


func _usages(id: String) -> String:
	var out := []
	for t in ["buildings", "enemies", "resources", "items"]:
		for oid in DB.data[t]:
			var s := JSON.stringify(DB.data[t][oid].get("sounds", {}))
			if ("\"%s\"" % id) in s:
				out.append("%s: %s" % [DB.TYPE_NAMES.get(t, t), DB.data[t][oid].get("name", oid)])
	var mu := JSON.stringify(DB.data.get("music", {}))
	if ("\"%s\"" % id) in mu:
		out.append("Музыка и фон")
	if out.is_empty():
		return "В данных игры этот звук не назначен. Его может включать сам движок игры по id «%s» (шаги, клики, взрывы)." % id
	return "\n".join(out)


func _music_ui() -> void:
	var m: Dictionary = DB.data.get("music", {})
	var pc := _section("Музыка и фоновые звуки",
		"Музыка играет по очереди из списка и плавно меняется: в меню, днём, ночью и во время волны. Подходят файлы OGG, MP3 и WAV.")
	var f := EdForm.make(m, EdSchema.fields("music"), false, 220)
	f.changed.connect(func(): _queue_save("music", "", m))
	pc.add_child(f)


# ---------------------------------------------------------------- генератор звуков

func _synth_ui() -> void:
	var v := _section("Сделать звук самому",
		"Не нужно искать файлы: выберите заготовку, послушайте, подвигайте ползунки. Каждое нажатие заготовки даёт немного другой вариант. Понравилось — «Добавить к этому звуку».")
	var pg := HFlowContainer.new()
	v.add_child(pg)
	for k in EdSynth.PRESETS:
		var kk: String = k
		pg.add_child(UI.button(EdSynth.PRESETS[k].name, func():
			synth = EdSynth.preset(kk)
			_synth_changed(true)))
	var wv := HBoxContainer.new()
	v.add_child(wv)
	wv.add_child(UI.small("Форма волны:"))
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	for i in EdSynth.WAVES.size():
		ob.add_item(EdSynth.WAVE_NAMES[i], i)
	ob.select(maxi(0, EdSynth.WAVES.find(synth.get("wave", "square"))))
	ob.item_selected.connect(func(i): synth["wave"] = EdSynth.WAVES[i]; _synth_changed(true))
	wv.add_child(ob)
	wave_view = Control.new()
	wave_view.custom_minimum_size = Vector2(0, 70)
	wave_view.draw.connect(_draw_wave)
	v.add_child(wave_view)
	var grid := GridContainer.new()
	grid.columns = 3
	v.add_child(grid)
	for s in EdSynth.SLIDERS:
		var key: String = s[0]
		var l := UI.small(s[1])
		l.custom_minimum_size = Vector2(180, 0)
		grid.add_child(l)
		var sl := HSlider.new()
		sl.min_value = s[2]
		sl.max_value = s[3]
		sl.step = s[4]
		sl.value = float(synth.get(key, 0))
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size = Vector2(160, 0)
		sl.focus_mode = Control.FOCUS_NONE
		grid.add_child(sl)
		var val := UI.small(str(snappedf(sl.value, 0.01)))
		val.custom_minimum_size = Vector2(50, 0)
		grid.add_child(val)
		sl.value_changed.connect(func(x):
			synth[key] = x
			val.text = str(snappedf(x, 0.01))
			_synth_changed(false))
		sl.drag_ended.connect(func(_c): _play_preview())
	var bh := HFlowContainer.new()
	v.add_child(bh)
	bh.add_child(UI.button("▶ Прослушать", _play_preview))
	bh.add_child(UI.button("🎲 Похожий вариант", func(): synth = EdSynth.mutate(synth, 0.2); _synth_changed(true)))
	bh.add_child(UI.button("Добавить к этому звуку", func(): _save_synth(false), "Файл добавится в список — будет играть то один, то другой"))
	bh.add_child(UI.button("Заменить звук этим", func(): _save_synth(true), "Звук будет только этим"))
	bh.add_child(UI.button("Новый звук из этого…", _new_from_synth))
	_synth_changed(false)


func _synth_changed(play: bool) -> void:
	_preview = EdSynth.make(synth)
	_peaks = EdSynth.peaks(_preview, 240)
	if wave_view:
		wave_view.queue_redraw()
	if play:
		_open_refresh_sliders()
		_play_preview()


## После смены заготовки ползунки должны показать новые значения.
func _open_refresh_sliders() -> void:
	if cur_id != "" and cur_id != "@music":
		var keep := synth
		open(cur_id)
		synth = keep
		_preview = EdSynth.make(synth)
		_peaks = EdSynth.peaks(_preview, 240)


func _play_preview() -> void:
	if _preview == null:
		_preview = EdSynth.make(synth)
	_player.stream = _preview
	_player.play()


func _draw_wave() -> void:
	var r := wave_view.get_rect()
	wave_view.draw_rect(Rect2(Vector2.ZERO, r.size), Color(0.05, 0.06, 0.08))
	var n := _peaks.size()
	if n == 0:
		return
	var mid := r.size.y * 0.5
	for i in n:
		var x := r.size.x * float(i) / n
		var h := _peaks[i] * mid * 0.95
		wave_view.draw_line(Vector2(x, mid - h), Vector2(x, mid + h), UI.ACCENT, maxf(1.0, r.size.x / n))
	wave_view.draw_string(ThemeDB.fallback_font, Vector2(6, 14), "%.2f сек" % EdSynth.length(synth), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)


func _save_synth(replace: bool) -> void:
	if cur_id == "" or cur_id == "@music":
		return
	var snd: Dictionary = DB.data.sounds[cur_id]
	var dir := DB.edit_target.path_join("sounds")
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 1
	while FileAccess.file_exists(dir.path_join("%s_%d.wav" % [cur_id, n])):
		n += 1
	var fn := "%s_%d.wav" % [cur_id, n]
	var w := EdSynth.make(synth)
	if w.save_to_wav(dir.path_join(fn)) != OK:
		ed.set_status("Не удалось записать файл звука")
		return
	var files: Array = [] if replace else snd.get("files", []).duplicate()
	files.append("sounds/" + fn)
	snd["files"] = files
	snd["synth"] = synth.duplicate()
	DB.save_object("sounds", cur_id, snd)
	ed.content_changed()
	open(cur_id)
	ed.set_status("Звук записан: sounds/%s" % fn)


func _new_from_synth() -> void:
	ed.ask_text("Название нового звука:", "Мой звук", func(nm: String):
		var id := _new_id(nm)
		DB.save_object("sounds", id, {"name": nm, "files": [], "volume": -8, "pitch": 0.08, "positional": true, "max_dist": 100, "cooldown": 40})
		cur_id = id
		_save_synth(true)
		_fill())


func _new_sound() -> void:
	ed.ask_text("Название нового звука:", "Мой звук", func(nm: String):
		var id := _new_id(nm)
		DB.save_object("sounds", id, {"name": nm, "files": [], "volume": -8, "pitch": 0.08, "positional": true, "max_dist": 100, "cooldown": 40})
		ed.content_changed()
		_fill()
		open(id))


func _new_id(nm: String) -> String:
	var base := DB.latin_id(nm)
	if base == "" or not base.is_valid_identifier():
		base = "sound"
	var id := base
	var k := 2
	while DB.data.sounds.has(id):
		id = "%s_%d" % [base, k]
		k += 1
	return id


func _delete() -> void:
	if cur_id == "" or cur_id == "@music":
		return
	var id := cur_id
	ed.confirm("Удалить звук «%s»?" % DB.data.sounds[id].get("name", id), func():
		DB.save_object("sounds", id, null)
		ed.content_changed()
		cur_id = ""
		_fill()
		if not ids.is_empty():
			open(ids[0]))


## Для проверок: сгенерировать все заготовки и записать в файлы.
func _test_synth() -> void:
	var dir := OS.get_user_data_dir().path_join("synth_test")
	DirAccess.make_dir_recursive_absolute(dir)
	for k in EdSynth.PRESETS:
		var w := EdSynth.make(EdSynth.preset(k))
		w.save_to_wav(dir.path_join(k + ".wav"))
		print("SYNTH ", k, " ", w.data.size(), " bytes")
	print("SYNTH dir ", dir)
