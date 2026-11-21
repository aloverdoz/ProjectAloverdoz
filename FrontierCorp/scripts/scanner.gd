extends RefCounted
## Находки и сканирование (13.10). Предмет становится «найденным», как только попал в рюкзак или штаб.
## Найденное сырьё надо отсканировать N штук (поле предмета «Сканировать штук») — после этого оно
## доступно в рецептах. Окно «Сканер» (клавиша I). Правила — «Настройки» → «Сканирование».

var game
var prog := {}        # id -> сколько уже отсканировано
var _t := 0.0


func _init(g) -> void:
	game = g


func cfg() -> Dictionary:
	var c = DB.data.settings.get("scan", {})
	return c if c is Dictionary else {}


func on() -> bool:
	return game.module("scan") and bool(cfg().get("enabled", true))


func setup() -> void:
	DB.discovery = on()
	DB.known.clear()
	DB.researched.clear()
	prog.clear()
	for id in cfg().get("start_known", []):
		DB.known[str(id)] = true
	for id in cfg().get("start_researched", []):
		DB.known[str(id)] = true
		DB.researched[str(id)] = true


## Раз в полсекунды: всё, что лежит у героя и в штабе, — найдено.
func update(delta: float) -> void:
	if not DB.discovery:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var invs := [game.player.inv]
	if game.factory.hq:
		invs.append(game.factory.hq.inv)
	for inv in invs:
		for s in inv.slots:
			if s != null:
				_found(str(s.id))


func _found(id: String) -> void:
	if id == "" or DB.known.has(id):
		return
	DB.known[id] = true
	if DB.scan_need(id) > 0:
		game.notify("Найден новый ресурс: %s. Отсканируйте %d шт. (I — сканер), чтобы использовать его в рецептах" % [DB.item_name(id), DB.scan_need(id)], Color(0.55, 0.85, 1.0))
	game.hud.refresh_open()


## Найденные, но ещё не изученные предметы.
func pending() -> Array:
	var out := []
	for id in DB.known:
		if not DB.is_researched(id):
			out.append(id)
	out.sort_custom(func(a, b): return DB.item_name(a) < DB.item_name(b))
	return out


func progress(id: String) -> int:
	return int(prog.get(id, 0))


## Отсканировать сколько есть (не больше нужного): штуки берутся у героя, потом из штаба.
func scan(id: String) -> int:
	if not DB.discovery or DB.is_researched(id) or not DB.is_known(id):
		return 0
	var need := DB.scan_need(id) - progress(id)
	# A-4 r8: у гостя общий склад штаба — у хозяина; гость сканирует только из своего рюкзака
	var guest := Net.is_client()
	var n := mini(need, game.player.inv.count(id) if guest else game.factory.available(id))
	if n <= 0:
		if guest and game.factory.available(id) > 0:
			game.notify_once("scan_guest", "В сетевой игре гость сканирует только то, что у него в рюкзаке", Color(1, 0.75, 0.4))
		return 0
	if bool(cfg().get("consume", true)):
		if guest:
			game.player.inv.remove(id, n)
			Net._self().report_inv_now()
		else:
			game.factory.pay({id: n})
	prog[id] = progress(id) + n
	if progress(id) >= DB.scan_need(id):
		DB.researched[id] = true
		if Net.active():
			Net._self().share_research(id)   # 18: в сетевой игре изученное — общее, списки рецептов у всех одинаковые
		game.notify("Изучено: %s — теперь его можно использовать в рецептах и постройках" % DB.item_name(id), Color(0.5, 1.0, 0.6))
		game.sfx.play_ui("click")
		game.hud.refresh_open()
	return n


func researched_count() -> int:
	var c := 0
	for id in DB.researched:
		if DB.scan_need(id) > 0:
			c += 1
	return c


# ---------------------------------------------------------------- 1.0.8: этапы сканера
var _st_rev := -1
var _stages: Array = []
var _src := {}


## Этапы (как в дереве открытий): [{tier, name, items: [id...]}] — какое сырьё и детали понадобятся на каждом этапе.
## Предмет попадает на самый ранний этап, где он нужен: цена зданий этапа, рецепты этапа, цена узлов дерева.
func stages() -> Array:
	if _st_rev == DB.revision:
		return _stages
	_st_rev = DB.revision
	_stages = []
	_src = {}
	var nodes: Dictionary = DB.data.get("tech", {})
	var b_tier := {}
	var r_tier := {}
	var it_tier := {}
	var put := func(id: String, t: int) -> void:
		if DB.scan_need(id) > 0 and (not it_tier.has(id) or t < int(it_tier[id])):
			it_tier[id] = t
	for nid in nodes:
		var nd: Dictionary = nodes[nid]
		var t := int(nd.get("tier", 0))
		for bid in nd.get("unlocks", {}).get("buildings", []):
			b_tier[str(bid)] = mini(t, int(b_tier.get(str(bid), 99)))
		for rid in nd.get("unlocks", {}).get("recipes", []):
			r_tier[str(rid)] = mini(t, int(r_tier.get(str(rid), 99)))
		for k in nd.get("cost", {}):
			put.call(str(k), t)
	var st_tier := {"hand": 0}
	for bid in DB.data.buildings:
		var bt := int(b_tier.get(bid, 0))
		var st := str(DB.data.buildings[bid].get("params", {}).get("station", ""))
		if st != "":
			st_tier[st] = mini(bt, int(st_tier.get(st, 99)))
		if bool(DB.data.buildings[bid].get("params", {}).get("buildable", true)):
			for k in DB.data.buildings[bid].get("cost", {}):
				put.call(str(k), bt)
	for rid in DB.data.recipes:
		var r: Dictionary = DB.data.recipes[rid]
		var t := int(r_tier.get(rid, 99))
		if t == 99:
			for st in r.get("stations", []):
				t = mini(t, int(st_tier.get(str(st), 99)))
		if t == 99:
			t = 0
		for k in r.get("in", {}):
			put.call(str(k), t)
		for k in r.get("out", {}):
			if not _src.has(str(k)):
				var sts: Array = r.get("stations", [])
				_src[str(k)] = "делается: " + (game.station_name(str(sts[0])) if not sts.is_empty() and str(sts[0]) != "hand" else "руками")
	for d in DB.data.world.get("deposits", []):
		_src[str(d.get("item", ""))] = "месторождение"
	for rid in DB.data.get("resources", {}):
		for dr in DB.data.resources[rid].get("drops", []):
			if dr is Dictionary and not _src.has(str(dr.get("item", ""))):
				_src[str(dr.get("item", ""))] = "в природе: " + str(DB.data.resources[rid].get("name", rid)).to_lower()
	# когда предмет вообще можно получить: природа и залежи — сразу, рецепт — не раньше станции/узла и своих входов.
	# Этап предмета = позже из двух: когда он впервые нужен и когда его можно добыть (сталь нужна рано, но варится позже).
	var ob := {}
	for d in DB.data.world.get("deposits", []):
		ob[str(d.get("item", ""))] = 0
	for rid in DB.data.get("resources", {}):
		for dr in DB.data.resources[rid].get("drops", []):
			if dr is Dictionary:
				ob[str(dr.get("item", ""))] = 0
	for e in DB.data.get("enemies", {}).values():
		if e is Dictionary:
			for dr in e.get("drops", []):
				if dr is Dictionary and not ob.has(str(dr.get("item", ""))):
					ob[str(dr.get("item", ""))] = 1
	for pass_i in 12:
		var changed := false
		for rid in DB.data.recipes:
			var r: Dictionary = DB.data.recipes[rid]
			var t := int(r_tier.get(rid, 99))
			if t == 99:
				for st in r.get("stations", []):
					t = mini(t, int(st_tier.get(str(st), 99)))
			if t == 99:
				t = 0
			var ok := true
			for k in r.get("in", {}):
				if not ob.has(str(k)):
					ok = false
					break
				t = maxi(t, int(ob[str(k)]))
			if not ok:
				continue
			for k in r.get("out", {}):
				if not ob.has(str(k)) or t < int(ob[str(k)]):
					ob[str(k)] = t
					changed = true
		if not changed:
			break
	for id in it_tier.keys():
		it_tier[id] = maxi(int(it_tier[id]), int(ob.get(id, it_tier[id])))
	var names: Array = DB.setting("tech_ui", {}).get("tier_names", []) if DB.setting("tech_ui", {}) is Dictionary else []
	var by := {}
	for id in it_tier:
		var t := int(it_tier[id])
		if not by.has(t):
			by[t] = []
		by[t].append(id)
	var keys: Array = by.keys()
	keys.sort()
	for t in keys:
		var nm := ""
		if t < names.size():
			nm = str(names[t].get("name", "")) if names[t] is Dictionary else str(names[t])
		if nm == "":
			nm = "Начало" if t == 0 else "Этап %d" % t
		var arr: Array = by[t]
		arr.sort_custom(func(a, b): return str(DB.item(a).get("name", a)) < str(DB.item(b).get("name", b)))
		_stages.append({"tier": t, "name": nm, "items": arr})
	return _stages


## Где взять предмет (подсказка у «Неизвестного ресурса»): месторождение, природа, станция.
func source_hint(id: String) -> String:
	stages()
	var s := str(_src.get(id, ""))
	if s == "":
		s = "с монстров и в подземельях" if str(DB.item(id).get("category", "")) == "Добыча с монстров" else ""
	return s


func to_dict() -> Dictionary:
	return {"known": DB.known.keys(), "researched": DB.researched.keys(), "prog": prog.duplicate()}


func from_dict(d: Dictionary) -> void:
	for id in d.get("known", []):
		DB.known[str(id)] = true
	for id in d.get("researched", []):
		DB.researched[str(id)] = true
	prog = d.get("prog", {}).duplicate()
