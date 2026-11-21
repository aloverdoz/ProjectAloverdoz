extends RefCounted
## Фото- и видеорежим (14.7). F9 — войти/выйти, интерфейс скрыт.
## F — свободная камера (WASD, Пробел/Ctrl — вверх/вниз, правая кнопка мыши — повернуть, колесо — приближение, Shift — быстрее);
## [ и ] — фильтр; V — размытие дали; F12 — снимок; F11 — снимок в высоком разрешении; F8 — запись ролика (.avi); H — подсказка.
## Фильтры правятся в «Данные → Настройки → Фоторежим: фильтры».

const AviWriter = preload("res://scripts/avi_writer.gd")

var game
var free_cam := false
var pos := Vector3.ZERO
var yaw := 0.0
var pitch := -0.4
var fov := 70.0
var filter_i := 0
var dof := false
var rec = null              # AviWriter, пока идёт запись
var rec_t := 0.0
var rec_acc := 0.0
var rec_real := 0.0
var rec_path := ""
var layer: CanvasLayer
var tip: Label
var tip_on := true
var _rmb := false
var _env_saved := {}
var last_file := ""
var _cam_fov := 70.0


func _init(g) -> void:
	game = g


func filters() -> Array:
	var f: Array = DB.setting("photo_filters", [])
	return f if not f.is_empty() else [{"name": "Обычный"}]


func enter() -> void:
	var cam: Camera3D = game.camera
	pos = cam.global_position
	var fw := -cam.global_transform.basis.z
	yaw = atan2(-fw.x, -fw.z)
	pitch = asin(clampf(fw.y, -1.0, 1.0))
	fov = cam.fov
	_cam_fov = cam.fov
	_env_saved = {"s": game.env.adjustment_saturation, "c": game.env.adjustment_contrast, "b": game.env.adjustment_brightness,
		"cc": game.env.adjustment_color_correction}
	if layer == null:
		layer = CanvasLayer.new()
		layer.layer = 50
		tip = UI.label("", 15)
		tip.position = Vector2(16, 12)
		tip.add_theme_color_override("font_outline_color", Color.BLACK)
		tip.add_theme_constant_override("outline_size", 6)
		layer.add_child(tip)
		game.add_child(layer)
	layer.visible = true
	_apply_filter()
	_update_tip()


func leave() -> void:
	if rec != null:
		stop_rec()
	free_cam = false
	dof = false
	game.camera.attributes = null
	game.camera.fov = _cam_fov
	if not _env_saved.is_empty():
		game.env.adjustment_saturation = _env_saved.s
		game.env.adjustment_contrast = _env_saved.c
		game.env.adjustment_brightness = _env_saved.b
		game.env.adjustment_color_correction = _env_saved.cc
	if layer:
		layer.visible = false


func _update_tip() -> void:
	if tip == null:
		return
	var fl: Dictionary = filters()[filter_i % filters().size()]
	var t := "ФОТОРЕЖИМ · фильтр: %s%s%s" % [str(fl.get("name", "")), " · свободная камера" if free_cam else "", " · размытие дали" if dof else ""]
	if rec != null:
		# во время записи подсказку не рисуем (попала бы в ролик) — пишем в заголовок окна
		DisplayServer.window_set_title("● ЗАПИСЬ %d:%02d — F8 остановить" % [int(rec_real) / 60, int(rec_real) % 60])
	elif tip_on:
		t += "\nF — свободная камера · [ ] — фильтр · V — размытие дали · F12 — снимок · F11 — снимок в высоком разрешении · F8 — запись ролика · H — скрыть подсказку · F9 — выйти"
		if last_file != "":
			t += "\nСохранено: " + last_file
	tip.text = t
	tip.visible = tip_on and rec == null


## Клавиши фоторежима. true — клавиша съедена.
func key(k: int, shift: bool) -> bool:
	match k:
		KEY_F:
			free_cam = not free_cam
			if free_cam:
				enter_free()
		KEY_BRACKETRIGHT:
			filter_i = (filter_i + 1) % filters().size()
			_apply_filter()
		KEY_BRACKETLEFT:
			filter_i = (filter_i - 1 + filters().size()) % filters().size()
			_apply_filter()
		KEY_V:
			dof = not dof
			_apply_dof()
		KEY_H:
			tip_on = not tip_on
		KEY_F12:
			snap()
		KEY_F11:
			snap_hi()
		KEY_F8:
			if rec == null:
				start_rec()
			else:
				stop_rec()
		_:
			return k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL, KEY_Q, KEY_E] and free_cam
	_update_tip()
	return true


func enter_free() -> void:
	var cam: Camera3D = game.camera
	pos = cam.global_position
	var fw := -cam.global_transform.basis.z
	yaw = atan2(-fw.x, -fw.z)
	pitch = asin(clampf(fw.y, -1.0, 1.0))


func mouse(ev: InputEvent) -> bool:
	if not free_cam:
		return false
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			_rmb = ev.pressed
			return true
		if ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			fov = clampf(fov - 3.0, 15.0, 100.0)
			return true
		if ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			fov = clampf(fov + 3.0, 15.0, 100.0)
			return true
	elif ev is InputEventMouseMotion and _rmb:
		yaw -= ev.relative.x * 0.004
		pitch = clampf(pitch - ev.relative.y * 0.004, -1.5, 1.5)
		return true
	return false


## Свободная камера: летает где угодно (но не дальше 150 м от героя — дальше мир не прогружен).
func update_cam(cam: Camera3D, dt: float) -> void:
	var sp := 12.0 * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0))
	var mv := Vector3.ZERO
	if not game.typing():
		if Input.is_key_pressed(KEY_W): mv -= basis.z
		if Input.is_key_pressed(KEY_S): mv += basis.z
		if Input.is_key_pressed(KEY_A): mv -= basis.x
		if Input.is_key_pressed(KEY_D): mv += basis.x
		if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E): mv += Vector3.UP
		if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q): mv -= Vector3.UP
	pos += mv.normalized() * sp * dt if mv.length() > 0.01 else Vector3.ZERO
	var pp: Vector3 = game.player.position
	var off := World.delta(pp, pos)
	var flat := Vector3(off.x, 0, off.z).limit_length(150.0)
	pos = pp + Vector3(flat.x, off.y, flat.z)
	pos.y = clampf(pos.y, game.world.height_at(pos) + 0.6, pp.y + 120.0)
	cam.global_position = pos
	cam.global_transform.basis = basis
	cam.fov = fov


func _apply_filter() -> void:
	var fl: Dictionary = filters()[filter_i % filters().size()]
	var e: Environment = game.env
	var base_s: float = _env_saved.get("s", 1.0)
	var base_c: float = _env_saved.get("c", 1.0)
	e.adjustment_enabled = true
	e.adjustment_saturation = base_s * float(fl.get("saturation", 1.0))
	e.adjustment_contrast = base_c * float(fl.get("contrast", 1.0))
	e.adjustment_brightness = float(fl.get("brightness", 1.0))
	var dark := str(fl.get("dark", ""))
	var light := str(fl.get("light", ""))
	if dark != "" and light != "":
		# цвет теней и светлых мест (сепия, тёплый, холодный...)
		var g := Gradient.new()
		g.set_color(0, DB.color(dark))
		g.set_color(1, DB.color(light))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		e.adjustment_color_correction = gt
	else:
		e.adjustment_color_correction = _env_saved.get("cc", null)


func _apply_dof() -> void:
	if not dof:
		game.camera.attributes = null
		return
	var a := CameraAttributesPractical.new()
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = 40.0
	a.dof_blur_far_transition = 30.0
	a.dof_blur_amount = 0.12
	game.camera.attributes = a


func _dir(sub: String) -> String:
	var d := DB.saves_dir().get_base_dir().path_join(sub)
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "-")


## Обычный снимок (без подсказки на экране).
func snap() -> String:
	var was := tip.visible if tip else false
	if tip:
		tip.visible = false
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = game.get_viewport().get_texture().get_image()
	var p := _dir("screenshots").path_join("photo_%s.png" % _stamp())
	if img:
		img.save_png(p)
	if tip:
		tip.visible = was
	last_file = p
	_update_tip()
	return p


## Снимок в высоком разрешении: та же сцена отрисовывается отдельно в 2 раза крупнее (до 7680 по ширине).
func snap_hi(k := 2.0) -> String:
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	var size := Vector2i(mini(int(vs.x * k), 7680), mini(int(vs.y * k), 4320))
	var sv := SubViewport.new()
	sv.size = size
	sv.world_3d = game.get_viewport().world_3d
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.global_transform = game.camera.global_transform
	cam.fov = game.camera.fov
	cam.far = game.camera.far
	cam.near = game.camera.near
	cam.attributes = game.camera.attributes
	sv.add_child(cam)
	game.add_child(sv)
	cam.global_transform = game.camera.global_transform
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	var p := _dir("screenshots").path_join("photo_%dx%d_%s.png" % [size.x, size.y, _stamp()])
	if img:
		img.save_png(p)
	sv.queue_free()
	last_file = p
	_update_tip()
	return p


## Запись ролика: кадры идут в файл .avi (до 1920 по ширине, 30 кадров в секунду).
func start_rec() -> void:
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	var maxw := int(DB.setting("video_max_width", 1920))
	var k := minf(1.0, float(maxw) / vs.x)
	var w := int(vs.x * k) / 2 * 2
	var h := int(vs.y * k) / 2 * 2
	rec = AviWriter.new()
	rec_path = _dir("videos").path_join("video_%s.avi" % _stamp())
	if not rec.open(rec_path, w, h, int(DB.setting("video_fps", 30))):
		rec = null
		game.notify("Не удалось начать запись", Color(1, 0.5, 0.4))
		return
	rec_acc = 0.0
	rec_real = 0.0
	_update_tip()


func stop_rec() -> String:
	if rec == null:
		return ""
	var fps: int = int(round(rec.frames / maxf(0.1, rec_real))) if rec_real > 0.5 else rec.fps
	rec.close(clampi(fps, 1, rec.fps))
	var p := rec_path
	last_file = p
	rec = null
	game.get_window().title = "%s %s" % [DB.window_title(), DB.game_version()]
	_update_tip()
	return p


## Каждый кадр: записать кадр ролика (в свой такт 30 к/с).
func update(dt: float) -> void:
	if rec == null:
		return
	rec_real += dt
	rec_acc += dt
	var step := 1.0 / float(rec.fps)
	if rec_acc < step:
		return
	rec_acc = fmod(rec_acc, step)
	var img: Image = game.get_viewport().get_texture().get_image()
	if img:
		rec.add_image(img, float(DB.setting("video_quality", 0.85)))
	if int(rec_real * 2.0) % 2 == 0:
		_update_tip()
