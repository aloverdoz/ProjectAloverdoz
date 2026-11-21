extends Node3D
## Живой монстр (или НПС) рядом с героем: модель на скелете, игра сама двигает кости каждый кадр.
## Скелет описан в модели («rig»): кости, ноги, руки, голова, челюсти, хвосты и усики, дыхание, параметры походки.
## Вдали тот же монстр рисуется быстрым общим MultiMesh (enemies.gd), а здесь — полноценная анимация:
##  • шаги в такт пройденному пути (ноги не скользят), ноги в фазах как у настоящих животных;
##  • перенос веса: корпус покачивается вверх-вниз и с боку на бок, наклон вперёд на бегу и вбок на поворотах;
##  • стоит — дышит, оглядывается, хвост и усики живут своей жизнью;
##  • перед ударом замах (голова вверх, пасть открыта), удар — рывок вперёд;
##  • попадание — вздрагивает и вспыхивает; смерть — заваливается набок, лапы поджимаются, тело уходит в землю.

var clip_player: AnimationPlayer
var clip_name := ""
var rig: Dictionary = {}
var gait: Dictionary = {}
var bones := {}          # имя -> Node3D
var rest := {}           # имя -> Vector3 (положение в покое относительно родителя)
var meshes: Array = []   # [MultiMesh, цвет, подкрашивать]
var root_bone := ""
var phase := 0.0
var amp := 0.0           # сила походки 0..1
var t := 0.0
var last_pos := Vector3.INF
var last_yaw := 0.0
var turn := 0.0          # скорость поворота, рад/с (сглаженная)
var atk_t := 9.0         # время с начала удара
var dead_t := -1.0       # время с момента смерти (-1 — жив)
var dead_side := 1.0
var hit_side := 1.0
var look := 0.0          # поворот головы
var seed_k := 0.0
var acc_dt := 0.0         # пропущенное время (дальние монстры обновляют позу реже)
var slot := randi() % 6
var wheel_dist := 0.0     # сколько проехали колёса (поворот колеса = путь / радиус)
var spin := 0.0           # угол винтов, рад


func build(model_id: String, tint := Color.WHITE, tint_k := 0.0) -> bool:
	var m: Dictionary = ModelLib.model(model_id)
	if m.get("animated_colony", false):
		var scene := ModelLib.glb_instance(str(m.glb))
		if scene == null:
			return false
		clip_player = ModelLib.glb_player(scene)
		if clip_player == null:
			scene.free()
			return false
		var factor := float(m.get("scale", 1))
		scene.transform = Transform3D(Basis.from_scale(Vector3.ONE * factor), Vector3.ZERO) * ModelLib.glb_offset(m)
		add_child(scene)
		for clip in ["Idle", "Walk", "Run", "Fly"]:
			if clip_player.has_animation(clip):
				clip_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		return true
	rig = m.get("rig", {})
	if rig.is_empty() or rig.get("bones", []).is_empty():
		return false
	gait = rig.get("gait", {})
	seed_k = randf() * 100.0
	var piv := {}
	for b in rig.bones:
		piv[b.name] = ModelLib.v3(b.pivot)
	for b in rig.bones:
		var n := Node3D.new()
		n.name = str(b.name).replace(":", "_")
		bones[b.name] = n
		var par := str(b.get("parent", ""))
		rest[b.name] = piv[b.name] - (piv[par] if piv.has(par) else Vector3.ZERO)
		n.position = rest[b.name]
		if root_bone == "" and par == "":
			root_bone = b.name
	for b in rig.bones:
		var par := str(b.get("parent", ""))
		(bones[par] if bones.has(par) else self).add_child(bones[b.name])
	var g := float(m.get("scale", 1.0))
	if _build_skin(m, piv, tint, tint_k):
		return true
	for p in ModelLib.merged_parts(model_id, true, true):
		var role := str(p[5])
		if not bones.has(role):
			role = root_bone
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = p[0]
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D.IDENTITY)
		var col: Color = Enemies.recolor(p[3], tint, tint_k) if p[4] and tint_k > 0.0 else p[3]
		mm.set_instance_color(0, col)
		# x = 0: шейдерные «шаги» выключены — ногами двигает скелет
		mm.set_instance_custom_data(0, Color(0.0, randf(), 0, 0))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = p[1]
		mi.transform = Transform3D(Basis.IDENTITY, -piv[role] * g) * p[2] if piv.has(role) else p[2]
		bones[role].add_child(mi)
		meshes.append([mm, col, p[4]])
	return true


## Модель с гладкой сеткой на костях (автоскелет нейросети, поле «skin»): одна сетка, вершины тянутся за костями
## с плавными весами у суставов — без щелей. Кости скелета повторяют узлы-кости этого монстра каждый кадр.
var skel: Skeleton3D = null
var skel_names: Array = []
var skin_mi: MeshInstance3D = null

func _build_skin(m: Dictionary, piv: Dictionary, _tint: Color, _tint_k: float) -> bool:
	var sd = m.get("skin", {})
	if not (sd is Dictionary) or sd.is_empty():
		return false
	var mesh := ModelLib.part_mesh({"shape": "mesh", "mesh": str(sd.get("mesh", ""))})
	if mesh == null or mesh.get_surface_count() == 0 or (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES) == 0:
		return false
	skel_names = sd.get("bones", [])
	for bn in skel_names:
		if not bones.has(bn):
			return false
	skel = Skeleton3D.new()
	add_child(skel)
	var skin := Skin.new()
	for i in skel_names.size():
		skel.add_bone(_bn(skel_names[i]))   # в имени кости скелета нельзя «:»
	for i in skel_names.size():
		var bn: String = skel_names[i]
		var pn := ""
		for b in rig.bones:
			if b.name == bn:
				pn = str(b.get("parent", ""))
		skel.set_bone_parent(i, skel_names.find(pn))
		skel.set_bone_rest(i, Transform3D(Basis(), rest[bn]))
		skin.add_named_bind(_bn(bn), Transform3D(Basis(), -piv[bn]))
	skel.reset_bone_poses()
	skin_mi = MeshInstance3D.new()
	skin_mi.mesh = mesh
	skin_mi.skin = skin
	var p0: Dictionary = m.get("parts", [{}])[0] if not m.get("parts", []).is_empty() else {}
	skin_mi.material_override = ModelLib.material(p0, true, false, false)
	skel.add_child(skin_mi)
	skin_mi.skeleton = NodePath("..")
	return true


static func _bn(s: String) -> String:
	return s.replace(":", "_").replace("/", "_")


func _sync_skin() -> void:
	if skel == null:
		return
	for i in skel_names.size():
		var n: Node3D = bones[skel_names[i]]
		skel.set_bone_pose_position(i, n.position)
		skel.set_bone_pose_rotation(i, n.basis.get_rotation_quaternion())
		skel.set_bone_pose_scale(i, n.basis.get_scale())


func set_flash(f: float) -> void:
	for x in meshes:
		if not x[2] or x[0] == null:
			continue
		var c: Color = x[1]
		if f > 0.0:
			c = c.lerp(Color(1.4, 0.55, 0.45), clampf(f, 0.0, 1.0) * 0.7)
		x[0].set_instance_color(0, c)


func strike() -> void:
	atk_t = 0.0


func die(side: float) -> void:
	dead_t = 0.0
	dead_side = side


func _rot(name: String, axis: Vector3, deg: float) -> void:
	if bones.has(name) and absf(deg) > 0.001:
		var n: Node3D = bones[name]
		n.basis = n.basis * Basis(axis, deg_to_rad(deg))


## pos — где монстр в мире (уже со сдвигом под зацикленный мир), yaw — куда смотрит, scale — размер.
## info: speed (номинальная скорость), moving, windup 0..1 (замах), flash, target_dir (Vector3 или ZERO).
func animate(delta: float, pos: Vector3, yaw: float, scale_k: float, info: Dictionary) -> void:
	t += delta
	atk_t += delta
	if clip_player != null:
		var movement := 0.0 if last_pos == Vector3.INF else last_pos.distance_to(pos) / maxf(delta, 0.001)
		last_pos = pos
		var next_clip := "Idle"
		if dead_t >= 0.0:
			dead_t += delta
			next_clip = "Death"
		elif float(info.get("flash", 0)) > 0.2:
			next_clip = "Hurt"
		elif atk_t < 0.6:
			next_clip = "Breath" if clip_player.has_animation("Breath") else "Attack"
		elif str(info.get("flight", "")) != "":
			next_clip = info.flight
		elif movement > 0.2:
			next_clip = "Run" if movement > 2.5 else "Walk"
		if next_clip != clip_name:
			clip_player.play(next_clip, 0.09)
			clip_name = next_clip
		follow(pos, yaw, scale_k)
		return
	# сброс позы
	for k in bones:
		bones[k].basis = Basis.IDENTITY
		bones[k].position = rest[k]
	var stride := maxf(0.2, float(gait.get("stride", 1.2)) * scale_k)
	var moved := 0.0
	if last_pos != Vector3.INF:
		var d := pos - last_pos
		d.y = 0.0
		moved = d.length()
		if moved > 3.0:
			moved = 0.0   # телепорт или перенос через край мира
	last_pos = pos
	wheel_dist += moved
	var dyaw := wrapf(yaw - last_yaw, -PI, PI)
	last_yaw = yaw
	turn = lerpf(turn, dyaw / maxf(delta, 0.001), minf(1.0, delta * 6.0))
	var spd := moved / maxf(delta, 0.001)
	var nominal := maxf(0.5, float(info.get("speed", 4.0)))
	var want := clampf(spd / nominal, 0.0, 1.3)
	if dead_t < 0.0 and absf(turn) > 0.8 and want < 0.3:
		want = 0.35   # разворот на месте — переступает
	amp = move_toward(amp, want, delta * 4.0)
	# фаза шага привязана к пройденному пути — поэтому лапы не скользят по земле
	phase = fposmod(phase + moved / stride + absf(dyaw) * 0.12, 1.0)
	if dead_t >= 0.0:
		_pose_dead(delta)
	else:
		_pose_alive(delta, info)
	_pose_machine(delta)
	_sync_skin()
	global_position = pos
	basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_k)


## Кадр без пересчёта позы (дальний монстр): только место и поворот.
func follow(pos: Vector3, yaw: float, scale_k: float) -> void:
	global_position = pos
	basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_k)


func _pose_alive(_delta: float, info: Dictionary) -> void:
	var g := gait
	var duty := float(g.get("duty", 0.6))
	var swing := float(g.get("swing", 25.0))
	var lift := float(g.get("lift", 20.0))
	var knee := float(g.get("knee", 30.0))
	var a := amp
	# ноги
	for L in rig.get("legs", []):
		var lp := fposmod(phase + float(L.get("phase", 0.0)), 1.0)
		var ang := 0.0
		var up := 0.0
		if lp < duty:
			ang = lerpf(1.0, -1.0, lp / duty)                    # опора: лапа на земле, тело едет вперёд
		else:
			var s := (lp - duty) / (1.0 - duty)                  # перенос: лапа поднята и выносится вперёд
			ang = lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, s))
			up = sin(PI * s)
		var side := float(L.get("side", 1.0))
		if str(L.get("style", "z")) == "y":
			_rot(L.hip, Vector3.UP, ang * swing * a * side)
			_rot(L.hip, Vector3.RIGHT, -side * up * lift * a)
			_rot(L.knee, Vector3.RIGHT, side * up * knee * a)
		else:
			_rot(L.hip, Vector3.BACK, ang * swing * a)
			_rot(L.knee, Vector3.BACK, -(up * knee + 4.0) * a)
	# руки — навстречу ногам
	for A in rig.get("arms", []):
		var ap := fposmod(phase + float(A.get("phase", 0.0)), 1.0)
		_rot(A.bone, Vector3.BACK, sin(ap * TAU) * float(A.get("amp", 25.0)) * a)
		if A.has("fore"):
			_rot(A.fore, Vector3.BACK, (12.0 + 18.0 * a))
	# корпус: перенос веса, наклон на бегу и в повороте, дыхание
	var body := str(rig.get("body", root_bone))
	if bones.has(body):
		var b: Node3D = bones[body]
		var bob := float(g.get("bob", 0.05))
		var beats := 2.0
		b.position.y += -bob * a * (0.5 - 0.5 * cos(phase * TAU * beats)) + sin(t * 1.6 + seed_k) * 0.012 * (1.0 - a)
		var bank := float(g.get("bank", 6.0))
		_rot(body, Vector3.RIGHT, sin(phase * TAU) * float(g.get("roll", 4.0)) * a + clampf(-turn * bank, -bank * 2.3, bank * 2.3))
		_rot(body, Vector3.BACK, -float(g.get("lean", 6.0)) * a + sin(t * 1.6 + seed_k) * 1.2 * (1.0 - a))
		# замах и удар
		var w := float(info.get("windup", 0.0))
		var st := 0.0
		if atk_t < 0.45:
			st = atk_t / 0.08 if atk_t < 0.08 else maxf(0.0, 1.0 - (atk_t - 0.08) / 0.37)
		b.position.x += (-0.12 * w + 0.35 * st)
		_rot(body, Vector3.BACK, 9.0 * w - 14.0 * st)
		# вздрагивание от попадания
		var f := float(info.get("flash", 0.0))
		if f > 0.0:
			_rot(body, Vector3.RIGHT, hit_side * 14.0 * f)
			_rot(body, Vector3.BACK, 10.0 * f)
			b.position.x -= 0.12 * f
		else:
			hit_side = 1.0 if randf() < 0.5 else -1.0
	for k in rig.get("breath", []):
		if bones.has(k):
			var s := 1.0 + sin(t * 2.2 + seed_k) * 0.035 + float(info.get("windup", 0.0)) * 0.08
			bones[k].basis = bones[k].basis.scaled(Vector3(s, s, s))
	# голова: смотрит на цель, а без цели оглядывается
	var head := str(rig.get("head", ""))
	if bones.has(head):
		var want := 0.0
		var td: Vector3 = info.get("target_dir", Vector3.ZERO)
		if td != Vector3.ZERO:
			want = clampf(wrapf(atan2(-td.z, td.x) - last_yaw, -PI, PI), -0.7, 0.7)
		else:
			want = sin(t * 0.55 + seed_k) * 0.45 * (1.0 - a) + sin(t * 1.7 + seed_k) * 0.08
		look = lerpf(look, want, 0.12)
		_rot(head, Vector3.UP, rad_to_deg(look))
		var w2 := float(info.get("windup", 0.0))
		var st2 := 0.0
		if atk_t < 0.45:
			st2 = atk_t / 0.08 if atk_t < 0.08 else maxf(0.0, 1.0 - (atk_t - 0.08) / 0.37)
		_rot(head, Vector3.BACK, 16.0 * w2 - 22.0 * st2 + sin(phase * TAU * 2.0) * 3.0 * a)
	# челюсти: дышит пастью, на бегу приоткрыта, на замахе раскрыта
	var open := 0.15 + 0.15 * sin(t * 2.7 + seed_k) + 0.35 * amp + float(info.get("windup", 0.0))
	if atk_t < 0.3:
		open = maxf(open, 1.0 - atk_t / 0.3)
	for J in rig.get("jaws", []):
		var ax := Vector3.UP if str(J.get("axis", "z")) == "y" else Vector3.BACK
		_rot(J.bone, ax, float(J.get("open", 20.0)) * clampf(open, 0.0, 1.2))
	# хвосты, усики, щупальца — волна по цепочке, на повороте отстают
	for C in rig.get("chains", []):
		var axn := str(C.get("axis", "y"))
		var ax2 := Vector3.UP if axn == "y" else (Vector3.RIGHT if axn == "x" else Vector3.BACK)
		var i := 0
		for bn in C.get("bones", []):
			# крылья: ось x, у правого крыла знак −1 — машут вместе; lag — запаздывание звеньев
			var w := sin(t * float(C.get("speed", 3.0)) * (1.0 + amp) - i * float(C.get("lag", 0.8)) + (0.0 if C.get("sync", false) else seed_k)) * float(C.get("amp", 12.0)) * float(C.get("sign", 1.0))
			if C.get("follow", false):
				w += clampf(-turn * 10.0, -25.0, 25.0)
			_rot(bn, ax2, w)
			i += 1


## Механика: винты крутятся всегда (быстрее на ходу, после смерти останавливаются), колёса — по пройденному пути,
## летающий корпус парит вверх-вниз. Поля скелета «rotors», «wheels», «hover» (правятся в редакторе моделей).
func _pose_machine(delta: float) -> void:
	var alive := dead_t < 0.0
	var spin_k := (0.75 + 0.5 * amp) if alive else maxf(0.0, 1.0 - dead_t * 0.8)
	spin += delta * spin_k
	for R in rig.get("rotors", []):
		var ax := Vector3.UP if str(R.get("axis", "y")) == "y" else (Vector3.RIGHT if str(R.get("axis", "y")) == "x" else Vector3.BACK)
		_rot(str(R.get("bone", "")), ax, rad_to_deg(fmod(spin * float(R.get("speed", 20.0)), TAU)))
	for W in rig.get("wheels", []):
		var axw := Vector3.BACK if str(W.get("axis", "z")) == "z" else (Vector3.RIGHT if str(W.get("axis", "z")) == "x" else Vector3.UP)
		_rot(str(W.get("bone", "")), axw, -rad_to_deg(fmod(wheel_dist / maxf(0.05, float(W.get("radius", 0.4))), TAU)))
	var hv = rig.get("hover", {})
	if hv is Dictionary and not hv.is_empty() and alive:
		var body := str(rig.get("body", root_bone))
		if bones.has(body):
			bones[body].position.y += sin(t * float(hv.get("speed", 2.0)) + seed_k) * float(hv.get("amp", 0.1)) * (1.0 - 0.5 * amp)


func _pose_dead(delta: float) -> void:
	dead_t += delta
	var k := smoothstep(0.0, 0.7, dead_t)
	var body := str(rig.get("body", root_bone))
	if bones.has(body):
		var b: Node3D = bones[body]
		b.position.y -= rest[body].y * 0.72 * k
		_rot(body, Vector3.RIGHT, dead_side * 75.0 * k)
		_rot(body, Vector3.BACK, -8.0 * k)
	for L in rig.get("legs", []):
		var side := float(L.get("side", 1.0))
		# подёргивание лап сразу после смерти
		var tw := sin(dead_t * 22.0 + side) * 10.0 * maxf(0.0, 1.0 - dead_t / 1.2)
		if str(L.get("style", "z")) == "y":
			_rot(L.hip, Vector3.RIGHT, -side * 55.0 * k + tw)
			_rot(L.knee, Vector3.RIGHT, side * 70.0 * k)
		else:
			_rot(L.hip, Vector3.BACK, 25.0 * k + tw)
			_rot(L.knee, Vector3.BACK, -75.0 * k)
	var head := str(rig.get("head", ""))
	_rot(head, Vector3.BACK, -30.0 * k)
	for J in rig.get("jaws", []):
		var ax := Vector3.UP if str(J.get("axis", "z")) == "y" else Vector3.BACK
		_rot(J.bone, ax, float(J.get("open", 20.0)) * k)
	for C in rig.get("chains", []):
		var i := 0
		for bn in C.get("bones", []):
			_rot(bn, Vector3.BACK, -12.0 * k * (i + 1))
			i += 1
	# полежал — уходит в землю
	if dead_t > 2.5 and bones.has(body):
		bones[body].position.y -= (dead_t - 2.5) * 0.7
	set_flash(maxf(0.0, 1.0 - dead_t * 3.0))


func finished() -> bool:
	return dead_t > 4.2
