class_name Minimap
extends Control
## Миникарта (в углу экрана) и большая карта (клавиша M).
## Землю рисует шейдер прямо из карт мира, сверху — герой, штаб, здания, гнёзда, монстры и метки.
## Всё настраивается: Данные → «Правила игры» → «Миникарта…».

var game
var big := false          # большая карта: колесо — масштаб, перетаскивание — сдвиг, ЛКМ — метка, ПКМ — убрать
var view_m := 220.0       # сколько метров видно поперёк
var pan := Vector3.ZERO   # сдвиг большой карты от героя
var land: ColorRect
var mat: ShaderMaterial
var _acc := 0.0
var _drag := false
var _moved := 0.0


func setup(p_game, p_big: bool) -> void:
	game = p_game
	big = p_big
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if big else Control.MOUSE_FILTER_IGNORE
	land = ColorRect.new()
	land.set_anchors_preset(Control.PRESET_FULL_RECT)
	land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	land.show_behind_parent = true   # значки рисуются поверх земли
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/minimap.gdshader")
	land.material = mat
	add_child(land)
	view_m = float(DB.setting("bigmap_range" if big else "minimap_range", 900.0 if big else 220.0))
	if game.world.ocean and not big: view_m = 64.
	_bind_world()


func _bind_world() -> void:
	var w = game.world
	if w == null or w.splat_tex == null:
		return
	mat.set_shader_parameter("splat", w.splat_tex)
	mat.set_shader_parameter("water", w.water_tex)
	mat.set_shader_parameter("height_map", w.height_tex)
	mat.set_shader_parameter("ore_map", w.ore_tex)
	mat.set_shader_parameter("occ", w.occ_tex)
	mat.set_shader_parameter("world_size", w.W * World.C)
	mat.set_shader_parameter("cell", World.C)
	mat.set_shader_parameter("wrap", w.wrap)
	if w.ground_mat:
		for pair in [["c_grass", "c_grass_a"], ["c_dirt", "c_dirt"], ["c_sand", "c_sand"], ["c_rock", "c_rock"], ["c_snow", "c_snow"]]:
			var v = w.ground_mat.get_shader_parameter(pair[1])
			if v != null:
				mat.set_shader_parameter(pair[0], v)
	set_meta("bound", true)


## Поворот: миникарта крутится вместе с камерой (верх — куда смотрит камера), большая — север сверху.
func _rot() -> float:
	if big or not bool(DB.setting("minimap_rotate", true)):
		return 0.0
	return game.cam_yaw


func _center() -> Vector3:
	var c: Vector3 = game.player.position + (pan if big else Vector3.ZERO)
	return World.wrap_pos(c) if game.world.wrap else c


func _process(delta: float) -> void:
	if not is_visible_in_tree() or game == null or game.player == null:
		return
	if not has_meta("bound"):
		_bind_world()
	var c := _center()
	if game.world.ocean:
		mat.set_shader_parameter("ocean",true)
		mat.set_shader_parameter("chart_only",big)
		mat.set_shader_parameter("chart_origin",Vector2(game.world.chart_origin)*World.C)
	mat.set_shader_parameter("center", Vector2(c.x, c.z))
	mat.set_shader_parameter("view_m", view_m)
	mat.set_shader_parameter("rot", _rot())
	mat.set_shader_parameter("aspect", size.y / maxf(1.0, size.x))
	mat.set_shader_parameter("round_mask", not big and bool(DB.setting("minimap_round", true)))
	var fg = game.fog
	var fon: bool = fg != null and fg.on() and fg.tex != null
	mat.set_shader_parameter("fog_on", fon)
	# граница зоны берётся из общих значений шейдеров (zone.gd)
	if fon and mat.get_shader_parameter("fog_tex") != fg.tex:
		mat.set_shader_parameter("fog_tex", fg.tex)
	_acc += delta
	if _acc > 0.05:
		_acc = 0.0
		queue_redraw()


## Точка мира -> точка на карте.
func to_screen(p: Vector3) -> Vector2:
	var d: Vector3 = World.delta(_center(), p)
	var r := _rot()
	var c := cos(r)
	var s := sin(r)
	var u := Vector2(c * d.x - s * d.z, s * d.x + c * d.z) / view_m
	return Vector2((u.x + 0.5) * size.x, u.y * size.x + size.y * 0.5)


## Точка на карте -> точка мира.
func to_world(sp: Vector2) -> Vector3:
	var u := Vector2(sp.x / size.x - 0.5, (sp.y - size.y * 0.5) / size.x)
	var r := _rot()
	var c := cos(r)
	var s := sin(r)
	var d := Vector2(c * u.x + s * u.y, -s * u.x + c * u.y) * view_m
	var p := _center() + Vector3(d.x, 0, d.y)
	return World.wrap_pos(p) if game.world.wrap else p


func _inside(sp: Vector2) -> bool:
	if big or not bool(DB.setting("minimap_round", true)):
		return Rect2(Vector2.ZERO, size).has_point(sp)
	return sp.distance_to(size * 0.5) < size.x * 0.5 - 3.0


func _draw() -> void:
	if game == null or game.factory == null:
		return
	var px := size.x / view_m    # пикселей на метр
	if big and game.world.ocean:
		var footprint: float = World.ISLAND_CHUNK*World.C*px
		for key in game.world.chart_tiles:
			var at := to_screen(World.cell_to_world(key*game.world.ISLAND_CHUNK)-Vector3(World.C/2.,0,World.C/2.))
			if not Rect2(Vector2.ZERO,size).grow(footprint*1.5).has_point(at): continue
			draw_set_transform(at,_rot(),Vector2.ONE*px*World.C)
			draw_texture(game.world.chart_tiles[key],Vector2.ZERO)
		draw_set_transform(Vector2.ZERO,0.,Vector2.ONE)
	# здания цветом своего раздела меню
	for b in game.factory.all:
		var sp := to_screen(b.center())
		if not _inside(sp):
			continue
		var cat: Dictionary = DB.data.categories.get(DB.building(b.type).get("category", ""), {})
		var col := DB.color(cat.get("color", "#a0a4ab"))
		if b.beh == "belt":
			col = Color(0.75, 0.77, 0.8)
		elif b.beh == "foundation":
			col = Color(0.72, 0.7, 0.64)
		var hs := maxf(1.5, b.size * World.C * px * 0.5)
		draw_rect(Rect2(sp - Vector2(hs, hs), Vector2(hs, hs) * 2.0), col)
	# штаб
	if game.factory.hq:
		var hp := to_screen(game.factory.hq.center())
		if _inside(hp) or big:
			hp = _clamp_edge(hp)
			draw_circle(hp, 7.0, Color(0.1, 0.1, 0.12))
			draw_circle(hp, 5.0, UI.ACCENT)
	# гнёзда
	for n in game.world.nests:
		if not n.alive or (game.fog and not game.fog.explored(n.pos)):
			continue
		var np := to_screen(n.pos)
		if _inside(np):
			draw_circle(np, maxf(4.0, 6.0 * px), Color(0.7, 0.15, 0.85))
			draw_arc(np, maxf(5.0, 7.0 * px), 0, TAU, 16, Color(0, 0, 0, 0.7), 1.5)
	# подземелья (открытые туманом): оранжевые — не пройдены, серые — пройдены
	if game.dungeons:
		for d in game.dungeons.list:
			var dw: Vector3 = World.cell_to_world(d.cell)
			if game.fog and not game.fog.explored(dw):
				continue
			var dp := to_screen(dw)
			if _inside(dp) or big:
				dp = _clamp_edge(dp)
				draw_rect(Rect2(dp - Vector2(6, 6), Vector2(12, 12)), Color(0, 0, 0, 0.8))
				draw_rect(Rect2(dp - Vector2(4.5, 4.5), Vector2(9, 9)), Color(0.55, 0.55, 0.55) if d.done else Color(1.0, 0.55, 0.15))
				if big:
					draw_string(get_theme_font("font", "Label"), dp + Vector2(9, 5), "Подземелье" + (" (пройдено)" if d.done else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# монстры рядом с героем
	if bool(DB.setting("minimap_enemies", true)):
		var vr: float = game.view_range()
		for e in game.enemies.list:
			if not e.alive or World.dist(e.pos, game.player.position) > vr:
				continue
			if (game.fog and not game.fog.explored(e.pos)) or (game.zone and not game.zone.inside(e.pos)):
				continue
			var ep := to_screen(e.pos)
			if _inside(ep):
				# 1.7: мирные (торговцы, путники) — зелёные, враги — красные
				draw_circle(ep, 3.0, Color(0.3, 0.95, 0.4) if e.peaceful else Color(1, 0.25, 0.2))
	# сундуки на месте гибели
	for g in game.graves:
		var gp := _clamp_edge(to_screen(g.pos))
		draw_rect(Rect2(gp - Vector2(4, 4), Vector2(8, 8)), Color(1, 0.3, 0.3))
	# метки игрока
	for m in game.marks:
		var mp := _clamp_edge(to_screen(Vector3(m.x, 0, m.z)))
		var mc := DB.color(m.get("color", "#ffd040"))
		var pts := PackedVector2Array([mp + Vector2(0, -7), mp + Vector2(6, 0), mp + Vector2(0, 7), mp + Vector2(-6, 0)])
		draw_colored_polygon(pts, mc)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 1.5)
		if big and str(m.get("name", "")) != "":
			draw_string(get_theme_font("font", "Label"), mp + Vector2(9, 5), str(m.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	# герой: стрелка по направлению взгляда
	var pp := to_screen(game.player.position)
	var a: float = game.player.hips.rotation.y
	var fwd := Vector3(cos(a), 0, -sin(a))
	var tip := to_screen(game.player.position + fwd * view_m * 0.04) - pp
	var dir := tip.normalized() if tip.length() > 0.01 else Vector2.UP
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([pp + dir * 9.0, pp - dir * 6.0 + side * 6.0, pp - dir * 3.0, pp - dir * 6.0 - side * 6.0])
	draw_colored_polygon(arrow, Color.WHITE)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0, 0, 0, 0.9), 1.5)
	# север
	var north := to_screen(_center() + Vector3(0, 0, -view_m)) - size * 0.5
	var np2 := size * 0.5 + north.normalized() * (size.x * 0.5 - 12.0)
	if not big:
		draw_circle(np2, 9.0, Color(0.08, 0.09, 0.11))
		draw_string(get_theme_font("font", "Label"), np2 + Vector2(-5, 5), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.45, 0.4))
	else:
		draw_string(get_theme_font("font", "Label"), Vector2(size.x - 30, 24), "С ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.45, 0.4))
		draw_string(get_theme_font("font", "Label"), Vector2(10, size.y - 10), "%d м поперёк · колесо — масштаб · тянуть — сдвиг · ЛКМ — метка · ПКМ — убрать метку · пробел — к герою" % int(view_m),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85))


## Важные значки (штаб, метки) у края карты, если они дальше видимого.
func _clamp_edge(p: Vector2) -> Vector2:
	var c := size * 0.5
	var d := p - c
	var lim := size.x * 0.5 - 8.0
	if big:
		return Vector2(clampf(p.x, 8.0, size.x - 8.0), clampf(p.y, 8.0, size.y - 8.0))
	if bool(DB.setting("minimap_round", true)):
		return c + d.limit_length(lim)
	return Vector2(clampf(p.x, 8.0, size.x - 8.0), clampf(p.y, 8.0, size.y - 8.0))


func _gui_input(ev: InputEvent) -> void:
	if not big:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			view_m = maxf(60.0, view_m * 0.85)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			view_m = view_m*1.18 if game.world.ocean else minf(game.world.W * World.C * 1.2, view_m * 1.18)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				_moved = 0.0
			else:
				_drag = false
				if _moved < 6.0:
					add_mark(to_world(mb.position))
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			remove_mark_near(mb.position)
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		var mm := ev as InputEventMouseMotion
		_moved += mm.relative.length()
		pan -= Vector3(mm.relative.x, 0, mm.relative.y) * view_m / size.x
		accept_event()
	elif ev is InputEventKey and ev.pressed and (ev as InputEventKey).keycode == KEY_SPACE:
		pan = Vector3.ZERO
		accept_event()


func add_mark(p: Vector3) -> void:
	var cols := ["#ffd040", "#40c8ff", "#ff6a5a", "#7dff6a", "#d07dff"]
	game.marks.append({"x": snappedf(p.x, 0.1), "z": snappedf(p.z, 0.1), "name": "Метка %d" % (game.marks.size() + 1), "color": cols[game.marks.size() % cols.size()]})
	game.sfx.play_ui("click")
	queue_redraw()


func remove_mark_near(sp: Vector2) -> void:
	for i in range(game.marks.size() - 1, -1, -1):
		var m: Dictionary = game.marks[i]
		if to_screen(Vector3(m.x, 0, m.z)).distance_to(sp) < 12.0:
			game.marks.remove_at(i)
			game.sfx.play_ui("click")
			queue_redraw()
			return
