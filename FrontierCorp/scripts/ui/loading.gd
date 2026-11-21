class_name LoadingScreen
extends CanvasLayer
## Экран загрузки: фон, надпись и случайный совет из «Главное меню и экраны».
## Показывается поверх текущей сцены, потом сцена меняется. Пока новая сцена
## строит мир, на экране остаётся этот кадр.

var target := ""
var t := 0.0
var min_time := 0.8
var bar: ProgressBar
var switched := false
var step_lbl: Label
var fade := -1.0
var root_ctl: Control


static func go(tree: SceneTree, scene: String) -> void:
	var l := LoadingScreen.new()
	l.target = scene
	tree.root.add_child.call_deferred(l)


static func random_tip() -> String:
	var tips: Array = DB.menu("tips", [])
	var list := []
	for tp in tips:
		var s := str(tp.get("text", "")) if tp is Dictionary else str(tp)
		if s.strip_edges() != "":
			list.append(s)
	return DB.t(list[randi() % list.size()]) if not list.is_empty() else ""


func _ready() -> void:
	layer = 100
	min_time = float(DB.menu("loading_min_time", 0.8))
	var root := Control.new()
	root_ctl = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.use_game_style(true)
	root.theme = UI.theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = DB.color(DB.menu("bg_color_a", "#080d17"))
	root.add_child(bg)
	var img: String = str(DB.menu("bg_image", ""))
	if img != "":
		var tex = ModelLib.texture(img)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.modulate = Color(1, 1, 1, 0.5)
			root.add_child(tr)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var v := UI.vbox(16)
	v.custom_minimum_size = Vector2(640, 0)
	center.add_child(v)
	var l := UI.label(DB.t(DB.menu("loading_text", "Загрузка...")), 30, UI.ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 1.0
	v.add_child(bar)
	step_lbl = UI.label(DB.tx("load_build", "Строим мир..."), 14, UI.DIM)
	step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(step_lbl)
	var tip := random_tip()
	if tip != "":
		var r := UI.rich("[center][color=#8a93a3]%s[/color]\n%s[/center]" % [DB.tx("tip", "Совет"), tip], 17)
		r.custom_minimum_size = Vector2(640, 0)
		v.add_child(r)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames=") or a.begins_with("--test"):
			min_time = 0.0


func _process(delta: float) -> void:
	t += delta
	bar.value = clampf(t / max(0.01, min_time), 0.0, 0.95)
	if fade >= 0.0:
		# мир готов: экран загрузки плавно исчезает
		fade += delta
		root_ctl.modulate.a = 1.0 - clampf(fade / 0.4, 0.0, 1.0)
		if fade >= 0.4:
			queue_free()
		return
	if switched:
		# новая сцена построила мир и прогрела материалы — тогда убираем экран загрузки
		var sc := get_tree().current_scene
		if sc and sc.scene_file_path == target:
			if not ("loading_done" in sc) or sc.loading_done:
				bar.value = 1.0
				fade = 0.0
			elif "loading_step" in sc and str(sc.loading_step) != "":
				step_lbl.text = str(sc.loading_step)
				bar.value = maxf(bar.value, 0.97)
		return
	if t >= min_time:
		switched = true
		get_tree().change_scene_to_file(target)
