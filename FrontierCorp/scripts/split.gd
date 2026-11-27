extends Node
## 1.3: сплитскрин в одной копии игры. Второй игрок жмёт Start на своём геймпаде (или «Пауза → Добавить игрока»):
## экран делится на две половины, у каждой своя камера, свой интерфейс и свой герой, мир и база общие.
## Устроено «местами» (seat): у игры одни поля player, hud, camera, cam_*, стройка и наведение — перед работой
## за место use(i) подставляет в игру поля этого места и запоминает поля прежнего. Ввод второго игрока приходит
## только с его геймпада (события с device = Pad.MARK + 1), клавиатура и мышь — у первого.

var game
var active := false
var seats: Array = [{}, {}]      # поля игры каждого места (SEAT_VARS)
var cur := 0                     # чьи поля сейчас в игре
var pad_dev := -1                # геймпад второго игрока
var pad2                         # его pad.gd (свой, без общих действий ввода)
var views: Array = []            # [SubViewportContainer, SubViewport] на место
var box: HBoxContainer
var layer: CanvasLayer
var p2_start_inv: Array = []     # вещи второго героя из сохранения
var p2_start_extra: Dictionary = {}   # A-8 r7: одежда, уровень рюкзака, здоровье, еда и вода второго

const SEAT_VARS := ["player", "hud", "camera", "cam_yaw", "cam_yaw_target", "cam_dist", "cam_dist_target", "strategy_zoom", "explorer_zoom", "cam_focus",
	"cam_pitch_override", "zoom_home", "edge_off", "build_type", "build_dir", "demolish", "wiring", "zone_pick", "wire_from",
	"wire_line", "ghost", "hover_cell", "hover_point", "lmb", "rmb", "drag_last", "drag_placed", "trauma", "_cam_lead",
	"_ghost_cell", "target", "target_ring", "top_view", "wire_hl", "wire_flash", "wire_flash_b", "_hl_pool", "_spoil_acc"]
const VIEW_LAYER := [11, 12]     # слои отрисовки, которые видит только своя камера (земля и трава вокруг героя)


func _init(g) -> void:
	game = g
	name = "Split"


func _ready() -> void:
	Pad.join_request.connect(start)


func running() -> bool:
	return active


## Оба героя (для монстров, подбора, укрытий), в каком бы месте ни была сейчас игра.
func local_players() -> Array:
	if not active:
		return [game.player]
	return [p1(), p2()]


## A-10 r5: место героя (0 — первый, 1 — второй).
func seat_of(pl) -> int:
	return 1 if active and pl != null and pl == p2() else 0


func p1():
	return game.player if cur == 0 or not active else seats[0].player


func p2():
	if not active:
		return null
	return game.player if cur == 1 else seats[1].player


func hud_of(i: int):
	if not active or cur == i:
		return game.hud
	return seats[i].hud


## Что ответить, если второго игрока добавить нельзя ("" — можно).
func why_not() -> String:
	if active:
		return "Второй игрок уже в игре"
	if game.player == null or game.hud == null:
		return "Игра ещё загружается"
	return ""


# ---------------------------------------------------------------- места

func _save(i: int) -> void:
	var d: Dictionary = seats[i]
	for k in SEAT_VARS:
		d[k] = game.get(k)


func _load(i: int) -> void:
	var d: Dictionary = seats[i]
	for k in SEAT_VARS:
		if d.has(k):
			game.set(k, d[k])


## Подставить в игру поля места i (свои: герой, камера, интерфейс, стройка, наведение).
func use(i: int) -> void:
	if not active or i == cur:
		return
	_save(cur)
	_load(i)
	cur = i


## Выполнить f за место i и вернуть игру туда, где она была.
func with_seat(i: int, f: Callable):
	if not active:
		return f.call()
	var was := cur
	use(i)
	var r = f.call()
	use(was)
	return r


## Чьё это событие ввода: геймпад второго игрока (и его искусственная мышь) — место 1, всё остальное — место 0.
func event_seat(ev: InputEvent) -> int:
	if not active:
		return 0
	if ev.device == Pad.MARK + 1:
		return 1
	if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion) and ev.device == pad_dev:
		return 1
	return 0


## Прямоугольник половины экрана (в пикселях окна).
func rect(i: int) -> Rect2:
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	if not active or views.is_empty():
		return Rect2(Vector2.ZERO, vs)
	var c: Control = views[i][0]
	return Rect2(c.global_position, c.size)


## Курсор места для луча камеры: в координатах его половины.
func mouse_pos(i: int) -> Vector2:
	var sv: SubViewport = views[i][1]
	var pad = Pad if i == 0 else pad2
	if pad != null and pad.active:
		var r := rect(i)
		var lsz := Vector2(sv.size_2d_override) if sv.size_2d_override != Vector2i.ZERO else Vector2(sv.size)
		return (pad.cursor - r.position) * lsz / r.size
	return sv.get_mouse_position()


# ---------------------------------------------------------------- начать и закончить

func start(dev: int) -> void:
	var w := why_not()
	if w != "":
		game.notify(w, Color(1, 0.8, 0.5))
		return
	pad_dev = dev
	if Pad.device == dev:
		Pad.device = -1    # первый игрок остаётся на клавиатуре и мыши
	cur = 0
	_save(0)
	# второй герой рядом с первым; облик — следующий в списке героев
	var p := Player.new()
	p.game = game
	var looks := Player.looks()
	var my: String = game.player.look if game.player.look != "" else str(DB.setting("hero_model", "hero"))
	var li := looks.find(my)
	p.look = str(looks[(li + 1) % looks.size()]) if looks.size() > 1 else my
	p.p2 = true
	game.add_child(p)
	p.build()
	p.position = game.island.landing() if game.island != null else game.player.position + Vector3(2.5, 0, 1.5)
	if game.island != null and p2_start_inv.is_empty() and p2_start_extra.is_empty():
		p.inv.add("salvage_rod",1)
		p.pin_item(0,"salvage_rod")
	if not p2_start_extra.is_empty():
		p.bag_level = int(p2_start_extra.get("bag", 0))
		p.apply_bag()
		p.clothes = str(p2_start_extra.get("clothes", ""))
		for k in ["hp", "food", "water"]:
			if p2_start_extra.has(k):
				p.set(k, float(p2_start_extra[k]))
		p2_start_extra = {}
	if not p2_start_inv.is_empty():
		p.inv.from_array(p2_start_inv)
		p2_start_inv = []
	pad2 = load("res://scripts/pad.gd").new()
	pad2.seat = 1
	pad2.device = dev
	pad2.name = "Pad2"
	game.add_child(pad2)
	p.ctl = pad2
	var cam := Camera3D.new()
	cam.fov = game.camera.fov
	cam.near = game.camera.near
	cam.far = game.camera.far
	cam.attributes = game.camera.attributes
	var h := Hud.new()
	h.game = game
	h.seat = 1
	# две половины экрана, у каждой свой вид на общий мир
	layer = CanvasLayer.new()
	layer.layer = -1
	layer.name = "SplitViews"
	game.add_child(layer)
	box = HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	views = []
	var rv: Viewport = game.get_viewport()
	for i in 2:
		var c := SubViewportContainer.new()
		c.stretch = true
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(c)
		var sv := SubViewport.new()
		sv.world_3d = rv.world_3d
		sv.msaa_3d = rv.msaa_3d
		sv.screen_space_aa = rv.screen_space_aa
		sv.scaling_3d_scale = rv.scaling_3d_scale
		sv.mesh_lod_threshold = rv.mesh_lod_threshold
		sv.positional_shadow_atlas_size = rv.positional_shadow_atlas_size
		sv.handle_input_locally = true
		sv.audio_listener_enable_3d = i == 0
		c.add_child(sv)
		views.append([c, sv])
	# первому месту — его камера и интерфейс, второму — новые
	game.camera.reparent(views[0][1], false)
	game.hud.reparent(views[0][1], false)
	views[1][1].add_child(cam)
	views[1][1].add_child(h)
	for i in 2:
		var gate := Gate.new()
		gate.split = self
		gate.seat = i
		views[i][1].add_child(gate)
		var cm: Camera3D = game.camera if i == 0 else cam
		cm.cull_mask = (cm.cull_mask | (1 << (VIEW_LAYER[i] - 1))) & ~(1 << (VIEW_LAYER[1 - i] - 1))
		cm.make_current()
	rv.disable_3d = true
	active = true
	box.resized.connect(_fit)
	_fit.call_deferred()
	# поля второго места: свои герой, камера и интерфейс, остальное — с нуля
	var s1: Dictionary = seats[0].duplicate()
	s1.player = p
	s1.hud = h
	s1.camera = cam
	s1.build_type = ""
	s1.demolish = false
	s1.wiring = false
	s1.zone_pick = false
	s1.wire_from = null
	for k in ["wire_line", "ghost", "target_ring", "wire_hl", "drag_placed"]:
		s1[k] = null
	s1.target = {}
	s1.wire_flash_b = []
	s1._hl_pool = []
	s1.lmb = false
	s1.rmb = false
	s1.cam_focus = p.position
	s1.trauma = 0.0
	s1.top_view = false
	seats[1] = s1
	with_seat(1, func(): h.build())
	game.world.split_views(true, VIEW_LAYER)
	game.notify("Второй игрок в игре — экран делится пополам", Color(0.6, 0.9, 1))
	game.sfx.play_ui("click")


## Интерфейс рассчитан на ширину от ~1100 точек: на узкой половине он рисуется мельче, а не вылезает за край.
func _fit() -> void:
	for v in views:
		var c: SubViewportContainer = v[0]
		var sv: SubViewport = v[1]
		var sz := Vector2i(c.size)
		if sz.x <= 0 or sz.y <= 0:
			continue
		var k := maxf(1.0, 1100.0 / float(sz.x))
		sv.size_2d_override = Vector2i(roundi(sz.x * k), roundi(sz.y * k)) if k > 1.0 else Vector2i.ZERO
		sv.size_2d_override_stretch = k > 1.0


func stop() -> void:
	if not active:
		return
	# B-6 r11: у гостя команды второго игрока ещё без ответа — выход ждёт ответа (иначе ответ доставался первому)
	if Net.busy():
		game.notify("Второй игрок выйдет, когда хозяин ответит на его действия", Color(1, 0.8, 0.5))
		Net.when_idle(stop)
		return
	use(0)
	var s1: Dictionary = seats[1]
	var p = s1.player
	if p != null and game.vehicles != null and game.vehicles.driving != "" and game.vehicles.driver == p:
		if not game.vehicles.leave():   # A-1 r6: второй был за рулём — машина паркуется у него
			game.vehicles.force_leave()
	# A-2 r8: расширенный рюкзак, здоровье, еда и вода второго остаются за ним до следующего входа
	if p != null:
		p2_start_extra = {"bag": int(p.bag_level), "hp": float(p.hp) if p.alive else float(p.maxhp), "food": float(p.food), "water": float(p.water)}
	# вещи второго героя — на склад штаба, чтобы ничего не пропало
	var moved := 0
	if p != null and Net.is_client():
		# B-4 r8: у гостя склад штаба — копия хозяйского; вещи и одежда остаются за вторым игроком до следующего входа
		p2_start_inv = p.inv.to_array()
		p2_start_extra["clothes"] = str(p.clothes)
		p.inv.slots.fill(null)
		p.clothes = ""
	elif p != null and game.factory.hq != null:
		for s in p.inv.slots:
			if s != null:
				# A-9 r5: слот целиком (износ/свежесть); не влезло — на землю у штаба
				var left: int = game.factory.hq.inv.add_slot(s)
				moved += s.n - left
				if left > 0:
					var rest: Dictionary = (s as Dictionary).duplicate()
					rest["n"] = left
					game.drops.spawn_slot(rest, game.factory.hq.center() + Vector3(0, 1, 0))
		# A-8 r7: надетая одежда — тоже на склад
		if str(p.clothes) != "":
			var cl := {"id": str(p.clothes), "n": 1}
			if game.factory.hq.inv.add_slot(cl) > 0:
				game.drops.spawn_slot(cl, game.factory.hq.center() + Vector3(0, 1, 0))
			moved += 1
			p.clothes = ""
	for k in ["ghost", "wire_line", "target_ring", "wire_hl"]:
		if s1.get(k) != null and is_instance_valid(s1[k]):
			s1[k].queue_free()
	if s1.hud != null:
		s1.hud.queue_free()
	game.camera.reparent(game, false)
	game.hud.reparent(game, false)
	game.camera.cull_mask = game.camera.cull_mask & ~(1 << (VIEW_LAYER[0] - 1))
	game.camera.make_current()
	game.get_viewport().disable_3d = false
	game.world.split_views(false, VIEW_LAYER)
	active = false
	if p != null:
		p.queue_free()
	if pad2 != null:
		pad2.queue_free()
		pad2 = null
	layer.queue_free()
	layer = null
	views = []
	seats = [{}, {}]
	pad_dev = -1
	if Pad.device < 0 and not Input.get_connected_joypads().is_empty():
		Pad.device = Input.get_connected_joypads()[0]
	game.notify("Второй игрок вышел — экран снова целый" + ("" if moved == 0 else ". Его вещи — на складе штаба"), Color(0.6, 0.9, 1))
	if Net.is_client():
		Net._self().send_my_state()   # B-4 r8: хозяин запоминает вещи второго игрока гостя


## Сохранение: вещи второго героя (при загрузке он появится с ними, когда снова нажмёт Start).
func save_state() -> Dictionary:
	if not active:
		if p2_start_inv.is_empty() and p2_start_extra.is_empty():
			return {}
		var keep := p2_start_extra.duplicate()
		keep["inv"] = p2_start_inv   # A-8 r5
		return keep
	var q = p2()
	var ss: Dictionary = q.saved_state()   # A-3 r8
	return {"inv": q.inv.to_array(), "clothes": str(q.clothes), "bag": int(q.bag_level), "hp": float(ss.hp), "food": float(ss.food), "water": float(ss.water)}


func load_state(d) -> void:
	if d is Dictionary:
		p2_start_inv = d.get("inv", [])
		p2_start_extra = {}
		for k in ["clothes", "bag", "hp", "food", "water"]:
			if d.has(k):
				p2_start_extra[k] = d[k]


## Привратник половины экрана: первым получает ввод в своей половине, подставляет её место
## и отсекает чужие события (клавиатуру — у второй половины, геймпад второго игрока — у первой).
class Gate extends Node:
	var split
	var seat := 0

	func _input(ev: InputEvent) -> void:
		if split == null or not split.active:
			return
		if split.event_seat(ev) != seat:
			get_viewport().set_input_as_handled()
			return
		split.with_seat(seat, func(): split.game._input_impl(ev))

	func _unhandled_input(ev: InputEvent) -> void:
		if split == null or not split.active or split.event_seat(ev) != seat:
			return
		split.with_seat(seat, func(): split.game._unhandled_impl(ev))
