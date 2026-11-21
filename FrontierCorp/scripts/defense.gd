extends RefCounted
## Оборона (13.10): энергощиты, замедляющие поля, ремонтные башни. Здания с полем «Оборона: тип»:
##   barrier — щит-купол с запасом прочности: принимает на себя урон героя и зданий внутри, сам восстанавливается;
##   slow    — поле замедления: роботы внутри идут медленнее;
##   repair  — ремонтная башня: чинит здания вокруг.
## Числа — в параметрах здания (редактор → «Здания»), нужна энергия, если задана «Энергия».

var game
var st := {}          # здание -> {hp, down, flash, node}
var list: Array = []
var _scan_t := 0.0
var _rep_t := 0.0
const SHADER := preload("res://shaders/barrier.gdshader")


func _init(g) -> void:
	game = g


func _active(b) -> bool:
	return not b.dead and b.hp > 0.0 and Factory.clock(b) > 0.0 and game.factory._sat(b) >= 0.5


func state(b) -> Dictionary:
	if not st.has(b):
		st[b] = {"hp": float(b.p("barrier_hp", 0)) * b.mult, "down": 0.0, "flash": 0.0, "node": null}
	return st[b]


## Урон по точке: сначала его принимают щиты, под которыми точка. Возвращает остаток урона.
func absorb(pos: Vector3, amount: float) -> float:
	if amount <= 0.0:
		return amount
	for b in list:
		if b.p("defense", "") != "barrier" or not _active(b):
			continue
		var s := state(b)
		if s.hp <= 0.0 or s.down > 0.0:
			continue
		if World.dist(b.center(), pos) > float(b.p("barrier_radius", 10.0)):
			continue
		var take := minf(amount, s.hp)
		s.hp -= take
		s.flash = 1.0
		amount -= take
		if s.hp <= 0.0:
			s.down = float(b.p("barrier_delay", 8.0))
			game.notify("Щит пробит: %s восстановится через %d с" % [DB.building(b.type).get("name", b.type), int(s.down)], Color(1, 0.6, 0.3))
			game.sfx.play("boom", b.center())
		if amount <= 0.0:
			return 0.0
	return amount


func update(dt: float) -> void:
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 1.0
		list.clear()
		for b in game.factory.all:
			if b.p("defense", "") != "":
				list.append(b)
			for sb in b.subs:   # 14.10: щиты и поля, встроенные в составное здание
				if sb.p("defense", "") != "":
					list.append(sb)
		for b in st.keys():
			if not b in list:
				if st[b].node:
					st[b].node.queue_free()
				st.erase(b)
	# замедление: сначала у всех снимаем, потом поля задают своё
	for e in game.enemies.list:
		e.slow_k = 1.0
	_rep_t -= dt
	var rep := _rep_t <= 0.0
	if rep:
		_rep_t = 1.0
	for b in list:
		var kind: String = b.p("defense", "")
		var on := _active(b)
		match kind:
			"barrier":
				var s := state(b)
				var mx: float = float(b.p("barrier_hp", 500)) * b.mult * maxf(0.05, Factory.clock(b))   # A-6 r3: прочность барьера — по мощности
				if s.down > 0.0:
					s.down -= dt
					if s.down <= 0.0:
						s.hp = mx * 0.25
				elif on:
					s.hp = minf(mx, s.hp + float(b.p("barrier_regen", 10.0)) * b.mult * game.factory.sat_c(b) * dt)
				s.hp = minf(s.hp, mx)
				s.flash = maxf(0.0, s.flash - dt * 3.0)
				_dome(b, s, on and s.down <= 0.0 and s.hp > 0.0, s.hp / maxf(1.0, mx))
			"slow":
				if not on:
					continue
				var r := float(b.p("slow_radius", 12.0))
				for e in game.enemies.list:
					if e.alive and not e.peaceful and World.dist(e.pos, b.center()) < r:
						e.slow_k = minf(e.slow_k, 1.0 - (1.0 - float(b.p("slow_k", 0.5))) * minf(1.0, game.factory.sat_c(b)))
			"repair":
				if not on or not rep:
					continue
				var r2 := float(b.p("repair_radius", 12.0))
				var amt: float = float(b.p("repair_rate", 20.0)) * b.mult * minf(1.0, game.factory.sat_c(b))
				var n := 0
				for o in game.factory.all:
					if o.dead or o.hp >= o.maxhp or World.dist(o.center(), b.center()) > r2:
						continue
					o.hp = minf(o.maxhp, o.hp + amt)
					game.factory._tint(o)
					n += 1
					if n <= 3:
						game.fx.tracer(b.center() + Vector3(0, 2.5, 0), o.center() + Vector3(0, 1, 0), Color(0.4, 1.0, 0.6), 0.25)


func _dome(b, s: Dictionary, show: bool, k: float) -> void:
	if s.node == null:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := float(b.p("barrier_radius", 10.0))
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 48
		sm.rings = 24
		mi.mesh = sm
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("color", DB.color(str(b.p("barrier_color", "#5fd0ff"))))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.add_child(mi)
		s.node = mi
	var node: MeshInstance3D = s.node
	node.visible = show
	node.position = b.center()
	var m := node.material_override as ShaderMaterial
	m.set_shader_parameter("strength", k)
	m.set_shader_parameter("flash", s.flash)


func info(b) -> String:
	match str(b.p("defense", "")):
		"barrier":
			var s := state(b)
			if s.down > 0.0:
				return "Щит пробит, восстановится через %d с" % int(s.down)
			return "Щит: %d / %d" % [int(s.hp), int(b.p("barrier_hp", 0))]
		"slow":
			return "Замедляет роботов в радиусе %d м" % int(b.p("slow_radius", 12))
		"repair":
			return "Чинит здания в радиусе %d м" % int(b.p("repair_radius", 12))
	return ""
