extends RefCounted
## Осады с боссом (14.7): раз в несколько дней утром приходит предупреждение «сегодня ночью осада»,
## ночью с одной стороны идёт гигантский босс со свитой. Убить босса — большая награда.
## Всё в «Волны → Осады»: как часто, с какого дня, сколько свиты, кто босс (монстры с «Это босс»).

var game
var announced_day := -1
var fired_day := -1
var boss_type := ""
var dir := Vector3.FORWARD
var boss = null            # живой босс (Enemies.E)
var count := 0             # сколько осад уже было
var won := 0


func _init(g) -> void:
	game = g


func cfg() -> Dictionary:
	return DB.data.waves.get("sieges", {})


func enabled() -> bool:
	return bool(cfg().get("enabled", false)) and game.enemies.waves_on()   # A17-2: модуль «Волны» выключен — осад тоже нет


## Есть ли осада в этот день.
func siege_day(d: int) -> bool:
	var c := cfg()
	var first := int(c.get("first_day", 5))
	var every := maxi(1, int(c.get("every_days", 5)))
	return d >= first and (d - first) % every == 0


func next_day() -> int:
	var d: int = game.day_n
	for i in 400:
		if siege_day(d + i):
			return d + i
	return -1


func _pick_boss() -> String:
	var opts: Array = cfg().get("bosses", [])
	var total := 0.0
	var ok := []
	for o in opts:
		if DB.data.enemies.has(str(o.get("enemy", ""))) and game.day_n >= int(o.get("from_day", 0)):
			ok.append(o)
			total += float(o.get("weight", 1.0))
	if ok.is_empty():
		return ""
	var r := randf() * total
	for o in ok:
		r -= float(o.get("weight", 1.0))
		if r <= 0.0:
			return str(o.enemy)
	return str(ok[-1].enemy)


static func side_name(v: Vector3) -> String:
	var a := fposmod(rad_to_deg(atan2(v.x, -v.z)), 360.0)
	var names := ["с севера", "с северо-востока", "с востока", "с юго-востока", "с юга", "с юго-запада", "с запада", "с северо-запада"]
	return names[int(round(a / 45.0)) % 8]


func update(_dt: float) -> void:
	if Net.is_client() or not enabled() or game.victory or game.factory.hq == null:
		return
	var d: int = game.day_n
	if boss != null and not boss.alive:
		won += 1
		var rw := int(cfg().get("reward", 0))
		if rw > 0:
			game.add_credits(rw, true)
		game.notify("Босс повержен! Осада отбита%s" % (" · +%d кр" % rw if rw > 0 else ""), Color(1.0, 0.85, 0.3))
		boss = null
	if not siege_day(d):
		return
	# 1.5: на первых этапах боссы не приходят (waves.pace) — сначала освоиться
	if announced_day != d and not game.enemies.bosses_allowed():
		return
	if announced_day != d and not game.is_night() and game.day_t > 0.2:
		announce()
	if fired_day != d and announced_day == d and game.is_night() and game.day_t > 0.5:
		start()


## Утром: кто придёт и откуда (чтобы успеть построить оборону).
func announce() -> void:
	announced_day = game.day_n
	boss_type = _pick_boss()
	if boss_type == "":
		return
	var a := randf() * TAU
	dir = Vector3(cos(a), 0, sin(a))
	var nm := str(DB.data.enemies[boss_type].get("name", boss_type))
	game.notify("Сегодня ночью осада: %s идёт %s! Стройте оборону." % [nm, side_name(dir)], Color(1.0, 0.45, 0.3))
	game.sfx.play("alarm", game.player.position)


## Ночью: босс и свита выходят с объявленной стороны.
func start() -> void:
	fired_day = game.day_n
	if boss_type == "" or not DB.data.enemies.has(boss_type):
		return
	var c := cfg()
	var en = game.enemies
	var hqp: Vector3 = game.factory.hq.center()
	var origin := hqp + dir * float(c.get("spawn_dist", 90.0))
	# 13.10: при зоне за тучами босс выходит прямо из туч на краю зоны
	if game.zone and game.zone.on():
		origin = game.zone.edge_point(dir, 2.0)
	if game.island != null:
		origin = game.island.wave_origin()
	var wdo: Dictionary = DB.data.waves
	if str(wdo.get("boss_omen", "")) != "":
		game.hud.omen(str(wdo.boss_omen), DB.color(wdo.get("omen_color", "#ff4a3a")), float(wdo.get("omen_time", 5.0)), str(wdo.get("omen_sound", "omen")))
	count += 1
	boss = en.spawn(boss_type, origin)
	if boss:
		boss.target = game.factory.hq
		var hk := 1.0 + float(c.get("hp_growth", 0.25)) * (count - 1)
		boss.hp *= hk
		boss.maxhp = boss.hp
	var n := int(c.get("escort", 10)) + int(c.get("escort_growth", 3)) * (count - 1)
	var groups: Array = DB.data.waves.get("groups", [])
	for i in n:
		var t: String = en._pick_type(groups)
		if t == "":
			continue
		var e = en.spawn(t, origin if game.island != null else origin + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)))
		if e:
			e.target = game.factory.hq
	for k in 6:
		game.fx.dirt(origin + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 2.0)
	en.wave_alert = 14.0
	game.sfx.play("alarm", origin)
	game.notify("ОСАДА! %s и свита (%d) идут на базу %s" % [str(DB.data.enemies[boss_type].get("name", boss_type)), n, side_name(dir)], Color(1.0, 0.3, 0.25))


## Для сохранения.
func save() -> Dictionary:
	return {"announced": announced_day, "fired": fired_day, "type": boss_type, "dir": [dir.x, dir.z], "count": count, "won": won, "live": boss != null and boss.alive}


func load_from(d: Dictionary) -> void:
	announced_day = int(d.get("announced", -1))
	fired_day = int(d.get("fired", -1))
	boss_type = str(d.get("type", ""))
	var dv: Array = d.get("dir", [0, -1])
	dir = Vector3(float(dv[0]), 0, float(dv[1]))
	count = int(d.get("count", 0))
	won = int(d.get("won", 0))
	if bool(d.get("live", false)) and fired_day >= 0:
		# A-10 r3: сохранились посреди осады — монстры не сохраняются, поэтому осада придёт заново этой же ночью
		announced_day = fired_day
		fired_day = -1
		count = maxi(0, count - 1)
