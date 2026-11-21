class_name Tuning
extends RefCounted
## 14.23: тонкая настройка зданий — НЕобязательная. Ручка 0..100 в окне здания (по умолчанию 50 — обычная работа, ×1.0).
## У каждого вида настройки (температура печи, обороты бура, pH химзавода…) своя «золотая зона»: в ней бонус
## (быстрее, лишний предмет, дольше горит топливо, сильнее турель, больше энергии). Где зона — в каждом мире своё:
## её ищут по индикатору эффективности, а после открытия «Тонкая настройка» она подсвечена.
## Крайние значения вредят: «холодно» — медленнее, «перегрев» — здание изнашивается.
## Правится: «Настройки → Тонкая настройка» (виды, бонусы, ширина зоны), параметр здания tune, модуль «Тонкая настройка».

static func cfg() -> Dictionary:
	return DB.setting("tuning", {})


static func kind_of(b) -> String:
	return str(b.p("tune", "")) if b != null else ""


static func kind(id: String) -> Dictionary:
	return cfg().get("kinds", {}).get(id, {})


static var _game = null


static func on() -> bool:
	if not bool(cfg().get("enabled", true)):
		return false
	return _game == null or _game.module("tuning")


static func value(b) -> float:
	return float(b.cfg.get("tune", cfg().get("neutral", 50.0)))


## Центр золотой зоны для вида в этом мире (меняется от зерна мира, но не у самой середины).
static func center(id: String) -> float:
	var c := cfg()
	var seed := 0
	if _game != null and _game.world != null:
		seed = int(_game.world.used_seed)
	var h := absi(hash("%s|%d" % [id, seed]))
	var lo := float(c.get("golden_min", 12.0))
	var hi := float(c.get("golden_max", 88.0))
	var nu := float(c.get("neutral", 50.0))
	var w := float(c.get("width", 12.0))
	var g := lo + float(h % 1000) / 1000.0 * (hi - lo)
	if absf(g - nu) < w:   # обычное положение ручки не должно давать бонус «даром»
		g = nu + (w if g >= nu else -w) * 1.2
	return clampf(g, lo, hi)


## Насколько попали в зону: 1 — в центре, 0 — вне зоны.
static func quality(b) -> float:
	var id := kind_of(b)
	if id == "" or not on():
		return 0.0
	var w := float(cfg().get("width", 12.0))
	return clampf(1.0 - absf(value(b) - center(id)) / maxf(1.0, w), 0.0, 1.0)


static func danger(b) -> bool:
	return kind_of(b) != "" and on() and value(b) >= float(cfg().get("danger", 92.0))


static func too_low(b) -> bool:
	return kind_of(b) != "" and on() and value(b) <= float(cfg().get("low", 8.0))


## Множитель для эффекта: speed, output (доля шанса лишнего), fuel, damage, supply.
static func k(b, effect: String) -> float:
	var id := kind_of(b)
	if id == "" or not on():
		return 1.0
	var c := cfg()
	var ef: Dictionary = kind(id).get("effects", {})
	var m := 1.0
	if ef.has(effect):
		m += float(ef[effect]) * quality(b)
	if effect in ["speed", "supply", "damage"]:
		if too_low(b):
			m *= 1.0 - float(c.get("low_pen", 0.25))
		elif danger(b):
			m *= 1.0 - float(c.get("danger_pen", 0.3))
	return m


## Шанс лишнего предмета за цикл.
static func extra_chance(b) -> float:
	return k(b, "output") - 1.0


## Перегрев: здание изнашивается (раз в секунду из factory).
static func wear(f, dt: float) -> void:
	if not on():
		return
	var dps := float(cfg().get("wear_dps", 4.0))
	for b in f.all.duplicate():
		if b.dead or kind_of(b) == "" or not b.cfg.has("tune"):
			continue
		if danger(b) and (b.active or b.beh == "turret"):
			f.damage(b, dps * dt)
			if randf() < 0.5:
				f.game.fx.puff(b.center() + Vector3(0, 1.5, 0), "steam", 0.8)
			f.game.notify_once("tune_wear_" + kind_of(b), "%s: на пределе здание изнашивается. Уменьшите «%s»." % [DB.building(b.type).get("name", b.type), str(kind(kind_of(b)).get("knob", "настройку"))], Color(1, 0.7, 0.3))


static func hinted() -> bool:
	var t := str(cfg().get("hint_tech", "t_tuning"))
	if t == "" or _game == null or _game.tech == null:
		return true
	return _game.tech.done.has(t) or not _game.tech.enabled()


## Текст для окна здания.
static func info(b) -> String:
	var id := kind_of(b)
	var kd := kind(id)
	var q := quality(b)
	var best := 1.0
	for e in ["speed", "supply", "damage", "fuel"]:
		var v := k(b, e)
		if absf(v - 1.0) > absf(best - 1.0):
			best = v
	var t := "Эффективность: [b]%+d%%[/b]" % roundi((best - 1.0) * 100.0)
	if extra_chance(b) > 0.001:
		t += " · лишний предмет: %d%%" % roundi(extra_chance(b) * 100.0)
	if danger(b):
		t += "\n[color=#ff8844]%s: здание изнашивается![/color]" % str(kd.get("hi", "Перегрев"))
	elif too_low(b):
		t += "\n[color=#88aaff]%s: работает медленнее.[/color]" % str(kd.get("lo", "Мало"))
	elif q > 0.85:
		t += "\n[color=#ffd36a]Золотая зона![/color]"
	elif q > 0.0:
		t += "\n[color=#a0e080]Тепло… почти в зоне.[/color]"
	if hinted():
		var c := center(id)
		var w := float(cfg().get("width", 12.0))
		t += "\nЗолотая зона: %d–%d" % [int(c - w * 0.5), int(c + w * 0.5)]
	else:
		t += "\n[color=#8899aa]Зону ищите сами — или откройте «Тонкая настройка».[/color]"
	return t
