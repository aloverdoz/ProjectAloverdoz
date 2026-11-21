extends Node
## Настройки игрока (автозагрузка «Prefs»): управление, звук, графика, игра.
## Сам список пунктов меню берётся из options.json, поэтому редактор и моды могут добавлять свои.
## Значения хранятся в user://settings.cfg и применяются сразу.

const FILE := "user://settings.cfg"

var values := {}
var _loaded := false


## 1.3: сплитскрин — "left" у первой копии игры, "right" у второй (вторая не пишет настройки в файл).
var split := ""


func _ready() -> void:
	load_file()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--split="):
			split = a.substr(8)
	if split != "":
		place_split.call_deferred()


func load_file() -> void:
	var cfg := ConfigFile.new()
	var real := DisplayServer.get_name() != "headless" and not " ".join(OS.get_cmdline_user_args()).contains("--test")
	if cfg.load(FILE) == OK and cfg.has_section("prefs"):
		for k in cfg.get_section_keys("prefs"):
			values[k] = cfg.get_value("prefs", k)
		# 1.5: у тех, кто играл раньше, — один раз подстроить графику, если видеокарта встроенная
		if real and not values.has("gpu_checked15"):
			_first_run_quality.call_deferred(true)
	elif real:
		_first_run_quality.call_deferred()
	_loaded = true


## 1.5: первый запуск — подобрать качество под компьютер. Встроенная видеокарта (ноутбуки) — «Средне»,
## а на большом экране (2,5K и больше) картинка считается в разрешении около Full HD и растягивается FSR.
func _first_run_quality(only_integrated := false) -> void:
	var integrated := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	var software := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU or "llvmpipe" in adapter or "swiftshader" in adapter
	var scr := DisplayServer.screen_get_size()
	var px := float(maxi(1, scr.x * scr.y))
	values["gpu_checked15"] = true
	save_file()
	if only_integrated and ((not integrated and not software) or str(get_value("quality", "high")) in ["low", "medium"]):
		return
	if software:
		set_value("quality", "low")
		set_value("render_scale", .65)
	elif integrated:
		set_value("quality", "medium")
		if px > 1920.0 * 1200.0 * 1.1:
			set_value("render_scale", snappedf(clampf(sqrt(1920.0 * 1080.0 / px), 0.6, 1.0), 0.05))
	elif px > 2560.0 * 1440.0 * 1.1:
		set_value("render_scale", 0.85)
	print("Первый запуск: видеокарта %s (%s), экран %dx%d → качество %s, масштаб %s" % [RenderingServer.get_video_adapter_name(),
		"встроенная" if integrated else "отдельная", scr.x, scr.y, get_value("quality", "?"), get_value("render_scale", 1.0)])


func save_file() -> void:
	if split == "right":
		return   # вторая копия игры (второй игрок) — настройки общие с первой, не перезаписываем
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("prefs", k, values[k])
	cfg.save(FILE)


func has(key: String) -> bool:
	return values.has(key)


## Все пункты меню: [{section, key, name, type, default, ...}]
func items() -> Array:
	var out := []
	for sec in DB.data.get("options", {}).get("sections", []):
		for it in sec.get("items", []):
			var d: Dictionary = it.duplicate()
			d["section"] = sec.get("id", "")
			out.append(d)
	return out


func item(key: String) -> Dictionary:
	for it in items():
		if it.get("key", "") == key:
			return it
	return {}


var _defaults := {}
var _defaults_rev := -1


## Значение настройки. Если игрок её не менял — берётся правило игры из редактора (settings.json),
## а если его нет — значение по умолчанию из меню настроек.
func get_value(key: String, def = null):
	if values.has(key):
		return values[key]
	var st: Dictionary = DB.data.get("settings", {})
	if st.has(key):
		return st[key]
	if _defaults_rev != DB.revision:
		_defaults_rev = DB.revision
		_defaults.clear()
		for it in items():
			_defaults[it.get("key", "")] = it.get("default")
	if _defaults.has(key) and _defaults[key] != null:
		return _defaults[key]
	return def


func set_value(key: String, v) -> void:
	values[key] = v
	save_file()
	apply(key)
	if key == "quality":
		_apply_quality(str(v))


func reset_section(sec: String) -> void:
	for it in items():
		if it.section == sec:
			values.erase(it.key)
	save_file()
	apply_all()


# ---------------------------------------------------------------- применение

## Окно на свою половину экрана (сплитскрин), без рамки. split "" — вернуть режим окна из настроек.
func place_split() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if split == "":
		apply("window_mode")
		return
	var scr := DisplayServer.window_get_current_screen()
	var r := DisplayServer.screen_get_usable_rect(scr)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	var w := r.size.x / 2
	DisplayServer.window_set_size(Vector2i(w, r.size.y))
	DisplayServer.window_set_position(r.position + Vector2i(w if split == "right" else 0, 0))


func unsplit() -> void:
	split = ""
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	apply("window_mode")
	apply("resolution")


func apply_all() -> void:
	setup_input()
	for it in items():
		apply(it.key)


func apply(key: String) -> void:
	var v = get_value(key)
	if key.begins_with("key_"):
		_bind(key.substr(4), str(v))
		return
	match key:
		"language":
			if has_node("/root/Lang"):
				get_node("/root/Lang").apply_locale()
		"window_mode":
			if split != "":
				place_split()
				return
			match str(v):
				"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				"borderless": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				_: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"resolution":
			if split != "":
				return
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and str(v) != "auto":
				var p := str(v).split("x")
				if p.size() == 2:
					DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)
		"fps_limit":
			Engine.max_fps = int(v)
		"msaa":
			var m := {"off": Viewport.MSAA_DISABLED, "2x": Viewport.MSAA_2X, "4x": Viewport.MSAA_4X, "8x": Viewport.MSAA_8X}
			get_viewport().msaa_3d = m.get(str(v), Viewport.MSAA_4X)
		"fxaa":
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if v else Viewport.SCREEN_SPACE_AA_DISABLED
		"render_scale":
			# больше 1 — суперсэмплинг: картинка считается крупнее экрана и сжимается (как 4K на Full HD)
			get_viewport().scaling_3d_scale = clampf(float(v), 0.5, 2.0)
			# 1.5: меньше 1 — растягиваем FSR (резче, чем простое растяжение)
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if float(v) < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
		"lod_px":
			# насколько сильно упрощать дальние модели: разница в пикселях, которую не заметить
			get_viewport().mesh_lod_threshold = clampf(float(v), 0.0, 16.0)
		"detail_dist":
			RenderingServer.global_shader_parameter_set("detail_dist", float(v))
		"aniso":
			# 0 выкл, 1 2x, 2 4x, 3 8x, 4 16x (свойство вьюпорта или общая настройка проекта — смотря что есть в движке)
			var lvl: int = {"off": 0, "2x": 1, "4x": 2, "8x": 3, "16x": 4}.get(str(v), 2)
			if "anisotropic_filtering_level" in get_viewport():
				get_viewport().set("anisotropic_filtering_level", lvl)
			else:
				ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", lvl)
		"soft_shadows":
			var sq := {"off": RenderingServer.SHADOW_QUALITY_HARD, "low": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
				"high": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "ultra": RenderingServer.SHADOW_QUALITY_SOFT_ULTRA}
			RenderingServer.directional_soft_shadow_filter_set_quality(sq.get(str(v), RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM))
			RenderingServer.positional_soft_shadow_filter_set_quality(sq.get(str(v), RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM))
		"ui_scale":
			get_tree().root.content_scale_factor = clampf(float(v), 0.6, 2.0)
		"vol_master":
			Sfx.set_volume("Master", float(v))
		"vol_music":
			Sfx.set_volume("Music", float(v))
		"vol_effects":
			Sfx.set_volume("Effects", float(v))
		"vol_ambient":
			Sfx.set_volume("Ambient", float(v))
		"vol_ui":
			Sfx.set_volume("UI", float(v))
	# остальное (тени, трава, дальность, поле зрения...) читает сама игра каждый кадр
	var main = get_tree().current_scene
	if main and main.has_method("on_pref_changed"):
		main.on_pref_changed(key)


func _apply_quality(q: String) -> void:
	var presets := {
		"low": {"clouds_lq": true, "lod_px": 8, "live_anim_max": 4, "shadows": "off", "ssao": false, "glow": false, "grass": false, "msaa": "off", "render_scale": 0.75, "detail_dist": 40, "aniso": "off", "soft_shadows": "off", "ssil": false, "dof": false, "vignette": false, "grass_dense": false, "flora_less": true, "menu_live": false},
		"medium": {"clouds_lq": true, "lod_px": 4, "live_anim_max": 10, "shadows": "low", "ssao": false, "glow": true, "grass": true, "msaa": "2x", "render_scale": 1.0, "detail_dist": 60, "aniso": "2x", "soft_shadows": "low", "ssil": false, "dof": false, "vignette": true, "grass_dense": false, "flora_less": true},
		"high": {"clouds_lq": false, "lod_px": 2, "live_anim_max": 14, "shadows": "high", "ssao": true, "glow": true, "grass": true, "msaa": "4x", "render_scale": 1.0, "detail_dist": 90, "aniso": "4x", "soft_shadows": "medium", "ssil": true, "dof": true, "vignette": true, "grass_dense": true, "flora_less": false},
		"ultra": {"clouds_lq": false, "lod_px": 1, "live_anim_max": 24, "shadows": "ultra", "ssao": true, "glow": true, "grass": true, "msaa": "8x", "render_scale": 1.0, "detail_dist": 180, "aniso": "16x", "soft_shadows": "high", "ssil": true, "dof": true, "vignette": true, "grass_dense": true, "flora_less": false},
		# «Кино»: всё на максимум и суперсэмплинг ×1,5 — картинка уровня 4K даже на Full HD (нужна мощная видеокарта)
		"cinema": {"clouds_lq": false, "lod_px": 0.5, "live_anim_max": 40, "shadows": "ultra", "ssao": true, "glow": true, "grass": true, "msaa": "8x", "render_scale": 1.5, "detail_dist": 300, "aniso": "16x", "soft_shadows": "ultra", "ssil": true, "dof": true, "vignette": true, "grass_dense": true, "flora_less": false},
	}
	if not presets.has(q):
		return
	for k in presets[q]:
		values[k] = presets[q][k]
		apply(k)
	save_file()


# ---------------------------------------------------------------- управление

func setup_input() -> void:
	for it in items():
		if str(it.get("key", "")).begins_with("key_"):
			_bind(it.key.substr(4), str(get_value(it.key)))


## Назначить клавишу или кнопку мыши действию. Имя клавиши — как в Godot: "W", "Shift", "Mouse1".
func _bind(action: String, key_name: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := event_from_name(key_name)
	if ev:
		InputMap.action_add_event(action, ev)


static func event_from_name(n: String) -> InputEvent:
	if n.begins_with("Mouse"):
		var mb := InputEventMouseButton.new()
		mb.button_index = int(n.substr(5)) as MouseButton
		return mb
	var code := OS.find_keycode_from_string(n)
	if code == KEY_NONE:
		return null
	var k := InputEventKey.new()
	k.physical_keycode = code
	return k


static func event_name(ev: InputEvent) -> String:
	if ev is InputEventMouseButton:
		return "Mouse%d" % ev.button_index
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(code)
	return ""
