extends RefCounted
## Лабиринты и ловушки (14.7). Монстры у базы ищут путь в обход стен к ближайшему зданию
## (поле направлений от зданий, обход по клеткам). Если пути нет — ломают стену, как раньше.
## Шипы и другие ловушки (здания с «Ловушка: урон в секунду») ранят монстров, которые по ним идут.
## Правится: «Настройки» (радиус лабиринта), «Здания» (Ловушка: урон, Турель: цепь молний).

var game
var R := 0                       # полуразмер области (клеток)
var origin := Vector2i.ZERO      # левый верхний угол области
var side := 0
var dist := PackedInt32Array()   # шагов до ближайшего здания (-1 — не дойти)
var ready := false
var _sig := -1
var _t := 0.0
var _trap_t := 0.0
var traps: Array = []
# перестройка поля идёт по кусочку за кадр (без рывков на большой базе)
var _job := {}
const STEP_CELLS := 3000
const NB := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


func _init(g) -> void:
	game = g


func update(dt: float) -> void:
	var f = game.factory
	if f.hq == null:
		ready = false
		return
	_t -= dt
	if _t <= 0.0:
		_t = 1.5
		var sig: int = f.all.size() * 7919 + f.hq.cell.x * 31 + f.hq.cell.y
		if sig != _sig and _job.is_empty():
			_sig = sig
			_start_job()
	if not _job.is_empty():
		_run_job()
	_trap_t -= dt
	if _trap_t <= 0.0:
		_trap_t = 0.25
		_traps(0.25)


func _blocked(b) -> bool:
	return b != null and not game.factory.walkable(b)


## Поле направлений: обход в ширину от всех зданий, кроме стен (стены и ворота непроходимы).
func rebuild() -> void:
	var f = game.factory
	R = int(DB.setting("maze_radius", 70))
	if R <= 0:
		ready = false
		return
	side = R * 2 + 1
	origin = f.hq.cell - Vector2i(R, R)
	dist = PackedInt32Array()
	dist.resize(side * side)
	dist.fill(-1)
	var q: Array[int] = []
	var wall := PackedByteArray()
	wall.resize(side * side)
	traps.clear()
	for b in f.all:
		if b.dead:
			continue
		if float(b.p("trap_dps", 0.0)) > 0.0 or float(b.p("trap_dps_player", 0.0)) > 0.0:
			traps.append(b)
	for z in side:
		for x in side:
			var c := World.wc(origin + Vector2i(x, z))
			var b = f.grid.get(c)
			var i := z * side + x
			if b == null:
				if game.enemies._wet(c):
					wall[i] = 1
				continue
			if b.beh == "wall" or b.p("wild", false):
				wall[i] = 1
			elif _blocked(b):
				# здание — цель: с него начинается обход
				wall[i] = 1
				dist[i] = 0
				q.append(i)
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var x := i % side
		var z := i / side
		var d := dist[i] + 1
		for k in 4:
			var nx: int = x + NB[k].x
			var nz: int = z + NB[k].y
			if nx < 0 or nz < 0 or nx >= side or nz >= side:
				continue
			var j := nz * side + nx
			if dist[j] >= 0 or wall[j] == 1:
				continue
			dist[j] = d
			q.append(j)
	ready = true


func _idx(c: Vector2i) -> int:
	var d := c - origin
	if World.wrap_w > 0:
		var w := World.wrap_w
		d = Vector2i(posmod(d.x + w / 2, w) - w / 2, posmod(d.y + w / 2, w) - w / 2)
	if d.x < 0 or d.y < 0 or d.x >= side or d.y >= side:
		return -1
	return d.y * side + d.x


## Куда идти монстру в этой точке (по полю). ZERO — поля нет или до зданий не дойти (идёт напрямую).
func dir_at(p: Vector3) -> Vector3:
	if not ready:
		return Vector3.ZERO
	var c: Vector2i = World.world_to_cell(p)
	var i := _idx(c)
	if i < 0 or dist[i] <= 0:
		return Vector3.ZERO
	var best := dist[i]
	var bc := Vector2i.ZERO
	for k in NB.size():
		var o: Vector2i = NB[k]
		var j := _idx(c + o)
		if j < 0:
			continue
		var dj := dist[j]
		if dj < 0 or dj >= best:
			continue
		# по диагонали — только если оба боковых прохода свободны (не срезать угол стены)
		if k >= 4:
			var a := _idx(c + Vector2i(o.x, 0))
			var b := _idx(c + Vector2i(0, o.y))
			if a < 0 or b < 0 or dist[a] < 0 or dist[b] < 0:
				continue
		best = dj
		bc = o
	if bc == Vector2i.ZERO:
		return Vector3.ZERO
	var tgt: Vector3 = World.cell_to_world(World.wc(c + bc))
	var v: Vector3 = World.delta(p, tgt)
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.ZERO


## Перестройка по частям: сначала разметка клеток, потом обход в ширину. Готовое поле подменяется целиком.
func _start_job() -> void:
	var r := int(DB.setting("maze_radius", 70))
	if r <= 0:
		ready = false
		return
	var sd := r * 2 + 1
	var d := PackedInt32Array()
	d.resize(sd * sd)
	d.fill(-1)
	var w := PackedByteArray()
	w.resize(sd * sd)
	_job = {"R": r, "side": sd, "origin": game.factory.hq.cell - Vector2i(r, r), "dist": d, "wall": w, "q": PackedInt32Array(), "i": 0, "head": 0, "phase": 0}


func _run_job() -> void:
	var f = game.factory
	var j := _job
	var sd: int = j.side
	var org: Vector2i = j.origin
	var dd: PackedInt32Array = j.dist
	var wl: PackedByteArray = j.wall
	var q: PackedInt32Array = j.q
	if j.phase == 0:
		var stop: int = mini(sd * sd, int(j.i) + STEP_CELLS)
		for i in range(int(j.i), stop):
			var c := World.wc(org + Vector2i(i % sd, i / sd))
			var b = f.grid.get(c)
			if b == null:
				if game.enemies._wet(c):
					wl[i] = 1
				continue
			if b.beh == "wall" or b.p("wild", false):
				wl[i] = 1
			elif _blocked(b):
				wl[i] = 1
				dd[i] = 0
				q.append(i)
		j.i = stop
		if stop >= sd * sd:
			j.phase = 1
	else:
		var head: int = j.head
		var budget := STEP_CELLS
		while head < q.size() and budget > 0:
			budget -= 1
			var i: int = q[head]
			head += 1
			var x := i % sd
			var z := i / sd
			var nd := dd[i] + 1
			for k in 4:
				var nx: int = x + NB[k].x
				var nz: int = z + NB[k].y
				if nx < 0 or nz < 0 or nx >= sd or nz >= sd:
					continue
				var jj := nz * sd + nx
				if dd[jj] >= 0 or wl[jj] == 1:
					continue
				dd[jj] = nd
				q.append(jj)
		j.head = head
		if head >= q.size():
			R = j.R
			side = sd
			origin = org
			dist = dd
			ready = true
			traps.clear()
			for b in f.all:
				if not b.dead and (float(b.p("trap_dps", 0.0)) > 0.0 or float(b.p("trap_dps_player", 0.0)) > 0.0):
					traps.append(b)
			_job = {}
			return
	j.dist = dd
	j.wall = wl
	j.q = q


## Можно ли дойти до зданий из этой клетки (без ломания стен).
func reachable(p: Vector3) -> bool:
	if not ready:
		return true
	var i := _idx(World.world_to_cell(p))
	return i < 0 or dist[i] >= 0


## Ловушки: урон всем монстрам на клетках ловушки; ловушка изнашивается.
func _traps(dt: float) -> void:
	if traps.is_empty() or Net.is_client():
		return
	var en = game.enemies
	for b in traps.duplicate():
		if b.dead:
			traps.erase(b)
			continue
		var dps := float(b.p("trap_dps", 0.0))
		var r: float = b.size * World.C * 0.55 + 0.3
		var c: Vector3 = b.center()
		var hits := 0
		var pdps := float(b.p("trap_dps_player", 0.0))
		if pdps > 0.0:
			# ловушки подземелий ранят героя (в прыжке — нет)
			for pl in game.hit_targets():   # A-5 r5: оба героя сплитскрина и гости
				var dv: Vector3 = World.delta(c, pl.position)
				if pl.alive and absf(dv.x) <= r and absf(dv.z) <= r and pl.position.y - game.factory.support_at(pl.position) < 0.5:
					if pl is Player and not ("peer" in pl):   # B-6 r9: модель гостя тоже Player — ей урон порциями
						pl.damage(pdps * dt)
					else:
						# гостю — накопленный урон целыми порциями (не RPC каждый кадр)
						var acc: float = float(pl.get_meta("trap_acc", 0.0)) + pdps * dt
						if acc >= 2.0:
							pl.damage(acc)
							acc = 0.0
						pl.set_meta("trap_acc", acc)
					hits += 1
		if dps <= 0.0:
			continue
		for e in en.list:
			if not e.alive or e.npc != "" or e.fly or e.under > 0.5:
				continue
			if absf(World.delta(c, e.pos).x) <= r and absf(World.delta(c, e.pos).z) <= r:
				en.hit(e, dps * dt)
				hits += 1
				if randf() < 0.3:
					game.fx.spark(e.pos + Vector3(0, 0.3, 0))
		if hits > 0:
			var wear := float(b.p("trap_wear", 2.0))
			if wear > 0.0:
				game.factory.damage(b, wear * hits * dt)
