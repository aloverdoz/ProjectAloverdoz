class_name Tech
extends RefCounted
## Дерево открытий и задания орбитальной станции.
## Узлы дерева — тип данных «tech»: ступень, условия (другие узлы, задание станции, день),
## цена (предметы сдаются частями, кредиты, очки исследований) и что открывает (здания, рецепты, месторождения).
## Всё, что упомянуто в «Открывает» хотя бы одного узла, закрыто, пока узел не открыт; остальное открыто сразу.
## Задания станции — тип данных «contracts»: сдать предметы, построить, продержаться N волн.

var game
var done := {}          # открытые узлы: id -> true
var paid := {}          # сколько уже сдано: id узла -> {предмет: n}
var target := ""        # узел, на который работает терминал открытий (ленты везут туда)
var research := 0       # очки исследований
var c_done := {}        # выполненные задания станции
var c_paid := {}        # сдано по заданию: id -> {предмет: n}
var c_start := {}       # с какой отметки считать (волны): id -> число
var _locks_rev := -1
var patterns := {}      # 14.23: собранные узоры инженерного стола: id -> true
var rare := {}          # редкие здания, открытые чертежами из подземелий: id -> true


func _init(g) -> void:
	game = g


func enabled() -> bool:
	return bool(DB.setting("tech_tree", true)) and not DB.data.get("tech", {}).is_empty()


## Открыть всё без сообщений (проверки, старые сохранения, выключенное дерево).
func unlock_all() -> void:
	for id in nodes():
		if not demo_closed(id):
			done[id] = true
	refresh_locks()


func nodes() -> Dictionary:
	return DB.data.get("tech", {})


func contracts() -> Dictionary:
	return DB.data.get("contracts", {})


## Узлы по ступеням и порядку.
func sorted_ids() -> Array:
	var ids: Array = nodes().keys()
	ids.sort_custom(func(a, b):
		var na: Dictionary = nodes()[a]
		var nb: Dictionary = nodes()[b]
		if int(na.get("tier", 0)) != int(nb.get("tier", 0)):
			return int(na.get("tier", 0)) < int(nb.get("tier", 0))
		return int(na.get("order", 0)) < int(nb.get("order", 0)))
	return ids


static var lock_rev := 0


## Пересчитать, что закрыто (DB.locked видят меню стройки, крафт и машины).
func refresh_locks() -> void:
	var lk := {}
	if enabled():
		for id in nodes():
			if done.has(id) or bool(nodes()[id].get("start", false)):
				continue
			var u: Dictionary = nodes()[id].get("unlocks", {})
			for b in u.get("buildings", []):
				lk["b:" + str(b)] = id
			for r in u.get("recipes", []):
				lk["r:" + str(r)] = id
			for d in u.get("deposits", []):
				lk["d:" + str(d)] = id
		# открытое хоть одним открытым узлом — открыто
		for id in nodes():
			if not (done.has(id) or bool(nodes()[id].get("start", false))):
				continue
			var u: Dictionary = nodes()[id].get("unlocks", {})
			for b in u.get("buildings", []):
				lk.erase("b:" + str(b))
			for r in u.get("recipes", []):
				lk.erase("r:" + str(r))
			for d in u.get("deposits", []):
				lk.erase("d:" + str(d))
	# редкие здания (в данных «Редкое — только по чертежу») закрыты, пока не найден чертёж
	# если подземелья выключены, редкое здание, которое есть в дереве открытий, открывается обычным исследованием
	var by_tech := {}
	if not bool(DB.setting("dungeons", {}).get("enabled", false)):
		for id in nodes():
			for bb in nodes()[id].get("unlocks", {}).get("buildings", []):
				by_tech[str(bb)] = true
	for id in DB.data.buildings:
		if rare.has(id):
			lk.erase("b:" + str(id))
		elif bool(DB.data.buildings[id].get("rare", false)) and not by_tech.has(str(id)):
			lk["b:" + str(id)] = "__rare"
	# 14.23: улучшенные рецепты закрыты, пока не собран их узор на инженерном столе
	for rid in DB.data.recipes:
		var pid := str(DB.data.recipes[rid].get("pattern", ""))
		if pid != "" and not patterns.has(pid):
			lk["r:" + str(rid)] = "__pattern"
	# 1.3: демо-версия — всё, что открывают этапы дальше demo.max_tier, закрыто насовсем (даже чертежами и читами)
	var mt := demo_max()
	if mt >= 0:
		var ok := {}
		for id in nodes():
			if int(nodes()[id].get("tier", 0)) <= mt:
				var u: Dictionary = nodes()[id].get("unlocks", {})
				for b in u.get("buildings", []): ok["b:" + str(b)] = true
				for r in u.get("recipes", []): ok["r:" + str(r)] = true
				for d in u.get("deposits", []): ok["d:" + str(d)] = true
		for id in nodes():
			if int(nodes()[id].get("tier", 0)) > mt:
				var u: Dictionary = nodes()[id].get("unlocks", {})
				for b in u.get("buildings", []):
					if not ok.has("b:" + str(b)): lk["b:" + str(b)] = "__demo"
				for r in u.get("recipes", []):
					if not ok.has("r:" + str(r)): lk["r:" + str(r)] = "__demo"
				for d in u.get("deposits", []):
					if not ok.has("d:" + str(d)): lk["d:" + str(d)] = "__demo"
		for k in lk.keys():
			if lk[k] == "__rare":
				lk[k] = "__demo"
	# 1.1.15: открылись или закрылись залежи — перерисовать пятна (у гостей, после «Открыть все технологии» и т. п.;
	# раньше перерисовывал только путь обычного изучения у хозяина)
	var dep_changed := false
	for k in lk:
		if str(k).begins_with("d:") and not DB.locked.has(k):
			dep_changed = true
	for k in DB.locked:
		if str(k).begins_with("d:") and not lk.has(k):
			dep_changed = true
	if lk.hash() != DB.locked.hash():
		lock_rev += 1   # 1.1.15: меню стройки и крафта пересобираются только когда что-то открылось/закрылось
	DB.locked = lk
	_locks_rev = DB.revision
	if dep_changed and game != null and is_instance_valid(game) and game.world != null and game.world.deposits.size() > 0:
		game.world.reveal_deposits()


## 1.3: демо-версия. Сборка с признаком «demo» (пресет «Демо»), ключ --demo или правило settings.demo.enabled.
## Возвращает последний доступный этап дерева открытий или -1, если это полная игра.
static func demo_max() -> int:
	var d = DB.setting("demo", {})
	var on: bool = OS.has_feature("demo") or "--demo" in OS.get_cmdline_user_args() or (d is Dictionary and bool(d.get("enabled", false)))
	if not on:
		return -1
	return int(d.get("max_tier", 3)) if d is Dictionary else 3


static func demo_text() -> String:
	var d = DB.setting("demo", {})
	return str(d.get("text", "Ожидайте релиз!")) if d is Dictionary else "Ожидайте релиз!"


## Узел за пределами демо-версии.
func demo_closed(id: String) -> bool:
	var mt := demo_max()
	return mt >= 0 and int(nodes().get(id, {}).get("tier", 0)) > mt


func check_rev() -> void:
	if _locks_rev != DB.revision:
		refresh_locks()


static func building_locked(id: String) -> bool:
	return DB.locked.has("b:" + id)


static func recipe_locked(id: String) -> bool:
	return DB.locked.has("r:" + id)


## Узел, который открывает здание или рецепт (для подсказки «Откройте: …»).
func opener(kind: String, id: String) -> String:
	var nid: String = str(DB.locked.get(kind + ":" + id, ""))
	if nid == "__demo":
		return demo_text()
	if nid == "__rare":
		return "редкий чертёж — ищите в подземельях"
	return str(nodes().get(nid, {}).get("name", nid))


## Чертёж из подземелья: открыть редкое здание.
func unlock_rare(id: String) -> bool:
	if not DB.data.buildings.has(id) or rare.has(id):
		return false
	rare[id] = true
	refresh_locks()
	return true


## Сколько осталось сдать по узлу: {предмет: n}.
func left_of(id: String) -> Dictionary:
	var out := {}
	var cost: Dictionary = nodes().get(id, {}).get("cost", {})
	var p: Dictionary = paid.get(id, {})
	for k in cost:
		var n := int(cost[k]) - int(p.get(k, 0))
		if n > 0:
			out[k] = n
	return out


## Почему узел пока нельзя открыть (пусто — условия выполнены, осталось заплатить).
func animate_site(id: String) -> void:
	var type := research_site(id)
	for b in game.factory.all:
		if b.type == type and not b.dead:
			b.bstate["scan_time"] = 4.0
			return


func research_site(id: String) -> String:
	return "tech_terminal" if not nodes().get(id, {}).get("unlocks", {}).get("buildings", []).is_empty() else "research_lab"

func why_not(id: String) -> String:
	var n: Dictionary = nodes().get(id, {})
	if demo_closed(id):
		return "Демо-версия: %s" % demo_text()
	var site := research_site(id)
	if game.factory != null and not game.factory.all.any(func(b): return b.type == site and not b.dead):
		return "Для исследования постройте «%s»" % DB.building(site).get("name", site)
	var miss := []
	var free := bool(DB.setting("tech_ui", {}).get("free", true))   # 15.1: свободный порядок — «нужно сначала» не держит
	for r in ([] if free else n.get("requires", [])):
		if not done.has(r) and not bool(nodes().get(r, {}).get("start", false)):
			miss.append(str(nodes().get(r, {}).get("name", r)))
	if not miss.is_empty():
		return "Сначала откройте: " + ", ".join(miss)
	var cq := str(n.get("contract", ""))
	if cq != "" and not c_done.has(cq):
		return "Нужно выполнить задание станции «%s»" % contracts().get(cq, {}).get("name", cq)
	var day := int(n.get("day", 0))
	if day > 0 and game.day_n < day:
		return "Станет доступно на %d-й день" % day
	return ""


func state(id: String) -> String:
	if done.has(id) or bool(nodes().get(id, {}).get("start", false)):
		return "done"
	return "locked" if why_not(id) != "" else "open"


## Сдать в терминал всё, что есть (сначала со склада штаба, потом из рюкзака). Возвращает, сколько сдано.
func donate(id: String) -> int:
	if state(id) != "open":
		return 0
	var moved := 0
	var p: Dictionary = paid.get(id, {})
	for k in left_of(id):
		var need: int = left_of(id)[k]
		var take := 0
		var home: Inventory = game.home_inv()   # B-7 r3: в «своих базах» — склад своей базы
		if home != null:
			take += home.take_up_to(k, need)
		if take < need:
			take += game.player.inv.take_up_to(k, need - take)
		if take > 0:
			p[k] = int(p.get(k, 0)) + take
			moved += take
	paid[id] = p
	if moved > 0:
		animate_site(id)
	try_finish(id)
	return moved


## Терминал принимает предметы с ленты для выбранного узла.
func accept_item(item: String) -> bool:
	if target == "" or state(target) != "open":
		return false
	if int(left_of(target).get(item, 0)) <= 0:
		return false
	var p: Dictionary = paid.get(target, {})
	p[item] = int(p.get(item, 0)) + 1
	paid[target] = p
	try_finish(target)
	return true


## Открыть узел, если всё сдано и хватает кредитов и очков исследований.
func try_finish(id: String) -> bool:
	if state(id) != "open" or not left_of(id).is_empty():
		return false
	var n: Dictionary = nodes()[id]
	var cr := int(n.get("credits", 0))
	var rp := int(n.get("research", 0))
	if game.credits < cr or research < rp:
		return false
	game.credits -= cr
	research -= rp
	unlock(id)
	return true


func study_calibration(b) -> bool:
	if b == null or b.dead or Tuning.kind_of(b) == "" or not Tuning.hinted():
		return false
	var key := "calibration_" + str(b.type)
	var points := int(Tuning.cfg().get("calibration_research", 18))
	var price := int(Tuning.cfg().get("calibration_credits", 600))
	if done.has(key) or research < points or game.credits < price:
		return false
	research -= points
	game.credits -= price
	done[key] = true
	b.cfg["tune"] = Tuning.center(Tuning.kind_of(b))
	return true


func unlock(id: String) -> void:
	if demo_closed(id):
		return
	done[id] = true
	paid.erase(id)
	if target == id:
		target = ""
	refresh_locks()
	var n: Dictionary = nodes().get(id, {})
	game.notify("Открыто: %s" % n.get("name", id), Color(0.55, 1, 0.75))
	game.sfx.play_ui("click")
	for d in n.get("unlocks", {}).get("deposits", []):
		game.notify("Открыт орбитальный заказ ресурса «%s»" % DB.item_name(str(d)), Color(1, 0.85, 0.5))
	if game.hud:
		game.hud.refresh_open()
	_demo_check()


## Демо: всё доступное открыто — поздравить и сказать, что дальше будет в полной версии.
func _demo_check() -> void:
	var mt := demo_max()
	if mt < 0:
		return
	for id in nodes():
		if int(nodes()[id].get("tier", 0)) <= mt and not done.has(id) and not bool(nodes()[id].get("start", false)):
			return
	if game.has_method("celebrate"):
		game.celebrate(DB.tx("demo_done", "ДЕМО ПРОЙДЕНО"), demo_text() + "\n" + "Этапы %d–9 откроются в полной версии." % (mt + 1), Color(1.0, 0.8, 0.35))
	game.notify(demo_text(), Color(1.0, 0.8, 0.35))


# ---------------------------------------------------------------- задания станции

func c_state(id: String) -> String:
	if c_done.has(id):
		return "done"
	var c: Dictionary = contracts().get(id, {})
	for r in c.get("requires", []):
		if not done.has(r) and not bool(nodes().get(r, {}).get("start", false)):
			return "locked"
	var day := int(c.get("day", 0))
	if day > 0 and game.day_n < day:
		return "locked"
	return "open"


## Прогресс задания: [сейчас, нужно].
func c_progress(id: String) -> Array:
	var c: Dictionary = contracts().get(id, {})
	var need := int(c.get("n", 1))
	match str(c.get("goal", "deliver")):
		"deliver":
			return [int(c_paid.get(id, {}).get(str(c.get("item", "")), 0)), need]
		"build":
			var types: Array = c.get("buildings", [])
			var have := 0
			for b in game.factory.all:
				if b.type in types:
					have += 1
			return [have, need]
		"survive":
			if not c_start.has(id):
				c_start[id] = game.enemies.waves_survived
			return [game.enemies.waves_survived - int(c_start[id]), need]
	return [0, need]


## Сдать предметы по заданию (со склада штаба, потом из рюкзака).
func c_deliver(id: String) -> int:
	if c_state(id) != "open":
		return 0
	var c: Dictionary = contracts()[id]
	if str(c.get("goal", "deliver")) != "deliver":
		return 0
	var item := str(c.get("item", ""))
	var pr := c_progress(id)
	var need: int = pr[1] - pr[0]
	var take := 0
	var home2: Inventory = game.home_inv()   # B-7 r3
	if home2 != null:
		take += home2.take_up_to(item, need)
	if take < need:
		take += game.player.inv.take_up_to(item, need - take)
	var p: Dictionary = c_paid.get(id, {})
	p[item] = int(p.get(item, 0)) + take
	c_paid[id] = p
	c_check(id)
	return take


func c_check(id: String) -> void:
	if c_state(id) != "open":
		return
	var pr := c_progress(id)
	if pr[0] < pr[1]:
		return
	var c: Dictionary = contracts()[id]
	c_done[id] = true
	_pay_contract(int(c.get("reward", 0)))
	research += int(c.get("research", 0))
	game.notify("Задание станции выполнено: %s  +%d кр%s" % [c.get("name", id), int(c.get("reward", 0)),
		(" +%d очков исследований" % int(c.get("research", 0))) if int(c.get("research", 0)) > 0 else ""], Color(0.55, 1, 0.75))
	if game.hud:
		game.hud.refresh_open()


## B-5 r4: награда за задание станции. Свои кошельки и задание выполнено не командой игрока —
## делим поровну между всеми в комнате (на выделенном сервере — между гостями).
func _pay_contract(rw: int) -> void:
	var N = Net._self()
	if rw <= 0:
		return
	if not (Net.is_host() and N.own_wallets() and N.actor == 0):
		game.credits += rw
		return
	var who: Array = []
	if not N.dedicated:
		who.append("")
	for pid in N.peers:
		if pid != 1 and pid != N.my_id():
			who.append(str(N.peers[pid].nick))
	if who.is_empty():
		return
	var part := maxi(1, rw / who.size())
	for nk in who:
		if nk == "":
			game.credits += part
		else:
			N.wallets[nk] = int(N.wallets.get(nk, 0)) + part


var _acc := 0.0
func update(dt: float) -> void:
	if Net.is_client():
		return   # B-5 r4: задания станции проверяет хозяин (у гостя награда появлялась и откатывалась)
	_acc += dt
	if _acc < 1.0:
		return
	_acc = 0.0
	check_rev()
	for id in contracts():
		if c_state(id) == "open" and str(contracts()[id].get("goal", "deliver")) != "deliver":
			c_check(id)


func to_dict() -> Dictionary:
	return {"patterns": patterns.keys(), "done": done.keys(), "paid": paid, "target": target, "research": research, "c_done": c_done.keys(), "c_paid": c_paid, "c_start": c_start, "rare": rare.keys()}


func from_dict(d: Dictionary) -> void:
	patterns.clear()
	for id in d.get("patterns", []):
		patterns[str(id)] = true
	done.clear()
	for id in d.get("done", []):
		done[str(id)] = true
	paid = {}
	var pd: Dictionary = d.get("paid", {})
	for id in pd:
		var m := {}
		for k in pd[id]:
			m[k] = int(pd[id][k])
		paid[id] = m
	target = str(d.get("target", ""))
	research = int(d.get("research", 0))
	c_done.clear()
	for id in d.get("c_done", []):
		c_done[str(id)] = true
	c_paid = {}
	var cp: Dictionary = d.get("c_paid", {})
	for id in cp:
		var m2 := {}
		for k in cp[id]:
			m2[k] = int(cp[id][k])
		c_paid[id] = m2
	c_start = {}
	var cs: Dictionary = d.get("c_start", {})
	for id in cs:
		c_start[id] = int(cs[id])
	rare.clear()
	for id in d.get("rare", []):
		rare[str(id)] = true
	refresh_locks()
