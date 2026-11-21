class_name Drops
extends Node3D
## Предметы на земле: вылетают из дерева или камня, падают, крутятся, светятся
## и сами притягиваются к герою, когда он проходит рядом.

class D:
	var id := ""
	var n := 1
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var t := 0.0
	var spin := 0.0
	var landed := false
	var magnet := false
	var rolling := false   # 21: после падения катится под горку и отскакивает от зданий
	var who = null         # 1.3: к какому герою летит (сплитскрин — героев двое)
	var slot := {}         # A-11 r4: предмет с износом/свежестью (украденный инструмент) — подбирается как есть

var game
var list: Array = []
var renderers := {}   # model -> PartRenderer
var halo: PartRenderer


func setup() -> void:
	halo = PartRenderer.new()
	var hm := ShaderMaterial.new()
	hm.shader = ModelLib.PART_SHADER
	hm.set_shader_parameter("emission", 2.5)
	hm.set_shader_parameter("anim", 2)
	hm.set_shader_parameter("speed", 4.0)
	hm.set_shader_parameter("amount", 1.0)
	hm.set_shader_parameter("always", true)
	halo.add_part(ModelLib.unit_mesh("torus", 1.0, 20), hm, Transform3D(Basis.from_scale(Vector3(0.9, 0.25, 0.9)), Vector3.ZERO), Color.WHITE, false, false)
	add_child(halo)


func _renderer(model: String) -> PartRenderer:
	if not renderers.has(model):
		var r := ModelLib.make_renderer(model, true)
		add_child(r)
		renderers[model] = r
	return renderers[model]


func spawn(id: String, n: int, at: Vector3) -> void:
	if n <= 0 or not DB.data.items.has(id) or (Inventory.no_personal and DB.personal_item(id)):
		return
	if not DB.setting("drops_on_ground", true):
		var left: int = game.player.inv.add(id, n)
		game.on_picked(id, n - left)
		if left > 0:
			_spawn_real(id, left, at)
		return
	_spawn_real(id, n, at)


## A-11 r4: выронить слот целиком (с износом/свежестью).
func spawn_slot(sl: Dictionary, at: Vector3) -> void:
	if not (sl.has("dur") or sl.has("fresh")):
		spawn(str(sl.get("id", "")), int(sl.get("n", 0)), at)
		return
	if int(sl.get("n", 0)) <= 0 or not DB.data.items.has(str(sl.get("id", ""))):
		return
	_spawn_real(str(sl.id), int(sl.n), at)
	list[-1].slot = sl.duplicate()


func _spawn_real(id: String, n: int, at: Vector3) -> void:
	var d := D.new()
	d.id = id
	d.n = n
	d.pos = at
	var a := randf() * TAU
	d.vel = Vector3(cos(a) * randf_range(1.5, 3.5), randf_range(4.0, 6.5), sin(a) * randf_range(1.5, 3.5))
	d.spin = randf() * TAU
	list.append(d)
	var model: String = DB.item(id).get("model", "drop_box")
	var r := _renderer(model)
	r.add(d, Transform3D(Basis(), at), 1.0)
	var col := DB.item_color(id)
	for i in r.parts.size():
		if r.parts[i].color == Color.WHITE:
			r.set_part_color(d, i, col)
	halo.add(d, Transform3D(Basis(), at), 1.0)
	halo.set_part_color(d, 0, col)


func update(delta: float) -> void:
	if list.is_empty():
		return
	var sp_on: bool = game.split != null and game.split.active
	var pls: Array = game.split.local_players() if sp_on else [game.player]
	var glow_t := float(DB.setting("drop_glow_time", 60))
	var life := float(DB.setting("drop_lifetime", 300))
	var pick_r := float(DB.setting("pickup_radius", 2.2))
	var done := []
	var picked := []
	for d in list:
		d.t += delta
		d.spin += delta * 2.5
		if not d.landed:
			d.vel.y -= 18.0 * delta
			d.pos += d.vel * delta
			var floor_y: float = game.factory.support_at(d.pos) + 0.35
			if d.pos.y <= floor_y:
				d.pos.y = floor_y
				if absf(d.vel.y) > 2.0:
					d.vel = Vector3(d.vel.x * 0.55, -d.vel.y * 0.35, d.vel.z * 0.55)
				else:
					d.landed = true
					d.rolling = _roll_on()
					d.vel.y = 0.0
			_bounce(d)
		elif d.rolling and not d.magnet:
			_roll(d, delta)
		if game.strategy:
			# 1.1.15: стратегия — проведите курсором по добыче: она взлетает и улетает к панели уровня (в рюкзак)
			# 1.1.16: по земле (без высоты: курсор над крышей или склоном тоже берёт); рюкзак полон — в штаб
			var hv: Vector3 = World.delta(d.pos, game.hover_point)
			hv.y = 0.0
			if d.t > 0.4 and not d.magnet and hv.length() < float(DB.setting("strategy_pick_r", 2.6)):
				var left2: int = game.player.inv.add(d.id, d.n) if d.slot.is_empty() else game.player.inv.add_slot(d.slot)
				var got2: int = d.n - left2
				if got2 > 0:
					game.on_picked(d.id, got2)
				if left2 > 0:
					game.overflow(d.id, left2, d.pos, d.slot)
					left2 = 0
				fly_to_panel(d.id, d.n, d.pos)
				if left2 == 0:
					done.append(d)
					picked.append(d)
					d.who = game.player
					continue
				d.n = left2
		elif not d.magnet and d.t > 0.5:
			for pl in pls:
				var to: Vector3 = World.delta(d.pos, pl.position)
				to.y = 0
				if pl.alive and to.length() < pick_r and pl.inv.can_add(d.id, 1):
					d.magnet = true
					d.who = pl
					break
		if d.magnet and (d.who == null or not is_instance_valid(d.who)):
			d.who = game.player
		if d.magnet:
			var pp: Vector3 = d.who.position
			var rel := World.delta(d.pos, pp + Vector3(0, 1.0, 0))
			rel.y = pp.y + 1.0 - d.pos.y
			d.pos += rel * min(1.0, delta * 12.0)
			if rel.length() < 0.6:
				var left: int = d.who.inv.add(d.id, d.n) if d.slot.is_empty() else d.who.inv.add_slot(d.slot)
				var got: int = d.n - left
				var id: String = d.id
				if sp_on:
					game.split.with_seat(1 if d.who == game.split.p2() else 0, func(): game.on_picked(id, got))
				else:
					game.on_picked(id, got)
				if left == 0:
					done.append(d)
					picked.append(d)
					continue
				d.n = left
				d.magnet = false
		d.pos = World.wrap_pos(d.pos)
		if d.t > life:
			done.append(d)
			continue
		var bob := sin(d.t * 3.0) * 0.12 if d.landed else 0.0
		var xf := Transform3D(Basis(Vector3.UP, d.spin).scaled(Vector3.ONE * clampf(float(DB.item(d.id).get("model_scale", 1.0)), 0.2, 3.0)), d.pos + Vector3(0, bob, 0))
		var r: PartRenderer = renderers[DB.item(d.id).get("model", "drop_box")]
		r.set_xform(d, xf)
		var glow := 1.0 - smoothstep(glow_t * 0.8, glow_t, d.t)
		var hs := 0.001 if glow <= 0.01 else glow
		halo.set_xform(d, Transform3D(Basis().scaled(Vector3.ONE * hs), Vector3(d.pos.x, 0.05, d.pos.z)))
	for d in done:
		list.erase(d)
		var r: PartRenderer = renderers.get(DB.item(d.id).get("model", "drop_box"))
		if r:
			r.remove(d)
		halo.remove(d)
		if d in picked:
			game.sfx.play("pickup", d.who.position if d.who != null and is_instance_valid(d.who) else game.player.position)


## 1.1.15: значок предмета взлетает с места на экране и летит к панели уровня (слева сверху), там тает.
func fly_to_panel(id: String, n: int, at: Vector3) -> void:
	var hud = game.hud
	if hud == null or game.camera == null or Net.dedicated:
		return
	var cam: Camera3D = game.camera
	if cam.is_position_behind(at):
		return
	var from: Vector2 = cam.unproject_position(at + Vector3(0, 0.6, 0)) / hud.root.get_tree().root.content_scale_factor
	var corp: Control = hud.panels.get("corp")
	var to := Vector2(60, 40)
	if corp != null and corp.visible:
		to = corp.position + Vector2(34, corp.size.y * 0.5) * corp.scale
	var ic: Control = UI.item_icon(id, 40)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.pivot_offset = Vector2(20, 20)
	ic.position = from - Vector2(20, 20)
	hud.root.add_child(ic)
	var lb := UI.label("+%d" % n, 14, Color(1, 0.95, 0.6))
	lb.position = Vector2(30, -6)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(lb)
	var up := from + Vector2(randf_range(-30, 30), -70) - Vector2(20, 20)
	var tw: Tween = ic.create_tween()
	tw.tween_property(ic, "position", up, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "scale", Vector2.ONE * 1.25, 0.22)
	tw.tween_property(ic, "position", to - Vector2(20, 20), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ic, "scale", Vector2.ONE * 0.55, 0.55)
	tw.tween_property(ic, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		ic.queue_free()
		if corp != null and is_instance_valid(corp):
			var pt: Tween = corp.create_tween()
			corp.pivot_offset = Vector2(20, 20)
			pt.tween_property(corp, "modulate", Color(1.25, 1.2, 0.9), 0.06)
			pt.tween_property(corp, "modulate", Color.WHITE, 0.2))
	flying += 1
	tw.tween_callback(func(): flying -= 1)


var flying := 0


# ---------------------------------------------------------------- 21: физика предметов

func _roll_on() -> bool:
	var c = DB.setting("physics", {})
	return not (c is Dictionary) or (bool(c.get("enabled", true)) and bool(c.get("roll", true)))


## Предмет врезался в стену здания — отскакивает обратно.
func _bounce(d: D) -> void:
	var b = game.factory.grid.get(World.world_to_cell(d.pos))
	if b != null and not game.factory.walkable(b) and b.beh != "belt" and d.pos.y < game.factory.roof_top(b):
		var back: Vector3 = d.pos - Vector3(d.vel.x, 0, d.vel.z) * 0.04
		d.vel.x *= -0.5
		d.vel.z *= -0.5
		d.pos.x = back.x
		d.pos.z = back.z


## Катится: под уклон разгоняется, трение тормозит, остановился — лежит.
func _roll(d: D, delta: float) -> void:
	var f = game.factory
	var e := 0.6
	var gx: float = f.support_at(d.pos + Vector3(e, 0, 0)) - f.support_at(d.pos - Vector3(e, 0, 0))
	var gz: float = f.support_at(d.pos + Vector3(0, 0, e)) - f.support_at(d.pos - Vector3(0, 0, e))
	var slope := Vector3(-gx, 0, -gz) / (2.0 * e)
	if slope.length() > 0.12:
		d.vel += slope * 18.0 * delta
	d.vel *= maxf(0.0, 1.0 - delta * 2.2)
	if d.vel.length() < 0.08 and slope.length() <= 0.12:
		d.rolling = false
		d.vel = Vector3.ZERO
		return
	d.pos += d.vel * delta
	_bounce(d)
	d.pos.y = f.support_at(d.pos) + 0.35
	d.spin += d.vel.length() * delta * 1.5


## 21: забрать предмет с земли (дрон-сборщик).
func take(d: D) -> void:
	if not d in list:
		return
	list.erase(d)
	var r: PartRenderer = renderers.get(DB.item(d.id).get("model", "drop_box"))
	if r:
		r.remove(d)
	halo.remove(d)
