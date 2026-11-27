class_name Player
extends Node3D
## Герой: ходьба и бег с анимацией ног и рук, удары инструментом, стрельба, ремонт,
## инвентарь с быстрыми слотами. Модель собрана из деталей и анимируется кодом.

var game
var inv := Inventory.new(36)
var selected := 0
var hot_items := {}
var hot_builds := {}   # ячейка панели быстрого доступа → здание для быстрой стройки
var bag_level := 0     # 13.10: сколько раз расширяли рюкзак за ресурсы


## Настройки расширения рюкзака (Данные → Настройки → «Рюкзак»).
static func bag_cfg() -> Dictionary:
	var c = DB.setting("bag", {})
	return c if c is Dictionary else {}


## Ячеек в рюкзаке после level расширений.
static func bag_size(level: int) -> int:
	var c := bag_cfg()
	var n := int(c.get("start", 36))
	if not bool(c.get("enabled", true)):
		return maxi(n, 9)
	var steps: Array = c.get("steps", [])
	for i in mini(level, steps.size()):
		n += int(steps[i].get("add", 9)) if steps[i] is Dictionary else 9
	return clampi(n, 9, maxi(9, int(c.get("max", 999))))


## Следующий шаг расширения: {"add": N, "cost": {...}} или {} — расширять больше некуда.
static func bag_next(level: int) -> Dictionary:
	var c := bag_cfg()
	var steps: Array = c.get("steps", [])
	if not bool(c.get("enabled", true)) or level >= steps.size() or not steps[level] is Dictionary:
		return {}
	if bag_size(level + 1) <= bag_size(level):
		return {}
	return steps[level]


## Применить размер рюкзака для текущего уровня (лишние предметы при уменьшении не теряются — ячейки остаются).
func apply_bag() -> void:
	var n := bag_size(bag_level)
	if n > inv.size():
		inv.resize(n)
	elif n < inv.size():
		var last := n
		for i in inv.size():
			if inv.slots[i] != null:
				last = maxi(last, i + 1)
		inv.resize(last)
	inv.changed.emit()


## Сколько ячеек в панели быстрого доступа (первые ячейки инвентаря).
static func hot_n() -> int:
	return clampi(int(Prefs.get_value("hotbar_slots", 9)), 4, 12)
var hp := 200.0
var maxhp := 200.0
var alive := true
var respawn := 0.0
var fire_cd := 0.0
var hurt_cd := 0.0
var hurt_t := 0.0
var aim := Vector3.ZERO
var action_t := 0.0       # сколько ещё герой смотрит на цель после удара или выстрела
var melee_target = null   # монстр, по которому бьём (автоцель)
var act_pt := Vector3.INF # куда смотреть во время удара или выстрела
var move_dir := Vector3.ZERO
var phase := 0.0
var swing_t := -1.0
var swing_cell := Vector2i.ZERO
var swing_hit := false
var shoot_t := 0.0
var death_t := 0.0
var t := 0.0
var food := 100.0
var water := 100.0
var clothes := ""      # надетая одежда (climate.gd)
var melee := false
var god := false
var step_acc := 0.0
var jump_t := -1.0
var jump_y := 0.0

# кости
var hips: Node3D
var torso: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var hand_r: Node3D
# 1.1.10: полный скелет — грудь (скрутка делится между поясницей и грудью), стопы, левая кисть
var chest: Node3D
var foot_l: Node3D
var foot_r: Node3D
var hand_l: Node3D
var tool_node: Node3D
var tool_id := "-"
var gun: Node3D
var muzzle: Node3D
var muzzle_light: OmniLight3D
var flashlight: SpotLight3D
var mats: Array = []
var model_id := ""
var ctl = null    # 1.3: сплитскрин — геймпад второго игрока (pad.gd с seat = 1); null — клавиатура, мышь и первый геймпад
var p2 := false   # второй игрок сплитскрина
var look := ""     # 1.3: модель героя, выбранная игроком («Герой» в меню); "" — модель из настроек игры

const ARMOR := Color(0.92, 0.55, 0.12)
const DARK := Color(0.15, 0.16, 0.18)


const BONES_DEFAULT := {
	"hips": [0, 0.95, 0], "leg_l": [0, -0.05, 0.17], "leg_r": [0, -0.05, -0.17], "shin_l": [0, -0.47, 0], "shin_r": [0, -0.47, 0],
	"torso": [0, 0.1, 0], "head": [0.02, 0.72, 0], "arm_l": [0, 0.58, 0.45], "arm_r": [0, 0.58, -0.45],
	"fore_l": [0, -0.42, 0], "fore_r": [0, -0.42, 0], "hand_r": [0, -0.38, 0], "gun": [0, 0, 0], "muzzle": [0.56, 0.02, 0],
}
const BONE_PARENT := {"leg_l": "hips", "leg_r": "hips", "shin_l": "leg_l", "shin_r": "leg_r", "torso": "hips", "head": "chest",
	"arm_l": "chest", "arm_r": "chest", "fore_l": "arm_l", "fore_r": "arm_r", "hand_r": "fore_r", "gun": "hand_r", "muzzle": "gun",
	"chest": "torso", "foot_l": "shin_l", "foot_r": "shin_r", "hand_l": "fore_l"}
const BONE_ORDER := ["hips", "leg_l", "leg_r", "shin_l", "shin_r", "foot_l", "foot_r", "torso", "chest", "head", "arm_l", "arm_r",
	"fore_l", "fore_r", "hand_l", "hand_r", "gun", "muzzle"]
var body_parts: Array = []   # [MultiMesh, исходный цвет] — для вспышки при уроне
# своя модель героя из GLB со скелетом: анимации файла вместо собранной из деталей
var glb_node: Node3D
var glb_ap: AnimationPlayer
var glb_names := PackedStringArray()
var glb_md: Dictionary = {}
var glb_cur := ""
var glb_state := ""
var glb_hand: BoneAttachment3D
var _was_hurt := false


## Герой собирается из модели (Данные → Модели → «Герой»): каждая деталь привязана к части тела полем «Роль».
## Белые детали красятся в цвет профессии.
## 1.3: герои на выбор — модели категории «Герои» (люди из Blender) и роботы.
static func looks() -> Array:
	var out := []
	for id in DB.data.models:
		if str(DB.data.models[id].get("category", "")) == "Герои":
			out.append(id)
	out.sort_custom(func(a, b): return int(DB.data.models[a].get("look_order", 99)) < int(DB.data.models[b].get("look_order", 99)))
	for id in ["hero_robot", "hero"]:
		if DB.data.models.has(id) and not id in out:
			out.append(id)
	return out


static func my_look() -> String:
	return str(Prefs.get_value("hero_look", ""))


func build() -> void:
	inv.avoid = {}
	inv.no_fluids = true   # жидкость в рюкзак — только в канистрах
	apply_bag()
	maxhp = float(DB.setting("player_hp", 200))
	hp = maxhp
	var mid := str(DB.setting("hero_model", "hero"))
	if look != "" and DB.data.models.has(look):
		mid = look
	if not DB.data.models.has(mid):
		mid = "hero"
	model_id = mid
	var md: Dictionary = ModelLib.model(mid)
	var bones: Dictionary = BONES_DEFAULT.duplicate()
	bones.merge(md.get("bones", {}), true)
	scale = Vector3.ONE * float(md.get("scale", 1.25))
	if str(md.get("glb", "")) != "":
		# у готовой модели масштаб часто 0.01 (сантиметры) — сам герой (рука, инструмент, оружие) остаётся обычного размера
		scale = Vector3.ONE * float(DB.setting("hero_glb_scale", 1.25))
	_add_bones(bones)
	var piv := {}
	for bn in BONE_ORDER:
		var bp: Array = bones.get(bn, [0, 0, 0])
		var parent: Node3D = self if bn == "hips" else piv[BONE_PARENT[bn]]
		piv[bn] = _pivot(parent, Vector3(float(bp[0]), float(bp[1]), float(bp[2])))
	hips = piv.hips
	hips_y0 = hips.position.y
	leg_l = piv.leg_l
	leg_r = piv.leg_r
	shin_l = piv.shin_l
	shin_r = piv.shin_r
	torso = piv.torso
	head = piv.head
	arm_l = piv.arm_l
	arm_r = piv.arm_r
	fore_l = piv.fore_l
	fore_r = piv.fore_r
	hand_r = piv.hand_r
	chest = piv.chest
	foot_l = piv.foot_l
	foot_r = piv.foot_r
	hand_l = piv.hand_l
	gun = piv.gun
	muzzle = piv.muzzle
	# 1.3: оружие в модели смотрит вперёд при опущенной руке, а целится герой рукой вперёд —
	# поворачиваем его вдоль руки, чтобы в прицеле ствол смотрел на цель, а не в небо
	if str(md.get("glb", "")) == "":
		gun.rotation.z = deg_to_rad(float(md.get("gun_pitch", -90.0)))
	var prof_col := Color(0.92, 0.55, 0.12)
	var prof: String = str(game.profession) if game != null else ""
	if DB.data.get("professions", {}).has(prof):
		prof_col = DB.color(DB.data.professions[prof].get("color", "#ffa040"))
	# неподвижные детали одной кости и материала склеены в одну сетку: у героя 300+ деталей, а рисуется он быстро
	_build_glb(md)
	var skinned := _build_skin(md, piv)
	var node := ModelLib.make_node(mid, false, true)
	var pdata := ModelLib.merged_parts(mid, false, true)
	var ci := -1
	for c in node.get_children():
		ci += 1
		var role := str(c.get_meta("role", "hips"))
		if role == "glb" and glb_node != null:
			continue   # её рисует сам файл со скелетом
		if skinned and role != "gun":
			continue   # всё тело — одна гладкая сетка на костях (оружие в руке — отдельной деталью)
		if not piv.has(role):
			role = "hips"
		var xf: Transform3D = c.transform
		xf = Transform3D(xf.basis.scaled(Vector3.ONE / scale.x), xf.origin / scale.x)
		node.remove_child(c)
		c.transform = xf
		if role == "torso":
			# 1.1.10: корпус целиком едет с грудью (поясница — только точка скрутки); локальные координаты те же
			role = "chest"
			c.transform.origin -= chest.position
		piv[role].add_child(c)
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
			var col: Color = pdata[ci][3] if ci < pdata.size() else Color.WHITE
			var merged: bool = ci < pdata.size() and pdata[ci].size() > 6 and bool(pdata[ci][6])
			if col.is_equal_approx(Color.WHITE) and not merged:
				col = prof_col
				mm.set_instance_color(0, col)
			elif col.is_equal_approx(Color.WHITE) and merged:
				# готовая модель из Blender: цвет в текстуре, профессию показываем лёгким оттенком (у людей — нет)
				col = Color.WHITE.lerp(prof_col, float(md.get("prof_tint", DB.setting("hero_prof_tint", 0.35))))
				mm.set_instance_color(0, col)
			body_parts.append([mm, col])
			if role in ["shin_l", "shin_r", "fore_l", "fore_r"]:
				var sub := _split_part(c, piv[{"shin_l": "foot_l", "shin_r": "foot_r", "fore_l": "hand_l", "fore_r": "hand_r"}[role]])
				if sub != null:
					sub.multimesh.set_instance_color(0, col)
					body_parts.append([sub.multimesh, col])
	node.queue_free()
	_glb_hand_attach()
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.75, 0.3)
	muzzle_light.omni_range = 7.0
	muzzle_light.light_energy = 0.0
	muzzle.add_child(muzzle_light)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.2, 0.3, 0)
	flashlight.rotation = Vector3(0, -PI / 2, 0)
	flashlight.rotate_object_local(Vector3.RIGHT, -0.35)
	flashlight.spot_range = 32.0
	flashlight.spot_angle = 38.0
	flashlight.light_energy = 0.0
	flashlight.shadow_enabled = true
	head.add_child(flashlight)


## 1.1.10: недостающие кости (грудь, стопы, левая кисть) ставятся по пропорциям модели, если в модели их нет.
## Грудь — между поясницей и шеей; голова и плечи переезжают на неё (их мировое положение не меняется).
func _add_bones(bones: Dictionary) -> void:
	var hy := float(bones.hips[1])
	if not bones.has("chest"):
		var cy := float(bones.head[1]) * 0.42
		bones["chest"] = [0, cy, 0]
		for bn in ["head", "arm_l", "arm_r"]:
			var b: Array = bones[bn].duplicate()
			b[1] = float(b[1]) - cy
			bones[bn] = b
	var ankle := hy * float(DB.setting("hero_ankle_k", 0.085))
	for sd in ["l", "r"]:
		if not bones.has("foot_" + sd):
			var knee_y := hy + float(bones["leg_" + sd][1]) + float(bones["shin_" + sd][1])
			bones["foot_" + sd] = [0.0, -(knee_y - ankle), 0.0]
	if not bones.has("hand_l"):
		var hr: Array = bones.hand_r
		bones["hand_l"] = [float(hr[0]), float(hr[1]), -float(hr[2])]


## Деталь голени (предплечья) режется по суставу: треугольники ниже щиколотки (за запястьем) уходят на стопу (кисть).
## Сетки кешируются — режем один раз на модель.
static var _split_cache := {}

func _split_part(c: MultiMeshInstance3D, child: Node3D) -> MultiMeshInstance3D:
	var mm := c.multimesh
	if mm == null or mm.mesh == null or mm.instance_count != 1:
		return null
	var cut := child.position         # сустав в системе родительской кости
	var dirv := cut.normalized()      # кость идёт от своего начала к суставу
	var xf: Transform3D = c.transform * mm.get_instance_transform(0)
	var key := "%d|%s|%s" % [mm.mesh.get_instance_id(), cut, xf]
	var pair: Array
	if _split_cache.has(key):
		pair = _split_cache[key]
	else:
		var keep := ArrayMesh.new()
		var away := ArrayMesh.new()
		var src: Mesh = mm.mesh
		for si in src.get_surface_count():
			var arr := src.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ids = arr[Mesh.ARRAY_INDEX]
			if ids == null or (ids as PackedInt32Array).is_empty():
				ids = PackedInt32Array(range(vs.size()))
			var ia := PackedInt32Array()
			var ib := PackedInt32Array()
			for ti in range(0, ids.size(), 3):
				var ctr: Vector3 = (xf * vs[ids[ti]] + xf * vs[ids[ti + 1]] + xf * vs[ids[ti + 2]]) / 3.0
				var tgt := ib if (ctr - cut).dot(dirv) > 0.0 else ia
				tgt.append(ids[ti]); tgt.append(ids[ti + 1]); tgt.append(ids[ti + 2])
			for pr in [[keep, ia], [away, ib]]:
				if (pr[1] as PackedInt32Array).is_empty():
					continue
				var a2 := arr.duplicate()
				a2[Mesh.ARRAY_INDEX] = pr[1]
				(pr[0] as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
				(pr[0] as ArrayMesh).surface_set_material((pr[0] as ArrayMesh).get_surface_count() - 1, src.surface_get_material(si))
		pair = [keep, away]
		_split_cache[key] = pair
	if (pair[1] as ArrayMesh).get_surface_count() == 0 or (pair[0] as ArrayMesh).get_surface_count() == 0:
		return null
	mm.mesh = pair[0]
	var m2 := MultiMesh.new()
	m2.transform_format = MultiMesh.TRANSFORM_3D
	m2.use_colors = true
	m2.use_custom_data = true
	m2.mesh = pair[1]
	m2.instance_count = 1
	m2.set_instance_transform(0, mm.get_instance_transform(0))
	m2.set_instance_custom_data(0, mm.get_instance_custom_data(0))
	var n2 := MultiMeshInstance3D.new()
	n2.multimesh = m2
	n2.material_override = c.material_override
	n2.cast_shadow = c.cast_shadow
	n2.transform = Transform3D(c.transform.basis, c.transform.origin - cut)
	child.add_child(n2)
	return n2


## Модель героя с гладкой сеткой на костях (автоскелет, поле «skin»): одна сетка, суставы гнутся без щелей.
## Кости скелета каждый кадр повторяют узлы-кости героя (hips, ноги, руки...), которые двигает обычная анимация.
var skel: Skeleton3D = null
var skel_nodes: Array = []

func _build_skin(md: Dictionary, piv: Dictionary) -> bool:
	var sd = md.get("skin", {})
	if not (sd is Dictionary) or sd.is_empty():
		return false
	var mesh := ModelLib.part_mesh({"shape": "mesh", "mesh": str(sd.get("mesh", ""))})
	if mesh == null or mesh.get_surface_count() == 0 or (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES) == 0:
		return false
	var names0: Array = sd.get("bones", [])
	var names: Array = []
	for bn in BONE_ORDER:
		if bn in names0 or bn in ["chest", "foot_l", "foot_r", "hand_l"]:
			names.append(bn)
	for bn in names0:
		if not bn in names:
			names.append(bn)
	mesh = _reweight(mesh, names0, names, piv, str(sd.get("mesh", "")))
	skel = Skeleton3D.new()
	add_child(skel)
	var skin := Skin.new()
	var world := {}
	for bn in names:
		if not piv.has(bn):
			skel.queue_free()
			skel = null
			return false
		skel.add_bone(bn)
		skel_nodes.append(piv[bn])
	for i in names.size():
		var bn: String = names[i]
		var pn: String = BONE_PARENT.get(bn, "")
		skel.set_bone_parent(i, names.find(pn))
		var off: Vector3 = (piv[bn] as Node3D).position
		world[bn] = off + (world[pn] if world.has(pn) else Vector3.ZERO)
		skel.set_bone_rest(i, Transform3D(Basis(), off))
		skin.add_named_bind(bn, Transform3D(Basis(), -world[bn]))
	skel.reset_bone_poses()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.skin = skin
	var p0: Dictionary = md.get("parts", [{}])[0] if not md.get("parts", []).is_empty() else {}
	if sd.get("mat") is Dictionary:
		p0 = sd.mat     # 1.3: у сетки на костях свой материал (текстура персонажа), детали — только оружие
	mi.material_override = ModelLib.material(p0, false, false, false)
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	return true


## 1.1.10: веса сетки на костях дополняются новыми костями — грудь, стопы, левая кисть. Доля веса плавно
## переходит с голени на стопу ниже щиколотки, с предплечья на кисть за запястьем, с корпуса на грудь выше середины.
## Кешируется на модель.
static var _rw_cache := {}

func _reweight(mesh: Mesh, old_names: Array, names: Array, piv: Dictionary, key: String) -> Mesh:
	if _rw_cache.has(key):
		return _rw_cache[key]
	var world := {}
	for bn in names:
		var pn: String = BONE_PARENT.get(bn, "")
		world[bn] = (piv[bn] as Node3D).position + (world[pn] if world.has(pn) else Vector3.ZERO)
	var remap := PackedInt32Array()
	for bn in old_names:
		remap.append(names.find(bn))
	var i_torso: int = names.find("torso")
	var i_chest: int = names.find("chest")
	var moves := []   # [откуда, куда, начало сустава, направление, ширина перехода]
	var cy: Vector3 = world.chest
	moves.append([i_torso, i_chest, cy, Vector3.UP, 0.07])
	for sd in ["l", "r"]:
		moves.append([names.find("shin_" + sd), names.find("foot_" + sd), world["foot_" + sd], Vector3.DOWN, 0.025])
	var wl: Vector3 = world.hand_l
	moves.append([names.find("fore_l"), names.find("hand_l"), wl, (wl - (world.fore_l as Vector3)).normalized(), 0.015])
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wo: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per: int = bo.size() / maxi(1, vs.size())
		var nb := PackedInt32Array()
		var nw := PackedFloat32Array()
		nb.resize(vs.size() * 4)
		nw.resize(vs.size() * 4)
		var bi := PackedInt32Array()
		var bw := PackedFloat32Array()
		for vi in vs.size():
			bi.clear()
			bw.clear()
			for k in per:
				var w := wo[vi * per + k]
				if w <= 0.0:
					continue
				bi.append(remap[bo[vi * per + k]])
				bw.append(w)
			for mv in moves:
				var j: int = bi.find(mv[0])
				if j < 0:
					continue
				var d: float = (vs[vi] - (mv[2] as Vector3)).dot(mv[3])
				var f := smoothstep(-float(mv[4]), float(mv[4]), d)
				if f <= 0.0:
					continue
				var take := bw[j] * f
				bw[j] -= take
				var j2: int = bi.find(mv[1])
				if j2 < 0:
					bi.append(mv[1])
					bw.append(take)
				else:
					bw[j2] += take
			# четыре самых сильных влияния
			var sum := 0.0
			for k in 4:
				var best := -1
				for q in bw.size():
					if bw[q] > 0.0 and (best < 0 or bw[q] > bw[best]):
						best = q
				if best < 0:
					nb[vi * 4 + k] = 0
					nw[vi * 4 + k] = 0.0
					continue
				nb[vi * 4 + k] = bi[best]
				nw[vi * 4 + k] = bw[best]
				sum += bw[best]
				bw[best] = 0.0
			if sum > 0.0:
				for k in 4:
					nw[vi * 4 + k] /= sum
		arr[Mesh.ARRAY_BONES] = nb
		arr[Mesh.ARRAY_WEIGHTS] = nw
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, mesh.surface_get_material(si))
	_rw_cache[key] = out
	return out


func _sync_skin() -> void:
	if skel == null:
		return
	for i in skel_nodes.size():
		var n: Node3D = skel_nodes[i]
		skel.set_bone_pose_position(i, n.position)
		skel.set_bone_pose_rotation(i, n.basis.get_rotation_quaternion())


## Модель героя — готовый GLB с анимациями: ставим файл целиком, анимации подбираются по названиям
## (или из поля модели «Анимации GLB»). Без анимаций в файле — модель двигается деталями, как раньше.
func _build_glb(md: Dictionary) -> void:
	var path := str(md.get("glb", ""))
	if path == "" or not bool(md.get("glb_animate", true)):
		return
	glb_names = ModelLib.glb_anims(path)
	if glb_names.is_empty():
		return
	glb_node = ModelLib.glb_instance(path)
	if glb_node == null:
		return
	glb_ap = ModelLib.glb_player(glb_node)
	glb_md = md
	for st in ["idle", "walk", "run"]:
		var nm := ModelLib.glb_anim_for(md, st, glb_names)
		if nm != "" and glb_ap.has_animation(nm):
			glb_ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
	add_child(glb_node)
	_glb_update(0.0)


## Инструмент в руке — к кости кисти модели (если такая кость нашлась).
func _glb_hand_attach() -> void:
	if glb_node == null:
		return
	var sk := _find_skeleton(glb_node)
	if sk == null:
		return
	var want := str(glb_md.get("glb_hand_bone", ""))
	var bi := sk.find_bone(want) if want != "" else -1
	if bi < 0:
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i).to_lower().replace("_", "").replace(".", "").replace(" ", "")
			if bn.ends_with("righthand") or bn.ends_with("handr") or bn.ends_with("rhand") or bn.ends_with("handright"):
				bi = i
				break
	if bi < 0:
		return
	glb_hand = BoneAttachment3D.new()
	sk.add_child(glb_hand)
	glb_hand.bone_idx = bi
	hand_r.get_parent().remove_child(hand_r)
	glb_hand.add_child(hand_r)
	hand_r.transform = Transform3D.IDENTITY


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null


func _glb_update(delta: float) -> void:
	if glb_node == null:
		return
	var yaw := deg_to_rad(90.0 + float(glb_md.get("glb_yaw", 0.0)))
	var k := float(glb_md.get("scale", 1.0)) / maxf(0.0001, scale.x)
	glb_node.transform = Transform3D(Basis(Vector3.UP, hips.rotation.y - _pel + yaw).scaled(Vector3.ONE * k), Vector3.ZERO) * ModelLib.glb_offset(glb_md)
	if glb_hand and is_instance_valid(hand_r):
		# кость в файле может быть в сантиметрах — держим инструмент в размере героя
		var gs := glb_hand.global_transform.basis.get_scale().x
		if gs > 0.0001:
			hand_r.scale = Vector3.ONE * (scale.x / gs)
	if glb_ap == null:
		return
	var mv := Vector2(move_dir.x, move_dir.z).length()
	var st := "idle"
	if not alive:
		st = "die"
	elif swing_t >= 0.0:
		st = "attack"
	elif shoot_t > 0.0:
		st = "shoot"
	elif airborne:
		st = "jump"
	elif hurt_t > 0.15:
		st = "hurt"
	elif mv > 0.4:
		st = "run" if _run_k > 0.5 else "walk"
	glb_state = st
	var nm := ModelLib.glb_anim_for(glb_md, st, glb_names)
	var fb := {"shoot": "attack", "run": "walk", "hurt": "idle", "jump": "idle", "die": "idle"}
	while nm == "" and fb.has(st):
		st = fb[st]
		nm = ModelLib.glb_anim_for(glb_md, st, glb_names)
	if nm == "" and glb_state in ["walk", "run"]:
		nm = glb_names[0]   # одна безымянная анимация (как у Mixamo) — это ходьба
	if nm == "":
		if glb_cur != "":
			glb_ap.pause()
			glb_cur = ""
		return
	if nm != glb_cur:
		glb_ap.play(nm, 0.15)
		glb_cur = nm
	elif not glb_ap.is_playing() and glb_ap.get_animation(nm).loop_mode != Animation.LOOP_NONE:
		glb_ap.play(nm)
	if glb_state in ["walk", "run"]:
		var ref := float(glb_md.get("glb_run_speed" if glb_state == "run" else "glb_walk_speed", 5.0 if glb_state == "run" else 2.0))
		glb_ap.speed_scale = clampf(mv / maxf(0.1, ref), 0.5, 2.5)
	else:
		glb_ap.speed_scale = 1.0


func _mat(c: Color, metal: float, rough: float, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	m.emission_enabled = true
	m.emission = c if emit > 0.0 else Color(1, 0.1, 0.05)
	m.emission_energy_multiplier = emit
	mats.append([m, emit])
	return m


func _pivot(parent: Node3D, p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	parent.add_child(n)
	return n


func _box(parent: Node3D, size: Vector3, m: Material, p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ModelLib.unit_mesh("box")
	mi.scale = size
	mi.position = p
	mi.material_override = m
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- инвентарь

func hot_slot(index: int) -> int:
	var id := str(hot_items.get(index, ""))
	if id != "":
		for i in inv.size():
			if inv.slots[i] != null and inv.slots[i].id == id:
				return i
		hot_items.erase(index)
	return -1


func pin_item(index: int, id: String) -> void:
	hot_builds.erase(index)
	if id == "":
		hot_items.erase(index)
	else:
		hot_items[index] = id


func seed_hotbar() -> void:
	for i in mini(hot_n(), inv.size()):
		if inv.slots[i] != null and not hot_builds.has(i):
			pin_item(i, inv.slots[i].id)


func selected_item() -> String:
	return _slot_id(hot_slot(selected))


func tool_power(kind: String) -> float:
	var it := DB.item(selected_item())
	if it.get("tool", "") == kind:
		return float(it.get("power", 1.0))
	return 1.0


func _slot_id(i: int) -> String:
	if i < 0 or i >= inv.size() or inv.slots[i] == null:
		return ""
	return inv.slots[i].id


func _slot_power(i: int, kind: String) -> float:
	var it := DB.item(_slot_id(i))
	if kind != "" and it.get("tool", "") == kind:
		return float(it.get("power", 1.0))
	return 1.0


## 1.1.15: стратегия — лучший инструмент этого вида из рюкзака (−1 — нет, добыча руками).
func best_tool(kind: String) -> int:
	var best := -1
	var bp := 0.0
	if kind == "":
		return -1
	for i in inv.size():
		var it := DB.item(_slot_id(i))
		if it.get("tool", "") == kind and float(it.get("power", 1.0)) > bp:
			bp = float(it.get("power", 1.0))
			best = i
	return best


func _update_tool_visual() -> void:
	var id := selected_item()
	var it := DB.item(id)
	var show_tool: bool = id != "" and (it.has("tool") or it.get("weapon", "") == "melee")
	gun.visible = it.get("weapon", "") == "gun"
	if (id if show_tool else "") == tool_id:
		return
	tool_id = id if show_tool else ""
	if tool_node:
		tool_node.queue_free()
		tool_node = null
	if show_tool:
		# 1.3: инструмент в кулаке — рукоять проходит через ладонь, лезвие/боёк вперёд и вниз,
		# размер как у настоящего (топор ~0.85 м, нож ~0.38 м), а не парит рядом с рукой
		var mid := str(it.get("model", "drop_tool"))
		tool_node = ModelLib.make_node(mid)
		var g := grip_of(mid)
		var want := float(DB.setting("held_len_small", 0.38)) if it.get("weapon", "") == "melee" and float(g.len) < 0.75 else float(DB.setting("held_len", 0.85))
		var k := want / maxf(0.05, float(g.len) * scale.x)
		tool_node.rotation = Vector3(0, 0, -PI / 2 + deg_to_rad(float(DB.setting("held_tilt", 15.0))))
		tool_node.scale = Vector3.ONE * k
		var palm := Vector3(0.015, -0.06, 0)
		tool_node.position = palm - tool_node.basis * (g.point as Vector3)
		hand_r.add_child(tool_node)


static var _grips := {}


## Где держать предмет: точка хвата (низ рукояти, ~13% длины) и длина модели вдоль её оси Y.
## Модели предметов стоят рукоятью вниз. Поле модели «grip» [x, y, z] задаёт точку вручную.
static func grip_of(mid: String) -> Dictionary:
	if _grips.has(mid):
		return _grips[mid]
	var n := ModelLib.make_node(mid)
	var bb := AABB()
	var first := true
	for c in n.get_children():
		if c is MultiMeshInstance3D and c.multimesh and c.multimesh.mesh:
			for i in c.multimesh.instance_count:
				var b: AABB = (c.transform * c.multimesh.get_instance_transform(i)) * c.multimesh.mesh.get_aabb()
				bb = b if first else bb.merge(b)
				first = false
	n.free()
	var md: Dictionary = DB.data.models.get(mid, {})
	var pt := Vector3(0, bb.position.y + bb.size.y * 0.13, 0)
	if md.get("grip") is Array and md.grip.size() == 3:
		pt = Vector3(float(md.grip[0]), float(md.grip[1]), float(md.grip[2]))
	_grips[mid] = {"point": pt, "len": maxf(0.05, bb.size.y)}
	return _grips[mid]


# ---------------------------------------------------------------- урон

func damage(x: float) -> void:
	if not alive or god or game.strategy:   # 1.1.15: в стратегии героя нет — урона тоже
		return
	if game.defense:
		x = game.defense.absorb(position, x)   # под энергощитом урон принимает щит
		if x <= 0.0:
			return
	game.sfx.play("hurt", position)
	# броня (бустер «armor» от надетых вещей) снижает урон, но не больше чем на 80%
	hp -= x * (1.0 - clampf(game.bonus("armor"), 0.0, 0.8))
	hurt_cd = 4.0
	hurt_t = 0.25
	game.hud.hurt_flash()
	game.add_trauma(clampf(0.2 + x / 60.0, 0.2, 0.6))
	if hp <= 0.0:
		alive = false
		if game is Node and game.has_method("quip"):
			game.quip("death", true)
		death_t = 0.0
		respawn = float(DB.data.settings.get("death", {}).get("respawn_time", 6))
		jump_t = -1.0
		jump_y = 0.0
		airborne = false
		vel_y = 0.0
		position.y = support(position)
		if game.get("split") != null and game.split.running():
			game.split.with_seat(game.split.seat_of(self), game.on_player_died)   # A-10 r5: правило смерти — для погибшего героя
		else:
			game.on_player_died()
		game.fx.explosion(position + Vector3(0, 1, 0), 0.8, Color(1, 0.6, 0.2))
		game.notify("Герой выведен из строя! Восстановление в штабе...", Color(1, 0.4, 0.3))


# ---------------------------------------------------------------- кадр

func update(delta: float, aim_point: Vector3, cam_yaw: float) -> void:
	t += delta
	muzzle_light.light_energy = max(0.0, muzzle_light.light_energy - delta * 40.0)
	hurt_t = max(0.0, hurt_t - delta)
	if hurt_t > 0.0 or _was_hurt:
		_was_hurt = hurt_t > 0.0
		for bp in body_parts:
			(bp[0] as MultiMesh).set_instance_color(0, (bp[1] as Color).lerp(Color(1, 0.15, 0.1), clampf(hurt_t * 4.0, 0.0, 0.8)))
	maxhp = float(DB.setting("player_hp", 200)) + game.bonus("max_hp")
	if game.strategy:
		# 1.1.15: режим «Стратегия» — вместо героя невидимая точка обзора, камера летает над картой
		game.strat.move(self, delta, cam_yaw)
		aim = aim_point
		food = 100.0
		water = 100.0
		fire_cd -= delta
		action_t = max(0.0, action_t - delta)
		shoot_t = max(0.0, shoot_t - delta)
		_update_swing(delta)
		return
	if not alive:
		_glb_update(delta)
		death_t += delta
		# смерть: колени подламываются, потом герой заваливается вперёд, руки обмякают
		var buckle := clampf(death_t / 0.35, 0.0, 1.0)
		var fall := clampf((death_t - 0.25) / 0.5, 0.0, 1.0)
		fall = fall * fall
		shin_l.rotation.z = lerpf(shin_l.rotation.z, -1.5 * buckle, min(1.0, delta * 10.0))
		shin_r.rotation.z = lerpf(shin_r.rotation.z, -1.2 * buckle, min(1.0, delta * 10.0))
		leg_l.rotation.z = lerpf(leg_l.rotation.z, 0.9 * buckle, min(1.0, delta * 10.0))
		leg_r.rotation.z = lerpf(leg_r.rotation.z, 0.6 * buckle, min(1.0, delta * 10.0))
		torso.rotation.z = lerpf(torso.rotation.z, -1.4 * fall - 0.3 * buckle, min(1.0, delta * 8.0))
		hips.position.y = lerpf(hips.position.y, hips_y0 - 0.35 * buckle - 0.2 * fall, min(1.0, delta * 8.0))
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 1.2 * fall, min(1.0, delta * 6.0))
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 1.0 * fall, min(1.0, delta * 6.0))
		fore_l.rotation.z = lerpf(fore_l.rotation.z, 0.2, min(1.0, delta * 6.0))
		fore_r.rotation.z = lerpf(fore_r.rotation.z, 0.2, min(1.0, delta * 6.0))
		head.rotation.z = lerpf(head.rotation.z, 0.5 * fall, min(1.0, delta * 6.0))
		# 1.1.10: стопы вытягиваются, кисти обмякают
		foot_l.rotation.z = lerpf(foot_l.rotation.z, -0.6 * fall, min(1.0, delta * 6.0))
		foot_r.rotation.z = lerpf(foot_r.rotation.z, -0.5 * fall, min(1.0, delta * 6.0))
		hand_l.rotation.z = lerpf(hand_l.rotation.z, 0.5 * fall, min(1.0, delta * 6.0))
		hand_r.rotation.z = lerpf(hand_r.rotation.z, 0.4 * fall, min(1.0, delta * 6.0))
		respawn -= delta
		if respawn <= 0.0:
			alive = true
			hp = maxhp
			torso.rotation.z = 0
			hips.position.y = hips_y0
			for bn in [leg_l, leg_r, shin_l, shin_r, arm_l, arm_r, fore_l, fore_r, head, chest, foot_l, foot_r, hand_l, hand_r]:
				bn.rotation = Vector3.ZERO
			food = max(food, 60.0)
			water = max(water, 60.0)
			position = game.island.landing() if game.island != null else (game.factory.hq.center() + Vector3(5, 0, 5) if game.factory.hq else position)
			game.cam_focus = position
			game.notify("Герой восстановлен у штаба", Color(0.6, 1, 0.7))
		return
	hurt_cd -= delta
	var starving: bool = game.module("survival") and (food <= 0.0 or water <= 0.0)
	if hurt_cd <= 0.0 and hp < maxhp and not starving:
		hp = min(maxhp, hp + 10.0 * delta * (1.0 + game.bonus("regen")) * (0.3 if game.module("survival") and (food < 25.0 or water < 25.0) else 1.0))
	_update_tool_visual()
	# движение
	var input := Vector2.ZERO
	if ctl != null:
		input = ctl.move
	elif not game.typing() and not (game.photo_mode and game.photo.free_cam):
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running: bool = (ctl.sprint_on if ctl != null else Input.is_action_pressed("sprint")) and not game.typing()
	var speed: float = float(DB.setting("player_sprint" if running else "player_speed", 15.0 if running else 9.0)) * (1.0 + game.bonus("move")) * (game.climate.speed_k() if game.climate else 1.0)
	if in_water():
		speed *= float(DB.setting("wade_speed", 0.5))
	if game.vehicles:
		speed *= game.vehicles.speed_mult(self)
	var want := Vector3.ZERO
	if input != Vector2.ZERO:
		input = input.normalized()
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		want = (right * input.x - fwd * input.y) * speed
	move_dir = move_dir.lerp(want, min(1.0, delta * (3.5 if airborne else 12.0)))   # в воздухе — по инерции
	_unstuck()
	var np := position + Vector3(move_dir.x * delta, 0, 0)
	if not _blocked(np):
		position = np
	np = position + Vector3(0, 0, move_dir.z * delta)
	if not _blocked(np):
		position = np
	if game.world.wrap:
		position = World.wrap_pos(position)
	elif not game.world.ocean:
		var lim: float = game.world.W * World.C - 1.0
		position.x = clampf(position.x, 1.0, lim)
		position.z = clampf(position.z, 1.0, lim)
	# высота: земля, фундамент или крыша; прыжок и падение — с силой тяжести
	var sup: float = support(position) - (float(DB.setting("wade_depth", 0.85)) if in_water() else 0.0)
	if game.world.ocean and in_water():
		sup = game.world.ocean_surface(position,game.island.fishing.clock).x - .48
	_update_jump(delta, sup)
	aim = aim_point
	_animate(delta, running)
	_glb_update(delta)
	_sync_skin()
	fire_cd -= delta
	action_t = max(0.0, action_t - delta)
	shoot_t = max(0.0, shoot_t - delta)
	_update_swing(delta)


## Походка героя (1.3): как у человека. Темп и размах шагов считаются из скорости и длины ноги,
## поэтому ступня, стоящая на земле, не скользит. Таз ставится по опорной ноге (ступня всегда на земле):
## медленно — шаг с перекатом через опорную ногу, быстро — бег с фазой полёта, на спринте — высокий вынос
## бедра, пятка к ягодице, руки согнуты под прямым углом. Таз качается и поворачивается за шагающей ногой,
## плечи — навстречу, корпус наклоняется вперёд по скорости и при разгоне, назад при торможении, внутрь поворота.
## Стоя — дышит, переминается, оглядывается. Параметры — «Данные → Настройки → Походка героя».
var _gait_amp := 0.0
var _run_k := 0.0
var _turn := 0.0
var _last_yaw := 0.0
var _torso_yaw := 0.0
var _land_t := 9.0
var _land_k := 0.0
var _look_t := 0.0
var _look := 0.0
var _pel := 0.0        # поворот таза за шагающей ногой (добавлен к hips.rotation.y)
var _spd := 0.0        # сглаженная скорость
var _acc := 0.0        # разгон (+) или торможение (−)
var _air_k := 0.0      # 0 — на земле, 1 — в полёте
var _lead := 1.0       # какая нога впереди в прыжке (1 — левая, −1 — правая)
var hips_y0 := 0.95    # высота таза в позе покоя (у каждой модели своя)
var vel_y := 0.0       # вертикальная скорость: прыжок, падение
var airborne := false
var _pre_t := -1.0     # присед-толчок перед прыжком с места
var _air_base := 0.0   # с какой высоты прыгнул (камера держит этот уровень)
# 1.1.10: поворот на месте — ступни стоят, таз поворачивается, при большом угле герой переступает
var _fy_l := 0.0       # куда смотрит левая ступня (мировой угол)
var _fy_r := 0.0
var _fy_init := false
var _tstep := -1.0     # время шага на месте (−1 — не шагает)
var _ts_from := 0.0
var _ts_lead := 1.0    # 1 — первой шагает правая нога (поворот вправо), −1 — левая
var _settle_t := 0.0
var _hpitch := 0.0
var _turning := false
var _gun_k := 0.0


func _gait(key: String, def: float) -> float:
	var g = DB.setting("hero_gait", {})
	return float(g.get(key, def)) if g is Dictionary else def


## Высота таза над ступнёй, если бедро повёрнуто на th, а колено согнуто на k (в единицах модели).
func _leg_ext(th: float, k: float) -> float:
	var T := absf(shin_l.position.y)
	var S := maxf(0.1, hips_y0 + leg_l.position.y - T)
	return -leg_l.position.y + T * cos(th) + S * cos(th - k)


func _animate(delta: float, running: bool) -> void:
	var mv := Vector2(move_dir.x, move_dir.z).length()
	var L := maxf(0.5, hips_y0 * scale.x)        # длина ноги, м
	var prev_spd := _spd
	_spd = lerpf(_spd, mv, minf(1.0, delta * 8.0))
	_acc = lerpf(_acc, (_spd - prev_spd) / maxf(delta, 0.001), minf(1.0, delta * 6.0))
	var vn := _spd / L                            # длин ноги в секунду: человек переходит на бег около 2
	var rk := smoothstep(1.6, 3.0, vn)
	if running:
		rk = maxf(rk, smoothstep(0.5, 2.0, vn))
	_run_k = move_toward(_run_k, rk, delta * 3.0)
	var R := _run_k
	var sp := smoothstep(6.5, 11.5, vn) * R       # спринт
	_gait_amp = move_toward(_gait_amp, clampf(mv / 1.0, 0.0, 1.0), delta * 4.0)
	var walk := _gait_amp
	# доля опоры одной ноги: шаг — обе ноги на земле, бег — полёт, спринт — короткое касание
	var duty := lerpf(_gait("duty", 0.62), lerpf(_gait("run_duty", 0.36), _gait("sprint_duty", 0.25), sp), R)
	# частота шагов подбирается под желаемый размах бедра — тогда ступня на земле не едет
	var a_want := deg_to_rad(lerpf(_gait("swing", 24.0), _gait("run_swing", 40.0), R) + 6.0 * sp)
	var freq := _spd * duty / (2.0 * L * sin(a_want)) * _gait("stride", 1.0)
	freq = clampf(freq, 0.75, _gait("max_freq", 2.3))
	var A := maxf(deg_to_rad(6.0), asin(clampf(_spd * duty / (freq * 2.0 * L), 0.0, sin(deg_to_rad(55.0)))))
	var ph0 := phase
	if walk > 0.01:
		phase = fposmod(phase + freq * delta, 1.0)
	# шаги звучат, когда ступня встаёт на землю
	if walk > 0.5 and not airborne and not (game is Dictionary) and (phase < ph0 or (ph0 < 0.5 and phase >= 0.5)):
		game.sfx.play("step", position)
		if R > 0.6 and game.fx and not in_water():
			game.fx.puff(position + Vector3(0, 0.05, 0), "dust", 0.25 + 0.2 * sp)   # пыль из-под ног на бегу
	var la := _leg_pose(phase, duty, A, R, sp) * walk
	var ra := _leg_pose(fposmod(phase + 0.5, 1.0), duty, A, R, sp) * walk
	# куда смотрит герой (без покачивания таза)
	var face := hips.rotation.y - _pel
	if mv > 0.4:
		face = lerp_angle(face, atan2(-move_dir.z, move_dir.x), minf(1.0, delta * lerpf(11.0, 8.0, R)))
	var dyaw := wrapf(face - _last_yaw, -PI, PI)
	_last_yaw = face
	_turn = lerpf(_turn, dyaw / maxf(delta, 0.001), minf(1.0, delta * 6.0))
	# таз: по опорной ноге (ступня на земле). Обе ноги на земле — по нижней; в полёте — дуга
	var in_l := phase < duty
	var in_r := fposmod(phase + 0.5, 1.0) < duty
	var hy: float
	if in_l and in_r:
		hy = minf(_leg_ext(la.x, la.y), _leg_ext(ra.x, ra.y))
	elif in_l:
		hy = _leg_ext(la.x, la.y)
	elif in_r:
		hy = _leg_ext(ra.x, ra.y)
	else:
		# полёт: от толчка одной ноги до касания другой
		var pr := fposmod(phase + 0.5, 1.0)
		var off := phase if phase - duty < pr - duty else pr
		var u := clampf((off - duty) / maxf(0.01, 0.5 - duty), 0.0, 1.0)
		var tf := (0.5 - duty) / maxf(0.1, freq)
		var apex := 9.8 * tf * tf / 8.0 / scale.x
		var pre := _leg_pose(duty, duty, A, R, sp) * walk
		var fr := _leg_pose(0.0, duty, A, R, sp) * walk
		hy = lerpf(_leg_ext(pre.x, pre.y), _leg_ext(fr.x, fr.y), u) + 4.0 * apex * u * (1.0 - u) * walk
	var breathe := sin(t * 2.2) * 0.010 * (1.0 - walk)
	var shift := sin(t * 0.55) * (1.0 - walk)       # стоя — переминается с ноги на ногу
	var q := phase - duty * 0.5                     # 0 — середина опоры левой ноги
	# приземление и присед перед прыжком: колени и бёдра сгибаются, таз опускается по ногам
	_land_t += delta
	var ldur := 0.16 + 0.34 * _land_k
	var land := 0.0
	if _land_t < ldur:
		land = (_land_t / 0.05 if _land_t < 0.05 else 1.0 - smoothstep(0.05, ldur, _land_t)) * _land_k * lerpf(1.0, 0.55, R * walk)
	if _pre_t >= 0.0:
		land = maxf(land, 0.55 * clampf(_pre_t / 0.06, 0.0, 1.0))
	if land > 0.0:
		var c := Vector2(deg_to_rad(42.0), deg_to_rad(80.0)) * land
		la += c
		ra += c
		hy = minf(_leg_ext(la.x, la.y), _leg_ext(ra.x, ra.y))
	hips.position.y = hy + breathe - absf(shift) * 0.012
	hips.position.z = shift * 0.03 + cos(q * TAU) * lerpf(0.03, 0.012, R) * walk
	# таз поворачивается за шагающей ногой, плечи — навстречу
	_pel = deg_to_rad(lerpf(_gait("pelvis", 5.0), _gait("run_pelvis", 8.0), R)) * cos(phase * TAU) * walk
	hips.rotation.y = face + _pel
	var roll := -deg_to_rad(lerpf(_gait("roll", 4.0), 2.0, R)) * cos(q * TAU) * walk
	hips.rotation.x = roll + clampf(-_turn * deg_to_rad(_gait("turn_lean", 8.0)) * 0.5, -0.3, 0.3) * walk + shift * 0.04
	# корпус: к цели (прицел), скрутка навстречу тазу, наклон вперёд по скорости и разгону
	var to := World.delta(position, act_pt if action_t > 0.0 and act_pt != Vector3.INF else aim)
	to.y = 0
	var aim_yaw := atan2(-to.z, to.x) if to.length() > 0.3 else face
	# на бегу герой смотрит туда, куда бежит; к курсору поворачивается, только когда стоит,
	# бьёт или стреляет (настройка «Герой смотрит туда, куда бежит»)
	if mv > 0.4 and action_t <= 0.0 and bool(DB.setting("face_move", true)):
		aim_yaw = face
	var rel := wrapf(aim_yaw - face, -PI, PI)
	# 1.1.10: позвоночник крутится не больше ~50°: поясница 40 %, грудь 60 % — плечи не «ломаются» о таз
	var twl := deg_to_rad(_gait("twist_max", 50.0))
	_torso_yaw = lerp_angle(_torso_yaw, clampf(rel, -twl, twl), min(1.0, delta * 14.0))
	var tw := _torso_yaw - _pel * (1.0 + _gait("twist", 0.6))
	torso.rotation.y = tw * 0.4
	chest.rotation.y = tw * 0.6
	torso.rotation.x = -roll * 0.7
	var lean := deg_to_rad(_gait("lean", 3.0) + _gait("run_lean", 9.0) * R + 7.0 * sp) * walk
	lean += clampf(_acc * 0.012, -0.22, 0.25) + land * 0.35
	lean -= cos(q * TAU * 2.0) * 0.03 * R * walk      # на бегу корпус чуть кивает на каждом шаге
	var flinch := clampf(hurt_t / 0.25, 0.0, 1.0)
	torso.rotation.z = lerpf(torso.rotation.z, -lean + flinch * 0.3, min(1.0, delta * 12.0))
	# дыхание — грудью; на бегу дышит чаще и глубже
	var br_f := lerpf(2.2, 5.0, R * walk)
	chest.scale = Vector3(1.0, 1.0 + sin(t * br_f) * 0.012, 1.0 + sin(t * br_f) * (0.02 + 0.01 * R * walk))
	chest.rotation.z = -lean * 0.25 + sin(t * br_f) * 0.01
	# голова держит взгляд ровно: гасит наклон и скрутку корпуса; стоя — изредка оглядывается
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(2.0, 5.0)
		_look = randf_range(-0.45, 0.45) if randf() < 0.6 else 0.0
	var look := _look * (1.0 - walk) * (1.0 if action_t <= 0.0 else 0.0)
	# голова смотрит первой: в поворот — с опережением, к цели — наклоном вниз/вверх
	var ahead := clampf(_turn * 0.12, -0.45, 0.45) * (1.0 if action_t <= 0.0 else 0.3)
	var hyaw := clampf(rel - torso.rotation.y - chest.rotation.y + look + ahead, -1.1, 1.1)
	head.rotation.y = lerp_angle(head.rotation.y, hyaw, min(1.0, delta * (12.0 if look == 0.0 else 3.0)))
	var tgt := act_pt if action_t > 0.0 and act_pt != Vector3.INF else aim
	var hd := Vector2(to.x, to.z).length()
	var pitch := 0.0
	if hd > 0.5 and hd < 25.0 and (mv < 0.4 or action_t > 0.0):
		pitch = clampf(-atan2(position.y + 1.6 - tgt.y, hd) * 0.5, -0.38, 0.2)
	_hpitch = lerpf(_hpitch, pitch, minf(1.0, delta * 6.0))
	head.rotation.z = lean * 0.7 + chest.rotation.z * -1.0 - flinch * 0.25 + _hpitch
	head.rotation.x = -torso.rotation.x - roll * 0.5
	# стоя — корпус поворачивается к цели раньше (позвоночник не перекручивается), ступни догоняют шагом
	var turn_at := twl if mv > 0.4 else deg_to_rad(_gait("stand_turn", 35.0))
	# начал поворачиваться — доворачивается до цели целиком (как в шутерах: ноги догоняют корпус)
	if absf(rel) > turn_at:
		_turning = true
	elif absf(rel) < 0.08 or mv > 0.4:
		_turning = false
	if _turning or absf(rel) > turn_at:
		face = lerp_angle(face, aim_yaw, min(1.0, delta * 6.0 * clampf(absf(rel) * 3.0, 0.35, 1.0)))
		hips.rotation.y = face + _pel
	# руки: в противофазе ногам и чуть позже них; на бегу локти согнуты, вперёд рука сгибается сильнее
	var arm_a := deg_to_rad(lerpf(_gait("arms", 18.0), _gait("run_arms", 38.0), R) + 14.0 * sp) * walk
	var arm_f := deg_to_rad(lerpf(3.0, 10.0, R)) * walk
	var elbow := lerpf(0.15, deg_to_rad(lerpf(_gait("elbow", 14.0), _gait("run_elbow", 85.0), R)), walk)
	var ca := cos(phase * TAU - 0.35)
	var flex := deg_to_rad(10.0 + 12.0 * R) * walk
	# 1.1.10: рука отводится в сторону тем сильнее, чем дальше она от тела — кисть не проходит сквозь бедро и живот
	var al_z := arm_f - arm_a * ca + sin(t * 2.2) * 0.03 * (1.0 - walk) - land * 0.3
	var ar_z := arm_f + arm_a * ca + sin(t * 2.2 + 1.0) * 0.03 * (1.0 - walk) - land * 0.3
	var abd := _gait("arm_out", 0.07)
	# согнутое предплечье разворачивается наружу (плечо чуть поворачивается) — кисти не заходят за середину корпуса
	var out_y := (_gait("arm_yaw", 0.1) + _gait("run_arm_yaw", 0.32) * R) * walk
	var al := Vector3(-(abd + 0.04 * R + maxf(0.0, -al_z) * 0.15 + land * 0.15), -out_y, al_z)
	var fl := elbow + maxf(0.0, -ca) * flex + land * 0.4
	var ar := Vector3(abd + 0.04 * R + maxf(0.0, -ar_z) * 0.15 + land * 0.15, out_y, ar_z)
	var fr2 := elbow + maxf(0.0, ca) * flex + land * 0.4
	# прыжок и падение: взлёт — «ножницы» с разбега или группировка с места, вниз — ноги тянутся к земле, руки в стороны
	var air := airborne or jump_y > 0.3
	_air_k = move_toward(_air_k, 1.0 if air else 0.0, delta * (9.0 if air else 16.0))
	if _air_k > 0.0:
		var u := clampf(vel_y / 7.0, -1.0, 1.0)
		var w_up := maxf(0.0, u)
		var w_dn := maxf(0.0, -u)
		var w_top := 1.0 - w_up - w_dn
		var m := clampf(_spd / (2.5 * L), 0.0, 1.0)    # с разбега или с места
		var d := PackedFloat32Array()
		# [бедро ведущей, колено ведущей, бедро другой, колено другой, рука ведущей стороны, рука другой, локти]
		var up_run := [1.05, 1.6, -0.45, 0.9, -0.6, 0.9, 1.2]
		var up_std := [0.55, 1.0, 0.45, 0.9, 1.1, 1.1, 0.5]
		var top_run := [0.9, 1.5, 0.05, 1.3, -0.3, 0.6, 1.0]
		var top_std := [0.8, 1.6, 0.75, 1.55, 0.7, 0.7, 0.6]
		var dn := [0.35, 0.45, 0.15, 0.35, 0.35, 0.35, 0.45]
		for i in 7:
			var v_up := lerpf(up_std[i], up_run[i], m)
			var v_top := lerpf(top_std[i], top_run[i], m)
			d.append(v_up * w_up + v_top * w_top + float(dn[i]) * w_dn)
		var lead_l := _lead > 0.0
		var pl := Vector2(d[0], d[1]) if lead_l else Vector2(d[2], d[3])
		var pr := Vector2(d[2], d[3]) if lead_l else Vector2(d[0], d[1])
		la = la.lerp(pl, _air_k)
		ra = ra.lerp(pr, _air_k)
		# рука напротив ведущей ноги идёт вперёд
		var arm_lz := d[4] if lead_l else d[5]
		var arm_rz := d[5] if lead_l else d[4]
		al = al.lerp(Vector3(-0.15 - 0.6 * w_dn, 0, arm_lz), _air_k)
		ar = ar.lerp(Vector3(0.15 + 0.6 * w_dn, 0, arm_rz), _air_k)
		fl = lerpf(fl, d[6], _air_k)
		fr2 = lerpf(fr2, d[6], _air_k)
		hips.position.y = lerpf(hips.position.y, hips_y0 - 0.04, _air_k)
		torso.rotation.z = lerpf(torso.rotation.z, -0.15 * w_up * m - 0.1 * w_top, _air_k * minf(1.0, delta * 10.0))
	# 1.1.10: поворот на месте — ступни стоят на месте, бедро скручивается; больше угла — шаг
	var face_now := hips.rotation.y - _pel
	if not _fy_init:
		_fy_l = face_now
		_fy_r = face_now
		_fy_init = true
	var lift_l := 0.0
	var lift_r := 0.0
	if walk > 0.3 or air or not alive:
		_fy_l = face_now
		_fy_r = face_now
		_tstep = -1.0
	else:
		var dl := wrapf(face_now - _fy_l, -PI, PI)
		var dr := wrapf(face_now - _fy_r, -PI, PI)
		var big := maxf(absf(dl), absf(dr))
		if _tstep < 0.0:
			_settle_t = _settle_t + delta if absf(_turn) < 0.4 else 0.0
			if big > deg_to_rad(_gait("step_turn", 32.0)) or (big > 0.1 and _settle_t > 0.35):
				_tstep = 0.0
				_ts_lead = 1.0 if (dl + dr) > 0.0 else -1.0
		if _tstep >= 0.0:
			_tstep += delta
			var dur := _gait("step_time", 0.32)
			var u := _tstep / dur
			var u1 := clampf(u * 2.0, 0.0, 1.0)
			var u2 := clampf(u * 2.0 - 1.0, 0.0, 1.0)
			var e1 := minf(1.0, delta / maxf(0.01, dur * 0.5 * (1.0 - u1) + 0.001)) if u1 < 1.0 else 1.0
			var e2 := minf(1.0, delta / maxf(0.01, dur * 0.5 * (1.0 - u2) + 0.001)) if u2 < 1.0 else 1.0
			# ведущая нога — со стороны поворота (поворот вправо — правая)
			if _ts_lead > 0.0:
				_fy_r = lerp_angle(_fy_r, face_now, e1)
				lift_r = sin(PI * u1)
				if u >= 0.5:
					_fy_l = lerp_angle(_fy_l, face_now, e2)
					lift_l = sin(PI * u2)
			else:
				_fy_l = lerp_angle(_fy_l, face_now, e1)
				lift_l = sin(PI * u1)
				if u >= 0.5:
					_fy_r = lerp_angle(_fy_r, face_now, e2)
					lift_r = sin(PI * u2)
			if u >= 1.0:
				_fy_l = face_now
				_fy_r = face_now
				_tstep = -1.0
				_settle_t = 0.0
				if not (game is Dictionary) and game.sfx:
					game.sfx.play("step", position)
	var lift := Vector2(deg_to_rad(_gait("step_hip", 16.0)), deg_to_rad(_gait("step_knee", 34.0)))
	la += lift * lift_l
	ra += lift * lift_r
	var yl := clampf(wrapf(_fy_l - face_now, -PI, PI), -1.0, 1.0)
	var yr := clampf(wrapf(_fy_r - face_now, -PI, PI), -1.0, 1.0)
	# ноги чуть врозь — колени и стопы не задевают друг друга
	var spread := deg_to_rad(_gait("leg_out", 2.5))
	leg_l.rotation = Vector3(-spread, yl, la.x)
	leg_r.rotation = Vector3(spread, yr, ra.x)
	shin_l.rotation = Vector3(spread * 0.6, 0, -la.y)
	shin_r.rotation = Vector3(-spread * 0.6, 0, -ra.y)
	# стопы: пятка встаёт первой, стопа перекатывается, отталкивается носком; в переносе носок поднят над землёй
	var fpl := _foot_pitch(phase, duty, R) * walk
	var fpr := _foot_pitch(fposmod(phase + 0.5, 1.0), duty, R) * walk
	fpl = lerpf(fpl, -0.45, _air_k) - 0.25 * lift_l
	fpr = lerpf(fpr, -0.45, _air_k) - 0.25 * lift_r
	if alive:
		foot_l.rotation = Vector3(spread * 0.4, 0, fpl - (la.x - la.y) * (1.0 - _air_k * 0.6))
		foot_r.rotation = Vector3(-spread * 0.4, 0, fpr - (ra.x - ra.y) * (1.0 - _air_k * 0.6))
	arm_l.rotation = al
	fore_l.rotation.z = fl
	# кисти: расслаблены и чуть отстают от взмаха руки; на бегу сжаты и держатся ровнее
	hand_l.rotation = Vector3(0.12, 0, lerpf(-0.12, -0.3, R * walk) + al_z * -0.12 * walk)
	if swing_t >= 0.0 or game.flags.has("pose"):
		_swing_pose(swing_t / 0.42 if swing_t >= 0.0 else float(game.flags.pose))
	elif shoot_t > 0.0 or gun.visible:
		arm_r.rotation.x = 0.0
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 1.45 - shoot_t * 1.5, min(1.0, delta * 18.0))
		fore_r.rotation.z = lerpf(fore_r.rotation.z, 0.1, min(1.0, delta * 18.0))
		hand_r.rotation = hand_r.rotation.lerp(Vector3.ZERO, min(1.0, delta * 18.0))
		# 1.1.10: оружие держится двумя руками — левая поддерживает снизу, отдача качает обе
		_gun_k = move_toward(_gun_k, clampf(1.0 - _air_k, 0.0, 1.0), delta * 6.0)
		arm_l.rotation = arm_l.rotation.lerp(Vector3(_gait("gun_l_in", 0.55), 0.35, 1.2 - shoot_t * 1.2), _gun_k)
		fore_l.rotation.z = lerpf(fore_l.rotation.z, _gait("gun_l_elbow", 0.55), _gun_k)
		hand_l.rotation = hand_l.rotation.lerp(Vector3(0.3, 0, 0.1), _gun_k)
	else:
		_gun_k = 0.0
		arm_r.rotation = ar
		fore_r.rotation.z = fr2
		var holding: bool = tool_node != null and tool_node.visible
		hand_r.rotation = Vector3(-0.12, 0, (0.0 if holding else lerpf(-0.12, -0.3, R * walk) + ar_z * -0.12 * walk))


## Бедро (x) и сгиб колена (y) для фазы ноги p (0 — ступня встаёт на землю).
## Опора: нога ровно уходит назад, колено пружинит, принимая вес, и к отталкиванию уже сгибается.
## Перенос: колено сразу сильно сгибается (пятка вверх), бедро выносится вперёд (на бегу — выше),
## в конце нога выпрямляется и чуть «загребает» назад перед постановкой.
func _leg_pose(p: float, duty: float, A: float, R: float, sp: float) -> Vector2:
	var kst := deg_to_rad(lerpf(_gait("knee", 12.0), _gait("run_knee", 34.0), R))
	var ksw := deg_to_rad(lerpf(_gait("swing_knee", 60.0), _gait("run_swing_knee", 100.0), R) + 25.0 * sp)
	var front := A * (0.92 - 0.1 * R)
	var pre := deg_to_rad(lerpf(28.0, 18.0, R))
	if p < duty:
		var s := p / duty
		var k := kst * sin(PI * minf(1.0, s / 0.8)) * (1.0 - smoothstep(0.75, 1.0, s)) + pre * smoothstep(0.7, 1.0, s)
		return Vector2(lerpf(front, -A, s), k)
	var s2 := (p - duty) / (1.0 - duty)
	var drive := A * (1.0 + 0.35 * R + 0.35 * sp)
	var th: float
	if s2 < 0.8:
		var e := s2 / 0.8
		th = lerpf(-A, drive, e * e * (3.0 - 2.0 * e))
	else:
		var e2 := (s2 - 0.8) / 0.2
		th = lerpf(drive, front, e2 * e2 * (3.0 - 2.0 * e2))
	return Vector2(th, maxf(pre * (1.0 - s2), ksw * sin(PI * pow(s2, 0.7))))


## 1.1.10: наклон стопы к земле для фазы ноги p (0 — касание): плюс — носок вверх.
## Шаг: пятка → вся стопа → носок (пятка отрывается в конце опоры). Бег: ставится на переднюю часть стопы.
func _foot_pitch(p: float, duty: float, R: float) -> float:
	var heel := deg_to_rad(_gait("heel", 14.0)) * (1.0 - 0.8 * R)
	var toe := deg_to_rad(_gait("toe_off", 30.0) + 12.0 * R)
	var clear := deg_to_rad(_gait("toe_up", 10.0))
	if p < duty:
		var s := p / duty
		return heel * (1.0 - smoothstep(0.0, 0.2, s)) - toe * smoothstep(0.6, 1.0, s)
	var s2 := (p - duty) / (1.0 - duty)
	return lerpf(-toe, clear, smoothstep(0.0, 0.45, s2)) + (heel - clear) * smoothstep(0.75, 1.0, s2)


## Удар сверху вниз, как топором: замах вперёд-вверх над головой (локоть согнут, корпус чуть назад),
## быстрый удар вниз перед собой (рука выпрямляется, корпус наклоняется) и возврат.
func _swing_pose(p: float) -> void:
	var up := float(DB.setting("swing_raise", 2.7))      # насколько высоко замах (радианы от опущенной руки)
	var down := float(DB.setting("swing_hit", 0.8))      # где рука в момент удара
	var a: float
	var fa: float
	var lean: float
	if p < 0.45:
		var e := smoothstep(0.0, 1.0, p / 0.45)
		a = lerpf(0.25, up, e)
		fa = lerpf(0.3, 1.3, e)
		lean = 0.12 * e
	elif p < 0.62:
		var e := (p - 0.45) / 0.17
		e *= e
		a = lerpf(up, down, e)
		fa = lerpf(1.3, 0.12, e)
		lean = lerpf(0.12, -0.3, e)
	else:
		var e := smoothstep(0.0, 1.0, (p - 0.62) / 0.38)
		a = lerpf(down, 0.25, e)
		fa = lerpf(0.12, 0.3, e)
		lean = lerpf(-0.3, 0.0, e)
	arm_r.rotation.z = a
	arm_r.rotation.x = 0.0
	fore_r.rotation.z = fa
	# кисть: в замахе отведена назад, в ударе «доворачивает» инструмент вниз
	hand_r.rotation = Vector3(0, 0, lerpf(-0.35, 0.35, clampf((up - a) / maxf(0.1, up - down), 0.0, 1.0)) if p < 0.62 else lerpf(0.35, 0.0, smoothstep(0.62, 1.0, p)))
	# левая рука помогает: чуть поднимается в замахе
	arm_l.rotation.z += 0.6 * clampf(a / up, 0.0, 1.0)
	torso.rotation.z += lean


## Прыжок (1.3): обычный, с силой тяжести. Высота — «Высота прыжка», ловкость прыгает выше.
## Залезть на крышу можно, только если ступни поднялись почти до её края — получится или нет, зависит от игрока.
## С места — короткий присед-толчок, с разбега — сразу. Сорвался с края — падает. Приземление гасится коленями.
func jump() -> void:
	if airborne or _pre_t >= 0.0 or not alive:
		return
	if Vector2(move_dir.x, move_dir.z).length() < 1.5:
		_pre_t = 0.0
	else:
		_launch()


func _launch() -> void:
	_pre_t = -1.0
	var g := float(DB.setting("jump_gravity", 25.0))
	var h: float = float(DB.setting("jump_height", 1.5)) * (1.0 + game.bonus("jump"))
	vel_y = sqrt(2.0 * g * h)
	airborne = true
	_air_base = position.y
	jump_t = 0.0
	_lead = 1.0 if leg_l.rotation.z >= leg_r.rotation.z else -1.0
	game.sfx.play("jump", position)
	game.fx.puff(position + Vector3(0, 0.1, 0), "dust", 0.5)


func _land(sup: float) -> void:
	_land_k = clampf((-vel_y - 3.0) / 14.0, 0.15, 1.0)
	_land_t = 0.0
	airborne = false
	vel_y = 0.0
	jump_t = -1.0
	position.y = maxf(position.y, sup) if sup - position.y < 0.05 else position.y
	game.sfx.play("land", position, lerpf(1.15, 0.85, _land_k))
	game.fx.puff(position + Vector3(0, 0.1, 0), "dust", 0.4 + 0.8 * _land_k)
	if _land_k > 0.5:
		game.add_trauma(0.25 * _land_k)


func _update_jump(delta: float, sup: float) -> void:
	if ctl != null:
		if ctl.jump_just:
			ctl.jump_just = false
			jump()
	elif Input.is_action_just_pressed("jump") and not game.typing():
		jump()
	if _pre_t >= 0.0:
		_pre_t += delta
		if _pre_t >= float(DB.setting("jump_crouch", 0.08)):
			_launch()
	if airborne:
		jump_t += delta
		var g := float(DB.setting("jump_gravity", 25.0))
		if vel_y < 0.0:
			g *= float(DB.setting("fall_gravity_k", 1.5))
		position.y += vel_y * delta - 0.5 * g * delta * delta    # точно при любом FPS
		vel_y = maxf(vel_y - g * delta, -40.0)
		if vel_y <= 0.0 and position.y <= sup:
			_land(sup)
	else:
		if sup > position.y:
			# ступенька — подшагивает; большая разница (поставили фундамент под ноги) — быстро наверх
			position.y = move_toward(position.y, sup, delta * (9.0 if sup - position.y < 0.8 else 24.0))
		elif sup < position.y - 0.02:
			if position.y - sup > float(DB.setting("step_down", 0.75)):
				airborne = true      # сорвался с края — падает
				vel_y = 0.0
				jump_t = 0.0
				_air_base = position.y
			else:
				position.y = move_toward(position.y, sup, delta * (4.0 + (position.y - sup) * 10.0))
	jump_y = maxf(0.0, position.y - sup) if airborne else 0.0


## Высота, за которой следит камера: в прыжке держит уровень, с которого прыгнул (дуга видна, камера не дёргается).
func cam_y() -> float:
	if airborne:
		return minf(position.y, _air_base + maxf(0.0, position.y - _air_base - 2.0))
	return position.y


## Герой бредёт по воде (по пояс, медленнее).
func in_water() -> bool:
	var c := World.world_to_cell(position)
	return game.world.water_at(c) and game.factory.found_top(c) == null


func _blocked(p: Vector3) -> bool:
	# забраться можно на ступеньку не выше «Высоты шага» (в прыжке — выше)
	var climb := float(DB.setting("climb_height", 0.7))
	var ocean: bool = game.world.ocean
	var swimming := in_water()
	if ocean and not swimming and game.world.water_at(World.world_to_cell(p)):
		return true
	var base_y := position.y + (float(DB.setting("wade_depth",0.85)) if swimming and not ocean else 0.)

	for off in [Vector3.ZERO,Vector3.RIGHT*.28,Vector3.LEFT*.28,Vector3.BACK*.28,Vector3.FORWARD*.28]:
		var probe: Vector3 = p + off
		var c := World.world_to_cell(probe)
		if ocean and game.world.water_at(c) and game.factory.grid.get(c) == null:
			continue
		# 21: крыша невысокого здания — как ступенька; в прыжке герой подтягивается и залезает
		var rt: float = game.factory.roof_top(game.factory.body_at(probe))
		if rt >= 0.0:
			if rt - base_y <= climb:
				continue
			return true
		var ht := hop_top(c, probe)
		if ht >= 0.0 and ht - base_y > climb:
			return true      # невысокая преграда выше шага — перепрыгнуть
		if _cell_blocked(c, ht >= 0.0, probe):
			return true
		if game.world.dep_top(c) - base_y > climb:
			return true      # знак месторождения выше шага — только запрыгнуть
		if game.factory.support_at(p + off) - base_y > climb:
			return true
	return false


## Опора под героем: земля, фундамент или крыша здания, на котором он стоит.
func support(p: Vector3) -> float:
	var s: float = game.factory.support_at(p)
	var c := World.world_to_cell(p)
	var rt: float = game.factory.roof_top(game.factory.body_at(p))
	return maxf(maxf(maxf(s, rt), game.world.dep_top(c)), hop_top(c, p))   # 1.3: знак месторождения, камни, костёр — на них можно встать


## Стоит ли герой на крыше.
func on_roof() -> bool:
	var rt: float = game.factory.roof_top(game.factory.body_at(position))
	return rt >= 0.0 and position.y >= rt - 0.6


## 1.3: верх невысокой преграды на клетке (костёр, фонарь, турель, декор, камень, рудный камень) или −1.
## Через неё можно перешагнуть (если не выше шага) или перепрыгнуть, на неё можно встать.
## Высокие здания (стены, машины выше прыжка) и деревья — не перепрыгнуть.
func hop_top(c: Vector2i, point := Vector3.INF) -> float:
	var top := -1.0
	var b = game.factory.body_at(World.cell_to_world(c) if point == Vector3.INF else point)
	if b != null and not b.dead and not game.factory.walkable(b) and not b.p("gate", false) and game.factory.roof_top(b) < 0.0:
		top = game.factory.hop_top(b)
		if top < 0.0:
			return -1.0
	var w = game.world
	if w.blocks(c):
		var nt: float = w.node_top(World.wc(c))
		if nt < 0.0:
			return -1.0
		top = maxf(top, nt)
	return top


func _cell_blocked(c: Vector2i, hop := false, point := Vector3.INF) -> bool:
	var b = game.factory.body_at(World.cell_to_world(c) if point == Vector3.INF else point)
	if not hop and b != null and not game.factory.walkable(b) and not b.p("gate", false):
		# низкие преграды (забор) можно перепрыгнуть; через ворота герой проходит
		if not (jump_y > 0.5 and b.p("low", false)):
			return true
	var w = game.world
	if not w.in_bounds(c):
		return true
	if game.zone and not game.zone.inside_cell(c):
		return true   # за стеной бури не пройти: зону расширяют в штабе
	if not hop and w.blocks(c):
		# низкий ресурс (руда, кактус) перепрыгивается; если уже стоим на нём — можно сойти
		var low: bool = DB.data.resources.get(w.nodes[World.wc(c)].res, {}).get("low", false)
		if not (low and (jump_y > 0.35 or World.world_to_cell(position) == World.wc(c))):
			return true
	if w.water_at(c) and not w.ocean and not bool(DB.setting("wade", true)) and game.factory.found_top(c) == null:
		return true
	if game.world.nest_cells.has(c):
		var n = game.world.nests[game.world.nest_cells[c]]
		if n.alive and World.dist(World.cell_to_world(c), n.pos) < 4.5:
			return true
	return false


## Если герой оказался внутри здания или дерева — выталкиваем на ближайшую свободную клетку.
func _unstuck() -> void:
	var c := World.world_to_cell(position)
	var ht := hop_top(c, position)
	if not _cell_blocked(c, ht >= 0.0 and position.y >= ht - float(DB.setting("climb_height", 0.7)), position) or game.factory.roof_top(game.factory.body_at(position)) >= 0.0:
		return
	for r in range(1, 8):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var q := c + Vector2i(dx, dz)
				if not _cell_blocked(q):
					position = World.cell_to_world(q)
					return


func occupied_cells() -> Array:
	var out := []
	for off in [Vector3.ZERO, Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, -0.5)]:
		var c := World.world_to_cell(position + off)
		if not c in out:
			out.append(c)
	return out


# ---------------------------------------------------------------- действия

## Удар по ресурсу (дерево, камень, руда, куст).
func start_swing(cell: Vector2i) -> void:
	if swing_t >= 0.0 or not alive:
		return
	swing_t = 0.0
	swing_cell = cell
	swing_hit = false
	action_t = 0.6
	act_pt = World.cell_to_world(cell)
	var to := World.delta(position, World.cell_to_world(cell))
	hips.rotation.y = atan2(-to.z, to.x)
	torso.rotation.y = 0


func _update_swing(delta: float) -> void:
	if swing_t < 0.0:
		return
	swing_t += delta * (1.0 + game.bonus("gather") * 0.5)
	if not swing_hit and swing_t > 0.24 and melee:
		swing_hit = true
		_melee_hit()
	if not swing_hit and swing_t > 0.24:
		swing_hit = true
		var n = game.world.nodes.get(swing_cell)
		if n != null:
			var rd: Dictionary = DB.data.resources.get(n.res, {})
			var kind: String = rd.get("tool", "")
			var ts := best_tool(kind) if game.strategy else hot_slot(selected)
			var power: float = 10.0 * _slot_power(ts, kind) * (1.0 + game.bonus("gather"))
			var tool_kind: String = DB.item(_slot_id(ts)).get("tool", "")
			game.world.hit_node(swing_cell, power, tool_kind if tool_kind != "" else kind if kind == "" else "hand")
			Net._self().node_hit(swing_cell, power, tool_kind if tool_kind != "" else kind if kind == "" else "hand")
			game.sfx.play(rd.get("sounds", {}).get("hit", "chop" if kind == "axe" else "hit"), position)
			if tool_kind != "":
				game.wear(ts)
		elif game.world.can_mine(swing_cell):
			# руда прямо с месторождения: кирка — быстро, руками — медленно
			var ts2 := best_tool("pickaxe") if game.strategy else hot_slot(selected)
			var tool_kind2: String = DB.item(_slot_id(ts2)).get("tool", "")
			var power2: float = 10.0 * _slot_power(ts2, "pickaxe") * (1.0 + game.bonus("gather"))
			game.world.mine_deposit(swing_cell, power2, tool_kind2 if tool_kind2 != "" else "hand")
			game.sfx.play("hit", position)
			if tool_kind2 != "":
				game.wear(ts2)
	if swing_t >= 0.42:
		swing_t = -1.0
		melee = false


## Удар оружием ближнего боя (или кулаком) по направлению взгляда.
func start_attack(at := Vector3.INF, target = null) -> void:
	if swing_t >= 0.0 or not alive or fire_cd > 0.0:
		return
	melee_target = target
	action_t = 0.6
	act_pt = at
	var it := DB.item(selected_item())
	fire_cd = float(it.get("rate", 0.5)) if it.get("weapon", "") == "melee" else 0.5
	fire_cd /= max(0.2, 1.0 + game.bonus("attack_speed"))
	swing_t = 0.0
	swing_hit = false
	melee = true
	var to := World.delta(position, aim if at == Vector3.INF else at)
	hips.rotation.y = atan2(-to.z, to.x)
	torso.rotation.y = 0


func _melee_hit() -> void:
	var it := DB.item(selected_item())
	var is_weapon: bool = it.get("weapon", "") == "melee"
	var dmg: float = (float(it.get("damage", 5)) if is_weapon else 5.0) * (1.0 + game.bonus("damage"))
	var rng := float(it.get("range", 2.4)) if is_weapon else 2.0
	var fwd := Vector3(cos(hips.rotation.y), 0, -sin(hips.rotation.y))
	var hit := false
	var mt = melee_target
	melee_target = null
	for e in (game.enemies.list.duplicate() if game.module("melee") else []):   # A18-6: модуль «Ближний бой» выключен — рукой и ножом монстров не бить
		if not game.enemies.targetable(e):
			continue
		var rel: Vector3 = World.delta(position, e.pos)
		rel.y = 0
		var d := rel.length()
		# цель, выбранная автоприцелом, получает удар, даже если успела сместиться вбок
		var aimed: bool = e == mt and d < rng + e.radius + 0.8
		if aimed or (d < rng + e.radius and (d < 0.6 or rel.normalized().dot(fwd) > 0.35)):
			game.enemies.hit(e, dmg, true)
			game.fx.goo(e.pos + Vector3(0, 0.6, 0), 0.4)
			game.fx.spark(e.pos + Vector3(0, 0.8, 0))
			hit = true
	for n in game.world.nests:
		if n.alive and World.dist(position, n.pos) < rng + 3.5:
			game.damage_nest(n, dmg)
			hit = true
	game.sfx.play("hit" if hit else "whoosh", position, randf_range(0.9, 1.1))
	if hit:
		game.add_trauma(0.22)
		game.hitstop(0.045)
	if hit and is_weapon:
		game.wear(hot_slot(selected))


## Выстрел из бластера. Попадает в первого монстра или гнездо на линии огня.
func shoot(at := Vector3.INF) -> void:
	if not alive or fire_cd > 0.0 or swing_t >= 0.0:
		return
	if game.module("finite_ammo") and not game.flags.get("god", false):
		if inv.count("ammo") <= 0:
			game.notify_once("no_ammo", "Нет патронов! Сделайте их в мастерской — или бейте ножом.", Color(1, 0.8, 0.3))
			return
		inv.remove("ammo", 1)
	game.wear(hot_slot(selected))
	fire_cd = float(DB.item(selected_item()).get("rate", 0.12))
	fire_cd /= max(0.2, 1.0 + game.bonus("attack_speed"))
	shoot_t = 0.12
	action_t = 0.6
	act_pt = at
	var dir := World.delta(position, aim if at == Vector3.INF else at)
	dir.y = 0
	if dir.length() < 0.1:
		return
	dir = dir.normalized().rotated(Vector3.UP, randf_range(-0.03, 0.03))
	var from := muzzle.global_position
	var best_t := 38.0
	var best = null
	var best_nest = null
	for e in game.enemies.list:
		if not game.enemies.targetable(e):
			continue
		var rel: Vector3 = World.delta(position, e.pos)
		rel.y = 0
		var tt := rel.dot(dir)
		if tt < 0.0 or tt > best_t:
			continue
		if (rel - dir * tt).length() < e.radius:
			best_t = tt
			best = e
	for n in game.world.nests:
		if not n.alive:
			continue
		var rel: Vector3 = World.delta(position, n.pos)
		rel.y = 0
		var tt := rel.dot(dir)
		if tt < 0.0 or tt > best_t:
			continue
		if (rel - dir * tt).length() < 3.5:
			best_t = tt - 2.0
			best = null
			best_nest = n
	var hit_p := position + dir * best_t + Vector3(0, from.y, 0)
	game.fx.tracer(from, hit_p, Color(1.0, 0.85, 0.4), 0.05)
	muzzle_light.light_energy = 4.0
	game.sfx.play("shot", position)
	var dmg: float = float(DB.item(selected_item()).get("damage", 11)) * (1.0 + game.bonus("damage"))
	if best != null:
		game.enemies.hit(best, dmg, true)
	elif best_nest != null:
		game.damage_nest(best_nest, dmg)
		if randf() < 0.3:
			game.fx.goo(hit_p, 0.5)


## Съесть или использовать предмет (ягоды, аптечка).
func use_item(slot: int) -> bool:
	var s = inv.slots[slot]
	if s == null:
		return false
	var it := DB.item(s.id)
	# A17-3/4/5: у гостя вещи, меняющие мир (заплатка, граната, чертёж, баллон, саженец), применяет хозяин
	var world_fx: bool = float(it.get("repair_near", 0.0)) > 0.0 or float(it.get("decon", 0.0)) > 0.0 or str(it.get("plant", "")) != ""
	for ac in it.get("on_use", []):
		# A18-1/2: телепорт, разведчик, туман — у самого гостя; взрыв, чертёж, выдача вещей, стройка — у хозяина
		if ac is Dictionary and str(ac.get("do", "")) in ["explode", "unlock_rare", "give", "place", "drop", "spawn", "enemy", "event"]:
			world_fx = true
	var acting: bool = Net.active() and Net._self().applying   # хозяин выполняет за гостя: личное (сытость, лечение) не трогаем
	if world_fx and Net.is_client() and not acting:
		game.cmd("use_item", {"si": slot, "sid": str(s.id)})
		return true
	var used := false
	var msg := []
	var heal := 0.0 if acting else float(it.get("heal", 0))
	if heal > 0.0 and hp < maxhp:
		hp = min(maxhp, hp + heal)
		msg.append("+%d здоровья" % int(heal))
		used = true
	elif heal < 0.0:
		msg.append("%d здоровья" % int(heal))
		used = true
	if it.has("food") and (food < 99.0 or not used) and not acting:
		food = min(100.0, food + float(it.food))
		msg.append("сытость +%d" % int(it.food))
		used = true
	if it.has("water") and not acting:
		water = min(100.0, water + float(it.water))
		msg.append("вода +%d" % int(it.water))
		used = true
	if it.has("boost") and game.module("boosters") and not acting:
		var b: Dictionary = it.boost
		game.add_effect(b.get("stat", ""), float(b.get("value", 0)), float(b.get("time", 30)), it.get("name", s.id))
		msg.append(it.get("name", s.id))
		used = true
	if float(it.get("decon", 0.0)) > 0.0 and game.hazards:
		var took: float = game.hazards.decon_at(position, float(it.get("decon_radius", 8.0)), float(it.decon))
		game.fx.puff(position + Vector3(0, 0.8, 0), "steam", 3.0)
		msg.append("дезактивация: снято %d" % int(took) if took > 0.0 else "здесь чисто")
		used = true
	if str(it.get("clothes", "")) != "" and game.climate and not acting:
		game.climate.put_on(s.id)
		return true
	if float(it.get("rad_cure", 0.0)) > 0.0 and game.hazards and not acting:
		var was: float = game.hazards.dose
		game.hazards.dose = maxf(0.0, was * (1.0 - float(it.rad_cure) / 100.0))
		msg.append("доза облучения −%d%%" % int(it.rad_cure))
		used = true
	if float(it.get("repair_near", 0.0)) > 0.0:
		var nb = null
		var nd := 8.0
		for b in game.factory.all:
			if b.dead or b.hp >= b.maxhp:
				continue
			var dd := World.dist(b.center(), position)
			if dd < nd:
				nd = dd
				nb = b
		if nb == null:
			game.notify("Рядом нет повреждённых зданий", Color(1, 0.8, 0.4))
			return false
		nb.hp = minf(nb.maxhp, nb.hp + float(it.repair_near))
		msg.append("%s: +%d прочности" % [DB.t(DB.building(nb.type).get("name", nb.type)), int(it.repair_near)])
		used = true
	if str(it.get("prank", "")) != "" and game.coop:
		if game.coop.use_item(s.id, str(it.prank)):
			used = true
		else:
			return false
	if str(it.get("plant", "")) != "":
		# 1.4: саженец — в свободную клетку перед героем, дальше растёт сам
		var fa: float = hips.rotation.y if hips != null else 0.0
		var fwd := Vector3(cos(fa), 0, -sin(fa))
		var seedling := it
		if s.id == "tree_seed":
			seedling = DB.item(["sapling_oak","sapling_birch","sapling_pine","sapling_fir"].pick_random())
		var pc = game.world.plant_sapling(str(seedling.get("plant_young","")),str(seedling.plant),position+fwd*1.6)
		if pc == null:
			game.notify("Здесь негде посадить — нужна свободная земля", Color(1, 0.8, 0.4))
			return false
		msg.append("посажено: вырастет через %d мин" % int(ceil(float(DB.setting("sapling_grow", 300.0)) / 60.0)))
		used = true
	if not it.get("on_use", []).is_empty():
		var c := World.world_to_cell(position)
		game.console.run_actions(it.on_use, {"x": c.x, "z": c.y})
		used = true
	if str(it.get("script", "")) != "":
		var sc = Blocks.script_for(str(it.script))
		if sc != null and sc.has_method("on_use"):
			if sc.on_use(game, s.id) != false:
				used = true
	if not used:
		if it.has("tool") or it.has("weapon"):
			pin_item(selected, str(s.id))
		return false
	if not it.get("keep_on_use", false):
		# A17-6: убывает из той ячейки, по которой щёлкнули (не из последней такой же)
		s.n = int(s.n) - 1
		if int(s.n) <= 0:
			inv.slots[slot] = null
		inv.changed.emit()
	game.sfx.play(str(it.get("use_sound", "eat")), position)
	if not msg.is_empty():
		game.notify(", ".join(msg), Color(0.5, 1, 0.5))
	if heal < 0.0:
		damage(-heal)
	return true


## A-3 r8: что записать в сохранение — погибший герой пишется уже восстановленным у штаба.
func saved_state() -> Dictionary:
	if alive:
		return {"pos": position, "hp": hp, "food": food, "water": water}
	var at: Vector3 = game.island.landing() if game.island != null else (game.factory.hq.center() + Vector3(5, 0, 5) if game.factory.hq else position)
	return {"pos": at, "hp": maxhp, "food": maxf(food, 60.0), "water": maxf(water, 60.0)}
