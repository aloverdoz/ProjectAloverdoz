class_name Enemies
extends Node3D
const CreatureRig = preload("res://scripts/creature_rig.gd")
const MobRules = preload("res://scripts/mob_rules.gd")
## Монстры: волны атакуют базу, стража охраняет гнёзда.
## Виды монстров — enemies.json, правила волн — waves.json.
## Каждый вид рисуется одним MultiMesh.

const C := World.C

class E:
	var type := ""
	var pos := Vector3.ZERO
	var yaw := 0.0
	var kv := Vector3.ZERO   # 21: отброс (взрыв, удар) — по земле
	var kvy := 0.0           # 21: подброс вверх
	var kh := 0.0            # 21: высота подброса
	var hp := 40.0
	var maxhp := 40.0
	var speed := 6.0
	var slow_k := 1.0      # замедление полем обороны (defense.gd): 1 — без замедления
	var dmg := 10.0
	var rate := 0.8
	var reach := 1.3
	var radius := 0.8
	var ranged := false
	var behavior := "nearest"
	var cd := 0.0
	var target = null
	var retarget := 0.0
	var alive := true
	var flash := 0.0
	var guard := false
	var home := Vector3.ZERO
	var reward := 3
	var xp := 1.0
	var moving := false
	var act := 1.0         # сила анимации шага (1 — идёт, около 0 — стоит)
	var lunge := 0.0
	var roam := false      # из бродячей стаи
	var pack = null        # стая (Pack)
	var slot := Vector3.ZERO  # место в строю стаи
	var chase_t := 0.0     # сколько уже гонится за героем
	var calm_t := 0.0      # потерял интерес: не замечает героя ещё столько секунд
	var far_t := 0.0       # сколько герой уже далеко (дальше «Дистанции побега»)
	# НПС (npcs.gd)
	var npc := ""          # trader, traveler, bandit, infiltrator; "" — монстр
	var peaceful := false  # турели и автоприцел героя не трогают
	var talk_t := 0.0      # 1.7: с ним говорят — стоит и смотрит на собеседника
	var talk_to := Vector3.ZERO
	var loot := {}
	var stock := {}
	var cash := -1         # 1.1.8: кредиты торговца на скупку (−1 — ещё не выдали)
	var state := ""
	var goal := Vector3.ZERO
	var timer := 0.0
	var revealed := false
	var said := 0
	var person := ""        # кто это (память НПС, npcs.gd)
	var pchar := ""         # характер
	var hurt_at := -10.0
	var skip_dt := 0.0      # накопленное время для дальних (думают через кадр)
	var think_slot := randi() % 2
	# сетевая игра
	var nid := 0              # номер монстра у всех игроков
	var last_hitter := 0      # кто ударил последним (награда — ему)
	var last_bld = null       # B-9 r5: здание (турель), ударившее последним
	var net_pos := Vector3.INF
	var net_yaw := 0.0
	var net_vel := Vector3.ZERO   # 1.5: скорость по двум последним снимкам — монстр идёт плавно между ними
	var net_t := 0.0
	# события мира
	var hunt := false         # «Рёв матери»: идёт прямо на героя и не отстаёт
	var burrow := false       # роет под землёй, вылезает только для удара
	var under := 0.0          # 0 — на поверхности, 1 — целиком под землёй
	var dig_t := 0.0
	var no_loot := false      # погиб от события — без добычи
	# умения (14.4): полёт, телепорт, взрыв, призыв, лечение своих, кража
	var d: Dictionary = {}    # запись вида из «Монстры и НПС»
	var fly := false
	var flight_phase := 0.0
	var flight_pose := ""
	var fly_h := 0.0
	var tp_t := 0.0
	var sum_t := 0.0
	var heal_t := 0.0
	var kids := 0             # сколько призванных ещё живы
	var parent = null         # кто призвал
	var stolen := {}          # что утащил у героя (выпадет, если убить)
	var flee_t := 0.0         # убегает с добычей
	# правила блоками (14.5, mob_rules.gd)
	var rule_t := 0.0
	var rule_last := {}
	var rule_mode := ""       # режим из правила: attack_player, attack_base, attack_building, flee, wander, go_home
	var hit_at := -99.0
	var player_hit_at := -99.0   # когда последний раз ударил герой (босс отвечает ему)
	var born_at := 0.0
	var born_pos := Vector3.ZERO
	var boost := 1.0
	var boost_t := 0.0


## Бродячая стая: бредёт по карте, нападает на героя, если он рядом.
class Pack:
	var center := Vector3.ZERO
	var goal := Vector3.ZERO
	var members: Array = []
	var aggro := false
	var speed := 2.5
	var chase_t := 0.0
	var calm_t := 0.0
	var far_t := 0.0

var game
var list: Array = []
var renderers := {}
var rigs := {}          # монстр -> CreatureRig (рядом с героем: живая анимация на скелете)
var corpses: Array = [] # умершие рядом: доигрывают падение
var spit: Array = []    # плевки: [pos, vel, life, dmg]

var wave := 0
var wave_timer := 400.0
var _omen_done := false
var wave_dir := Vector3.ZERO
var wave_alert := 0.0
var kills := 0
var waves_survived := 0
var wave_live := 0
var packs: Array = []
var roam_timer := 90.0


## 1.3 «Натиск» (waves.rush, галочка при создании мира или сервера): через start_min минут монстры нападают
## каждые every_min минут, и каждый раз их больше (count_growth) и они сильнее (hp_growth, dmg_growth). Идёт вместе с обычными волнами.
var rush_n := 0
var rush_timer := -1.0
var _spawn_hp_k := 1.0
var _spawn_dmg_k := 1.0


func _rush() -> Dictionary:
	var r = DB.data.waves.get("rush", {})
	return r if r is Dictionary else {}


func rush_on() -> bool:
	return bool(_rush().get("enabled", false)) and game.module("monsters")


func _update_rush(delta: float) -> void:
	if rush_timer < 0.0:
		rush_timer = float(_rush().get("start_min", 30.0)) * 60.0
	if game.factory.hq == null:
		return
	rush_timer -= delta
	if rush_timer > 0.0:
		return
	var r := _rush()
	rush_timer = maxf(10.0, float(r.get("every_min", 1.0)) * 60.0)
	var alive := 0
	for e in list:
		if not e.guard and not e.roam and e.npc == "":
			alive += 1
	var count := int(float(r.get("base_count", 5)) + float(r.get("count_growth", 2)) * rush_n)
	count = mini(count, int(r.get("max_count", 120)))
	count = mini(count, int(r.get("max_alive", 300)) - alive)
	rush_n += 1
	if count <= 0:
		return
	_spawn_hp_k = 1.0 + float(r.get("hp_growth", 0.08)) * (rush_n - 1)
	_spawn_dmg_k = 1.0 + float(r.get("dmg_growth", 0.04)) * (rush_n - 1)
	var hqp: Vector3 = game.factory.hq.center()
	var a := randf() * TAU
	var dir := Vector3(cos(a), 0, sin(a))
	var zn = game.zone
	var at_edge: bool = zn != null and zn.on()
	var origin: Vector3 = zn.edge_point(dir, 1.5) if at_edge else hqp + dir * float(DB.data.waves.get("spawn_dist", 70))
	var groups: Array = DB.data.waves.get("groups", [{"enemy": "crawler", "weight": 1}])
	var w_real := wave
	wave = maxi(wave, rush_n)   # состав — как у волны с тем же номером
	for i in count:
		var t := _pick_type(groups)
		if t == "":
			continue
		var at := origin + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
		if at_edge:
			var ang := a + randf_range(-0.22, 0.22)
			at = zn.edge_point(Vector3(cos(ang), 0, sin(ang)), randf_range(0.5, 3.0))
		spawn(t, at)
	wave = w_real
	_spawn_hp_k = 1.0
	_spawn_dmg_k = 1.0
	wave_alert = 6.0
	game.sfx.play("alarm", origin)
	game.notify("НАТИСК %d! Монстров всё больше" % rush_n, Color(1, 0.3, 0.25))


func setup() -> void:
	rush_n = 0
	rush_timer = -1.0
	wave_timer = float(DB.data.waves.get("first_delay", 420)) * float(pace().get("k_first", 1.0))
	roam_timer = float(DB.data.waves.get("roaming", {}).get("first_delay", 90))


# ---------------------------------------------------------------- 1.5: темп угрозы по прогрессу
## Насколько далеко продвинулся завод: каждый полностью открытый этап дерева открытий даёт 1
## (частично открытый — долю). 0 — ничего не открыто, ~9 — эндгейм. Без дерева открытий — по дням.
var _pace_cache := {}
var _pace_t := -1.0
var _pace_lvl := -1


func progress() -> float:
	if game == null or game.tech == null:
		return 0.0
	if not game.tech.enabled():
		return float(game.day_n) * 0.5
	var per_tier := {}
	var done_tier := {}
	for id in game.tech.nodes():
		var t := int(game.tech.nodes()[id].get("tier", 0))
		if t <= 0:
			continue
		per_tier[t] = int(per_tier.get(t, 0)) + 1
		if game.tech.done.has(id):
			done_tier[t] = int(done_tier.get(t, 0)) + 1
	var f := 0.0
	for t in per_tier:
		f += float(done_tier.get(t, 0)) / float(per_tier[t])
	return f


## Параметры волн для текущего прогресса (waves.pace.levels, между уровнями — плавно).
## k_* — множители к обычным значениям «Волн» (правила комнаты и заготовки сложности тоже действуют).
func pace() -> Dictionary:
	var pc: Dictionary = DB.data.waves.get("pace", {})
	if not bool(pc.get("enabled", false)):
		return {}
	var now := Time.get_ticks_msec() * 0.001
	if now - _pace_t < 1.0 and not _pace_cache.is_empty():
		return _pace_cache
	_pace_t = now
	var lv: Array = pc.get("levels", [])
	if lv.is_empty():
		return {}
	var f := progress()
	var a: Dictionary = lv[0]
	var b: Dictionary = lv[0]
	for i in lv.size():
		if f >= float(lv[i].get("at", 0.0)):
			a = lv[i]
			b = lv[mini(i + 1, lv.size() - 1)]
	var span := float(b.get("at", 0.0)) - float(a.get("at", 0.0))
	var k := clampf((f - float(a.get("at", 0.0))) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var out := {"progress": f}
	for key in a:
		var va = a[key]
		var vb = b.get(key, va)
		if (va is float or va is int) and (vb is float or vb is int) and not va is bool:
			out[key] = lerpf(float(va), float(vb), k)
		else:
			out[key] = va
	# сложность мира: реже/чаще и меньше/больше роботов
	var diff: float = game.difficulty if game and "difficulty" in game else 1.0
	out["k_interval"] = float(out.get("k_interval", 1.0)) / pow(maxf(0.1, diff), 0.35)
	out["k_count"] = float(out.get("k_count", 1.0)) * pow(maxf(0.1, diff), 0.5)
	_pace_cache = out
	var lvl := int(floor(f))
	if _pace_lvl >= 0 and lvl > _pace_lvl and not Net.is_client():
		game.notify("Завод растёт — роботы заметили: волны станут чуть сильнее", Color(1, 0.6, 0.35))
	_pace_lvl = lvl
	return out


## Номер волны для силы и состава роботов: на раннем этапе не растёт выше max_wave.
func eff_wave() -> int:
	var p := pace()
	if p.is_empty():
		return wave
	return mini(wave, maxi(1, int(round(float(p.get("max_wave", 999))))))


## Боссы (осады) — только когда завод уже на этапе с ними (pace.bosses).
func bosses_allowed() -> bool:
	var p := pace()
	return p.is_empty() or bool(p.get("bosses", true))


func _renderer(type: String) -> PartRenderer:
	if renderers.has(type):
		return renderers[type]
	var r := ModelLib.make_renderer(DB.data.enemies.get(type, {}).get("model", type), true, true, true)
	var ed: Dictionary = DB.data.enemies.get(type, {})
	if float(ed.get("tint_k", 0.0)) > 0.0:
		# вариант силы: тот же скелет и модель, другая окраска
		for p in r.parts:
			if p.tint:
				p.color = recolor(p.color, DB.color(ed.get("tint", "#ffffff")), float(ed.tint_k))
	add_child(r)
	renderers[type] = r
	return r


## Перекрасить деталь под вариант монстра: оттенок и насыщенность — к цвету варианта, яркость своя.
static func recolor(c: Color, to: Color, k: float) -> Color:
	if k <= 0.0:
		return c
	var h := lerpf(c.h, to.h, k) if absf(c.h - to.h) <= 0.5 else fposmod(lerpf(c.h, to.h + (1.0 if to.h < c.h else -1.0), k), 1.0)
	var v := lerpf(c.v, c.v * (0.55 + to.v * 0.7), k)
	return Color.from_hsv(h, lerpf(c.s, maxf(to.s, c.s * 0.6), k), clampf(v, 0.0, 1.0), c.a)


func rebuild_visuals() -> void:
	for k in renderers:
		renderers[k].queue_free()
	renderers.clear()
	for e in rigs:
		rigs[e].queue_free()
	rigs.clear()
	for e in list:
		_renderer(e.type).add(e, _xf(e), 1.0)


func spawn(type: String, pos: Vector3, guard := false, from_net := false) -> E:
	var d: Dictionary = DB.data.enemies.get(type, {})
	if d.is_empty():
		return null
	# у подключившегося монстров заводит только хозяин (по сети)
	if Net.is_client() and not from_net:
		return null
	# 16: «Монстры на карте» выключены — враждебные роботы не появляются (торговцы и путники остаются)
	if not from_net and game and not game.module("monsters") and not str(d.get("behavior", "")) in ["trader", "traveler"]:
		return null
	var e := E.new()
	e.type = type
	e.pos = World.wrap_pos(pos)
	e.guard = guard
	e.home = e.pos
	e.yaw = randf() * TAU
	var diff: float = game.difficulty if game and "difficulty" in game else 1.0
	var pc := pace() if not from_net and game != null and not str(d.get("behavior", "")) in ["trader", "traveler"] else {}
	var hp_k := (1.0 + eff_wave() * float(DB.data.waves.get("hp_growth", 0.06))) * diff * float(pc.get("k_hp", 1.0))
	e.hp = float(d.get("hp", 40)) * hp_k * _spawn_hp_k
	e.maxhp = e.hp
	e.speed = float(d.get("speed", 6)) * randf_range(0.9, 1.1)
	e.dmg = float(d.get("damage", 10)) * lerpf(1.0, diff, 0.7) * _spawn_dmg_k * float(pc.get("k_dmg", 1.0))
	e.rate = float(d.get("rate", 0.8))
	e.reach = float(d.get("reach", 1.3))
	e.radius = float(d.get("radius", 0.8))
	e.ranged = bool(d.get("ranged", false))
	e.behavior = d.get("behavior", "nearest")
	e.reward = int(d.get("reward", 3))
	e.xp = float(d.get("xp", 1))
	e.burrow = bool(d.get("burrow", false))
	if e.burrow:
		e.under = 1.0
	e.d = d
	e.fly = bool(d.get("fly", false))
	e.fly_h = float(d.get("fly_height", 3.0)) if e.fly else 0.0
	e.tp_t = randf_range(0.5, 1.0) * float(d.get("teleport_every", 0.0))
	e.sum_t = randf_range(0.4, 1.0) * float(d.get("summon_every", 0.0))
	e.heal_t = randf_range(0.3, 1.0) * float(d.get("heal_every", 0.0))
	e.born_at = Time.get_ticks_msec() * 0.001
	e.born_pos = e.pos
	e.rule_t = randf() * 0.5
	if e.behavior in ["trader", "traveler", "bandit", "infiltrator"]:
		e.npc = e.behavior
		e.peaceful = e.behavior != "bandit"
	if Net.is_host():
		e.nid = Net._self().new_nid()
	list.append(e)
	_renderer(type).add(e, _xf(e), 1.0)
	return e


func _xf(e: E) -> Transform3D:
	var s := float(DB.data.enemies.get(e.type, {}).get("scale", 1.0))
	var fwd := Vector3(cos(e.yaw), 0, -sin(e.yaw))
	return Transform3D(Basis(Vector3.UP, e.yaw).scaled(Vector3.ONE * s), e.pos + fwd * e.lunge)


func is_alive(e) -> bool:
	return e != null and e.alive


## Можно ли выстрелить или ударить: НПС-мирных и червей под землёй не трогают.
func targetable(e) -> bool:
	return e.alive and not e.peaceful and e.under < 0.6


func pos_of(e) -> Vector3:
	return e.pos


func nearest(p: Vector3, r: float):
	var best = null
	var bd := r
	for e in list:
		if not targetable(e):
			continue
		var d := World.dist(p, e.pos)
		if d < bd:
			bd = d
			best = e
	return best


func hit(e: E, dmg: float, by_player := false, by_bld = null) -> void:
	if not e.alive:
		return
	if not Net.is_client():
		e.last_bld = by_bld
		if by_player or by_bld != null:
			e.last_hitter = 0   # B-5 r6: добил хозяин или турель — не гость, ударивший раньше
	if Net.is_client():
		# урон считает хозяин; здесь — только вспышка (турели у хозяина стреляют сами)
		e.flash = 1.0
		if by_player:
			Net._self().hit_monster(e, dmg)
		return
	e.hp -= dmg
	e.flash = 1.0
	e.hit_at = Time.get_ticks_msec() * 0.001
	if by_player:
		e.player_hit_at = e.hit_at
		game.fx.number(e.pos + Vector3(0, 1.4 + e.radius, 0), str(roundi(dmg)), Color(1, 0.85, 0.3), dmg >= 30.0)
		# 21: удар героя чуть отталкивает
		var away: Vector3 = World.delta(game.player.position, e.pos)
		away.y = 0
		if away.length() > 0.05:
			knock(e, away.normalized() * Phys.num("hit_knock", 2.5) / maxf(0.6, e.radius), 0.0)
	if by_player and e.npc != "" and game.npcs:
		game.npcs.on_hurt(e)
	if e.guard and e.target == null:
		e.target = game.player
	if e.hp <= 0.0:
		_kill(e)


func _kill(e: E) -> void:
	e.alive = false
	if not (Net.is_host() and e.last_hitter > 1):
		kills += 1   # B18-3: добил гость — счёт убийств у него (got_reward)
	if Time.get_ticks_msec() * 0.001 - e.player_hit_at < 0.3:
		game.hitstop(0.07)       # 1.3: добил сам — кадр замирает, камера вздрагивает
		game.add_trauma(0.3)
	game.fx.goo(e.pos + Vector3(0, 0.6, 0), e.radius * 1.3)
	var loot: bool = not e.no_loot and not (game.events and game.events.no_loot())
	var remote_killer: bool = Net.is_host() and e.last_hitter > 1
	# B-9 r5: добила турель гостя (свои кошельки) — награда владельцу турели
	var bld_own := ""
	if not remote_killer and e.last_bld != null and Net.is_host() and Net._self().own_wallets() and game.get("coop") != null:
		bld_own = game.coop.owner_of(e.last_bld)
		if bld_own == Net._self().nick:
			bld_own = ""
	if loot:
		if remote_killer and Net._self().own_wallets():
			Net._self().wallet_add_id(e.last_hitter, e.reward)   # 16: свои кошельки — награда тому, кто добил
		elif bld_own != "":
			Net._self().wallet_add(bld_own, e.reward)
		else:
			game.add_credits(e.reward, false)
	if not remote_killer and loot and bld_own == "":
		game.add_xp(float(DB.data.levels.get("xp", {}).get("kill", 1)) * e.xp)
	game.sfx.play(_snd(e, "die", "splat"), e.pos)
	_renderer(e.type).remove(e)
	if rigs.has(e):
		# рядом с героем — монстр заваливается и уходит в землю, а не исчезает
		var rg: CreatureRig = rigs[e]
		rigs.erase(e)
		rg.die(1.0 if randf() < 0.5 else -1.0)
		corpses.append([rg, e])
	list.erase(e)
	if e.parent != null:
		e.parent.kids = maxi(0, e.parent.kids - 1)
	for id in e.stolen:
		if e.stolen[id] is Dictionary:   # A-11 r4: инструмент с износом
			game.drops.spawn_slot(e.stolen[id], e.pos + Vector3(0, 0.8, 0))
		else:
			game.drops.spawn(id, int(e.stolen[id]), e.pos + Vector3(0, 0.8, 0))
	e.stolen.clear()
	if e.npc != "" and game.npcs:
		game.npcs.on_killed(e)
	if e.pack != null:
		e.pack.members.erase(e)
		if e.pack.members.is_empty():
			packs.erase(e.pack)
	# таблица добычи монстра: предмет, шанс, сколько (добил игрок по сети — добыча и опыт у него)
	var got := []
	for d in (DB.data.enemies.get(e.type, {}).get("drops", []) if loot else []):
		if randf() < float(d.get("chance", 1.0)):
			var n := randi_range(int(d.get("min", 1)), int(d.get("max", 1)))
			if n > 0:
				if remote_killer:
					got.append([d.get("item", ""), n])
				else:
					game.drops.spawn(d.get("item", ""), n, e.pos + Vector3(randf_range(-0.6, 0.6), 0.8, randf_range(-0.6, 0.6)))
	if remote_killer and loot:
		Net._self().reward(e.last_hitter, e.reward, float(DB.data.levels.get("xp", {}).get("kill", 1)) * e.xp, got, e.pos)


## У подключившегося: монстр пропал из присланного хозяином списка — убит. Только вид и звук.
func kill_visual(e: E) -> void:
	e.alive = false
	game.fx.goo(e.pos + Vector3(0, 0.6, 0), e.radius * 1.3)
	game.sfx.play(_snd(e, "die", "splat"), e.pos)
	_renderer(e.type).remove(e)
	if rigs.has(e):
		var rg: CreatureRig = rigs[e]
		rigs.erase(e)
		rg.die(1.0 if randf() < 0.5 else -1.0)
		corpses.append([rg, e])
	list.erase(e)


# ---------------------------------------------------------------- умения (14.4)

## Телепорт к цели, призыв помощников, лечение своих. Значения — в «Монстры и НПС».
func _abilities(e: E, player, delta: float) -> void:
	var d: Dictionary = e.d
	if e.target == null:
		return
	var tp: Vector3 = e.target.position if e.target is Player else e.target.center()
	var te := float(d.get("teleport_every", 0.0))
	if te > 0.0:
		e.tp_t -= delta
		if e.tp_t <= 0.0:
			e.tp_t = te
			if World.dist(e.pos, tp) > 6.0 and World.dist(e.pos, tp) < float(d.get("teleport_range", 30.0)):
				game.fx.magic(e.pos, Color(0.7, 0.3, 1.0))
				var ang := randf() * TAU
				e.pos = World.wrap_pos(tp + Vector3(cos(ang), 0, sin(ang)) * randf_range(2.5, 4.0))
				game.fx.magic(e.pos, Color(0.7, 0.3, 1.0))
				game.sfx.play(_snd(e, "ability", "click"), e.pos)
	var se := float(d.get("summon_every", 0.0))
	var st := str(d.get("summon", ""))
	if se > 0.0 and st != "" and DB.data.enemies.has(st):
		e.sum_t -= delta
		if e.sum_t <= 0.0:
			e.sum_t = se
			var n := mini(int(d.get("summon_n", 2)), int(d.get("summon_max", 6)) - e.kids)
			for i in n:
				var ang := randf() * TAU
				var k = spawn(st, e.pos + Vector3(cos(ang), 0, sin(ang)) * randf_range(1.5, 3.0))
				if k:
					k.parent = e
					k.target = e.target
					e.kids += 1
					game.fx.magic(k.pos, Color(1.0, 0.3, 0.2))
	var he := float(d.get("heal_every", 0.0))
	if he > 0.0:
		e.heal_t -= delta
		if e.heal_t <= 0.0:
			e.heal_t = he
			var r := float(d.get("heal_radius", 8.0))
			var amt := float(d.get("heal_amount", 20.0))
			var any := false
			for o in list:
				if o.alive and o.npc == "" and o.hp < o.maxhp and World.dist(o.pos, e.pos) <= r:
					o.hp = minf(o.maxhp, o.hp + amt)
					game.fx.magic(o.pos, Color(0.3, 1.0, 0.4), 0.6)
					any = true
			if any:
				game.sfx.play(_snd(e, "ability", "click"), e.pos)


## Взрыв у цели: урон герою и зданиям рядом, сам монстр погибает.
## Режим из правила (mob_rules.gd) вместо обычного выбора цели. true — монстр уже походил сам (убегает).
func _rule_target(e: E, player, fac, delta: float) -> bool:
	match e.rule_mode:
		"attack_player":
			if player.alive:
				e.target = player
				e.calm_t = 0.0
		"attack_base", "attack_building":
			# 14.23: отвечает герою, который рядом или только что ударил (раньше босс его не замечал)
			if _provoked(e, player):
				e.target = player
				return false
			if e.target == player:
				e.target = null
			# путь перегородило здание — сначала ломает его (раньше цель каждый кадр снова становилась штабом, и босс стоял)
			if e.target != null and e.target != fac.hq and not e.target.dead and e.retarget > 0.0:
				return false
			if e.rule_mode == "attack_base":
				e.target = fac.hq
			elif e.target == null or e.target.dead:
				e.target = building_near(e.pos)
		"wander", "go_home":
			e.target = null
		"flee":
			e.target = null
			var away: Vector3 = World.delta(player.position, e.pos)
			away.y = 0.0
			e.moving = false
			if away.length() > 0.1 and away.length() < 45.0:
				var ad := away.normalized()
				e.pos += ad * e.speed * 1.1 * delta
				e.moving = true
				e.yaw = lerp_angle(e.yaw, atan2(-ad.z, ad.x), min(1.0, delta * 8.0))
			return true
	return false


## Герой рядом или ударил недавно — монстр в режиме «на базу» переключается на него.
func _provoked(e: E, player) -> bool:
	if player == null or not player.alive:
		return false
	var cfg: Dictionary = DB.setting("bosses", {})
	var now := Time.get_ticks_msec() * 0.001
	if now - e.player_hit_at < float(cfg.get("revenge_time", 6.0)):
		return true
	var r := float(e.d.get("player_aggro", cfg.get("player_aggro", 10.0)))
	return r > 0.0 and World.dist(e.pos, player.position) <= r


func _explode(e: E) -> void:
	var r := float(e.d.get("explode_radius", 3.0))
	var dmg := float(e.d.get("explode_damage", 40.0))
	game.fx.explosion(e.pos + Vector3(0, 0.8, 0), 1.0 + r * 0.4, Color(1.0, 0.6, 0.2))
	game.sfx.play("boom", e.pos)
	for pl in game.hit_targets():
		if pl.alive and World.dist(pl.position, e.pos) <= r:
			pl.damage(dmg)
	var c: Vector2i = World.world_to_cell(e.pos)
	var rc := ceili(r / C)
	for dx in range(-rc, rc + 1):
		for dz in range(-rc, rc + 1):
			var b = game.factory.building_at(World.wc(c + Vector2i(dx, dz)))
			if b != null and not b.dead and World.dist(b.center(), e.pos) <= r + b.size * C * 0.5:
				game.factory.damage(b, dmg)
	e.hp = 0.0
	_kill(e)


## Кража: утаскивает предметы из рюкзака героя и убегает. Убить вора — вещи выпадут.
func _steal(e: E, player) -> void:
	var n := int(e.d.get("steal", 0))
	var inv = player.inv
	var ids := []
	for s in inv.slots:
		if s != null and int(s.get("n", 0)) > 0 and str(s.get("id", "")) != player.selected_item():
			ids.append(str(s.id))
	if ids.is_empty():
		return
	var id: String = ids[randi() % ids.size()]
	var got := mini(n, inv.count(id))
	# A-11 r4: инструмент/еда — уносит слот целиком (износ и свежесть сохраняются)
	for i in inv.slots.size():
		var sl = inv.slots[i]
		if sl != null and str(sl.get("id", "")) == id and (sl.has("dur") or sl.has("fresh")):
			got = mini(n, int(sl.n))   # A-2 r5: не больше, чем вор умеет унести
			e.stolen[id] = (sl as Dictionary).duplicate()
			e.stolen[id]["n"] = got
			if got >= int(sl.n):
				inv.slots[i] = null
			else:
				sl["n"] = int(sl.n) - got
			inv._bump()
			break
	if not e.stolen.has(id):
		inv.remove(id, got)
		e.stolen[id] = got
	e.flee_t = float(e.d.get("flee_time", 25.0))
	e.target = null
	game.notify("%s утащил %s × %d! Догоните его." % [str(e.d.get("name", e.type)), DB.item_name(id), got], Color(1, 0.6, 0.3))


## Монстр уходит без боя (червь зарылся после события): без добычи и без «убийства».
func vanish(e: E) -> void:
	e.alive = false
	game.fx.dirt(Vector3(e.pos.x, game.factory.support_at(e.pos), e.pos.z), 1.0)
	_renderer(e.type).remove(e)
	if rigs.has(e):
		_drop_rig(e)
	list.erase(e)
	if e.parent != null:
		e.parent.kids = maxi(0, e.parent.kids - 1)
	if e.pack != null:
		e.pack.members.erase(e)


## У подключившегося монстры только показываются: плавно идут к месту, присланному хозяином.
func _update_puppets(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for e in list:
		if e.net_pos != Vector3.INF:
			var ahead: Vector3 = e.net_vel * clampf(now - e.net_t, 0.0, 0.2)
			var d: Vector3 = World.delta(e.pos, e.net_pos + ahead)
			e.pos = e.net_pos if d.length() > 6.0 else World.wrap_pos(e.pos + d * minf(1.0, delta * 12.0))
			e.yaw = lerp_angle(e.yaw, e.net_yaw, minf(1.0, delta * 10.0))
	_update_rigs(delta)
	for e in list:
		if rigs.has(e):
			continue
		var r := _renderer(e.type)
		r.set_xform(e, _xf(e))
		var want := 1.0 if e.moving else 0.0
		var na := move_toward(e.act, want, delta * 5.0)
		if absf(na - e.act) > 0.001:
			e.act = na
			r.set_active(e, na)
		if e.flash > 0.0:
			e.flash = max(0.0, e.flash - delta * 6.0)
			r.set_tint(e, 0.0, e.flash)


## Убрать без награды и добычи (НПС ушёл с карты).
func remove_silent(e: E) -> void:
	if not e.alive:
		return
	e.alive = false
	_renderer(e.type).remove(e)
	_drop_rig(e)
	list.erase(e)


func _snd(e: E, what: String, def: String) -> String:
	return DB.data.enemies.get(e.type, {}).get("sounds", {}).get(what, def)


# ---------------------------------------------------------------- волны

## Монстры с «Вес появления» > 0 сами попадают в волны и стаи (не нужно вписывать каждого в списки).
var _auto_src = null
var _auto: Array = []

func auto_groups() -> Array:
	if not is_same(_auto_src, DB.data.enemies):
		_auto_src = DB.data.enemies
		_auto.clear()
		for id in DB.data.enemies:
			var d: Dictionary = DB.data.enemies[id]
			var w := float(d.get("spawn_weight", 0.0))
			if w > 0.0:
				var fd := int(d.get("from_day", 1))
				_auto.append({"enemy": id, "weight": w, "from_wave": fd, "from_day": fd, "leader": bool(d.get("spawn_leader", false)), "where": str(d.get("spawn_where", "both"))})
	return _auto


func _pick_type(groups: Array) -> String:
	var total := 0.0
	var ok := []
	var ew := eff_wave()
	var lvl: int = maxi(ew, game.day_n) if pace().is_empty() else ew
	for g in auto_groups():
		if g.where != "roam" and lvl >= int(g.from_wave):
			ok.append(g)
			total += float(g.weight)
	for g in groups:
		if ew >= int(g.get("from_wave", 1)) and DB.data.enemies.has(g.get("enemy", "")):
			ok.append(g)
			total += float(g.get("weight", 1))
	var r := randf() * total
	for g in ok:
		r -= float(g.get("weight", 1))
		if r <= 0.0:
			return g.enemy
	return ok[0].enemy if not ok.is_empty() else ""


func start_wave(mult := 1.0) -> void:
	_omen_done = false
	var wd: Dictionary = DB.data.waves
	var alive_nests := []
	for n in game.world.nests:
		if n.alive:
			alive_nests.append(n)
	# 18: волны бесконечные, пока база жива; останавливаются после победы, только если так задано («Меню» → «Победа» → stop_waves)
	if game.factory.hq == null or (game.victory and bool(DB.menu("victory", {}).get("stop_waves", false))):
		wave_timer = float(wd.get("interval", 150))
		return
	wave += 1
	var hqp: Vector3 = game.factory.hq.center()
	var nd := 9999.0
	if alive_nests.is_empty():
		# на карте без гнёзд волна приходит из случайной стороны
		var a := randf() * TAU
		wave_dir = Vector3(cos(a), 0, sin(a))
	else:
		var nest = alive_nests[randi() % alive_nests.size()]
		wave_dir = World.delta(hqp, nest.pos)
		wave_dir.y = 0
		nd = wave_dir.length()
	wave_dir = wave_dir.normalized()
	var dist: float = min(float(wd.get("spawn_dist", 70)), nd - 6.0)
	var origin := hqp + wave_dir * dist
	# 13.10: при зоне за тучами роботы выходят прямо из туч на краю зоны игрока
	var zn = game.zone
	var at_edge: bool = zn != null and zn.on()
	if at_edge:
		origin = zn.edge_point(wave_dir, 1.5)
	var pc := pace()
	var count := int(float(wd.get("base_count", 4)) + float(wd.get("growth", 2.5)) * (eff_wave() - 1))
	count = maxi(1, int(round(count * float(pc.get("k_count", 1.0)))))
	if game.is_night():
		count = int(count * float(wd.get("night_mult", 1.4)))
	if game.events:
		mult *= game.events.wave_mult()
	count = int(count * mult)
	count = mini(count, int(wd.get("max_count", 200)))
	var groups: Array = wd.get("groups", [{"enemy": "crawler", "weight": 1}])
	for i in count:
		var t := _pick_type(groups)
		if t != "":
			if at_edge:
				# вдоль края, веером в сторону волны
				var ang := atan2(wave_dir.z, wave_dir.x) + randf_range(-0.22, 0.22)
				spawn(t, zn.edge_point(Vector3(cos(ang), 0, sin(ang)), randf_range(0.5, 3.0)))
			else:
				spawn(t, origin + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))
	for k in 4:
		game.fx.dirt(origin + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 1.5)
	wave_live = count
	wave_alert = 12.0
	wave_timer = max(float(wd.get("interval_min", 80)), float(wd.get("interval", 150)) - float(wd.get("interval_step", 8)) * eff_wave())
	if not pc.is_empty():
		wave_timer = maxf(float(wd.get("interval_min", 80)) * minf(1.0, float(pc.get("k_interval", 1.0))), float(wd.get("interval", 150)) * float(pc.get("k_interval", 1.0)))
	game.sfx.play("alarm", origin)
	game.on_wave_started(wave)
	game.notify("ВОЛНА %d! Монстры идут к базе" % wave, Color(1, 0.35, 0.3))


func _check_guards() -> void:
	var gd: Dictionary = DB.data.waves.get("guards", {})
	for n in game.world.nests:
		if n.alive and not n.guards and game.near_any_hero(n.pos) < 75.0:   # B-4 r5: любой герой
			n.guards = true
			n["mobs"] = []
			# A-6 r7: после загрузки — только недобитые
			var types: Array = []
			if n.get("left") is Array:
				types = n.left
				n.erase("left")
			else:
				for i in int(gd.get("count", 6)):
					types.append(str(gd.get("enemy", "crawler")))
				if gd.get("boss", "") != "":
					types.append(str(gd.boss))
			for t in types:
				var boss: bool = str(t) == str(gd.get("boss", "")) and gd.get("boss", "") != ""
				var a := randf() * TAU
				var e = spawn(str(t), n.pos + (Vector3(4, 0, 4) if boss else Vector3(cos(a), 0, sin(a)) * randf_range(6, 10)), true)
				if e:
					n.mobs.append(e)


# ---------------------------------------------------------------- бродячие стаи

func _roam_cfg() -> Dictionary:
	return DB.data.waves.get("roaming", {})


func _pick_roam_type(groups: Array, leader: bool) -> String:
	var total := 0.0
	var ok := []
	for g in auto_groups():
		if g.where != "waves" and game.day_n >= int(g.from_day) and bool(g.leader) == leader:
			ok.append(g)
			total += float(g.weight)
	for g in groups:
		if game.day_n >= int(g.get("from_day", 1)) and DB.data.enemies.has(g.get("enemy", "")) and bool(g.get("leader", false)) == leader:
			ok.append(g)
			total += float(g.get("weight", 1))
	var r := randf() * total
	for g in ok:
		r -= float(g.get("weight", 1))
		if r <= 0.0:
			return g.enemy
	return ok[0].enemy if not ok.is_empty() else ""


func roaming_count() -> int:
	var n := 0
	for p in packs:
		n += p.members.size()
	return n


## Найти место для стаи: далеко от героя и от штаба, не в воде.
func _roam_spot(cfg: Dictionary, from: Vector3) -> Vector3:
	var hq = game.factory.hq
	for i in 30:
		var a := randf() * TAU
		var d := randf_range(float(cfg.get("spawn_min_dist", 55)), float(cfg.get("spawn_max_dist", 110)))
		var p := World.wrap_pos(from + Vector3(cos(a), 0, sin(a)) * d) if game.world.wrap else from + Vector3(cos(a), 0, sin(a)) * d
		var c := World.world_to_cell(p)
		if not game.world.in_bounds(c) or game.world.water_at(c) or game.world.blocks(c):
			continue
		if hq != null and World.dist(p, hq.center()) < float(cfg.get("base_safe_radius", 35)):
			continue
		return p
	return Vector3.INF


func spawn_pack(at := Vector3.INF) -> Pack:
	var cfg := _roam_cfg()
	if at == Vector3.INF:
		at = _roam_spot(cfg, game.player.position)
		if at == Vector3.INF:
			return null
	var groups: Array = cfg.get("groups", [{"enemy": "crawler", "weight": 1}])
	var pk := Pack.new()
	pk.center = at
	pk.goal = at
	var rk := float(pace().get("k_roam", 1.0))
	var n := maxi(1, int(round(randi_range(int(cfg.get("pack_min", 3)), int(cfg.get("pack_max", 6))) * rk)))
	var leader := _pick_roam_type(groups, true)
	if leader != "" and randf() < 0.35 * rk:
		_add_member(pk, leader)
	for i in n:
		var t := _pick_roam_type(groups, false)
		if t != "":
			_add_member(pk, t)
	if pk.members.is_empty():
		return null
	var slow := INF
	for e in pk.members:
		slow = min(slow, e.speed)
	pk.speed = slow * float(cfg.get("wander_speed", 0.45)) * 0.8
	packs.append(pk)
	return pk


func _add_member(pk: Pack, t: String) -> void:
	var a := randf() * TAU
	var e := spawn(t, pk.center + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 4.0))
	if e == null:
		return
	e.roam = true
	e.pack = pk
	e.slot = Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 4.5)
	pk.members.append(e)


## Вода без фундамента (монстры её обходят).
func _wet(c: Vector2i) -> bool:
	return game.world.water_at(c) and game.factory.found_top(c) == null


func chase_time() -> float:
	return float(DB.setting("monster_chase_time", 0.0))


## Побег: если герой дальше этой дистанции «Сколько секунд побега» подряд, монстр отстаёт.
func escape_dist() -> float:
	return float(DB.setting("monster_escape_dist", 16.0))


func escape_time() -> float:
	return float(DB.setting("monster_escape_time", 10.0))


## Монстр без героя рядом ищет здание поблизости (ленты, машины, стены) и ломает его.
func building_near(pos: Vector3):
	if not bool(DB.setting("monster_attack_buildings", true)):
		return null
	return game.factory.nearest_building(pos, int(DB.setting("monster_building_cells", 8)))


func _update_packs(delta: float) -> void:
	var cfg := _roam_cfg()
	if not bool(cfg.get("enabled", true)) or not game.module("monsters"):
		return
	roam_timer -= delta * (float(cfg.get("night_mult", 1.5)) if game.is_night() else 1.0)
	if roam_timer <= 0.0:
		roam_timer = float(cfg.get("interval", 70)) / maxf(0.2, float(pace().get("k_roam", 1.0)))
		if packs.size() < maxi(1, int(round(int(cfg.get("max_packs", 6)) * float(pace().get("k_roam", 1.0))))) and roaming_count() < int(cfg.get("max_monsters", 40)):
			spawn_pack()
	var aggro_r := float(cfg.get("aggro_radius", 18))
	var lose_r := float(cfg.get("lose_radius", 40))
	for pk in packs.duplicate():
		# стая замечает героя — нападает вся
		var near := INF
		for e in pk.members:
			near = min(near, game.near_any_hero(e.pos))   # B-4 r5: стаю будит любой герой
		pk.calm_t = maxf(0.0, pk.calm_t - delta)
		pk.chase_t = pk.chase_t + delta if pk.aggro else 0.0
		pk.far_t = pk.far_t + delta if pk.aggro and near > escape_dist() else 0.0
		var bored: bool = pk.aggro and ((chase_time() > 0.0 and pk.chase_t > chase_time()) or (escape_time() > 0.0 and pk.far_t > escape_time()))
		if bored:
			pk.calm_t = float(DB.setting("monster_calm_time", 10.0))
		if near < aggro_r and pk.calm_t <= 0.0:
			if not pk.aggro:
				pk.aggro = true
				game.sfx.play(_snd(pk.members[0], "attack", "bite"), pk.members[0].pos)
		elif pk.aggro and (near > lose_r or bored):
			pk.aggro = false
			var sum := Vector3.ZERO
			for e in pk.members:
				sum += World.delta(pk.members[0].pos, e.pos)
			pk.center = World.wrap_pos(pk.members[0].pos + sum / pk.members.size()) if game.world.wrap else pk.members[0].pos + sum / pk.members.size()
			pk.goal = pk.center
		if pk.aggro:
			continue
		# бредём к случайной цели, обходя базу
		var to := World.delta(pk.center, pk.goal)
		to.y = 0
		if to.length() < 2.0:
			var hq = game.factory.hq
			for i in 10:
				var a := randf() * TAU
				var g: Vector3 = pk.center + Vector3(cos(a), 0, sin(a)) * randf_range(10, 30)
				if game.world.wrap:
					g = World.wrap_pos(g)
				if hq != null and World.dist(g, hq.center()) < float(cfg.get("base_safe_radius", 35)):
					continue
				if game.world.water_at(World.world_to_cell(g)):
					continue
				pk.goal = g
				break
		else:
			pk.center += to.normalized() * min(to.length(), pk.speed * delta)
			if game.world.wrap:
				pk.center = World.wrap_pos(pk.center)
		# слишком далеко от героя — растворяется, чтобы появиться где-то ещё
		if game.near_any_hero(pk.center) > float(cfg.get("despawn_dist", 260)):
			for e in pk.members.duplicate():
				e.alive = false
				_renderer(e.type).remove(e)
				list.erase(e)
			packs.erase(pk)


# ---------------------------------------------------------------- обновление

var _guard_acc := 0.0

## Идут ли волны: «Волны» в редакторе и модули новой игры «Волны роботов» и «Монстры на карте».
func waves_on() -> bool:
	return bool(DB.data.waves.get("enabled", true)) and game.module("waves") and game.module("monsters") and not peaceful()


## 1.5: сложность «Мирная» — волн и осад с боссами нет (бродячие роботы остаются, но слабые).
func peaceful() -> bool:
	return game != null and "difficulty" in game and float(game.difficulty) <= 0.3


func update(delta: float) -> void:
	if Net.is_client():
		_update_puppets(delta)
		return
	if not game.victory and waves_on():
		wave_timer -= delta
		# 13.10: за несколько секунд до волны — зловещая надпись («Волны» → «Предупреждение»)
		var wd: Dictionary = DB.data.waves
		if not _omen_done and wave_timer <= float(wd.get("omen_lead", 0.0)) and str(wd.get("omen", "")) != "" and game.factory.hq != null:
			_omen_done = true
			game.hud.omen(str(wd.omen), DB.color(wd.get("omen_color", "#ff4a3a")), float(wd.get("omen_time", 5.0)), str(wd.get("omen_sound", "omen")))
		if wave_timer <= 0.0:
			_omen_done = false
			start_wave()
	if not game.victory and rush_on():
		_update_rush(delta)
	wave_alert = max(0.0, wave_alert - delta)
	var _pt := Time.get_ticks_usec()
	_update_packs(delta)
	if game.prof_on: game._prof("en.packs", _pt); _pt = Time.get_ticks_usec()
	if game.maze:
		game.maze.update(delta)
	if game.prof_on: game._prof("en.maze", _pt); _pt = Time.get_ticks_usec()
	_guard_acc += delta
	if _guard_acc > 1.0:
		_guard_acc = 0.0
		_check_guards()
	var buckets := {}
	for e in list:
		var k := Vector2i(floori(e.pos.x / 3.0), floori(e.pos.z / 3.0))
		if not buckets.has(k):
			buckets[k] = []
		buckets[k].append(e)
	var player = game.player if not game.strategy else game.strat.ghost   # 1.1.15: в стратегии героя «нет»
	var fac = game.factory
	var any_wave := 0
	var net_on := Net.active()
	# A-4 r7: в сплитскрине монстр тоже выбирает ближайшего героя
	var multi: bool = net_on or (game.split != null and game.split.active)
	var sleep_d := float(DB.setting("sleep_dist", 160.0))
	var hq_p: Vector3 = fac.hq.center() if fac.hq else player.position
	if game.prof_on: game._prof("en.pre", _pt); _pt = Time.get_ticks_usec()
	var dt0 := delta
	var fno := Engine.get_process_frames()
	for e in list.duplicate():
		delta = dt0
		if not e.alive:
			continue
		# дальние монстры (не у героя) думают через кадр — с накопленным временем; вблизи — каждый кадр
		if not (is_instance_valid(e.target) and e.target is Player) and not e.hunt and e.npc == "" and (game.near_any_hero(e.pos) if multi else World.dist(e.pos, game.player.position)) > float(DB.setting("think_far", 45.0)):
			e.skip_dt += dt0
			if (fno + e.think_slot) % 2 != 0:
				continue
			delta = e.skip_dt
		e.skip_dt = 0.0
		if not e.guard and not e.roam and e.npc == "":
			any_wave += 1
		# в сетевой игре монстр выбирает ближайшего героя (своего или чужого)
		if game.strategy and e.target is Player:
			e.target = null
		if multi:
			if e.target != null and not is_instance_valid(e.target):
				e.target = null   # гость отключился
			player = e.target if is_instance_valid(e.target) and e.target is Player else game.nearest_player(e.pos)
		# далеко от героя и базы — «спит»: не думает и не ходит
		if sleep_d > 0.0 and e.target == null and World.dist(e.pos, player.position) > sleep_d and World.dist(e.pos, hq_p) > sleep_d:
			e.moving = false
			continue
		if e.npc != "" and game.npcs and game.npcs.update_npc(e, delta):
			continue
		e.cd -= delta
		e.retarget -= delta
		e.lunge = max(0.0, e.lunge - delta * 4.0)
		if e.flee_t > 0.0:
			# вор убегает от героя с добычей, а через время исчезает вместе с ней
			e.flee_t -= delta
			var away: Vector3 = World.delta(player.position, e.pos)
			away.y = 0.0
			if away.length() > 0.1:
				var ad := away.normalized()
				e.pos += ad * e.speed * 1.15 * delta
				e.moving = true
				e.yaw = lerp_angle(e.yaw, atan2(-ad.z, ad.x), min(1.0, delta * 8.0))
			if e.flee_t <= 0.0:
				e.stolen.clear()
				e.no_loot = true
				vanish(e)
			continue
		_abilities(e, player, delta)
		if e.boost_t > 0.0:
			e.boost_t -= delta
			if e.boost_t <= 0.0:
				e.speed /= e.boost
				e.boost = 1.0
		if e.d.has("rules"):
			MobRules.think(self, e, player, delta)
			if not e.alive:
				continue
		var to_player: float = World.dist(e.pos, player.position) if player.alive else INF
		# погоня надоедает: через «Сколько гонится» монстр отстаёт и какое-то время не замечает героя
		e.calm_t = maxf(0.0, e.calm_t - delta)
		e.chase_t = e.chase_t + delta if e.target == player else 0.0
		e.far_t = e.far_t + delta if e.target == player and to_player > escape_dist() else 0.0
		if e.rule_mode == "" and not e.roam and not e.hunt and e.target == player and ((chase_time() > 0.0 and e.chase_t > chase_time()) or (escape_time() > 0.0 and e.far_t > escape_time())):
			e.target = null
			e.retarget = 0.0
			e.calm_t = float(DB.setting("monster_calm_time", 10.0))
		if e.rule_mode != "":
			if _rule_target(e, player, fac, delta):
				continue
		elif e.hunt and player.alive:
			e.target = player   # «Рёв матери»: идёт на героя, не отстаёт
			e.calm_t = 0.0
		elif e.guard:
			if to_player < 16.0 and e.calm_t <= 0.0:
				e.target = player
			elif e.target == player and (to_player > 45.0 or World.dist(e.pos, e.home) > 50.0):
				e.target = null
		elif e.roam:
			if e.pack.aggro and player.alive:
				e.target = player
			else:
				e.home = e.pack.center + e.slot
				if e.target == player:
					e.target = null
				if e.retarget <= 0.0:
					e.retarget = randf_range(0.8, 1.4)
					if e.target == null or e.target.dead:
						e.target = building_near(e.pos)
		elif e.target != player and e.calm_t <= 0.0 and player.alive and to_player < (25.0 if e.behavior == "player" else 12.0):
			e.target = player   # герой снова рядом — бросает здание и нападает сразу
			e.far_t = 0.0
		elif e.retarget <= 0.0:
			e.retarget = randf_range(0.5, 0.9)
			var aggro := 25.0 if e.behavior == "player" else 12.0
			if to_player < aggro and e.calm_t <= 0.0:
				e.target = player
			elif e.target == player and player.alive and (escape_time() <= 0.0 or e.far_t < escape_time()):
				pass   # гонится, пока герой не убежал на «Дистанцию побега» дольше «Времени побега»
			elif e.behavior == "base" and fac.hq != null:
				e.target = fac.hq
			else:
				var b = building_near(e.pos)
				e.target = b if b != null else fac.hq
		var tp: Vector3
		var reach: float = e.reach
		if e.target == player:
			if not player.alive:
				e.target = null
				e.retarget = 0.0
				continue
			tp = player.position
		elif e.target != null:
			if e.target.hp <= 0.0 or e.target.dead:
				e.target = null
				e.retarget = 0.0
				continue
			tp = e.target.center()
			if not e.ranged:
				reach += e.target.size * C * 0.5
		else:
			tp = e.home + Vector3(sin(Time.get_ticks_msec() * 0.0003 + e.home.x) * 5.0, 0, cos(Time.get_ticks_msec() * 0.00025 + e.yaw) * 5.0)
		var to := World.delta(e.pos, tp)
		to.y = 0.0
		var dist := to.length()
		e.moving = false
		if e.burrow:
			# червь: роет к цели под землёй, у цели вылезает, бьёт и снова прячется
			var up_want := 0.0 if (dist <= reach + 1.0 and e.target != null) else 1.0
			e.under = move_toward(e.under, up_want, delta * 1.6)
			if e.under > 0.3 and dist > reach:
				e.dig_t -= delta
				if e.dig_t <= 0.0:
					e.dig_t = 0.3
					game.fx.dirt(Vector3(e.pos.x, fac.support_at(e.pos), e.pos.z), 0.5 * e.radius)
			if e.under > 0.05 and dist <= reach + 1.0:
				e.cd = maxf(e.cd, 0.2)   # пока вылезает — не бьёт
		if dist > reach and (e.burrow or e.fly):
			var dirb := to / dist
			e.pos += dirb * e.speed * e.slow_k * (0.4 if e.target == null else 1.0) * delta
			e.moving = true
			e.yaw = lerp_angle(e.yaw, atan2(-dirb.z, dirb.x), min(1.0, delta * 8.0))
		elif dist > reach:
			var dir := to / dist
			if e.target != null and e.target != player and game.maze and game.maze.ready:
				# лабиринт: обход стен по полю направлений (нет пути — идёт напрямую и ломает)
				var md: Vector3 = game.maze.dir_at(e.pos)
				if md != Vector3.ZERO:
					dir = md
			var sp: float = e.speed * e.slow_k * (0.4 if e.target == null else 1.0)
			var ahead: Vector2i = World.world_to_cell(e.pos + dir * (e.radius + 0.4))
			var blk = fac.grid.get(ahead)
			if blk == null and fac.support_at(e.pos + dir * (e.radius + 0.4)) - e.pos.y > float(DB.setting("climb_height", 0.7)) + 0.5:
				blk = fac.found_top(ahead)   # высокий фундамент — монстр его ломает
			if blk != null and (not fac.walkable(blk) or blk.beh == "foundation") and blk != e.target and e.target != null:
				e.target = blk
				e.retarget = 3.0
			elif _wet(ahead):
				# в воду монстры не заходят: обходят берегом
				for ang in [0.8, -0.8, 1.6, -1.6, 2.4, -2.4]:
					var d2 := dir.rotated(Vector3.UP, ang)
					if not _wet(World.world_to_cell(e.pos + d2 * (e.radius + 0.4))):
						e.pos += d2 * sp * delta
						e.moving = true
						break
			else:
				e.pos += dir * sp * delta
				e.moving = true
			e.yaw = lerp_angle(e.yaw, atan2(-dir.z, dir.x), min(1.0, delta * 8.0))
		elif e.target != null:
			e.yaw = lerp_angle(e.yaw, atan2(-to.z, to.x), min(1.0, delta * 8.0))
			if e.cd <= 0.0:
				e.cd = e.rate
				if float(e.d.get("explode_damage", 0.0)) > 0.0:
					_explode(e)
					continue
				if e.ranged:
					var from: Vector3 = e.pos + Vector3(0, 1.0, 0)
					var v := (to.normalized() * 18.0) + Vector3(0, dist * 0.28, 0)
					spit.append([from, v, 3.0, e.dmg])
					if rigs.has(e):
						rigs[e].strike()
					game.sfx.play(_snd(e, "attack", "spit"), e.pos)
				else:
					e.lunge = 0.0 if rigs.has(e) else 0.5 * e.radius
					if rigs.has(e):
						rigs[e].strike()
					game.sfx.play(_snd(e, "attack", "bite"), e.pos)
					if e.target == player:
						player.damage(e.dmg)
						if int(e.d.get("steal", 0)) > 0 and e.stolen.is_empty():
							_steal(e, player)
					elif e.npc != "" and game.npcs and game.npcs.on_attack(e):
						pass
					else:
						fac.damage(e.target, e.dmg)
	delta = dt0
	if game.prof_on: game._prof("en.think", _pt); _pt = Time.get_ticks_usec()
	# расталкивание
	for e in list:
		var k := Vector2i(floori(e.pos.x / 3.0), floori(e.pos.z / 3.0))
		var push := Vector3.ZERO
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var bk := k + Vector2i(dx, dz)
				if World.wrap_w > 0:
					var nb := floori(World.wrap_w * World.C / 3.0)
					bk = Vector2i(posmod(bk.x, nb), posmod(bk.y, nb))
				var bl = buckets.get(bk)
				if bl == null:
					continue
				for o in bl:
					if o == e:
						continue
					var d: Vector3 = World.delta(o.pos, e.pos)
					d.y = 0
					var rr: float = e.radius + o.radius
					var l := d.length()
					if l < rr and l > 0.001:
						push += d / l * (rr - l)
		var before: Vector3 = e.pos
		e.pos += push * min(1.0, delta * 6.0)
		if e.kv != Vector3.ZERO:
			_apply_knock(e, delta)
		if not e.burrow and not e.fly and _wet(World.world_to_cell(e.pos)) and not _wet(World.world_to_cell(before)):
			e.pos = before
		if game.world.wrap:
			e.pos = World.wrap_pos(e.pos)
		else:
			e.pos.x = clampf(e.pos.x, 1.0, game.world.W * C - 1.0)
			e.pos.z = clampf(e.pos.z, 1.0, game.world.W * C - 1.0)
		e.pos.y = fac.support_at(e.pos)
		if e.fly:
			var height_factor := 1.0
			if e.d.has("perch_cycle"):
				var cycle := maxf(6.0, float(e.d.perch_cycle))
				e.flight_phase = fmod(e.flight_phase + delta, cycle)
				var phase: float = e.flight_phase / cycle
				height_factor = smoothstep(0.02, 0.12, phase) * (1.0 - smoothstep(0.74, 0.84, phase))
				e.flight_pose = "Takeoff" if phase >= .02 and phase < .12 else "Fly" if phase >= .12 and phase < .74 else "Land" if phase >= .74 and phase < .84 else ""
			e.pos.y += height_factor * (e.fly_h + sin(Time.get_ticks_msec() * 0.002 + e.home.x) * 0.35)
		if e.under > 0.0:
			e.pos.y -= e.under * 2.6 * float(DB.data.enemies.get(e.type, {}).get("scale", 1.0))
		if e.kh > 0.0 or e.kvy > 0.0:
			e.kvy -= 18.0 * delta
			e.kh += e.kvy * delta
			if e.kh <= 0.0:
				e.kh = 0.0
				e.kvy = 0.0
			e.pos.y += e.kh
	if game.prof_on: game._prof("en.push", _pt); _pt = Time.get_ticks_usec()
	_update_spit(delta)
	_update_rigs(delta)
	if game.prof_on: game._prof("en.rigs", _pt); _pt = Time.get_ticks_usec()
	for e in list:
		if rigs.has(e):
			continue
		var r := _renderer(e.type)
		r.set_xform(e, _xf(e))
		# ноги шагают, только пока монстр идёт; в бою — лёгкое переминание
		var want := 1.0 if e.moving else (0.25 if e.target != null else 0.0)
		var na := move_toward(e.act, want, delta * 5.0)
		if absf(na - e.act) > 0.001:
			e.act = na
			r.set_active(e, na)
		if e.flash > 0.0:
			e.flash = max(0.0, e.flash - delta * 6.0)
			r.set_tint(e, 0.0, e.flash)
	if game.prof_on: game._prof("en.render", _pt)
	if wave_live > 0 and any_wave == 0:
		wave_live = 0
		waves_survived += 1
		game.on_wave_cleared(wave)
		game.notify("Волна %d отбита!" % wave, Color(0.5, 1, 0.5))
		game.add_credits(40 + wave * 25, true)


func _update_spit(delta: float) -> void:
	if spit.is_empty():
		return
	var keep := []
	for s in spit:
		var p: Vector3 = s[0]
		var v: Vector3 = s[1]
		v.y -= 22.0 * delta
		var np := p + v * delta
		game.fx.tracer(p, np, Color(0.6, 1.0, 0.2), 0.08)
		s[0] = np
		s[1] = v
		s[2] -= delta
		var hit := false
		var hp_pl = null
		for pl in game.hit_targets():
			if pl.alive and World.dist(np, pl.position) < 1.0 and np.y < pl.position.y + 2.2 and np.y > pl.position.y - 0.5:
				hp_pl = pl
		if hp_pl != null:
			hp_pl.damage(s[3])
			hit = true
		elif np.y <= game.factory.support_at(np) + 0.2:
			var b = game.factory.building_at(World.world_to_cell(np))
			if b != null:
				game.factory.damage(b, s[3])
			hit = true
		if hit:
			game.fx.goo(np, 0.4)
		elif s[2] > 0.0:
			keep.append(s)
	spit = keep



# ---------------------------------------------------------------- живая анимация рядом с героем

## Монстры ближе «Дальности живой анимации» получают скелет (CreatureRig) и двигаются по-настоящему;
## дальше — быстрый общий MultiMesh. Не больше «Сколько монстров анимировать» сразу (ближайшие).
func _update_rigs(delta: float) -> void:
	var pp: Vector3 = game.player.position
	var near_d := minf(float(DB.setting("anim_dist", 60.0)), float(Prefs.get_value("live_anim_dist", 45.0)))
	var max_n := mini(int(DB.setting("anim_max", 40)), int(Prefs.get_value("live_anim_max", 14)))
	var cand := []
	for e in list:
		var md: Dictionary = ModelLib.model(str(DB.data.enemies.get(e.type, {}).get("model", e.type)))
		if not md.has("rig") and not md.get("animated_colony", false):
			continue
		var d := World.dist(e.pos, pp)
		if d < near_d or (rigs.has(e) and d < near_d + 10.0):
			cand.append([d, e])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var keep := {}
	for i in mini(cand.size(), max_n):
		keep[cand[i][1]] = true
	for e in rigs.keys():
		if not keep.has(e):
			_drop_rig(e)
			if e.alive:
				_renderer(e.type).add(e, _xf(e), 1.0)
	for e in keep:
		if not rigs.has(e):
			var rg := CreatureRig.new()
			var ed: Dictionary = DB.data.enemies.get(e.type, {})
			if not rg.build(str(ed.get("model", e.type)), DB.color(ed.get("tint", "#ffffff")), float(ed.get("tint_k", 0.0))):
				rg.free()
				continue
			add_child(rg)
			rigs[e] = rg
			_renderer(e.type).remove(e)
		var rg2: CreatureRig = rigs[e]
		var td := Vector3.ZERO
		var windup := 0.0
		if e.target != null:
			var is_pl: bool = e.target is Player
			var tp: Vector3 = e.target.position if is_pl else e.target.center()
			td = World.delta(e.pos, tp)
			td.y = 0.0
			if td.length() <= e.reach + (0.0 if is_pl else e.target.size * C * 0.5) + 0.3:
				windup = clampf((0.3 - e.cd) / 0.3, 0.0, 1.0)
		var s := float(DB.data.enemies.get(e.type, {}).get("scale", 1.0))
		# дальние — поза пересчитывается реже (через кадр или два), место — каждый кадр
		var de := World.dist(e.pos, pp)
		var every := 1 if de < 16.0 else (2 if de < 30.0 else 3)
		rg2.acc_dt += delta
		if every > 1 and (Engine.get_process_frames() + rg2.slot) % every != 0 and windup <= 0.0 and e.flash <= 0.0:
			rg2.follow(pp + World.delta(pp, e.pos), e.yaw, s)
			continue
		rg2.animate(rg2.acc_dt, pp + World.delta(pp, e.pos), e.yaw, s, {"speed": e.speed, "flight": e.flight_pose, "windup": windup, "flash": e.flash, "target_dir": td})
		rg2.acc_dt = 0.0
		if e.flash > 0.0:
			e.flash = maxf(0.0, e.flash - delta * 6.0)
		rg2.set_flash(e.flash)
	for c in corpses.duplicate():
		var rg3: CreatureRig = c[0]
		var e3: E = c[1]
		var s3 := float(DB.data.enemies.get(e3.type, {}).get("scale", 1.0))
		_corpse_fly(c, delta)
		rg3.animate(delta, pp + World.delta(pp, e3.pos), e3.yaw, s3, {"speed": e3.speed})
		var cst = c[2] if c.size() > 2 else null
		if cst != null and cst.axis != Vector3.ZERO and absf(cst.ang) > 0.01:
			rg3.basis = Basis(cst.axis, cst.ang) * rg3.basis
		if rg3.finished():
			rg3.queue_free()
			corpses.erase(c)


func _drop_rig(e) -> void:
	if rigs.has(e):
		rigs[e].queue_free()
		rigs.erase(e)


# ---------------------------------------------------------------- 21: физика

const Phys = preload("res://scripts/physics21.gd")


## Толчок монстра: по земле (v) и вверх (up). Боссы и тяжёлые сдвигаются меньше.
func knock(e: E, v: Vector3, up: float) -> void:
	if not Phys.on("knock"):
		return
	var heavy := 1.0 + float(DB.data.enemies.get(e.type, {}).get("boss", false)) * 3.0
	e.kv += v / heavy
	if up > 0.0 and not e.fly and not e.burrow:
		e.kvy = maxf(e.kvy, minf(up / heavy, 12.0))
		e.kh = maxf(e.kh, 0.01)


func _apply_knock(e: E, delta: float) -> void:
	var step := e.kv * delta
	var nc := World.world_to_cell(e.pos + step)
	var bb = game.factory.grid.get(nc)
	if bb != null and not game.factory.walkable(bb):
		e.kv = -e.kv * 0.3   # ударился о здание
	elif not (not e.fly and _wet(nc) and not _wet(World.world_to_cell(e.pos))):
		e.pos += step
	e.kv *= maxf(0.0, 1.0 - delta * (2.5 if e.kh > 0.0 else 6.0))
	if e.kv.length() < 0.1:
		e.kv = Vector3.ZERO


## Тело убитого рядом с героем: отлетает по инерции толчка, кувыркается и падает (лапы дёргаются в creature_rig).
func _corpse_fly(c: Array, delta: float) -> void:
	if c.size() < 3:
		var e0: E = c[1]
		var v: Vector3 = e0.kv * 1.2
		var up: float = maxf(e0.kvy, 0.0) + (2.5 if v.length() > 1.5 else 0.0)
		var axis := Vector3.UP.cross(v).normalized() if v.length() > 0.2 else Vector3.ZERO
		c.append({"v": v, "vy": up, "h": e0.kh, "axis": axis, "ang": 0.0, "spin": clampf(v.length() * 0.5, 0.0, 3.5), "on": Phys.on("ragdoll")})
	var st: Dictionary = c[2]
	if not st.on:
		return
	var e3: E = c[1]
	if st.h > 0.0 or st.vy > 0.0:
		st.vy -= 18.0 * delta
		st.h = maxf(0.0, st.h + st.vy * delta)
		if st.h <= 0.0:
			if absf(st.vy) > 3.0:
				st.vy = -st.vy * 0.3   # отскок от земли
				st.h = 0.01
			else:
				st.vy = 0.0
		st.ang += st.spin * delta
	else:
		st.ang = lerpf(st.ang, clampf(st.ang, -1.2, 1.2), minf(1.0, delta * 6.0))   # лёг на бок, не на спину
	var step: Vector3 = st.v * delta
	var bb = game.factory.grid.get(World.world_to_cell(e3.pos + step))
	if bb != null and not game.factory.walkable(bb):
		st.v = -st.v * 0.3
	else:
		e3.pos = World.wrap_pos(e3.pos + step)
	st.v *= maxf(0.0, 1.0 - delta * (1.0 if st.h > 0.0 else 5.0))
	e3.pos.y = game.factory.support_at(e3.pos) + st.h
