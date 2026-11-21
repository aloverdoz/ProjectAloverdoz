class_name Coop
extends Node
## 16: игра вместе — торговля между игроками, продажа энергии, свои базы и «подколы».
##  • Рынок игрока (здание): владелец ставит цены на товар в нём и «Куплю» на то, что скупает; другие покупают и продают
##    за свои кредиты (правило комнаты «У каждого свои деньги»).
##  • Продажа / покупка энергии: пара зданий-опор в разных сетях, кВт идут из сети продавца в сеть покупателя.
##  • Подколы: эмоции над головой, фразы, метка на земле, снежки и помидоры, подушка-пердушка, розовая краска, гном,
##    сюрприз в ящике, кирпич с запиской, пинок, гудок, «дай пять», конфетти, салют, диско, кубик, корона богачу…
## Включаются правилами комнаты («Подколы», «Торговля»); числа — «Правила игры → coop».

var game
var traps: Array = []        # [Vector3, ник] — спрятанные подушки
var _labels := {}            # здание → Label3D (надпись таблички)
var _paint := {}             # здание → Node3D (розовые пятна)
var _bubbles := {}           # узел героя → Label3D
var crown: Node3D
var _t := 0.0
var _flag_in := ""
var _five := {}              # ник → время «дай пять» (мс)
var _cool := {}              # что → время, когда можно снова
var _owed := {}              # покупатель энергии → накопленный долг (дробные кредиты)
var disco_t := 0.0
var ui: CanvasLayer
var panel: PanelContainer
var _splat_layer: CanvasLayer
var seen := {}               # какие фишки приходили (для проверок)


func _init(g) -> void:
	game = g
	name = "Coop"


static func cfg() -> Dictionary:
	return DB.setting("coop", {})


static func c(k: String, def):
	return cfg().get(k, def)


func net():
	return Net._self()


func online() -> bool:
	return Net.active()


func pranks_on() -> bool:
	return not online() or bool(net().room.get("pranks", true))


func trade_on() -> bool:
	return not online() or bool(net().room.get("trade", true))


func me() -> String:
	return net().nick if online() else "Вы"


## Герой по нику: свой или чужой (в сетевой игре).
func hero_of(nk: String):
	if nk == "" or nk == me() or not online():
		return game.player
	for id in net().puppets:
		var pp = net().puppets[id]
		if is_instance_valid(pp) and pp.nick == nk:
			return pp
	return null


func peer_of(nk: String) -> int:
	if not online():
		return 0
	for id in net().peers:
		if str(net().peers[id].nick) == nk:
			return int(id)
	return 0


## Сообщение тому, кто сделал действие (у хозяина действие гостя — сообщение уходит гостю).
func tell(text: String, col := Color(1, 0.8, 0.5)) -> void:
	if Net.is_host() and net().actor != 0:
		net().rpc_id(net().actor, "toast", text, col)
	else:
		game.notify(text, col)


static func owner_of(b) -> String:
	return str(b.bstate.get("owner", "")) if b != null else ""


func is_mine(b) -> bool:
	var o := owner_of(b)
	return o == "" or not online() or o == net().actor_nick()


## Отправить «фишку» всем (и показать у себя).
func fun(kind: String, d := {}) -> void:
	d["by"] = me()
	if online():
		net().rpc("fun_remote", kind, d)
	on_fun(kind, d)


func _ready_cool(key: String, sec: float) -> bool:
	var now := Time.get_ticks_msec()
	if now < int(_cool.get(key, 0)):
		return false
	_cool[key] = now + int(sec * 1000)
	return true


# ================================================================ показ фишек

func on_fun(kind: String, d: Dictionary) -> void:
	seen[kind] = int(seen.get(kind, 0)) + 1
	if not pranks_on() and not kind in ["ping", "emote", "phrase"]:
		return
	var by := str(d.get("by", ""))
	var h = hero_of(by)
	var pos: Vector3 = d.get("pos", h.position if h else game.player.position)
	match kind:
		"emote", "phrase":
			bubble(h, str(d.get("text", "")))
		"ping":
			_ping(pos, by, DB.color(str(d.get("col", "#ffd23f"))))
		"throw":
			_throw(d.get("a", pos), d.get("b", pos), str(d.get("item", "snowball")), str(d.get("target", "")), by)
		"cushion":
			traps.append([pos, by])
		"fart":
			for tr in traps.duplicate():
				if World.dist(tr[0], pos) < 1.5:
					traps.erase(tr)
			game.sfx.play("fart", pos)
			game.fx.puff(pos + Vector3(0, 0.4, 0), "smoke", 1.4)
			var vic := str(d.get("victim", ""))
			bubble(hero_of(vic), "Пффф!")
			game.notify("%s сел на подушку-пердушку от %s" % [vic, by], Color(1, 0.6, 0.9))
		"confetti":
			confetti(pos + Vector3(0, 2.2, 0))
			game.sfx.play("pop", pos)
		"firework":
			firework(pos)
		"brick":
			var tgt := str(d.get("target", ""))
			var th = hero_of(tgt)
			if th:
				_fly(pos + Vector3(0, 1.6, 0), th.position + Vector3(0, 1.6, 0), "brick", func():
					game.sfx.play("bonk", th.position)
					bubble(th, "Ай!"))
			if tgt == me():
				game.notify("Вам прилетел кирпич от %s с запиской: «%s»" % [by, str(d.get("text", "..."))], Color(1, 0.75, 0.5))
			else:
				game.notify("%s кинул кирпич в %s" % [by, tgt], Color(0.8, 0.8, 0.8))
		"push":
			var tg := str(d.get("target", ""))
			bubble(hero_of(tg), "Эй!")
			if tg == me():
				var dir: Vector3 = d.get("dir", Vector3.FORWARD)
				var tw := create_tween()
				tw.tween_property(game.player, "position", game.player.position + dir.normalized() * 4.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				game.notify("%s дал вам пинка!" % by, Color(1, 0.7, 0.5))
		"horn":
			game.sfx.play("horn", pos)
			bubble(h, "БИ-БИП!")
		"five":
			_five[by] = Time.get_ticks_msec()
			bubble(h, "Дай пять!")
			for other in _five:
				if other != by and Time.get_ticks_msec() - int(_five[other]) < 4000:
					var oh = hero_of(other)
					if oh and h and World.dist(oh.position, h.position) < 5.0:
						_five.erase(other)
						_five.erase(by)
						confetti((oh.position + h.position) * 0.5 + Vector3(0, 2.5, 0))
						game.sfx.play("pop", pos)
						game.notify("Дай пять! %s и %s — достижение «Команда»" % [other, by], Color(0.6, 1, 0.6))
						break
		"boo":
			confetti(pos + Vector3(0, 1.5, 0))
			game.sfx.play("pop", pos)
			bubble(hero_of(str(d.get("victim", ""))), "А-а-а!")
			game.notify("%s открыл сюрприз от %s. БУ!" % [str(d.get("victim", "")), by], Color(1, 0.6, 0.9))
		"disco":
			disco_t = 15.0
			game.notify("%s включил диско на 15 секунд!" % by, Color(0.9, 0.6, 1))
		"gnome":
			game.notify("%s подкинул гнома на базу игрока %s" % [by, str(d.get("to", ""))], Color(0.7, 0.9, 1))
		"gift":
			confetti(pos + Vector3(0, 2.2, 0))
			if str(d.get("to", "")) == me():
				game.notify("Подарок от %s: %s ×%d" % [by, DB.item_name(str(d.get("id", ""))), int(d.get("n", 1))], Color(0.6, 1, 0.6))


## Облачко с текстом над героем (3 секунды).
func bubble(h, text: String, sec := 3.0) -> void:
	if h == null or not is_instance_valid(h) or text == "":
		return
	var l: Label3D = _bubbles.get(h)
	if l == null or not is_instance_valid(l):
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 64
		l.pixel_size = 0.006
		l.outline_size = 12
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.modulate = Color(1, 1, 0.85)
		l.position = Vector3(0, 3.7, 0)
		h.add_child(l)
		_bubbles[h] = l
	l.text = text
	l.visible = true
	l.set_meta("until", Time.get_ticks_msec() + int(sec * 1000))


func _unshaded(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _ping(pos: Vector3, by: String, col: Color) -> void:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.18
	cm.height = 14.0
	mi.mesh = cm
	mi.material_override = _unshaded(Color(col.r, col.g, col.b, 0.55))
	mi.position = Vector3(0, 7, 0)
	n.add_child(mi)
	var l := Label3D.new()
	l.text = by
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.pixel_size = 0.008
	l.outline_size = 12
	l.modulate = col
	l.position = Vector3(0, 14.5, 0)
	n.add_child(l)
	game.add_child(n)
	n.position = pos
	game.sfx.play("click", pos)
	get_tree().create_timer(8.0).timeout.connect(n.queue_free)


func _fly(a: Vector3, b: Vector3, what: String, done := Callable()) -> void:
	var mi := MeshInstance3D.new()
	if what == "brick":
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.2, 0.2)
		mi.mesh = bm
		mi.material_override = _unshaded(Color(0.72, 0.3, 0.2))
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		mi.mesh = sm
		mi.material_override = _unshaded(Color(0.95, 0.97, 1.0) if what == "snowball" else Color(0.85, 0.12, 0.12))
	game.add_child(mi)
	mi.position = a
	var h := clampf(World.dist(a, b) * 0.15, 0.5, 5.0)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(mi):
			mi.position = a.lerp(b, t) + Vector3(0, 4.0 * h * t * (1.0 - t), 0)
			mi.rotation.x = t * 12.0, 0.0, 1.0, clampf(World.dist(a, b) / 22.0, 0.25, 1.2))
	tw.tween_callback(func():
		if is_instance_valid(mi):
			mi.queue_free()
		if done.is_valid():
			done.call())


func _throw(a: Vector3, b: Vector3, item: String, target: String, by: String) -> void:
	_fly(a, b, item, func():
		game.sfx.play("bonk" if item == "snowball" else "splat", b)
		game.fx.puff(b, "steam" if item == "snowball" else "smoke", 0.6)
		var th = hero_of(target) if target != "" else null
		if th:
			bubble(th, "Ой!")
		if target != "" and target == me() and online():
			splat(Color(0.95, 0.97, 1.0, 0.92) if item == "snowball" else Color(0.8, 0.1, 0.08, 0.88))
			game.notify("В вас попал%s от %s" % [" снежок" if item == "snowball" else " помидор", by], Color(1, 0.7, 0.6)))


## Залепленный экран (помидор, снежок).
func splat(col: Color) -> void:
	if _splat_layer == null:
		_splat_layer = CanvasLayer.new()
		_splat_layer.layer = 30
		game.add_child(_splat_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splat_layer.add_child(root)
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	for i in 9:
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		var r := randf_range(90, 300)
		sb.set_corner_radius_all(int(r))
		p.add_theme_stylebox_override("panel", sb)
		p.size = Vector2(r * 2, r * 2 * randf_range(0.7, 1.2))
		p.position = Vector2(randf_range(0, vs.x) - r, randf_range(0, vs.y) - r)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
	var tw := create_tween()
	tw.tween_interval(float(c("splat_time", 4.0)) * 0.5)
	tw.tween_property(root, "modulate:a", 0.0, float(c("splat_time", 4.0)) * 0.5)
	tw.tween_callback(root.queue_free)


func confetti(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 160
	p.lifetime = 2.6
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0, -7, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	var qm := QuadMesh.new()
	qm.size = Vector2(0.14, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = m
	p.mesh = qm
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray([Color("#ff3b3b"), Color("#ffd23f"), Color("#4cd964"), Color("#3fa9ff"), Color("#b05cff"), Color("#ff5fc8")])
	p.color_initial_ramp = g
	game.add_child(p)
	p.position = pos
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


func firework(pos: Vector3) -> void:
	game.sfx.play("firework", pos)
	var rk := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	rk.mesh = sm
	rk.material_override = _unshaded(Color(1, 0.9, 0.5))
	game.add_child(rk)
	rk.position = pos + Vector3(0, 1, 0)
	var top := pos + Vector3(randf_range(-2, 2), 18, randf_range(-2, 2))
	var tw := create_tween()
	tw.tween_property(rk, "position", top, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		rk.queue_free()
		var hue := randf()
		var p := CPUParticles3D.new()
		p.amount = 220
		p.lifetime = 2.2
		p.one_shot = true
		p.explosiveness = 1.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.3
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 7.0
		p.initial_velocity_max = 11.0
		p.gravity = Vector3(0, -3, 0)
		p.damping_min = 2.0
		p.damping_max = 3.0
		var sm2 := SphereMesh.new()
		sm2.radius = 0.09
		sm2.height = 0.18
		sm2.radial_segments = 4
		sm2.rings = 2
		var m := _unshaded(Color.from_hsv(hue, 0.7, 1.0))
		m.vertex_color_use_as_albedo = true
		sm2.material = m
		p.mesh = sm2
		var g := Gradient.new()
		g.colors = PackedColorArray([Color.from_hsv(hue, 0.5, 1.0), Color.from_hsv(fmod(hue + 0.15, 1.0), 0.9, 1.0, 0.0)])
		p.color_ramp = g
		game.add_child(p)
		p.position = top
		p.emitting = true
		var lt := OmniLight3D.new()
		lt.light_color = Color.from_hsv(hue, 0.6, 1.0)
		lt.omni_range = 40.0
		lt.light_energy = 6.0
		game.add_child(lt)
		lt.position = top
		var t2 := create_tween()
		t2.tween_property(lt, "light_energy", 0.0, 1.2)
		t2.tween_callback(lt.queue_free)
		get_tree().create_timer(3.5).timeout.connect(p.queue_free))


# ================================================================ предметы-подколы

## Использовать предмет с полем «prank» (снежок, помидор, краска, подушка, салют, хлопушка). true — потрачен.
func use_item(id: String, kind: String) -> bool:
	if not pranks_on():
		game.notify("Подколы выключены в правилах этой комнаты", Color(1, 0.7, 0.5))
		return false
	var pl = game.player
	match kind:
		"snowball", "tomato":
			var tgt := _aim_target(30.0)
			var b: Vector3 = tgt[1]
			fun("throw", {"a": pl.position + Vector3(0, 1.6, 0), "b": b, "item": kind, "target": tgt[0]})
			return true
		"paint":
			var bb = _front_building(7.0)
			if bb == null:
				game.notify("Подойдите к зданию и смотрите на него", Color(1, 0.8, 0.5))
				return false
			game.cmd("paint", {"b": bb, "by": me()})
			return true
		"cushion":
			fun("cushion", {"pos": pl.position})
			game.notify("Подушка спрятана. Ждём…", Color(1, 0.6, 0.9))
			return true
		"firework":
			fun("firework", {"pos": pl.position})
			return true
		"confetti":
			fun("confetti", {"pos": pl.position})
			return true
	return false


## Кого видит герой: [ник, точка]. Сначала другой игрок перед героем, иначе точка под курсором.
func _aim_target(rng: float) -> Array:
	var pl = game.player
	var fwd: Vector3 = (game.hover_point - pl.position)
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var best := ""
	var bp: Vector3 = game.hover_point
	var bd := INF
	if online():
		for id in net().puppets:
			var pp = net().puppets[id]
			if not is_instance_valid(pp) or not pp.alive:
				continue
			var d: Vector3 = World.delta(pl.position, pp.position)
			d.y = 0
			if d.length() < rng and (d.length() < 2.5 or d.normalized().dot(fwd) > 0.75) and d.length() < bd:
				bd = d.length()
				best = pp.nick
				bp = pp.position + Vector3(0, 1.4, 0)
	if best == "" and World.dist(pl.position, bp) > rng:
		bp = pl.position + fwd * rng
	return [best, bp]


func _front_building(rng: float):
	var b = game.factory.building_at(World.world_to_cell(game.hover_point))
	if b != null and World.dist(game.player.position, b.center()) < rng + b.size * 2.0:
		return b
	return game.factory.nearest_building(game.player.position, int(rng / World.C))


## Розовая краска на здании (команда «paint», сохраняется и видна всем).
func paint(b, by: String) -> void:
	if b == null:
		return
	if by == "":
		b.bstate.erase("paint")
	else:
		b.bstate["paint"] = by
		game.sfx.play("splat", b.center())
		if owner_of(b) != "" and owner_of(b) != by:
			game.notify("%s покрасил здание игрока %s в розовый" % [by, owner_of(b)], Color(1, 0.6, 0.9))
	_paint_fx(b)


func _paint_fx(b) -> void:
	var has: bool = str(b.bstate.get("paint", "")) != "" and not b.dead
	var n: Node3D = _paint.get(b)
	if not has:
		if n != null and is_instance_valid(n):
			n.queue_free()
		_paint.erase(b)
		return
	if n != null and is_instance_valid(n):
		return
	n = Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(b.cell)
	var half: float = b.size * World.C * 0.5
	var col := DB.color(str(c("paint_color", "#ff5fc8")))
	for i in 10 + b.size * 6:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r: float = rng.randf_range(0.25, 0.6) * (1.0 + b.size * 0.25)
		sm.radius = r
		sm.height = r * 0.5
		sm.radial_segments = 8
		sm.rings = 3
		mi.mesh = sm
		mi.material_override = _unshaded(col.lerp(Color.WHITE, rng.randf() * 0.25))
		mi.position = Vector3(rng.randf_range(-half, half), rng.randf_range(0.3, 1.6 + b.size * 0.6), rng.randf_range(-half, half))
		n.add_child(mi)
	game.add_child(n)
	n.position = b.center()
	_paint[b] = n


# ================================================================ рынок игрока

static func is_market(b) -> bool:
	return b != null and bool(b.p("player_market", false))


static func price_of(b, id: String) -> int:
	return int(b.cfg.get("prices", {}).get(id, 0))


## Купить у рынка (действие от лица покупателя: его рюкзак и кредиты).
func market_buy(b, id: String, n: int) -> int:
	if not trade_on():
		tell("Торговля выключена в правилах комнаты")
		return 0
	var price := price_of(b, id)
	if price <= 0:
		tell("Это не продаётся")
		return 0
	var who: String = net().actor_nick() if online() else ""
	if who != "" and who == owner_of(b):
		tell("Это ваш рынок — заберите товар как из ящика")
		return 0
	var shared_money: bool = online() and not net().own_wallets()   # B-1 r10
	n = mini(n, b.inv.count(id))
	if not shared_money:
		n = mini(n, int(game.credits / price))
	if n <= 0:
		tell("Не хватает кредитов" if b.inv.count(id) > 0 else "Товар закончился")
		return 0
	var got: int = b.inv.move_to(game.player.inv, id, n)   # B-7 r5: со своим износом/свежестью
	if got <= 0:
		tell("Рюкзак полон")
		return 0
	if not shared_money:
		game.credits -= got * price
		_pay_owner(b, got * price)
	game.sfx.play("coin", b.center())
	tell(("Взято с рынка: %s ×%d (деньги в комнате общие)" % [DB.item_name(id), got]) if shared_money else ("Куплено: %s ×%d за %d кр" % [DB.item_name(id), got, got * price]), Color(0.6, 1, 0.6))
	return got


## Продать рынку по его «Куплю» (деньги платит владелец рынка).
func market_sell(b, id: String, n: int) -> int:
	if not trade_on():
		tell("Торговля выключена в правилах комнаты")
		return 0
	var w: Array = b.cfg.get("wants", {}).get(id, [0, 0])
	var price := int(w[0])
	var want := int(w[1]) if w.size() > 1 else 0
	if price <= 0 or want <= 0:
		tell("Этот рынок такое не покупает")
		return 0
	var own := owner_of(b)
	var budget: int = net().wallet_get(own) if online() and own != "" else game.credits
	# B-1 r10: при общих деньгах сделка — только обмен вещами (иначе продажа создавала кредиты из ничего)
	var shared_money: bool = online() and not net().own_wallets()
	n = mini(mini(n, game.player.inv.count(id)), want)
	if not shared_money:
		n = mini(n, int(budget / price))
	if n <= 0:
		tell("У владельца рынка нет денег" if game.player.inv.count(id) > 0 else "У вас нет: " + DB.item_name(id))
		return 0
	var put: int = game.player.inv.move_to(b.inv, id, n)   # B-7 r5
	if put <= 0:
		tell("Рынок переполнен")
		return 0
	if not shared_money:
		game.credits += put * price
		if online() and own != "":
			net().wallet_add(own, -put * price)
	var nw: Dictionary = b.cfg.get("wants", {}).duplicate(true)
	nw[id] = [price, want - put]
	b.cfg["wants"] = nw
	game.sfx.play("coin", b.center())
	tell(("Отдано на рынок: %s ×%d (деньги в комнате общие)" % [DB.item_name(id), put]) if shared_money else ("Продано: %s ×%d за %d кр" % [DB.item_name(id), put, put * price]), Color(0.6, 1, 0.6))
	return put


func _pay_owner(b, amount: int) -> void:
	var own := owner_of(b)
	if online() and own != "":
		net().wallet_add(own, amount)
	elif not online():
		game.credits += amount


## Доход здания (продажа через торговый терминал): кредиты владельцу здания.
func income(b, amount: int) -> void:
	if Net.is_client():
		return   # деньги считает хозяин игры
	if online() and net().own_wallets() and owner_of(b) != "" and owner_of(b) != net().nick:
		net().wallet_add(owner_of(b), amount)
	else:
		game.add_credits(amount, false)


# ================================================================ продажа энергии

static func trade_kind(b) -> String:
	return str(b.p("power_trade", "")) if b != null else ""


func sellers() -> Array:
	var out := []
	for b in game.factory.power_nodes:
		if not b.dead and trade_kind(b) == "sell":
			out.append(b)
	return out


## Из расчёта сетей (factory._power): покупатель получает кВт из сети продавца, продавец платит спросом.
func grid(f, dt: float) -> void:
	var sold := {}
	for bu in f.power_nodes:
		if bu.dead or trade_kind(bu) != "buy" or bu.net < 0:
			continue
		bu.bstate["pw_in"] = 0.0
		var fr = bu.cfg.get("from")
		if not (fr is Array) or fr.size() < 2 or not trade_on():
			continue
		var se = f.building_at(Vector2i(int(fr[0]), int(fr[1])))
		if se == null or se.dead or trade_kind(se) != "sell" or se.net < 0 or se.net == bu.net:
			continue
		var cap := float(se.cfg.get("kw", 20.0)) - float(sold.get(se, 0.0))
		var kw := clampf(float(bu.cfg.get("kw", 10.0)), 0.0, maxf(0.0, cap))
		var price := float(se.cfg.get("price", 1.0))
		var buyer := owner_of(bu)
		if online() and Net.is_host() and net().own_wallets() and buyer != owner_of(se) and net().wallet_get(buyer) <= 0 and price > 0.0:
			continue   # у покупателя кончились деньги
		var sn: Dictionary = f.nets[se.net]
		var sat := float(sn.get("sat", 1.0)) if not sn.tripped else 0.0
		sn.demand += kw
		var got := kw * sat
		f.nets[bu.net].supply += got
		f.nets[bu.net].gen_max += kw
		sold[se] = float(sold.get(se, 0.0)) + kw
		bu.bstate["pw_in"] = got
		se.bstate["pw_out"] = float(sold[se])
		if Net.is_client() or price <= 0.0:
			continue
		var owe: float = float(_owed.get(bu, 0.0)) + got * price * dt / 60.0
		var whole := int(owe)
		_owed[bu] = owe - whole
		if whole > 0 and online() and buyer != owner_of(se):
			net().wallet_add(buyer, -whole)
			net().wallet_add(owner_of(se), whole)
	for se in sellers():
		if not sold.has(se):
			se.bstate["pw_out"] = 0.0


# ================================================================ своя база

## Новый игрок со своей базой: открыть ему участок, убрать деревья, поставить аванпост со стартовым набором.
func make_base(cell: Vector2i, rc: Vector2i, owner: String):
	var z = game.zone
	if z and z.on() and not rc in z.rects:
		z.rects.append(rc)
		z.rebuild()
	for dx in range(-4, 6):
		for dz in range(-4, 6):
			game.world.remove_node(World.wc(cell + Vector2i(dx, dz)))
	var b = game.factory.building_at(cell)
	if b != null:
		return b if b.type == "outpost" else null
	if game.factory.can_place("outpost", cell) != "":
		return null
	b = game.factory.place("outpost", cell, 0)
	b.bstate["owner"] = owner
	b.paid = {}
	var kit: Dictionary = c("kit", {})
	for it in kit:
		if DB.data.items.has(it):
			b.inv.add(it, int(kit[it]))
	return b


func outpost_of(nk: String):
	for b in game.factory.all:
		if not b.dead and b.type == "outpost" and owner_of(b) == nk:
			return b
	return null


# ================================================================ цикл

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game.player):
		return
	_t += delta
	var now := Time.get_ticks_msec()
	for h in _bubbles.keys():
		var l = _bubbles[h]
		if not is_instance_valid(h) or not is_instance_valid(l):
			_bubbles.erase(h)
		elif l.visible and now > int(l.get_meta("until", 0)):
			l.visible = false
	# подушки: наступил свой герой на чужую
	for tr in traps:
		if tr[1] != me() and World.dist(game.player.position, tr[0]) < 1.1:
			fun("fart", {"pos": tr[0], "victim": me(), "by_trap": tr[1]})
			break
	if disco_t > 0.0:
		disco_t -= delta
		if game.sun:
			game.sun.light_color = Color.from_hsv(fmod(_t * 0.8, 1.0), 0.8, 1.0)
	if _t >= 1.0:
		_t = 0.0
		_slow()


## Раз в секунду: таблички, краска, флаги территорий, корона, склад своей базы.
func _slow() -> void:
	var f = game.factory
	for b in _labels.keys():
		if not is_instance_valid(_labels[b]) or b.dead or str(b.cfg.get("text", "")) == "":
			if is_instance_valid(_labels[b]):
				_labels[b].queue_free()
			_labels.erase(b)
	for b in _paint.keys():
		if b.dead or str(b.bstate.get("paint", "")) == "":
			_paint_fx(b)
	var here := ""
	for b in f.all:
		if b.dead:
			continue
		var tx := str(b.cfg.get("text", ""))
		if tx != "":
			var l: Label3D = _labels.get(b)
			if l == null:
				l = Label3D.new()
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.font_size = 48
				l.pixel_size = 0.006
				l.outline_size = 10
				l.modulate = Color(1, 0.95, 0.8)
				game.add_child(l)
				l.position = b.center() + Vector3(0, 2.2, 0)
				_labels[b] = l
			l.text = tx
		if str(b.bstate.get("paint", "")) != "" and not _paint.has(b):
			_paint_fx(b)
		if b.type == "flag" and online() and owner_of(b) != "" and owner_of(b) != me():
			if World.dist(game.player.position, b.center()) < float(c("flag_radius", 14)):
				here = owner_of(b)
	if here != _flag_in:
		_flag_in = here
		if here != "":
			game.notify("Вы на территории игрока %s" % here, Color(0.7, 0.9, 1))
	_update_crown()
	if online() and net().separate() and Net.is_client():
		var ob = outpost_of(me())
		f.personal = ob.inv if ob != null else net().empty_store()
		f.personal_b = ob


func _update_crown() -> void:
	var rich := ""
	var best := -1
	if online() and net().peers.size() >= 2:
		for nk in net().stats:
			var cr := int(net().stats[nk].get("cr", 0))
			if cr > best:
				best = cr
				rich = nk
	var h = hero_of(rich) if rich != "" else null
	if h == null:
		if crown and is_instance_valid(crown):
			crown.visible = false
		return
	if crown == null or not is_instance_valid(crown):
		crown = Node3D.new()
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(1.0, 0.8, 0.2)
		gold.metallic = 0.9
		gold.roughness = 0.25
		gold.emission_enabled = true
		gold.emission = Color(0.5, 0.35, 0.05)
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.32
		cm.bottom_radius = 0.3
		cm.height = 0.16
		ring.mesh = cm
		ring.material_override = gold
		crown.add_child(ring)
		for i in 5:
			var sp := MeshInstance3D.new()
			var cn := CylinderMesh.new()
			cn.top_radius = 0.0
			cn.bottom_radius = 0.08
			cn.height = 0.24
			sp.mesh = cn
			sp.material_override = gold
			var a := i * TAU / 5.0
			sp.position = Vector3(cos(a) * 0.27, 0.18, sin(a) * 0.27)
			crown.add_child(sp)
	if crown.get_parent() != h:
		if crown.get_parent():
			crown.get_parent().remove_child(crown)
		h.add_child(crown)
		crown.position = Vector3(0, 3.05, 0)
	crown.visible = true
	crown.rotation.y += 0.05


## Звания по таблице игроков: богатый, строитель, душа компании.
func titles() -> Dictionary:
	var out := {}
	if not online() or net().stats.size() < 2:
		return out
	for k in [["cr", "Магнат"], ["bld", "Строитель"], ["rep", "Душа компании"]]:
		var best := ""
		var bv := 0
		for nk in net().stats:
			var v := int(net().stats[nk].get(k[0], 0))
			if v > bv:
				bv = v
				best = nk
		if best != "":
			out[best] = (out.get(best, "") + ", " if out.has(best) else "") + str(k[1])
	return out


# ================================================================ команды чата

## «/команда» в чате. true — обработано.
func chat_command(t: String) -> bool:
	if not t.begins_with("/"):
		return false
	var p := t.substr(1).split(" ", false, 2)
	if p.is_empty():
		return true
	var cmd := p[0].to_lower()
	var arg := p[1] if p.size() > 1 else ""
	var rest := p[2] if p.size() > 2 else ""
	if cmd in ["pay", "gift", "brick", "thanks", "kick"] and p.size() > 1:
		# A-11: ник может быть с пробелом («Гость 2») — ищем самый длинный известный ник в начале
		var body := t.substr(1 + p[0].length()).strip_edges()
		var best := ""
		var known: Array = [net().nick]
		for k in net().peers:
			known.append(str(net().peers[k].nick))
		for nk in known:
			if nk.length() > best.length() and (body == nk or body.begins_with(nk + " ")):
				best = nk
		if best != "":
			arg = best
			rest = body.substr(best.length()).strip_edges()
	var em: Dictionary = c("emotes", {})
	if em.has(cmd):
		fun("emote", {"text": str(em[cmd])})
		return true
	match cmd:
		"help", "помощь":
			game.notify("Команды: /pay ник сумма, /gift ник (выбранный предмет), /brick ник записка, /push, /five, /horn, /roll, /coin, /disco, /thanks ник, /kick ник, /yes, /no, /me действие, /admin пароль — админ-панель, /admin пароль команда (выделенный сервер), эмоции: /" + " /".join(em.keys()), Color(0.7, 0.9, 1))
		"pay":
			game.cmd("pay", {"to": arg, "n": int(rest)})
		"gift":
			var s = game.player.inv.slots[game.player.selected] if game.player.selected < game.player.inv.size() else null
			if s == null:
				game.notify("Выберите предмет на панели быстрого доступа", Color(1, 0.8, 0.5))
			else:
				game.cmd("gift", {"to": arg, "id": s.id, "n": int(s.n)})
		"brick":
			if pranks_on() and peer_of(arg) != 0 and _ready_cool("brick", 5.0):
				fun("brick", {"target": arg, "text": rest if rest != "" else "привет"})
		"push":
			var tg := _nearest_player(3.5)
			if tg[0] != "" and pranks_on():
				fun("push", {"target": tg[0], "dir": tg[1]})
			else:
				game.notify("Рядом никого", Color(1, 0.8, 0.5))
		"five":
			fun("five")
		"horn":
			if _ready_cool("horn", 3.0):
				fun("horn", {"pos": game.player.position})
		"disco":
			if _ready_cool("disco", 30.0):
				fun("disco")
		"roll", "coin":
			net().req_roll(cmd) if online() else game.notify("Кубик: %d" % randi_range(1, 6) if cmd == "roll" else ("Орёл" if randf() < 0.5 else "Решка"), Color(0.8, 0.9, 1))
		"thanks", "спасибо":
			if online():
				net().rpc_id(1, "req_thanks", arg) if Net.is_client() else net().req_thanks_local(net().nick, arg)
		"kick":
			if online():
				net().start_vote(arg)
		"yes", "no":
			if online():
				net().vote(cmd == "yes")
		"admin", "админ":
			# 1.0.9: команды выделенного сервера: /admin пароль status | save | kick ник | say текст | stop
			# 1.1.11: «/admin пароль» без команды — открыть админ-панель
			if rest.strip_edges() == "" or not Net.is_client():
				game.notify(game.admin.login(arg), Color(1, 0.85, 0.35))
			else:
				net().rpc_id(1, "req_admin", (arg + " " + rest).strip_edges())
		"me":
			if online():
				net().send_chat_raw("* %s %s" % [net().nick, (arg + " " + rest).strip_edges()])
		_:
			game.notify("Нет такой команды. /help — список", Color(1, 0.7, 0.5))
	return true


func _nearest_player(r: float) -> Array:
	var best := ""
	var bd := r
	var dir := Vector3.FORWARD
	if online():
		for id in net().puppets:
			var pp = net().puppets[id]
			if is_instance_valid(pp):
				var d: Vector3 = World.delta(game.player.position, pp.position)
				if d.length() < bd:
					bd = d.length()
					best = pp.nick
					dir = Vector3(d.x, 0, d.z)
	return [best, dir]


## Метка на земле под курсором (клавиша «Метка», видно всем).
func ping() -> void:
	if _ready_cool("ping", 1.0):
		fun("ping", {"pos": game.hover_point, "col": net().color if online() else "#ffd23f"})


# ================================================================ окно «Фишки»

func panel_open() -> bool:
	return panel != null and panel.visible


func toggle_panel() -> void:
	if panel_open():
		panel.visible = false
		return
	if ui == null:
		ui = CanvasLayer.new()
		ui.layer = 7
		game.add_child(ui)
	if panel != null:
		panel.queue_free()
	panel = UI.panel(0.92)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = 70
	ui.add_child(panel)
	var v := UI.vbox(6)
	panel.add_child(v)
	var hdr := UI.hbox(8)
	hdr.add_child(UI.title("ФИШКИ И ПОДКОЛЫ", 18))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	hdr.add_child(UI.button("✕", toggle_panel))
	v.add_child(hdr)
	if online() and not pranks_on():
		v.add_child(UI.small("В этой комнате подколы выключены — остались эмоции, фразы и метки."))
	v.add_child(UI.section("Эмоции над головой"))
	var em := HFlowContainer.new()
	var emotes: Dictionary = c("emotes", {})
	for k in emotes:
		var txt := str(emotes[k])
		em.add_child(UI.button(txt, func(): fun("emote", {"text": txt}), "/" + k))
	v.add_child(em)
	v.add_child(UI.section("Быстрые фразы (в чат и над головой)"))
	var ph := HFlowContainer.new()
	for s in c("phrases", []):
		var txt := str(s)
		ph.add_child(UI.button(txt, func():
			fun("phrase", {"text": txt})
			if online():
				net().send_chat_text(txt)))
	v.add_child(ph)
	v.add_child(UI.section("Праздник и шум"))
	var pr := HFlowContainer.new()
	pr.add_child(UI.button("Конфетти", func(): if _ready_cool("confetti", 3.0): fun("confetti", {"pos": game.player.position})))
	pr.add_child(UI.button("Салют", func(): if _ready_cool("firework", 4.0): fun("firework", {"pos": game.player.position})))
	pr.add_child(UI.button("Гудок", func(): if _ready_cool("horn", 3.0): fun("horn", {"pos": game.player.position})))
	pr.add_child(UI.button("Дай пять!", func(): fun("five"), "Двое рядом нажимают в течение 4 секунд"))
	pr.add_child(UI.button("Диско 15 с", func(): if _ready_cool("disco", 30.0): fun("disco")))
	pr.add_child(UI.button("Метка под курсором", ping, "Клавиша " + str(Prefs.get_value("key_ping", "O"))))
	pr.add_child(UI.button("Кубик", func(): chat_command("/roll")))
	pr.add_child(UI.button("Монетка", func(): chat_command("/coin")))
	v.add_child(pr)
	v.add_child(UI.section("Подколы предметами (делаются на верстаке)"))
	var it := HFlowContainer.new()
	for row in [["snowball", "Снежок"], ["tomato", "Помидор"], ["paint_can", "Краска на здание"], ["cushion", "Подушка"], ["surprise", "Сюрприз (положите в чужой ящик)"]]:
		var iid: String = row[0]
		var have: int = game.player.inv.count(iid)
		var bt := UI.button("%s (%d)" % [row[1], have], func():
			if iid == "surprise":
				game.notify("Положите «Сюрприз» в чужой ящик, как обычный предмет", Color(1, 0.8, 0.6))
				return
			var slot: int = game.player.inv.find(iid) if game.player.inv.has_method("find") else -1
			if game.player.inv.count(iid) <= 0:
				game.notify("Нет: %s — сделайте на верстаке" % DB.item_name(iid), Color(1, 0.8, 0.5))
				return
			if use_item(iid, str(DB.item(iid).get("prank", ""))):
				game.player.inv.remove(iid, 1)
			toggle_panel()
			toggle_panel())
		it.add_child(bt)
	v.add_child(it)
	if online():
		v.add_child(UI.section("Другие игроки"))
		for id in net().peers:
			var nk := str(net().peers[id].nick)
			if nk == me():
				continue
			var r := HFlowContainer.new()
			r.add_child(UI.label(nk, 15, DB.color(str(net().peers[id].color))))
			r.add_child(UI.button("Кирпич", func(): chat_command("/brick %s привет" % nk)))
			r.add_child(UI.button("Спасибо", func(): chat_command("/thanks " + nk), "+1 к репутации"))
			r.add_child(UI.button("Подарить выбранное", func(): chat_command("/gift " + nk)))
			var sb := SpinBox.new()
			sb.min_value = 1
			sb.max_value = 100000
			sb.value = 100
			r.add_child(sb)
			r.add_child(UI.button("Перевести кр", func(): chat_command("/pay %s %d" % [nk, int(sb.value)])))
			r.add_child(UI.button("Выгнать", func(): chat_command("/kick " + nk), "Голосование всех игроков (хозяин выгоняет сразу)"))
			v.add_child(r)
		v.add_child(UI.small("Чат: Enter. Команды: /help"))


# ================================================================ панели в окне здания

## Окно здания: владелец, рынок, энергия, надпись, краска.
func building_panel(hud, w, b) -> void:
	var v := UI.vbox(5)
	var own := owner_of(b)
	if online() and own != "":
		v.add_child(UI.small("Владелец: %s%s" % [own, " (вы)" if own == me() else ""]))
	if str(b.bstate.get("paint", "")) != "":
		var r := UI.hbox(8)
		r.add_child(UI.label("В розовых пятнах от %s" % str(b.bstate.paint), 14, Color(1, 0.6, 0.9)))
		r.add_child(UI.button("Отмыть", func():
			game.cmd("paint", {"b": b, "by": ""})
			w.set_meta("built_for", null)))
		v.add_child(r)
	if b.type in ["sign", "flag"] or b.cfg.has("text"):
		var r2 := UI.hbox(8)
		r2.add_child(UI.label("Надпись", 14))
		var le := LineEdit.new()
		le.text = str(b.cfg.get("text", ""))
		le.placeholder_text = "Здесь был %s" % me()
		le.custom_minimum_size = Vector2(260, 0)
		le.text_submitted.connect(func(tx: String):
			var nc: Dictionary = b.cfg.duplicate(true)
			nc["text"] = tx.left(60)
			game.cmd("bcfg", {"b": b, "cfg": nc}))
		r2.add_child(le)
		r2.add_child(UI.small("Enter — сохранить"))
		v.add_child(r2)
	if is_market(b):
		_market_ui(v, w, b)
	if trade_kind(b) != "":
		_power_ui(v, w, b)
	if v.get_child_count() > 0:
		w.body.add_child(v)


func _market_ui(v: VBoxContainer, w, b) -> void:
	var mine := owner_of(b) == "" or owner_of(b) == me()
	v.add_child(UI.section("Рынок игрока" + ("" if mine else " · " + owner_of(b))))
	var prices: Dictionary = b.cfg.get("prices", {})
	var wants: Dictionary = b.cfg.get("wants", {})
	var push := func(key: String, val):
		var nc: Dictionary = b.cfg.duplicate(true)
		nc[key] = val
		game.cmd("bcfg", {"b": b, "cfg": nc})
	if mine:
		v.add_child(UI.small("Цена за штуку (0 — не продаётся). Товар привозите лентами с любой стороны или кладите руками. Деньги приходят вам."))
		var ids := {}
		for s in b.inv.slots:
			if s != null:
				ids[s.id] = true
		for id in prices:
			ids[id] = true
		var g := GridContainer.new()
		g.columns = 3
		for id in ids:
			g.add_child(UI.item_icon(id, 24))
			g.add_child(UI.label("%s ×%d" % [DB.item_name(id), b.inv.count(id)], 14))
			var sb := SpinBox.new()
			sb.max_value = 100000
			sb.value = int(prices.get(id, 0))
			sb.suffix = "кр"
			var iid: String = id
			sb.value_changed.connect(func(x):
				var np: Dictionary = b.cfg.get("prices", {}).duplicate()
				np[iid] = int(x)
				push.call("prices", np))
			g.add_child(sb)
		v.add_child(g)
		v.add_child(UI.section("Куплю (другие продают вам, платите вы)"))
		for id in wants:
			var r := UI.hbox(6)
			r.add_child(UI.item_icon(id, 24))
			r.add_child(UI.label("%s: по %d кр, ещё %d шт" % [DB.item_name(id), int(wants[id][0]), int(wants[id][1])], 14))
			var iid2: String = id
			r.add_child(UI.button("✕", func():
				var nw: Dictionary = b.cfg.get("wants", {}).duplicate(true)
				nw.erase(iid2)
				push.call("wants", nw)
				w.set_meta("built_for", null)))
			v.add_child(r)
		var add := UI.hbox(6)
		var ob := OptionButton.new()
		var all_ids: Array = DB.data.items.keys().filter(func(x): return not DB.discovery or DB.is_known(x))
		all_ids.sort_custom(func(x, y): return DB.item_name(x) < DB.item_name(y))
		for i in all_ids.size():
			ob.add_item(DB.item_name(all_ids[i]), i)
		ob.custom_minimum_size = Vector2(200, 0)
		add.add_child(ob)
		var pr := SpinBox.new()
		pr.min_value = 1
		pr.max_value = 100000
		pr.value = 5
		pr.suffix = "кр"
		add.add_child(pr)
		var qn := SpinBox.new()
		qn.min_value = 1
		qn.max_value = 100000
		qn.value = 50
		qn.suffix = "шт"
		add.add_child(qn)
		add.add_child(UI.button("+ Куплю", func():
			var nw: Dictionary = b.cfg.get("wants", {}).duplicate(true)
			nw[all_ids[ob.selected]] = [int(pr.value), int(qn.value)]
			push.call("wants", nw)
			w.set_meta("built_for", null)))
		v.add_child(add)
	else:
		var any := false
		for id in prices:
			if int(prices[id]) <= 0 or b.inv.count(id) <= 0:
				continue
			any = true
			var r := UI.hbox(6)
			r.add_child(UI.item_icon(id, 24))
			r.add_child(UI.label("%s ×%d — %d кр/шт" % [DB.item_name(id), b.inv.count(id), int(prices[id])], 14))
			var iid: String = id
			for n in [1, 10, 50]:
				var nn: int = n
				r.add_child(UI.button("Купить %d" % n, func():
					game.cmd("mbuy", {"b": b, "id": iid, "n": nn})
					w.set_meta("built_for", null)))
			v.add_child(r)
		for id in wants:
			if int(wants[id][1]) <= 0:
				continue
			any = true
			var r2 := UI.hbox(6)
			r2.add_child(UI.item_icon(id, 24))
			r2.add_child(UI.label("Купит %s по %d кр (ещё %d) · у вас %d" % [DB.item_name(id), int(wants[id][0]), int(wants[id][1]), game.player.inv.count(id)], 14))
			var iid3: String = id
			r2.add_child(UI.button("Продать 10", func():
				game.cmd("msell", {"b": b, "id": iid3, "n": 10})
				w.set_meta("built_for", null)))
			r2.add_child(UI.button("Продать всё", func():
				game.cmd("msell", {"b": b, "id": iid3, "n": 99999})
				w.set_meta("built_for", null)))
			v.add_child(r2)
		if not any:
			v.add_child(UI.small("Пока ничего не продаётся и не покупается."))
		v.add_child(UI.small("Ваши кредиты: %d" % int(game.credits)))


func _power_ui(v: VBoxContainer, w, b) -> void:
	var mine := owner_of(b) == "" or owner_of(b) == me()
	var push := func(key: String, val):
		var nc: Dictionary = b.cfg.duplicate(true)
		nc[key] = val
		game.cmd("bcfg", {"b": b, "cfg": nc})
	if trade_kind(b) == "sell":
		v.add_child(UI.section("Продажа энергии"))
		v.add_child(UI.small("Сейчас покупают: %.1f кВт. Цена — кредиты за 1 кВт в минуту." % float(b.bstate.get("pw_out", 0.0))))
		var r := UI.hbox(8)
		r.add_child(UI.label("Не больше", 14))
		var kw := SpinBox.new()
		kw.max_value = 5000
		kw.value = float(b.cfg.get("kw", 20.0))
		kw.suffix = "кВт"
		kw.editable = mine
		kw.value_changed.connect(func(x): push.call("kw", x))
		r.add_child(kw)
		r.add_child(UI.label("Цена", 14))
		var pr := SpinBox.new()
		pr.max_value = 1000
		pr.step = 0.1
		pr.value = float(b.cfg.get("price", 1.0))
		pr.suffix = "кр"
		pr.editable = mine
		pr.value_changed.connect(func(x): push.call("price", x))
		r.add_child(pr)
		v.add_child(r)
	else:
		v.add_child(UI.section("Покупка энергии"))
		v.add_child(UI.small("Приходит: %.1f кВт. Выберите продавца (его «Продажа энергии» должна быть в другой сети)." % float(b.bstate.get("pw_in", 0.0))))
		var r := UI.hbox(8)
		var ob := OptionButton.new()
		ob.add_item("— нет —")
		var list := sellers()
		var fr = b.cfg.get("from")
		for i in list.size():
			var se = list[i]
			ob.add_item("%s · %.1f кр/кВт·мин · до %d кВт" % [owner_of(se) if owner_of(se) != "" else "ничья", float(se.cfg.get("price", 1.0)), int(se.cfg.get("kw", 20.0))])
			if fr is Array and fr.size() >= 2 and Vector2i(int(fr[0]), int(fr[1])) == se.cell:
				ob.select(i + 1)
		ob.disabled = not mine
		ob.item_selected.connect(func(ix):
			push.call("from", [list[ix - 1].cell.x, list[ix - 1].cell.y] if ix > 0 else null))
		r.add_child(ob)
		var kw := SpinBox.new()
		kw.max_value = 5000
		kw.value = float(b.cfg.get("kw", 10.0))
		kw.suffix = "кВт"
		kw.editable = mine
		kw.value_changed.connect(func(x): push.call("kw", x))
		r.add_child(kw)
		v.add_child(r)
