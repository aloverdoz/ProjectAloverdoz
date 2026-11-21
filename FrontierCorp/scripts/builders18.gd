class_name Builders18
extends RefCounted
## 18: роботы-строители. В каждой «Мастерской роботов-строителей» живёт один робот. Когда монстры ломают здание, стену,
## ленту или трубу, на её месте остаётся «призрак» (полупрозрачный контур). Робот мастерской, в радиусе которой лежит
## призрак, берёт стоимость здания из штаба, идёт туда и отстраивает его заново: тот же поворот, рецепт и настройки.
## Когда отстраивать нечего — подлатывает повреждённые здания рядом (бесплатно, понемногу).
## Робот работает только в небольшом радиусе своей мастерской, тратит энергию постоянно (без энергии стоит),
## не воюет и хрупкий: монстры рядом его ломают, мастерская собирает нового за ресурсы из штаба.
## Правится: здание — «Радиус стройки», «Скорость робота», «Время стройки», «Прочность робота», «Ремонт в сек»;
## «Настройки» → «Роботы-строители»: сколько минут помнить развалины, цена и время сборки нового робота.

var game
var f:
	get:
		return game.factory
var ruins: Array = []        # {type, cell, dir, r, cfg, t, claim, node}
var bays := {}               # мастерская (B) → {"bot": {...} или null, "dead_t": сек}
var _scan_t := 0.0
var _threat_t := 0.0
var _net_t := 0.0
var _note_t := 0.0
var _net_nodes := {}         # у гостя: номер → узел робота (положения присылает хозяин)


static func cfg() -> Dictionary:
	var c = DB.setting("builders", {})
	return c if c is Dictionary else {}


static func is_bay(b) -> bool:
	return b != null and bool(b.p("builder_bay", false))


func _init(g) -> void:
	game = g


# ---------------------------------------------------------------- развалины

## Здание разрушено монстрами: запомнить, что тут стояло (вызывается из factory.damage и у гостей из сети).
func add_ruin(b) -> void:
	if b == null or b == f.hq:
		return
	if not DB.data.buildings.has(b.type) or not bool(b.p("buildable", true)):
		return
	for r in ruins:
		if r.cell == b.cell:
			return
	var r := {"type": b.type, "cell": b.cell, "dir": b.dir, "r": b.recipe, "cfg": b.cfg.duplicate(true), "t": 0.0, "claim": null, "node": null,
		"lvl": b.lvl, "subs": _subs_plan(b), "owner": str(b.bstate.get("owner", ""))}   # 1.1.15 (+B-6 r4: и владелец): уровень объединения и встроенные машины — восстанавливаются вместе с ним
	ruins.append(r)
	_ghost(r)


## 1.1.15: что было встроено в составное здание (без содержимого — оно сгорело).
func _subs_plan(b) -> Array:
	var out := []
	for e in f.fz.save_subs(b):
		var q := {"t": e.t, "lvl": int(e.get("lvl", 1)), "r": str(e.get("r", ""))}
		if e.has("cfg"):
			q["cfg"] = e.cfg
		out.append(q)
	return out


## 1.1.15: цена восстановления: здание × уровень объединения + встроенные машины.
func ruin_cost(r: Dictionary) -> Dictionary:
	var out := {}
	var parts := [[str(r.type), maxi(1, int(r.get("lvl", 1)))]]
	for e in r.get("subs", []):
		parts.append([str(e.get("t", "")), maxi(1, int(e.get("lvl", 1)))])
	for pr in parts:
		var c := cost_of(pr[0])
		for k in c:
			out[k] = int(out.get(k, 0)) + int(c[k]) * int(pr[1])
	return out


## 1.1.15: вернуть восстановленному зданию уровень и встроенные машины (на всех в сети — из команды repair/ruin_extra).
func restore_extra(nb, lvl: int, subs: Array) -> void:
	if nb == null or nb.dead:
		return
	if lvl > 1 and f.fz.levels_on():
		f.fz.set_level(nb, lvl)
	if not subs.is_empty() and nb.subs.is_empty():
		f.fz.load_subs(nb, subs)
		for sb in nb.subs:
			sb.paid = {}   # 1.1.15: восстановление оплачено целиком в основе — иначе снос возвращал полную цену частей (размножение ресурсов)
		f.fz.refresh_visual(nb)
		f.power_dirty = true
	nb.hp = nb.maxhp


## 1.1.12: развалины под клеткой (по всему следу здания) или null.
func ruin_at(c: Vector2i):
	c = World.wc(c)
	for r in ruins:
		var sz := maxi(1, int(DB.building(r.type).get("size", 1)))
		for x in sz:
			for z in sz:
				if World.wc(r.cell + Vector2i(x, z)) == c:
					return r
	return null


## 1.1.12: на месте развалин поставили здание — развалины убираются (раньше контур оставался под новым зданием).
func clear_at(type: String, cell: Vector2i) -> void:
	var sz := maxi(1, int(DB.building(type).get("size", 1)))
	for x in sz:
		for z in sz:
			var r = ruin_at(cell + Vector2i(x, z))
			if r != null:
				_drop_ruin(r)


func _ghost(r: Dictionary) -> void:
	if not bool(cfg().get("show_ruins", true)) or game.world == null:
		return
	# 1.0.8: не куб, а тонкий контур на земле — и виден только когда игрок занят роботами (см. _ruins_visible)
	var sz := maxi(1, int(DB.building(r.type).get("size", 1)))
	var w := sz * World.C * 0.92
	var root := Node3D.new()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.8, 0.3, 0.75)
	var mf := m.duplicate()
	mf.albedo_color = Color(1.0, 0.8, 0.3, 0.12)
	mf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var t := 0.08
	for e in [[Vector3(w, 0.06, t), Vector3(0, 0, -w * 0.5)], [Vector3(w, 0.06, t), Vector3(0, 0, w * 0.5)],
			[Vector3(t, 0.06, w), Vector3(-w * 0.5, 0, 0)], [Vector3(t, 0.06, w), Vector3(w * 0.5, 0, 0)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = e[0]
		mi.mesh = bm
		mi.position = e[1]
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var pl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, w)
	pl.mesh = pm
	pl.material_override = mf
	pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pl)
	game.add_child(root)
	var c0: Vector3 = World.cell_to_world(r.cell)
	var cen := c0 + Vector3((sz - 1) * World.C * 0.5, 0, (sz - 1) * World.C * 0.5)
	root.position = Vector3(cen.x, game.world.height_at(cen) + 0.05, cen.z)
	root.visible = _ruins_visible()
	r.node = root


## 1.0.8: контуры развалин видны, только пока открыто окно мастерской роботов или игрок ставит мастерскую
## («Роботы-строители» → «Когда видны контуры»: bay / always).
func _ruins_visible() -> bool:
	if str(cfg().get("ruins_when", "bay")) == "always":
		return true
	if game.build_type != "" and bool(DB.building(game.build_type).get("params", {}).get("builder_bay", false)):
		return true
	var h = game.hud
	if h == null or not h.is_open("building"):
		return false
	return is_bay(h.bld)


var _vis_last := false
func _vis_ruins() -> void:
	var v := _ruins_visible()
	if v == _vis_last:
		return
	_vis_last = v
	for r in ruins:
		if r.node != null and is_instance_valid(r.node):
			r.node.visible = v


func _drop_ruin(r: Dictionary) -> void:
	if r.node != null and is_instance_valid(r.node):
		r.node.queue_free()
	r.node = null
	ruins.erase(r)


func ruin_center(r: Dictionary) -> Vector3:
	var sz := maxi(1, int(DB.building(r.type).get("size", 1)))
	var c0: Vector3 = World.cell_to_world(r.cell)
	var cen := c0 + Vector3((sz - 1) * World.C * 0.5, 0, (sz - 1) * World.C * 0.5)
	return Vector3(cen.x, game.world.height_at(cen), cen.z)


## Цена отстройки: как у стройки игрока (с бонусами навыков).
func cost_of(type: String) -> Dictionary:
	return game._scaled_cost(type)


func _can_pay(cost: Dictionary) -> String:
	if game.flags.get("free_build", false):
		return ""
	if f.hq == null:
		return "нет штаба"
	var miss := []
	for k in cost:
		if f.hq.inv.count(k) < int(cost[k]):
			miss.append("%s %d" % [DB.item_name(k), int(cost[k]) - f.hq.inv.count(k)])
	return ", ".join(miss)


# ---------------------------------------------------------------- мастерские

func _sync() -> void:
	var seen := {}
	for b in f.all:
		if is_bay(b) and not b.dead:
			seen[b] = true
			if not bays.has(b):
				bays[b] = {"bot": null, "dead_t": 0.0, "msg": "", "built": 0}
				bays[b].bot = _new_bot(b)
	for b in bays.keys():
		if not seen.has(b):
			var bot = bays[b].bot
			if bot != null:
				_free_bot(bot)
			bays.erase(b)


func _new_bot(b) -> Dictionary:
	var p: Vector3 = b.center()
	var bot := {"pos": Vector3(p.x, game.world.height_at(p), p.z + 1.2), "hp": float(b.p("bot_hp", 40)), "state": "dock",
		"job": null, "rep": null, "t": 0.0, "yaw": 0.0, "node": null}
	bot.node = _bot_node()
	bot.node.position = bot.pos
	return bot


func _bot_node() -> Node3D:
	var m := "builder_bot"
	var node: Node3D = ModelLib.make_node(m if not DB.model_def(m).is_empty() else "drone_carrier")
	game.add_child(node)
	return node


func _free_bot(bot: Dictionary) -> void:
	if bot.node != null and is_instance_valid(bot.node):
		bot.node.queue_free()
	bot.node = null
	if bot.job != null:
		bot.job.claim = null


func radius_m(b) -> float:
	return float(b.p("build_radius", 10)) * World.C


func update(dt: float) -> void:
	_vis_ruins()
	if Net.is_client():
		_client_cleanup(dt)
		return
	_scan_t -= dt
	_note_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_sync()
		_tidy(0.5)
	_threat_t -= dt
	var threat := _threat_t <= 0.0
	if threat:
		_threat_t = 0.25
	for b in bays.keys():
		var s: Dictionary = bays[b]
		b.want = true                      # робот на зарядке и в работе — постоянная нагрузка
		var sat: float = clampf(f.sat_c(b), 0.0, 1.0)
		if s.bot == null:
			s.dead_t -= dt
			s.msg = "Робот сломан — новый через %d с" % maxi(0, ceili(s.dead_t))
			if s.dead_t <= 0.0:
				var cost: Dictionary = cfg().get("rebuild_cost", {})
				var miss := _can_pay(cost)
				if miss == "":
					if not game.flags.get("free_build", false):
						for k in cost:
							f.hq.inv.remove(k, int(cost[k]))
					s.bot = _new_bot(b)
				else:
					s.msg = "Новый робот: в штабе не хватает %s" % miss
			continue
		_step(b, s, s.bot, dt, sat)
		if threat:
			_threats(b, s, 0.25)
		b.active = sat > 0.1 and s.bot != null and s.bot.state != "dock"
	if Net.is_host():
		_net_t -= dt
		if _net_t <= 0.0:
			_net_t = 0.25
			_send()


## Развалины: время жизни; убрать, если место заняли (игрок поставил сам или робот отстроил).
func _tidy(dt: float) -> void:
	var keep := float(cfg().get("ruin_keep_min", 40.0)) * 60.0
	for r in ruins.duplicate():
		r.t += dt
		var o = f.building_at(r.cell)
		if (o != null and not o.dead) or r.t > keep:
			_drop_ruin(r)


func _client_cleanup(dt: float) -> void:
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_tidy(0.5)


func _step(b, s: Dictionary, bot: Dictionary, dt: float, sat: float) -> void:
	var speed: float = float(b.p("bot_speed", 4.0)) * sat
	var home: Vector3 = b.center() + Vector3(0, 0, 1.2)
	match bot.state:
		"dock":
			s.msg = "Робот ждёт: всё целое" if sat > 0.1 else "Нет энергии — робот стоит"
			if sat <= 0.1:
				return
			bot.t -= dt
			if bot.t > 0.0:
				return
			bot.t = 0.5
			_find_job(b, s, bot)
		"go":
			var tgt: Vector3 = ruin_center(bot.job) if bot.job != null else (bot.rep.center() if bot.rep != null and not bot.rep.dead else home)
			if bot.job != null and not ruins.has(bot.job):
				bot.job = null
				bot.state = "back"
				return
			if bot.rep != null and (bot.rep.dead or bot.rep.hp >= bot.rep.maxhp):
				bot.rep = null
				bot.state = "back"
				return
			if _walk(bot, tgt, speed, dt, 1.6):
				bot.state = "build" if bot.job != null else "repair"
				bot.t = float(b.p("build_time", 4.0))
		"build":
			var r = bot.job
			if r == null or not ruins.has(r):
				bot.state = "back"
				return
			s.msg = "Отстраивает: %s" % DB.building(r.type).get("name", r.type)
			bot.t -= dt * sat
			if randf() < dt * 4.0 and game.fx:
				game.fx.puff(ruin_center(r) + Vector3(randf_range(-0.5, 0.5), 0.6, randf_range(-0.5, 0.5)), "spark", 0.6)
			if bot.t <= 0.0:
				_rebuild(b, s, r)
				bot.job = null
				bot.t = 0.0
				_find_job(b, s, bot)
				if bot.state == "dock":
					bot.state = "back"
		"repair":
			var o = bot.rep
			if o == null or o.dead or o.hp >= o.maxhp:
				bot.rep = null
				_find_job(b, s, bot)
				if bot.state == "dock":
					bot.state = "back"
				return
			s.msg = "Чинит: %s" % DB.building(o.type).get("name", o.type)
			f.repair(o, float(b.p("bot_repair", 15.0)) * sat * dt)
			if randf() < dt * 3.0 and game.fx:
				game.fx.puff(o.center() + Vector3(0, 1.0, 0), "spark", 0.5)
		"back":
			s.msg = "Возвращается в мастерскую"
			if _walk(bot, home, speed, dt, 0.6):
				bot.state = "dock"
				bot.t = 0.5
	_visual(bot)


## Ближайшая развалина в радиусе (на которую хватает ресурсов), иначе ближайшее повреждённое здание.
func _find_job(b, s: Dictionary, bot: Dictionary) -> void:
	var c: Vector3 = b.center()
	var rr := radius_m(b)
	var best = null
	var bd := INF
	var short := ""
	for r in ruins:
		if r.claim != null and r.claim != b:
			continue
		var d: float = World.dist(c, ruin_center(r))
		if d > rr or d >= bd:
			continue
		if f.can_place(r.type, r.cell) != "":
			continue
		var miss := _can_pay(ruin_cost(r))
		if miss != "":
			short = "Не хватает в штабе на «%s»: %s" % [DB.building(r.type).get("name", r.type), miss]
			continue
		best = r
		bd = d
	if best != null:
		best.claim = b
		bot.job = best
		bot.rep = null
		bot.state = "go"
		return
	var rep = null
	bd = INF
	for o in f.damaged.keys():
		if o == null or o.dead or o.hp >= o.maxhp:
			continue
		var d: float = World.dist(c, o.center())
		if d <= rr and d < bd:
			rep = o
			bd = d
	if rep != null:
		bot.rep = rep
		bot.job = null
		bot.state = "go"
		return
	if short != "":
		s.msg = short
		if _note_t <= 0.0:
			_note_t = 30.0
			game.notify("Робот-строитель: " + short, Color(1, 0.8, 0.45))
	if bot.state != "dock" and bot.state != "back":
		bot.state = "back"


func _rebuild(b, s: Dictionary, r: Dictionary) -> void:
	var cost := ruin_cost(r)
	if _can_pay(cost) != "" or f.can_place(r.type, r.cell) != "":
		r.claim = null
		return
	var free_was: bool = game.flags.get("free_build", false)
	if not free_was:
		for k in cost:
			f.hq.inv.remove(k, int(cost[k]))
	game.flags["free_build"] = true
	var own0 := str(r.get("owner", ""))
	var nb = game.cmd("place", {"type": r.type, "cell": r.cell, "dir": r.dir, "owner": own0 if own0 != "" else str(b.bstate.get("owner", Net._self().nick if Net.active() else ""))})
	game.flags["free_build"] = free_was
	if nb == null:
		# не встало — вернуть ресурсы
		if not free_was:
			for k in cost:
				f.hq.inv.add(k, int(cost[k]))
		r.claim = null
		return
	nb.paid = {} if free_was else cost
	if str(r.r) != "":
		game.cmd("recipe", {"b": nb, "rid": str(r.r)})
	if r.cfg is Dictionary and not r.cfg.is_empty():
		game.cmd("bcfg", {"b": nb, "cfg": r.cfg})
	if int(r.get("lvl", 1)) > 1 or not (r.get("subs", []) as Array).is_empty():
		game.cmd("ruin_extra", {"b": nb, "lvl": int(r.get("lvl", 1)), "subs": r.get("subs", [])})
	s.built = int(s.get("built", 0)) + 1
	_drop_ruin(r)


func _walk(bot: Dictionary, to: Vector3, speed: float, dt: float, near: float) -> bool:
	var d: Vector3 = World.delta(bot.pos, to)
	d.y = 0
	var dist := d.length()
	if dist <= near:
		return true
	if speed <= 0.0:
		return false
	var step := minf(dist, speed * dt)
	var dir := d / dist
	bot.pos += dir * step
	bot.pos.y = game.world.height_at(bot.pos)
	bot.yaw = atan2(dir.x, dir.z)
	return false


func _visual(bot: Dictionary) -> void:
	var n: Node3D = bot.node
	if n == null or not is_instance_valid(n):
		return
	var t := Time.get_ticks_msec() * 0.001
	var bob := sin(t * 10.0) * 0.04 if bot.state in ["go", "back"] else 0.0
	n.position = bot.pos + Vector3(0, bob, 0)
	n.rotation.y = bot.yaw
	if bot.state in ["build", "repair"]:
		n.rotation.z = sin(t * 14.0) * 0.12
	else:
		n.rotation.z = 0.0


## Монстры рядом бьют робота (он не отвечает).
func _threats(b, s: Dictionary, dt: float) -> void:
	var bot = s.bot
	if bot == null or game.enemies == null:
		return
	var r := float(cfg().get("threat_r", 4.0))
	var dmg := 0.0
	for e in game.enemies.list:
		if not e.alive or e.npc != "" or e.peaceful:
			continue
		var dd: Vector3 = World.delta(bot.pos, game.enemies.pos_of(e))
		if Vector2(dd.x, dd.z).length() <= r + (3.0 if e.ranged else 0.0):
			dmg += e.dmg / maxf(0.3, e.rate) * dt
	if dmg <= 0.0:
		return
	bot.hp -= dmg
	if bot.hp <= 0.0:
		game.fx.explosion(bot.pos + Vector3(0, 0.6, 0), 0.7, Color(1.0, 0.7, 0.2))
		game.sfx.play("boom", bot.pos)
		_free_bot(bot)
		s.bot = null
		s.dead_t = float(cfg().get("rebuild_bot_s", 45.0))
		if _note_t <= 0.0:
			_note_t = 10.0
			game.notify("Монстры сломали робота-строителя! Мастерская соберёт нового.", Color(1, 0.5, 0.35))


## Строка для окна мастерской.
func info(b) -> String:
	if not bays.has(b):
		return "Робот-строитель: %d клеток вокруг" % int(b.p("build_radius", 10))
	var s: Dictionary = bays[b]
	var pending := 0
	for r in ruins:
		if World.dist(b.center(), ruin_center(r)) <= radius_m(b):
			pending += 1
	var hp := ""
	if s.bot != null:
		hp = " · прочность робота %d/%d" % [int(s.bot.hp), int(b.p("bot_hp", 40))]
	return "Робот-строитель: %s%s\nРадиус %d клеток · ждут отстройки: %d · отстроено: %d%s" % [str(s.get("msg", "")), hp, int(b.p("build_radius", 10)), pending, int(s.get("built", 0)),
		"\nЖёлтые контуры на земле — что робот отстроит (видны, пока открыто это окно)" if pending > 0 else ""]


func bot_of(b):
	return bays[b].bot if bays.has(b) else null


# ---------------------------------------------------------------- сеть: гости видят роботов хозяина

func _send() -> void:
	var arr := PackedFloat32Array()
	for b in bays:
		var bot = bays[b].bot
		if bot != null:
			arr.append_array([bot.pos.x, bot.pos.y, bot.pos.z, bot.yaw, 1.0 if bot.state in ["build", "repair"] else 0.0])
	Net._self().send_bots18(arr)


func net_bots(arr: PackedFloat32Array) -> void:
	var n := int(arr.size() / 5)
	for i in n:
		if not _net_nodes.has(i) or not is_instance_valid(_net_nodes[i]):
			_net_nodes[i] = _bot_node()
		var node: Node3D = _net_nodes[i]
		node.position = Vector3(arr[i * 5], arr[i * 5 + 1], arr[i * 5 + 2])
		node.rotation.y = arr[i * 5 + 3]
		node.rotation.z = sin(Time.get_ticks_msec() * 0.014) * 0.12 if arr[i * 5 + 4] > 0.5 else 0.0
	for k in _net_nodes.keys():
		if int(k) >= n:
			if is_instance_valid(_net_nodes[k]):
				_net_nodes[k].queue_free()
			_net_nodes.erase(k)


# ---------------------------------------------------------------- сохранение

func to_dict() -> Dictionary:
	return {"ruins": ruins.map(func(r): return {"type": r.type, "c": [r.cell.x, r.cell.y], "d": r.dir, "r": r.r, "cfg": r.cfg, "t": r.t,
		"lvl": int(r.get("lvl", 1)), "subs": r.get("subs", []), "owner": str(r.get("owner", ""))})}


func from_dict(d: Dictionary) -> void:
	for r in ruins.duplicate():
		_drop_ruin(r)
	for e in d.get("ruins", []):
		if e is Dictionary and DB.data.buildings.has(str(e.get("type", ""))):
			var r := {"type": str(e.type), "cell": Vector2i(int(e.c[0]), int(e.c[1])), "dir": int(e.get("d", 0)), "r": str(e.get("r", "")),
				"cfg": e.get("cfg", {}), "t": float(e.get("t", 0.0)), "claim": null, "node": null,
				"lvl": int(e.get("lvl", 1)), "subs": e.get("subs", []) if e.get("subs") is Array else [], "owner": str(e.get("owner", ""))}
			ruins.append(r)
			_ghost(r)
