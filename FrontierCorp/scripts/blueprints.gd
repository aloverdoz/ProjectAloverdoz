extends RefCounted
## Чертежи: скопировать кусок базы и поставить копию в другом месте.
## Клавиша «Чертёж» (G): зажать ЛКМ и выделить область → чертёж в руке, R — повернуть, ЛКМ — поставить, ПКМ/Esc — отмена.
## Чертежи можно сохранить с именем (окно «Чертежи») — они лежат в папке сохранений игры, blueprints.json.

const C := World.C

var game
var mode := ""             # "" | "select" | "paste"
var start := Vector2i(-999, -999)
var cur := {}              # {name, items: [{t, x, z, d, r, it, cfg}], w, h}
var rot := 0
var ghosts: Array = []
var frame: MeshInstance3D
var saved := {}            # имя -> чертёж


func _init(g) -> void:
	game = g
	_load()


func path() -> String:
	return DB.saves_dir().path_join("blueprints.json")


func _load() -> void:
	var d = DB.read_file(path()) if FileAccess.file_exists(path()) else null
	saved = d if d is Dictionary else {}


func _save() -> void:
	DB.write_file(path(), saved)


func active() -> bool:
	return mode != ""


func begin_select() -> void:
	game.cancel_build()
	cancel()
	mode = "select"
	start = Vector2i(-999, -999)
	game.notify("Чертёж: зажмите ЛКМ и выделите здания. ПКМ — отмена", Color(0.6, 0.85, 1.0))


func cancel() -> void:
	mode = ""
	_clear_ghosts()
	if frame:
		frame.queue_free()
		frame = null


func _clear_ghosts() -> void:
	for g in ghosts:
		g.queue_free()
	ghosts.clear()


## Скопировать здания в прямоугольнике клеток a..b.
func copy_rect(a: Vector2i, b: Vector2i) -> Dictionary:
	var a_w := World.cell_to_world(a)
	var d := World.delta(a_w, World.cell_to_world(b)) / C
	var w := absi(roundi(d.x)) + 1
	var h := absi(roundi(d.z)) + 1
	var x0 := mini(0, roundi(d.x))
	var z0 := mini(0, roundi(d.z))
	var items := []
	var lost := 0
	for bl in game.factory.all:
		if bl == game.factory.hq or bl.dead or not bool(bl.p("buildable", true)) or bl.p("wild", false):
			continue
		var o := World.delta(a_w, World.cell_to_world(bl.cell)) / C
		var ox := roundi(o.x) - x0
		var oz := roundi(o.z) - z0
		if ox < 0 or oz < 0 or ox + bl.size - 1 >= w or oz + bl.size - 1 >= h:
			continue
		var e := {"t": bl.type, "x": ox, "z": oz, "d": bl.dir}
		if bl.recipe != "":
			e["r"] = bl.recipe
		if not bl.cfg.is_empty():
			e["cfg"] = bl.cfg.duplicate(true)
			e.cfg.erase("qpair")   # A-1 r3: номер квантовой пары — не копируем (иначе общий склад удваивался)
			if e.cfg.is_empty():
				e.erase("cfg")
		items.append(e)
		if bl.lvl > 1 or not bl.subs.is_empty():
			lost += 1
	if lost > 0 and game.has_method("notify"):
		# A-12 r4: объединения и встроенные здания чертёж не хранит — честно предупреждаем
		game.notify("Чертёж: %d зданий с объединением или встроенными скопированы как обычные" % lost, Color(1, 0.8, 0.4))
	return {"name": "", "items": items, "w": w, "h": h, "plain": lost}


## Клетки и направления зданий чертежа после поворота (поворот вокруг левого верхнего угла).
func layout(bp: Dictionary, r: int) -> Array:
	var out := []
	var w := int(bp.get("w", 1))
	var h := int(bp.get("h", 1))
	var m := max_size()
	if m > 0 and (w > m or h > m):
		return out   # A13-3: чертёж больше предела не ставится
	for e in bp.get("items", []):
		var s := int(DB.building(str(e.t)).get("size", 1))
		var x := int(e.x)
		var z := int(e.z)
		if x < 0 or z < 0 or x >= w or z >= h:
			continue   # A13-3: здание за пределами размера чертежа
		var cw := w
		var ch := h
		for i in posmod(r, 4):
			# (x, z) → (-z, x), со сдвигом, чтобы чертёж оставался в положительных клетках
			var nx := ch - (z + s)
			var nz := x
			x = nx
			z = nz
			var t := cw
			cw = ch
			ch = t
		out.append({"e": e, "x": x, "z": z, "d": posmod(int(e.get("d", 0)) + r, 4)})
	return out


func total_cost(bp: Dictionary) -> Dictionary:
	var c := {}
	for e in bp.get("items", []):
		var k: Dictionary = game._scaled_cost(str(e.t))
		for it in k:
			c[it] = int(c.get(it, 0)) + int(k[it])
	return c


func start_paste(bp: Dictionary) -> void:
	game.cancel_build()
	_clear_ghosts()
	cur = bp
	rot = 0
	mode = "paste"
	for e in bp.get("items", []):
		var g: Node3D = ModelLib.make_ghost(DB.building(str(e.t)).get("model", e.t))
		game.add_child(g)
		ghosts.append(g)
	var n: int = bp.get("items", []).size()
	game.notify("Чертёж: %d зданий. ЛКМ — поставить, R — повернуть, ПКМ — отмена" % n, Color(0.6, 0.85, 1.0))


## Поставить чертёж от клетки at. Возвращает, сколько зданий поставлено.
func paste(bp: Dictionary, at: Vector2i, r: int) -> int:
	var cost := total_cost(bp)
	if not game.flags.get("free_build", false):
		for k in cost:
			if game.factory.available(k) < cost[k]:
				game.notify("Чертежу не хватает: %s" % game.missing_text(cost, game.factory.available), Color(1, 0.6, 0.4))
				return 0
	var n := 0
	for L in layout(bp, r):
		var e: Dictionary = L.e
		if Tech.building_locked(str(e.t)) and not game.flags.get("free_build", false):
			continue
		var bd: Dictionary = DB.data.buildings.get(str(e.t), {})
		if bd.is_empty() or not bool(bd.get("params", {}).get("buildable", true)) or bool(bd.get("params", {}).get("wild", false)):
			continue
		var pa := {"type": str(e.t), "cell": World.wc(at + Vector2i(L.x, L.z)), "dir": L.d}
		# A-7 r7: рецепт и настройки едут в самой команде — у гостя её выполняет хозяин
		if e.has("r"):
			pa["bp_r"] = str(e.r)
		if e.has("cfg") and e.cfg is Dictionary:
			pa["bp_cfg"] = e.cfg
		var b = game.cmd("place", pa)
		if b == null:
			if Net.is_client():
				n += 1   # отправлено хозяину; поставит он
			continue
		n += 1
	return n


# ---------------------------------------------------------------- ввод (из main)

func click(cell: Vector2i) -> void:
	if mode == "select":
		start = cell
	elif mode == "paste":
		var n := paste(cur, cell, rot)
		if n > 0:
			game.notify("Поставлено по чертежу: %d" % n, Color(0.6, 1, 0.7))


## Предел размера чертежа в клетках (правило «Чертёж: наибольший размер»; 0 — без предела).
static func max_size() -> int:
	return int(DB.setting("blueprint_max", 16))


func too_big(a: Vector2i, b: Vector2i) -> bool:
	var m := max_size()
	if m <= 0:
		return false
	var d := World.delta(World.cell_to_world(a), World.cell_to_world(b)) / C
	return absi(roundi(d.x)) + 1 > m or absi(roundi(d.z)) + 1 > m


func release(cell: Vector2i) -> void:
	if mode != "select" or start.x == -999:
		return
	if too_big(start, cell):
		game.notify("Чертёж больше %d×%d клеток — выделите меньше" % [max_size(), max_size()], Color(1, 0.6, 0.4))
		start = Vector2i(-999, -999)
		return
	var bp := copy_rect(start, cell)
	start = Vector2i(-999, -999)
	if bp.items.is_empty():
		game.notify("В выделении нет зданий", Color(1, 0.8, 0.5))
		return
	start_paste(bp)


func rotate() -> void:
	rot = (rot + 1) % 4


func update(hover: Vector2i) -> void:
	if mode == "select" and start.x != -999:
		_draw_frame(start, hover)
	elif frame:
		frame.visible = false
	if mode != "paste":
		return
	var L := layout(cur, rot)
	for i in mini(L.size(), ghosts.size()):
		var e: Dictionary = L[i].e
		var t := str(e.t)
		var cell: Vector2i = World.wc(hover + Vector2i(L[i].x, L[i].z))
		var s := int(DB.building(t).get("size", 1))
		var o2 := (s - 1) * C * 0.5
		var gb: Array = game.factory.base_for(t, cell)
		var wp := World.cell_to_world(hover + Vector2i(L[i].x, L[i].z))
		var g: Node3D = ghosts[i]
		g.position = Vector3(wp.x + o2, float(gb[0]) + 0.02, wp.z + o2)
		g.rotation.y = -int(L[i].d) * PI * 0.5
		var ok: bool = game.factory.can_place(t, cell) == ""
		var gm: StandardMaterial3D = g.get_meta("mat")
		gm.albedo_color = Color(0.3, 0.8, 1.0, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.4)


func _draw_frame(a: Vector2i, b: Vector2i) -> void:
	if frame == null:
		frame = MeshInstance3D.new()
		var m := BoxMesh.new()
		frame.mesh = m
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.3, 0.75, 1.0, 0.22)
		frame.material_override = mat
		game.add_child(frame)
	frame.visible = true
	(frame.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.3, 0.2, 0.25) if too_big(a, b) else Color(0.3, 0.75, 1.0, 0.22)
	var aw := World.cell_to_world(a)
	var d := World.delta(aw, World.cell_to_world(b))
	var size := Vector3(absf(d.x) + C, 0.6, absf(d.z) + C)
	var y: float = game.world.height_at(aw + d * 0.5)
	frame.position = aw + d * 0.5 + Vector3(0, y + 0.3 - aw.y, 0)
	(frame.mesh as BoxMesh).size = size


# ---------------------------------------------------------------- сохранённые чертежи

func save_current(name: String) -> void:
	if cur.is_empty() or name.strip_edges() == "":
		return
	var bp := cur.duplicate(true)
	bp["name"] = name.strip_edges()
	saved[bp.name] = bp
	_save()
	game.notify("Чертёж «%s» сохранён" % bp.name, Color(0.6, 1, 0.7))


func remove(name: String) -> void:
	saved.erase(name)
	_save()


# ---------------------------------------------------------------- обмен одним файлом

## Папка для обмена: сюда игра кладёт выгруженные чертежи, отсюда же забирает чужие (файлы *.fcbp).
static func share_dir() -> String:
	var d := OS.get_user_data_dir().path_join("blueprints_share")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func export_file(name: String) -> String:
	if not saved.has(name):
		return ""
	var f := share_dir().path_join(name.validate_filename() + ".fcbp")
	DB.write_file(f, {"format": "frontier_blueprint", "version": 1, "blueprint": saved[name]})
	return f


## Забрать все чертежи из папки обмена. Слишком большие (больше предела) и с неизвестными зданиями пропускаются.
func import_all() -> Array:
	var got := []
	var dir := DirAccess.open(share_dir())
	if dir == null:
		return got
	for fn in dir.get_files():
		if not fn.ends_with(".fcbp"):
			continue
		var d = DB.read_file(share_dir().path_join(fn))
		if not d is Dictionary or not d.get("blueprint") is Dictionary:
			continue
		var bp: Dictionary = d.blueprint
		var m := max_size()
		if m > 0 and (int(bp.get("w", 0)) > m or int(bp.get("h", 0)) > m):
			continue
		var ok := true
		var bw := int(bp.get("w", 0))
		var bh := int(bp.get("h", 0))
		for e in bp.get("items", []):
			if not e is Dictionary or not DB.data.buildings.has(str(e.get("t", ""))):
				ok = false
				break
			# A13-3: здания — внутри заявленного размера (раньше «2×2» ставил здания на 161 клетку)
			if int(e.get("x", 0)) < 0 or int(e.get("z", 0)) < 0 or int(e.get("x", 0)) >= bw or int(e.get("z", 0)) >= bh:
				ok = false
				break
		if not ok:
			continue
		var nm := str(bp.get("name", fn.get_basename()))
		if nm == "":
			nm = fn.get_basename()
		bp["name"] = nm
		saved[nm] = bp
		got.append(nm)
	if not got.is_empty():
		_save()
	return got
