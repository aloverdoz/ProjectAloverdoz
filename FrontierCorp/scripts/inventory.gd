class_name Inventory
extends RefCounted
## Инвентарь из ячеек. Размер стака каждого предмета берётся из базы (поле "stack").

signal changed
var ver := 0   # 21: растёт при каждом изменении — машины не перебирают рецепты, пока сырьё не менялось

var slots: Array = []
var avoid: Dictionary = {}   # ячейки, куда новые предметы не кладутся сами (в них закреплены здания)
var allow := Callable()      # какие предметы сюда можно положить (например, только топливо); пусто — любые
var no_fluids := false       # рюкзак героя: жидкости сюда не кладутся (только в канистрах)
## 1.1.16: «Стратегия» — вещей для героя (оружие, еда, аптечки…) нет нигде: не кладутся и не грузятся.
static var no_personal := false


func _init(n := 30) -> void:
	slots.resize(n)
	changed.connect(_on_changed)


## 1.1.11: кто менял ячейки напрямую и звал changed — версия тоже растёт (по ней рассылаются здания гостям).
func _on_changed() -> void:
	ver += 1


func size() -> int:
	return slots.size()


func resize(n: int) -> void:
	slots.resize(n)


## Добавляет предметы. Возвращает, сколько не влезло.
func add(id: String, n: int) -> int:
	if n <= 0 or id == "":
		return 0
	if no_fluids and DB.is_fluid(id):
		return n
	if no_personal and DB.personal_item(id):
		return 0
	var st := DB.stack_of(id)
	for i in slots.size():
		var s = slots[i]
		if s != null and s.id == id and s.n < st:
			var k: int = min(st - s.n, n)
			if s.has("fresh"):
				s["fresh"] = mix_fresh(id, s, k, null)   # A-1 r8: свежие добавки — средняя свежесть
			s.n += k
			n -= k
			if n == 0:
				_bump()
				return 0
	for i in slots.size():
		if slots[i] == null and not avoid.has(i):
			var k: int = min(st, n)
			slots[i] = {"id": id, "n": k}
			n -= k
			if n == 0:
				_bump()
				return 0
	_bump()
	return n


## Положить ячейку целиком: предмет с прочностью или свежестью не теряет своё состояние.
## Возвращает, сколько не влезло.
func add_slot(s: Dictionary) -> int:
	if no_fluids and DB.is_fluid(str(s.get("id", ""))):
		return int(s.n)
	if no_personal and DB.personal_item(str(s.get("id", ""))):
		return 0
	if not (s.has("dur") or s.has("fresh")):
		return add(str(s.id), int(s.n))
	for i in slots.size():
		if slots[i] == null and not avoid.has(i):
			slots[i] = s.duplicate()
			_bump()
			return 0
	return int(s.n)


## A-1 r8: свежесть стопки b после добавления k штук из a (null — только что сделанные, полностью свежие).
static func mix_fresh(id: String, b: Dictionary, k: int, a) -> float:
	var sp := float(DB.item(id).get("spoil", 0))
	var fb := float(b.get("fresh", sp))
	var fa := float(a.get("fresh", sp)) if a is Dictionary else sp
	var nb := int(b.n)
	return (fb * nb + fa * k) / float(maxi(1, nb + k))


func can_add(id: String, n: int) -> bool:
	if no_fluids and DB.is_fluid(id):
		return false
	var st := DB.stack_of(id)
	var room := 0
	for i in slots.size():
		var s = slots[i]
		if s == null:
			if not avoid.has(i):
				room += st
		elif s.id == id:
			room += st - s.n
		if room >= n:
			return true
	return room >= n


func count(id: String) -> int:
	var c := 0
	for s in slots:
		if s != null and s.id == id:
			c += s.n
	return c


## Забирает n предметов. Если не хватает — ничего не забирает и возвращает false.
func remove(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if s != null and s.id == id:
			var k: int = min(s.n, n)
			s.n -= k
			n -= k
			if s.n <= 0:
				slots[i] = null
			if n == 0:
				break
	_bump()
	return true


## Забирает до n предметов, возвращает сколько получилось.
func take_up_to(id: String, n: int) -> int:
	var have := count(id)
	var k: int = min(have, n)
	if k > 0:
		remove(id, k)
	return k


func totals() -> Dictionary:
	var d := {}
	for s in slots:
		if s != null:
			d[s.id] = d.get(s.id, 0) + s.n
	return d


func is_empty() -> bool:
	for s in slots:
		if s != null:
			return false
	return true


func first_item() -> String:
	for s in slots:
		if s != null:
			return s.id
	return ""


func swap(a: int, b: int) -> void:
	var t = slots[a]
	slots[a] = slots[b]
	slots[b] = t
	_bump()


## Для сохранения: вместе с прочностью (dur) и свежестью (fresh).
func to_array() -> Array:
	var out := []
	for s in slots:
		out.append(null if s == null else s.duplicate())
	return out


func from_array(a: Array) -> void:
	slots.resize(max(slots.size(), a.size()))
	for i in a.size():
		var s = a[i]
		if s is Dictionary and s.has("id") and DB.data.items.has(str(s.id)) and not (no_personal and DB.personal_item(str(s.id))):
			var d := {"id": str(s.id), "n": int(s.get("n", 1))}
			if s.has("dur"):
				d["dur"] = float(s.dur)
			if s.has("fresh"):
				d["fresh"] = float(s.fresh)
			slots[i] = d
		else:
			slots[i] = null
	_bump()


## B-7/B-10 r5: перенести до n предметов id в dst, сохраняя износ и свежесть (ячейки с dur/fresh — целиком).
## only_special — только такие ячейки. Возвращает, сколько перенесено.
func move_to(dst, id: String, n: int, only_special := false) -> int:
	var moved := 0
	for i in slots.size():
		if moved >= n:
			break
		var sl = slots[i]
		if sl == null or str(sl.get("id", "")) != id:
			continue
		var special: bool = sl.has("dur") or sl.has("fresh")
		if only_special and not special:
			continue
		var k: int = mini(n - moved, int(sl.n))
		var left: int
		if special:
			var part: Dictionary = (sl as Dictionary).duplicate()
			part["n"] = k
			left = dst.add_slot(part)
		else:
			left = dst.add(id, k)
		var done := k - left
		if done <= 0:
			continue
		sl["n"] = int(sl.n) - done
		if int(sl.n) <= 0:
			slots[i] = null
		moved += done
	if moved > 0:
		_bump()
	return moved


func _bump() -> void:
	ver += 1
	changed.emit()


## 1.5: перенести ячейку (или половину) из одного инвентаря в другой — общий код для окна и для сетевой команды.
## Возвращает "" или почему нельзя.
static func move_between(src: Inventory, si: int, dst: Inventory, di: int, half := false) -> String:
	if src == null or dst == null or si < 0 or di < 0 or si >= src.slots.size() or di >= dst.slots.size():
		return "?"
	if src == dst and si == di:
		return ""
	var a = src.slots[si]
	if a == null:
		return ""
	if dst.allow.is_valid() and not dst.allow.call(str(a.id)):
		return "%s сюда не подходит" % DB.item_name(str(a.id))
	if dst.no_fluids and DB.is_fluid(str(a.id)):
		return "%s сюда не подходит" % DB.item_name(str(a.id))
	var b = dst.slots[di]
	var n: int = a.n / 2 if half else a.n
	if n <= 0:
		return ""
	if b == null:
		dst.slots[di] = a.duplicate()
		dst.slots[di].n = n
		a.n -= n
		if a.n <= 0:
			src.slots[si] = null
	elif b.id == a.id and not a.has("dur") and not b.has("dur"):
		var k: int = min(n, DB.stack_of(a.id) - b.n)
		if k > 0 and (a.has("fresh") or b.has("fresh")):
			b["fresh"] = mix_fresh(str(a.id), b, k, a)   # A-1 r8: свежесть — средняя по штукам
		b.n += k
		a.n -= k
		if a.n <= 0:
			src.slots[si] = null
	elif not half:
		if src.allow.is_valid() and not src.allow.call(str(b.id)):
			return "%s сюда не подходит" % DB.item_name(str(b.id))
		src.slots[si] = b
		dst.slots[di] = a
	src._bump()
	if dst != src:
		dst._bump()
	return ""
