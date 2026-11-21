extends Node
## Иконки предметов и зданий (автозагрузка «Icons»).
## Рисуются из 3D-моделей в маленьком отдельном мире, по одной за кадр, и запоминаются.
## Поэтому новая модель из редактора сразу получает свою иконку.

signal baked(key: String)

const SIZE := 96

var cache := {}
var queue: Array = []
var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var busy := ""
var wait := 0
var rev := -1
var enabled := true


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	sun.light_energy = 1.0
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)


## key: "item:<id>" или "building:<id>" или "model:<id>"
func get_icon(key: String) -> Texture2D:
	if not enabled:
		return null
	if rev != DB.revision:
		rev = DB.revision
		_recheck()
	if cache.has(key):
		return cache[key]
	# пустая картинка сразу, а нарисованная иконка подменит её содержимое
	var tex := ImageTexture.create_from_image(Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8))
	cache[key] = tex
	sig[key] = _sig(key)
	queue.append(key)
	return tex


var sig := {}

## Отпечаток того, из чего рисуется иконка: если он не изменился, перерисовывать не нужно.
func _sig(key: String) -> int:
	var mid := _model_of(key)
	var h := hash(JSON.stringify(DB.model_def(mid)))
	if key.begins_with("item:"):
		h = hash([h, DB.item(key.substr(5)).get("color", ""), DB.item(key.substr(5)).get("model", "")])
	elif key.begins_with("cat:"):
		h = hash([h, _cat_obj(key).get("color", "")])
	return h


## Данные поменялись: перерисовать только те иконки, чья модель изменилась. Картинки обновляются на месте.
func _recheck() -> void:
	for k in cache.keys():
		var s := _sig(k)
		if s != sig.get(k, 0):
			sig[k] = s
			if not k in queue and k != busy:
				queue.append(k)


func _model_of(key: String) -> String:
	var p := key.split(":", true, 1)
	match p[0]:
		"item":
			return DB.item(p[1]).get("model", "drop_box")
		"building":
			return DB.building(p[1]).get("model", p[1])
		"cat":
			return str(_cat_obj(key).get("model", ""))
	return p[1]


## Объект каталога по ключу "cat:<тип>:<id>".
func _cat_obj(key: String) -> Dictionary:
	var p := key.split(":", true, 2)
	if p.size() < 3:
		return {}
	return DB.catalog_data().get(p[1], {}).get(p[2], {})


func _process(_d: float) -> void:
	if not enabled:
		return
	if busy != "":
		wait -= 1
		if wait > 0:
			return
		var img := vp.get_texture().get_image()
		if img and cache.has(busy):
			img.convert(Image.FORMAT_RGBA8)
			(cache[busy] as ImageTexture).update(img)
			baked.emit(busy)
		busy = ""
		UI.clear(holder)
	if queue.is_empty():
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	busy = queue.pop_front()
	var node := ModelLib.make_node(_model_of(busy))
	holder.add_child(node)
	# предметы — белые детали красим в цвет предмета
	if busy.begins_with("item:") or busy.begins_with("cat:items:"):
		var cit := _cat_obj(busy) if busy.begins_with("cat:") else DB.item(busy.substr(5))
		var col := DB.color(cit.get("color", "#ffffff"))
		var own_model := not str(cit.get("model", "drop_box")).begins_with("drop_")
		var first := true
		for c in node.get_children():
			if c is MultiMeshInstance3D:
				var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
				# у стандартных моделей предметов главная деталь красится в цвет предмета
				if mm.get_instance_color(0) == Color.WHITE or (first and not own_model):
					mm.set_instance_color(0, col)
				first = false
	# металл отражает пустой фон и на иконке выходит чёрным — делаем его матовее
	for c in node.get_children():
		if c is GeometryInstance3D and (c as GeometryInstance3D).material_override is ShaderMaterial:
			var m: ShaderMaterial = (c as GeometryInstance3D).material_override.duplicate()
			var mt = m.get_shader_parameter("metallic")
			if mt != null and float(mt) > 0.3:
				m.set_shader_parameter("metallic", 0.3)
			(c as GeometryInstance3D).material_override = m
	var box := _aabb(node)
	var center := box.get_center()
	var r: float = max(0.3, box.size.length() * 0.5)
	cam.size = r * 2.05
	var dir := Vector3(1.0, 0.85, 1.25).normalized()
	cam.position = center + dir * (r * 4.0)
	cam.look_at(center, Vector3.UP)
	cam.near = 0.05
	cam.far = r * 10.0
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	wait = 3


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.get_children():
		if c is GeometryInstance3D:
			var b: AABB = (c as Node3D).transform * (c as GeometryInstance3D).get_aabb()
			if c is MultiMeshInstance3D:
				var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
				b = (c as Node3D).transform * mm.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box
