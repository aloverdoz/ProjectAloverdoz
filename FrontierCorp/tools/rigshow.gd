extends Node3D
## Ролик анимации монстров на скелете: стоит, идёт, бьёт, получает урон, умирает. Кадры — в папку.
## Запуск: godot --path . res://tools/rigshow.tscn -- --ids=crawler,brute --out=папка --fps=15 --secs=8

const CreatureRig = preload("res://scripts/creature_rig.gd")
var rigs := []
var out := ""
var fps := 15.0
var secs := 8.0
var frame := 0
var cam: Camera3D
var xs := []

var zoom := 1.0

func _ready() -> void:
	var ids := ["crawler"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			ids = Array(a.substr(6).split(","))
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--fps="):
			fps = float(a.substr(6))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--secs="):
			secs = float(a.substr(7))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.74, 0.86)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.9)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 60)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.5, 0.3)
	g.material_override = gm
	add_child(g)
	# полоски на земле — видно, скользят ли лапы
	for i in 60:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.01, 30)
		m.mesh = bm
		m.position = Vector3(-20 + i * 1.0, 0.005, 0)
		m.material_override = StandardMaterial3D.new()
		(m.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.42, 0.25)
		add_child(m)
	for i in ids.size():
		if ids[i] == "hero":
			var pl = load("res://scripts/player.gd").new()
			pl.game = {"flags": {}, "profession": ""}
			add_child(pl)
			pl.build()
			pl.gun.visible = false
			rigs.append([pl, "hero", -6.0, (i - (ids.size() - 1) / 2.0) * 3.2])
			continue
		var r := CreatureRig.new()
		var md := str(DB.data.enemies.get(ids[i], {}).get("model", ids[i]))
		if not r.build(md):
			print("NO RIG ", ids[i])
			continue
		add_child(r)
		rigs.append([r, ids[i], -6.0, (i - (ids.size() - 1) / 2.0) * 3.2])
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	RenderingServer.global_shader_parameter_set("view_on", 0.0)

func _process(_d: float) -> void:
	var dt := 1.0 / fps
	var t := frame * dt
	var cx := 0.0
	for x in rigs:
		var r = x[0]
		if x[1] == "hero":
			# стоит 1,2 с, идёт до 3,5, бежит до 6, останавливается; в 6,6 — попадание
			var v := 0.0
			if t > 1.2 and t < 3.5:
				v = float(DB.setting("player_speed", 9.0))
			elif t >= 3.5 and t < 6.0:
				v = float(DB.setting("player_sprint", 15.0))
			r.move_dir = r.move_dir.lerp(Vector3(v, 0, 0), minf(1.0, dt * 12.0))
			x[2] += r.move_dir.x * dt
			r.position = Vector3(x[2], 0, x[3])
			r.aim = r.position + Vector3(5, 0, 0)
			r.t += dt
			if absf(t - 6.6) < dt * 0.5:
				r.hurt_t = 0.25
			r.hurt_t = maxf(0.0, r.hurt_t - dt)
			r._animate(dt, t >= 3.5 and t < 6.0)
			cx += x[2]
			continue
		var d: Dictionary = DB.data.enemies.get(x[1], {})
		var sp := float(d.get("speed", 4.0))
		var info := {"speed": sp}
		# 0–1,2 с стоит; 1,2–5 идёт; 5–6 замах и удар; 6–6,6 попадания; 6,6 — смерть
		if t > 1.2 and t < 5.0:
			x[2] += sp * 0.8 * dt
		if t > 5.0 and t < 5.4:
			info["windup"] = (t - 5.0) / 0.4
		if absf(t - 5.4) < dt * 0.5:
			r.strike()
		if t > 6.0 and t < 6.6:
			info["flash"] = 1.0 - fmod(t - 6.0, 0.3) / 0.3
		if absf(t - 6.6) < dt * 0.5:
			r.die(1.0)
		info["target_dir"] = Vector3(1, 0, 0) if t > 4.5 else Vector3.ZERO
		r.animate(dt, Vector3(x[2], 0, x[3]), 0.0, float(d.get("scale", 1.0)), info)
		cx += x[2]
	cx /= maxf(1, rigs.size())
	var sc := 1.0
	if not rigs.is_empty():
		sc = float(DB.data.enemies.get(rigs[0][1], {}).get("scale", 1.0)) * (1.6 if rigs[0][1] == "brute" else 1.0) * (1.5 if rigs[0][1] == "hero" else 1.0)
	sc *= zoom
	cam.position = Vector3(cx + 1.6 * sc, 1.9 * sc, 4.6 * sc)
	cam.look_at(Vector3(cx + 0.3, 0.7 * sc, 0))
	frame += 1
	if frame > 3 and out != "":
		get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [out, frame])
	if t > secs:
		get_tree().quit()
