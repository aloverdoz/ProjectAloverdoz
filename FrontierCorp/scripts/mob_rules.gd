extends RefCounted
## Правила поведения монстров блоками (14.5): «если … → то …», без программирования.
## У монстра в данных: "rules": [{"if": "hp_below", "n": 0.3, "then": "flee"}, ...].
## Правила проверяются по порядку дважды в секунду; срабатывает первое подходящее.
## Действия «атаковать героя / базу / здание», «бродить», «домой», «убегать» — это режим: он держится,
## пока не сработает другое правило. Остальные действия (лечиться, призвать, позвать своих…) — разовые,
## у них свой «Не чаще, чем раз в, сек».

const CONDS := {
	"always": "Всегда",
	"sees_player": "Герой ближе N м",
	"player_far": "Герой дальше N м",
	"hp_below": "Своё здоровье меньше доли N (0.3 = 30%)",
	"hp_above": "Своё здоровье больше доли N",
	"night": "Ночь",
	"day": "День",
	"allies_near": "Своих рядом (10 м) не меньше N",
	"alone": "Рядом (10 м) нет своих",
	"player_hp_below": "У героя здоровья меньше доли N",
	"near_base": "Штаб ближе N м",
	"wave": "Идёт волна",
	"hit": "Его ударили за последние 2 сек",
	"chance": "Случайно: шанс N в секунду",
	"timer": "Прошло N сек с появления",
}

const ACTS := {
	"attack_player": "Атаковать героя (режим)",
	"attack_base": "Идти на штаб (режим)",
	"attack_building": "Ломать ближайшее здание (режим)",
	"flee": "Убегать от героя (режим)",
	"wander": "Бродить у дома (режим)",
	"go_home": "Вернуться домой (режим)",
	"normal": "Обычное поведение (снять режим)",
	"heal_self": "Подлечиться на «Значение»",
	"summon": "Призвать «Монстра» × «Значение»",
	"teleport": "Телепорт к герою",
	"explode": "Взорваться",
	"call_allies": "Позвать своих в радиусе «Значение» м на героя",
	"speed": "Ускориться в «Значение» раз на 3 сек",
	"say": "Сказать «Текст»",
	"actions": "Действия (как команды консоли)",
}

const MODES := ["attack_player", "attack_base", "attack_building", "flee", "wander", "go_home", "normal"]


## Проверить правила монстра e. Возвращает true, если что-то сработало.
static func think(en, e, player, dt: float) -> bool:
	var rules: Array = e.d.get("rules", [])
	if rules.is_empty():
		return false
	e.rule_t -= dt
	if e.rule_t > 0.0:
		return false
	e.rule_t = 0.5
	for i in rules.size():
		var r: Dictionary = rules[i]
		var cd := float(r.get("cooldown", 0.0))
		if cd > 0.0 and Time.get_ticks_msec() * 0.001 - float(e.rule_last.get(i, -9999.0)) < cd:
			continue
		var ok := _cond(en, e, player, r)
		if bool(r.get("not", false)):
			ok = not ok
		if not ok:
			continue
		e.rule_last[i] = Time.get_ticks_msec() * 0.001
		_act(en, e, player, r)
		if bool(r.get("stop", true)):
			return true
	return true


static func _allies(en, e, r: float) -> int:
	var n := 0
	for o in en.list:
		if o != e and o.alive and o.npc == "" and World.dist(o.pos, e.pos) <= r:
			n += 1
	return n


static func _cond(en, e, player, r: Dictionary) -> bool:
	var n := float(r.get("n", 0.0))
	var g = en.game
	match str(r.get("if", "always")):
		"always":
			return true
		"sees_player":
			return player.alive and World.dist(e.pos, player.position) <= n
		"player_far":
			return not player.alive or World.dist(e.pos, player.position) > n
		"hp_below":
			return e.hp < e.maxhp * n
		"hp_above":
			return e.hp > e.maxhp * n
		"night":
			return g.is_night()
		"day":
			return not g.is_night()
		"allies_near":
			return _allies(en, e, 10.0) >= int(n)
		"alone":
			return _allies(en, e, 10.0) == 0
		"player_hp_below":
			return player.hp < player.maxhp * n
		"near_base":
			return g.factory.hq != null and World.dist(e.pos, g.factory.hq.center()) <= n
		"wave":
			return en.wave_live > 0
		"hit":
			return e.flash > 0.0 or Time.get_ticks_msec() * 0.001 - e.hit_at < 2.0
		"chance":
			return randf() < n * 0.5
		"timer":
			return Time.get_ticks_msec() * 0.001 - e.born_at >= n
	return false


static func _act(en, e, player, r: Dictionary) -> void:
	var g = en.game
	var v := float(r.get("value", 0.0))
	var a := str(r.get("then", "normal"))
	if a in MODES:
		var was: String = e.rule_mode
		match a:
			"attack_player":
				e.target = player
			"attack_base":
				if e.target == null or e.target == player or e.target.dead or e.retarget <= 0.0:
					e.target = g.factory.hq   # здание на пути (retarget > 0) не бросает
			"attack_building":
				if e.target == null or e.target == player or e.target.dead:
					e.target = en.building_near(e.pos)
			"wander":
				if was != "wander":
					e.home = e.pos   # бродит там, где его застало правило
				e.target = null
			"go_home":
				e.home = e.born_pos
				e.target = null
			"flee", "normal":
				e.target = null
		e.rule_mode = "" if a == "normal" else a
		if was != e.rule_mode:
			e.retarget = 0.0
		return
	match a:
		"heal_self":
			e.hp = minf(e.maxhp, e.hp + (v if v > 0.0 else e.maxhp * 0.25))
			g.fx.magic(e.pos, Color(0.3, 1.0, 0.4), 0.7)
		"summon":
			var t := str(r.get("enemy", ""))
			if DB.data.enemies.has(t):
				for i in maxi(1, int(v)):
					var ang := randf() * TAU
					var k = en.spawn(t, e.pos + Vector3(cos(ang), 0, sin(ang)) * randf_range(1.5, 3.0))
					if k:
						k.parent = e
						e.kids += 1
						k.target = e.target if e.target != null else player
						g.fx.magic(k.pos, Color(1.0, 0.3, 0.2))
		"teleport":
			if player.alive:
				g.fx.magic(e.pos, Color(0.7, 0.3, 1.0))
				var ang := randf() * TAU
				e.pos = World.wrap_pos(player.position + Vector3(cos(ang), 0, sin(ang)) * randf_range(2.5, 4.0))
				g.fx.magic(e.pos, Color(0.7, 0.3, 1.0))
		"explode":
			en._explode(e)
		"call_allies":
			var rr := v if v > 0.0 else 15.0
			for o in en.list:
				if o != e and o.alive and o.npc == "" and World.dist(o.pos, e.pos) <= rr:
					o.target = player
					o.calm_t = 0.0
		"speed":
			if e.boost_t <= 0.0:
				e.boost = maxf(1.0, v if v > 0.0 else 1.5)
				e.speed *= e.boost
			e.boost_t = 3.0
		"say":
			var txt := str(r.get("text", ""))
			if txt != "" and World.dist(e.pos, player.position) < 40.0:
				g.notify("%s: %s" % [str(e.d.get("name", e.type)), txt], Color(1.0, 0.8, 0.6))
		"actions":
			if g.console:
				var c: Vector2i = World.world_to_cell(e.pos)
				g.console.run_actions(r.get("actions", []), {"x": c.x, "z": c.y})
