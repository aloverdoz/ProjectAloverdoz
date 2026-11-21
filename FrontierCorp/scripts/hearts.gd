extends RefCounted
## 1.1.15: «Сердца» — предел размера базы (оба режима: с героем и «Стратегия»).
##  • штаб даёт место под 20 зданий, каждое «Сердце» — ещё под 25 (settings.heart_limit);
##  • ленты, стены, полы, фундаменты, опоры, трубы, разделители, рельсы, фонари и украшения не считаются;
##  • сердца ставятся не ближе «gap» клеток друг к другу;
##  • разрушенное (не снесённое) сердце рушит 10 ближайших к нему зданий; если среди них другое сердце —
##    оно тоже рушится и тянет свои 10: цепная реакция.

const FREE := ["belt", "pole", "wall", "pipe", "foundation", "floor", "splitter", "merger", "junction", "rails",
	"decor", "light", "hq", "heart", "vehicle"]

var game
var _frame := -1
var _n := -1
var _used := 0
var _cap := 0
var _beat := 0.0
var _doomed := {}   # здания, которые уже рушатся по цепочке (второе сердце берёт следующие 10)


func _init(g) -> void:
	game = g


static func cfg() -> Dictionary:
	var c = DB.setting("heart_limit", {})
	return c if c is Dictionary else {}


func on() -> bool:
	return bool(cfg().get("enabled", true))


static func counted(beh: String, type := "") -> bool:
	if beh == "decor" and type != "":
		# 1.1.20 B14-5: бесплатны только настоящие украшения; машины с поведением «decor» (лаборатория, купол, барьер…) — считаются
		var cat := str(DB.building(type).get("category", ""))
		return not (cat in ["decor", ""] or type in ["trap_mine", "searchlight"])
	return not beh in FREE


func _count() -> void:
	if _frame == Engine.get_process_frames() and _n == game.factory.all.size():
		return
	_frame = Engine.get_process_frames()
	_n = game.factory.all.size()
	var c := cfg()
	var used := 0
	var hqs := 0
	var hearts := 0
	for b in game.factory.all:
		if b.dead or b.p("wild", false):
			continue
		if b.beh == "hq" or b.type == "outpost":
			hqs += 1   # аванпост своей базы в сетевой игре — как штаб
		elif b.beh == "heart":
			hearts += 1
		elif counted(b.beh, b.type):
			used += 1
	_used = used
	_cap = hqs * int(c.get("hq", 20)) + hearts * int(c.get("heart", 25))


func used() -> int:
	_count()
	return _used


func cap() -> int:
	_count()
	return _cap


## Почему нельзя поставить (пусто — можно).
func why(type: String, cell: Vector2i) -> String:
	if not on() or game.factory.loading:
		return ""
	var beh := str(DB.building(type).get("behavior", ""))
	if beh == "heart":
		var gap := int(cfg().get("gap", 2))
		for b in game.factory.all:
			if b.beh == "heart" and not b.dead:
				var d: Vector3 = World.delta(World.cell_to_world(b.cell), World.cell_to_world(cell)) / World.C
				if maxf(absf(d.x), absf(d.z)) <= gap:
					return DB.t(DB.tx("heart_gap", "Сердца ставятся не ближе {n} клеток друг к другу"), {"n": gap})
		return ""
	if not counted(beh, type) or type == "outpost":
		return ""
	if used() >= cap():
		return DB.t(DB.tx("heart_full", "Нет места: зданий {u} из {c}. Поставьте «Сердце» — ещё 25 мест"), {"u": used(), "c": cap()})
	return ""


func text() -> String:
	if not on():
		return ""
	return DB.t(DB.tx("heart_count", "Зданий {u} / {c}"), {"u": used(), "c": cap()})


## Сердце разрушено (не снесено): рушатся ближайшие здания, другие сердца среди них — по цепочке.
func on_destroyed(b) -> void:
	if b.beh != "heart" or not on() or Net.is_client():
		return
	var c := cfg()
	var n := int(c.get("chain_n", 10))
	var at: Vector3 = b.center()
	var cand := []
	for o in game.factory.all:
		if o == b or o.dead or _doomed.has(o) or o.beh == "hq" or o.type == "outpost" or o.p("wild", false):
			continue
		if not (counted(o.beh, o.type) or o.beh == "heart"):
			continue
		cand.append([World.dist(at, o.center()), o])
	cand.sort_custom(func(x, y): return x[0] < y[0])
	cand = cand.slice(0, n)
	for e in cand:
		_doomed[e[1]] = true
	game.notify(DB.tx("heart_broken", "Сердце разрушено! Рушатся ближайшие здания"), Color(1, 0.35, 0.4))
	game.fx.explosion(at + Vector3(0, 1.5, 0), 3.0, Color(1.0, 0.2, 0.3))
	game.add_trauma(0.5)
	var delay := float(c.get("chain_delay", 0.12))
	var tree: SceneTree = game.get_tree()
	for i in cand.size():
		var o = cand[i][1]
		if i == 0 or delay <= 0.0 or tree == null:
			_crush(o)
		else:
			tree.create_timer(delay * i).timeout.connect(_crush.bind(o))


func _crush(o) -> void:
	_doomed.erase(o)
	if o == null or o.dead or o.hp <= 0.0 or not is_instance_valid(game):
		return
	game.factory.damage(o, o.hp + 1.0e6)   # обычное разрушение: обломки, руины, по сети — всем


## Сердца бьются: двойной толчок, как у настоящего.
func update(delta: float) -> void:
	_beat = fmod(_beat + delta * 1.15, 1.0)
	var ph := _beat
	var k := 1.0 + 0.13 * exp(-pow(ph - 0.08, 2.0) / 0.0018) + 0.08 * exp(-pow(ph - 0.3, 2.0) / 0.0018)
	var r = game.factory.renderers.get("heart")
	if r == null:
		return
	var idx: Array = r.parts_with_role("heart")
	if idx.is_empty():
		return
	var pv := Vector3(0, 1.55, 0)
	var sx := Transform3D(Basis().scaled(Vector3.ONE * k), pv - pv * k)
	for b in game.factory.all:
		if b.beh == "heart" and not b.dead:
			for i in idx:
				r.set_part_xform(b, i, sx * r.parts[i].local)
