class_name Nuclear
extends RefCounted
## 14.22: АЭС (ядерный реактор). Игрок сам настраивает:
##  • сколько ТВЭЛов опущено в активную зону (загрузка 0..слотов),
##  • положение стержней управления (100% — полностью опущены, реактор заглушён),
##  • насосы охлаждения (сколько воды в секунду гонять через зону).
## Тепло = ТВЭЛы × (1 − стержни) × «тепло на ТВЭЛ». Охлаждение = вода × «охлаждение на воду» (чем горячее, тем лучше снимает).
## Энергия = снятое водой тепло (выше температуры пара). Если тепла больше, чем снимает вода, температура растёт:
## выше «критической» дольше «времени до аварии» или выше «расплавления» — взрыв: всё в радиусе разрушено, местность заражена.
## АЗ-5 — аварийная защита: стержни падают вниз. Правится: «Настройки → Реактор», здание «АЭС» (параметр reactor).

var f   # factory


func _init(fac) -> void:
	f = fac


static func cfg() -> Dictionary:
	return DB.setting("reactor", {})


static func c(k: String, def):
	return cfg().get(k, def)


static func is_reactor(b) -> bool:
	return b != null and bool(b.p("reactor", false))


## Состояние реактора (хранится в b.bstate — сохраняется вместе со зданием).
static func st(b) -> Dictionary:
	var s: Dictionary = b.bstate
	if not s.has("T"):
		s["T"] = 20.0          # температура зоны, °C
		s["rods"] = 1.0        # где стержни сейчас (1 — опущены полностью)
		s["rods_set"] = 1.0    # куда их двигать
		s["load"] = 0          # сколько ТВЭЛов опущено в зону
		s["pump"] = 1.0        # насосы 0..1
		s["water"] = 0.0       # вода в контуре
		s["burn"] = 0.0        # выгорание текущего ТВЭЛа, с
		s["crit"] = 0.0        # сколько секунд выше критической
		s["scram"] = false     # нажата АЗ-5
		s["auto"] = bool(c("auto_scram_default", false))
		s["out_pw"] = 0.0
		s["heat"] = 0.0
		s["cool"] = 0.0
	return s


static func slots(b) -> int:
	return int(b.p("fuel_slots", c("slots", 4)))


static func rods_in(b) -> int:
	return b.fuel.count(_fuel_id(b)) if b.fuel != null else 0


static func _fuel_id(b) -> String:
	var l = b.p("fuels", ["fuel_rod"])
	return str(l[0]) if l is Array and not l.is_empty() else "fuel_rod"


static func active_rods(b) -> int:
	return mini(int(st(b).load), rods_in(b))


static func water_buf() -> float:
	return float(c("water_buf", 60.0))


## Сколько воды реактор готов принять по трубам.
static func wants_water(b, id: String) -> int:
	if id != str(c("coolant", "water")):
		return 0
	return maxi(0, int(water_buf() - float(st(b).water)))


static func add_water(b, n: float) -> void:
	var s := st(b)
	s.water = minf(water_buf(), float(s.water) + n)


func setup(b) -> void:
	if b.out == null:
		b.out = Inventory.new(2)   # отработанные ТВЭЛы
	st(b)


## Шаг физики; возвращает, сколько энергии отдал реактор в сеть.
func power(b, dt: float, off: bool) -> float:
	var s := st(b)
	if b.out == null:
		setup(b)
	var T := float(s.T)
	# стержни едут к заданному положению (АЗ-5 — быстро вниз)
	var target := 1.0 if s.scram else float(s.rods_set)
	var sp := float(c("scram_speed", 60.0) if s.scram else c("rod_speed", 20.0)) / 100.0
	s.rods = move_toward(float(s.rods), target, sp * dt)
	var n := active_rods(b)
	var free := 1.0 - float(s.rods)
	var heat: float = n * free * float(c("heat_per_rod", 400.0)) * b.mult
	# охлаждение водой: чем горячее зона, тем больше тепла забирает вода (до «полного» перепада)
	var flow := float(s.pump) * float(c("max_flow", 5.0)) * dt
	var use := minf(flow, float(s.water))
	var k := clampf((T - 20.0) / maxf(1.0, float(c("cool_full_at", 150.0))), 0.0, 1.0)
	var cool := use / maxf(dt, 0.0001) * float(c("cool_per_water", 300.0)) * k
	s.water = float(s.water) - use * k
	var passive := float(c("passive", 0.5)) * (T - 20.0)
	T += (heat - cool - passive) * dt / maxf(1.0, float(c("heat_cap", 40.0)))
	T = maxf(20.0, T)
	s.T = T
	s.heat = heat
	s.cool = cool
	# выгорание ТВЭЛов → отработанные
	if n > 0 and free > 0.0:
		s.burn = float(s.burn) + n * free * dt
		var life := float(DB.item(_fuel_id(b)).get("fuel", c("rod_life", 600.0)))
		while float(s.burn) >= life and rods_in(b) > 0:
			s.burn = float(s.burn) - life
			b.fuel.remove(_fuel_id(b), 1)
			var w := str(c("waste", "nuclear_waste"))
			if w != "" and b.out.add(w, 1) > 0:
				f.game.notify_once("waste_full", "АЭС: выход отработанных ТВЭЛов полон — заберите их (хранилище отходов).", Color(1, 0.8, 0.3))
			if int(s.load) > rods_in(b):
				s.load = rods_in(b)
	# энергия: пар идёт в турбину, когда вода закипает
	var pw := 0.0
	if T >= float(c("steam_t", 100.0)) and not off:
		pw = minf(float(b.p("power", 1500)) * b.mult, cool * float(c("power_per_heat", 1.0)))
	pw *= Tuning.k(b, "supply") * Factory.clock(b)
	s.out_pw = pw
	var on := pw > 0.0
	if on != b.active:
		b.active = on
		f.renderer(b.type).set_active(b, 1.0 if on else 0.0)
	_safety(b, s, dt)
	return pw


func _safety(b, s: Dictionary, dt: float) -> void:
	var T := float(s.T)
	var crit := float(c("crit_t", 800.0))
	var warn := float(c("warn_t", 500.0))
	if bool(s.auto) and T >= warn and not s.scram:
		s.scram = true
		f.game.notify("АЭС: автоматическая защита сработала (%d°). Стержни опущены." % int(T), Color(1, 0.8, 0.3))
	if T >= crit:
		s.crit = float(s.crit) + dt
		f.game.notify_once("reactor_crit", "АЭС ПЕРЕГРЕВАЕТСЯ: %d°! Опустите стержни, добавьте воды или жмите АЗ-5!" % int(T), Color(1, 0.3, 0.2))
		if f.game.sfx and fmod(float(s.crit), 1.0) < dt:
			f.game.sfx.play("alarm", b.center())
	else:
		s.crit = maxf(0.0, float(s.crit) - dt * 0.5)
		if T >= warn:
			f.game.notify_once("reactor_warn", "АЭС горячая: %d°. Опустите стержни или усильте охлаждение." % int(T), Color(1, 0.75, 0.3))
	if T >= float(c("melt_t", 1100.0)) or float(s.crit) >= float(c("crit_time", 15.0)):
		meltdown(b)


## Авария: взрыв, разрушения вокруг, заражение местности.
func meltdown(b) -> void:
	if b.dead:
		return
	var g = f.game
	var p: Vector3 = b.center()
	var C := World.C
	var br := float(c("boom_radius", 14.0)) * C
	var hr := float(c("hurt_radius", 28.0)) * C
	var dmg := float(c("boom_damage", 400.0))
	g.fx.explosion(p + Vector3(0, 3, 0), 14.0, Color(1.0, 0.75, 0.3))
	g.fx.explosion(p + Vector3(0, 8, 0), 9.0, Color(0.6, 1.0, 0.4))
	if g.sfx:
		g.sfx.play("boom", p)
		g.sfx.play("thunder", p)
	if g.events:
		g.events.shake = maxf(g.events.shake, 3.0)
	f.remove(b)
	for o in f.all.duplicate():
		if o.dead or o == f.hq and not bool(c("boom_hq", false)):
			continue
		var d: float = World.dist(o.center(), p)
		if d <= br:
			f.damage(o, o.maxhp * 10.0)
		elif d <= hr:
			f.damage(o, dmg * (1.0 - (d - br) / maxf(1.0, hr - br)))
	# A-2 r11: все герои рядом (второй игрок сплитскрина, гости; на выделенном сервере — только гости)
	for pl in g.hit_targets():
		if pl == null or not is_instance_valid(pl) or ("alive" in pl and not pl.alive) or g.flags.get("god", false):
			continue
		var dp: float = World.dist(pl.position, p)
		if dp <= hr:
			pl.damage(dmg * clampf(1.2 - dp / hr, 0.1, 1.0))
	if g.enemies:
		for e in g.enemies.list.duplicate():
			if World.dist(g.enemies.pos_of(e), p) <= hr:
				g.enemies.hit(e, dmg * 3.0)
	if g.hazards:
		g.hazards.contaminate(p, float(c("zone_radius", 40.0)), float(c("zone_strength", 60.0)))
	g.notify("АВАРИЯ НА АЭС! Взрыв разрушил всё рядом, местность заражена радиацией. Защитный костюм, дезактивация.", Color(1, 0.3, 0.2))


## Окно: текст состояния.
static func info(b) -> String:
	var s := st(b)
	var T := float(s.T)
	var col := "#7dff7a" if T < float(c("warn_t", 500.0)) else ("#ffcc44" if T < float(c("crit_t", 800.0)) else "#ff5544")
	var t := "[color=%s]Температура: %d°[/color] (опасно с %d°, авария при %d°)\n" % [col, int(T), int(c("crit_t", 800.0)), int(c("melt_t", 1100.0))]
	t += "Тепло %d · охлаждение %d · энергия %d из %d\n" % [int(s.heat), int(s.cool), int(s.out_pw), int(b.p("power", 1500) * b.mult)]
	t += "ТВЭЛов внутри: %d, в зоне: %d · стержни опущены на %d%%\n" % [rods_in(b), active_rods(b), roundi(float(s.rods) * 100.0)]
	t += "Вода в контуре: %d / %d" % [int(s.water), int(water_buf())]
	if s.scram:
		t += "\n[color=#ff8844]АЗ-5: стержни сброшены. Нажмите «Снять АЗ», чтобы снова управлять.[/color]"
	if float(s.crit) > 0.0:
		t += "\n[color=#ff4433]КРИТИЧНО: до аварии %d с[/color]" % maxi(0, int(float(c("crit_time", 15.0)) - float(s.crit)))
	return t
