extends RefCounted
## Сезоны и выживание (14.7): температура воздуха по сезону и времени суток, холод и жара для героя.
## Греют одежда, костры, печи, обогреватели и горячая еда с кухни; охлаждают лёгкая одежда, охладители и салат.
## Зимой земля в снегу, осенью трава желтеет. Модуль «Климат» (новая игра → модули).
## Правится: «Настройки → Климат», «Настройки → Сезоны», «Предметы» (Одежда), «Здания» (Обогрев), «Рецепты» (Кухня).

var game
var air := 15.0        # воздух, °C
var feel := 15.0       # как чувствует герой (с одеждой, обогревом, едой)
var chill := 0.0       # переохлаждение 0..100
var heat := 0.0        # перегрев 0..100
var near_src := 0.0    # обогрев (+) или охлаждение (−) от зданий рядом
var _t := 0.0
var _snow := 0.0
var _tint := Color(1, 1, 1, 0)
var _vis_init := false


func _init(g) -> void:
	game = g


func cfg() -> Dictionary:
	return DB.setting("climate", {})


func enabled() -> bool:
	return game.module("climate")


## Воздух сейчас: между ночной и дневной температурой сезона (по свету дня).
func air_now() -> float:
	var s: Dictionary = game.season()
	var c := cfg()
	var td := float(s.get("temp_day", c.get("temp_day", 18)))
	var tn := float(s.get("temp_night", c.get("temp_night", 8)))
	var ev: float = game.events.temp_add() if game.events else 0.0
	return lerpf(tn, td, clampf(game.daylight(), 0.0, 1.0)) + ev


func clothes() -> Dictionary:
	var id: String = game.player.clothes
	return DB.item(id) if id != "" else {}


var _heat_r := -1
var _heat_rev := 0


## Обогрев от зданий рядом (костры, печи, обогреватели; охладители — минус).
func heat_at(p: Vector3) -> float:
	var f = game.factory
	var sum := 0.0
	# 21: смотрим только клетки вокруг (раньше — все здания карты, включая тысячи лент)
	if _heat_r < 0 or _heat_rev != DB.data.buildings.size():
		_heat_r = 0
		_heat_rev = DB.data.buildings.size()
		for k in DB.data.buildings:
			var pr: Dictionary = DB.data.buildings[k].get("params", {})
			if float(pr.get("heat", 0.0)) != 0.0:
				_heat_r = maxi(_heat_r, int(ceil(float(pr.get("heat_radius", 5.0)))) + int(DB.data.buildings[k].get("size", 1)))
	var R := _heat_r
	var c0 := World.world_to_cell(p)
	var seen := {}
	for dx in range(-R, R + 1):
		for dz in range(-R, R + 1):
			var b = f.grid.get(World.wc(c0 + Vector2i(dx, dz)))
			if b == null or seen.has(b):
				continue
			seen[b] = true
			var h := float(b.p("heat", 0.0))
			if h == 0.0 or b.dead:
				continue
			sum += _heat_of(f, b, p, h)
	return sum + magma_heat_at(p)


func _heat_of(f, b, p: Vector3, h: float) -> float:
	if true:
		var r := float(b.p("heat_radius", 5.0)) * World.C
		var d := World.dist(b.center(), p)
		if d > r:
			return 0.0
		if float(b.p("power", 0.0)) > 0.0 and not f.shield_on(b):
			return 0.0
		if b.beh == "crafter" and not b.active and b.fuel_t <= 0.0:
			return 0.0   # холодная печь без топлива не греет
		return h * (1.0 - 0.5 * d / maxf(r, 0.01))
	return 0.0


## 17.10: жар от выходов магмы (видимых и ещё не открытых — жарко всё равно). «Настройки» → «Климат» → magma_heat, magma_radius.
func magma_heat_at(p: Vector3) -> float:
	var w = game.world
	var hmax := float(cfg().get("magma_heat", 55.0))
	if w == null or hmax <= 0.0:
		return 0.0
	var rc := int(ceil(float(cfg().get("magma_radius", 4.0))))
	var c0 := World.world_to_cell(p)
	var best := 0.0
	for dx in range(-rc, rc + 1):
		for dz in range(-rc, rc + 1):
			var c: Vector2i = w.wc(c0 + Vector2i(dx, dz))
			if not w.deposit.has(c):
				continue
			if str(w.deposits[w.deposit[c]].get("item", "")) != "magma":
				continue
			var k := 1.0 - Vector2(dx, dz).length() / float(rc + 1)
			best = maxf(best, hmax * clampf(k, 0.0, 1.0))
	return best


## Скорость героя ×: замёрзший двигается медленнее.
func speed_k() -> float:
	if not enabled():
		return 1.0
	var c := cfg()
	var from := float(c.get("slow_from", 60))
	if chill <= from:
		return 1.0
	return 1.0 - float(c.get("slow", 0.3)) * (chill - from) / maxf(1.0, 100.0 - from)


func update(dt: float) -> void:
	_visuals(dt)
	if not enabled():
		chill = 0.0
		heat = 0.0
		return
	_t += dt
	if _t < 0.5:
		return
	step(_t)
	_t = 0.0



## A-7 r5: в сплитскрине у каждого героя свои показатели — считаем по очереди за каждое место.
func _per_hero(fn: Callable, vars: Array) -> bool:
	var sp = game.get("split")
	if sp == null or not sp.running():
		return false
	for i in 2:
		sp.with_seat(i, func():
			var pl = game.player
			if pl != null:
				for k in vars:
					if pl.has_meta("cl_" + k):
						set(k, pl.get_meta("cl_" + k))
				fn.call()
				for k in vars:
					pl.set_meta("cl_" + k, get(k)))
	var me = game.player
	if me != null:
		for k in vars:
			if me.has_meta("cl_" + k):
				set(k, me.get_meta("cl_" + k))
	return true

func step(dt: float) -> void:
	if game.strategy:
		air = air_now()
		feel = air
		near_src = 0.0
		chill = 0.0
		heat = 0.0
		return
	if _per_hero(_step_one.bind(dt), ["air", "near_src", "feel", "chill", "heat"]):
		return
	_step_one(dt)


func _step_one(dt: float) -> void:
	var c := cfg()
	var pl = game.player
	air = air_now()
	near_src = heat_at(pl.position)
	var it := clothes()
	var warm: float = float(it.get("warmth", 0.0)) + game.bonus("warmth")
	var cool: float = float(it.get("cooling", 0.0)) + game.bonus("cooling")
	var cmin := float(c.get("comfort_min", 8))
	var cmax := float(c.get("comfort_max", 30))
	var f := air + near_src
	if f < cmin:
		f = minf(cmin, f + warm)
	elif f > cmax:
		f = maxf(cmax, f - cool) + float(it.get("warmth", 0.0)) * float(c.get("hot_clothes", 0.5))
	# 1.1.15: под навесом штаба, в бункере или под щитом — ни мороза, ни зноя (как от кислотного дождя)
	if game.events != null and game.events.protected(pl.position):
		f = clampf(f, cmin, cmax)
	feel = f
	var rec := float(c.get("recover", 4.0)) * dt
	if feel < cmin:
		chill = minf(100.0, chill + (cmin - feel) * float(c.get("chill_rate", 0.05)) * dt)
		heat = maxf(0.0, heat - rec)
	elif feel > cmax:
		heat = minf(100.0, heat + (feel - cmax) * float(c.get("heat_rate", 0.05)) * dt)
		chill = maxf(0.0, chill - rec)
	else:
		chill = maxf(0.0, chill - rec)
		heat = maxf(0.0, heat - rec)
	if game.flags.get("god", false) or not pl.alive:
		return
	if heat > 30.0 and game.module("survival"):
		pl.water = maxf(0.0, pl.water - float(DB.data.settings.get("thirst_rate", 0.35)) * float(c.get("heat_thirst", 1.5)) * dt * heat / 100.0)
	if chill >= 100.0:
		pl.damage(float(c.get("cold_damage", 3.0)) * dt)
		game.notify_once("cold", "Герой замерзает! Наденьте тёплую одежду, встаньте у костра или обогревателя, съешьте жаркое.", Color(0.6, 0.85, 1.0))
	elif heat >= 100.0:
		pl.damage(float(c.get("heat_damage", 2.0)) * dt)
		game.notify_once("hot", "Герою жарко! Лёгкий костюм, охладитель, салат или тень.", Color(1.0, 0.6, 0.3))
	elif chill > 50.0:
		game.notify_once("chilly", "Холодно: герой мёрзнет и двигается медленнее.", Color(0.6, 0.85, 1.0))


## Снег зимой и цвет травы по сезону (плавно).
func _visuals(dt: float) -> void:
	var s: Dictionary = game.season()
	var want_snow := maxf(float(s.get("snow", 0.0)), game.events.snow if game.events else 0.0)
	var tc := DB.color(str(s.get("tint", "#ffffff")))
	tc.a = float(s.get("tint_k", 0.0))
	var k := 1.0 if not _vis_init else minf(1.0, dt * 0.05)
	_vis_init = true
	_snow = lerpf(_snow, want_snow, k)
	_tint = _tint.lerp(tc, k)
	var gm = game.world.ground_mat if "ground_mat" in game.world else null
	if gm:
		gm.set_shader_parameter("season_snow", _snow)
		gm.set_shader_parameter("season_tint", _tint)
	var gr = game.world.grass_mat if "grass_mat" in game.world else null
	if gr:
		gr.set_shader_parameter("season_snow", _snow)
		gr.set_shader_parameter("season_tint", _tint)
	var gf = game.world.grass_far if "grass_far" in game.world else null
	if gf and is_instance_valid(gf):
		gf.material_override.set_shader_parameter("season_snow", _snow)
		gf.material_override.set_shader_parameter("season_tint", _tint)


## Надеть одежду из рюкзака (прежняя возвращается в рюкзак).
func put_on(id: String) -> bool:
	var pl = game.player
	if id == "" or pl.inv.count(id) <= 0 or str(DB.item(id).get("clothes", "")) == "":
		return false
	pl.inv.remove(id, 1)
	if pl.clothes != "":
		game.factory.give_player(pl.clothes, 1)
	pl.clothes = id
	game.notify("Надето: %s" % DB.item_name(id), Color(0.8, 0.9, 1.0))
	return true


func take_off() -> void:
	var pl = game.player
	if pl.clothes == "":
		return
	game.factory.give_player(pl.clothes, 1)
	game.notify("Снято: %s" % DB.item_name(pl.clothes), Color(0.8, 0.9, 1.0))
	pl.clothes = ""


func text() -> String:
	var s: Dictionary = game.season()
	var t := "%s%+d°" % [(str(s.get("name", "")) + " · ") if not s.is_empty() else "", roundi(air)]
	if absf(feel - air) >= 1.0:
		t += " (ощущается %+d°)" % roundi(feel)
	return t


func to_dict() -> Dictionary:
	return {"chill": chill, "heat": heat}


func from_dict(d: Dictionary) -> void:
	chill = float(d.get("chill", 0.0))
	heat = float(d.get("heat", 0.0))
