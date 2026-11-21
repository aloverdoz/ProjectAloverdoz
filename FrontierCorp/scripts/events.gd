extends RefCounted
## События мира и загрязнение.
## События — тип данных «events» (в редакторе «События мира»): метеоритный дождь, буря, нашествие, свои.
## Каждый новый день игра бросает кубик для каждого события (шанс в день, не раньше дня N).
## Загрязнение — сумма «загрязнения» работающих зданий; чем оно выше, тем больше монстров в волне.

const KINDS := {"meteor": "Метеоритный дождь", "storm": "Буря", "invasion": "Нашествие", "visit": "Приход НПС",
	"flare": "Солнечный выброс", "horde": "Рёв матери (толпа на героя)", "worms": "Дрожь земли (черви)", "quake": "Землетрясение",
	"weather": "Погода (дождь, мороз, зной, затмение, туман)", "pests": "Вредители (едят еду на складах)", "capsule": "Падение капсулы с добычей",
	"vein": "Новая богатая жила", "custom": "Своё (только действия)"}

var game
var active := {}          # id события -> сколько секунд осталось
var last_day := 0
var storm := 0.0          # 0..1, сила бури сейчас (плавно)
var storm_target := 0.0
var pollution := 0.0      # уровень загрязнения (плавно идёт к сумме зданий)
var pollution_src := 0.0  # сумма по зданиям сейчас
var _acc := 0.0
var _meteor_left := 0
var _meteor_t := 0.0
var _meteor_at := Vector3.ZERO
var _met_t := -1.0         # 1.1.15: до следующего одиночного метеорита (раз в ~5 минут)
# опасные события (14.3): укрытия, щиты, тряска, цвет неба
var shelters: Array = []  # [центр, радиус в м, здание, щит?]
var shake := 0.0          # сила тряски камеры сейчас
var tint := Color(0, 0, 0, 0)   # цвет неба события, a — сила
var heat := 0.0           # 0..1 — сила опасного события сейчас (для вида)
var spawned := {}         # id события -> монстры, которых оно привело
var _fx_acc := 0.0
var domes := {}
var _warn_t := 0.0
var pending := {}   # 13.10: событие объявлено зловещей надписью и начнётся через N секунд
var _veil: ColorRect = null           # щит -> MeshInstance3D купола
## Погода событий (плавно): дождь, темнота затмения, густой туман, снег мороза
var rain := 0.0
var dark := 0.0
var fog := 0.0
var snow := 0.0
var rain_col := Color(0.7, 0.8, 1.0)
var _rain: CPUParticles3D = null
var eaten := 0            # сколько еды съели вредители (для подсказки и проверки)
var capsules: Array = []  # [здание, метка на карте]


func _init(g) -> void:
	game = g


static func list() -> Dictionary:
	return DB.data.get("events", {})


func update(delta: float) -> void:
	storm = move_toward(storm, storm_target, delta * 0.08)
	_update_visuals(delta)
	if _meteor_left > 0:
		_meteor_t -= delta
		if _meteor_t <= 0.0:
			_meteor_t = randf_range(0.6, 1.6)
			_meteor_left -= 1
			_drop_meteor()
	_acc += delta
	if _acc < 1.0:
		return
	var dt := _acc
	_acc = 0.0
	# у подключившегося события начинает и заканчивает хозяин
	if Net.is_client():
		_update_pollution(dt)
		_hazards(dt, true)
		for id in active.keys():
			active[id] -= dt
			if active[id] <= 0.0:
				finish(id)   # 1.1.15: у гостя тоже по-настоящему (раньше буря иногда не кончалась: небо оставалось тёмным)
				active.erase(id)
		return
	for id in active.keys():
		active[id] -= dt
		if active[id] <= 0.0:
			finish(id)
	_lone_meteor(dt)
	for id in pending.keys():
		pending[id] -= dt
		if pending[id] <= 0.0:
			pending.erase(id)
			start(id, true)
	if game.module("events") and game.day_n != last_day:
		last_day = game.day_n
		_roll_day()
	_update_pollution(dt)
	_hazards(dt, false)


func _roll_day() -> void:
	for id in list():
		var e: Dictionary = list()[id]
		if active.has(id) or pending.has(id) or game.day_n < int(e.get("min_day", 1)):
			continue
		var ch := float(e.get("chance", 0.0))
		# отношение группы: друзья заходят чаще, враги чаще нападают
		if str(e.get("kind", "")) == "visit" and game.npcs:
			if not game.module("npcs"):
				continue
			var nd: Dictionary = DB.data.enemies.get(str(e.get("npc", "")), {})
			var r: int = game.npcs.rep_of(str(nd.get("faction", "")))
			ch *= (1.0 + maxf(0.0, -r) / 50.0) if str(nd.get("behavior", "")) == "bandit" else (1.0 + maxf(0.0, r) / 100.0)
		if randf() < ch:
			# сначала зловещая надпись, само событие — через «Предупреждение: за сколько секунд»
			var lead := float(e.get("omen_lead", 0.0))
			if str(e.get("omen", "")) != "" and lead > 0.0:
				show_omen(id)
				pending[id] = lead
			else:
				start(id)


## Зловещая надпись события (поля «Предупреждение» в редакторе).
func show_omen(id: String) -> void:
	var e: Dictionary = list().get(id, {})
	var t := str(e.get("omen", ""))
	if t == "" or game.hud == null:
		return
	game.hud.omen(DB.tx(t, t) if t.begins_with("@") else t, DB.color(e.get("omen_color", e.get("color", "#ff5040"))),
		float(e.get("omen_time", 5.0)), str(e.get("omen_sound", "omen")))


## Запустить событие (кубик, консоль «event id», действие «event»). omened — надпись уже показана заранее.
func start(id: String, omened := false) -> bool:
	var e: Dictionary = list().get(id, {})
	if e.is_empty():
		return false
	if not omened:
		show_omen(id)
	active[id] = maxf(1.0, float(e.get("duration", 60)))
	if Net.is_host():
		Net._self().event_started(id)
	var txt := str(e.get("text", ""))
	if txt == "":
		txt = str(e.get("name", id))
	game.notify(DB.tx(txt, txt) if txt.begins_with("@") else txt, DB.color(e.get("color", "#ffb050")))
	if id == "meteor_shower" and game.has_method("quip"):
		game.quip("meteor")
	var pw := float(e.get("power", 1.0))
	match str(e.get("kind", "custom")):
		"storm":
			storm_target = clampf(pw, 0.0, 1.0)
			game.add_effect("move", -0.15 * clampf(pw, 0.0, 1.0), active[id], str(e.get("name", "Буря")))
		"invasion":
			if game.factory.hq != null:
				game.enemies.start_wave(maxf(1.0, pw))
		"visit":
			if game.npcs and game.module("npcs"):
				game.npcs.spawn_visit(str(e.get("npc", "")), maxi(1, int(pw)))
		"meteor":
			_meteor_left = maxi(1, int(pw))
			_meteor_t = 1.5
			_meteor_at = _someone_pos()   # 1.1.15: на сервере — у живого игрока, а не у невидимого героя сервера
		"horde":
			_spawn_horde(id, e, maxi(1, int(pw)))
		"worms":
			_spawn_worms(id, e, maxi(1, int(pw)))
		"quake":
			_quake(e)
		"pests":
			_spawn_pests(id, e, maxi(1, int(pw)))
		"capsule":
			_drop_capsule(id, e, maxi(0, int(pw)))
		"vein":
			_make_vein(e, maxi(1, int(pw)))
	var acts: Array = e.get("actions", [])
	if not acts.is_empty() and game.console:
		var c: Vector2i = World.world_to_cell(_someone_pos())   # 1.1.15: на сервере — у живого игрока
		game.console.run_actions(acts, {"x": c.x, "z": c.y})
	return true


## У подключившегося: событие идёт у хозяина — показать сообщение и бурю, без метеоритов и нашествий.
func start_visual(id: String) -> void:
	var e: Dictionary = list().get(id, {})
	if e.is_empty():
		return
	active[id] = maxf(1.0, float(e.get("duration", 60)))
	show_omen(id)
	var txt := str(e.get("text", ""))
	if txt == "":
		txt = str(e.get("name", id))
	game.notify(DB.tx(txt, txt) if txt.begins_with("@") else txt, DB.color(e.get("color", "#ffb050")))
	if str(e.get("kind", "")) == "storm":
		storm_target = clampf(float(e.get("power", 1.0)), 0.0, 1.0)
	if str(e.get("kind", "")) == "quake":
		shake = maxf(shake, float(e.get("shake", 1.0)))


func finish(id: String) -> void:
	active.erase(id)
	var e: Dictionary = list().get(id, {})
	# черви уходят под землю и пропадают, толпа остаётся драться
	for m in spawned.get(id, []):
		if m.alive and m.burrow and game.enemies:
			m.no_loot = true
			game.enemies.vanish(m)
	spawned.erase(id)
	if not _any("stop_machines") and game.factory:
		for b in game.factory.machines:
			b.ev_halt = false   # машины снова работают
	if str(e.get("kind", "")) == "storm":
		storm_target = 0.0
	var et := str(e.get("end_text", ""))
	if et != "":
		game.notify(et, Color(0.7, 0.9, 1.0))


## 1.1.15: одиночный метеорит раз в ~5 минут (настройка meteor115) рядом со случайным игроком — раньше они
## падали только во время редкого «Метеоритного дождя» (7.5% в день), и игроки их почти не видели.
func _lone_meteor(dt: float) -> void:
	var c: Dictionary = DB.setting("meteor115", {})
	if not bool(c.get("enabled", true)) or not game.module("events"):   # A-1 r11: модуль «События мира» выключен
		return
	var every := maxf(30.0, float(c.get("every", 300.0)))
	if _met_t < 0.0:
		_met_t = every * randf_range(0.8, 1.2)
	_met_t -= dt
	if _met_t > 0.0:
		return
	_met_t = every * randf_range(0.8, 1.2)
	var at := _someone_pos()
	var n := randi_range(int(c.get("min", 1)), int(c.get("max", 2)))
	var landed := 0
	for i in n:
		landed += 1 if _drop_meteor(at) else 0
	if landed > 0:
		game.notify(str(c.get("text", "С неба упал метеорит — в нём руда и кристаллы!")), Color(1.0, 0.65, 0.3))


## Где игрок: свой герой или (на сервере) случайный из подключённых.
func _someone_pos() -> Vector3:
	var list := []
	if game.player != null and game.player.alive and game.player.visible:
		list.append(game.player.position)
	if Net.active():
		for id in Net._self().puppets:
			var pp = Net._self().puppets[id]
			if is_instance_valid(pp):
				list.append(pp.position)
	if list.is_empty():
		return game.factory.hq.center() if game.factory.hq != null else game.player.position
	return list[randi() % list.size()]


## Метеорит падает рядом с героем: вспышка, грохот и камень с рудой.
func _drop_meteor(around = null) -> bool:
	var base: Vector3 = around if around is Vector3 else _meteor_at
	var cell := Vector2i(-1, -1)
	var w = game.world
	var f = game.factory
	for t in 30:
		# 1.1.15: не в воду, не на фундамент и не под навес штаба
		var ang := randf() * TAU
		var d := randf_range(10.0, 26.0) * World.C
		var c: Vector2i = World.world_to_cell(base + Vector3(cos(ang), 0, sin(ang)) * d)
		if w.in_bounds(c) and not w.water_at(c) and not f.found.has(c) and not f.grid.has(c) and not w.nodes.has(c) \
				and not ("canopy_cells" in f and f.canopy_cells.has(c)) and (game.zone == null or game.zone.inside_cell(c)):
			cell = c
			break
	if cell.x < 0:
		return false
	if Net.is_host():
		Net._self().meteor(cell)   # 1.1.15: у гостей тоже — вспышка и камень (раньше камень был только у хозяина)
	meteor_land(cell)
	return true


func meteor_land(cell: Vector2i) -> void:
	var res := "meteorite"
	if not DB.data.resources.has(res):
		return
	var at := World.cell_to_world(cell)
	at.y = game.world.height_at(at)
	game.fx.explosion(at + Vector3(0, 1, 0), 1.6, Color(1.0, 0.5, 0.2))
	game.fx.dirt(at, 1.5)
	game.sfx.play("boom", at)
	for en in game.enemies.list.duplicate():
		if World.dist(en.pos, at) < 4.0 * World.C:
			game.enemies.hit(en, 80.0)
	for pl in (game.split.local_players() if game.get("split") != null else [game.player]):   # A-7 r5: оба героя сплитскрина
		if pl != null and World.dist(pl.position, at) < 2.0 * World.C:
			pl.damage(15.0)
	if game.world.nodes.has(cell) or game.factory.building_at(cell) != null:
		return
	game.world.add_node(res, cell)


# ---------------------------------------------------------------- опасные события (14.3)

## Значение поля события, которое уже действует (прошла «Задержка»). Для чисел — сумма, для флагов — любое.
func _sec_in(id: String) -> float:
	var e: Dictionary = list().get(id, {})
	return float(e.get("duration", 60)) - float(active.get(id, 0.0))


func _live(id: String) -> bool:
	return _sec_in(id) >= float(list().get(id, {}).get("delay", 0.0))


func _sum(key: String) -> float:
	var t := 0.0
	for id in active:
		if _live(id):
			t += float(list().get(id, {}).get(key, 0.0))
	return t


func _any(key: String) -> bool:
	for id in active:
		if _live(id) and bool(list().get(id, {}).get(key, false)):
			return true
	return false


## С монстров сейчас не падает добыча (солнечный выброс).
func no_loot() -> bool:
	return _any("no_loot")


## Укрытия и щиты: здания с «Укрытие: радиус» и «Щит: радиус» (щит работает, пока есть энергия).
func _collect_shelters() -> void:
	shelters.clear()
	var f = game.factory
	for b in f.all:
		var sr := float(b.p("shelter_radius", 0))
		var hr := float(b.p("shield_radius", 0))
		if sr > 0.0:
			shelters.append([b.center(), sr * World.C, b, false])
		if hr > 0.0 and f.shield_on(b):
			shelters.append([b.center(), hr * World.C, b, true])
	if f.canopy_on():   # 1.3: навес у штаба
		shelters.append([f.canopy_center, float(DB.setting("hq_canopy_radius", 2.1)), f.hq, false])


## Точка под защитой укрытия или щита. buildings — считать только щиты (укрытие защищает людей, а не завод).
func protected(p: Vector3, buildings := false) -> bool:
	for s in shelters:
		if buildings and not s[3]:
			continue
		if World.dist(p, s[0]) <= s[1]:
			return true
	return false


## Раз в секунду: жара снаружи, урон зданиям, остановка машин.
func _hazards(dt: float, client: bool) -> void:
	_collect_shelters()
	var dps := _sum("outdoor_dps")
	var stop := _any("stop_machines")
	var f = game.factory
	if not client:
		var bd := 0.0
		for id in active:
			if _live(id):
				var e: Dictionary = list()[id]
				var span := maxf(1.0, float(e.get("duration", 60)) - float(e.get("delay", 0.0)))
				bd += float(e.get("building_dmg", 0.0)) / span
		for b in f.machines:
			var h: bool = stop and not protected(b.center(), true)
			if h != b.ev_halt:
				b.ev_halt = h
		if bd > 0.0:
			for b in f.all.duplicate():
				if b.dead or b == f.hq or float(b.p("shelter_radius", 0)) > 0.0 or float(b.p("shield_radius", 0)) > 0.0:
					continue
				if protected(b.center(), true):
					continue
				# частичный урон: здание не рушится, остаётся хотя бы 10% прочности
				var amt: float = minf(b.maxhp * bd * dt, b.hp - b.maxhp * 0.1)
				if amt > 0.0:
					f.damage(b, amt)
		if dps > 0.0 and game.enemies:
			for m in game.enemies.list.duplicate():
				if m.alive and m.under < 0.5 and not protected(m.pos):
					m.no_loot = true
					game.enemies.hit(m, dps * dt)
	elif stop:
		pass   # у подключившегося машины выравнивает хозяин
	var sp = game.get("split")
	if sp != null and sp.running():
		for si in 2:
			sp.with_seat(si, _outdoor_hit.bind(dps, dt))
	else:
		_outdoor_hit(dps, dt)
	if not stop:
		for b in f.machines:
			if b.ev_halt:
				b.ev_halt = false
	if not client:
		_pests(dt)
	_check_capsules()   # 1.1.15: и у гостей — метки пустых капсул пропадают


## Защитный предмет от события: поле предмета «Защищает от событий» (id) и «Защита снаружи 0..1».
## Пока защищает — теряет прочность (1 в секунду × «Износ от защиты»). Возвращает долю снятого урона.
func _guard(ev_id: String, dt: float) -> float:
	var inv = game.player.inv
	for i in inv.slots.size():
		var s = inv.slots[i]
		if s == null:
			continue
		var it := DB.item(str(s.id))
		var evs: Array = it.get("guard_events", [])
		var k := clampf(float(it.get("outdoor_guard", 0.0)), 0.0, 1.0)
		if k <= 0.0 or (not evs.is_empty() and not ev_id in evs):
			continue
		var maxd := float(it.get("durability", 0))
		if maxd > 0.0 and game.module("durability") and not bool(game.get("strategy")):   # A17-1: без модуля «Прочность» (и в «Стратегии») не изнашивается
			s["dur"] = float(s.get("dur", maxd)) - dt * float(it.get("guard_wear", 1.0))
			if float(s.dur) <= 0.0:
				inv.slots[i] = null
				game.notify("%s сломался!" % DB.item_name(str(s.id)), Color(1, 0.6, 0.3))
				game.sfx.play_ui("click")
			inv.changed.emit()
		return k
	return 0.0


## Зонтик над головой героя, пока он защищает.
var _guard_node: Node3D
func _show_guard(on: bool) -> void:
	var pl = game.player
	if pl == null:
		return
	if on and _guard_node == null:
		var mid := "m_umbrella"
		for s in pl.inv.slots:
			if s != null and float(DB.item(str(s.id)).get("outdoor_guard", 0.0)) > 0.0:
				mid = str(DB.item(str(s.id)).get("guard_model", mid))
				break
		if DB.data.models.has(mid):
			_guard_node = ModelLib.make_node(mid)
			pl.add_child(_guard_node)
			_guard_node.position = Vector3(0.15, 0.0, 0.0)
	if _guard_node:
		_guard_node.visible = on
		if not on:
			_guard_node.queue_free()
			_guard_node = null


## «Рёв матери»: толпа разных монстров с нескольких сторон идёт прямо на героя.
func _spawn_horde(id: String, e: Dictionary, n: int) -> void:
	var types: Array = e.get("monsters", [])
	if types.is_empty():
		types = ["crawler"]
	var dist := float(e.get("spawn_dist", 40.0))
	var sides := randi_range(2, 3)
	var base_ang := randf() * TAU
	var got := []
	# «Идут на базу» — вторжение к штабу, иначе толпа идёт на героя
	var to_base: bool = bool(e.get("go_base", false)) and game.factory.hq != null
	var from: Vector3 = game.factory.hq.center() if to_base else _someone_pos()
	for i in n:
		var ang := base_ang + float(i % sides) / sides * TAU + randf_range(-0.3, 0.3)
		var p: Vector3 = from + Vector3(cos(ang), 0, sin(ang)) * (dist + randf_range(-4.0, 6.0))
		var m = game.enemies.spawn(str(types[randi() % types.size()]), p)
		if m:
			if to_base:
				m.target = game.factory.hq
			else:
				m.hunt = true
			got.append(m)
	spawned[id] = got
	shake = maxf(shake, float(e.get("shake", 0.0)))


## «Дрожь земли»: черви вылезают под зданиями базы (или рядом с героем) — ломают и кусают.
func _spawn_worms(id: String, e: Dictionary, n: int) -> void:
	var types: Array = e.get("monsters", [])
	if types.is_empty():
		types = ["worm"]
	var f = game.factory
	var dist := float(e.get("spawn_dist", 20.0))
	var got := []
	for i in n:
		var at: Vector3 = _someone_pos()
		if not f.all.is_empty() and randf() < 0.7:
			at = f.all[randi() % f.all.size()].center()
		var ang := randf() * TAU
		var m = game.enemies.spawn(str(types[randi() % types.size()]), at + Vector3(cos(ang), 0, sin(ang)) * dist * randf_range(0.6, 1.0))
		if m:
			m.burrow = true
			m.under = 1.0
			got.append(m)
	spawned[id] = got
	shake = maxf(shake, float(e.get("shake", 0.4)))


## Землетрясение: все здания сразу теряют долю прочности (на фундаменте — меньше), сильная тряска.
func _quake(e: Dictionary) -> void:
	var f = game.factory
	var k := float(e.get("quake_dmg", 0.5))
	var kf := float(e.get("quake_found_mult", 0.5))
	var can_kill := bool(e.get("quake_kill", false))
	shake = maxf(shake, float(e.get("shake", 1.0)))
	var n := 0
	for b in f.all.duplicate():
		if b.dead or b.beh == "foundation":
			continue
		var on_found: bool = f.found_top(b.cell) != null
		var amt: float = b.maxhp * k * (kf if on_found else 1.0)
		if not can_kill:
			amt = minf(amt, b.hp - 1.0)
		if amt > 0.0:
			f.damage(b, amt)
			n += 1
			if n % 7 == 0:
				game.fx.dirt(b.center(), 1.2)


## Вид: тряска камеры, цвет неба, купола щитов.
func _update_visuals(delta: float) -> void:
	var want := Color(0, 0, 0, 0)
	var hz := 0.0
	var sh := 0.0
	for id in active:
		var e: Dictionary = list().get(id, {})
		var k := 1.0 if _live(id) else clampf(_sec_in(id) / maxf(0.1, float(e.get("delay", 0.0))), 0.0, 1.0) * 0.5
		var sky := str(e.get("sky_color", ""))
		if sky != "":
			var c := DB.color(sky)
			want = Color(c.r, c.g, c.b, maxf(want.a, float(e.get("sky_power", 0.6)) * k))
		if float(e.get("outdoor_dps", 0.0)) > 0.0 or bool(e.get("stop_machines", false)):
			hz = maxf(hz, k)
		if str(e.get("kind", "")) in ["quake", "worms"]:
			sh = maxf(sh, float(e.get("shake", 0.5)) * (0.35 if str(e.get("kind", "")) == "worms" else 0.6))
	var w_rain := 0.0
	var w_dark := 0.0
	var w_fog := 0.0
	var w_snow := 0.0
	for id in active:
		var e2: Dictionary = list().get(id, {})
		var k2 := 1.0 if _live(id) else 0.3
		w_rain = maxf(w_rain, float(e2.get("rain", 0.0)) * k2)
		w_dark = maxf(w_dark, float(e2.get("dark", 0.0)) * k2)
		w_fog = maxf(w_fog, float(e2.get("fog", 0.0)) * k2)
		w_snow = maxf(w_snow, float(e2.get("snow", 0.0)) * k2)
		if float(e2.get("rain", 0.0)) > 0.0:
			rain_col = DB.color(str(e2.get("rain_color", "#a8c8ff")))
	rain = move_toward(rain, w_rain, delta * 0.3)
	dark = move_toward(dark, w_dark, delta * 0.15)
	fog = move_toward(fog, w_fog, delta * 0.12)
	snow = move_toward(snow, w_snow, delta * 0.05)
	_update_rain()
	tint = tint.lerp(want if want.a > 0.0 else Color(tint.r, tint.g, tint.b, 0.0), minf(1.0, delta * 0.8))
	heat = move_toward(heat, hz, delta * 0.5)
	# жаркое марево поверх экрана: снаружи сильнее, в укрытии слабее
	var veil := heat * (0.06 if protected(game.player.position) else 0.2) * tint.a / maxf(0.01, want.a if want.a > 0.0 else tint.a)
	if veil > 0.002 and _veil == null:
		var cl := CanvasLayer.new()
		cl.layer = 0
		_veil = ColorRect.new()
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		cl.add_child(_veil)
		game.add_child(cl)
	if _veil != null:
		_veil.visible = veil > 0.002
		_veil.color = Color(tint.r, tint.g * 0.85, tint.b * 0.6, clampf(veil, 0.0, 0.35))
	shake = move_toward(shake, sh, delta * 0.7)
	_fx_acc += delta
	if _fx_acc >= 0.5:
		_fx_acc = 0.0
		_update_domes()
	for b in domes:
		var mi: MeshInstance3D = domes[b]
		var t := Time.get_ticks_msec() * 0.001
		var mat: StandardMaterial3D = mi.material_override
		mat.albedo_color.a = (0.06 + heat * 0.12) * (0.85 + sin(t * 2.0 + b.cell.x) * 0.15)
		mat.emission_energy_multiplier = 0.6 + heat * 2.5


## Купола над работающими щитами: прозрачная полусфера радиуса щита.
func _update_domes() -> void:
	var f = game.factory
	var live := {}
	for b in f.all:
		var r := float(b.p("shield_radius", 0))
		if r <= 0.0 or not f.shield_on(b):
			continue
		live[b] = true
		if not domes.has(b):
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = r * World.C
			sm.height = r * World.C * 2.0
			sm.is_hemisphere = true
			sm.radial_segments = 48
			sm.rings = 16
			mi.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var col := DB.color(str(b.p("shield_color", "#5fd0ff")))
			mat.albedo_color = Color(col.r, col.g, col.b, 0.12)
			mat.emission_enabled = true
			mat.emission = col
			mat.rim_enabled = true
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			game.add_child(mi)
			domes[b] = mi
		domes[b].position = b.center()
	for b in domes.keys():
		if not live.has(b):
			domes[b].queue_free()
			domes.erase(b)


# ---------------------------------------------------------------- загрязнение

## Сколько загрязняет здание: «загрязнение» в параметрах, иначе по виду (генераторы на топливе, буры, печи).
static func building_pollution(type: String) -> float:
	var d := DB.building(type)
	var p: Dictionary = d.get("params", {})
	if p.has("pollution"):
		return float(p.pollution)
	match str(d.get("behavior", "")):
		"generator":
			return 0.0 if p.get("solar", false) or p.get("wind", false) or p.get("water", false) else 3.0
		"miner":
			return 1.0
		"crafter":
			return 1.5 if p.get("fuel", false) else 0.5
	return 0.0


func _update_pollution(dt: float) -> void:
	if not game.module("pollution"):
		pollution = 0.0
		pollution_src = 0.0
		return
	var s := 0.0
	for b in game.factory.all:
		if b.active:
			s += building_pollution(b.type)
	pollution_src = s
	# растёт за минуты, спадает ещё медленнее
	var k := 0.02 if s > pollution else 0.005
	pollution = lerpf(pollution, s, clampf(dt * k, 0.0, 1.0))


## Во сколько раз больше монстров из-за загрязнения.
func wave_mult() -> float:
	if not game.module("pollution"):
		return 1.0
	var cap := float(DB.setting("pollution_cap", 300.0))
	return 1.0 + minf(pollution, cap) * float(DB.setting("pollution_k", 0.004))


func status_text() -> String:
	var parts := []
	for id in active:
		parts.append("%s %d с" % [list().get(id, {}).get("name", id), int(active[id])])
	if game.module("pollution") and pollution >= 1.0:
		parts.append("загрязнение %d (монстров ×%.2f)" % [int(pollution), wave_mult()])
	return " · ".join(parts)


## Сколько градусов добавляют события (мороз −, зной +).
func temp_add() -> float:
	return _sum("temp_add")


## Жажда × (засуха и зной).
func thirst_mult() -> float:
	if game.player != null and protected(game.player.position):
		return 1.0   # 1.1.15: в укрытии зной не сушит
	return 1.0 + _sum("thirst_add")


## Дождь (кислотный или обычный): капли вокруг героя.
func _update_rain() -> void:
	if rain <= 0.01:
		if _rain:
			_rain.emitting = false
		return
	if _rain == null:
		_rain = CPUParticles3D.new()
		_rain.amount = 1600
		_rain.lifetime = 1.0
		_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_rain.emission_box_extents = Vector3(28, 0.5, 28)
		_rain.direction = Vector3(0.15, -1, 0)
		_rain.spread = 3.0
		_rain.gravity = Vector3(0, -40, 0)
		_rain.initial_velocity_min = 22.0
		_rain.initial_velocity_max = 28.0
		_rain.local_coords = false
		var qm := QuadMesh.new()
		qm.size = Vector2(0.04, 0.7)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.vertex_color_use_as_albedo = true
		qm.material = mat
		_rain.mesh = qm
		game.add_child(_rain)
	_rain.emitting = true
	_rain.color = Color(rain_col.r, rain_col.g, rain_col.b, 0.55 * clampf(rain, 0.0, 1.0))
	_rain.position = game.player.position + Vector3(0, 18, 0)


## Вредители: насекомые идут к складам с едой и съедают её.
func _spawn_pests(id: String, e: Dictionary, n: int) -> void:
	var types: Array = e.get("monsters", [])
	if types.is_empty():
		types = ["drone"]
	var f = game.factory
	var center: Vector3 = f.hq.center() if f.hq else game.player.position
	var dist := float(e.get("spawn_dist", 40.0))
	var ang := randf() * TAU
	var got := []
	for i in n:
		var a := ang + randf_range(-0.5, 0.5)
		var m = game.enemies.spawn(str(types[randi() % types.size()]), center + Vector3(cos(a), 0, sin(a)) * (dist + randf_range(-5, 5)))
		if m:
			m.set_meta("pest", true)
			got.append(m)
	spawned[id] = got


static func _is_food(id: String) -> bool:
	var it: Dictionary = DB.item(id)
	return str(it.get("category", "")) == "Еда" or float(it.get("food", 0)) > 0.0


func _food_store(p: Vector3):
	var best = null
	var bd := 120.0
	for b in game.factory.all:
		if b.dead or b.inv == null or b.p("wild", false):
			continue
		var has := false
		for sl in b.inv.slots:
			if sl != null and _is_food(str(sl.id)):
				has = true
				break
		if not has:
			continue
		var d := World.dist(p, b.center())
		if d < bd:
			bd = d
			best = b
	return best


func _pests(dt: float) -> void:
	for id in spawned:
		for m in spawned[id]:
			if not m.alive or not m.has_meta("pest"):
				continue
			var b = m.target if (m.target != null and m.target != game.player and "inv" in m.target and m.target.inv != null and not m.target.dead) else _food_store(m.pos)
			if b == null:
				continue
			m.target = b
			if World.dist(m.pos, b.center()) <= b.size * World.C * 0.7 + 2.5:
				for sl in b.inv.slots:
					if sl != null and _is_food(str(sl.id)):
						var fid := str(sl.id)
						b.inv.remove(fid, 1)
						eaten += 1
						if eaten == 1 or eaten % 20 == 0:
							game.notify("Вредители едят запасы еды на складе!", Color(1, 0.7, 0.3))
						break


## Капсула падает недалеко от героя: в ней добыча, рядом может быть охрана. Отмечена на карте.
func _drop_capsule(id: String, e: Dictionary, guards: int) -> void:
	var f = game.factory
	var bt := str(e.get("capsule", "supply_capsule"))
	if not DB.data.buildings.has(bt):
		return
	var pp: Vector3 = _someone_pos()   # 1.1.15: на сервере — у игроков
	var dist := float(e.get("spawn_dist", 35.0))
	var cell := Vector2i(-99999, 0)
	for t in 60:
		var a := randf() * TAU
		var c := World.wc(World.world_to_cell(pp + Vector3(cos(a), 0, sin(a)) * dist * randf_range(0.7, 1.3)))
		# 1.1.15: место без камней и деревьев (раньше их убирали только у хозяина — у гостя капсула не вставала)
		if game.world.nodes.has(c):
			continue
		if f.can_place(bt, c) == "" or (game.flags.get("free_build", false) and not f.grid.has(c) and not game.world.water_at(c)):
			cell = c
			break
	if cell.x == -99999:
		return
	var was: bool = game.flags.get("free_build", false)
	game.flags["free_build"] = true
	var b = game.cmd("place", {"type": bt, "cell": cell, "dir": randi() % 4, "owner": ""}) if Net.active() else f.place(bt, cell, randi() % 4)   # 1.1.15: гостям тоже
	game.flags["free_build"] = was
	if b == null:
		return
	if b.inv:
		for l in e.get("loot", []):
			if randf() <= float(l.get("chance", 1.0)) and DB.data.items.has(str(l.get("item", ""))):
				b.inv.add(str(l.item), randi_range(int(l.get("min", 1)), int(l.get("max", 1))))
	var wp: Vector3 = b.center()
	game.fx.magic(wp + Vector3(0, 2, 0), Color(1.0, 0.7, 0.3), 2.0)
	game.fx.dirt(wp, 1.5)
	shake = maxf(shake, 0.4)
	var mk := {"x": snappedf(wp.x, 0.1), "z": snappedf(wp.z, 0.1), "name": str(e.get("name", "Капсула")), "color": "#ffb040", "auto": true}
	game.marks.append(mk)
	capsules.append([b, mk])
	if Net.is_host():
		Net._self().nodes_added("", [], mk)   # 1.1.15: метка капсулы — и гостям
	var types: Array = e.get("monsters", [])
	var got := []
	for i in guards:
		if types.is_empty():
			break
		var a := randf() * TAU
		var m = game.enemies.spawn(str(types[randi() % types.size()]), wp + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 7.0), true)
		if m:
			m.home = wp
			got.append(m)
	spawned[id] = got


## Капсулу опустошили — метка с карты убирается.
func _check_capsules() -> void:
	for c in capsules.duplicate():
		var b = c[0]
		if b.dead or b.inv == null or b.inv.first_item() == "":
			game.marks.erase(c[1])
			capsules.erase(c)
	# 1.1.15: метки капсул после загрузки (список капсул не сохраняется) и у гостей — убрать, когда капсула пуста или пропала
	for mk in game.marks.duplicate():
		if not (mk is Dictionary and mk.get("auto", false) and str(mk.get("color", "")) == "#ffb040"):
			continue
		var tracked := false
		for c in capsules:
			tracked = tracked or c[1] == mk
		if tracked:
			continue
		var b2 = game.factory.building_at(World.world_to_cell(Vector3(float(mk.get("x", 0)), 0, float(mk.get("z", 0)))))
		if b2 == null or b2.dead or b2.inv == null or b2.inv.first_item() == "":
			game.marks.erase(mk)
	# A-5 r6: богатую жилу выкопали — метка уходит
	for mk in game.marks.duplicate():
		if not (mk is Dictionary and mk.get("auto", false) and mk.get("cells") is Array):
			continue
		var left := false
		for q in mk.cells:
			if game.world.nodes.has(Vector2i(int(q[0]), int(q[1]))):
				left = true
				break
		if not left:
			game.marks.erase(mk)


## Богатая жила: рядом с героем появляется россыпь руды. Отмечена на карте.
func _make_vein(e: Dictionary, n: int) -> void:
	var ress: Array = e.get("resources", [])
	ress = ress.filter(func(r): return DB.data.resources.has(str(r)))
	if ress.is_empty():
		return
	var res := str(ress[randi() % ress.size()])
	var pp: Vector3 = _someone_pos()
	var dist := float(e.get("spawn_dist", 30.0))
	for t in 40:
		var a := randf() * TAU
		var c0 := World.wc(World.world_to_cell(pp + Vector3(cos(a), 0, sin(a)) * dist * randf_range(0.7, 1.3)))
		var made := 0
		var cells := []
		for r in range(0, 4):
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if made >= n or maxi(absi(dx), absi(dz)) != r:
						continue
					var c := World.wc(c0 + Vector2i(dx, dz))
					if game.world.water_at(c) or game.factory.grid.has(c) or game.world.nodes.has(c) or game.world.nest_cells.has(c) \
							or (game.zone != null and not game.zone.inside_cell(c)):
						continue
					if game.world.add_node(res, c) != null:
						made += 1
						cells.append([c.x, c.y])
		if made >= maxi(1, n / 2):
			var wp: Vector3 = World.cell_to_world(c0)
			var vm := {"x": snappedf(wp.x, 0.1), "z": snappedf(wp.z, 0.1), "name": "Жила: %s" % str(DB.data.resources[res].get("name", res)), "color": "#40e0a0", "auto": true, "cells": cells}   # A-5 r6: клетки — чтобы снять метку
			game.marks.append(vm)
			game.fx.dirt(wp, 1.5)
			if Net.is_host():
				Net._self().nodes_added(res, cells, vm)   # 1.1.15: гости тоже видят жилу
			return
		elif made > 0 and Net.is_host():
			Net._self().nodes_added(res, cells, {})


func to_dict() -> Dictionary:
	return {"active": active.duplicate(), "pending": pending.duplicate(), "last_day": last_day, "storm": storm, "storm_target": storm_target, "pollution": pollution}


func load_dict(d: Dictionary) -> void:
	active = d.get("active", {}).duplicate()
	pending = d.get("pending", {}).duplicate()
	last_day = int(d.get("last_day", game.day_n))
	storm = float(d.get("storm", 0.0))
	storm_target = float(d.get("storm_target", 0.0))
	pollution = float(d.get("pollution", 0.0))


## A-7 r5: урон снаружи — для героя текущего места (в сплитскрине вызывается за каждого).
func _outdoor_hit(dps: float, dt: float) -> void:
	var pl_g = game.player
	var guarding := false
	if dps > 0.0 and pl_g.alive and not protected(pl_g.position):
		# 13.10: защитный предмет в рюкзаке (кислотный зонтик) снимает урон от своих событий и изнашивается
		dps = 0.0
		for id in active:
			if not _live(id):
				continue
			var ed := float(list()[id].get("outdoor_dps", 0.0))
			if ed > 0.0:
				var k := _guard(id, dt)
				guarding = guarding or k > 0.0
				dps += ed * (1.0 - k)
	_show_guard(guarding)
	if dps > 0.0:
		var pl = game.player
		if pl.alive and not protected(pl.position):
			pl.damage(dps * dt)
			_warn_t -= dt
			if _warn_t <= 0.0:
				_warn_t = 12.0
				game.notify("Снаружи опасно! Укройтесь под навесом штаба, у бункера или под щитом-куполом — там не страшны ни кислота, ни жара, ни мороз.", Color(1, 0.6, 0.3))
