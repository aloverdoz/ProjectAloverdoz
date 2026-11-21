extends Node
## 21: квантовое измерение — поздняя игра после атома. Квантовый портал (нужна энергия) открывает:
##  • квантовые жилы: пока на жилу никто не смотрит, она в суперпозиции и не добывается. Подойдите и
##    посмотрите — жила «схлопнется» в одно из редких сырьё. Не понравилось — в окне портала можно вернуть
##    свободные жилы в суперпозицию за квантовый осколок и посмотреть снова;
##  • запутанные пары: два запутанных ящика делят одно содержимое, где бы ни стояли; две запутанные станции
##    энергии — одна сеть через всю карту;
##  • квантовых теней: двигаются, только пока на них не смотрят. Посмотрели — замирают и не бьют.
## Числа — «Данные → Настройки → Квантовое измерение».

var game
var veins := {}          # номер -> {cells: [[x, z]...], item: ""}
var next_vein := 1
var next_pair := 1
var pairs := {}          # qpair -> [здания]
var stats := {"collapsed": 0, "reset": 0, "shades": 0, "linked": 0}
var _t := 0.0
var _spawn_t := 20.0


func _init(g) -> void:
	game = g


static func cfg() -> Dictionary:
	var c = DB.setting("quantum", {})
	return c if c is Dictionary else {}


static func num(key: String, def: float) -> float:
	return float(cfg().get(key, def))


func portal():
	for b in game.factory.having("quantum_portal"):
		if not b.dead:
			return b
	return null


## Портал работает: построен и получает энергию.
func is_open() -> bool:
	var p = portal()
	return p != null and (not game.factory.is_electric(p) or game.factory.sat_c(p) > 0.3)


func vein_idx() -> int:
	var w = game.world
	for i in w.deposits.size():
		if str(w.deposits[i].get("item", "")) == "q_superposition":
			return i
	return -1


func update(delta: float) -> void:
	_freeze()
	_t += delta
	if _t < 0.25:
		return
	var dt := _t
	_t = 0.0
	if Net.is_client():
		return
	if is_open():
		if veins.is_empty():
			spawn_veins(portal())
		_spawn_shades(dt)
	_observe()


# ---------------------------------------------------------------- квантовые жилы

func spawn_veins(p) -> int:
	var idx := vein_idx()
	if idx < 0 or p == null:
		return 0
	var w = game.world
	var f = game.factory
	var want := int(num("veins", 6))
	var r0 := int(num("vein_min", 14))
	var r1 := int(num("vein_max", 60))
	var made := 0
	for tries in 400:
		if made >= want:
			break
		var a := randf() * TAU
		var r := randf_range(r0, r1)
		var c: Vector2i = World.wc(p.cell + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r)))
		var cells := [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]
		var ok := true
		for q in cells:
			q = World.wc(q)
			if not w.in_bounds(q) or w.water_at(q) or f.grid.has(q) or w.deposit.has(q) or w.nest_cells.has(q):
				ok = false
				break
			if game.zone and not game.zone.inside_cell(q):
				ok = false
				break
		if not ok:
			continue
		var cl := []
		for q in cells:
			q = World.wc(q)
			w.remove_node(q)
			w.set_deposit(q, idx, DB.color(str(cfg().get("vein_color", "#b98cff"))))
			cl.append([q.x, q.y])
		veins[next_vein] = {"cells": cl, "item": ""}
		next_vein += 1
		made += 1
	if made > 0:
		_net_push()   # B-5 r5: гостям — тоже
		game.notify("Портал открыт: вокруг появились квантовые жилы (%d). Посмотрите на жилу вблизи — она выберет, чем стать." % made, Color(0.75, 0.6, 1.0))
	return made


func vein_at(c: Vector2i) -> int:
	c = World.wc(c)
	for vid in veins:
		for q in veins[vid].cells:
			if q[0] == c.x and q[1] == c.y:
				return vid
	return 0


func _vein_center(v: Dictionary) -> Vector3:
	var q = v.cells[0]
	return World.cell_to_world(Vector2i(q[0], q[1])) + Vector3(World.C * 0.5, 0.5, World.C * 0.5)


## Наблюдение: герой рядом и жила в кадре — жила выбирает, чем быть.
func _observe() -> void:
	var cam: Camera3D = game.get_viewport().get_camera_3d()
	var dmax := num("observe_dist", 16.0) * World.C * 0.5
	for vid in veins.keys():
		var v: Dictionary = veins[vid]
		if str(v.item) != "":
			continue
		var at := _vein_center(v)
		# B-5 r5: смотрит любой герой; свой — ещё и в кадре, гость/второй игрок — достаточно подойти
		for pl in game.hit_targets():
			if pl == null or not is_instance_valid(pl) or World.dist(pl.position, at) > dmax:
				continue
			if pl == game.player and cam != null and not cam.is_position_in_frustum(pl.position + World.delta(pl.position, at)):
				continue
			collapse(vid)
			break


func _pick_outcome() -> String:
	var outs: Array = cfg().get("outcomes", [])
	var total := 0.0
	for o in outs:
		total += maxf(0.0, float(o.get("w", 1.0)))
	var h := randf() * total
	for o in outs:
		h -= maxf(0.0, float(o.get("w", 1.0)))
		if h <= 0.0 and DB.data.items.has(str(o.get("item", ""))):
			return str(o.get("item", ""))
	return "void_crystal"


func collapse(vid: int, item := "") -> void:
	var v: Dictionary = veins.get(vid, {})
	if v.is_empty():
		return
	if item == "":
		item = _pick_outcome()
	v.item = item
	var w = game.world
	var idx := vein_idx()
	for q in v.cells:
		var c := Vector2i(q[0], q[1])
		w.dep_override[c] = item
		w.set_deposit(c, idx, DB.item_color(item))
		var b = game.factory.grid.get(c)
		if b != null and b.beh == "miner":
			b.recipe = game.factory.miner_item(b.type, b.cell)
	stats.collapsed += 1
	_net_push()
	game.fx.magic(_vein_center(v), DB.item_color(item), 1.6)
	game.sfx.play("click", _vein_center(v))
	game.notify("Квантовая жила схлопнулась: %s" % DB.item_name(item), Color(0.8, 0.65, 1.0))


## Вернуть свободные жилы (без бура) в суперпозицию — за квантовый осколок каждая.
func reset_free() -> int:
	var cost: Dictionary = cfg().get("reset_cost", {"quantum_shard": 1})
	var w = game.world
	var idx := vein_idx()
	var n := 0
	for vid in veins:
		var v: Dictionary = veins[vid]
		if str(v.item) == "":
			continue
		var busy := false
		for q in v.cells:
			if game.factory.grid.has(Vector2i(q[0], q[1])):
				busy = true
		if busy:
			continue
		if not game.flags.get("free_build", false):
			var ok := true
			for k in cost:
				if game.factory.available(k) < int(cost[k]):
					ok = false
			if not ok:
				break
			game.factory.pay(cost)
		v.item = ""
		for q in v.cells:
			var c := Vector2i(q[0], q[1])
			w.dep_override.erase(c)
			w.set_deposit(c, idx, DB.color(str(cfg().get("vein_color", "#b98cff"))))
		n += 1
	stats.reset += n
	if n > 0:
		game.notify("В суперпозиции снова: %d жил. Посмотрите на них ещё раз." % n, Color(0.75, 0.6, 1.0))
	else:
		game.notify("Нечего возвращать: свободных схлопнутых жил нет или не хватает осколков", Color(1, 0.8, 0.5))
	return n


# ---------------------------------------------------------------- тени

func is_shade(e) -> bool:
	return bool(e.d.get("quantum", false))


func observed(e) -> bool:
	var cam: Camera3D = game.get_viewport().get_camera_3d()
	var pp: Vector3 = game.player.position
	var at: Vector3 = pp + World.delta(pp, e.pos) + Vector3(0, 1.0, 0)
	if World.dist(pp, e.pos) > num("see_dist", 70.0):
		return false
	return cam == null or cam.is_position_in_frustum(at)


## Каждый кадр: тень в кадре замирает и не бьёт, вне кадра — несётся к герою.
func _freeze() -> void:
	if game.enemies == null:
		return
	for e in game.enemies.list:
		if not e.alive or not is_shade(e):
			continue
		if observed(e):
			e.slow_k = 0.0
			e.cd = maxf(e.cd, 0.4)
			e.kv = Vector3.ZERO
		else:
			e.slow_k = num("unseen_k", 1.0)


func _spawn_shades(dt: float) -> void:
	_spawn_t -= dt
	if _spawn_t > 0.0:
		return
	_spawn_t = num("shade_every", 45.0)
	var typ := str(cfg().get("shade", "q_shade"))
	if not DB.data.enemies.has(typ):
		return
	var alive := 0
	for e in game.enemies.list:
		if e.alive and is_shade(e):
			alive += 1
	if alive >= int(num("shade_max", 4)):
		return
	if bool(cfg().get("shade_night_only", false)) and not game.is_night():
		return
	# появляется за спиной: там, куда камера не смотрит
	var cam: Camera3D = game.get_viewport().get_camera_3d()
	var back := Vector3(0, 0, 1)
	if cam != null:
		back = cam.global_transform.basis.z
		back.y = 0
		back = back.normalized() if back.length() > 0.01 else Vector3(0, 0, 1)
	var pos: Vector3 = game.player.position + back.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(22.0, 32.0)
	var e = game.enemies.spawn(typ, World.wrap_pos(pos))
	if e != null:
		e.target = game.player
		stats.shades += 1
		if alive == 0:
			game.notify("Квантовая тень рядом! Она двигается, только пока вы на неё не смотрите.", Color(0.8, 0.6, 1.0))


# ---------------------------------------------------------------- запутанные пары

func on_place(b) -> void:
	if not b.p("entangled", false) or game.factory.loading:
		return
	for id in pairs:
		var pr: Array = pairs[id]
		pr = pr.filter(func(o): return not o.dead)
		pairs[id] = pr
		if pr.size() == 1 and pr[0].type == b.type and pr[0] != b:
			b.cfg["qpair"] = id
			pr.append(b)
			_link(pr[0], b)
			game.notify("Пара запутана: «%s» связан с первым" % DB.building(b.type).get("name", b.type), Color(0.75, 0.6, 1.0))
			return
	b.cfg["qpair"] = next_pair
	pairs[next_pair] = [b]
	next_pair += 1
	game.notify("Поставьте второй такой же — они станут запутанной парой", Color(0.75, 0.6, 1.0))


func _link(a, b) -> void:
	if a.inv != null and b.inv != null:
		# содержимое второго (обычно пустое) переходит в общее
		for s in b.inv.slots:
			if s != null:
				a.inv.add(str(s.id), int(s.n))
		b.inv = a.inv
	game.factory.power_dirty = true
	stats.linked += 1


func partner(b):
	var id = b.cfg.get("qpair")
	if id == null:
		return null
	for o in pairs.get(int(id), []):
		if o != b and not o.dead:
			return o
	return null


## Снос одного из пары: содержимое остаётся у второго, у сносимого — пусто (ничего не удваивается).
func detach(b) -> void:
	var id = b.cfg.get("qpair")
	if id == null:
		return
	var o = partner(b)
	if o != null and b.inv != null and b.inv == o.inv:
		b.inv = Inventory.new(b.inv.size())
	pairs[int(id)] = pairs.get(int(id), []).filter(func(x): return x != b)
	game.factory.power_dirty = true


## Станции одной пары связаны в одну сеть, сколько бы между ними ни было.
static func linked(a, c) -> bool:
	var pa = a.cfg.get("qpair")
	return pa != null and pa == c.cfg.get("qpair") and a.p("entangled", false)


## После загрузки: собрать пары заново (обе половины сохранили одинаковое содержимое — берём одно).
func after_load() -> void:
	pairs.clear()
	var mx := 0
	for b in game.factory.all:
		var id = b.cfg.get("qpair")
		if id == null:
			continue
		id = int(id)
		mx = maxi(mx, id)
		var pr: Array = pairs.get(id, [])
		if pr.size() == 1 and pr[0].inv != null and b.inv != null:
			b.inv = pr[0].inv
		pr.append(b)
		pairs[id] = pr
	next_pair = maxi(next_pair, mx + 1)
	game.factory.power_dirty = true


func to_dict() -> Dictionary:
	return {"veins": veins, "nv": next_vein, "np": next_pair}


func _net_push() -> void:
	if Net.is_host():
		Net._self().qveins_sync(to_dict())


## B-5 r5: у гостя — жилы от хозяина (появились или схлопнулись).
func apply_net(d: Dictionary) -> void:
	var idx := vein_idx()
	var w = game.world
	var vs: Dictionary = d.get("veins", {})
	for k in vs:
		var vid := int(k)
		var v: Dictionary = vs[k]
		var old: Dictionary = veins.get(vid, {})
		var it := str(v.get("item", ""))
		for q in v.get("cells", []):
			var c := Vector2i(int(q[0]), int(q[1]))
			if it != "":
				w.dep_override[c] = it
				if idx >= 0:
					w.set_deposit(c, idx, DB.item_color(it))
				var b = game.factory.grid.get(c)
				if b != null and b.beh == "miner":
					b.recipe = game.factory.miner_item(b.type, b.cell)
			elif old.is_empty() and idx >= 0:
				w.remove_node(c)
				w.set_deposit(c, idx, DB.color(str(cfg().get("vein_color", "#b98cff"))))
		if it != "" and str(old.get("item", "")) == "":
			game.fx.magic(_vein_center(v), DB.item_color(it), 1.6)
			game.notify("Квантовая жила схлопнулась: %s" % DB.item_name(it), Color(0.8, 0.65, 1.0))
		veins[vid] = v
	next_vein = int(d.get("nv", next_vein))


func from_dict(d: Dictionary) -> void:
	veins.clear()
	var vs: Dictionary = d.get("veins", {})
	for k in vs:
		veins[int(k)] = vs[k]
	next_vein = int(d.get("nv", 1))
	next_pair = int(d.get("np", 1))
	for vid in veins:
		var it := str(veins[vid].get("item", ""))
		if it != "":
			for q in veins[vid].cells:
				game.world.dep_override[Vector2i(int(q[0]), int(q[1]))] = it
