extends RefCounted
## Перевозчики: дроны и грузовики между зданиями с блоком «carrier».
## Отправитель (mode = send) копит предметы, принятые с ленты, и раз в N секунд отправляет партию
## ближайшему получателю того же канала (mode = receive). Получатель выдаёт груз на ленту.

var game
var flights: Array = []    # {node, from: Vector3, to: Vector3, b (получатель), item, n, t, dur, ground}


func _init(g) -> void:
	game = g


static func fleet(b) -> Array:
	return b.bstate.get("freighters", [1, 0, 0, 0, 0])


static func fleet_capacity(b) -> int:
	var tiers: Array = DB.setting("cargo_capacities", [10, 20, 35, 60, 100])
	var total := 0
	var counts := fleet(b)
	for i in mini(counts.size(), tiers.size()):
		total += maxi(0, int(counts[i])) * int(tiers[i])
	return total


func assign(b, tier: int, amount: int) -> int:
	if b == null or b.dead or b.type != "drone_port" or tier < 0 or tier >= 5 or amount <= 0:
		return 0
	var id := "freighter_" + str(tier + 1)
	var n := mini(amount, game.factory.available(id))
	if n > 0:
		game.factory.pay({id: n})
		var counts := fleet(b).duplicate()
		counts[tier] = int(counts[tier]) + n
		b.bstate["freighters"] = counts
	return n


func recall(b, tier: int, amount: int) -> int:
	if b == null or b.dead or b.type != "drone_port" or tier < 0 or tier >= 5 or amount < 1 or airborne(b):
		return 0
	var counts := fleet(b).duplicate()
	var built_in := 1 if tier == 0 else 0
	var quantity := clampi(int(counts[tier]) - built_in, 0, amount)
	counts[tier] = int(counts[tier]) - quantity
	b.bstate["freighters"] = counts
	if quantity > 0:
		game.factory.give_player("freighter_" + str(tier + 1), quantity)
	return quantity


func airborne(b) -> bool:
	for flight in flights:
		if flight.src == b:
			return true
	return false


func launch(from_b, to_b, item: String, n: int, model: String, speed: float, ground: bool, into := "out") -> void:
	var a: Vector3 = from_b.center()
	var z: Vector3 = to_b.center()
	var dist := World.dist(a, z)
	var node: Node3D = ModelLib.make_node(model if not DB.model_def(model).is_empty() else "drone_carrier")
	game.add_child(node)
	node.position = a
	flights.append({"rotors": rotor_nodes(node), "node": node, "from": a, "d": World.delta(a, z), "b": to_b, "src": from_b, "item": item, "n": n, "t": 0.0,
		"model": model, "speed": speed, "dur": maxf(0.5, dist / maxf(1.0, speed)), "ground": ground, "into": into})


func update(delta: float) -> void:
	for f in flights.duplicate():
		f.t += delta
		var k := clampf(f.t / f.dur, 0.0, 1.0)
		var eased := smoothstep(0.0, 1.0, k)
		var p: Vector3 = f.from + f.d * eased
		var node: Node3D = f.node
		if f.ground:
			p.y = game.factory.support_at(p)
		else:
			# взлёт, полёт на высоте, посадка
			var gy: float = game.world.height_at(p)
			p.y = maxf(gy, lerpf(f.from.y, gy, k)) + sin(k * PI) * 9.0 + 1.0
		node.position = p
		pad_pose(f.src, minf(k*8.0,1.0))
		pad_pose(f.b, smoothstep(.78, .94, k)*(1.0-smoothstep(.94, 1.0, k)))
		for rotor in f.get("rotors", []):
			var sign_dir := -1.0 if rotor.get_meta("role") in ["rotor0", "rotor3"] else 1.0
			rotor.rotation.y = sign_dir * f.t * 26.0
		var dd: Vector3 = f.d
		node.rotation.y = atan2(-dd.z, dd.x)
		if not f.ground:
			node.rotation.z = 0.11 * sin(k * TAU)
		if k >= 1.0:
			_arrive(f)


func _arrive(f: Dictionary) -> void:
	flights.erase(f)
	pad_pose(f.src, 0.0)
	pad_pose(f.b, 0.0)
	f.node.queue_free()
	var b = f.b
	var destination = null
	var plain := false
	if b != null and not b.dead:
		destination = b.out if f.get("into", "out") == "out" else dest_inv(b)
		plain = f.get("into", "out") == "out" or b.beh in ["storage", "hq"]
	var source = f.get("src")
	var fallback := []
	if source != null and not source.dead:
		fallback.append(source.inv)
		fallback.append(source.out)
	fallback.append(game.factory._store())
	var manifest: Array = f.get("sl", []).duplicate(true)
	var unpacked := int(f.n)
	for slot in manifest:
		unpacked -= int(slot.n)
	if unpacked > 0:
		manifest.append({"id": f.item, "n": unpacked})
	for slot in manifest:
		if destination is Inventory:
			if plain:
				slot.n = destination.add_slot(slot)
			else:
				while int(slot.n) > 0 and game.factory.would_accept(b, f.item) and game.factory.accept(b, f.item, null):
					slot.n -= 1
		for inv in fallback:
			if int(slot.n) <= 0:
				break
			if inv is Inventory:
				slot.n = inv.add_slot(slot)
		if int(slot.n) > 0:
			game.drops.spawn_slot(slot, f.from + f.d + Vector3.UP)



## Найти получателя для отправителя b (тот же канал, в пределах дальности, есть место).
func find_receiver(b, bl: Dictionary, item: String):
	var best = null
	var bd := INF
	var priority := -1
	var ch := str(b.cfg.get("cargo_channel", bl.get("channel", "A")))
	var r := float(bl.get("range", 80)) * World.C
	for o in game.factory.block_bldgs:
		if o == b or o.dead or o.out == null:
			continue
		for ob in Blocks.of(o.type):
			if str(ob.get("type", "")) == "carrier" and str(ob.get("mode", "send")) == "receive" and str(o.cfg.get("cargo_channel", ob.get("channel", "A"))) == ch:
				var d := World.dist(b.center(), o.center())
				var rank := int(o.cfg.get("cargo_priority", 0))
				if d < r and (rank > priority or (rank == priority and d < bd)) and o.out.can_add(item, 1):
					priority = rank
					bd = d
					best = o
	return best


## Маршруты (блок «route»): здание подходит метке, если метка в его окне совпала или это id его вида.
static func tag_ok(o, tag: String) -> bool:
	return tag != "" and (str(o.cfg.get("tag", "")) == tag or o.type == tag)


## Откуда брать: готовое (выход), а у складов — содержимое.
static func src_inv(o):
	return o.out if o.out != null and not o.out.is_empty() else o.inv


## Куда класть: вход машины или склад; у кого входа нет — выход.
static func dest_inv(o):
	return o.inv if o.inv != null else o.out


## Один рейс по шагу маршрута {item, n, from_tag, to_tag, keep}. true — дрон вылетел.
func route_step(hub, bl: Dictionary, stp: Dictionary) -> bool:
	var r := float(bl.get("range", 120.0)) * World.C
	var want := str(stp.get("item", ""))
	var keep := int(stp.get("keep", 0))
	var src = null
	var it := ""
	var have := 0
	for o in game.factory.all:
		if o.dead or o == hub or not tag_ok(o, str(stp.get("from_tag", ""))) or World.dist(hub.center(), o.center()) > r:
			continue
		var inv = src_inv(o)
		if inv == null:
			continue
		var cand: String = want if want != "" else inv.first_item()
		if cand == "" or inv.count(cand) - keep <= 0:
			continue
		src = o
		it = cand
		have = inv.count(cand) - keep
		break
	if src == null:
		return false
	var dst = null
	for o in game.factory.all:
		if o.dead or o == src or not tag_ok(o, str(stp.get("to_tag", ""))) or World.dist(hub.center(), o.center()) > r:
			continue
		var inv = dest_inv(o)
		if inv != null and game.factory.would_accept(o, it):   # A-5 r8: только то, что здание принимает
			dst = o
			break
	if dst == null:
		return false
	var n := mini(maxi(1, int(stp.get("n", 10))), have)
	# A-8 r6: инструменты/еда — слотами (износ и свежесть), остальное по счёту
	var tmp := Inventory.new(maxi(4, n))
	var moved_sp: int = src_inv(src).move_to(tmp, it, n, true)
	src_inv(src).remove(it, n - moved_sp)
	launch(src, dst, it, n, str(bl.get("model", "drone_carrier")), float(bl.get("speed", 16.0)), bool(bl.get("ground", false)), "in")
	var sl_list := []
	for s0 in tmp.slots:
		if s0 != null:
			sl_list.append(s0)
	flights[-1]["sl"] = sl_list
	return true


func save_flights() -> Array:
	var records := []
	for f in flights:
		var record := {"item": f.item, "n": f.n, "sl": f.get("sl", []).duplicate(true),
			"into": f.into, "model": f.model, "speed": f.speed, "ground": f.ground,
			"elapsed": f.t, "duration": f.dur, "start": [f.from.x, f.from.y, f.from.z],
			"delta": [f.d.x, f.d.y, f.d.z]}
		for key in ["src", "b"]:
			var building = f[key]
			if building != null and not building.dead:
				record[key] = [building.cell.x, building.cell.y]
		records.append(record)
	return records


func restore_flights(records: Array) -> void:
	clear()
	for record in records:
		var model := str(record.model)
		var node := ModelLib.make_node(model if not DB.model_def(model).is_empty() else "drone_carrier")
		game.add_child(node)
		var f: Dictionary = record.duplicate(true)
		for key in ["src", "b"]:
			var cell = record.get(key)
			f[key] = game.factory.building_at(Vector2i(int(cell[0]), int(cell[1]))) if cell is Array else null
		f["node"] = node
		f["rotors"] = rotor_nodes(node)
		f["from"] = Vector3(record.start[0], record.start[1], record.start[2])
		f["d"] = Vector3(record.delta[0], record.delta[1], record.delta[2])
		f["t"] = float(record.elapsed)
		f["dur"] = maxf(0.01, float(record.duration))
		flights.append(f)
	update(0.0)


func clear() -> void:
	for f in flights:
		pad_pose(f.src, 0.0)
		pad_pose(f.b, 0.0)
		f.node.queue_free()
	flights.clear()


func rotor_nodes(node: Node3D) -> Array:
	return node.get_children().filter(func(part): return str(part.get_meta("role", "")).begins_with("rotor"))


func pad_pose(station, amount: float) -> void:
	if station == null or station.dead or station.type not in ["drone_port", "drone_dock"]:
		return
	var r = game.factory.renderer(station.type)
	for i in r.parts_with_role("dockcraft"):
		var xf: Transform3D = r.parts[i].local
		var raised := xf.translated_local(Vector3.UP * amount * .11)
		if station.type == "drone_port":
			raised = raised.scaled_local(Vector3.ONE * (1.0 - .999 * amount))
		r.set_part_xform(station, i, raised)
