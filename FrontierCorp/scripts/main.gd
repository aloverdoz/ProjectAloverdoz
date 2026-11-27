extends Node3D
## Игра: собирает мир, камеру, свет, обрабатывает ввод.
## Все действия игрока проходят через cmd() — это основа для будущего мультиплеера:
## в сетевой игре те же команды будут отправляться на сервер.

const C := World.C

var island
var world: World
var factory: Factory
var enemies: Enemies
var fx: Fx
var player: Player
var hud: Hud
var drops: Drops
var camera: Camera3D
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sfx: Sfx
var mirror: WrapMirror
var console: Console
var admin: AdminPanel        # 1.1.11: админ-панель (команда admin)

var paused := false
var victory := false
var game_over := false
var credits := 100
var sink_points_total := 0   # 17.10: сколько очков набрали все утилизаторы (за всю игру)
var earned := 0
var edge_off := Vector3.ZERO
var ng_modules := {}       # модули, выбранные при создании игры (перекрывают правила игры)
var _victory_t := 0.0
var play_time := 0.0      # секунд в игре (для списка сохранений)
var level := 1
var xp := 0.0
var skill_points := 0
var skills := {}
var attrs := {}          # характеристики героя: сила, ловкость...
var attr_points := 0
var gen_ms := 0             # сколько строилась карта (для проверок)
var marks: Array = []    # метки на карте: {x, z, name, color}
var graves: Array = []   # сундуки с вещами погибшего героя: {pos, inv, node}
var profession := "engineer"
var difficulty := 1.0   # множитель силы монстров: 0.6 лёгкая … 2.2 кошмар
var delivered := {}
var effects := {}          # stat -> {value, t, name}
var flags := {}            # god, free_build, no_waves, show_fps...
var first_person := false
var look_pitch := -0.18
var explorer_anchor := {}
var strategy := false      # 1.1.15: режим «Стратегия» — без героя (strategy.gd)
var strat                  # strategy.gd
var hearts                 # hearts.gd: предел зданий и «Сердца»
var tech: Tech             # дерево открытий и задания станции
var events                 # события мира и загрязнение (events.gd)
var flow_map               # карта потоков: узкие места лент и машин (flow_map.gd)
var blueprints             # чертежи: копировать и ставить куски базы (blueprints.gd)
var vehicles               # машины (vehicles.gd)
var carriers               # дроны и грузовики между зданиями (carriers.gd)
var progress17             # 17.10: мастерство машин, связки, рекорды производства (progress17.gd)
var drones: Drones         # 14.21: станции дронов с маршрутами А → Б (drones.gd)
var builders: Builders18   # 18: роботы-строители отстраивают разрушенное (builders18.gd)
var sieges                 # осады с боссом (sieges.gd)
var coop: Coop             # 16: торговля между игроками, продажа энергии, подколы (coop.gd)
var star: Starworks        # 14.23: НЛО-торговля, инженерный стол, звёздные врата (starworks.gd)
var hazards: Hazards       # 14.22: радиация и кислота (hazards.gd)
var climate                # сезоны и выживание: холод, жара, одежда, обогрев (climate.gd)
var dungeons               # подземелья: руины со стражей, ловушками и редкими чертежами (dungeons.gd)
var maze                   # лабиринты и ловушки: обход стен монстрами (maze.gd)
var fog                    # туман войны: что уже открыто на карте (fog.gd)
var zone                   # открытая зона и стена бури (zone.gd)
var scanner                # находки и сканирование ресурсов (scanner.gd)
var tutorial: Tutorial     # обучение для новичков (tutorial.gd)
var defense                # энергощиты, поля замедления, ремонтные башни (defense.gd)
var photo                  # фото- и видеорежим: свободная камера, фильтры, запись (photo.gd)
var npcs                   # НПС и репутация (npcs.gd)
var orders                 # заказы на станции (orders.gd)
var last_sold := {}        # предмет -> когда его последний раз продавали (play_time)
var photo_mode := false    # без интерфейса — для красивых снимков
var top_view := false      # камера сверху
var craft_queue: Array = []  # [{rid, t, station}]
var day_length := 480.0

# камера
var cam_yaw := 0.6
var cam_yaw_target := 0.6
var dormant_caves := []
var strategy_zoom := 34.0
var explorer_zoom := 9.0
var layout_version := 2
var cam_dist := 42.0
var cam_dist_target := 42.0
var cam_focus := Vector3.ZERO
var cam_pitch_override := 0.0
var cam_max := 90.0
const CAM_CLOSE := 2.6        # 1.3: ближе всего на «+» — герой во весь рост
var zoom_home := -1.0         # 1.3: с какой высоты начали приближать «+» — дальше неё «−» не отдаляет

# строительство
var field_selection := -1
var build_type := ""
var build_dir := 0
var demolish := false
var wiring := false            # режим «Провода»: тянуть провод мышью от здания к зданию
var pview                      # 21: режим энергии — покрытие станций (V)
var physics                    # 21: обломки, взрывы, отлёт тел (physics21.gd)
var rules_ov := {}             # 21: правила мира, заданные при создании одиночной игры (хранятся в сохранении)
var split                      # 1.3: сплитскрин — второй игрок на половине экрана этой же игры (split.gd)
var quantum                    # 21: квантовое измерение — портал, жилы, запутанные пары, тени (quantum21.gd)
var zone_pick := false         # 15.5: выбор участка 5×5 блоков, который откроется из-под бури
var wire_from = null
var wire_line: MeshInstance3D
var ghost: Node3D
var hover_cell := Vector2i.ZERO
var hover_point := Vector3.ZERO
var lmb := false
var rmb := false
var drag_last := Vector2i(-999, -999)
var drag_placed = null
var demo_layer := "top"    # 1.1.19: протягивание сноса — здания («top») или фундаменты («found»)
var drag_cross := Vector2i(-999, -999)  # 1.7: линия лент прошла поперёк чужой ленты — здесь встанет кротовина
var drag_new := Vector2i(-999, -999)   # 1.7: гость — клетка, куда он только что поставил (здание придёт от хозяина позже)
var repair_acc := 0.0
var spark_acc := 0.0

# время суток
var day_t := 0.328
var day_n := 1

# рынок
var price_mult := {}
var price_prev := {}
var market_timer := 30.0
var trade_earned := 0

# задачи
var quest_i := 0
var quests: Array = []

# челнок
var shuttle: Node3D
var shuttle_beam: MeshInstance3D
var shuttle_busy := false



## Склеенные модели живут в статическом кэше — освобождаем до выключения рендера.
func _exit_tree() -> void:
	get_tree().set_auto_accept_quit(true)
	DB.discovery = false   # в редакторе и меню все предметы видны
	ModelLib._merged.clear()
	Net.detach()
	preload("res://scripts/server_settings.gd").restore()

## 21: крупные здания («Правила мира → Производство → Здания крупнее героя»). Выключено — прежние размеры.
## v13 = false — сохранение до 1.3: бур 2×2 (size12/scale12), как было при его создании.
func _apply_sizes(big := bool(DB.setting("big_buildings", true)), v13 := true) -> void:
	for bid in DB.data.buildings:
		var bd: Dictionary = DB.data.buildings[bid]
		if not bd.has("size0"):
			continue
		if not bd.has("size_big"):
			bd["size_big"] = bd["size"]
		bd["size"] = (bd["size12"] if bd.has("size12") and not v13 else bd["size_big"]) if big else bd["size0"]
		var md: Dictionary = DB.data.models.get(bd.get("model", bid), {})
		if layout_version < 2 and big and bd.has("layout1"):
			bd["size"] = bd.layout1
		if md.has("scale0"):
			if not md.has("scale_big"):
				md["scale_big"] = md["scale"]
			md["scale"] = (md["scale12"] if md.has("scale12") and not v13 else md["scale_big"]) if big else md["scale0"]
			if layout_version < 2 and big and md.has("layout1_scale"):
				md["scale"] = md.layout1_scale
			for em in md.get("emitters", []):
				if em.has("pos0"):
					if not em.has("pos_big"):
						em["pos_big"] = em["pos"]
						em["size_big"] = em.get("size", 1.0)
					em["pos"] = em["pos_big"] if big else em["pos0"]
					em["size"] = em["size_big"] if big else em.get("size0", em.get("size", 1.0))
	ModelLib._merged.clear()


func _ready() -> void:
	randomize()
	# 1.0.9: настройки сервера (комнаты) — у хозяина и у каждого гостя одинаковые, до того как мир прочтёт правила
	var ng0: Dictionary = DB.get_meta("new_game", {}) if DB.has_meta("new_game") else {}
	if Net.active():
		preload("res://scripts/server_settings.gd").apply(Net._self().room.get("ov", {}))
	elif ng0.get("ov") is Dictionary and not ng0.ov.is_empty():
		preload("res://scripts/server_settings.gd").apply(ng0.ov)   # 21: правила мира из новой игры
	elif ng0.has("save") and ng0.save.get("rules_ov") is Dictionary and not ng0.save.rules_ov.is_empty():
		preload("res://scripts/server_settings.gd").apply(ng0.save.rules_ov)
	rules_ov = (ng0.get("ov", {}) if ng0.get("ov") is Dictionary else (ng0.save.get("rules_ov", {}) if ng0.has("save") else {})).duplicate()
	# старые сохранения (до 1.2) построены с прежними размерами зданий — так и загружаем
	var has_save: bool = ng0.has("save") and ng0.save is Dictionary
	layout_version = int(ng0.save.get("layout_version",1)) if has_save else 2
	_apply_sizes(bool(ng0.save.get("big", false)) if has_save else bool(DB.setting("big_buildings", true)), bool(ng0.save.get("big13", false)) if has_save else true)
	World.dep_fit = bool(ng0.save.get("dep_fit", false)) if ng0.has("save") and ng0.save is Dictionary else true
	# 1.1.9: порты зданий — в новых мирах; миры до 1.1.9 загружаются с прежними подключениями (ленты с любой стороны),
	# иначе у игроков встанут уже построенные заводы
	if not DB.has_meta("ports_def"):
		DB.set_meta("ports_def", Factory.ports_on())
	DB.data.settings["ports18"] = {"on": bool(DB.get_meta("ports_def")) and (not has_save or bool(ng0.save.get("ports19", false)))}
	_dep118(not has_save or bool(ng0.save.get("dep118", false)))
	get_tree().set_auto_accept_quit(false)   # 18: при закрытии окна сетевая игра успевает сохраниться (quit_game)
	for ua in OS.get_cmdline_user_args():
		# для повторяемых замеров: та же карта и та же база
		if ua.begins_with("--seed="):
			seed(int(ua.substr(7)))
	var ng: Dictionary = DB.get_meta("new_game", {}) if DB.has_meta("new_game") else {}
	profession = ng.get("profession", "engineer")
	if ng.get("modules") is Dictionary:
		ng_modules = ng.modules.duplicate()
	if ng.has("save") and ng.save.get("modules") is Dictionary:
		ng_modules = ng.save.modules.duplicate()
	difficulty = float(ng.get("difficulty", DB.setting("difficulty", 1.0)))
	if not DB.data.professions.has(profession):
		profession = "engineer"
	_setup_environment()
	tech = Tech.new(self)
	events = preload("res://scripts/events.gd").new(self)
	blueprints = preload("res://scripts/blueprints.gd").new(self)
	flow_map = preload("res://scripts/flow_map.gd").new(self)
	add_child(flow_map)
	vehicles = preload("res://scripts/vehicles.gd").new(self)
	carriers = preload("res://scripts/carriers.gd").new(self)
	progress17 = Progress17.new(self)
	drones = Drones.new(self)
	builders = Builders18.new(self)
	sieges = preload("res://scripts/sieges.gd").new(self)
	photo = preload("res://scripts/photo.gd").new(self)
	fog = preload("res://scripts/fog.gd").new(self)
	maze = preload("res://scripts/maze.gd").new(self)
	dungeons = preload("res://scripts/dungeons.gd").new(self)
	climate = preload("res://scripts/climate.gd").new(self)
	hazards = Hazards.new(self)
	star = Starworks.new(self)
	coop = Coop.new(self)
	pview = preload("res://scripts/power_view.gd").new(self)
	add_child(pview)
	physics = preload("res://scripts/physics21.gd").new(self)
	add_child(physics)
	quantum = preload("res://scripts/quantum21.gd").new(self)
	split = preload("res://scripts/split.gd").new(self)
	add_child(split)
	add_child(quantum)
	if fx != null:
		fx.on_blast = physics.blast
	add_child(coop)
	npcs = preload("res://scripts/npcs.gd").new(self)
	orders = preload("res://scripts/orders.gd").new(self)
	for a in OS.get_cmdline_user_args():
		if a in ["--test=perf_landing", "--test=ocean"]:
			continue
		# проверки старых частей игры идут с открытым деревом (свою проверку дерево делает само)
		if a.begins_with("--test=") and a != "--test=tech":
			tech.unlock_all()
			if a != "--test=batch2":
				DB.data.settings["auto_wire"] = true   # старые проверки рассчитаны на автоподключение
			# 21: старые проверки рассчитаны на провода; станции проверяет своя проверка
			if not a in ["--test=stations21", "--test=upgrade21", "--test=quantum21"]:
				DB.data.settings["power_mode"] = "wires"
			if a != "--test=belts21":
				DB.data.settings["belt_spill_pct"] = 0.0   # старые проверки считают каждый предмет
			# 21: здания стали крупнее; старые проверки расставлены под прежние размеры
			if not a in ["--test=sizes21", "--test=perf", "--test=v13", "--test=ports13", "--test=v19"]:
				_apply_sizes(false)
				World.dep_fit = false   # 1.3: и залежи по-старому (1×1, зазор в клетку)
		# 13.10: старые проверки рассчитаны на открытую карту — зона с бурей включается только в своей проверке
		# 17.10: старые проверки рассчитаны на генераторы без воды и машины без мастерства и связок
		if a.begins_with("--test=") and not a in ["--test=mech17"]:
			if DB.data.buildings.has("coal_generator"):
				DB.data.buildings["coal_generator"]["params"]["water_per_min"] = 0
			DB.data.settings["mastery"] = {"enabled": false}
			DB.data.settings["milestones"] = {"enabled": false}
			DB.data.settings["daily"] = {"enabled": false}
		if a.begins_with("--test=") and not a in ["--test=zone", "--test=rework", "--test=s15", "--test=doc17", "--test=pace15", "--test=perf15", "--test=v18", "--test=dep118_115"]:
			DB.data.settings["zone"] = {"enabled": false}
			DB.data.settings["scan"] = {"enabled": false}
		if a.begins_with("--test=") and a != "--test=pace15":
			# старые тесты рассчитаны на волны без темпа по прогрессу
			var wp = DB.data.waves.get("pace", {})
			if wp is Dictionary:
				wp = wp.duplicate()
				wp["enabled"] = false
				DB.data.waves["pace"] = wp
		if a.begins_with("--test=") and not a in ["--test=v17", "--test=dep118_115"]:
			DB.data.world["start_set"] = false   # 1.7: старые проверки расставлены на карте без новых залежей у штаба
		if a.begins_with("--test=") and not a in ["--test=v18", "--test=v18net", "--test=v111", "--test=dep118_115"]:
			_old_economy()   # 1.1.8: старые проверки — на старой экономике
		if a.begins_with("--test=") and not a in ["--test=v19", "--test=v111", "--test=endgame112"] and OS.get_environment("FC_PORTS") != "1":
			DB.data.settings["ports18"] = {"on": false}   # 1.1.9: старые проверки ставят ленты с любой стороны
		if a.begins_with("--test=") and not a.ends_with("115"):
			_legacy_115()   # 1.1.15: старые проверки — на прежней обороне (патроны из штаба, турели без энергии) и без метеоритов
		if a.begins_with("--test=") and a != "--test=tutorial":
			var tc = DB.data.settings.get("tutorial", {})
			if tc is Dictionary:
				tc = tc.duplicate()
				tc["enabled"] = false
				DB.data.settings["tutorial"] = tc
	tech.refresh_locks()
	world = World.new()
	world.game = self
	add_child(world)
	var wd: Dictionary = DB.data.world
	day_length = float(wd.get("day_length", 480))
	var map_file: String = ng.get("map_file", wd.get("map_file", ""))
	var mode: String = ng.get("map_mode", wd.get("map_mode", "procedural"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_file = a.substr(6)
			mode = "fixed"
	var ocean_mode: bool = ng.save.has("ocean_island") if has_save else str(ng.get("map_mode", "ocean")) == "ocean" and mode != "fixed"
	if ocean_mode:
		island = preload("res://scripts/ocean_island.gd").new(self)
		world.ocean = true
	var loaded := false
	if ng.has("save") and ng.save.get("map") is Dictionary:
		world.load_map(ng.save.map)
		loaded = true
	elif mode == "fixed" and map_file != "":
		var m = DB.read_file(DB.find_file(map_file))
		if m is Dictionary:
			world.load_map(m)
			loaded = true
	if not loaded:
		var ov := {}
		if int(ng.get("size", 0)) >= 64:
			ov["size"] = int(ng.size)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--size="):
				ov["size"] = int(a.substr(7))
			elif a.begins_with("--res="):
				ng["res"] = a.substr(6)
		# 1.0.8: «Ресурсы: мало / обычно / много» — во столько раз больше или меньше месторождений
		var rid := str(ng.get("res", "normal"))
		for e in DB.data.world.get("res_levels", []):
			if e is Dictionary and str(e.get("id", "")) == rid:
				ov["res_k"] = float(e.get("k", 1.0))
		var t0 := Time.get_ticks_msec()
		var map_seed := int(ng.get("seed", randi() % 999999 + 1))
		if map_seed == 0: map_seed = randi_range(1,999999)
		if island != null:
			world.generate_island(map_seed, clampi(int(ov.get("size",256)),64,1152))
		else:
			world.generate(map_seed, ov)
		gen_ms = Time.get_ticks_msec() - t0
	factory = Factory.new()
	factory.game = self
	add_child(factory)
	enemies = Enemies.new()
	enemies.game = self
	add_child(enemies)
	enemies.setup()
	fx = Fx.new()
	fx.game = self
	add_child(fx)
	fx.setup()
	if physics != null:
		fx.on_blast = physics.blast
	sfx = Sfx.new()
	add_child(sfx)
	sfx.setup()
	drops = Drops.new()
	drops.game = self
	add_child(drops)
	drops.setup()
	for ua in OS.get_cmdline_user_args():
		# для скриншота: герой из GLB-файла (как после выбора в редакторе)
		if ua.begins_with("--hero_glb="):
			var gp := ua.substr(11)
			DB.data.models["shot_glb_hero"] = ModelLib.glb_fit({"name": "GLB", "parts": [], "glb": gp}, gp)
			DB.data.settings["hero_model"] = "shot_glb_hero"
	for ua in OS.get_cmdline_user_args():
		if ua == "--strategy" or ua == "--test=strategy115" or ua == "--test=wiredrop115":
			DB.data.settings["strategy"] = true
	strategy = preload("res://scripts/strategy.gd").on()
	Inventory.no_personal = strategy
	strat = preload("res://scripts/strategy.gd").new(self)
	hearts = preload("res://scripts/hearts.gd").new(self)
	if strategy and not Net.dedicated:
		strat.make_overlay()
	player = Player.new()
	player.game = self
	player.look = Player.my_look()
	for ua in OS.get_cmdline_user_args():
		if ua.begins_with("--hero="):    # скриншоты: герой на этот запуск
			player.look = ua.substr(7)
	add_child(player)
	player.build()
	player.visible = not strategy
	factory.setup()
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.near = 0.3
	camera.far = 1500.0
	add_child(camera)
	for id in DB.data.skills:
		skills[id] = 0
	for id in DB.data.items:
		price_mult[id] = randf_range(0.85, 1.15)
		price_prev[id] = price_mult[id]
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	hud.build()
	console = Console.new()
	console.game = self
	add_child(console)
	admin = AdminPanel.new(self)
	mirror = WrapMirror.new()
	add_child(mirror)
	mirror.setup(world.W * C, [world, factory, enemies, drops, fx])
	Prefs.apply_all()
	fog.setup()
	defense = preload("res://scripts/defense.gd").new(self)
	scanner = preload("res://scripts/scanner.gd").new(self)
	scanner.setup()
	zone = preload("res://scripts/zone.gd").new()
	zone.game = self
	add_child(zone)
	tutorial = Tutorial.new()
	add_child(tutorial)
	tutorial.setup(self)
	if ng.has("save"):
		load_game(ng.save)
	else:
		if island == null: tutorial.start_new()
		_start_base()
		zone.setup(factory.hq.center() if factory.hq else World.cell_to_world(world.center))
		if island == null:
			star.place_elevator()
			dungeons.place_caves()
			dungeons.generate()
		if factory.hq:
			fog.reveal(factory.hq.center(), float(DB.setting("fog_start_radius", 70.0)))
	if island != null:
		island.setup(ng.get("save", {}).get("ocean_island", {}))
	if island == null and not Net.dedicated and not Net.active():
		add_child(preload("res://scripts/hoppers.gd").new())
	_make_shuttle()
	_setup_quests()
	cam_focus = player.position
	if island != null and not ng.has("save"):
		notify("Океан • выберите удочку в ячейке 1. ЛКМ по воде — заброс. E у плиты — заказ и расширение.", UI.ACCENT)
	if island == null and not ng.has("save") and Prefs.get_value("show_hints", true) and not tutorial.active:
		hud.open("help")
	if str(ng.get("command", "")) != "":
		console.run.call_deferred(str(ng.command))
	Net.attach(self)
	_check_test_args()
	get_window().title = "%s %s" % [DB.window_title(), DB.game_version()]
	_warmup.call_deferred()


# ---------------------------------------------------------------- прогрев перед входом в мир

var loading_done := false
var loading_step := ""
var warming := false

## Пока висит экран загрузки: игра стоит, мир уже нарисован, и видеокарта заранее
## готовит все материалы (иначе первые секунды игры подтормаживают).
func _warmup() -> void:
	var quick := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test"):
			quick = true
	if quick or DisplayServer.get_name() == "headless":
		loading_done = true
		return
	warming = true
	loading_step = DB.tx("load_shaders", "Готовим материалы...")
	var holder := Node3D.new()
	add_child(holder)
	holder.global_transform = camera.global_transform.translated_local(Vector3(0, 0, -8))
	var seen := {}
	var k := 0
	for mid in (["tide_slab","tree_oak","tree_pine","salvage_rod","lp_barrel","drop_log"] if island != null else DB.data.models.keys()):
		var external := str(ModelLib.model(mid).get("glb", ""))
		if external != "" and not ModelLib._glb.has(external):
			continue
		for p in ModelLib.parts_of(mid, true):
			var m: Material = p[1]
			if m == null or seen.has(m):
				continue
			seen[m] = true
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = p[0]
			mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 0.05), Vector3((k % 20) * 0.1 - 1.0, (k / 20) * 0.1, 0)))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = m
			holder.add_child(mmi)
			k += 1
	# иконки предметов в рюкзаке и на панели — заранее
	for s in player.inv.slots:
		if s != null:
			Icons.get_icon("item:" + str(s.id))
	for i in 4:
		await get_tree().process_frame
	holder.queue_free()
	loading_step = DB.tx("load_world", "Почти готово...")
	for i in 3:
		await get_tree().process_frame
	warming = false
	loading_done = true


# ---------------------------------------------------------------- модули и бонусы

func module(id: String) -> bool:
	# 16: правила сетевой комнаты (волны, монстры) важнее настроек мира — одинаковые у всех игроков
	if Net.active() and (Net._self().room.get("modules", {}) as Dictionary).has(id):
		return bool(Net._self().room.modules[id])
	if ng_modules.has(id):
		return bool(ng_modules[id])
	return bool(DB.data.settings.get("modules", {}).get(id, false))


## Сумма бонуса: навыки + профессия + действующие бустеры.
func bonus(stat: String) -> float:
	if Net.is_host() and Net._self().applying and int(Net._self().actor) > 1:
		# B18-1: хозяин выполняет команду гостя (торговля, стройка) — бонусы гостя, а не хозяина
		var nn = Net._self()
		var gnk := str(nn.peers.get(nn.actor, {}).get("nick", ""))
		var gst = nn.saved.get(gnk, {})
		var gme = gst.get("me", {}) if gst is Dictionary else {}
		if not gme is Dictionary:
			gme = {}
		var gv := bonus_of(gme, stat)
		if module("professions"):
			gv += float(DB.data.professions.get(str(gme.get("profession", "")), {}).get("bonus", {}).get(stat, 0.0))
		return gv
	var v := 0.0
	for id in skills:
		if skills[id] > 0:
			v += float(DB.data.skills.get(id, {}).get("bonus", {}).get(stat, 0.0)) * skills[id]
	for id in attrs:
		if attrs[id] > 0:
			v += float(DB.data.attributes.get(id, {}).get("bonus", {}).get(stat, 0.0)) * attrs[id]
	if module("professions"):
		v += float(DB.data.professions.get(profession, {}).get("bonus", {}).get(stat, 0.0))
	# A-3 r10: эффекты хранятся по источнику (характеристика|название) и складываются
	for k in effects:
		if str(effects[k].get("stat", str(k).get_slice("|", 0))) == stat:
			v += float(effects[k].value)
	# 1.0.9: «Бонусы всего мира» (настройки сервера / правила игры) — всем героям одинаково
	var wb = DB.data.settings.get("world_bonus", {})
	if wb is Dictionary and wb.has(stat):
		v += float(wb[stat])
	return v


## 1.1.14: бонус по навыкам и характеристикам из сохранённого состояния игрока (гостя на сервере).
static func bonus_of(st: Dictionary, stat: String) -> float:
	var v := 0.0
	var sk = st.get("skills", {})
	if sk is Dictionary:
		for id in sk:
			v += float(DB.data.skills.get(id, {}).get("bonus", {}).get(stat, 0.0)) * float(sk[id])
	var at = st.get("attrs", {})
	if at is Dictionary:
		for id in at:
			v += float(DB.data.attributes.get(id, {}).get("bonus", {}).get(stat, 0.0)) * float(at[id])
	var wb = DB.data.settings.get("world_bonus", {})
	if wb is Dictionary and wb.has(stat):
		v += float(wb[stat])
	return v


## 1.1.14: лучший бонус среди всех игроков в мире (хозяин + подключённые гости). На выделенном сервере
## свой герой не в счёт — он невидимый и без навыков.
func team_bonus(stat: String) -> float:
	var n = Net._self()
	var v := 0.0 if (n != null and n.server != null) else bonus(stat)
	if n != null and Net.is_host():
		for id in n.peers:
			var nk := str(n.peers[id].nick)
			var me = n.saved.get(nk, {}).get("me", {})
			if me is Dictionary:
				v = maxf(v, bonus_of(me, stat))
	return v


func add_effect(stat: String, value: float, t: float, name: String) -> void:
	var key := stat + "|" + name
	# тот же источник — обновляется; разные источники — складываются
	effects[key] = {"stat": stat, "value": value, "t": t, "name": name}


func effects_text() -> String:
	var parts := []
	for k in effects:
		parts.append("[color=#66ffcc]%s[/color] %d с" % [effects[k].name, int(effects[k].t)])
	return "  ".join(parts)


## Ближайший живой герой (в сетевой игре — и чужие герои), для монстров.
func nearest_player(p: Vector3):
	if strategy:
		return strat.ghost
	var sp: bool = split != null and split.active
	if not Net.active() and not sp:
		return player
	var best = player
	var bd := INF
	for pl in (Net._self().all_players() if Net.active() else split.local_players()):
		if not pl.alive:
			continue
		var d := World.dist(p, pl.position)
		if d < bd:
			bd = d
			best = pl
	return best


func typing() -> bool:
	var f := (hud.get_viewport() if hud != null and hud.is_inside_tree() else get_viewport()).gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func is_frozen() -> bool:
	return paused or hud == null or hud.modal_open() or (console != null and console.visible_now())


## 1.3: курсор для луча камеры — в своей половине экрана при сплитскрине.
func _mouse() -> Vector2:
	if split != null and split.active:
		return split.mouse_pos(split.cur)
	return Pad.mouse_pos(get_viewport())


## Окно интерфейса под курсором (не бить и не строить сквозь окно).
func _ui_hovered() -> bool:
	return (hud.get_viewport() if hud.is_inside_tree() else get_viewport()).gui_get_hovered_control() != null


func xp_next() -> float:
	var lv: Dictionary = DB.data.levels
	return float(lv.get("base_xp", 60)) * pow(float(lv.get("growth", 1.35)), level - 1)


func add_xp(x: float) -> void:
	xp += x * max(0.0, 1.0 + bonus("xp"))
	var guard := 0
	while xp >= xp_next() and level < int(DB.data.levels.get("max_level", 50)) and guard < 20:
		guard += 1
		xp -= xp_next()
		level += 1
		skill_points += int(DB.data.levels.get("points_per_level", 1))
		var ap := int(DB.data.levels.get("attr_points_per_level", 2))
		attr_points += ap
		notify("Новый уровень %d! Очко навыка и %d очка характеристик (K)" % [level, ap], Color(0.5, 0.85, 1))
		celebrate("УРОВЕНЬ %d" % level, "Очко навыка и %d очка характеристик — клавиша K" % ap, Color(0.55, 0.85, 1.0))
		sfx.play_ui("levelup")
		quip("level_up")


# ---------------------------------------------------------------- 1.3: отклик (тряска, заморозка кадра, баннер)

var trauma := 0.0
var _cam_lead := Vector3.ZERO
var _ghost_cell := Vector2i(-99999, -99999)
var _banner: Control = null


## Тряска камеры от удара, взрыва, приземления: копится до 1 и быстро гаснет (настройка «Тряска камеры»).
func add_trauma(x: float) -> void:
	trauma = minf(1.0, trauma + x)


## Короткая заморозка кадра при сильном ударе — удар «ощущается». В сетевой игре и тестах — нет
## (время общее для всего мира).
func hitstop(t: float) -> void:
	if Net.active() or Engine.time_scale != 1.0 or not bool(Prefs.get_value("hitstop", true)):
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test"):
			return
	Engine.time_scale = 0.06
	get_tree().create_timer(t, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## Крупный баннер по центру экрана: новый уровень, задание выполнено. Вспыхивает, держится и тает.
func celebrate(title: String, sub: String, col: Color) -> void:
	if _banner and is_instance_valid(_banner):
		_banner.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	# 1.3: плашка во всю ширину экрана с полями, текст переносится и ужимается — не уходит за край
	var vs := get_viewport().get_visible_rect().size
	var bw := maxf(320.0, vs.x - 80.0)
	var box := VBoxContainer.new()
	box.position = Vector2((vs.x - bw) * 0.5, vs.y * 0.2)
	box.size = Vector2(bw, 120)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	var t1 := Label.new()
	t1.text = title
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.add_theme_font_size_override("font_size", int(clampf(bw / maxf(1.0, float(title.length()) * 0.72), 26.0, 54.0)))
	t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t1.custom_minimum_size.x = bw
	t1.add_theme_color_override("font_color", col)
	t1.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	t1.add_theme_constant_override("outline_size", 14)
	box.add_child(t1)
	var t2 := Label.new()
	t2.text = sub
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 20)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t2.custom_minimum_size.x = bw
	t2.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	t2.add_theme_constant_override("outline_size", 8)
	box.add_child(t2)
	box.pivot_offset = Vector2(bw * 0.5, 60.0)
	box.scale = Vector2.ONE * 0.4
	box.modulate.a = 0.0
	_banner = box
	var tw: Tween = box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.8)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)
	if player and fx:
		fx.magic(player.position, col, 1.6)
		fx.magic(player.position + Vector3(0, 1.2, 0), Color(1, 0.9, 0.5), 1.2)


func upgrade_skill(id: String) -> void:
	var lvl: int = skills.get(id, 0)
	if skill_points <= 0 or lvl >= int(DB.data.skills.get(id, {}).get("max", 5)):
		return
	if strategy and preload("res://scripts/strategy.gd").hero_only(DB.data.skills.get(id, {}).get("bonus", {})):
		return
	skill_points -= 1
	skills[id] = lvl + 1
	sfx.play_ui("coin")
	if not Net.is_client():   # A-16: прочность зданий в сети считает хозяин
		for b in factory.all:
			var k: float = b.hp / maxf(0.001, b.maxhp)
			b.maxhp = float(DB.building(b.type).get("hp", 100)) * (1.0 + bonus("build_hp")) * (1.0 + 0.5 * (b.lvl - 1))   # A-12: с уровнем объединения
			b.hp = b.maxhp * k
	notify("Навык улучшен: " + DB.data.skills[id].get("name", id), Color(0.6, 1, 0.6))
	if Net.is_client():
		Net._self().send_my_state()   # 1.1.14: хозяин сразу знает навык (авторемонт)


func upgrade_attr(id: String) -> void:
	var lvl: int = attrs.get(id, 0)
	if attr_points <= 0 or lvl >= int(DB.data.attributes.get(id, {}).get("max", 20)):
		return
	if strategy and preload("res://scripts/strategy.gd").hero_only(DB.data.attributes.get(id, {}).get("bonus", {})):
		return
	attr_points -= 1
	attrs[id] = lvl + 1
	sfx.play_ui("coin")
	notify("%s: %d" % [DB.data.attributes[id].get("name", id), attrs[id]], DB.color(DB.data.attributes[id].get("color", "#ffffff")))
	if Net.is_client():
		Net._self().send_my_state()   # 1.1.14: хозяин сразу знает навык (авторемонт)


# ---------------------------------------------------------------- смерть героя: сундук с вещами

## A-5/A-6 r5: все герои, по которым бьют ловушки, взрывы, события: сетевые и оба героя сплитскрина.
var _cam_max0 := -1.0
var _photo_seat := 0


func hit_targets() -> Array:
	if strategy:
		return []   # 1.1.15: в стратегии героя нет — монстры, выстрелы и взрывы его не задевают
	if Net.active():
		return Net._self().all_players()
	return split.local_players() if split != null else [player]


## B-4 r5: ближайшее расстояние от точки до любого героя (гости, сплитскрин; на выделенном сервере — только гости).
func near_any_hero(p: Vector3) -> float:
	var best := INF
	var lst := hit_targets()
	if strategy:
		# 1.1.15: в стратегии «герой» — точка обзора камеры (у каждого игрока своя)
		lst = Net._self().all_players() if Net.active() else (split.local_players() if split != null else [player])
	for pl in lst:
		if pl != null and is_instance_valid(pl) and bool(pl.get("alive") if pl.get("alive") != null else true):
			best = minf(best, World.dist(pl.position, p))
	return best


## Вызывает герой в момент гибели. Правило задаётся в settings.death (редактор).
func on_player_died() -> void:
	vehicles.force_leave()
	var rule: Dictionary = DB.data.settings.get("death", {})
	var mode: String = rule.get("mode", "chest")
	var lose := float(rule.get("lose_credits", 0.0))
	if lose > 0.0:
		credits -= int(credits * lose)
	if mode == "keep" or player.inv.is_empty():
		return
	var keep_bar: bool = rule.get("keep_hotbar", false)
	var inv := Inventory.new(player.inv.size())
	for i in player.inv.size():
		if keep_bar and player.inv.slots[i] != null and player.inv.slots[i].id in player.hot_items.values():
			continue
		inv.slots[i] = player.inv.slots[i]
		player.inv.slots[i] = null
	player.inv.changed.emit()
	if mode == "drop":
		for st in inv.slots:
			if st != null:
				drops.spawn(st.id, st.n, player.position + Vector3(randf_range(-1, 1), 1, randf_range(-1, 1)))
		return
	if mode == "lose":
		return
	add_grave(player.position, inv)
	notify("Ваши вещи остались в сундуке на месте гибели (отмечен красным флагом)", Color(1, 0.7, 0.4))


func add_grave(pos: Vector3, inv: Inventory) -> void:
	var node := ModelLib.make_node("grave_chest")
	node.position = World.wrap_pos(pos) if world.wrap else pos
	node.position.y = factory.support_at(node.position)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.35, 0.3)
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = Vector3(0, 2.0, 0)
	node.add_child(light)
	add_child(node)
	graves.append({"pos": node.position, "inv": inv, "node": node, "t": 0.0})
	Net._self().report_inv_now()


func _update_graves(delta: float) -> void:
	var life := float(DB.data.settings.get("death", {}).get("chest_lifetime", 0))
	for g in graves.duplicate():
		g.t += delta
		if life > 0.0 and g.t > life:
			_remove_grave(g)
			continue
		# A-5 r7: свой сундук может забрать любой из героев сплитскрина
		var try_take := func():
			if graves.has(g) and player.alive and World.dist(player.position, g.pos) < 2.6:
				take_grave(g)
		if split != null and split.active:
			for si in 2:
				split.with_seat(si, try_take)
		else:
			try_take.call()


## Забрать всё из сундука героя, что влезет.
func take_grave(g: Dictionary) -> void:
	var inv: Inventory = g.inv
	var got := 0
	for i in inv.size():
		var st = inv.slots[i]
		if st == null:
			continue
		if player.inv.slots.size() > i and player.inv.slots[i] == null:
			player.inv.slots[i] = st
			inv.slots[i] = null
			got += st.n
			continue
		var left: int = player.inv.add_slot(st)
		got += st.n - left
		if left > 0:
			st.n = left
		else:
			inv.slots[i] = null
	player.inv.changed.emit()
	if got > 0:
		sfx.play("pickup", player.position)
	if inv.is_empty():
		_remove_grave(g)
	if got > 0:
		Net._self().report_inv_now()   # B-3 r4: хозяин сразу знает и рюкзак, и могилу
	if not inv.is_empty():
		# B-11 r5: рюкзак полон — часть (или всё) осталось в сундуке
		if got > 0 or Time.get_ticks_msec() - int(g.get("full_ms", -99999)) > 8000:   # B-3 r6: не каждый кадр
			g["full_ms"] = Time.get_ticks_msec()
			notify("Инвентарь полон — часть вещей осталась в сундуке", Color(1, 0.8, 0.5))
	elif got > 0:
		notify("Вы забрали свои вещи", Color(0.6, 1, 0.7))


func _remove_grave(g: Dictionary) -> void:
	if is_instance_valid(g.node):
		g.node.queue_free()
	graves.erase(g)


var _pick_combo := 0
var _pick_t := 0


func on_picked(id: String, n: int) -> void:
	if n > 0:
		notify("+%d %s" % [n, DB.item_name(id)], DB.item_color(id).lightened(0.3))
		# 1.3: «+1 Бревно» над героем и звонкий звук, который поднимается, если подбираешь подряд
		var now := Time.get_ticks_msec()
		_pick_combo = _pick_combo + 1 if now - _pick_t < 900 else 0
		_pick_t = now
		if player:
			fx.number(player.position + Vector3(0, 2.6, 0), "+%d %s" % [n, DB.item_name(id)], DB.item_color(id).lightened(0.4))
		sfx.play_ui("blip", pow(1.0595, mini(_pick_combo, 12)))


var _once := {}
func notify_once(key: String, text: String, col := Color.WHITE) -> void:
	var now := Time.get_ticks_msec()
	if now - _once.get(key, -99999) < 4000:
		return
	_once[key] = now
	notify(text, col)


## Износ предмета в слоте героя (если включён модуль прочности).
## Телепорты (14.7): следующий по кругу телепорт после этого (null — второго нет).
func next_teleporter(from):
	var tps: Array = factory.all.filter(func(b): return not b.dead and b.p("teleport", false))
	if tps.size() < 2:
		return null
	tps.sort_custom(func(a, b): return a.cell.x * 100000 + a.cell.y < b.cell.x * 100000 + b.cell.y)
	var i := tps.find(from)
	return tps[(i + 1) % tps.size()]


## Перенести героя в точку (телепорт, консоль).
func teleport_player(pos: Vector3) -> void:
	player.position = Vector3(pos.x, maxf(pos.y, factory.support_at(pos)), pos.z)
	cam_focus = player.position
	if fog:
		fog.reveal(player.position, float(DB.setting("fog_reveal_radius", 30)))


func wear(slot: int) -> void:
	if slot < 0 or slot >= player.inv.size() or not module("durability"):
		return
	var s = player.inv.slots[slot]
	if s == null:
		return
	var maxd := float(DB.item(s.id).get("durability", 0))
	if maxd <= 0:
		return
	s["dur"] = float(s.get("dur", maxd)) - 1.0
	if s.dur <= 0.0:
		player.inv.slots[slot] = null
		for i in player.hot_items.keys():
			player.hot_slot(i)
		player.inv.changed.emit()
		notify("Сломалось: " + DB.item_name(s.id), Color(1, 0.5, 0.4))
		sfx.play("hit", player.position)


# ---------------------------------------------------------------- автотест (для разработки)

var _shot_path := ""
var _rec_dir := ""        # --rec=папка: сохранять каждый кадр (для роликов и проверки анимации)
var _rec_from := 0
var _mdemo := false
var _shot_frame := 0
var _frame := 0
var _proc_sum := 0.0
var _proc_max := 0.0
var _script_steps: Array = []

func _check_test_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frame = int(a.substr(9))
		elif a.begins_with("--time="):
			day_t = float(a.substr(7))
		elif a.begins_with("--select="):
			hud.close_all()
			select_build(a.substr(9))
		elif a.begins_with("--open="):
			hud.close_all()
			ui_action(a.substr(7))
		elif a == "--nohelp":
			hud.close_all()
			if tutorial.active:
				tutorial.active = false
				tutorial.card.visible = false
		elif a.begins_with("--tut_demo="):
			# для скриншота: шаг обучения N
			tutorial.done = false
			tutorial.active = true
			tutorial.step = int(a.substr(11))
			tutorial._enter()
		elif a.begins_with("--wavenum="):
			enemies.wave = int(a.substr(10))
		elif a.begins_with("--wave="):
			enemies.wave_timer = float(a.substr(7))
		elif a.begins_with("--timescale="):
			Engine.time_scale = float(a.substr(12))
		elif a.begins_with("--screen="):
			_show_screen.call_deferred(a.substr(9))
		elif a == "--hotbar-demo":
			hud.close_all()
			DemoSetup.hotbar_demo(self)
		elif a == "--item-belts":
			hud.close_all()
			DemoSetup.item_belts(self)
		elif a.begins_with("--ports"):
			hud.close_all()
			DemoSetup.ports(self, int(a.substr(8)) if a.length() > 8 else 0)
		elif a.begins_with("--belts"):
			hud.close_all()
			DemoSetup.belts(self, int(a.substr(8)) if a.length() > 8 else 0)
		elif a.begins_with("--pref="):
			# --pref=ключ:значение — настройка только на этот запуск (замеры и скриншоты), в файл не пишется
			var kv := a.substr(7).split(":")
			if kv.size() == 2:
				Prefs.values[kv[0]] = str_to_var(kv[1]) if kv[1] in ["true", "false"] or kv[1].is_valid_float() else kv[1]
				on_pref_changed(kv[0])
		elif a.begins_with("--cam="):
			var cv := a.substr(6).split(",")
			cam_dist = float(cv[0])
			cam_pitch_override = float(cv[1]) if cv.size() > 1 else 0.0
			if cv.size() > 2:
				cam_yaw = deg_to_rad(float(cv[2]))
				cam_yaw_target = cam_yaw
			cam_dist_target = cam_dist
		elif a == "--run_shot":         # скриншоты: герой бежит (ноги в движении)
			Input.action_press("move_up")
			Input.action_press("sprint")
		elif a.begins_with("--hold="):    # скриншоты: герой с предметом в руке
			hud.close_all()
			hud.root.visible = false
			player.inv.slots[0] = {"id": a.substr(7), "n": 1}
			hot_select(0)
		elif a == "--hold_gun":       # скриншоты: герой с бластером в руке
			hud.close_all()
			hud.root.visible = false
			player.inv.slots[0] = {"id": "blaster", "n": 1}
			hot_select(0)
		elif a.begins_with("--pose="):
			hud.close_all()
			flags["pose"] = float(a.substr(7))
			hud.root.visible = false
			player.hips.rotation.y = 0.0
		elif a == "--terrain-demo":
			hud.close_all()
			DemoSetup.terrain_demo(self)
		elif a == "--fluid-demo":
			hud.close_all()
			var fbase: Vector2i = factory.hq.cell + Vector2i(8, 7)
			var fl: Dictionary = DemoSetup.fluid_layout(self, fbase)
			for t in ["oil_pump", "refinery", "packager", "fuel_generator"]:
				for fb in factory.all:
					if fb.type == t:
						fb.active = true
						factory.renderer(t).set_active(fb, 1.0)
			if fl.ref:
				fl.ref.inv.add("oil", 6)
			for fp in fl.pipes:
				if fp:
					fp.fluid = "oil" if fp.cell.x < fbase.x + 6 else "fuel"
					fp.famt = 3.0
			factory.fluid_dirty = true
			player.position = World.cell_to_world(fbase + Vector2i(8, 4))
		elif a.begins_with("--power-demo"):
			hud.close_all()
			DemoSetup.power_demo(self, int(a.substr(13)) if a.length() > 13 else 0)
		elif a.begins_with("--art"):
			hud.close_all()
			DemoSetup.art(self, int(a.substr(6)) if a.length() > 6 else 0)
		elif a == "--miner_demo":       # скриншоты: бур 3×3 на залежи, рядом свободная залежь и камни
			hud.close_all()
			hud.root.visible = false
			flags["free_build"] = true
			var ore := DemoSetup.nearest_deposit(self, "iron_ore", factory.hq.cell)
			var ore2 := DemoSetup.nearest_deposit(self, "iron_ore", factory.hq.cell, [ore])
			var dc := world.dep_corner(ore)
			for dx in range(-8, 9):
				for dz in range(-6, 10):
					if not world.deposit.has(World.wc(dc + Vector2i(dx, dz))) and not world.nodes.get(World.wc(dc + Vector2i(dx, dz)), {"res": ""}).res.begins_with("ore") and not world.nodes.get(World.wc(dc + Vector2i(dx, dz)), {"res": ""}).res.begins_with("rock"):
						world.remove_node(World.wc(dc + Vector2i(dx, dz)))
			DemoSetup.put(self, "miner", world.dep_corner(ore), 0)
			player.position = World.cell_to_world(world.dep_corner(ore) + Vector2i(-2, 4))
			player.position.y = player.support(player.position)
			cam_focus = player.position
		elif a == "--pose_sheet":       # 1.1.10: скриншот — стойка с оружием, шаг при повороте, ходьба, бег, удар
			_pose_sheet()
		elif a.begins_with("--gait_sheet"):     # скриншоты: позы бега, шага и прыжка героя рядом (вид сбоку)
			_gait_sheet(int(a.substr(13)) if a.length() > 13 else -1)
		elif a.begins_with("--lineup="):
			hud.close_all()
			DemoSetup.lineup(self, a.substr(9).split(","))
		elif a == "--steam_showcase":
			hud.close_all()
			DemoSetup.steam_showcase(self)
		elif a == "--demo":
			hud.close_all()
			DemoSetup.build(self)
		elif a.begins_with("--heart_shot"):   # 1.1.15: скриншот — сердца у штаба (и погода стратегии: --heart_shot=frost)
			hud.close_all()
			flags["no_waves"] = true
			for k in 3:
				DemoSetup.put(self, "heart", factory.hq.cell + Vector2i(5 + k * 3, 4), 0)
			player.position = World.cell_to_world(factory.hq.cell + Vector2i(8, 6))
			cam_focus = player.position
			if a.length() > 13:
				events.active[a.substr(13)] = 300.0
		elif a == "--builders18":
			hud.close_all()
			DemoSetup.builders18(self)
		elif a.begins_with("--shots19="):
			hud.close_all()
			DemoSetup.shots19(self, a.substr(10))
		elif a == "--flow":
			flow_map.toggle()
		elif a.begins_with("--stress="):
			hud.close_all()
			DemoSetup.stress(self, int(a.substr(9)))
		elif a.begins_with("--yaw="):
			cam_yaw = float(a.substr(6)); cam_yaw_target = cam_yaw
		elif a.begins_with("--dist="):
			cam_dist = float(a.substr(7)); cam_dist_target = cam_dist
		elif a.begins_with("--cmd="):
			for c in a.substr(6).split(";"):
				console.run(c)
		elif a == "--mech_demo":
			# для скриншота: механические враги вокруг героя (стоят на месте)
			flags["god"] = true
			var spots := [["spitter", Vector3(3.5, 0, -2.5)], ["crawler", Vector3(4.0, 0, 1.0)], ["brute", Vector3(1.0, 0, 4.2)], ["runner", Vector3(-2.5, 0, 3.0)], ["crawler", Vector3(-3.0, 0, -1.5)]]
			for sp in spots:
				var me = enemies.spawn(sp[0], player.position + sp[1])
				if me:
					me.speed = 0.0
		elif a == "--defense_demo":
			# для скриншота: большой щит, турели и стазис возле героя, роботы снаружи (энергия для снимка не нужна)
			flags["god"] = true
			flags["free_build"] = true
			for t in ["barrier_large", "stasis_field", "repair_tower"]:
				DB.data.buildings[t].params["power"] = 0
			var pc: Vector2i = World.world_to_cell(player.position)
			for dx in range(-22, 23):
				for dz in range(-30, 12):
					world.remove_node(pc + Vector2i(dx, dz))
			for pb in [["barrier_large", Vector2i(0, -6)], ["gatling_turret", Vector2i(-4, -9)], ["cannon_turret", Vector2i(4, -9)],
					["missile_turret", Vector2i(-6, -4)], ["flame_turret", Vector2i(6, -4)], ["stasis_field", Vector2i(0, -12)],
					["repair_tower", Vector2i(-2, -2)], ["sniper_tower", Vector2i(3, -1)]]:
				DemoSetup.put(self, pb[0], pc + pb[1], 0)
			for i in 6:
				var me = enemies.spawn(["crawler", "brute", "guard", "runner", "sniper", "bomber"][i], World.cell_to_world(pc + Vector2i(-10 + i * 4, -17)))
				if me:
					me.speed = 0.0
			defense._scan_t = 0.0
		elif a == "--fusion_demo":
			# для скриншота: объединённые печи 3 ур., сборная линия с турелью на крыше, предложение объединить
			flags["god"] = true
			flags["free_build"] = true
			player.position = World.cell_to_world(World.wc(factory.hq.cell + Vector2i(-9, 10)))
			cam_focus = player.position
			var fc: Vector2i = World.world_to_cell(player.position)
			for dx in range(-12, 13):
				for dz in range(-14, 6):
					world.remove_node(fc + Vector2i(dx, dz))
			var fz = factory.fz
			DB.data.settings.fusion["ask_time"] = 9999.0
			var lv: Array = []
			for i in 4:
				lv.append(DemoSetup.put(self, "furnace", fc + Vector2i(-7 + i % 2, -3 + i / 2), 0))
			fz.fuse_level(lv[0], lv[1])
			fz.fuse_level(lv[2], lv[3])
			fz.fuse_level(lv[0], lv[2])
			var t1 = DemoSetup.put(self, "gatling_turret", fc + Vector2i(-2, -4), 0)
			fz.fuse_level(t1, DemoSetup.put(self, "gatling_turret", fc + Vector2i(-1, -4), 0))
			var hc: Vector2i = fc + Vector2i(3, -2)
			var host = DemoSetup.put(self, "furnace", hc, 0)
			for t in ["assembler", "wind_turbine", "battery_block", "chest"]:
				fz.fuse_combo(host, DemoSetup.put(self, t, hc + Vector2i(1, 0), 0))
			var h2 = DemoSetup.put(self, "assembler", fc + Vector2i(3, 2), 0)
			for t in ["gatling_turret", "repair_tower", "solar"]:
				fz.fuse_combo(h2, DemoSetup.put(self, t, fc + Vector2i(4, 2), 0))
			var fargs := OS.get_cmdline_user_args()
			if "--fusion_open" in fargs or "--fusion_near" in fargs:
				host.inv.add("iron_ore", 12)
				player.position = host.center() + Vector3(2.5, 0, 3.5)
				cam_focus = player.position
				if "--fusion_open" in fargs:
					hud.open_building.call_deferred(host)
			else:
				cmd("place", {"type": "furnace", "cell": fc + Vector2i(-5, 2), "dir": 0})
				cmd("place", {"type": "furnace", "cell": fc + Vector2i(-4, 2), "dir": 0})
		elif a == "--drones_demo" or a == "--drones_open":
			# для скриншота: станция дронов «Объединение 3» (4 дрона) возит руду из ящика А в ящик Б
			flags["god"] = true
			flags["free_build"] = true
			DB.data.buildings["drone_station"].params["power"] = 0
			player.position = World.cell_to_world(World.wc(factory.hq.cell + Vector2i(-9, 10)))
			cam_focus = player.position
			var dc: Vector2i = World.world_to_cell(player.position)
			for dx in range(-12, 13):
				for dz in range(-10, 6):
					world.remove_node(dc + Vector2i(dx, dz))
			var stn = DemoSetup.put(self, "drone_station", dc + Vector2i(0, -3), 0)
			var sts := [stn, DemoSetup.put(self, "drone_station", dc + Vector2i(1, -3), 0), DemoSetup.put(self, "drone_station", dc + Vector2i(0, -4), 0), DemoSetup.put(self, "drone_station", dc + Vector2i(1, -4), 0)]
			factory.fz.fuse_level(sts[0], sts[1])
			factory.fz.fuse_level(sts[2], sts[3])
			factory.fz.fuse_level(sts[0], sts[2])
			var ca = DemoSetup.put(self, "chest", dc + Vector2i(-5, -1), 0)
			var cb = DemoSetup.put(self, "chest", dc + Vector2i(5, -1), 0)
			ca.inv.add("iron_ore", 200)
			drones.set_routes(stn, [{"from": [ca.cell.x, ca.cell.y], "to": [cb.cell.x, cb.cell.y], "item": "", "keep": 0, "on": true}])
			drones.sync()
			for i in 120:
				drones.update(0.1)
			if a == "--drones_open":
				player.position = stn.center() + Vector3(-2.0, 0, 3.0)
				cam_focus = player.position
				hud.open_building.call_deferred(stn)
		elif a in ["--ufo_demo", "--ufo_open", "--tune_open", "--pattern_open", "--gate_open"]:
			# для скриншотов 14.23: НЛО над площадкой, окно площадки, ручка настройки печи, инженерный стол, звёздные врата
			flags["god"] = true
			flags["free_build"] = true
			player.position = World.cell_to_world(World.wc(factory.hq.cell + Vector2i(-14, 12)))
			cam_focus = player.position
			var uc: Vector2i = World.world_to_cell(player.position)
			for dx in range(-16, 16):
				for dz in range(-14, 10):
					world.remove_node(uc + Vector2i(dx, dz))
			var pad = DemoSetup.put_near(self, "ufo_pad", uc + Vector2i(-4, -6))
			var gate = DemoSetup.put_near(self, "star_gate", uc + Vector2i(8, -8))
			var sm = DemoSetup.put_near(self, "smelter", uc + Vector2i(4, 2))
			var tbl = DemoSetup.put_near(self, "eng_table", uc + Vector2i(-2, 2))
			DemoSetup.put_near(self, "fusion_reactor", uc + Vector2i(-12, 2))
			DemoSetup.put_near(self, "quantum_assembler", uc + Vector2i(1, -2))
			DemoSetup.put_near(self, "exotic_forge", uc + Vector2i(-6, 4))
			var ps := Starworks.st(pad)
			ps.orders = [{"id": "helium3", "n": 20}, {"id": "antimatter", "n": 1}]
			pad.inv.add("circuit", 300)
			pad.out.add("helium3", 12)
			day_n = 6
			for k in Starworks.stages()[0].need:
				gate.bstate["have"] = gate.bstate.get("have", {})
				gate.bstate.have[k] = int(Starworks.stages()[0].need[k]) / 2
			sm.inv.add("iron_ore", 30)
			sm.cfg["tune"] = Tuning.center("heat") + 2.0
			tbl.cfg["cells"] = ["", "", "", "", "coal_hq", "coal_hq", "coal_hq", "coal_hq", "iron_ingot", "iron_ingot", "", "", "", "", "", ""]
			player.inv.add("coal_hq", 8)
			player.inv.add("iron_ingot", 8)
			if a == "--ufo_demo":
				ps.phase = "landed"
				ps.anim = 0.0
				player.position = pad.center() + Vector3(10, 0, 12)
				cam_focus = player.position
			else:
				var tgt = {"--ufo_open": pad, "--tune_open": sm, "--pattern_open": tbl, "--gate_open": gate}[a]
				player.position = tgt.center() + Vector3(-2.5, 0, 4.0)
				cam_focus = player.position
				hud.open_building.call_deferred(tgt)
		elif a.begins_with("--ai_demo="):
			# 15.7: для скриншота: герой и монстры из готовых GLB через автоскелет (--ai_demo=герой.glb,монстр.glb)
			flags["god"] = true
			var fl := a.substr(10).split(",")
			var hr := AutoRig.rig(AutoRig.load_mesh(fl[0]), {"kind": "hero", "id": "ai_demo_hero"})
			for rel in hr.meshes:
				ModelLib.put_mesh(rel, hr.meshes[rel])
			DB.data.models["ai_demo_hero"] = hr.model
			if fl.size() > 1:
				var mr := AutoRig.rig(AutoRig.load_mesh(fl[1]), {"kind": "monster", "id": "ai_demo_mon", "height": 1.3})
				for rel in mr.meshes:
					ModelLib.put_mesh(rel, mr.meshes[rel])
				DB.data.models["ai_demo_mon"] = mr.model
				DB.data.enemies["crawler"]["model"] = "ai_demo_mon"
				DB.data.enemies["crawler"]["damage"] = 0
				for i in 3:
					enemies.spawn("crawler", player.position + Vector3(7 + i * 2.5, 0, -3 + i * 3))
			DB.data.settings["hero_model"] = "ai_demo_hero"
			DB.revision += 1
			var h2 = Player.new()
			h2.game = self
			add_child(h2)
			h2.position = player.position + Vector3(2.5, 0, 1.5)
			h2.build()
			h2.leg_l.rotation.z = 0.5
			h2.leg_r.rotation.z = -0.4
			h2.shin_r.rotation.z = -0.6
			h2.arm_l.rotation.z = -0.5
			h2.arm_r.rotation.z = 0.6
			h2.fore_r.rotation.z = 0.5
			h2._sync_skin()
			cam_focus = player.position + Vector3(3, 0, 0)
			cam_dist = 12.0
			cam_dist_target = 12.0
		elif a == "--inv_demo":
			# проверка: окно инвентаря не прыгает, когда меняется содержимое (крафт, перенос предмета)
			hud.open("inventory")
			var fr := [0]
			var ys := []
			get_tree().process_frame.connect(func():
				fr[0] += 1
				if fr[0] > 20 and fr[0] < 60:
					var w = hud.windows.inventory
					ys.append(int(w.position.y) * 10000 + int(w.size.y))
					if fr[0] % 3 == 0:
						player.inv.add("stone", 1)
					if fr[0] % 7 == 0:
						var a0 = player.inv.slots[0]
						player.inv.slots[0] = player.inv.slots[5]
						player.inv.slots[5] = a0
						player.inv.changed.emit()
				if fr[0] == 60:
					var uniq := {}
					for y in ys:
						uniq[y] = true
					print("TEST inv_jump rects=", uniq.keys().map(func(v): return "y%d h%d" % [v / 10000, v % 10000]), " ", "OK" if uniq.size() <= 2 else "FAIL"))
		elif a.begins_with("--coop_demo"):
			# 16: для скриншота: рынок игрока с товаром, табличка, розовое здание, окно «Фишки» или окно рынка
			flags["free_build"] = true
			var c0 := World.world_to_cell(player.position)
			var mk = preload("res://scripts/demo_setup.gd").put_near(self, "player_market", c0 + Vector2i(4, -3))
			if mk:
				mk.inv.add("iron_ingot", 40)
				mk.inv.add("copper_ingot", 25)
				mk.inv.add("plank", 60)
				mk.cfg = {"prices": {"iron_ingot": 5, "copper_ingot": 6, "plank": 2}, "wants": {"stone": [3, 100], "coal": [4, 50]}}
			var sg = preload("res://scripts/demo_setup.gd").put_near(self, "sign", c0 + Vector2i(-2, 3))
			if sg:
				sg.cfg = {"text": "Здесь был Вася"}
			var ch = preload("res://scripts/demo_setup.gd").put_near(self, "chest", c0 + Vector2i(-4, -2))
			if ch:
				coop.paint(ch, "Вася")
			preload("res://scripts/demo_setup.gd").put_near(self, "gnome", c0 + Vector2i(-1, 4))
			coop.bubble(player, "Ура!", 60.0)
			coop.confetti(player.position + Vector3(0, 2.5, 0))
			cam_focus = player.position + Vector3(2, 0, 0)
			if a == "--coop_demo=market" and mk:
				hud.open_building(mk)
			else:
				coop.toggle_panel()
		elif a.begins_with("--admin_demo"):
			# 1.1.11: для скриншота: админ-панель на нужной вкладке (--admin_demo=items)
			admin.login("")
			if "=" in a:
				admin.tab = a.split("=")[1]
				if admin.tab == "items":
					admin.item_q = "руда"
			admin.refresh()
		elif a == "--v19_demo":
			# 1.1.9: для скриншота: порты зданий (синие входы, зелёные выходы), часть подключена лентами
			flags["free_build"] = true
			flags["god"] = true
			var rc: Vector2i = World.wc(factory.hq.cell + Vector2i(12, 8))
			player.position = World.cell_to_world(rc + Vector2i(1, 7))
			for dx in range(-8, 16):
				for dz in range(-8, 12):
					world.remove_node(World.wc(rc + Vector2i(dx, dz)))
			var sm = DemoSetup.put(self, "smelter", rc, 0)
			var fu = DemoSetup.put(self, "furnace", rc + Vector2i(0, 4), 0)
			var asm = DemoSetup.put(self, "assembler", rc + Vector2i(6, 0), 1)
			DemoSetup.put(self, "chest", rc + Vector2i(7, 5), 0)
			if sm != null:
				for k in 2:
					DemoSetup.put(self, "belt", World.wc(sm.pin[0] - Vector2i(k, 0)), 0)
				DemoSetup.put(self, "belt", sm.pout[0], 0)
				DemoSetup.put(self, "belt", World.wc(sm.pout[0] + Vector2i(1, 0)), 0)
			if fu != null:
				DemoSetup.put(self, "belt", World.wc(fu.pin[0] - Vector2i(1, 0)), 0)
				DemoSetup.put(self, "belt", fu.pin[0], 0)
				if fu.pfuel >= 0:
					# 1.1.11: вход для топлива — отдельная лента с углём
					DemoSetup.put(self, "belt", World.wc(fu.pin[fu.pfuel] - Vector2i(1, 0)), 0)
					var fb = DemoSetup.put(self, "belt", fu.pin[fu.pfuel], 0)
					if fb:
						factory.set_item(fb, "coal")
			cam_focus = World.cell_to_world(rc + Vector2i(4, 3))
			player.position = World.cell_to_world(rc + Vector2i(3, 3))
			cam_dist = 20.0
			cam_dist_target = 20.0
			if tutorial:
				tutorial.skip()
			cam_dist = 13.0
			cam_dist_target = 13.0
			player.position = World.cell_to_world(rc + Vector2i(2, 3))
		elif a.begins_with("--v18_demo"):
			# 1.1.8: для скриншота: бур на земле → лифт → лента на фундаменте → печь на фундаменте; Чёрный рынок; залежь на фундаменте
			flags["free_build"] = true
			flags["god"] = true
			var rc: Vector2i = World.wc(factory.hq.cell + Vector2i(12, 8))
			player.position = World.cell_to_world(rc + Vector2i(2, 5))
			for dx in range(-8, 14):
				for dz in range(-8, 10):
					world.remove_node(World.wc(rc + Vector2i(dx, dz)))
			for k in range(3, 9):
				for j in range(-1, 3):
					DemoSetup.put(self, "found_1", rc + Vector2i(k, j), 0)
			DemoSetup.put(self, "belt", rc, 0)
			DemoSetup.put(self, "belt", rc + Vector2i(1, 0), 0)
			DemoSetup.put(self, "lift_mk1", rc + Vector2i(2, 0), 0)
			DemoSetup.put(self, "belt", rc + Vector2i(3, 0), 0)
			DemoSetup.put(self, "belt", rc + Vector2i(4, 0), 0)
			DemoSetup.put(self, "black_market", rc + Vector2i(5, 0), 0)
			DemoSetup.put(self, "belt", rc + Vector2i(0, 3), 0)
			DemoSetup.put(self, "lift_mk3", rc + Vector2i(1, 3), 0)
			DemoSetup.put(self, "lift_mk5", rc + Vector2i(2, 3), 0)
			DemoSetup.put(self, "black_market", rc + Vector2i(-2, 0), 0)
			# залежь под фундаментом
			for cc in world.dep_marks.keys():
				if World.dist(World.cell_to_world(cc), player.position) < 40.0 and not factory.grid.has(cc) and zone.inside_cell(cc):
					DemoSetup.put(self, "found_1" if world.dep_fp(world.deposits[world.deposit[cc]]) <= 1 else "found_2", cc, 0)
					break
			cam_focus = World.cell_to_world(rc + Vector2i(3, 1))
			if a == "--v18_demo=explain":
				hud.show_explain("black_market")
		elif a == "--patch_demo":
			# 15.5: для скриншота: открытый участок у края зоны и рамка выбора следующего
			flags["free_build"] = true
			var zc: Vector3 = zone.center
			var e1: Vector3 = zc + Vector3(zone.half() + zone.block_m() * 1.5, 0, 0)
			zone.open_patch(zone.patch_at(e1), true)
			player.position = zc + Vector3(zone.half() - 6.0, 0, 30.0)
			cam_focus = player.position
			ui_action("zone_pick")
			hover_point = zc + Vector3(zone.half() + zone.block_m() * 1.0, 0, zone.block_m() * 5.0)
		elif a == "--reactor_demo" or a == "--reactor_open" or a == "--zone_demo":
			# для скриншота: АЭС с трубами работает (или после аварии — заражённая земля и дозиметр)
			flags["god"] = true
			flags["free_build"] = true
			player.position = World.cell_to_world(World.wc(factory.hq.cell + Vector2i(14, 10)))
			cam_focus = player.position
			var rc: Vector2i = World.world_to_cell(player.position)
			for dx in range(-14, 15):
				for dz in range(-14, 10):
					world.remove_node(rc + Vector2i(dx, dz))
			var r = DemoSetup.put_near(self, "nuclear_reactor", rc + Vector2i(0, -5))
			for i in 6:
				DemoSetup.put(self, "pipe_mk2", r.cell + Vector2i(-2 - i, 0), 1)
			DemoSetup.put(self, "waste_storage", r.cell + Vector2i(3, 2), 0)
			DemoSetup.put(self, "decon_station", r.cell + Vector2i(-3, 3), 0)
			for i in 4:
				DemoSetup.put(self, "chest", r.cell + Vector2i(4 + i, -2), 0)
			r.fuel.add("fuel_rod", 6)
			var rs := Nuclear.st(r)
			rs.load = 4
			rs.pump = 1.0
			rs.rods_set = 0.45
			rs.rods = 0.45
			for i in 1200:
				Nuclear.add_water(r, 100.0)
				factory.nuc.power(r, 0.1, false)
			rs.water = Nuclear.water_buf()
			if a == "--zone_demo":
				player.clothes = "hazmat_suit"
				player.inv.add("decon_spray", 5)
				player.inv.add("fuel_rod", 2)
				rs.rods_set = 0.0
				rs.pump = 0.0
				rs.water = 0.0
				var guard := 0
				while not r.dead and guard < 5000:
					factory.nuc.power(r, 0.1, false)
					guard += 1
				events.shake = 0.0
				player.position += Vector3(4, 0, -2)
				cam_focus = player.position
				hazards._step(0.5)
				hazards.dose = 46.0
			elif a == "--reactor_open":
				rs.T = 412.0
				player.position = r.center() + Vector3(-3.0, 0, 5.0)
				cam_focus = player.position
				hud.open_building.call_deferred(r)
		elif a.begins_with("--omen_demo="):
			# для скриншота: зловещая надпись события висит долго
			var oe: Dictionary = DB.data.events.get(a.substr(12), {})
			hud.omen(str(oe.get("omen", "")), DB.color(oe.get("omen_color", "#ff5040")), 600.0, "")
		elif a == "--nohud":
			# для картинок магазина: без интерфейса
			hud.root.visible = false
			flags["quiet"] = true
		elif a == "--quiet":
			# для скриншотов: без всплывающих сообщений
			flags["quiet"] = true
		elif a == "--known_all":
			# для скриншота: все предметы найдены и изучены
			for kid in DB.data.items:
				DB.known[kid] = true
				DB.researched[kid] = true
			DB.revision += 1
		elif a.begins_with("--tip_demo="):
			# для скриншота: подсказка предмета (i:id) или здания (b:id) висит на экране
			var tid := a.substr(11)
			for kid in DB.data.items:
				DB.known[kid] = true
				DB.researched[kid] = true
			DB.revision += 1
			var tp := PanelContainer.new()
			tp.add_theme_stylebox_override("panel", UI.theme().get_stylebox("panel", "TooltipPanel"))
			if tid.begins_with("b:"):
				tp.add_child(UI.tip_panel(UI.building_tip(tid.substr(2)), UI.building_icon(tid.substr(2), 56)))
			else:
				tp.add_child(UI.tip_panel(UI.item_tip(tid.substr(2), 12), UI.item_icon(tid.substr(2), 48)))
			tp.position = Vector2(get_viewport().get_visible_rect().size.x - 500, 90)
			hud.root.add_child(tp)
		elif a == "--npc_demo":
			# для скриншота: торговец рядом с героем и открытое окно торговли
			var tr: Array = npcs.spawn_visit("trader", 1)
			if not tr.is_empty():
				tr[0].pos = player.position + Vector3(3, 0, 1)
				tr[0].state = "stay"
				tr[0].timer = 999.0
				cam_yaw_target = 0.9
				hud.open_npc(tr[0])
		elif a == "--ev_now":
			# для скриншота: погода события сразу в полную силу
			events._update_visuals(100.0)
		elif a == "--dungeon_demo":
			# для скриншота: герой у входа в подземелье
			if not dungeons.list.is_empty():
				var dd: Dictionary = dungeons.list[0]
				var side: int = int(dd.level) % 4
				var door: Vector2i = [Vector2i(0, 9), Vector2i(9, 0), Vector2i(0, -9), Vector2i(-9, 0)][side]
				teleport_player(World.cell_to_world(World.wc(dd.cell + door)))
				fog.reveal(player.position, 60.0)
				cam_yaw_target = [PI * 0.5, 0.0, -PI * 0.5, PI][side]
		elif a == "--ctor_demo":
			# для скриншота: конструктор модов с примером здания (основа + свои детали)
			hud.close_all()
			hud.ctor = ModCtor.new(hud)
			var c: ModCtor = hud.ctor
			c.new_object("buildings")
			c.rec["name"] = "Маяк-сигнальщик"
			c.rec["desc"] = "Мой первый мод: светится и даёт камень"
			c.rec["blocks"] = [{"type": "produce", "item": "stone", "n": 1, "every": 5.0, "needs_power": false}]
			c.extra = [{"shape": "cylinder", "size": [0.25, 1.6, 0.25], "pos": [0, 2.1, 0], "rot": [0, 0, 0], "color": "#9aa3ad", "mat": "metal"},
				{"shape": "sphere", "size": [0.5, 0.5, 0.5], "pos": [0, 3.0, 0], "rot": [0, 0, 0], "color": "#40c8ff", "mat": "glow"},
				{"shape": "torus", "size": [0.9, 0.12, 0.9], "pos": [0, 2.6, 0], "rot": [0, 0, 0], "color": "#ffa040", "mat": "paint"}]
			hud.open("constructor")
		elif a == "--flare_demo":
			# для скриншота: щит-купол и бункер рядом с героем, идёт солнечный выброс
			var pc: Vector2i = World.world_to_cell(player.position)
			flags["free_build"] = true
			var dm = DemoSetup.put_near(self, "shield_dome", pc + Vector2i(-3, -4))
			var gn = DemoSetup.put_near(self, "generator", pc + Vector2i(-7, -4))
			if gn and gn.fuel:
				gn.fuel.add("coal", 50)
			DemoSetup.put_near(self, "bunker", pc + Vector2i(8, -3))
			if dm:
				DemoSetup.put_near(self, "assembler", dm.cell + Vector2i(3, 2))
			factory.auto_wire_all()
			factory.power_dirty = true
			events.start("solar_flare")
			events.active["solar_flare"] = 50.0
			cam_yaw_target = 0.5
		elif a == "--orders_demo":
			orders.place("sell", "iron_ingot", 100, roundi(orders.unit_price("iron_ingot") * 100))
			orders.place("sell", "steel", 20, 999999)
			orders.place("buy", "circuit", 30, roundi(orders.unit_price("circuit") * 30 * 1.1))
			for o in orders.list:
				if orders.greed(o) < 1.5:
					o.offers.append(orders.make_offer(o))
					o.offers.append(orders.make_offer(o))
			orders._log("Гильдия торговцев купила 50 × Медный слиток за 260 кр — сделка")
			hud.open("orders")
		elif a.begins_with("--rec="):
			_rec_dir = a.substr(6)
		elif a.begins_with("--rec_from="):
			_rec_from = int(a.substr(11))
		elif a == "--monster_demo":
			# монстры рядом с героем: идут к нему, бьют; одного потом убиваем — видно падение
			_mdemo = true
			hud.close_all()
			player.hp = 99999.0
			player.maxhp = 99999.0
			var types := ["crawler", "brute", "spitter", "runner", "crawler", "runner"]
			for i in types.size():
				var ang := TAU * i / types.size()
				var e = enemies.spawn(types[i], player.position + Vector3(cos(ang), 0, sin(ang)) * (9.0 + i * 1.5))
				if e:
					e.target = player
		elif a == "--canopy_demo":   # 1.3: снимок навеса у штаба, герой под ним
			player.position = factory.canopy_center
			cam_focus = player.position
		elif a.begins_with("--at="):
			var p := a.substr(5).split(",")
			player.position = World.cell_to_world(Vector2i(int(p[0]), int(p[1])))
			cam_focus = player.position
		elif a.begins_with("--look_demo"):   # снимки стиля земли: у залежей или у воды (--look_demo=water)
			hud.close_all()
			hud.root.visible = false
			var at: Vector2i = factory.hq.cell + Vector2i(6, 6)
			if a.ends_with("water"):
				var bd := INF
				for dz in range(-90, 91, 2):
					for dx in range(-90, 91, 2):
						var c := World.wc(factory.hq.cell + Vector2i(dx, dz))
						if world.water_at(c) and Vector2(dx, dz).length() < bd and not world.water_at(World.wc(c + Vector2i(-5, 5))):
							bd = Vector2(dx, dz).length()
							at = c + Vector2i(-5, 5)
				if zone != null and zone.on() and not zone.inside(World.cell_to_world(at), 30.0):
					zone.set_blocks(zone.max_blocks())
			else:
				at = DemoSetup.nearest_deposit(self, "copper_ore", factory.hq.cell, [], 8.0) + Vector2i(-3, 4)
				if a.ends_with("found"):   # фундаменты рядом с героем
					flags["free_build"] = true
					for fo in [[Vector2i(-6, 2), "found_2"], [Vector2i(-4, 2), "found_2"], [Vector2i(-6, 4), "found_2"], [Vector2i(-4, 4), "found_1"], [Vector2i(-3, 4), "found_tall"]]:
						for dx in 3:
							for dz in 3:
								world.remove_node(World.wc(at + fo[0] + Vector2i(dx, dz)))
						cmd("place", {"type": fo[1], "cell": World.wc(at + fo[0]), "dir": 0})
			player.position = World.cell_to_world(at)
			player.position.y = player.support(player.position)
			cam_focus = player.position
		elif a == "--split_demo":   # 1.3: снимок сплитскрина — второй игрок с геймпада 1
			split.start.call_deferred(1)
		elif a == "--console":
			console.toggle()
		elif a.begins_with("--openb="):
			for b in factory.all:
				if b.type == a.substr(8):
					player.position = b.center() + Vector3(b.size * World.C * 0.5 + 1.5, 0, 0)
					hud.open_building(b)
					break
		elif a == "--test=ocean":
			preload("res://scripts/ocean_test.gd").run.call_deferred(self)
		elif a.begins_with("--test="):
			DemoSetup.test(self, a.substr(7))


func _test_tick() -> void:
	_frame += 1
	if _frame > 30:
		var pt := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_proc_sum += pt
		_proc_max = max(_proc_max, pt)
	if _rec_dir != "" and _frame >= _rec_from and _frame < _shot_frame and DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [_rec_dir, _frame])
	if _mdemo and _frame == _shot_frame - 45 and not enemies.list.is_empty():
		var near_e = enemies.list[0]
		for e in enemies.list:
			if World.dist(e.pos, player.position) < World.dist(near_e.pos, player.position):
				near_e = e
		enemies.hit(near_e, 999999.0)
	if _shot_frame > 0 and _frame == _shot_frame:
		if _shot_path != "" and DisplayServer.get_name() != "headless":
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot_path)
		print("REPORT credits=", credits, " level=", level, " wave=", enemies.wave, " kills=", enemies.kills, " hq_hp=", factory.hq.hp if factory.hq else -1, " player_hp=", player.hp, " inv=", player.inv.totals(), " hq=", factory.hq.inv.totals() if factory.hq else {})
		print("SHOT saved ", _shot_path, " avg_proc_ms=", _proc_sum / max(1, _frame - 30), " max_proc_ms=", _proc_max, " tick_ms=", factory.prof_tick / 1000.0 / max(1, factory.prof_ticks), " fps=", Engine.get_frames_per_second(), " buildings=", factory.all.size(), " items=", factory.items_on_belts, " enemies=", enemies.list.size(), " mirrors=", mirror.ghosts.size(), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		get_tree().quit()


## 1.3: проверка походки — копии героя в разных фазах шага, бега, спринта и прыжка в ряд, вид сбоку.
func _gait_sheet(only: int) -> void:
	hud.close_all()
	hud.root.visible = false
	player.visible = false
	var base := player.position + Vector3(-30, 0, 20)
	var bc := World.world_to_cell(base)
	for dx in range(-8, 20):
		for dz in range(-10, 8):
			world.remove_node(World.wc(bc + Vector2i(dx, dz)))
	var rows := [[1.4, false], [9.0, false], [15.0, true]]
	for ri in rows.size():
		if only >= 0 and ri != only:
			continue
		for k in 6:
			var h = load("res://scripts/player.gd").new()
			h.game = self
			h.look = player.look
			add_child(h)
			h.build()
			h.gun.visible = false
			h.position = base + Vector3(k * 2.4, 0, -ri * 3.2 if only < 0 else 0.0)
			h.position.y = player.support(h.position)
			h.move_dir = Vector3(float(rows[ri][0]), 0, 0)
			h.aim = h.position + Vector3(20, 0, 0)
			for i in 60:
				h._animate(0.03, rows[ri][1])
			h.phase = float(k) / 6.0
			h._animate(0.0001, rows[ri][1])
			h._sync_skin()
	# прыжок: толчок, взлёт, вершина, падение, приземление
	var vys := [6.0, 3.0, 0.0, -4.0, -9.0]
	for k in (6 if only < 0 or only == 3 else 0):
		var h = load("res://scripts/player.gd").new()
		h.game = self
		h.look = player.look
		add_child(h)
		h.build()
		h.gun.visible = false
		h.position = base + Vector3(k * 2.4, 0, 3.4 if only < 0 else 0.0)
		h.position.y = player.support(h.position)
		h.move_dir = Vector3(9.0, 0, 0)
		h.aim = h.position + Vector3(20, 0, 0)
		for i in 60:
			h._animate(0.03, false)
		if k < 5:
			h.airborne = true
			h.vel_y = vys[k]
			h._lead = 1.0
			h.position.y += [0.4, 1.1, 1.5, 1.1, 0.4][k]
		else:
			h._land_k = 0.8
			h._land_t = 0.0
		for i in 12:
			h._animate(0.02, false)
		h._sync_skin()
	cam_focus = base + Vector3(6, 0, 0)
	player.position = cam_focus


func _pose_sheet() -> void:
	hud.close_all()
	hud.root.visible = false
	player.visible = false
	var base := player.position + Vector3(-30, 0, 20)
	var bc := World.world_to_cell(base)
	for dx in range(-8, 20):
		for dz in range(-10, 8):
			world.remove_node(World.wc(bc + Vector2i(dx, dz)))
	for k in 5:
		var h = load("res://scripts/player.gd").new()
		h.game = self
		h.look = player.look
		add_child(h)
		h.build()
		h.gun.visible = k == 0
		h.position = base + Vector3(k * 2.6, 0, 0)
		h.position.y = player.support(h.position)
		h.aim = h.position + Vector3(20, 0, 0)
		h.move_dir = Vector3([0.0, 0.0, 3.0, 12.0, 0.0][k], 0, 0)
		for i in 90:
			h.t += 0.016
			h._animate(0.016, k == 3)
		if k == 1:
			h.aim = h.position + Vector3(0, 0, 20)
			for i in 9:
				h.t += 0.016
				h._animate(0.016, false)
		elif k == 4:
			h.swing_t = 0.42 * 0.5
			h._animate(0.0001, false)
		h._sync_skin()
	cam_focus = base + Vector3(5.2, 0, 0)
	player.position = cam_focus


# ---------------------------------------------------------------- старт

func _start_base() -> void:
	var wd: Dictionary = DB.data.world
	var c := world.center - Vector2i(1, 1)
	if island != null:
		factory.place("tide_slab", world.center, 0)
		player.inv.add("salvage_rod", 1)
	else:
		for dx in range(-2, 5):
			for dz in range(-2, 5):
				world.remove_node(c + Vector2i(dx, dz))
		factory.place("hq", c, 0)
	var sh: Dictionary = wd.get("start_hq", {})
	for k in sh:
		factory.hq.inv.add(k, int(sh[k]))
	var si: Dictionary = wd.get("start_inventory", {})
	for k in si:
		player.inv.add(k, int(si[k]))
	credits = int(wd.get("start_credits", 100))
	if module("professions"):
		var pd: Dictionary = DB.data.professions.get(profession, {})
		for k in pd.get("start_items", {}):
			player.inv.add(k, int(pd.start_items[k]))
		credits += int(pd.get("start_credits", 0))
	player.seed_hotbar()
	player.position = island.landing() if island != null else factory.hq.center() + (Vector3(-1.6, 0, .8) if strategy else Vector3(6, 0, 6))
	if island != null:
		player.pin_item(0,"salvage_rod")
		player.selected = 0


# ---------------------------------------------------------------- окружение и свет

func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("#aebdde")
	env.ambient_light_sky_contribution = 0.60
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# 17.10: ACES — плотные тени и мягкие светлые участки, как в современных играх
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	# отражённый свет (SSIL): трава подсвечивает стены зелёным, кирпич — землю тёплым
	env.ssil_enabled = bool(Prefs.get_value("ssil", true))
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.ssil_sharpness = 0.9
	env.ssil_normal_rejection = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_light_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = true
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.15
	env.adjustment_enabled = true
	apply_look()
	var we := WorldEnvironment.new()
	we.environment = env
	# глубина резкости «миниатюра»: дальний план и край кадра чуть размыты, база в фокусе
	cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_amount = 0.06
	we.camera_attributes = cam_attr
	add_child(we)
	_make_vignette()
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.6
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.rotation = Vector3(deg_to_rad(-55), deg_to_rad(140), 0)
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)


## Свет и цвета из «Мир и генератор карты» → «Внешний вид» (насыщенность, контраст, яркость, туман).
var cam_attr: CameraAttributesPractical
var vignette: ColorRect


## 17.10: виньетка и лёгкая цветокоррекция поверх картинки (под интерфейсом).
func _make_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -1
	add_child(cl)
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.38;
uniform vec3 tint : source_color = vec3(0.02, 0.03, 0.08);
void fragment() {
	vec2 d = UV - 0.5;
	d.x *= 1.25;
	float v = smoothstep(0.32, 0.86, length(d));
	COLOR = vec4(tint, v * strength);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	vignette.material = m
	cl.add_child(vignette)
	vignette.visible = bool(Prefs.get_value("vignette", true))


## Глубина резкости следует за камерой: в фокусе то, что под героем.
func _update_dof() -> void:
	if cam_attr == null:
		return
	var on := bool(Prefs.get_value("dof", true)) and not photo_dof_off()
	cam_attr.dof_blur_far_enabled = on
	cam_attr.dof_blur_near_enabled = false
	if on:
		cam_attr.dof_blur_far_distance = cam_dist * 1.25 + 6.0
		cam_attr.dof_blur_far_transition = cam_dist * 1.6 + 10.0


func photo_dof_off() -> bool:
	return top_view


func apply_look() -> void:
	var lk: Dictionary = World.look()
	env.tonemap_exposure = float(lk.get("exposure", 1.0)) * 1.05
	env.adjustment_saturation = float(lk.get("saturation", 1.18)) * 0.9   # ACES сам добавляет насыщенности
	env.adjustment_contrast = float(lk.get("contrast", 1.08))
	env.fog_density = float(lk.get("fog", 0.0007))
	if world:
		world.apply_look()


## Настройка игрока изменилась (меню настроек или консоль).
func on_pref_changed(key: String) -> void:
	match key:
		"shadows":
			var q := str(Prefs.get_value("shadows", "high"))
			sun.shadow_enabled = q != "off"
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == "low" else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = {"low": 70.0, "high": 140.0, "ultra": 220.0}.get(q, 140.0)
			var sz := {"low": 2048, "high": 4096, "ultra": 8192}.get(q, 4096)
			RenderingServer.directional_shadow_atlas_set_size(sz, true)
		"ssao", "quality":
			env.ssao_enabled = bool(Prefs.get_value("ssao", true))
			var hi := str(Prefs.get_value("quality", "high")) in ["ultra", "cinema"]
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA if hi else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
		"glow":
			env.glow_enabled = bool(Prefs.get_value("glow", true))
		"ssil":
			env.ssil_enabled = bool(Prefs.get_value("ssil", true))
		"vignette":
			if vignette:
				vignette.visible = bool(Prefs.get_value("vignette", true))
			env.adjustment_enabled = true
		"grass_dense":
			if world:
				world.remake_grass()
		"decor":
			if world:
				world._make_decor()
		"flora_less":
			if world:
				world._make_decor()
				world.remake_grass()
		"grass":
			if world.grass:
				world.grass.visible = bool(Prefs.get_value("grass", true))
		"draw_distance":
			var d := float(Prefs.get_value("draw_distance", 230))
			for k in world.renderers:
				for p in world.renderers[k].parts:
					p.mmi.visibility_range_end = d


func daylight() -> float:
	var h := sin((day_t - 0.25) * TAU)
	return smoothstep(-0.05, 0.3, h)


func _update_day(delta: float) -> void:
	var h0 := sin((day_t - 0.25) * TAU)
	var speed := 1.0 if h0 > 0.0 else 2.2
	day_t += delta / day_length * speed
	if day_t >= 1.0:
		day_t -= 1.0
		day_n += 1
	_apply_sky()


func _apply_sky() -> void:
	var h := sin((day_t - 0.25) * TAU)
	var dayk := smoothstep(-0.12, 0.25, h)
	var low := 1.0 - smoothstep(0.0, 0.45, h)
	var elev := clampf(h, 0.05, 1.0) * deg_to_rad(54.0) + 0.12
	sun.rotation = Vector3(-elev, day_t * TAU * 0.5 + 0.9, 0)
	sun.light_energy = smoothstep(-0.02, 0.18, h) * 1.2
	var lk: Dictionary = World.look()
	sun.light_color = DB.color(lk.get("sun_color", "#fff1d6")).lerp(Color(1.0, 0.62, 0.32), low * 0.85)
	sun.visible = sun.light_energy > 0.01
	moon.light_energy = (1.0 - dayk) * 0.32
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.08).lerp(DB.color(lk.get("sky_top", "#3f7fd9")), dayk)
	sky_mat.sky_horizon_color = Color(0.06, 0.08, 0.15).lerp(DB.color(lk.get("sky_horizon", "#b8d8f0")).lerp(Color(0.95, 0.62, 0.42), low * 0.7), dayk)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = sky_mat.sky_horizon_color * 0.4
	env.ambient_light_energy = lerpf(0.35, float(lk.get("ambient", 0.75)), dayk)
	env.fog_light_color = sky_mat.sky_horizon_color
	env.fog_light_energy = lerpf(0.4, 1.0, dayk)
	player.flashlight.light_energy = (1.0 - dayk) * 5.0
	if events and events.storm > 0.01:
		var s: float = events.storm
		var grey := Color(0.32, 0.34, 0.38)
		sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(grey * 0.6, s * 0.8)
		sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(grey, s * 0.8)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		sun.light_energy *= 1.0 - s * 0.6
		env.fog_light_color = sky_mat.sky_horizon_color
	if events and events.tint.a > 0.01:
		# солнечный выброс и другие события красят небо и свет
		var ta: float = events.tint.a
		var tc := Color(events.tint.r, events.tint.g, events.tint.b)
		sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(tc * 0.8, ta * 0.7)
		sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(tc, ta * 0.8)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		sun.light_color = sun.light_color.lerp(tc, ta * 0.6)
		sun.light_energy *= 1.0 + events.heat * 0.7
		env.fog_light_color = sky_mat.sky_horizon_color
	if events and events.dark > 0.01:
		# затмение: днём темно, как ночью
		var dk: float = events.dark
		sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color(0.03, 0.03, 0.06), dk * 0.9)
		sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color(0.25, 0.12, 0.08), dk * 0.85)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		sun.light_energy *= 1.0 - dk * 0.9
		env.ambient_light_energy *= 1.0 - dk * 0.5
		env.fog_light_color = sky_mat.sky_horizon_color
		player.flashlight.light_energy = maxf(player.flashlight.light_energy, dk * 5.0)
	if events:
		env.fog_density = float(lk.get("fog", 0.0007)) * (1.0 + events.storm * 5.0 + events.heat * 1.5 + events.fog * 30.0)
		if events.rain > 0.01:
			sun.light_energy *= 1.0 - events.rain * 0.35


func is_night() -> bool:
	return sin((day_t - 0.25) * TAU) < -0.05 or (events != null and events.dark > 0.6)


## Автонастройка: если FPS долго ниже порога, по шагу снижаем самое тяжёлое (сначала незаметное).
var _aq_t := 0.0
var _aq_low := 0.0
var _aq_warm := 8.0
const AQ_STEPS := [["clouds_lq", true, "тучи попроще"], ["flora_less", true, "меньше растительности"], ["lod_px", 4, "дальние модели проще"], ["ssao", false, "затенение углов"], ["render_scale", 0.85, "масштаб картинки 85%"], ["msaa", "off", "сглаживание MSAA"],
	["live_anim_max", 8, "живая анимация 8 монстров"], ["shadows", "low", "тени попроще"], ["glow", false, "свечение"],
	["detail_dist", 50, "мелкие детали ближе"], ["render_scale", 0.7, "масштаб картинки 70%"], ["grass", false, "трава"],
	["live_anim_max", 4, "живая анимация 4 монстров"], ["lod_px", 8, "дальние модели ещё проще"], ["shadows", "off", "тени"], ["decor", false, "цветы"]]
const SHADOW_ORDER := ["off", "low", "high", "ultra"]

func _auto_quality(delta: float) -> void:
	if not bool(Prefs.get_value("auto_quality", true)) or photo_mode or is_frozen() or DisplayServer.get_name() == "headless":
		return
	if _aq_warm > 0.0:
		_aq_warm -= delta
		return
	_aq_t += delta
	if _aq_t < 1.0:
		return
	_aq_t = 0.0
	var fps := Engine.get_frames_per_second()
	var target := float(Prefs.get_value("auto_fps", 45))
	if fps < target - 3:
		_aq_low += 1.0
	else:
		_aq_low = maxf(0.0, _aq_low - 2.0)
	if _aq_low < 6.0:
		return
	_aq_low = 0.0
	_aq_warm = 4.0
	for st in AQ_STEPS:
		var cur = Prefs.get_value(st[0])
		var worse := false
		if st[1] is bool:
			worse = (cur == true) != bool(st[1])   # 1.1.15: настройки ещё нет (null) — bool(null) падал
		elif str(st[0]) == "shadows":
			worse = SHADOW_ORDER.find(str(cur)) > SHADOW_ORDER.find(str(st[1]))
		elif str(st[0]) == "lod_px":
			worse = float(cur) < float(st[1]) - 0.001
		elif st[1] is String:
			worse = str(cur) != str(st[1])
		else:
			worse = float(cur) > float(st[1]) + 0.001
		if worse:
			Prefs.set_value(st[0], st[1])
			notify("Автонастройка графики: %s (FPS был %d). Отключить — «Настройки → Графика»." % [st[2], fps], Color(0.8, 0.9, 1.0))
			return


## Дальность видимости (густой туман сокращает).
func view_range() -> float:
	return float(DB.data.settings.get("view_range", 60)) * (1.0 - (events.fog * 0.55 if events else 0.0))


func clock_text() -> String:
	var mins := int(day_t * 24.0 * 60.0)
	var t := "День %d · %02d:%02d · %s" % [day_n, mins / 60, mins % 60, "ночь, монстры злее" if is_night() else "день"]
	var se := season()
	if not se.is_empty():
		t = "%s · %s" % [str(se.get("name", "")), t]
	if events:
		var et: String = events.status_text()
		if et != "":
			t += " · " + et
	if flags.get("show_fps", false):
		t += " · %d FPS" % Engine.get_frames_per_second()
	return t


# ---------------------------------------------------------------- главный цикл

## Замер времени по частям кадра (для поиска тормозов: --test=perf, F3 — счётчик).
var prof_on := false
var prof := {}
func _prof(name: String, t0: int) -> void:
	prof[name] = int(prof.get(name, 0)) + Time.get_ticks_usec() - t0


func _process(delta: float) -> void:
	if warming:
		return
	_test_tick()
	_auto_quality(delta)
	if pview != null:
		pview.update(delta)
	if physics != null:
		physics.update(delta)
	if quantum != null and not is_frozen():
		quantum.update(delta)
	# 1.3: сплитскрин — камера, наведение и интерфейс у каждого места свои
	var sp_on: bool = split != null and split.active
	for si in (2 if sp_on else 1):
		if sp_on:
			split.use(si)
		var _t_4 := Time.get_ticks_usec() if prof_on else 0
		_update_camera(delta)
		if prof_on: _prof("_update_camera", _t_4)
		var _t_7 := Time.get_ticks_usec() if prof_on else 0
		_update_hover()
		if prof_on: _prof("_update_hover", _t_7)
		var _t_10 := Time.get_ticks_usec() if prof_on else 0
		_update_fov()
		if prof_on: _prof("_update_fov", _t_10)
		var _t_13 := Time.get_ticks_usec() if prof_on else 0
		hud.update(delta)
		if prof_on: _prof("hud.update", _t_13)
	if sp_on:
		split.use(0)
	var _t_16 := Time.get_ticks_usec() if prof_on else 0
	photo.update(delta)
	if prof_on: _prof("photo.update", _t_16)
	var _t_19 := Time.get_ticks_usec() if prof_on else 0
	blueprints.update(Vector2i(floori(hover_point.x / C), floori(hover_point.z / C)))
	if prof_on: _prof("blueprints.update", _t_19)
	var _t_22 := Time.get_ticks_usec() if prof_on else 0
	world.update_visuals(player.position)
	if sp_on:
		world.update_split_view(split.p2().position)
	if prof_on: _prof("world.update_visuals", _t_22)
	var _t_25 := Time.get_ticks_usec() if prof_on else 0
	mirror.update(delta, cam_focus, get_world_3d().scenario)
	if prof_on: _prof("mirror.update", _t_25)
	var _t_28 := Time.get_ticks_usec() if prof_on else 0
	sfx.update(delta, camera.global_transform.basis)
	if prof_on: _prof("sfx.update", _t_28)
	var frz: bool = is_frozen() or game_over
	# в сетевой игре и в сплитскрине мир не останавливается, пока открыто окно: другие игроки продолжают играть
	if frz and not Net.active() and not (sp_on and not paused and not game_over):
		return
	if not Net.is_client():
		var _t_36 := Time.get_ticks_usec() if prof_on else 0
		_update_day(delta)
		if prof_on: _prof("_update_day", _t_36)
	if island != null: island.tick(delta)
	play_time += delta
	var _t_40 := Time.get_ticks_usec() if prof_on else 0
	_autosave(delta)
	if prof_on: _prof("_autosave", _t_40)
	var _t_43 := Time.get_ticks_usec() if prof_on else 0
	_check_victory(delta)
	if prof_on: _prof("_check_victory", _t_43)
	var _t_46 := Time.get_ticks_usec() if prof_on else 0
	world.update_nests(Time.get_ticks_msec() * 0.001)
	if prof_on: _prof("world.update_nests", _t_46)
	var _t_49 := Time.get_ticks_usec() if prof_on else 0
	world.update_respawns(delta)
	if prof_on: _prof("world.update_respawns", _t_49)
	for si in (2 if sp_on else 1):
		if sp_on:
			split.use(si)
			frz = is_frozen() or game_over
		if not frz and not Net.dedicated:   # 1.0.9: у выделенного сервера герой-заглушка не живёт
			var _t_53 := Time.get_ticks_usec() if prof_on else 0
			player.update(delta, hover_point, cam_yaw)
			if prof_on: _prof("player.update", _t_53)
			var _t_56 := Time.get_ticks_usec() if prof_on else 0
			_update_target(delta)
			if prof_on: _prof("_update_target", _t_56)
		if sp_on:
			# 1.0.8: в режиме проводов ЛКМ мимо зданий — обычный удар
			if not frz and lmb and build_type == "" and not demolish and (not wiring or (wire_from == null and wire_pick() == null)) and not zone_pick and not hud.any_window_open():
				_primary_action()
			_update_survival(delta)
	if sp_on:
		split.use(0)
		frz = is_frozen() or game_over
	if not flags.get("no_waves", false):
		var _t_60 := Time.get_ticks_usec() if prof_on else 0
		enemies.update(delta)
		if prof_on: _prof("enemies.update", _t_60)
	else:
		var wt := enemies.wave_timer
		var _t_65 := Time.get_ticks_usec() if prof_on else 0
		enemies.update(delta)
		if prof_on: _prof("enemies.update", _t_65)
		enemies.wave_timer = wt
	var _t_69 := Time.get_ticks_usec() if prof_on else 0
	drops.update(delta)
	if prof_on: _prof("drops.update", _t_69)
	# 1.0.8: в режиме проводов ЛКМ мимо зданий — обычный удар (раньше герой «не мог бить», если забыл выйти из режима)
	if not sp_on and not frz and lmb and build_type == "" and not demolish and (not wiring or (wire_from == null and wire_pick() == null)) and not zone_pick and not hud.any_window_open():
		var _t_73 := Time.get_ticks_usec() if prof_on else 0
		_primary_action()
		if prof_on: _prof("_primary_action", _t_73)
	var _t_76 := Time.get_ticks_usec() if prof_on else 0
	_update_repair(delta)
	if prof_on: _prof("_update_repair", _t_76)
	var _t_79 := Time.get_ticks_usec() if prof_on else 0
	_update_craft(delta)
	if prof_on: _prof("_update_craft", _t_79)
	var _t_82 := Time.get_ticks_usec() if prof_on else 0
	_update_graves(delta)
	if prof_on: _prof("_update_graves", _t_82)
	var _t_85 := Time.get_ticks_usec() if prof_on else 0
	if not sp_on:
		_update_survival(delta)
	if prof_on: _prof("_update_survival", _t_85)
	var _t_88 := Time.get_ticks_usec() if prof_on else 0
	_update_effects(delta)
	if prof_on: _prof("_update_effects", _t_88)
	if not Net.is_client():
		var _t_92 := Time.get_ticks_usec() if prof_on else 0
		_update_market(delta)
		if prof_on: _prof("_update_market", _t_92)
	var _t_95 := Time.get_ticks_usec() if prof_on else 0
	_check_quests()
	if prof_on: _prof("_check_quests", _t_95)
	var _t_98 := Time.get_ticks_usec() if prof_on else 0
	tech.update(delta)
	if prof_on: _prof("tech.update", _t_98)
	var _t_101 := Time.get_ticks_usec() if prof_on else 0
	events.update(delta)
	if prof_on: _prof("events.update", _t_101)
	var _t_104 := Time.get_ticks_usec() if prof_on else 0
	sieges.update(delta)
	if prof_on: _prof("sieges.update", _t_104)
	var _t_107 := Time.get_ticks_usec() if prof_on else 0
	fog.update(delta)
	zone.update(delta)
	scanner.update(delta)
	defense.update(delta)
	if prof_on: _prof("fog.update", _t_107)
	var _t_110 := Time.get_ticks_usec() if prof_on else 0
	dungeons.update(delta)
	if prof_on: _prof("dungeons.update", _t_110)
	var _t_113 := Time.get_ticks_usec() if prof_on else 0
	climate.update(delta)
	if strategy:
		strat.update(delta)
	hearts.update(delta)
	if prof_on: _prof("climate.update", _t_113); _t_113 = Time.get_ticks_usec()
	hazards.update(delta)
	if prof_on: _prof("hazards.update", _t_113); _t_113 = Time.get_ticks_usec()
	star.update(delta)   # у гостей — только полёт НЛО (обмен считает хозяин)
	if prof_on: _prof("star.update", _t_113)
	var _t_116 := Time.get_ticks_usec() if prof_on else 0
	vehicles.update(delta)
	if prof_on: _prof("vehicles.update", _t_116)
	var _t_119 := Time.get_ticks_usec() if prof_on else 0
	carriers.update(delta)
	progress17.update(delta)
	if prof_on: _prof("carriers.update", _t_119)
	if not Net.is_client():
		drones.update(delta)
	builders.update(delta)
	if not Net._self().dedicated:
		var _t_123 := Time.get_ticks_usec() if prof_on else 0
		orders.update(delta)   # 1.1.15: заказы у каждого игрока свои (у гостя тоже получают предложения)
		if prof_on: _prof("orders.update", _t_123)


func _update_fov() -> void:
	var on: bool = bool(Prefs.get_value("fov_enabled", DB.data.settings.get("fov_enabled", true))) and player.alive and not photo_mode and not strategy and not (split != null and split.active)
	if split != null and split.active and split.cur != 0:
		return
	var ang := float(Prefs.get_value("fov_angle", DB.data.settings.get("fov_angle", 120)))
	var to := World.delta(player.position, hover_point)
	to.y = 0
	var dir := to.normalized() if to.length() > 0.5 else Vector3(cos(player.hips.rotation.y), 0, -sin(player.hips.rotation.y))
	RenderingServer.global_shader_parameter_set("view_pos", player.position)
	RenderingServer.global_shader_parameter_set("view_dir", dir)
	RenderingServer.global_shader_parameter_set("view_cos", cos(deg_to_rad(min(ang, 359.0)) * 0.5))
	RenderingServer.global_shader_parameter_set("view_range", view_range())
	RenderingServer.global_shader_parameter_set("view_near", float(DB.data.settings.get("near_radius", 7)))
	RenderingServer.global_shader_parameter_set("view_on", 1.0 if on and ang < 359.0 else 0.0)


func cycle_camera() -> void:
	if Net.active() or photo_mode or not player.alive:
		return
	if strategy:
		strategy_zoom = cam_dist_target
		strategy = false
		first_person = false
		player.visible = true
		var anchor = explorer_anchor.get("pos", [])
		if anchor.size() == 3:
			player.position = Vector3(anchor[0], anchor[1], anchor[2])
		else:
			player.position = factory.hq.center() + Vector3(6, 0, 6)
			player.position.y = factory.support_at(player.position)
		for key in ["hp", "food", "water"]:
			if explorer_anchor.has(key):
				player.set(key, explorer_anchor[key])
		cam_focus = player.position
		cam_dist_target = explorer_zoom
		cam_dist = explorer_zoom
		edge_off = Vector3.ZERO
		_cam_lead = Vector3.ZERO
	elif not first_person:
		explorer_zoom = clampf(cam_dist_target, 6.0, 24.0)
		first_person = true
		player.visible = false
		look_pitch = -0.18
	else:
		explorer_anchor = {"pos": [player.position.x,player.position.y,player.position.z], "hp": player.hp, "food": player.food, "water": player.water}
		strategy = true
		first_person = false
		if strat.layer == null:
			strat.make_overlay()
		player.visible = false
		cam_dist_target = strategy_zoom
		cam_dist = strategy_zoom
	player.move_dir = Vector3.ZERO
	Inventory.no_personal = strategy
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if first_person else Input.MOUSE_MODE_VISIBLE
	notify("Стратегия" if strategy else ("От первого лица" if first_person else "От третьего лица"), Color.LIGHT_BLUE)


func _update_camera(delta: float) -> void:
	if photo_mode and photo.free_cam and (split == null or not split.running() or split.cur == _photo_seat):
		photo.update_cam(camera, delta)
		return
	if first_person:
		var capture: bool = not hud.any_window_open() and not typing()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
		camera.position = player.position + Vector3.UP * 1.62
		camera.rotation = Vector3(look_pitch, cam_yaw_target, 0)
		cam_yaw = cam_yaw_target
		return
	if not typing() and not console.visible_now():
		var sp := 1.8 * float(Prefs.get_value("cam_speed", 1.0))
		var ctl = player.ctl
		if (ctl.cam_l if ctl != null else Input.is_action_pressed("cam_left")):
			cam_yaw_target += delta * sp
		if (ctl.cam_r if ctl != null else Input.is_action_pressed("cam_right")):
			cam_yaw_target -= delta * sp
	if not typing() and not console.visible_now() and not hud.any_window_open() and player.ctl == null:
		_zoom_keys(delta)
	cam_yaw = lerpf(cam_yaw, cam_yaw_target, min(1.0, delta * 8.0))
	cam_dist = lerpf(cam_dist, cam_dist_target, min(1.0, delta * 8.0))
	_update_dof()
	# в зацикленном мире камера идёт за героем через край без рывка
	var look := Vector3.ZERO
	if Prefs.get_value("edge_scroll", false) and not hud.any_window_open():
		var vs: Vector2 = (hud.get_viewport() if split != null and split.active else get_viewport()).get_visible_rect().size
		var mp: Vector2 = _mouse()
		var e := Vector2(clampf((mp.x - vs.x * 0.5) / (vs.x * 0.5), -1, 1), clampf((mp.y - vs.y * 0.5) / (vs.y * 0.5), -1, 1))
		e = Vector2(signf(e.x) * maxf(0.0, absf(e.x) - 0.85), signf(e.y) * maxf(0.0, absf(e.y) - 0.85)) / 0.15
		edge_off += (Vector3(e.x, 0, e.y).rotated(Vector3.UP, cam_yaw) * cam_dist * 0.04 * 60.0 * delta)
		edge_off = edge_off.limit_length(cam_dist * 1.2)
	else:
		edge_off = edge_off.lerp(Vector3.ZERO, min(1.0, delta * 3.0))
	look = edge_off
	# 1.3: камера чуть забегает вперёд по ходу героя — видно, куда бежишь
	_cam_lead = _cam_lead.lerp(Vector3(player.move_dir.x, 0, player.move_dir.z) * float(DB.setting("cam_lead", 0.09)), minf(1.0, delta * 2.5))
	look += _cam_lead
	cam_focus += World.delta(cam_focus, player.position + look) * min(1.0, delta * 6.0)
	cam_focus.y = lerpf(cam_focus.y, player.cam_y(), min(1.0, delta * 6.0))
	if world.wrap:
		var before := cam_focus
		cam_focus = World.wrap_pos(cam_focus)
		if before != cam_focus:
			hover_point += cam_focus - before
	var pitch := deg_to_rad(88.0) if top_view else deg_to_rad(cam_pitch_override) if cam_pitch_override > 0.0 else deg_to_rad(lerpf(48.0, 62.0, inverse_lerp(14.0, 90.0, cam_dist)))
	# 1.3: вблизи («+») камера опускается и смотрит герою в грудь — его видно целиком и подробно
	var near_k := 0.0 if top_view or cam_pitch_override > 0.0 else clampf(inverse_lerp(12.0, CAM_CLOSE, cam_dist), 0.0, 1.0)
	pitch = lerpf(pitch, deg_to_rad(12.0), near_k)
	var off := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * cam_dist
	camera.position = cam_focus + off
	camera.look_at(cam_focus + Vector3(0, lerpf(1.0, 1.45, near_k), 0), Vector3.UP)
	if trauma > 0.0:
		# 1.3: удары, взрывы, приземление — короткая резкая тряска (сила в квадрате: слабые почти не трясут)
		var tk: float = trauma * trauma * float(Prefs.get_value("cam_shake", 1.0))
		var tt := Time.get_ticks_msec() * 0.001
		camera.position += Vector3(sin(tt * 53.0), sin(tt * 47.0 + 1.0), cos(tt * 59.0)) * tk * 0.35
		camera.rotate_object_local(Vector3.FORWARD, sin(tt * 43.0) * tk * 0.025)
		trauma = maxf(0.0, trauma - delta * 2.2)
	if events and events.shake > 0.01 and float(Prefs.get_value("cam_shake", 1.0)) > 0.0:
		# землетрясение и черви трясут камеру (в настройках можно ослабить)
		var sk: float = events.shake * float(Prefs.get_value("cam_shake", 1.0))
		var t := Time.get_ticks_msec() * 0.001
		camera.position += Vector3(sin(t * 37.0) + sin(t * 23.0) * 0.5, sin(t * 41.0) * 0.6, cos(t * 31.0) + sin(t * 19.0) * 0.5) * sk * 0.18
		camera.rotate_object_local(Vector3.FORWARD, sin(t * 29.0) * sk * 0.006)


## 1.3: «+» и «−» (основные и на цифровом блоке) — приблизить камеру к герою и отдалить обратно.
## Отдалить можно только до высоты, с которой начали приближать (дальше — колесом, как раньше).
## Основные «−»/«=» заняты быстрыми слотами 11–12, если слотов больше десяти.
func _zoom_keys(delta: float) -> void:
	var main_keys := Player.hot_n() <= 10
	var zin := Input.is_physical_key_pressed(KEY_KP_ADD) or (main_keys and Input.is_physical_key_pressed(KEY_EQUAL))
	var zout := Input.is_physical_key_pressed(KEY_KP_SUBTRACT) or (main_keys and Input.is_physical_key_pressed(KEY_MINUS))
	if zin == zout:
		return
	if zin:
		if zoom_home < 0.0:
			zoom_home = cam_dist_target
		cam_dist_target = maxf(CAM_CLOSE, cam_dist_target * (1.0 - 1.4 * delta))
	else:
		var top := zoom_home if zoom_home > 0.0 else cam_dist_target
		cam_dist_target = minf(top, cam_dist_target * (1.0 + 1.4 * delta))
		if zoom_home > 0.0 and cam_dist_target >= zoom_home - 0.01:
			zoom_home = -1.0


func _update_hover() -> void:
	var mp: Vector2 = get_viewport().get_visible_rect().size * 0.5 if first_person else _mouse()
	var o := camera.project_ray_origin(mp)
	var n := camera.project_ray_normal(mp)
	if first_person:
		hover_point = o + n * 6.0
	if absf(n.y) > 0.0001:
		var t := -o.y / n.y
		if t > 0.0:
			# луч до земли с холмами и фундаментами: несколько уточнений по высоте
			var hp := o + n * t
			for i in 6:
				var h: float = .20 if island != null and world.water_at(World.world_to_cell(hp)) else factory.support_at(hp)
				t = (h - o.y) / n.y
				if t <= 0.0:
					break
				hp = o + n * t
			hover_point = hp
	hover_cell = World.world_to_cell(hover_point)
	var snap = _miner_snap()
	if snap != null:
		hover_cell = snap
	var gmat: ShaderMaterial = world.ground_mat_of(split.cur if split != null and split.active else 0)
	if gmat != null:
		gmat.set_shader_parameter("cursor", hover_point)
		gmat.set_shader_parameter("grid_on", 1.0 if (build_type != "" or demolish) else 0.0)
	_update_wire_preview()
	_update_wire_hl(get_process_delta_time())
	if ghost:
		var s := int(DB.building(build_type).get("size", 1))
		var o2 := (s - 1) * C * 0.5
		var raw := Vector2i(floori(hover_point.x / C), floori(hover_point.z / C))
		if snap != null:
			raw += (snap as Vector2i) - World.world_to_cell(hover_point)   # 1.3: бур прилип к залежи
		var gb: Array = factory.base_for(build_type, World.wc(raw))
		var gpos := Vector3((raw.x + 0.5) * C + o2, float(gb[0]) + 0.02, (raw.y + 0.5) * C + o2)
		# 1.3: призрак не прыгает по сетке, а быстро доезжает; новая клетка — тихий щелчок
		if raw != _ghost_cell:
			if _ghost_cell != Vector2i(-99999, -99999):
				sfx.play_ui("tick")
			_ghost_cell = raw
		ghost.position = gpos if ghost.position.distance_to(gpos) > C * 3.0 else ghost.position.lerp(gpos, minf(1.0, get_process_delta_time() * 22.0))
		if DB.building(build_type).get("behavior", "") == "foundation":
			ghost.scale.y = maxf(0.05, (float(gb[2]) - float(gb[0])) / maxf(0.05, float(DB.bparam(build_type, "height", 1.0))))
		else:
			ghost.scale.y = 1.0
		ghost.rotation.y = lerp_angle(ghost.rotation.y, -build_dir * PI * 0.5, minf(1.0, get_process_delta_time() * 18.0))
		if int(ghost.get_meta("pdir", -1)) != build_dir:
			_ghost_ports()   # 1.1.9: порты призрака — для текущего поворота
		var ok: bool = (factory.can_place(build_type, hover_cell) == "" or factory.upgrade_target(build_type, hover_cell) != null or factory.rails_ok(build_type, hover_cell)) and (factory.can_afford(build_type) or flags.get("free_build", false))
		var gm: StandardMaterial3D = ghost.get_meta("mat")
		gm.albedo_color = Color(0.3, 1.0, 0.5, 0.45) if ok else Color(1.0, 0.25, 0.2, 0.45)


# ---------------------------------------------------------------- ввод

func _unhandled_input(ev: InputEvent) -> void:
	if split != null and split.active:
		return   # сплитскрин: ввод приходит через привратников половин экрана (split.gd, Gate)
	_unhandled_impl(ev)


func _unhandled_impl(ev: InputEvent) -> void:
	if console.visible_now():
		return
	if photo_mode and (ev is InputEventMouseButton or ev is InputEventMouseMotion) and photo.mouse(ev):
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		var zs := float(Prefs.get_value("zoom_speed", 1.0))
		var wheel_bar: bool = (str(Prefs.get_value("wheel_mode", "hotbar")) == "hotbar") != mb.ctrl_pressed
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mb.pressed and wheel_bar:
			var n := Player.hot_n()
			hot_select(posmod(player.selected + (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1), n), true)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist_target = max(minf(12.0, cam_dist_target), cam_dist_target * (1.0 - 0.12 * zs))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_home = -1.0
			cam_dist_target = min(cam_max, cam_dist_target * (1.0 + 0.12 * zs))
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and drones.picking():
			drones.pick_click()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and drones.picking():
			drones.cancel_pick()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			lmb = true
			drag_last = Vector2i(-999, -999)
			drag_placed = null
			_click_world()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and blueprints.active():
			blueprints.cancel()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if zone_pick:
				cancel_build()
			elif wiring:
				var wb = wire_pick()
				if wire_from != null:
					wire_from = null
				elif wb != null and factory.wire_count(wb) > 0:
					cmd("unwire", {"b": wb})
				else:
					cancel_build()
			elif field_selection >= 0 or build_type != "" or demolish or (pview != null and pview.on):
				cancel_build()
			else:
				rmb = true
	elif ev is InputEventMouseMotion:
		if lmb and (demolish or (build_type in ["wall", "wall_wood", "fence", "floor"] or _is_belt(build_type))):
			_drag_world()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = (ev as InputEventKey).physical_keycode
		var hk := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9, KEY_MINUS: 10, KEY_EQUAL: 11}
		if photo_mode and k != KEY_ESCAPE and photo.key(k, ev.shift_pressed):
			return
		if hk.has(k) and hk[k] < Player.hot_n() and (hk[k] < 10 or Player.hot_n() > 10):
			hot_select(hk[k])
			return
		if k == KEY_ESCAPE:
			if photo_mode:
				_action("photo")
				return
			if blueprints.active():
				blueprints.cancel()
				return
			if not hud.close_all():
				if field_selection >= 0 or build_type != "" or demolish or wiring or zone_pick or (pview != null and pview.on):
					cancel_build()
				else:
					hud.open("pause")
			return
		var kn := OS.get_keycode_string(k)
		var cw := hud.custom_window_for_key(kn)
		if cw != "":
			hud.toggle(cw)
			return
		for act in ["build_menu", "inventory", "craft", "skills", "trade", "help", "pause", "interact", "rotate", "demolish", "wire", "editor", "map", "tech", "blueprint", "photo", "top_view", "flow_map", "constructor", "scan", "fun", "ping", "records"]:
			if ev.is_action_pressed(act):
				_action(act)
				return


func _action(act: String) -> void:
	match act:
		"build_menu": hud.toggle("build")
		"map":
			if bool(DB.setting("bigmap", true)):
				hud.toggle("map")
		"inventory": hud.toggle("inventory")
		"craft":
			hud.station = "hand"
			hud.station_b = null
			hud.toggle("craft")
		"skills": hud.toggle("skills")
		"tech": hud.toggle("tech")
		"records": hud.toggle("records")
		"scan":
			if scanner.on():
				hud.toggle("scan")
		"fun": coop.toggle_panel()
		"ping": coop.ping()
		"trade": hud.toggle("trade")
		"help": hud.toggle("help")
		"pause": paused = not paused
		"interact": _interact()
		"blueprint":
			if blueprints.mode == "paste":
				hud.toggle("blueprints")
			elif blueprints.mode == "select":
				hud.toggle("blueprints")
			else:
				blueprints.begin_select()
		"photo":
			photo_mode = not photo_mode
			hud.visible = not photo_mode
			_photo_seat = split.cur if split != null and split.running() else 0   # A-10 r6: чей фоторежим
			if photo_mode:
				hud.close_all()
				_cam_max0 = cam_max
				cam_max = maxf(cam_max, 200.0)
				photo.enter()
			else:
				photo.leave()
				if _cam_max0 > 0.0:   # A-6 r6: дальность камеры — как до фоторежима
					cam_max = _cam_max0
					cam_dist_target = minf(cam_dist_target, cam_max)
					_cam_max0 = -1.0
		"top_view":
			top_view = not top_view
		"flow_map":
			flow_map.toggle()
		"rotate":
			if blueprints.mode == "paste":
				blueprints.rotate()
				return
			if build_type == "" and factory.building_at(hover_cell) == null and str(DB.item(player.selected_item()).get("tool", "")) == "axe":
				toggle_stumps()
				return
			build_dir = (build_dir + 1) % 4
			if build_type == "":
				var b = factory.building_at(hover_cell)
				if b != null and b != factory.hq:   # 1.1.15: и большие здания (входы/выходы зависят от поворота)
					cmd("rotate", {"b": b})
		"demolish": ui_action("demolish")
		"wire": ui_action("wire")
		"constructor": hud.toggle("constructor")
		"editor":
			if DB.studio and ResourceLoader.exists("res://scenes/editor.tscn"):
				to_editor()


func _input(ev: InputEvent) -> void:
	if split != null and split.active:
		return
	_input_impl(ev)


func _input_impl(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and first_person and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw_target -= ev.relative.x * 0.0028
		look_pitch = clampf(look_pitch - ev.relative.y * 0.0028, -1.22, 1.22)
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F6 and not typing():
		cycle_camera()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F3 and not typing():
		Prefs.set_value("show_fps", not bool(Prefs.get_value("show_fps", false)))
	if ev is InputEventMouseButton and not ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			lmb = false
			if blueprints.mode == "select":
				blueprints.release(hover_cell)
			if wiring and wire_from != null:
				_wire_release()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			rmb = false


## 1.1.15: команда консоли camera — фоторежим сразу со свободной камерой (WASD, Пробел/Ctrl, ПКМ, колесо, F12);
## ещё раз — обратно к герою.
## 1.1.18: залежи, которые теперь открывают узлы (уголь — «Уголь и сталь»…). В мирах до 1.1.18 они остаются открытыми,
## иначе бур на угле у игрока встал бы до изучения узла.
var dep118 := true

func _dep118(on: bool) -> void:
	dep118 = on
	var add = DB.setting("dep118", {})
	if not add is Dictionary:
		return
	for tid in add:
		if not DB.data.get("tech", {}).has(tid):
			continue
		var u: Dictionary = DB.data.tech[tid].get("unlocks", {})
		var dl: Array = u.get("deposits", [])
		for it in add[tid]:
			if on and not it in dl:
				dl.append(it)
			elif not on:
				dl.erase(it)
		u["deposits"] = dl
		DB.data.tech[tid]["unlocks"] = u


func _legacy_115() -> void:
	_dep118(false)   # 1.1.18: прежние залежи у штаба и открытые с начала
	DB.data.world.erase("start_one")
	# 1.1.19: прежние закрытые залежи, их число, зона 10×10 и канал штаба «клетки × 2»
	DB.data.world.erase("start_base")
	DB.data.world.erase("start_ring")
	var dold = DB.setting("dep119_old", {})
	if dold is Dictionary:
		for tid in dold:
			if DB.data.tech.has(tid):
				var u0: Dictionary = DB.data.tech[tid].get("unlocks", {})
				u0["deposits"] = (dold[tid] as Array).duplicate()
				DB.data.tech[tid]["unlocks"] = u0
	var pold = DB.setting("patches119_old", {})
	if pold is Dictionary:
		for d in DB.data.world.get("deposits", []):
			if pold.has(d.get("item", "")):
				d["patches"] = pold[d.item]
	if DB.data.settings.get("zone") is Dictionary:
		DB.data.settings.zone["start_blocks"] = 10
	DB.data.settings["hq_link115"] = DB.setting("hq_link115", {}).duplicate()
	DB.data.settings.hq_link115["power_min"] = 2.0
	DB.data.settings.hq_link115["power_per_cell"] = 2.0
	var old_n = DB.setting("near118_old", {})
	if old_n is Dictionary:
		for d in DB.data.world.get("deposits", []):
			if old_n.has(d.get("item", "")):
				d["near_start"] = old_n[d.item]
	DB.data.settings["defense115"] = {"local_ammo": false}
	DB.data.settings["meteor115"] = {"enabled": false}
	DB.data.settings["heart_limit"] = {"enabled": false}   # и без предела зданий («Сердца»)
	DB.data.settings["repair111"] = {"cost_k": 0.5, "time": 15.0}   # 1.1.17: старые проверки — ремонт 15 с
	DB.data.settings["auto_repair114"] = {"pct_per_min": [2, 3, 4, 5, 6]}   # и авторемонт 2–6 %/мин
	var zc = DB.data.settings.get("zone", {})
	if zc is Dictionary:
		zc = zc.duplicate()
		zc["expand_cooldown"] = 0.0
		DB.data.settings["zone"] = zc
	for bid in DB.data.buildings:
		var pr: Dictionary = DB.data.buildings[bid].get("params", {})
		if pr.has("power_old114"):
			pr["power"] = pr["power_old114"]


func free_camera() -> void:
	if photo_mode:
		_action("photo")
		return
	_action("photo")
	photo.free_cam = true
	photo.enter_free()
	photo._update_tip()
	notify("Свободная камера: WASD — лететь, Пробел/Ctrl — вверх/вниз, ПКМ — повернуть, F12 — снимок, F9 или camera — выйти", Color(0.7, 0.9, 1.0))


func ui_action(what: String) -> void:
	match what:
		"demolish":
			var on := not demolish
			cancel_build()
			demolish = on
		"zone_pick":
			var onz := not zone_pick
			cancel_build()
			zone_pick = onz and (island != null or zone.on())
		"wire":
			if not factory.wired():
				# 21: без проводов клавиша показывает карту энергии
				var onp: bool = not pview.on
				cancel_build()
				pview.on = onp
				return
			var on := not wiring
			cancel_build()
			wiring = on
		"skills", "trade", "help", "inventory", "craft", "settings", "build":
			hud.toggle(what)
		_:
			if hud.windows.has(what):
				hud.toggle(what)
			else:
				console.run(what)


## Выбрать ячейку панели быстрого доступа: предмет берётся в руки, закреплённое здание — сразу в стройку.
func hot_select(i: int, by_wheel := false) -> void:
	player.selected = i
	hud.inv_pick = -1
	var bt := str(player.hot_builds.get(i, ""))
	if bt != "" and not DB.building(bt).is_empty():
		if build_type != bt:
			select_build(bt)
	elif build_type != "" and (by_wheel or player.hot_items.has(i)):
		cancel_build()


func select_build(t: String) -> void:
	var same := build_type == t
	cancel_build()
	if same or DB.building(t).is_empty():
		return
	if Tech.building_locked(t) and not flags.get("free_build", false):
		notify("Ещё не открыто: «%s» в дереве открытий (J)" % tech.opener("b", t), Color(1, 0.8, 0.5))
		return
	var miss := DB.scan_missing(DB.building(t).get("cost", {}))
	if not miss.is_empty() and not flags.get("free_build", false):
		# 1.0.8: открыто, но в цене неизученное сырьё — сказать что именно и открыть сканер
		notify("«%s»: сначала изучите в сканере — %s" % [DB.building(t).get("name", t), ", ".join(miss.map(func(k): return DB.item_name(k)))], Color(1, 0.8, 0.5))
		hud.open("scan")
		return
	build_type = t
	ghost = ModelLib.make_ghost(DB.building(t).get("model", t))
	_ghost_inputs(t)
	add_child(ghost)


func cancel_build() -> void:
	field_selection = -1
	build_type = ""
	demolish = false
	wiring = false
	if pview != null:
		pview.on = false
	wire_from = null
	if zone_pick:
		zone_pick = false
		zone.show_pick(null)
	if ghost:
		ghost.queue_free()
		ghost = null


## «Бревно ×3, Камень ×2» — чего не хватает для цены. have(id) -> сколько есть.
func missing_text(cost: Dictionary, have: Callable) -> String:
	var parts := []
	for k in cost:
		var miss := int(cost[k]) - int(have.call(k))
		if miss > 0:
			parts.append("%s ×%d" % [DB.item_name(k), miss])
	return ", ".join(parts)


## 1.0.8: текущий режим для крупной надписи и цветных краёв экрана (пусто — обычная игра).
func mode_info() -> Dictionary:
	var c: Dictionary = Hud.mode_cfg()
	var cols: Dictionary = c.get("colors", {}) if c.get("colors", {}) is Dictionary else {}
	var mk := func(id: String, title: String, hint: String, def_col: String, edge: float) -> Dictionary:
		return {"id": id, "title": title, "hint": hint, "color": DB.color(cols.get(id, def_col)), "edge": float(c.get("edge_" + id, edge))}
	if field_selection >= 0:
		return mk.call("field", DB.item_name(world.deposits[field_selection].item), "ЛКМ — орбитальный заказ · ПКМ — отмена", "#74dadd", 0.25)
	if zone_pick and island != null:
		return mk.call("zone","РАСШИРЕНИЕ ОСТРОВА","ЛКМ по воде у берега · ПКМ — выйти","#7adbc8",.3)
	if zone_pick:
		return mk.call("zone", "ВЫБОР УЧАСТКА", "Наведите рамку на тучи у края открытой земли · ПКМ — выйти", "#b38cff", 0.45)
	if pview != null and pview.on:
		return mk.call("wire", DB.tx("pv_title", "РЕЖИМ ЭНЕРГИИ"), DB.tx("pv_hint", "Круги — покрытие станций · зелёные — работают, оранжевые — станции не хватило мощности, красные — станции рядом нет · %s или ПКМ — выйти") % str(Prefs.get_value("key_wire", "V")), "#3fa4ff", 0.45)
	if wiring:
		return mk.call("wire", "РЕЖИМ ПРОВОДОВ", "ЛКМ по зданию — провод, мимо зданий — удар · %s или ПКМ — выйти" % str(Prefs.get_value("key_wire", "V")), "#3fa4ff", 0.55)
	if demolish:
		return mk.call("demolish", "РЕЖИМ РАЗБОРА", "ЛКМ — разобрать здание, ресурсы вернутся · %s или ПКМ — выйти" % str(Prefs.get_value("key_demolish", "X")), "#ff5a45", 0.55)
	if drones != null and drones.picking():
		return mk.call("route", "МАРШРУТ ДРОНА", "Щёлкните по зданию для точки маршрута · ПКМ — готово", "#3fe0c8", 0.4)
	if build_type != "":
		return mk.call("build", "СТРОЙКА: " + str(DB.building(build_type).get("name", build_type)).to_upper(), "ЛКМ — поставить · R — повернуть · ПКМ — отмена", "#ffc23f", 0.3)
	return {}


func mode_text() -> String:
	if field_selection >= 0:
		return "Месторождение · %d кредитов · %s" % [world.order_price, world.order_issue(field_selection, hover_cell)]
	if zone_pick and island != null:
		var n: int = island.ring(hover_cell)
		var parts := PackedStringArray()
		for k in island.cost(n):
			parts.append("%s ×%d" % [DB.item_name(k),island.cost(n)[k]])
		return "Ряд %d · %s · %s" % [n,", ".join(parts),island.issue(hover_cell)]
	if zone_pick:
		var rc: Vector2i = zone.patch_at(hover_point)
		var why: String = zone.patch_can(rc)
		var ct: Dictionary = zone.patch_cost()
		return "ОТКРЫТЬ УЧАСТОК %d×%d: наведите рамку на тучи у края открытой земли и щёлкните · цена: %s%s · ПКМ — выйти" % [zone.patch_n(), zone.patch_n(),
			", ".join(ct.keys().map(func(k): return "%s ×%d" % [DB.item_name(k), ct[k]])), (" · " + why) if why != "" else ""]
	if wiring:
		var hb = wire_pick()
		var t := DB.tx("w_mode2", "ПРОВОДА: щёлкните по зданию (подсветится жёлтым), потом по второму (зелёное — можно) · ПКМ по зданию — снять провода · ПКМ — выйти")
		if hb != null and factory.is_electric(hb):
			t += " · %s: %s %d/%d" % [DB.building(hb.type).get("name", hb.type), DB.tx("w_conn", "разъёмы"), factory.wire_count(hb), factory.connectors(hb)]
		if wire_from != null and hb != null and hb != wire_from:
			var why: String = factory.wire_why(wire_from, hb)
			if why != "":
				t += " · " + why
			else:
				var wc: Dictionary = factory.wire_cost(wire_from, hb)
				if not wc.is_empty():
					t += " · %s: %s" % [DB.tx("w_cost", "цена"), ", ".join(wc.keys().map(func(k): return "%s ×%d" % [DB.item_name(k), wc[k]]))]
		return t
	if demolish:
		return "РАЗБОР: ЛКМ — разобрать здание (ресурсы вернутся) · ПКМ — выйти"
	if build_type != "":
		var why := factory.can_place(build_type, hover_cell)
		var upb = factory.upgrade_target(build_type, hover_cell) if why != "" else null
		if upb != null:
			why = DB.tx("upgrade_here2", "заменить «%s» на «%s» — содержимое и встроенные здания останутся") % [DB.building(upb.type).get("name", upb.type), DB.building(build_type).get("name", build_type)]
		elif why != "" and factory.rails_ok(build_type, hover_cell):
			why = DB.tx("rails_here", "поставить бортики на ленту")
		if why == "" and not factory.can_afford(build_type) and not flags.get("free_build", false):
			why = "Не хватает: " + missing_text(_scaled_cost(build_type), factory.available)
		var drag := " · тяните мышью для линии" if (build_type in ["wall", "wall_wood", "fence", "floor"] or _is_belt(build_type)) else ""
		return "%s: ЛКМ — поставить%s · R — повернуть · ПКМ — отмена %s" % [DB.building(build_type).get("name", build_type), drag, ("· " + why) if why != "" else ""]
	var it := DB.item(player.selected_item())
	var lmb_t := "бить"
	if it.get("weapon", "") == "gun":
		lmb_t = "стрелять"
	elif not target.is_empty() and target.kind in ["node", "deposit"]:
		lmb_t = "добывать"
	if island != null and player.selected_item() == "salvage_rod" and not strategy:
		return "ЛКМ — забросить / подтянуть · E у плиты — берег и дары · B — строить · Tab — рюкзак"
	return "ЛКМ — %s · ПКМ (держать) — чинить · E — открыть здание · B — строить · Tab — инвентарь · C — крафт" % lmb_t


## Автоцель: что ударит или куда выстрелит герой по ЛКМ. Курсор не обязан попадать точно:
## берётся ближайшее к курсору в пределах «Прилипание к цели», иначе ближайшее перед героем.
## Возвращает {} или {"kind": "node"/"enemy"/"nest", "pos", "cell"/"e"/"n", "r"}.
func find_target() -> Dictionary:
	if not player.alive:
		return {}
	if strategy:
		return _strategy_target()
	var it := DB.item(player.selected_item())
	var gun: bool = it.get("weapon", "") == "gun"
	var auto := bool(DB.setting("auto_aim", true))
	var snap := float(DB.setting("aim_snap", 2.5)) if auto else 0.9
	var reach := float(DB.setting("reach", 3.5)) + 1.2
	var mrange: float = (float(it.get("range", 2.4)) if it.get("weapon", "") == "melee" else 2.0) + 0.6
	var face := Vector3(cos(player.hips.rotation.y), 0, -sin(player.hips.rotation.y))
	var best := {}
	var best_s := INF
	var cands := []
	if not gun:
		var pc := World.world_to_cell(player.position)
		var rc := ceili((reach + C) / C)
		for dx in range(-rc, rc + 1):
			for dz in range(-rc, rc + 1):
				var c := World.wc(pc + Vector2i(dx, dz))
				if world.nodes.has(c) and zone.inside_cell(c):
					if keep_stumps() and is_stump(world.nodes[c].res):
						continue   # 1.7: топор в режиме «оставлять пни» — пни не трогаем, из них снова вырастут деревья
					var np := World.cell_to_world(c)
					if World.dist(player.position, np) <= reach + C * 0.5:
						cands.append({"kind": "node", "pos": np, "cell": c, "r": 0.9, "pri": 0.0})
				elif world.can_mine(c) and zone.inside_cell(c):
					var dp := World.cell_to_world(c)
					if World.dist(player.position, dp) <= reach + C * 0.5:
						cands.append({"kind": "deposit", "pos": dp, "cell": c, "r": 0.9, "pri": 0.3})
	for e in enemies.list:
		if not enemies.targetable(e):
			continue
		var d := World.dist(player.position, e.pos)
		if (gun and d < 38.0) or (not gun and d < mrange + e.radius):
			cands.append({"kind": "enemy", "pos": e.pos, "e": e, "r": e.radius, "pri": -1.0})
	for n in world.nests:
		if n.alive:
			var d := World.dist(player.position, n.pos)
			if (gun and d < 38.0) or (not gun and d < mrange + 3.5):
				cands.append({"kind": "nest", "pos": n.pos, "n": n, "r": 2.2, "pri": -0.5})
	for cd in cands:
		var to_cur := World.dist(cd.pos, hover_point)
		var sc := INF
		if to_cur < snap + cd.r:
			sc = to_cur - cd.r + cd.pri
		elif auto and not gun:
			# ничего под курсором — ближайшее перед героем
			var rel := World.delta(player.position, cd.pos)
			rel.y = 0
			var d := rel.length()
			var front := rel.normalized().dot(face) if d > 0.1 else 1.0
			if front > -0.2:
				sc = 100.0 + d - front * 2.0 + cd.pri * 3.0
		if sc < best_s:
			best_s = sc
			best = cd
	return best


## 1.1.15: стратегия — цель только под курсором: камень, дерево или руда (монстров бьют турели).
func _only_personal(res: String) -> bool:
	var ds: Array = DB.data.resources.get(res, {}).get("drops", [])
	if ds.is_empty():
		return false
	for d in ds:
		if not DB.personal_item(str(d.get("item", ""))):
			return false
	return true


func _strategy_target() -> Dictionary:
	var best := {}
	var best_s := INF
	var hc := World.world_to_cell(hover_point)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var c := World.wc(hc + Vector2i(dx, dz))
			if not zone.inside_cell(c) or factory.building_at(c) != null:
				continue
			var cd := {}
			if world.nodes.has(c):
				if keep_stumps() and is_stump(world.nodes[c].res):
					continue
				if _only_personal(str(world.nodes[c].res)):
					continue   # 1.1.16: грибы в «Стратегии» не нужны
				cd = {"kind": "node", "pos": World.cell_to_world(c), "cell": c, "r": 0.9, "pri": 0.0}
			elif world.can_mine(c):
				cd = {"kind": "deposit", "pos": World.cell_to_world(c), "cell": c, "r": 0.9, "pri": 0.3}
			else:
				continue
			var sc: float = World.dist(cd.pos, hover_point) + float(cd.pri)
			if sc < 2.4 and sc < best_s:
				best_s = sc
				best = cd
	return best


var target := {}
var target_ring: MeshInstance3D


func _update_target(delta: float) -> void:
	var show := build_type == "" and not demolish and player.alive and bool(DB.setting("aim_ring", true))
	target = find_target() if build_type == "" and not demolish else {}
	if target_ring == null:
		target_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.86
		tm.outer_radius = 1.0
		tm.rings = 24
		tm.ring_segments = 6
		target_ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		target_ring.material_override = m
		target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target_ring.set_meta("no_mirror", true)
		add_child(target_ring)
	target_ring.visible = show and not target.is_empty()
	if not target_ring.visible:
		return
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
	var r: float = float(target.r) * 1.15 * pulse
	# кольцо лежит на земле с холмами: берём самую высокую точку под кольцом, чтобы оно не уходило в склон
	var gy: float = factory.support_at(target.pos)
	for k in 6:
		var a := k * TAU / 6.0
		gy = maxf(gy, factory.support_at(target.pos + Vector3(cos(a), 0, sin(a)) * r))
	target_ring.global_position = Vector3(target.pos.x, gy + 0.1, target.pos.z)
	target_ring.scale = Vector3(r, 1.0, r)
	var col := DB.color(DB.setting("aim_color_enemy", "#ff5a46")) if not target.kind in ["node", "deposit"] else DB.color(DB.setting("aim_color_res", "#ffe08a"))
	col.a = 0.85
	(target_ring.material_override as StandardMaterial3D).albedo_color = col


## 1.7: режим топора — оставлять пни (из них снова вырастают деревья) или корчевать. Клавиша поворота с топором в руках.
func keep_stumps() -> bool:
	return bool(Prefs.get_value("axe_keep_stumps", true))


func toggle_stumps() -> void:
	var on := not keep_stumps()
	Prefs.set_value("axe_keep_stumps", on)
	sfx.play_ui("click")
	notify("Топор: " + ("оставлять пни — из них вырастут новые деревья" if on else "корчевать пни"), Color(0.75, 1.0, 0.6))


var _stumps := {}
func is_stump(res: String) -> bool:
	if _stumps.is_empty():
		_stumps["-"] = true
		for id in DB.data.resources:
			var st := str(DB.data.resources[id].get("stump", ""))
			if st != "":
				_stumps[st] = true
	return _stumps.has(res)


## ЛКМ без режима стройки: добыча, выстрел или удар — по автоцели.
func _primary_action() -> void:
	if not player.alive:
		return
	if strategy:
		if not target.is_empty():
			cmd("hit", {"cell": target.cell})
		return
	var it := DB.item(player.selected_item())
	var tg := target
	if it.get("weapon", "") == "gun":
		player.shoot(tg.pos if not tg.is_empty() else Vector3.INF)
		return
	if not tg.is_empty() and tg.kind in ["node", "deposit"]:
		cmd("hit", {"cell": tg.cell})
		return
	if not tg.is_empty():
		player.start_attack(tg.pos, tg.get("e"))
	else:
		player.start_attack()


func _click_world() -> void:
	if hud.any_window_open() and _ui_hovered():
		lmb = false
		return
	if field_selection >= 0:
		lmb = false
		if (cmd("shore_field", {"idx":field_selection,"cell":hover_cell}) if island != null else world.order_field(field_selection, hover_cell)):
			cancel_build()
		return
	if blueprints.active():
		blueprints.click(hover_cell)
		lmb = false
		return
	if zone_pick and island != null:
		cmd("shore_expand", {"cell":hover_cell})
		lmb = false
		return
	if zone_pick:
		cmd("zone_patch", {"rc": zone.patch_at(hover_point)})
		lmb = false
		return
	if wiring:
		var b = wire_pick()
		if wire_from == null:
			if b != null:
				wire_from = b
				sfx.play_ui("click")
			elif factory.building_at(hover_cell) != null:
				notify(DB.tx("w_noel", "Этому зданию энергия не нужна"), Color(1, 0.8, 0.5))
			else:
				notify(DB.tx("w_miss", "Щёлкните по зданию, которому нужна энергия (оно подсветится)"), Color(1, 0.85, 0.5))
		else:
			_wire_release()
		return
	if island != null and not strategy and player.selected_item() == "salvage_rod" and not demolish and build_type == "":
		lmb = false
		island.fishing.click(player,hover_point)
		return
	if strategy and not demolish and build_type == "":
		# 1.1.15: стратегия — щелчок по зданию открывает его окно (по камню и дереву — добыча, в _primary_action)
		var sb = factory.building_at(hover_cell)
		if sb != null:
			lmb = false
			_interact(true)
			return
	if demolish:
		# 1.1.19: что сносим этим нажатием — здание или фундамент; протягивание дальше сносит только то же
		# (раньше здание исчезало, а следующий кадр того же нажатия сносил фундамент под ним)
		if _demo_layer_at(hover_cell) == "" and world.ordered_fields.has(world.dep_corner(hover_cell)):
			lmb = false
			world.remove_field(hover_cell)
			return
		demo_layer = _demo_layer_at(hover_cell)   # 1.1.20: на пустой клетке слой выберет первая клетка с постройкой
		cmd("demolish", {"cell": hover_cell})
	elif build_type != "":
		drag_last = hover_cell
		drag_new = hover_cell if not factory.grid.has(World.wc(hover_cell)) else Vector2i(-999, -999)   # 1.1.19: фундамент под клеткой — не помеха
		drag_placed = cmd("place", {"type": build_type, "cell": hover_cell, "dir": build_dir})
		if drag_placed == null and ghost:
			# 1.3: сюда нельзя — призрак вздрагивает, короткий «нет»
			sfx.play_ui("buzz")
			var gp := ghost.position
			var tw: Tween = ghost.create_tween()
			for k in 4:
				tw.tween_property(ghost, "position", gp + Vector3(0.18 if k % 2 == 0 else -0.18, 0, 0), 0.03)
			tw.tween_property(ghost, "position", gp, 0.03)


## Что снесёт нажатие на клетке: "top" — здание, "found" — фундамент, "" — ничего нет.
func _demo_layer_at(c: Vector2i) -> String:
	if factory.grid.has(World.wc(c)):
		return "top"
	var fl = factory.found.get(World.wc(c))
	return "found" if fl != null and not (fl is Array and fl.is_empty()) and not (fl is Dictionary and fl.is_empty()) else ""


func _drag_world() -> void:
	var cur := hover_cell
	if demolish:
		if demo_layer == "":
			demo_layer = _demo_layer_at(cur)
			if demo_layer == "":
				return
		if (demo_layer == "top") != factory.grid.has(World.wc(cur)):
			return
		cmd("demolish", {"cell": cur})
		return
	if drag_last.x == -999:
		return
	var guard := 0
	while drag_last != cur and guard < 64:
		guard += 1
		var d := World.delta(World.cell_to_world(drag_last), World.cell_to_world(cur)) / C
		var step := Vector2i(signi(roundi(d.x)), 0) if absf(d.x) >= absf(d.z) else Vector2i(0, signi(roundi(d.z)))
		if step == Vector2i.ZERO:
			break
		var dir: int = Factory.DIRS.find(step)
		if _is_belt(build_type):
			build_dir = dir
			# 1.1.15: поворачиваем только ленту, поставленную в этом же протягивании на клетке поворота
			# (раньше, если клетка не встала — сундук, камень, нет ресурсов, — боком разворачивалась лента на несколько клеток назад)
			if drag_placed != null and drag_placed.beh == "belt" and not drag_placed.dead and drag_placed.cell == drag_last:
				cmd("rotate_to", {"b": drag_placed, "dir": dir})
			else:
				_guest_rotate(dir)
		elif str(DB.building(build_type).get("behavior", "")) == "wall":
			# 1.3: стена в линии встаёт вдоль линии (модели стен бывают длинными по X или по Z)
			var wd := factory.wall_dir(build_type, step)
			if wd != build_dir:
				build_dir = wd
				if drag_placed != null and drag_placed.beh == "wall" and not drag_placed.dead and drag_placed.cell == drag_last:
					cmd("rotate_to", {"b": drag_placed, "dir": wd})
				else:
					_guest_rotate(wd)
		if _is_belt(build_type) and drag_cross == drag_last:
			_auto_junction(drag_cross, dir)
		drag_cross = Vector2i(-999, -999)
		var prev := drag_last
		drag_last = World.wc(drag_last + step)
		var ob = factory.building_at(drag_last)
		if _is_belt(build_type) and ob != null and ob.beh == "belt" and ob.kind == 0 and ob.dir % 2 != dir % 2 and prev != drag_last:
			drag_cross = drag_last
		drag_new = drag_last if not factory.grid.has(World.wc(drag_last)) else Vector2i(-999, -999)   # 1.1.19: на фундаменте гость тоже поворачивает ленту
		# 1.1.15: поперечная лента — это перекрёсток (кротовина), а не улучшение: раньше лента Mk2 поверх
		# поперечной Mk1 улучшала её и разворачивала вдоль линии, и поперечная линия рвалась
		var b = null
		if drag_cross != drag_last:
			b = cmd("place", {"type": build_type, "cell": drag_last, "dir": build_dir, "drag": true})
		drag_placed = b


## 1.7: линия лент пересекла поперечную ленту и пошла дальше — на пересечении сама встаёт кротовина.
func _auto_junction(cell: Vector2i, dir: int) -> void:
	var ob = factory.building_at(cell)
	if ob == null or ob.beh != "belt" or ob.dir % 2 == dir % 2:
		return
	if Tech.building_locked("mole_junction") and not flags.get("free_build", false):
		notify_once("auto_jn", "Ленты пересеклись. Откройте «Кротовину» в дереве открытий — она будет ставиться сама", Color(1, 0.8, 0.5))
		return
	cmd("junction_at", {"b": ob})


## 1.7: у гостя «place» уходит хозяину и здание появляется позже — повернуть его по клетке
## (хозяин найдёт здание сам, запросы идут по порядку). Раньше у гостей лента в линии не поворачивалась.
func _guest_rotate(dir: int) -> void:
	if not Net.is_client() or drag_new != drag_last:
		return
	cmd("rotate_to", {"b": {"_b": [drag_new.x, drag_new.y]}, "dir": dir})


func _interact(from_click := false) -> void:
	if vehicles.driving != "" and vehicles.is_driver(player):   # A-1 r6: выходит только водитель
		vehicles.leave()
		return
	var tr = npcs.near_trader() if not from_click else null
	if tr != null:
		hud.open_npc(tr)
		return
	var b = factory.building_at(hover_cell)
	var reach := 9.0 if not strategy else INF   # 1.1.15: в стратегии здания открываются откуда угодно
	if strategy and b != null and b.beh == "vehicle":
		hud.open_building(b)
		return
	if b != null and b.beh == "vehicle" and World.dist(player.position, b.center()) < reach + b.size * C:
		if vehicles.driving != "":
			notify("Второй игрок уже за рулём", Color(1, 0.8, 0.5))
		else:
			vehicles.enter(b)
		return
	if b != null and World.dist(player.position, b.center()) < reach + b.size * C:
		if b.type == "ruin_arch" and b.bstate.has("cave_type") and DB.setting("cave_expeditions_enabled", false):
			enter_cave(b)
		elif b.beh == "station":
			hud.station = b.p("station", "hand")
			hud.station_b = b
			hud.open("craft")
			hud._with_inventory()
		elif b.beh == "terminal":
			hud.tech_tab = 0
			hud.open("tech")
		else:
			hud.open_building(b)
		return
	# вода рядом — попить и набрать флягу
	if world.water_at(hover_cell) and World.dist(player.position, World.cell_to_world(hover_cell)) < 6.0:
		cmd("drink", {})
		return
	if b != null:
		notify("Подойдите ближе", Color(1, 0.8, 0.5))


## Название станции крафта по её коду (берётся из здания, у которого этот код).
func enter_cave(b) -> void:
	if not DB.setting("cave_expeditions_enabled", false) or not b.bstate.has("cave_type"):
		return
	if Net.active() or has_node("Expedition"):
		return
	hud.close_all()
	var trip = preload("res://scenes/exploration/cavern.tscn").instantiate()
	trip.game = self
	trip.entrance = b
	add_child(trip)


func station_name(st: String) -> String:
	for id in DB.data.buildings:
		if str(DB.data.buildings[id].get("params", {}).get("station", "")) == st:
			return str(DB.data.buildings[id].get("name", id))
	return st


func near_stations() -> Array:
	var out := []
	for b in factory.all:
		if b.beh == "station" and (strategy or World.dist(player.position, b.center()) < 10.0):
			var st: String = b.p("station", "")
			if st != "" and not st in out:
				out.append(st)
	return out


# ---------------------------------------------------------------- команды (основа мультиплеера)

## Все действия игрока. Возвращает результат (например, поставленное здание).
## Все действия игрока. В сетевой игре у подключившегося команда уходит хозяину (net.gd).
func cmd(name: String, a: Dictionary):
	if Net.active() and not Net._self().applying:
		var why: String = Net._self().deny(name, a, Net._self().nick)
		if why != "":
			notify_once("deny_" + name, why, Color(1, 0.6, 0.4))
			return null
	if name == "demolish" and tutorial != null and not (Net.active() and Net._self().applying):
		var db = factory.building_at(World.wc(a.cell))
		if db != null and db != factory.hq:
			tutorial.demolished += 1   # 1.7: шаг обучения «Снос»
	if name == "place" and hud != null and not (Net.active() and Net._self().applying):
		hud.explain_once(str(a.get("type", "")))   # 1.1.8: «Как это работает» при первой постройке особого здания
	if Net.active() and Net._self().intercept(name, a):
		return null
	# 1.1.20: здания упаковываем до команды (после «объединить» ящик уже встроен, и гостям уходила ссылка, которой у них нет)
	var pre = Net._self()._pack(a) if Net.is_host() and name in Net.REPLICATED else null
	var r = _cmd_impl(name, a)
	if Net.is_host():
		Net._self().after_cmd(name, a, r, pre)
	return r


func _cmd_impl(name: String, a: Dictionary):
	match name:
		"shore_salvage":
			return island != null and island.fishing.collect(int(a.get("id",0)),player)
		"shore_expand":
			return island != null and a.get("cell") is Vector2i and island.expand(a.cell)
		"shore_offer":
			return island != null and island.deliver()
		"shore_relight":
			return island != null and island.relight(a.get("b"))
		"shore_field":
			return island != null and a.get("cell") is Vector2i and world.order_field(int(a.get("idx",-1)),a.cell)
		"scan":
			return scanner.scan(str(a.id))
		"bag_up":
			var st := Player.bag_next(player.bag_level)
			if st.is_empty():
				notify_once("bag", "Рюкзак уже максимальный", Color(1, 0.6, 0.4))
				return null
			var bcost: Dictionary = st.get("cost", {})
			if not flags.get("free_build", false):
				for it in bcost:
					if factory.available(it) < int(bcost[it]):
						notify_once("bag", "Не хватает: %s" % DB.item_name(it), Color(1, 0.6, 0.4))
						return null
				factory.pay(bcost)
			player.bag_level += 1
			player.apply_bag()
			notify("Рюкзак расширен: %d ячеек" % player.inv.size(), Color(0.5, 1.0, 0.6))
			sfx.play_ui("craft")
			return true
		"zone_patch":
			# 15.5: открыть участок P×P блоков, который выбрал игрок
			var rc: Vector2i = a.rc if a.rc is Vector2i else Vector2i(int(a.rc[0]), int(a.rc[1]))
			var pfree: bool = flags.get("free_build", false)
			var pwhy: String = zone.patch_why(rc) if pfree else zone.patch_can(rc)
			if pwhy != "":
				notify_once("zone_patch_" + pwhy, pwhy, Color(1, 0.6, 0.4))
				return false
			return zone.open_patch(rc, pfree)
		"zone_expand":
			# 1.1.15: у гостя — как решил хозяин (его склад и пауза могут отличаться; ресурсы штаба придут с хозяина)
			var zfree: bool = flags.get("free_build", false) or (Net.is_client() and Net._self().applying)
			var why: String = zone.can_expand()
			if not zfree and why != "":
				notify_once("zone", why, Color(1, 0.6, 0.4))
				return null
			return zone.expand(zfree)
		"place":
			var t: String = a.type
			var cell: Vector2i = World.wc(a.cell)
			if str(DB.building(t).get("behavior", "")) == "rails":
				# 21: бортики кладутся на готовую ленту
				if not factory.rails_ok(t, cell):
					notify_once("rails", DB.tx("rails_why", "Бортики ставятся на ленту без бортиков"), Color(1, 0.6, 0.4))
					return null
				var rcost := _scaled_cost(t)
				if not flags.get("free_build", false):
					for k in rcost:
						if factory.available(k) < rcost[k]:
							notify_once("cost", "%s — не хватает: %s" % [DB.building(t).get("name", t), missing_text(rcost, factory.available)], Color(1, 0.6, 0.4))
							return null
					factory.pay(rcost)
				var rb = factory.building_at(cell)
				factory.set_rails(rb, true)
				return rb
			var up = factory.upgrade_target(t, cell)
			if up == null and factory.can_place(t, cell) != "":
				return null
			var free: bool = flags.get("free_build", false)
			var cost := _scaled_cost(t)
			if up != null and up.lvl > 1:
				# 1.1.15: объединение N улучшается за N новых зданий (раньше — за одно, а вернулись все N старых)
				for k in cost:
					cost[k] = int(cost[k]) * up.lvl
			if not free:
				for k in cost:
					if factory.available(k) < cost[k]:
						notify_once("cost", "%s — не хватает: %s" % [DB.building(t).get("name", t), missing_text(cost, factory.available)], Color(1, 0.6, 0.4))
						return null
				factory.pay(cost)
			var own0 := str(up.bstate.get("owner", "")) if up != null and "bstate" in up else ""
			var b = factory.upgrade(up, t) if up != null else factory.place(t, cell, int(a.dir))
			b.paid = {} if free else cost
			# 1.1.15: лента, улучшенная протягиванием, смотрит вдоль новой линии
			if up != null and b.beh == "belt" and a.get("drag", false) and a.has("dir") and int(a.dir) != b.dir and int(a.dir) % 2 == b.dir % 2:
				factory.set_dir(b, int(a.dir))
			if Net.active():
				b.bstate["owner"] = own0 if own0 != "" else str(a.get("owner", Net._self().actor_nick()))   # 1.1.15: улучшение не переписывает хозяина
				if t == "gnome":
					_gnome_check(b)
			# A-7 r7: рецепт и настройки из чертежа приходят вместе с командой (гость не получает здание в ответ)
			if a.has("bp_r") and b.inv != null and DB.data.recipes.has(str(a.bp_r)):
				factory.set_recipe(b, str(a.bp_r))
			if a.get("bp_cfg") is Dictionary:
				var keep = b.cfg.get("qpair")
				b.cfg = (a.bp_cfg as Dictionary).duplicate(true)
				b.cfg.erase("qpair")
				if keep != null:
					b.cfg["qpair"] = keep
			# 1.1.20 B14-2: «Объединить?» — только тому, кто построил (не всем игрокам)
			if not (Net.active() and Net._self().applying) or (Net.is_client() and str(b.bstate.get("owner", "")) == str(Net._self().nick)):
				factory.fz.check_offers(b)
			fx.dirt(b.center(), 0.35 + 0.15 * b.size)
			factory.pop_in(b)    # 1.3: здание «вырастает» с лёгким перехлёстом
			sfx.play(DB.building(t).get("sounds", {}).get("place", "place"), b.center())
			var xp_mine: bool = not (Net.is_host() and Net._self().actor != 0) and str(a.get("owner", "-")) != ""   # 1.1.15: опыт за постройку гостя (и за капсулу события) — не хозяину
			if xp_mine and Net.active() and a.has("owner") and str(a.owner) != Net._self().nick:
				xp_mine = false   # B-8 r5: чужая постройка, пришедшая по сети, — не мой опыт
			if xp_mine:
				add_xp(float(DB.data.levels.get("xp", {}).get("build", 4)))
			return b
		"order_deal":
			# 1.1.15: сделка по заказу, принятому гостем (у хозяина — от его лица)
			var oo := {"side": str(a.get("side", "sell")), "item": str(a.get("item", "")), "n": int(a.get("n", 0))}
			var off := {"pay_item": str(a.get("pay_item", "")), "pay_n": int(a.get("pay_n", 0)), "credits": int(a.get("credits", 0)), "from": "Заказчик"}
			if not DB.data.items.has(oo.item) or oo.n <= 0 or (off.pay_item != "" and not DB.data.items.has(off.pay_item)) or off.pay_n < 0 or off.credits < 0:
				return false
			# гость сам получает предложения (заказы у каждого свои) — хозяин проверяет, что цена похожа на рыночную
			var mt: float = orders.market_total(oo)
			var lim: float = mt * (1.0 + float(DB.setting("order_spread", 0.12))) * 1.3 + 2.0
			if oo.side == "sell" and (off.credits > lim or (off.pay_item != "" and orders.unit_price(off.pay_item) * off.pay_n > lim)):
				return false
			if oo.side == "buy" and off.credits < mt * 0.7 - 2.0:
				return false
			var ok_deal: bool = orders.deal(oo, off)
			if ok_deal and Net.is_host() and Net._self().actor != 0:
				Net._self().rpc_id(Net._self().actor, "order_done", int(a.get("oid", -1)), str(a.get("text", "")))
			return ok_deal
		"npc_trade":
			# 1.1.15: торговля гостя с НПС — у хозяина (там товар торговца и кошелёк)
			for e in enemies.list:
				if e.nid == int(a.get("nid", -1)) and e.alive:
					if str(a.get("kind", "")) == "buy":
						return npcs.buy_from(e, int(a.get("i", -1)))
					if str(a.get("kind", "")) == "gift":
						return npcs.gift(e, str(a.get("item", ""))) > 0
					return npcs.sell_to(e, str(a.get("item", "")), int(a.get("n", 1)))
			return false
		"ruin_extra":
			# 1.1.15: робот-строитель восстановил объединённое/составное здание — уровень и встроенные машины
			builders.restore_extra(a.get("b"), int(a.get("lvl", 1)), a.get("subs", []) if a.get("subs") is Array else [])
			return a.get("b")
		"repair":
			# 1.1.12: ремонт / восстановление из развалин — по клетке
			return _do_repair(World.wc(a.cell if a.cell is Vector2i else Vector2i(int(a.cell[0]), int(a.cell[1]))))
		"fuse":
			# 14.10: объединить два соседних здания (kind: level — одинаковые, combo — встроить)
			if a.a == null or a.b == null or a.a.dead or a.b.dead:
				return false
			var kind := str(a.get("kind", "level"))
			if kind == "sub":
				# 15.4: объединить с уже встроенным таким же (a — составное, b — новое рядом)
				var hs = a.a if not a.a.subs.is_empty() else a.b
				var ms = a.b if hs == a.a else a.a
				return factory.fz.fuse_into_sub(hs, ms)
			var ok: bool = factory.fz.fuse_level(a.a, a.b) if kind == "level" else factory.fz.fuse_combo(a.a, a.b)
			if not ok:
				var why: String = factory.fz.level_why(a.a, a.b) if str(a.get("kind", "level")) == "level" else factory.fz.combo_why(a.a, a.b)
				notify(why, Color(1, 0.6, 0.4))
			return ok
		"demolish":
			var b = factory.building_at(a.cell)
			if b != null and b.beh == "foundation" and factory.found_why(b) != "":
				notify(factory.found_why(b), Color(1, 0.7, 0.4))
				return
			if b != null and b != factory.hq:
				factory.sink_out(b)  # 1.3: разбирается — оседает и уходит в землю
				factory.deconstruct(b)
				fx.dirt(b.center(), 0.5 + 0.2 * b.size)
				fx.chips(b.center() + Vector3(0, 0.8, 0), Color(0.6, 0.55, 0.5))
				add_trauma(0.12)
				sfx.play("demolish", b.center())
		"wire":
			var why: String = factory.wire_why(a.a, a.b)
			if why != "":
				notify(why, Color(1, 0.6, 0.4))
				return false
			var wc: Dictionary = factory.wire_cost(a.a, a.b)
			if not flags.get("free_build", false) and not wc.is_empty():
				for k in wc:
					if factory.available(k) < wc[k]:
						notify("%s: %s" % [DB.tx("w_nocost", "Не хватает на провод"), missing_text(wc, factory.available)], Color(1, 0.6, 0.4))
						return false
				factory.pay(wc)
			factory.add_wire(a.a, a.b)
			sfx.play("place", a.b.center())
			return true
		"unwire":
			for l in factory.links:
				if l[0] == a.b or l[1] == a.b:
					factory.refund(factory.wire_cost(l[0], l[1]))
			var n: int = factory.unwire(a.b)
			if n > 0:
				sfx.play("click", a.b.center())
		"reset_net":
			factory.reset_net(a.b)
			sfx.play_ui("click")
		"rotate":
			var b = a.b
			factory.set_dir(b, (b.dir + 1) % 4)
		"rotate_to":
			factory.set_dir(a.b, int(a.dir))
		"junction_at":
			# 1.7: поперечная лента → кротовина (ленту разобрали с возвратом, кротовину поставили)
			var jb = a.b
			if jb == null or jb.dead or jb.beh != "belt":
				return null
			var jcell: Vector2i = jb.cell
			var jfree: bool = flags.get("free_build", false)
			if Tech.building_locked("mole_junction") and not jfree:
				return null
			var jcost := _scaled_cost("mole_junction")
			if not jfree:
				var have := {}
				for k in jcost:
					have[k] = factory.available(k) + int(jb.paid.get(k, 0))
					if have[k] < jcost[k]:
						notify_once("cost", "Кротовина — не хватает: %s" % missing_text(jcost, func(it): return have.get(it, 0)), Color(1, 0.6, 0.4))
						return null
			var jdir: int = jb.dir
			factory.deconstruct(jb)
			return _cmd_impl("place", {"type": "mole_junction", "cell": jcell, "dir": jdir})
		"bcfg":
			# настройки умного разделителя / соединителя, ручка тонкой настройки
			var keep_q = a.b.cfg.get("qpair")
			a.b.cfg = a.cfg.duplicate(true)
			a.b.cfg.erase("qpair")   # номер квантовой пары меняет только сама игра
			if keep_q != null:
				a.b.cfg["qpair"] = keep_q
		"detach":
			# 15.4: убрать одно встроенное здание из составного
			return factory.fz.detach(a.h, a.s)
		"bstate":
			# 14.23: пульт АЭС, заказы НЛО — меняет одно поле состояния здания
			a.b.bstate[str(a.key)] = a.val
		"pattern":
			return star.try_pattern(a.cells, player.inv)
		"recipe":
			factory.set_recipe(a.b, a.rid)
		"mv":
			# 1.5: перетаскивание между героем и зданием (одна ячейка или половина)
			var src = player.inv if str(a.s) == "p" else a.b.get(str(a.s))
			var dst = player.inv if str(a.d) == "p" else a.b.get(str(a.d))
			if not (src is Inventory and dst is Inventory):
				return null
			# B-4 r11: в ячейке уже другой предмет (окно гостя устарело) — ничего не двигаем
			if str(a.get("sid", "")) != "" and (int(a.si) < 0 or int(a.si) >= src.slots.size() or src.slots[int(a.si)] == null or str(src.slots[int(a.si)].id) != str(a.sid)):
				return null
			var why := Inventory.move_between(src, int(a.si), dst, int(a.di), bool(a.get("half", false)))
			if why != "":
				notify(why, Color(1, 0.7, 0.4))
				return null
			return true
		"use_item":
			# A17-3/4/5: гость использовал вещь, меняющую мир, — хозяин применяет её от его лица (рюкзак и место — гостя)
			var ui := int(a.get("si", -1))
			if ui < 0 or ui >= player.inv.slots.size() or player.inv.slots[ui] == null or str(player.inv.slots[ui].id) != str(a.get("sid", "")):
				return null
			return player.use_item(ui)
		"xmv":
			# 1.1.20 B15-3: перетаскивание между частями одного составного здания (встроенный ящик ↔ основа/машина)
			var hb1 = a.b.host if a.b.host != null else a.b
			var hb2 = a.b2.host if a.b2.host != null else a.b2
			if hb1 != hb2 or str(a.d) == "out":
				return null   # в выход машины класть нельзя
			var src2 = a.b.get(str(a.s))
			var dst2 = a.b2.get(str(a.d))
			if not (src2 is Inventory and dst2 is Inventory):
				return null
			if str(a.get("sid", "")) != "" and (int(a.si) < 0 or int(a.si) >= src2.slots.size() or src2.slots[int(a.si)] == null or str(src2.slots[int(a.si)].id) != str(a.sid)):
				return null
			var why2 := Inventory.move_between(src2, int(a.si), dst2, int(a.di), bool(a.get("half", false)))
			if why2 != "":
				notify(why2, Color(1, 0.7, 0.4))
				return null
			return true
		"take_slots":
			# 1.5: Shift/двойной клик по ячейкам здания — эти стопки герою
			var tinv = a.b.get(str(a.k))
			if not tinv is Inventory:
				return null
			var moved := 0
			for k in a.idx:
				var ki := int(k)
				if ki < 0 or ki >= tinv.slots.size() or tinv.slots[ki] == null:
					continue
				if a.has("ids") and str(tinv.slots[ki].id) != str(a.ids[a.idx.find(k)]):
					continue   # B-4 r11: в ячейке уже другой предмет
				var o: Dictionary = tinv.slots[ki]
				var left: int = player.inv.add_slot(o)
				moved += int(o.n) - left
				if left == 0:
					tinv.slots[ki] = null
				else:
					o.n = left
					break   # рюкзак полон
			tinv._bump()
			player.inv.changed.emit()
			return moved
		"btrash":
			# 1.5: мусорка для ячеек здания (n < 0 — стопки целиком)
			var binv = a.b.get(str(a.k))
			if not binv is Inventory:
				return null
			for k in a.idx:
				var ki := int(k)
				if ki < 0 or ki >= binv.slots.size() or binv.slots[ki] == null:
					continue
				if a.has("ids") and str(binv.slots[ki].id) != str(a.ids[a.idx.find(k)]):
					continue   # B-4 r11: в ячейке уже другой предмет — не уничтожаем его
				var o: Dictionary = binv.slots[ki]
				if int(a.n) < 0 or int(a.n) >= int(o.n):
					binv.slots[ki] = null
				else:
					o.n = int(o.n) - int(a.n)
			binv._bump()
			return true
		"take":
			var n: int = factory.take_all(a.b, player.inv)
			if n > 0:
				sfx.play_ui("pickup")
			_surprise(a.b)
		"donate":
			var dn: int = tech.donate(a.id)
			if dn <= 0 and tech.state(a.id) == "open" and not tech.left_of(a.id).is_empty():
				notify("Нечего сдать: нужных предметов нет ни в штабе, ни в рюкзаке", Color(1, 0.8, 0.5))
			elif dn <= 0 and not tech.try_finish(a.id) and tech.state(a.id) == "open":
				notify("Не хватает кредитов или очков исследований", Color(1, 0.8, 0.5))
			hud.refresh_open()
		"tech_target":
			tech.target = a.id
			hud.refresh_open()
		"c_deliver":
			if tech.c_deliver(a.id) <= 0:
				notify("Нечего сдать: нужных предметов нет ни в штабе, ни в рюкзаке", Color(1, 0.8, 0.5))
			hud.refresh_open()
		"drain":
			factory.drain(a.b)
			notify("Жидкость слита", Color(0.6, 0.85, 1))
		"take_ready":
			var n: int = factory.take_ready(a.b, player.inv)
			if n > 0:
				sfx.play_ui("pickup")
			else:
				notify(DB.tx("nothing_ready", "Готового пока нет"), Color(1, 0.85, 0.5))
		"put_all":
			var n2: int = factory.put_from(a.b, player.inv)
			if n2 > 0:
				sfx.play_ui("click")
			else:
				notify("Нечего положить в это здание", Color(1, 0.8, 0.5))
		"put":
			var k := 0
			if a.b.beh in ["storage", "hq"] and a.b.inv != null:
				k = player.inv.move_to(a.b.inv, str(a.id), int(a.n), true)   # B-10 r5: износ/свежесть не сбрасываются
			while k < int(a.n) and player.inv.count(a.id) > 0 and factory.accept(a.b, a.id, null):
				player.inv.remove(a.id, 1)
				k += 1
			if k > 0 and str(a.id) == "surprise":
				a.b.bstate["surprise"] = Net._self().actor_nick() if Net.active() else "?"
			if k == 0 and int(a.n) > 0:
				notify(DB.t(DB.tx("not_accepted", "{b} не принимает: {i}"), {"b": DB.building(a.b.type).get("name", a.b.type), "i": DB.item_name(a.id)}), Color(1, 0.8, 0.5))
			elif k > 0:
				sfx.play_ui("click")
		"stash":
			# 1.1.16: вещь, не влезшая в рюкзак в стратегии, — в свой штаб; не влезла и туда — на землю у штаба
			var sq = factory.personal_b if factory.personal != null else factory.hq
			var sid := str(a.get("id", ""))
			var sn := int(a.get("n", 0))
			if sn <= 0 or not DB.data.items.has(sid):
				return
			var sl = a.get("slot", {})
			var sleft := sn
			if sq != null and sq.inv != null:
				if sl is Dictionary and not sl.is_empty():
					sl = sl.duplicate()
					sl["id"] = sid
					sl["n"] = sn
					sleft = sq.inv.add_slot(sl)
				else:
					sleft = sq.inv.add(sid, sn)
			if sleft > 0:
				drops.spawn(sid, sleft, (sq.center() if sq != null else player.position) + Vector3(0, 1.5, 0))
		"store_hq":
			var shq = factory.personal_b if factory.personal != null else factory.hq
			if shq == null or (World.dist(player.position, shq.center()) > 14.0 and not strategy):
				coop.tell("Подойдите к своему аванпосту" if factory.personal != null else "Подойдите к штабу")
				return
			for i in range(Player.hot_n(), player.inv.size()):
				var s = player.inv.slots[i]
				if s != null and not s.has("dur") and not s.has("fresh"):
					var left: int = shq.inv.add(s.id, s.n)
					if left == 0:
						player.inv.slots[i] = null
					else:
						s.n = left
			player.inv.changed.emit()
		"hit":
			player.start_swing(a.cell)
		"craft":
			queue_craft(a.rid, int(a.n), a.station)
		"coop_base":
			# 16: своя база игрока в сетевой игре (участок земли и аванпост)
			return coop.make_base(a.cell if a.cell is Vector2i else Vector2i(int(a.cell[0]), int(a.cell[1])), a.rc if a.rc is Vector2i else Vector2i(int(a.rc[0]), int(a.rc[1])), str(a.owner))
		"paint":
			coop.paint(a.b, str(a.by))
		"mbuy":
			return coop.market_buy(a.b, str(a.id), int(a.n))
		"msell":
			return coop.market_sell(a.b, str(a.id), int(a.n))
		"pay":
			if not Net.active():
				return false
			var N = Net._self()
			var to := str(a.to)
			var amt := int(a.n)
			if coop.peer_of(to) == 0 or to == N.actor_nick():
				coop.tell("Нет такого игрока: %s" % to)
			elif not N.own_wallets():
				coop.tell("В этой комнате деньги общие — переводить не нужно")
			elif amt <= 0 or credits < amt:
				coop.tell("Не хватает кредитов")
			else:
				credits -= amt
				N.wallet_add(to, amt)
				N.send_chat_raw("%s перевёл %d кр игроку %s" % [N.actor_nick(), amt, to])
				return true
			return false
		"gift":
			if not Net.active():
				return false
			# B-4 r9: дарятся только обычные вещи — подарок не хранит износ и свежесть
			var plain := 0
			for sl in player.inv.slots:
				if sl != null and sl.id == str(a.id) and not (sl.has("dur") or sl.has("fresh")):
					plain += int(sl.n)
			var gn := mini(int(a.n), plain)
			if gn <= 0 and player.inv.count(str(a.id)) > 0:
				coop.tell("Изношенные инструменты и начатую еду подарить нельзя")
				return false
			if gn <= 0 or coop.peer_of(str(a.to)) == 0 or str(a.to) == Net._self().actor_nick():
				coop.tell("Некому подарить или нечего")
				return false
			for i in gn:
				factory._take_plain(player.inv, str(a.id))
			Net._self().give_nick(str(a.to), str(a.id), gn)
			var th = coop.hero_of(str(a.to))
			var gd := {"to": str(a.to), "id": str(a.id), "n": gn, "pos": th.position if th else player.position, "by": Net._self().actor_nick()}
			Net._self().rpc("fun_remote", "gift", gd)
			coop.on_fun("gift", gd)
			return true
		"sell":
			sell(a.id, int(a.n))
		"buy":
			buy(a.id, int(a.n))
		"drink":
			if player.water < 99.0:
				player.water = 100.0
				sfx.play("eat", player.position)
				notify("Вы попили воды", Color(0.5, 0.8, 1))
	return null


## 16: «Сюрприз» в ящике: кто достал — тому «Бу!» (предмет исчезает).
func _surprise(b) -> void:
	if b == null or not b.bstate.has("surprise") or player.inv.count("surprise") <= 0:
		return
	var by := str(b.bstate.surprise)
	b.bstate.erase("surprise")
	player.inv.remove("surprise", player.inv.count("surprise"))
	var d := {"pos": b.center(), "victim": Net._self().actor_nick() if Net.active() else "Вы", "by": by}
	if Net.active():
		Net._self().rpc("fun_remote", "boo", d)
	coop.on_fun("boo", d)


## Гнома поставили рядом с чужим зданием — все узнают.
func _gnome_check(g) -> void:
	var own := str(g.bstate.get("owner", ""))
	var nb = null
	for b in factory.all:
		var o := str(b.bstate.get("owner", ""))
		if o != "" and o != own and b != g and World.dist(b.center(), g.center()) < 16.0:
			nb = b
			break
	if nb != null and (not Net.active() or Net.is_host()):
		var d := {"to": str(nb.bstate.owner), "by": own}
		if Net.active():
			Net._self().rpc("fun_remote", "gnome", d)
		coop.on_fun("gnome", d)


func _scaled_cost(t: String) -> Dictionary:
	var cost := factory.cost_of(t)
	var k := 1.0 + bonus("build_cost")
	var out := {}
	for id in cost:
		out[id] = maxi(1, ceili(int(cost[id]) * k))
	return out


# ---------------------------------------------------------------- крафт

func can_craft(rid: String, n := 1) -> bool:
	var r: Dictionary = DB.data.recipes.get(rid, {})
	for k in r.get("in", {}):
		if player.inv.count(k) < int(r["in"][k]) * n:
			return false
	return not r.is_empty()


func queue_craft(rid: String, n: int, station: String) -> void:
	var r: Dictionary = DB.data.recipes.get(rid, {})
	if r.is_empty():
		return
	if station != "hand" and not station in near_stations():
		notify("Подойдите к станции: " + station_name(station), Color(1, 0.8, 0.5))
		return
	# B-5 r11: у гостя вещи команды в пути ещё числятся в рюкзаке — крафт ждёт ответа хозяина
	if Net.busy():
		var pl_now = player
		Net.when_idle(func():
			if split != null and pl_now != player and is_instance_valid(pl_now):
				return
			queue_craft(rid, n, station))
		return
	var made := 0
	for i in n:
		if not can_craft(rid, 1) or craft_queue.size() >= int(DB.setting("craft_queue_max", 50)):
			break
		for k in r.get("in", {}):
			player.inv.remove(k, int(r["in"][k]))
		craft_queue.append({"rid": rid, "t": 0.0, "station": station, "seat": split.seat_of(player) if split != null else 0})   # A-11 r5: чей заказ
		made += 1
	if made == 0:
		var miss := missing_text(r.get("in", {}), player.inv.count)
		notify("%s — %s" % [r.get("name", rid), ("не хватает: " + miss) if miss != "" else "очередь крафта заполнена"], Color(1, 0.6, 0.4))


var _craft_chk := 0.0
var _craft_far := false


func _update_craft(delta: float) -> void:
	if craft_queue.is_empty():
		return
	var q: Dictionary = craft_queue[0]
	var r: Dictionary = DB.data.recipes.get(q.rid, {})
	# A16-6: крафт на станции идёт, только пока герой рядом с ней (раз в 0.5 с проверка)
	var qst := str(q.get("station", "hand"))
	if qst != "hand" and qst != "" and not strategy and (split == null or not split.running() or int(q.get("seat", 0)) == split.cur):
		_craft_chk -= delta
		if _craft_chk <= 0.0:
			_craft_chk = 0.5
			_craft_far = not qst in near_stations()
			if _craft_far:
				notify_once("craft_far", "Крафт на паузе — вернитесь к станции: " + station_name(qst), Color(1, 0.8, 0.5))
		if _craft_far:
			return
	q.t += delta * max(0.2, 1.0 + bonus("craft_speed"))
	if q.t >= float(r.get("time", 1.0)):
		craft_queue.pop_front()
		if split != null and split.running() and int(q.get("seat", 0)) != split.cur:
			split.with_seat(int(q.get("seat", 0)), _craft_give.bind(q, r))
		elif split != null and not split.running() and int(q.get("seat", 0)) == 1:
			# A-5 r9: заказ второго игрока, а его сейчас нет — изделие ждёт его в его вещах
			var tmp := Inventory.new(maxi(Player.bag_size(int(split.p2_start_extra.get("bag", 0))), split.p2_start_inv.size()))
			tmp.from_array(split.p2_start_inv)
			for k in r.get("out", {}):
				var left: int = tmp.add(k, int(r["out"][k]))
				if left > 0 and factory.hq != null:
					factory.hq.inv.add(k, left)
			split.p2_start_inv = tmp.to_array()
		else:
			_craft_give(q, r)


## 1.1.16: не влезло в рюкзак. В стратегии героя нет и подбирать с земли некому — вещь уходит в штаб
## (или свой аванпост); с героем — падает у ног, как раньше. В обоих случаях игрок видит почему.
func overflow(id: String, n: int, at: Vector3, slot: Dictionary = {}) -> void:
	if n <= 0:
		return
	if strategy:
		var a := {"id": id, "n": n}
		if not slot.is_empty():
			a["slot"] = slot
		cmd("stash", a)
		notify_once("bag_full_hq", DB.t(DB.tx("bag_full_hq", "Рюкзак полон: {i} ×{n} — в штабе"), {"i": DB.item_name(id), "n": n}), Color(1, 0.85, 0.5))
		return
	if Net.is_host() and Net._self().applying and int(Net._self().actor) > 1 and Net._self().peers.has(Net._self().actor):
		# B16-3: лишнее гостя (возврат при сносе, покупка…) — ему: у себя он положит или уронит рядом с собой
		# (вещи на земле по сети не передаются, а уроненное у хозяина гость бы не увидел)
		if slot.is_empty():
			Net._self().give_to(int(Net._self().actor), id, n)
		else:
			var gs: Dictionary = slot.duplicate()   # B17-1: целой ячейкой — с износом и свежестью
			gs["id"] = id
			gs["n"] = n
			Net._self().rpc_id(int(Net._self().actor), "got_slot", gs)
		return
	if slot.is_empty():
		drops.spawn(id, n, at)
	else:
		drops.spawn_slot(slot, at)
	notify_once("bag_full", DB.tx("bag_full", "Рюкзак полон — вещи на земле"), Color(1, 0.8, 0.5))


func _craft_give(q: Dictionary, r: Dictionary) -> void:
	if true:
		for k in r.get("out", {}):
			var left: int = player.inv.add(k, int(r["out"][k]))
			if left > 0:
				overflow(k, left, player.position + Vector3(0, 1, 0))
		sfx.play_ui("craft")
		add_xp(float(DB.data.levels.get("xp", {}).get("craft", 2)))
		notify("Готово: " + r.get("name", q.rid), Color(0.6, 1, 0.7))


# ---------------------------------------------------------------- выживание и эффекты

var _spoil_acc := 0.0

## A-6 r7: живые стражи разбуженных гнёзд (индекс гнезда → типы), чтобы загрузка не создавала их заново.
func _nest_guards_save() -> Dictionary:
	var out := {}
	for i in world.nests.size():
		var n: Dictionary = world.nests[i]
		if not n.alive:
			continue
		if n.get("left") is Array:
			out[str(i)] = n.left
		elif n.guards:
			out[str(i)] = (n.get("mobs", []) as Array).filter(func(e): return e != null and e.alive).map(func(e): return e.type)
	return out


func _update_survival(delta: float) -> void:
	if not module("survival") or not player.alive or flags.get("god", false) or strategy:
		return
	var k := 1.0 + bonus("hunger")
	var moving := player.move_dir.length() > 10.0
	player.food = max(0.0, player.food - float(DB.data.settings.get("hunger_rate", 0.25)) * delta * k * (1.5 if moving else 1.0))
	player.water = max(0.0, player.water - float(DB.data.settings.get("thirst_rate", 0.35)) * delta * k * (1.5 if moving else 1.0) * (events.thirst_mult() if events else 1.0))
	if player.food <= 0.0 or player.water <= 0.0:
		player.hp -= float(DB.data.settings.get("starve_damage", 2.0)) * delta
		notify_once("starve", "Герой голодает! Поешьте (ПКМ по еде) и попейте у воды (E).", Color(1, 0.5, 0.3))
		if player.hp <= 0.0:
			player.hp = 0.01
			player.damage(1.0)
	# порча еды
	_spoil_acc += delta
	if _spoil_acc < 1.0:
		return
	var dt := _spoil_acc
	_spoil_acc = 0.0
	for inv in [player.inv]:
		for i in inv.slots.size():
			var s = inv.slots[i]
			if s == null:
				continue
			var sp := float(DB.item(s.id).get("spoil", 0))
			if sp <= 0.0:
				continue
			s["fresh"] = float(s.get("fresh", sp)) - dt
			if s.fresh <= 0.0:
				inv.slots[i] = {"id": "rotten", "n": s.n}
				notify("%s испортились" % DB.item_name(s.id), Color(0.7, 0.8, 0.4))
				inv.changed.emit()


func _update_effects(delta: float) -> void:
	for k in effects.keys():
		effects[k].t -= delta
		if effects[k].t <= 0.0:
			notify("Закончилось: " + effects[k].name, Color(0.7, 0.8, 0.9))
			effects.erase(k)


# ---------------------------------------------------------------- ремонт

## 1.1.12: ремонт и восстановление — держать ПКМ (15 с по умолчанию), стоит до половины цены здания
## (повреждённое — по доле урона, разрушенное — ровно половина). Правило «Ремонт зданий» (repair111).
var rep_t := 0.0
var _rep_ang := 0.0
var rep_key := Vector2i(-99999, -99999)


static func repair_cfg() -> Dictionary:
	var c = DB.setting("repair111", {})
	return c if c is Dictionary else {}


## Что чинится в клетке: {"kind": "b"|"ruin", "b"|"r", "type", "frac"} или пусто.
func repair_target(c: Vector2i) -> Dictionary:
	var b = factory.building_at(c)
	if b != null:
		if b.hp < b.maxhp - 0.5 and not b.dead:
			return {"kind": "b", "b": b, "type": b.type, "frac": clampf(1.0 - b.hp / b.maxhp, 0.0, 1.0), "cell": b.cell}
		return {}
	if builders != null:
		var r = builders.ruin_at(c)
		if r != null:
			return {"kind": "ruin", "r": r, "type": str(r.type), "frac": 1.0, "cell": r.cell}
	return {}


func repair_cost(t: Dictionary) -> Dictionary:
	var k := float(repair_cfg().get("cost_k", 0.5)) * float(t.get("frac", 1.0))
	var base := _scaled_cost(str(t.type))
	if t.get("kind", "") == "ruin":
		base = builders.ruin_cost(t.r)   # 1.1.15: с уровнем и встроенными
	elif t.get("b") != null and (t.b.lvl > 1 or not t.b.subs.is_empty()):
		base = builders.ruin_cost({"type": t.type, "lvl": t.b.lvl, "subs": builders._subs_plan(t.b)})
	var out := {}
	for id in base:
		out[id] = maxi(1, ceili(int(base[id]) * k))
	return out


func repair_time() -> float:
	return maxf(0.5, float(repair_cfg().get("time", 15.0))) / (1.0 + bonus("repair") * 0.2)


## Строка «нужно: …» с тем, чего не хватает (красным).
func repair_need_text(cost: Dictionary) -> String:
	var parts := []
	for id in cost:
		var have: int = factory.available(id)
		var col := "#8fff9f" if have >= int(cost[id]) else "#ff6b5a"
		parts.append("[color=%s]%s %d[/color] (есть %d)" % [col, DB.item_name(id), int(cost[id]), have])
	return ", ".join(parts)


func _update_repair(delta: float) -> void:
	if not rmb or build_type != "" or demolish or not player.alive or hud.any_window_open():
		rep_t = 0.0
		return
	var t := repair_target(hover_cell)
	if t.is_empty():
		rep_t = 0.0
		return
	var center: Vector3 = t.b.center() if t.kind == "b" else builders.ruin_center(t.r)
	if World.dist(center, player.position) > 18.0 and not strategy:
		notify_once("repair_far", "Подойдите ближе, чтобы чинить", Color(1, 0.7, 0.4))
		rep_t = 0.0
		return
	if t.cell != rep_key:
		rep_key = t.cell
		rep_t = 0.0
	var cost := repair_cost(t)
	if not flags.get("free_build", false):
		for id in cost:
			if factory.available(id) < int(cost[id]):
				notify_once("repair", "Для ремонта не хватает: %s" % missing_text(cost, factory.available), Color(1, 0.7, 0.4))
				rep_t = 0.0
				return
	rep_t += delta
	if strategy:
		# 1.1.17: героя нет — энергия кружит вокруг самого здания (раньше луч шёл из центра экрана)
		_rep_ang += delta * 3.5
		var rr: float = maxf(1.3, float(DB.building(str(t.get("type", ""))).get("size", 1)) * World.C * 0.62)
		for k in 3:
			var a0: float = _rep_ang + k * TAU / 3.0
			var h: float = 0.5 + 0.45 * sin(_rep_ang * 1.7 + k * 2.1)
			var p1: Vector3 = center + Vector3(cos(a0) * rr, h, sin(a0) * rr)
			var p2: Vector3 = center + Vector3(cos(a0 + 0.55) * rr, h + 0.25 * sin(_rep_ang * 3.0 + k), sin(a0 + 0.55) * rr)
			fx.tracer(p1, p2, Color(0.3, 0.9, 1.0), 0.05)
	else:
		fx.tracer(player.muzzle.global_position, player.muzzle.global_position + World.delta(player.muzzle.global_position, center + Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6))), Color(0.3, 0.9, 1.0), 0.04)
	spark_acc -= delta
	if spark_acc <= 0.0:
		spark_acc = 0.15
		fx.spark(center + Vector3(0, 1, 0))
		sfx.play("repair", center)
	if rep_t >= repair_time():
		rep_t = 0.0
		cmd("repair", {"cell": t.cell})


## Выполнить ремонт (у хозяина — с оплатой, у гостей — по команде хозяина).
func _do_repair(c: Vector2i):
	var t := repair_target(c)
	if t.is_empty():
		return false
	var cost := repair_cost(t)
	var free: bool = flags.get("free_build", false)
	if not free:
		for id in cost:
			if factory.available(id) < int(cost[id]):
				notify_once("repair", "Для ремонта не хватает: %s" % missing_text(cost, factory.available), Color(1, 0.7, 0.4))
				return false
		factory.pay(cost)
	if t.kind == "b":
		var b = t.b
		factory.repair(b, b.maxhp)
		fx.spark(b.center() + Vector3(0, 1, 0))
		if not (Net.is_client() and Net._self().applying):
			notify("Отремонтировано: %s" % DB.building(b.type).get("name", b.type), Color(0.5, 1.0, 0.6))
		return true
	var r: Dictionary = t.r
	var free_was = flags.get("free_build", null)
	flags["free_build"] = true
	var pa := {"type": r.type, "cell": r.cell, "dir": r.dir}
	if str(r.get("owner", "")) != "":
		pa["owner"] = str(r.owner)   # B-6 r4: восстановленное здание — прежнему владельцу
	var nb = _cmd_impl("place", pa)
	if free_was == null:
		flags.erase("free_build")
	else:
		flags["free_build"] = free_was
	if nb == null:
		if not free:
			for id in cost:
				factory.give_player(id, int(cost[id]))
		var hw: String = hearts.why(str(r.type), r.cell) if hearts != null else ""   # 1.1.20 A14-6: настоящая причина
		notify_once("repair_place", ("Здесь не восстановить: " + hw) if hw != "" else "Здесь не восстановить: место занято", Color(1, 0.7, 0.4))
		return false
	nb.paid = {} if free else cost
	if str(r.get("r", "")) != "" and nb.beh in ["crafter", "miner"]:
		factory.set_recipe(nb, str(r.r))
	if r.get("cfg") is Dictionary and not r.cfg.is_empty():
		nb.cfg = r.cfg.duplicate(true)
	builders.restore_extra(nb, int(r.get("lvl", 1)), r.get("subs", []))
	if builders.ruins.has(r):
		builders._drop_ruin(r)
	if not (Net.is_client() and Net._self().applying):
		notify("Восстановлено: %s" % DB.building(nb.type).get("name", nb.type), Color(0.5, 1.0, 0.6))
	return nb


# ---------------------------------------------------------------- подсказка под курсором

func info_text() -> String:
	if hud.any_window_open():
		return ""
	var b = factory.building_at(hover_cell)
	if b == null:
		var dep := world.deposit_item(hover_cell)
		var n = world.nodes.get(hover_cell)
		var t := ""
		if n != null:
			var rd: Dictionary = DB.data.resources.get(n.res, {})
			var tool: String = rd.get("tool", "")
			t = "[b]%s[/b]\nПрочность: %d / %d" % [rd.get("name", n.res), int(n.hp), int(n.maxhp)]
			if tool != "":
				t += "\nЛучше всего: %s" % {"axe": "топор", "pickaxe": "кирка"}.get(tool, tool)
			t += "\nЛКМ рядом — добывать"
		if dep != "":
			t += ("\n\n" if t != "" else "") + "[b]Месторождение[/b]: %s\nСюда ставится бур" % DB.item_name(dep)
			var pu: Dictionary = world.purity_of(hover_cell)
			if not pu.is_empty():
				var pm := float(pu.get("per_min", 60))
				var mk := []
				for mid in ["miner", "miner_mk2", "miner_mk3", "miner_mk4", "miner_mk5"]:
					if DB.data.buildings.has(mid):
						mk.append("Mk%d — %d" % [mk.size() + 1, int(pm * float(DB.building(mid).get("params", {}).get("rate_mult", mk.size() + 1)))])
				t += "\nКачество: [color=%s][b]%s[/b][/color] — руды в минуту: %s" % [str(pu.get("color", "#ffffff")), str(pu.get("name", pu.get("id", ""))), ", ".join(mk)]
			if world.can_mine(hover_cell):
				t += "\nЛКМ рядом — добывать руками (киркой быстрее)"
		if t == "" and world.water_at(hover_cell):
			t = "[b]Вода[/b]\nE рядом — попить"
		var rt := repair_target(hover_cell)
		if not rt.is_empty():
			# 1.1.12: развалины разрушенного здания — можно восстановить за половину цены
			t = "[b][color=#ffa040]Развалины: %s[/color][/b]\n[color=#7fdcff]Восстановить: держите ПКМ %d с[/color]%s\nНужно: %s\nИли просто поставьте сюда новое здание" % [
				DB.building(rt.type).get("name", rt.type), ceili(repair_time()), _rep_progress(rt.cell), repair_need_text(repair_cost(rt))]
		return t
	var d := DB.building(b.type)
	var t2 := "[b][color=#ffa040]%s[/color][/b]\nПрочность: %d / %d" % [factory.fz.title(b), int(b.hp), int(b.maxhp)]
	if b.lvl > 1:
		t2 += "\n[color=#ffd36b]Объединение %d: сила ×%s[/color]" % [b.lvl, Fusion._num(b.mult)]
	if not b.subs.is_empty():
		t2 += "\n[color=#9fdcff]%s[/color]" % factory.fz.chain_text(b)
	match b.beh:
		"belt":
			t2 += "\nГруз: %s" % (DB.item_name(b.item) if b.item != "" else "пусто")
			t2 += "\n%s: %d %s" % [DB.tx("tp_speed", "Скорость"), int(round(factory.rate_max(b))), DB.tx("per_min", "в минуту")]
		"miner":
			t2 += "\nДобывает: %s" % DB.item_name(b.recipe)
			t2 += "\n%d / %d %s" % [int(round(factory.rate_now(b))), int(round(factory.rate_max(b))), DB.tx("per_min", "в минуту")]
		"crafter":
			t2 += "\n%s" % (("Делает: " + DB.data.recipes.get(b.crafting, {}).get("name", "")) if b.crafting != "" else "Ждёт сырьё")
			if factory.rate_max(b) > 0.0:
				t2 += "\n%d / %d %s" % [int(round(factory.rate_now(b))), int(round(factory.rate_max(b))), DB.tx("per_min", "в минуту")]
	if not b.subs.is_empty() and Fusion.role(b) != "power":
		t2 += "\nЭнергия: %d%%%s" % [int(b.csat * 100), (" · своя, запас %d%%" % int(b.cen / maxf(1.0, b.ccap) * 100)) if b.ccap > 0 else (" · своя" if b.has_gen else "")]
	elif float(b.p("power", 0)) > 0 and b.beh != "hq" and b.beh != "generator":
		t2 += "\n%s" % ("[color=#ff6b5a]Нет энергии[/color]" if b.net < 0 else "Энергия: %d%%" % int(factory.net_info(b).get("sat", 0) * 100))
	if not b.beh in ["belt", "floor", "wall", "decor"]:
		t2 += "\n[color=#7fdcff]E — открыть[/color]"
	if b.hp < b.maxhp - 0.5:
		var rt := repair_target(b.cell)
		t2 += "\n[color=#7fdcff]Ремонт: держите ПКМ %d с[/color]%s\nНужно: %s" % [ceili(repair_time()), _rep_progress(b.cell), repair_need_text(repair_cost(rt))]
	return t2


func _rep_progress(c: Vector2i) -> String:
	if rep_t <= 0.0 or rep_key != c:
		return ""
	var k := clampf(rep_t / repair_time(), 0.0, 1.0)
	var n := int(k * 20)
	return "  [color=#7fdcff]%s[/color][color=#3a4250]%s[/color] %d%%" % ["█".repeat(n), "█".repeat(20 - n), int(k * 100)]


# ---------------------------------------------------------------- экономика

func add_credits(n: int, show := true) -> void:
	credits += n
	if not (Net.is_host() and Net._self().applying and int(Net._self().actor) > 1 and Net._self().own_wallets()):
		earned += n   # B18-2: при своих кошельках заработок гостя считается у гостя (trade_credit)
	if show:
		notify("+%d кр" % n, Color(1, 0.85, 0.3))


## 1.1.8: старые тесты рассчитаны на экономику до 1.1.8: старые цены открытий, старт 100 кр, участки зоны, без Чёрного рынка в расчётах.
const _OLD_CR := {"t_chem": 200, "t_special": 500, "t_mk4": 1500, "t_mk5": 4000, "t_quantum": 6000}


func _old_economy() -> void:
	var e = DB.setting("economy18", {})
	e = e.duplicate() if e is Dictionary else {}
	e["on"] = false
	DB.data.settings["economy18"] = e
	DB.data.world["start_credits"] = 100
	var co = DB.setting("coop", {})
	if co is Dictionary:
		co = co.duplicate()
		co["start_credits"] = 150
		DB.data.settings["coop"] = co
	var z = DB.setting("zone", {})
	if z is Dictionary:
		z = z.duplicate()
		z["patches"] = true
		DB.data.settings["zone"] = z
	for id in DB.data.tech:
		var n = DB.data.tech[id]
		if n is Dictionary and n.has("credits"):
			n = n.duplicate()
			n["credits"] = int(_OLD_CR.get(id, 0))
			DB.data.tech[id] = n


## 1.1.8: сколько платят за 1 штуку при экономике на кредитах: как Чёрный рынок × доля канала (станция, заказы),
## с учётом того, как цена просела от продаж. Дробное — доли кредита копятся.
func sell_value(id: String, channel := "station_k") -> float:
	return Blocks.bm_value(self, id) * price_mult.get(id, 1.0) * float(Blocks.econ().get(channel, 0.5))


## Кредиты для показа: 0.001, 0.25, 3.5, 120.
static func fmt_cr(x: float) -> String:
	if x >= 100.0:
		return str(roundi(x))
	if x >= 10.0:
		return String.num(snappedf(x, 0.1))
	if x >= 0.1:
		return String.num(snappedf(x, 0.01))
	return String.num(snappedf(x, 0.001)) if x >= 0.001 else String.num(snappedf(x, 0.0001))


var _sell_frac := 0.0


func sell_price(id: String) -> int:
	return maxi(1, roundi(minf(float(DB.item(id).get("price", 1)) * price_mult.get(id, 1.0) * econ_mult(id) * (1.0 + bonus("sell")), Blocks.shop_sell_cap(id) * 2.0)))   # A-2 r10


## Купить всегда дороже, чем можно продать в любой момент (даже с бонусами к продаже) — без перепродажи.
func buy_price(id: String) -> int:
	var k := maxf(1.0, price_mult.get(id, 1.0) * econ_mult(id, true)) * 1.8 * (1.0 + maxf(0.0, bonus("sell")))
	return maxi(2, ceili(float(DB.item(id).get("price", 1)) * k))


# ---- живая экономика: сезоны, события мира и «чего у вас много — то дешевле» (всё в «Данные → Настройки»)
var abundance := {}   # предмет -> множитель цены (меньше 1 у того, чего у игрока больше всего)


## Сезон сейчас: запись из списка «Сезоны» (по дням), пусто — сезонов нет.
func season() -> Dictionary:
	var ss: Array = DB.setting("seasons", [])
	if ss.is_empty():
		return {}
	var total := 0
	for x in ss:
		total += maxi(1, int(x.get("days", 5)))
	var d := (day_n - 1) % maxi(1, total)
	for x in ss:
		d -= maxi(1, int(x.get("days", 5)))
		if d < 0:
			return x
	return ss[0]


static func _mod_fits(m: Dictionary, id: String) -> bool:
	var it := str(m.get("item", ""))
	var cat := str(m.get("category", ""))
	if it != "":
		return it == id
	if cat != "":
		return str(DB.item(id).get("category", "")) == cat
	return true


## Во сколько раз цена сейчас выше или ниже обычной из-за сезона, событий и запасов игрока.
## for_buy — для покупки запасы игрока не учитываются (станция не продаёт дешевле то, чего у вас много).
func econ_mult(id: String, for_buy := false) -> float:
	var k := 1.0
	for m in season().get("prices", []):
		if _mod_fits(m, id):
			k *= float(m.get("mult", 1.0))
	if events:
		for eid in events.active:
			for m in events.list().get(eid, {}).get("prices", []):
				if _mod_fits(m, id):
					k *= float(m.get("mult", 1.0))
	if not for_buy:
		k *= float(abundance.get(id, 1.0))
	return clampf(k, 0.05, 20.0)


## Почему цена такая: строки для подсказки в окне торговли.
func econ_reasons(id: String) -> Array:
	var out := []
	var se := season()
	for m in se.get("prices", []):
		if _mod_fits(m, id) and absf(float(m.get("mult", 1.0)) - 1.0) > 0.001:
			out.append("%s: %+d%%" % [str(se.get("name", "Сезон")), roundi((float(m.get("mult", 1.0)) - 1.0) * 100.0)])
	if events:
		for eid in events.active:
			var e: Dictionary = events.list().get(eid, {})
			for m in e.get("prices", []):
				if _mod_fits(m, id) and absf(float(m.get("mult", 1.0)) - 1.0) > 0.001:
					out.append("%s: %+d%%" % [str(e.get("name", eid)), roundi((float(m.get("mult", 1.0)) - 1.0) * 100.0)])
	if abundance.has(id):
		out.append("У вас этого больше всего: %+d%%" % roundi((float(abundance[id]) - 1.0) * 100.0))
	return out


## Пересчитать «чего у игрока больше всего»: несколько самых многочисленных предметов в штабе и рюкзаке дешевеют.
## Игрок, скорее всего, будет продавать именно их — станция платит меньше. Сила и число — в настройках.
func update_abundance() -> void:
	abundance.clear()
	if not bool(DB.setting("econ_abundance", true)):
		return
	var cnt := {}
	if factory and factory.hq:
		for sl in factory.hq.inv.slots:
			if sl != null and sl.get("id", "") != "":
				cnt[sl.id] = cnt.get(sl.id, 0) + int(sl.get("n", 0))
	if player:
		for sl in player.inv.slots:
			if sl != null and sl.get("id", "") != "":
				cnt[sl.id] = cnt.get(sl.id, 0) + int(sl.get("n", 0))
	var ids := cnt.keys().filter(func(x): return int(cnt[x]) >= int(DB.setting("econ_abundance_min", 50)) and int(DB.item(x).get("price", 0)) > 0)
	ids.sort_custom(func(a, b): return cnt[a] > cnt[b])
	var top := mini(ids.size(), int(DB.setting("econ_abundance_top", 5)))
	var drop := float(DB.setting("econ_abundance_drop", 0.3))
	for i in top:
		# первое место — полная скидка, дальше — меньше
		abundance[ids[i]] = 1.0 - drop * (1.0 - float(i) / float(maxi(1, top)))


func price_trend(id: String) -> float:
	return price_mult.get(id, 1.0) - price_prev.get(id, 1.0)


## A-19: склад «своей базы» того, кто торгует: в комнате «свои базы» у гостя — его аванпост, иначе штаб.
func home_inv() -> Inventory:
	var N = Net._self()
	if Net.is_host() and N.actor != 0 and N.separate():
		var ob = coop.outpost_of(str(N.peers.get(N.actor, {}).get("nick", "")))
		return ob.inv if ob != null and ob.inv != null and not ob.dead else null
	return factory.hq.inv if factory.hq != null and not factory.hq.dead else null


func sell(id: String, n: int) -> void:
	var home: Inventory = home_inv()
	var in_hq: int = home.count(id) if home else 0
	var have: int = in_hq + player.inv.count(id)
	if n < 0 or n > have:
		n = have
	if n <= 0:
		return
	var total := sell_price(id) * n
	if Blocks.econ_on():
		_sell_frac += sell_value(id) * n
		total = int(floor(_sell_frac))
		_sell_frac -= total
	# сначала со склада штаба, остальное — из рюкзака
	var from_hq := mini(n, in_hq)
	if from_hq > 0:
		home.remove(id, from_hq)
	if n > from_hq:
		player.inv.remove(id, n - from_hq)
	credits += total
	var guest_id: int = Net._self().actor if Net.is_host() else 0
	if guest_id == 0 or not Net._self().own_wallets():
		earned += total   # B17-2: при своих кошельках заработок гостя — его (trade_credit)
	market_sold(id, n)
	if guest_id != 0:
		# 1.1.15: продал гость — заработок и опыт его (для задания «Заработайте»), а не хозяина
		Net._self().rpc_id(guest_id, "trade_credit", total, float(DB.data.levels.get("xp", {}).get("sell", 0.05)) * total)
	else:
		trade_earned += total
		add_xp(float(DB.data.levels.get("xp", {}).get("sell", 0.05)) * total)
		notify("Продано: %d × %s за %d кр" % [n, DB.item_name(id), total], Color(1, 0.85, 0.3))
	sfx.play_ui("coin")
	_shuttle_run()


func buy(id: String, n: int) -> void:
	var cost := buy_price(id) * n
	if credits < cost:
		return
	credits -= cost
	var home: Inventory = home_inv()
	var left: int = home.add(id, n) if home else n
	if left > 0:
		# не влезло ни в штаб, ни в рюкзак — челнок сбрасывает остаток у героя
		factory.give_player(id, left)
	sfx.play_ui("coin")
	_shuttle_run()


func _update_market(delta: float) -> void:
	market_timer -= delta
	if market_timer > 0.0:
		return
	market_timer = 30.0
	update_abundance()
	# рынок живёт: цена возвращается к обычной, давно не продававшиеся товары дорожают, плюс небольшой шум
	var rec := float(DB.setting("market_recover", 0.08))
	for id in price_mult:
		price_prev[id] = price_mult[id]
		var target := 1.0 if play_time - float(last_sold.get(id, -9999.0)) < 600.0 else 1.2
		var m: float = price_mult[id]
		m += (target - m) * rec
		price_mult[id] = clampf(m * randf_range(0.94, 1.07), 0.3, 1.7)


## Продали n штук: цена на станции падает (сколько — правило «market_sell_drop»).
func market_sold(id: String, n: int) -> void:
	var drop := float(DB.setting("market_sell_drop", 0.004))
	price_mult[id] = maxf(0.3, float(price_mult.get(id, 1.0)) * (1.0 - minf(0.6, drop * n)))
	last_sold[id] = play_time


func on_delivered(item: String) -> void:
	delivered[item] = delivered.get(item, 0) + 1


func on_wave_started(_n: int) -> void:
	factory.blocks_event("wave_start")
	quip("wave_start")


func on_wave_cleared(_n: int) -> void:
	quip("wave_done", true)


var _quip_t := -999.0
var _quip_last := {}

## 1.3: «Радио Aloverdoz» — шутка корпорации к событию (settings.quips). Не чаще раза в quip_cooldown секунд,
## с шансом quip_chance (force — всегда, но кулдаун всё равно), одна и та же реплика не повторяется подряд.
func quip(ev: String, force := false) -> void:
	var lines = DB.data.settings.get("quips", {}).get(ev, [])
	if not (lines is Array) or lines.is_empty() or flags.get("quiet", false) or not bool(Prefs.get_value("quips_on", true)):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _quip_t < float(DB.setting("quip_cooldown", 45.0)):
		return
	if not force and randf() > float(DB.setting("quip_chance", 0.7)):
		return
	var i: int = randi() % lines.size()
	if lines.size() > 1 and i == int(_quip_last.get(ev, -1)):
		i = (i + 1) % lines.size()
	_quip_last[ev] = i
	_quip_t = now
	notify("%s: %s" % [str(DB.setting("quip_name", "Радио Aloverdoz")), str(lines[i])], Color(1.0, 0.82, 0.45))


func notify(text: String, col := Color.WHITE) -> void:
	# хозяин выполняет команду за другого игрока — сообщение уходит ему
	if Net.is_host() and Net._self().actor > 1:
		Net._self().rpc_id(Net._self().actor, "toast", text, col)
		return
	hud.toast(text, col)


## Значения для своих окон интерфейса (ui.json).
func ui_values() -> Dictionary:
	return {"level": level, "skill_points": skill_points, "credits": credits, "kills": enemies.kills,
		"waves": enemies.waves_survived, "buildings": factory.all.size(), "xp_frac": xp / max(1.0, xp_next()),
		"hp": int(player.hp), "food": int(player.food), "water": int(player.water), "day": day_n,
		"profession": DB.data.professions.get(profession, {}).get("name", profession),
		"attr_points": attr_points, "wave": enemies.wave, "hp_max": int(player.maxhp),
		"hp_frac": player.hp / maxf(1.0, player.maxhp), "food_frac": player.food / 100.0, "water_frac": player.water / 100.0,
		"nests": world.nest_alive_count(), "time": "%02d:%02d" % [int(day_t * 24.0) % 24, int(fmod(day_t * 24.0, 1.0) * 60.0)]}


# ---------------------------------------------------------------- гнёзда, победа, поражение

func damage_nest(n: Dictionary, d: float) -> void:
	n.hp -= d
	n.core.scale = Vector3.ONE * 1.35
	if n.hp <= 0.0 and n.alive:
		n.alive = false
		fx.explosion(n.pos + Vector3(0, 2, 0), 4.0, Color(0.9, 0.3, 1.0))
		fx.goo(n.pos + Vector3(0, 2, 0), 4.0)
		sfx.play("boom", n.pos)
		n.core.visible = false
		n.light.visible = false
		n.node.scale = Vector3(1.0, 0.35, 1.0)
		var idx := world.nests.find(n)
		for c in world.nest_cells.keys():
			if world.nest_cells[c] == idx:
				world.nest_cells.erase(c)
		add_credits(int(DB.data.world.get("nests", {}).get("reward", 400)))
		add_xp(50)
		notify("Гнездо уничтожено!", Color(0.8, 0.5, 1))
		if world.nest_alive_count() == 0 and victory_mode() == "nests":
			win()


func on_hq_destroyed() -> void:
	game_over = true
	Net._self().hq_lost()   # 1.1.15: и у гостей — экран поражения
	hud.show_result(false)


## Для скриншотов: открыть экран паузы, сохранений, гибели, победы или поражения.
func _show_screen(id: String) -> void:
	hud.close_all()
	await get_tree().create_timer(0.3).timeout
	match id:
		"pause": hud.open("pause")
		"save": save_game("save1", true); save_game("save2", true); hud.open_saves("save")
		"load": save_game("save1", true); hud.open_saves("load")
		"death":
			DB.data.settings["death"]["respawn_time"] = 30.0
			player.damage(99999.0)
		"victory": win()
		"defeat": on_hq_destroyed()
		_:
			# окна интерфейса с типичным набором вещей
			for pair in [["log", 14], ["branch", 9], ["stone", 22], ["iron_ore", 30], ["iron_ingot", 12], ["plank", 8], ["berry", 5], ["medkit", 2], ["stone_axe", 1], ["copper_ore", 3]]:
				player.inv.add(pair[0], pair[1])
			credits = 340
			player.inv.changed.emit()
			var hq_c: Vector2i = factory.hq.cell
			match id:
				"inventory", "craft", "build", "skills", "trade":
					hud.open(id)
				"build_logistics":
					hud.build_cat = "logistics"
					hud.open("build")
				"item_info":
					hud.open("inventory")
					var ax := 0
					for k in player.inv.slots.size():
						if player.inv.slots[k] != null and player.inv.slots[k].id == "stone_axe":
							ax = k
					hud.show_item_info(player.inv, ax)
				"chest", "smelter", "inv_chest":
					var t := "smelter" if id == "smelter" else "chest"
					world.remove_node(hq_c + Vector2i(-3, 0))
					var b = factory.place(t, hq_c + Vector2i(-3, 0), 0)
					if t == "chest":
						b.inv.add("copper_ingot", 20)
						b.inv.add("gear", 6)
					else:
						b.inv.add("iron_ore", 7)
					hud.open_building(b)
					if id == "inv_chest" or id == "chest":
						hud.open("inventory")


## Условие победы — в редакторе: Главное меню и экраны → Условие победы.
func victory_mode() -> String:
	return str(DB.menu("victory", {}).get("mode", "waves"))


func win() -> void:
	if victory:
		return
	victory = true
	hud.show_result(true)


func _check_victory(delta: float) -> void:
	_victory_t += delta
	if victory or game_over or _victory_t < 1.0:
		return
	_victory_t = 0.0
	var v: Dictionary = DB.menu("victory", {})
	var n := float(v.get("value", 0))
	var done := false
	match str(v.get("mode", "waves")):
		"waves": done = n > 0 and enemies.waves_survived >= n
		"credits": done = n > 0 and earned >= n
		"day": done = n > 0 and day_n >= n
		"level": done = n > 0 and level >= n
	if done:
		win()


## Итоги игры для экрана победы и поражения.
func stats() -> Array:
	return [[DB.tx("st_time", "Время в игре"), SavesUI.time_text(play_time)], [DB.tx("st_day", "Дней прожито"), str(day_n)],
		[DB.tx("st_waves", "Волн отбито"), str(enemies.waves_survived)], [DB.tx("st_kills", "Монстров убито"), str(enemies.kills)],
		[DB.tx("st_earned", "Заработано"), "%d кр" % earned], [DB.tx("st_buildings", "Построено зданий"), str(factory.stats.placed)],
		[DB.tx("st_level", "Уровень героя"), str(level)]]


## 18: личное у игрока в сетевой игре (хозяин хранит по нику и отдаёт при повторном входе).
func personal_state() -> Dictionary:
	if split != null and split.active and split.cur != 0:
		return split.with_seat(0, personal_state)   # B-1 r9: личное — всегда за первого игрока (второй — в split2)
	var ss: Dictionary = player.saved_state()   # A-3 r8
	return {"split2": split.save_state() if split != null else {},   # B-4 r8: вещи второго игрока гостя хранит хозяин
		"pos": [ss.pos.x, ss.pos.z], "hp": ss.hp, "food": ss.food, "water": ss.water, "clothes": player.clothes,
		"inv": player.inv.to_array(), "hot_items": player.hot_items.keys().map(func(k): return [k, player.hot_items[k]]), "hot_builds": player.hot_builds.keys().map(func(k): return [k, player.hot_builds[k]]), "selected": player.selected,
		"bag": player.bag_level, "level": level, "xp": xp, "skill_points": skill_points, "skills": skills.duplicate(), "attrs": attrs.duplicate(),
		"attr_points": attr_points, "profession": profession, "scan": scanner.to_dict(), "quest_i": quest_i, "tutorial": tutorial.to_dict(),
		"craft_queue": craft_queue.duplicate(true), "effects": effects.duplicate(true), "trade_earned": trade_earned,   # 1.1.15: и это у гостя своё
		"orders": orders.to_dict(), "climate": climate.to_dict(), "marks": marks.duplicate(true), "vehicle": vehicles.to_dict(), "dose": hazards.dose if hazards else 0.0, "delivered": delivered.duplicate(), "earned": earned, "kills": enemies.kills,
		"graves": graves.map(func(g): return {"pos": [g.pos.x, g.pos.z], "inv": g.inv.to_array()})}


## 18: выход из сетевой игры: хозяин сохраняет мир комнаты, гость отправляет хозяину свои вещи и прогресс.
func net_exit() -> void:
	if not Net.active():
		return
	if Net.is_host():
		# B-5 r9: гости присылают свежие рюкзаки перед последним сохранением хозяина
		if Net._self().peers.size() > 1:
			Net._self().rpc("state_now")
			await get_tree().create_timer(1.5).timeout
		save_game("autosave", true)
	else:
		Net._self().send_my_state()
		await get_tree().create_timer(0.4).timeout
	Net._self().leave()


func quit_game() -> void:
	await net_exit()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func to_menu() -> void:
	await net_exit()
	Engine.time_scale = 1.0
	if DB.get_meta("from_editor", false) and DB.studio:
		to_editor()
		return
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


## Вернуться в редактор (если игра запущена кнопкой «Играть» или F10 в версии с редактором).
func to_editor() -> void:
	Engine.time_scale = 1.0
	DB.set_meta("from_editor", false)
	get_tree().change_scene_to_file("res://scenes/editor.tscn")


# ---------------------------------------------------------------- задачи

## Задачи берутся из данных «Задачи (обучение)»: их можно создавать, править и удалять в редакторе.
func _setup_quests() -> void:
	quests = []
	var ids: Array = DB.data.get("quests", {}).keys()
	ids.sort_custom(func(x, y):
		var ox := int(DB.data.quests[x].get("order", 0))
		var oy := int(DB.data.quests[y].get("order", 0))
		return ox < oy if ox != oy else str(x) < str(y))
	for id in ids:
		var q: Dictionary = DB.data.quests[id]
		if str(q.get("text", "")).strip_edges() == "":
			continue
		var title := DB.t(str(q.text))
		if island != null and q.get("goal","") == "have" and q.get("item","") in ["branch","log","fiber","stone"]:
			title = "Добудьте %s ×%d из морского груза" % [DB.item_name(q.item),int(q.n)]
		quests.append({"id": id, "text": title, "reward": int(q.get("reward", 0)), "goal": str(q.get("goal", "have")),
			"n": max(1, int(q.get("n", 1))), "item": str(q.get("item", "")), "buildings": q.get("buildings", []), "hint": DB.t(str(q.get("hint", "")))})


## Прогресс задачи: [сколько есть, сколько нужно].
func quest_progress(q: Dictionary) -> Array:
	var n: int = q.n
	var cur := 0
	match q.goal:
		"have":
			var it: String = q.item
			var qh: Inventory = _quest_home()
			cur = player.inv.count(it) + (qh.count(it) if qh else 0)
		"build":
			for t in q.buildings:
				cur += _count(str(t))
		"build_each":
			# каждый вид здания — отдельная галочка
			var done := 0
			for t in q.buildings:
				if _count(str(t)) >= n:
					done += 1
			return [done, max(1, q.buildings.size())]
		"delivered":
			cur = int(delivered.get(q.item, 0)) if q.item != "" else _delivered_total()
		"skills":
			cur = _skill_sum()
		"tech":
			if not tech.enabled():
				return [n, n]
			if str(q.get("item", "")) != "":
				# 1.5: открыть конкретный узел
				return [1 if tech.done.has(str(q.item)) else 0, 1]
			for id in tech.done:
				if not bool(tech.nodes().get(id, {}).get("start", false)):
					cur += 1
		"trade":
			cur = trade_earned
		"scan":
			# изучить предмет (или любые N предметов, если предмет не указан)
			if not DB.discovery:
				return [n, n]
			if str(q.get("item", "")) != "":
				return [1 if DB.is_researched(str(q.item)) else 0, 1]
			cur = scanner.researched_count()
		"waves":
			cur = enemies.waves_survived
		"nests":
			cur = world.nests.size() - world.nest_alive_count()
		"victory":
			return [1 if victory else 0, 1]
		"level":
			cur = level
		"credits":
			cur = credits
	return [mini(cur, n), n]


func quest_done(q: Dictionary) -> bool:
	var p := quest_progress(q)
	return p[0] >= p[1]


func _has(id: String, n: int) -> bool:
	return player.inv.count(id) + (factory.hq.inv.count(id) if factory.hq else 0) >= n


func _count(t: String) -> int:
	var k := 0
	var mine := _own_bases_nick()
	for b in factory.all:
		if mine != "" and str(b.bstate.get("owner", "")) != mine:
			continue
		# A16-4: объединённое здание уровня N — это N построенных, встроенные тоже считаются
		if b.type == t:
			k += maxi(1, int(b.lvl))
		for sb in b.subs:
			if sb.type == t:
				k += maxi(1, int(sb.lvl))
	return k


## B-5 r3: в комнате «свои базы» задания гостя считаются по его зданиям и складу его аванпоста.
func _own_bases_nick() -> String:
	if Net.active() and Net._self().separate():
		return Net._self().nick
	return ""


## B-2 r5: засчитывать ли доставку в это здание мне: в «своих базах» гостю — только свой аванпост, хозяину — штаб.
func counts_delivery(t) -> bool:
	var mine := _own_bases_nick()
	if mine != "" and Net.is_client():
		return t.type == "outpost" and coop != null and coop.owner_of(t) == mine
	return t.beh == "hq"


func _quest_home() -> Inventory:
	var mine := _own_bases_nick()
	if mine != "" and Net.is_client():
		var ob = coop.outpost_of(mine)
		return ob.inv if ob != null and ob.inv != null else null
	return factory.hq.inv if factory.hq else null


func _delivered_total() -> int:
	var s := 0
	for k in delivered:
		s += delivered[k]
	return s


func _skill_sum() -> int:
	var s := 0
	for k in skills:
		s += skills[k]
	return s


var _quest_acc := 0.0

func _check_quests() -> void:
	_quest_acc += get_process_delta_time()
	if _quest_acc < 0.5 or quest_i >= quests.size():
		return
	_quest_acc = 0.0
	var q: Dictionary = quests[quest_i]
	if quest_done(q):
		quest_i += 1
		if q.reward > 0:
			if Net.is_client():
				Net._self().quest_reward(int(q.reward))   # 1.7: деньги гостя считает хозяин (иначе награда терялась)
			else:
				add_credits(q.reward, false)
		notify(DB.tx("quest_done", "Задача выполнена!") + (" +%d кр" % q.reward if q.reward > 0 else ""), Color(0.5, 1, 0.6))
		celebrate(DB.tx("quest_done_big", "ЗАДАЧА ВЫПОЛНЕНА"), str(q.text) + ("  +%d кр" % q.reward if q.reward > 0 else ""), Color(0.55, 1.0, 0.6))
		quip("quest_done")
		sfx.play_ui("victory")
		add_xp(10)


func quest_text() -> String:
	if island != null:
		var text: String = "[color=#ffcc66]ДАР КО ДНЮ %d[/color]" % island.due
		for id in island.request:
			text += "\n%s   %d / %d" % [DB.item_name(id),island.paid.get(id,0),island.request[id]]
		return text+"\n[color=#91c7be]"+("Дар принят" if island.complete() else "E у плиты · передать припасы")+"[/color]"
	var s := ""
	for i in quests.size():
		if i < quest_i - 1 or i > quest_i + 2:
			continue
		var q: Dictionary = quests[i]
		if i < quest_i:
			s += "[color=#6a7]✓ %s[/color]\n" % q.text
		elif i == quest_i:
			var p := quest_progress(q)
			var prog := ""
			if p[1] > 1 or q.goal in ["have", "build"]:
				prog = "  [color=#%s](%d/%d)[/color]" % ["8f8" if p[0] >= p[1] else "fff", p[0], p[1]]
			s += "[color=#ffcc66]▶ %s[/color]%s%s\n" % [q.text, prog, ("  [color=#aaa](+%d кр)[/color]" % q.reward) if q.reward > 0 else ""]
		else:
			s += "[color=#778]• %s[/color]\n" % q.text
	if quest_i >= quests.size():
		s += "[color=#6f6]%s[/color]" % DB.tx("quests_all_done", "Все задачи выполнены!")
	return s.strip_edges()


## Подсказка к текущей задаче (при наведении на список задач).
func quest_hint() -> String:
	if island != null: return island.description()+"\nE у плиты — передать материалы или насыпать клетку."
	if quest_i >= quests.size():
		return ""
	var q: Dictionary = quests[quest_i]
	var p := quest_progress(q)
	var s: String = q.text
	if q.item != "" and q.goal in ["have", "delivered"]:
		s += "\n%s: %s — %d/%d" % [DB.tx("need", "Нужно"), DB.item_name(q.item), p[0], p[1]]
	if q.hint != "":
		s += "\n" + q.hint
	return s


# ---------------------------------------------------------------- сохранение

## Снимок экрана в папку screenshots рядом с сохранениями.
func take_photo() -> String:
	var dir := DB.saves_dir().get_base_dir().path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var p := dir.path_join("photo_%s.png" % Time.get_datetime_string_from_system().replace(":", "-"))
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(p)
	return p


func save_game(slot := "save1", quiet := false) -> void:
	if Net.is_client():
		# 18: гость не хранит мир — но его рюкзак, уровень и навыки уходят хозяину, мир сохраняет хозяин
		Net._self().send_my_state()
		if not quiet:
			notify("Мир сохраняет хозяин комнаты. Ваши вещи, уровень и навыки отправлены ему и сохранятся вместе с миром", Color(0.7, 0.85, 1))
		return
	# 18: у хозяина автосохранение пишется в ячейку комнаты (net_<комната>) — её видно в «Загрузить» и при создании комнаты
	if Net.is_host() and slot == "autosave":
		slot = Net._self().room_slot()
	var data := save_dict()
	DB.write_failed = ""
	DB.write_file(DB.saves_dir().path_join("%s.json" % slot), data)
	if DB.write_failed != "":
		# B-1 r7: прежнее сохранение цело, новое не записалось
		notify("Не удалось сохранить игру — не хватает места на диске? Прежнее сохранение не тронуто", Color(1, 0.45, 0.35))
		return
	var meta := {"saved_at": data.saved_at, "play_time": play_time, "day": day_n,
		"level": level, "credits": credits, "profession": profession, "game": DB.game_name(), "version": DB.game_version()}
	if Net.is_host():
		meta["room"] = str(Net._self().room.get("name", ""))
		meta["players"] = Net._self().players_save().keys()
	DB.write_file(DB.saves_dir().path_join("%s.meta.json" % slot), meta)
	if not quiet:
		notify("Игра сохранена", Color(0.6, 1, 0.7))


## Весь мир одним словарём: для сохранения и для игрока, который подключается к сетевой игре.
func save_dict() -> Dictionary:
	if split != null and split.active and split.cur != 0:
		return split.with_seat(0, save_dict)   # сохраняется первый герой; вещи второго — отдельно
	var blds := dormant_caves.duplicate(true)
	factory.sync_fluids()
	for b in factory.all:
		var e := {"t": b.type, "c": [b.cell.x, b.cell.y], "d": b.dir, "hp": b.hp, "r": b.recipe, "it": b.item}
		if b.famt > 0.0:
			e["fl"] = [b.fluid, snappedf(b.famt, 0.01)]
		if not b.cfg.is_empty():
			e["cfg"] = b.cfg.duplicate(true)
		for k in ["inv", "out", "fuel"]:
			var inv: Inventory = b.get(k)
			if inv != null:
				e[k] = inv.to_array()
		if b.fuel_t > 0.0:
			e["fuel_t"] = b.fuel_t
		if b.energy > 0.0:
			e["energy"] = b.energy
		if b.crafting != "":
			e["crafting"] = b.crafting
			e["prog"] = b.prog
			e["timer"] = b.timer
		if not b.bstate.is_empty():
			e["bstate"] = b.bstate.duplicate(true)
		if b.paid is Dictionary:
			e["paid"] = b.paid
		if b.tripped:
			e["tripped"] = true
		if b.lvl > 1:
			e["lvl"] = b.lvl
		if not b.subs.is_empty():
			e["subs"] = factory.fz.save_subs(b)
			e["cen"] = b.cen
		blds.append(e)
	var wire_list := []
	for l in factory.links:
		wire_list.append([l[0].cell.x, l[0].cell.y, l[1].cell.x, l[1].cell.y])
	var node_hp := []
	for c in world.nodes:
		var n = world.nodes[c]
		if n.hp < n.maxhp:
			node_hp.append([c.x, c.y, n.hp])
	var data := {"version": DB.game_version(), "game": DB.game_name(), "map": world.to_map(), "buildings": blds, "carriers": carriers.save_flights(), "camera_mode": "strategy" if strategy else ("first" if first_person else "third"), "explorer_anchor": explorer_anchor, "layout_version":layout_version, "broadcast_cursor":hud.broadcast.cursor if hud and hud.broadcast else -1, "camera_zoom":[strategy_zoom if not strategy else cam_dist_target, explorer_zoom if strategy or first_person else cam_dist_target],
		"saved_at": Time.get_datetime_string_from_system(false, true), "play_time": play_time,
		"player": {"pos": [player.saved_state().pos.x, player.saved_state().pos.z], "elevation": player.saved_state().pos.y, "hp": player.saved_state().hp, "food": player.saved_state().food, "water": player.saved_state().water, "clothes": player.clothes, "inv": player.inv.to_array(),
			"hot_items": player.hot_items.keys().map(func(k): return [k, player.hot_items[k]]), "hot_builds": player.hot_builds.keys().map(func(k): return [k, player.hot_builds[k]]), "selected": player.selected, "bag": player.bag_level},
		"credits": credits, "sink_points_total": sink_points_total, "level": level, "xp": xp, "skill_points": skill_points, "skills": skills, "profession": profession, "difficulty": difficulty,
		"attrs": attrs, "attr_points": attr_points, "graves": graves.map(func(g): return {"pos": [g.pos.x, g.pos.z], "inv": g.inv.to_array()}),
		"day_t": day_t, "day_n": day_n, "wave": enemies.wave, "wave_timer": enemies.wave_timer, "wave_live": enemies.wave_live, "game_over": game_over, "rush_n": enemies.rush_n, "rush_timer": enemies.rush_timer, "quest_i": quest_i,
		"kills": enemies.kills, "waves_survived": enemies.waves_survived, "earned": earned, "trade_earned": trade_earned,
		"delivered": delivered, "effects": effects, "price_mult": price_mult, "price_prev": price_prev, "victory": victory,
		"craft_queue": craft_queue, "marks": marks, "tech": tech.to_dict(), "progress17": progress17.to_dict(), "builders18": builders.to_dict(), "events": events.to_dict(), "vehicle": vehicles.to_dict(), "npcs": npcs.to_dict(), "orders": orders.to_dict(), "sieges": sieges.save(), "fog": fog.to_dict(), "zone": zone.to_dict(), "tutorial": tutorial.to_dict(), "drones": drones.to_list(), "scan": scanner.to_dict(), "dungeons": dungeons.to_dict(), "climate": climate.to_dict(), "quantum": quantum.to_dict(), "rules_ov": rules_ov, "big": bool(DB.setting("big_buildings", true)) and DB.building("smelter").get("size", 1) > 1, "dep_fit": World.dep_fit, "ports19": Factory.ports_on(), "dep118": dep118, "big13": true, "hazards": hazards.to_dict(), "last_sold": last_sold, "node_hp": node_hp, "modules": ng_modules, "wires": wire_list,
		"respawns": world.respawns.map(func(r): return [r.res, r.cell.x, r.cell.y, r.t] + ([r.over] if r.has("over") else [])),
		"drops": drops.list.map(func(d): return [d.id, d.n, d.pos.x, d.pos.y, d.pos.z] + ([d.slot] if not d.slot.is_empty() else [])),   # A-12 r5: износ/свежесть
		"nests_dead": world.nests.filter(func(n): return not n.alive).map(func(n): return world.nests.find(n)),
		"nest_guards": _nest_guards_save()}
	if island != null:
		data["ocean_island"] = island.state().merged({"drift":island.fishing.records()})
	if Net.is_host():
		data["net_players"] = Net.players_save()
	if split != null:
		var s2: Dictionary = split.save_state()   # A-8 r5: и вещи, ждущие второго игрока
		if not s2.is_empty():
			data["split2"] = s2
	return data


func load_game(data: Dictionary) -> void:
	if data.has("camera_mode"):
		strategy = data.camera_mode == "strategy"
		first_person = data.camera_mode == "first"
		Inventory.no_personal = strategy
		player.visible = not strategy and not first_person
		if strategy and strat.layer == null and not Net.dedicated:
			strat.make_overlay()
	explorer_anchor = data.get("explorer_anchor", {})
	var zoom: Array = data.get("camera_zoom", [34.0, 9.0])
	if zoom.size() == 2:
		strategy_zoom = clampf(float(zoom[0]), 12.0, cam_max)
		explorer_zoom = clampf(float(zoom[1]), 6.0, 24.0)
		cam_dist_target = strategy_zoom if strategy else explorer_zoom
		cam_dist = cam_dist_target
	if hud and hud.broadcast:
		hud.broadcast.cursor = clampi(int(data.get("broadcast_cursor",-1)),-1,4999)
	dormant_caves.clear()
	# сначала то, от чего зависят здания (бонусы навыков и профессии к прочности)
	if DB.data.professions.has(str(data.get("profession", ""))):
		profession = str(data.profession)
	difficulty = float(data.get("difficulty", difficulty))
	level = int(data.get("level", 1))
	xp = float(data.get("xp", 0))
	skill_points = int(data.get("skill_points", 0))
	for k in data.get("skills", {}):
		skills[k] = int(data.skills[k])
	attr_points = int(data.get("attr_points", 0))
	for k in data.get("attrs", {}):
		attrs[k] = int(data.attrs[k])
	marks = data.get("marks", [])
	if data.get("net_players") is Dictionary and Net.is_host():
		Net._self().players_load(data.net_players)
	if data.get("progress17") is Dictionary:
		progress17.from_dict(data.progress17)
	if data.get("builders18") is Dictionary:
		builders.from_dict(data.builders18)
	if data.get("tech") is Dictionary:
		tech.from_dict(data.tech)
	else:
		tech.unlock_all()   # старое сохранение — всё уже открыто
	world.reveal_deposits()
	if data.has("big") and factory.all.size() <= 1:
		layout_version = int(data.get("layout_version",1))
		_apply_sizes(bool(data.big), bool(data.get("big13", false)))   # 21: размеры зданий как у того, кто сохранил мир (хозяин сетевой игры)
	factory.loading = true
	for b in data.get("buildings", []):
		var t: String = b.t
		if t == "ruin_arch" and b.get("bstate", {}).has("cave_type") and not DB.setting("cave_expeditions_enabled", false):
			dormant_caves.append(b.duplicate(true))
			continue
		if DB.building(t).is_empty():
			continue
		var cell := Vector2i(int(b.c[0]), int(b.c[1]))
		var nb = factory.building_at(cell) if t == "hq" else null
		if nb == null or nb.type != t:
			if factory.can_place(t, cell) != "" and factory.building_at(cell) != null:
				continue
			nb = factory.place(t, cell, int(b.d))
		nb.hp = minf(float(b.get("hp", nb.maxhp)), nb.maxhp)
		nb.recipe = b.get("r", nb.recipe)
		nb.cfg = b.get("cfg", {})
		for k in ["inv", "out", "fuel"]:
			var inv: Inventory = nb.get(k)
			if inv != null and b.has(k):
				inv.from_array(b[k])
		nb.fuel_t = float(b.get("fuel_t", 0.0))
		nb.energy = float(b.get("energy", 0.0))
		nb.crafting = str(b.get("crafting", ""))
		nb.prog = float(b.get("prog", 0.0))
		nb.timer = float(b.get("timer", 0.0))
		if b.has("bstate"):
			nb.bstate = b.bstate
			if nb.beh == "belt" and nb.bstate.get("rails", false):
				factory.set_rails(nb, true)
		nb.tripped = bool(b.get("tripped", false))
		if b.has("fl") and DB.data.items.has(str(b.fl[0])):
			nb.fluid = str(b.fl[0])
			nb.famt = float(b.fl[1])
			factory.fluid_dirty = true
		if b.get("paid") is Dictionary:
			var pd := {}
			for k in b.paid:
				pd[k] = int(b.paid[k])
			nb.paid = pd
		if int(b.get("lvl", 1)) > 1:
			factory.fz.set_level(nb, int(b.lvl))
			nb.hp = minf(float(b.get("hp", nb.maxhp)), nb.maxhp)
		if b.get("subs") is Array and not b.subs.is_empty():
			factory.fz.load_subs(nb, b.subs)
			nb.cen = float(b.get("cen", 0.0))
		var it := str(b.get("it", ""))
		if it != "" and nb.item == "" and nb.beh in ["belt", "splitter", "merger"] and DB.data.items.has(it):
			factory.set_item(nb, it)
		if nb.hp < nb.maxhp:
			factory.damaged[nb] = true   # B-14: после загрузки повреждённые снова чинятся (авторемонт, роботы)
		factory._tint(nb)
		if island != null and nb.type == "campfire" and nb.bstate.get("extinguished",false):
			island.fire_visual(nb,false)
	factory.loading = false
	carriers.restore_flights(data.get("carriers", []))
	# провода: в старых сохранениях их нет — подключаем всё само
	factory.links.clear()
	if data.has("wires"):
		for w in data.wires:
			var wa = factory.building_at(Vector2i(int(w[0]), int(w[1])))
			var wb = factory.building_at(Vector2i(int(w[2]), int(w[3])))
			if wa != null and wb != null and wa != wb and not factory.wired_to(wa, wb):
				factory.links.append([wa, wb])
	elif factory.wired():
		factory.auto_wire_all()
	factory.power_dirty = true
	var p: Dictionary = data.get("player", {})
	var pp: Array = p.get("pos", [0, 0])
	player.position = Vector3(float(pp[0]), 0, float(pp[1]))
	player.position.y = float(p.get("elevation",player.support(player.position)))
	player.hp = float(p.get("hp", player.maxhp))
	if player.hp <= 0.0:
		player.hp = player.maxhp   # A-3 r8: старое сохранение погибшего героя
	player.food = float(p.get("food", 100))
	player.water = float(p.get("water", 100))
	player.clothes = str(p.get("clothes", ""))
	player.bag_level = int(p.get("bag", 0))
	player.apply_bag()
	player.inv.from_array(p.get("inv", []))
	player.hot_builds.clear()
	for e in p.get("hot_builds", []):
		if DB.building(str(e[1])).size() > 0:
			player.hot_builds[int(e[0])] = str(e[1])
	player.hot_items.clear()
	if p.has("hot_items"):
		for pair in p.hot_items:
			if pair is Array and pair.size() == 2 and player.inv.count(str(pair[1])) > 0:
				player.pin_item(int(pair[0]), str(pair[1]))
	else:
		player.seed_hotbar()
	player.selected = clampi(int(p.get("selected", 0)), 0, Player.hot_n() - 1)
	credits = int(data.get("credits", 100))
	sink_points_total = int(data.get("sink_points_total", 0))
	for g in data.get("graves", []):
		var gi := Inventory.new(int(g.inv.size()))
		gi.from_array(g.inv)
		add_grave(Vector3(float(g.pos[0]), 0, float(g.pos[1])), gi)
	day_t = float(data.get("day_t", 0.3))
	day_n = int(data.get("day_n", 1))
	events.last_day = day_n
	if data.get("events") is Dictionary:
		events.load_dict(data.events)
	if data.get("vehicle") is Dictionary:
		vehicles.load_dict(data.vehicle)
	if data.get("npcs") is Dictionary:
		npcs.load_dict(data.npcs)
	if data.get("orders") is Dictionary:
		orders.load_dict(data.orders)
	if data.get("sieges") is Dictionary:
		sieges.load_from(data.sieges)
	if data.get("climate") is Dictionary:
		climate.from_dict(data.climate)
	if data.has("quantum"):
		quantum.from_dict(data.quantum)
	quantum.after_load()
	if data.get("hazards") is Dictionary:
		hazards.from_dict(data.hazards)
	if data.get("dungeons") is Array:
		dungeons.from_dict(data.dungeons)
	if data.get("scan") is Dictionary:
		scanner.from_dict(data.scan)
	elif DB.discovery:
		# старое сохранение: всё, что есть в игре, уже изучено
		for id in DB.data.items:
			DB.known[id] = true
			DB.researched[id] = true
	tutorial.load_dict(data.get("tutorial"))
	drones.load_list(data.get("drones"))
	if data.get("zone") is Dictionary:
		zone.setup(factory.hq.center() if factory.hq else World.cell_to_world(world.center))
		zone.from_dict(data.zone)
	else:
		# старое сохранение (до зоны): открыто всё, что можно
		zone.setup(factory.hq.center() if factory.hq else World.cell_to_world(world.center))
		zone.set_blocks(zone.max_blocks())
	if data.get("fog") is Dictionary and not data.fog.is_empty():
		fog.from_dict(data.fog)
	else:
		# старое сохранение: открыта база и округа
		for b in factory.all:
			if b.beh != "belt":
				fog.reveal(b.center(), 40.0)
	if data.get("last_sold") is Dictionary:
		last_sold = data.last_sold.duplicate()
	play_time = float(data.get("play_time", 0.0))
	enemies.wave = int(data.get("wave", 0))
	enemies.wave_timer = float(data.get("wave_timer", 300))
	if int(data.get("wave_live", 0)) > 0 and enemies.wave > 0:
		# B-15: сохранились посреди волны — монстры не сохраняются, поэтому эта волна придёт заново через 15 с
		enemies.wave -= 1
		enemies.wave_timer = minf(enemies.wave_timer, 15.0)
	enemies.rush_n = int(data.get("rush_n", 0))
	game_over = bool(data.get("game_over", false))
	if game_over and factory.hq != null:
		factory.hq.hp = 0.0
		if not Net._self().dedicated:
			hud.show_result.call_deferred(false)
	if split != null:
		split.load_state(data.get("split2", {}))
	enemies.rush_timer = float(data.get("rush_timer", -1.0))
	enemies.kills = int(data.get("kills", 0))
	enemies.waves_survived = int(data.get("waves_survived", 0))
	earned = int(data.get("earned", 0))
	trade_earned = int(data.get("trade_earned", 0))
	victory = bool(data.get("victory", false))
	quest_i = int(data.get("quest_i", 0))
	var dl = data.get("delivered", {})
	for k in dl:
		delivered[k] = int(dl[k])
	var ef = data.get("effects", {})
	for k in ef:
		effects[k] = ef[k]
	for k in data.get("price_mult", {}):
		price_mult[k] = float(data.price_mult[k])
	for k in data.get("price_prev", {}):
		price_prev[k] = float(data.price_prev[k])
	for q in data.get("craft_queue", []):
		if DB.data.recipes.has(str(q.get("rid", ""))):
			craft_queue.append({"rid": str(q.rid), "t": float(q.get("t", 0.0)), "station": str(q.get("station", "hand")), "seat": int(q.get("seat", 0))})   # A-5 r9
	for e in data.get("node_hp", []):
		var n = world.nodes.get(Vector2i(int(e[0]), int(e[1])))
		if n != null:
			n.hp = float(e[2])
	for r in data.get("respawns", []):
		var rr := {"res": str(r[0]), "cell": Vector2i(int(r[1]), int(r[2])), "t": float(r[3])}
		if r.size() > 4:
			rr["over"] = str(r[4])
		world.respawns.append(rr)
	for d in data.get("drops", []):
		drops._spawn_real(str(d[0]), int(d[1]), Vector3(float(d[2]), float(d[3]), float(d[4])))
		if d.size() > 5 and d[5] is Dictionary:
			drops.list[-1].slot = d[5]
	for i in data.get("nests_dead", []):
		if int(i) < world.nests.size():
			kill_nest_silent(world.nests[int(i)])
	var ng = data.get("nest_guards", {})
	if ng is Dictionary:
		for k in ng:
			if int(k) >= 0 and int(k) < world.nests.size() and ng[k] is Array:
				world.nests[int(k)]["left"] = ng[k]
	_migrate_turrets_115(str(data.get("version", "")))


## 1.1.15: турели из старых сохранений — магазин пустой, а патроны лежат в штабе. Заряжаем из штаба и предупреждаем.
func _migrate_turrets_115(ver: String) -> void:
	if not Factory.local_ammo() or factory.hq == null or Net.is_client():
		return
	var p := ver.split(".")
	var old := p.size() >= 3 and (int(p[0]) < 1 or (int(p[0]) == 1 and (int(p[1]) < 1 or (int(p[1]) == 1 and int(p[2]) < 15))))
	if not old:
		return
	var n := 0
	for b in factory.turrets:
		if b.dead or b.inv == null:
			continue
		var ammo := str(b.p("ammo", ""))
		var take: int = mini(factory.hq.inv.count(ammo), int(DB.stack_of(ammo)) * int(b.inv.slots.size()) - b.inv.count(ammo))
		if take > 0:
			factory.hq.inv.remove(ammo, take)
			b.inv.add(ammo, take)
			n += 1
	if not factory.turrets.is_empty():
		notify("Версия 1.1.15: турели берут патроны не из штаба, а из своего магазина (лента, канал штаба или руками) и требуют энергию. Заряжено из штаба: %d турелей." % n, Color(1, 0.8, 0.3))


var _autosave_t := 0.0


func _autosave(delta: float) -> void:
	var every := float(Prefs.get_value("autosave_min", 5)) * 60.0
	if every <= 0.0 or not player.alive:
		return
	_autosave_t += delta
	if _autosave_t >= every:
		_autosave_t = 0.0
		save_game("autosave", true)
		notify("Автосохранение", Color(0.6, 0.8, 1.0))


## Гнездо, уничтоженное раньше (при загрузке): без награды и без экрана победы.
func kill_nest_silent(n: Dictionary) -> void:
	n.alive = false
	n.hp = 0.0
	n.core.visible = false
	n.light.visible = false
	n.node.scale = Vector3(1.0, 0.35, 1.0)
	var idx := world.nests.find(n)
	for c in world.nest_cells.keys():
		if world.nest_cells[c] == idx:
			world.nest_cells.erase(c)


# ---------------------------------------------------------------- челнок станции

func _make_shuttle() -> void:
	shuttle = Node3D.new()
	add_child(shuttle)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.85, 0.87, 0.9)
	white.metallic = 0.6
	white.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.16, 0.2)
	dark.metallic = 0.7
	dark.roughness = 0.3
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.4, 0.8, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.4, 0.8, 1.0)
	glow.emission_energy_multiplier = 4.0
	var engine := StandardMaterial3D.new()
	engine.albedo_color = Color(1.0, 0.6, 0.2)
	engine.emission_enabled = true
	engine.emission = Color(1.0, 0.55, 0.15)
	engine.emission_energy_multiplier = 6.0
	for p in [[Vector3(4.2, 1.2, 2.0), white, Vector3(0, 0, 0), "box"],
			[Vector3(1.2, 0.6, 1.4), glow, Vector3(1.9, 0.3, 0), "box"],
			[Vector3(2.2, 0.2, 5.5), dark, Vector3(-0.5, -0.1, 0), "box"],
			[Vector3(1.0, 1.0, 0.2), white, Vector3(-1.8, 0.9, 0), "box"],
			[Vector3(0.9, 0.8, 0.9), engine, Vector3(-2.3, 0, 0.6), "cylinder"],
			[Vector3(0.9, 0.8, 0.9), engine, Vector3(-2.3, 0, -0.6), "cylinder"]]:
		var mi := MeshInstance3D.new()
		mi.mesh = ModelLib.unit_mesh(p[3])
		mi.material_override = p[1]
		mi.position = p[2]
		mi.scale = p[0]
		if p[1] == engine:
			mi.rotation.z = PI / 2
		shuttle.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 3.0
	l.omni_range = 14.0
	l.position = Vector3(-3, 0, 0)
	shuttle.add_child(l)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.35)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shuttle_beam = MeshInstance3D.new()
	shuttle_beam.mesh = ModelLib.unit_mesh("cylinder", 0.55, 16)
	shuttle_beam.scale = Vector3(3.2, 6.0, 3.2)
	shuttle_beam.material_override = beam_mat
	shuttle_beam.position = Vector3(0, -3.6, 0)
	shuttle_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shuttle_beam.visible = false
	shuttle.add_child(shuttle_beam)
	shuttle.visible = false


func _shuttle_run() -> void:
	if shuttle_busy or factory.hq == null:
		return
	shuttle_busy = true
	var hq: Vector3 = factory.hq.center()
	var hover := hq + Vector3(0, 11.5, 0)
	shuttle.position = hq + Vector3(-120, 90, 60)
	shuttle.look_at(hover, Vector3.UP)
	shuttle.rotate_object_local(Vector3.UP, PI / 2)
	shuttle.visible = true
	sfx.play("shuttle", hover)
	var tw := create_tween()
	tw.tween_property(shuttle, "position", hover, 3.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): shuttle_beam.visible = true)
	tw.tween_interval(1.8)
	tw.tween_callback(func(): shuttle_beam.visible = false)
	tw.tween_property(shuttle, "position", hover + Vector3(140, 110, -40), 3.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		shuttle.visible = false
		shuttle_busy = false)



## Сила ветра 0..1: плавно меняется со временем (ветряки). Правила игры: «Ветер от/до», «Как быстро меняется ветер».
var _wind_noise: FastNoiseLite
func wind() -> float:
	if _wind_noise == null:
		_wind_noise = FastNoiseLite.new()
		_wind_noise.seed = world.used_seed + 77
		_wind_noise.frequency = 0.01
	var a := float(DB.setting("wind_min", 0.2))
	var b := float(DB.setting("wind_max", 1.0))
	var sp := float(DB.setting("wind_change", 1.0))
	var v := _wind_noise.get_noise_1d(play_time * sp) * 0.5 + 0.5
	var w := lerpf(a, b, smoothstep(0.15, 0.85, v))
	if events:
		w = lerpf(w, 1.0, events.storm * 0.8)   # в бурю ветряки крутятся во всю силу
	return clampf(w, 0.0, 1.0)


## Сколько света получают солнечные панели (ночью 0, в бурю меньше).
func sun_power() -> float:
	var s := daylight()
	if events:
		s *= (1.0 - events.storm * 0.7) * (1.0 - events.dark * 0.9) * (1.0 - events.rain * 0.3)
	return s



# ---------------------------------------------------------------- провода
func _wire_release() -> void:
	var b = wire_pick()
	if b == null or b == wire_from:
		return   # отпустили на том же здании — ждём щелчка по второму
	var a = wire_from
	if cmd("wire", {"a": a, "b": b}) == true:
		notify(DB.t(DB.tx("w_done", "Подключено: {a} — {b}"), {"a": DB.building(a.type).get("name", a.type), "b": DB.building(b.type).get("name", b.type)}), Color(0.5, 1.0, 0.6))
		sfx.play_ui("coin")
		wire_flash = 0.6
		wire_flash_b = [a, b]
	wire_from = null


## 14.10: здание под мышью для проводов — с запасом вокруг (не надо попадать точно в клетку).
## Берётся ближайшее здание, которому нужна энергия, в радиусе «Провода: запас наведения».
func wire_pick():
	var snap := float(DB.setting("wire_snap", 2.5))
	var best = null
	var bd := INF
	var r := int(ceil(snap / C)) + 2
	var seen := {}
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var b = factory.building_at(World.wc(hover_cell + Vector2i(dx, dz)))
			if b == null or seen.has(b) or not factory.is_electric(b):
				continue
			seen[b] = true
			var d: float = maxf(0.0, World.dist(b.center(), hover_point) - b.size * C * 0.5)
			if d <= snap and d < bd:
				bd = d
				best = b
	return best


var wire_hl: Node3D
var wire_flash := 0.0
var wire_flash_b: Array = []
var _hl_pool: Array = []


func _hl_box(i: int) -> MeshInstance3D:
	while _hl_pool.size() <= i:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_mirror", true)
		wire_hl.add_child(mi)
		_hl_pool.append(mi)
	return _hl_pool[i]


## Подсветка для проводов: откуда тянем (жёлтое), куда (зелёное — можно, красное — нельзя),
## и все здания, к которым можно дотянуть провод (слабое зелёное).
func _update_wire_hl(delta: float) -> void:
	if wire_hl == null:
		wire_hl = Node3D.new()
		add_child(wire_hl)
	var n := 0
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	var marks := []   # [здание, цвет, высота]
	wire_flash = maxf(0.0, wire_flash - delta)
	if wire_flash > 0.0:
		for fb in wire_flash_b:
			if fb != null and not fb.dead:
				marks.append([fb, Color(0.4, 1.0, 0.5, 0.55 * wire_flash / 0.6), 3.2])
	if field_selection >= 0 and not _ui_hovered():
		var span := maxi(1, world.dep_fp(world.deposits[field_selection]))
		var good := world.order_issue(field_selection, hover_cell) == ""
		for cell in world.field_cells(hover_cell, span):
			var mi := _hl_box(n)
			n += 1
			mi.visible = true
			mi.scale = Vector3(C * 0.95, 0.04, C * 0.95)
			mi.position = World.cell_to_world(cell)
			mi.position.y = world.height_at(mi.position) + 0.15
			(mi.material_override as StandardMaterial3D).albedo_color = Color(0.25, 0.9, 0.8, 0.40) if good else Color(1.0, 0.31, 0.23, 0.42)
	if zone_pick and island != null:
		var mark := _hl_box(n)
		n += 1
		mark.show()
		mark.scale = Vector3(1.95,.075,1.95)
		mark.position = World.cell_to_world(hover_cell)+Vector3.UP*(.82 if world.island_cells.has(hover_cell) else .27)
		mark.material_override.albedo_color = Color(.2,.85,.65,.62) if island.issue(hover_cell)=="" else Color(.88,.34,.18,.52)
	elif zone_pick:
		var zrc: Vector2i = zone.patch_at(hover_point)
		zone.show_pick(zrc, zone.patch_can(zrc) == "")
	if wiring and not (hud.any_window_open() and _ui_hovered()):
		var hb = wire_pick()
		if wire_from != null and not wire_from.dead:
			marks.append([wire_from, Color(1.0, 0.85, 0.2, 0.35 + 0.25 * pulse), 3.4])
			if bool(DB.setting("wire_show_targets", true)):
				var k := 0
				for o in factory.all:
					if k >= 40:
						break
					if o == wire_from or o == hb or o.dead or not factory.is_electric(o):
						continue
					if factory.wire_dist(wire_from, o) <= factory.wire_len() and factory.wire_why(wire_from, o) == "":
						marks.append([o, Color(0.4, 1.0, 0.5, 0.16), 0.25])
						k += 1
			if hb != null and hb != wire_from:
				var ok: bool = factory.wire_why(wire_from, hb) == ""
				marks.append([hb, Color(0.4, 1.0, 0.5, 0.45 + 0.2 * pulse) if ok else Color(1.0, 0.35, 0.3, 0.45 + 0.2 * pulse), 3.4])
		elif hb != null:
			marks.append([hb, Color(1.0, 0.95, 0.6, 0.3 + 0.2 * pulse), 3.4])
	for mk in marks:
		var b = mk[0]
		var mi := _hl_box(n)
		n += 1
		mi.visible = true
		var w: float = b.size * C + 0.3
		var h: float = mk[2]
		mi.scale = Vector3(w, h, w)
		mi.position = b.center() + Vector3(0, h * 0.5, 0)
		(mi.material_override as StandardMaterial3D).albedo_color = mk[1]
	for i in range(n, _hl_pool.size()):
		_hl_pool[i].visible = false


## 1.3: бур и насос крупнее клетки сами встают ровно по центру ближайшей залежи под курсором
## (раньше угол здания шёл за курсором, и бур стоял на залежи одной ножкой). null — не прилипать.
func _miner_snap():
	if build_type == "" or world == null or str(DB.building(build_type).get("behavior", "")) != "miner":
		return null
	var s := int(DB.building(build_type).get("size", 1))
	if s <= 1:
		return null
	var best = null
	var bd := INF
	for dx in range(-s, s + 1):
		for dz in range(-s, s + 1):
			var c := World.wc(hover_cell + Vector2i(dx, dz))
			if not world.deposit.has(c):
				continue
			var idx: int = world.deposit[c]
			if world.dep_fp(world.deposits[idx]) <= 0 or world.deposit_hidden(idx):
				continue
			var d := World.dist(World.cell_to_world(c), hover_point)
			if d < bd:
				bd = d
				best = c
	if best == null or bd > s * C:
		return null
	var corner: Vector2i = world.dep_corner(best)
	var fp: int = world.dep_fp(world.deposits[world.deposit[best]])
	return World.wc(corner + Vector2i.ONE * ((fp - s) / 2 if fp >= s else 0))


func _update_wire_preview() -> void:
	if wire_line == null:
		wire_line = MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = true
		wire_line.material_override = m
		wire_line.set_meta("no_mirror", true)
		add_child(wire_line)
	if not wiring or wire_from == null or wire_from.dead:
		wire_line.visible = false
		return
	wire_line.visible = true
	var hb = wire_pick()
	var a: Vector3 = wire_from.center() + Vector3(0, factory._wire_h(wire_from), 0)
	var c: Vector3 = hover_point + Vector3(0, 1.0, 0)
	var ok := false
	if hb != null and hb != wire_from:
		c = hb.center() + Vector3(0, factory._wire_h(hb), 0)
		ok = factory.wire_why(wire_from, hb) == ""
	c = a + World.delta(a, c)
	var col := Color(0.4, 1.0, 0.5) if ok else (Color(1, 0.4, 0.3) if hb != null and hb != wire_from else Color(1, 0.9, 0.5))
	if hb == null and World.dist(a, c) > factory.wire_len():
		col = Color(1, 0.4, 0.3)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := (c - a).cross(Vector3.UP).normalized() * 0.06
	var prev := a
	for i in range(1, 11):
		var t := i / 10.0
		var p := a.lerp(c, t)
		p.y -= sin(t * PI) * a.distance_to(c) * 0.05
		for v in [prev - side, prev + side, p + side, prev - side, p + side, p - side]:
			im.surface_set_color(col)
			im.surface_add_vertex(v)
		prev = p
	im.surface_end()
	wire_line.mesh = im



static func _is_belt(t: String) -> bool:
	return t != "" and str(DB.building(t).get("behavior", "")) == "belt"



## Синие стрелки «сюда можно подать ленту» у призрака. 1.1.9: ровно у портов здания (синие — входы, зелёная — выход);
## у зданий без портов — на трёх сторонах, как раньше.
func _ghost_inputs(t: String) -> void:
	var holder := Node3D.new()
	holder.name = "ports"
	ghost.add_child(holder)
	ghost.set_meta("pdir", -1)
	ghost.set_meta("ptype", t)


func _ghost_ports() -> void:
	var holder := ghost.get_node_or_null("ports")
	if holder == null:
		return
	for ch in holder.get_children():
		ch.queue_free()
	ghost.set_meta("pdir", build_dir)
	var t := str(ghost.get_meta("ptype", ""))
	var d := DB.building(t)
	var beh := str(d.get("behavior", ""))
	var pr: Dictionary = d.get("params", {})
	var sz := int(d.get("size", 1))
	var arrows := []   # [смещение от центра в мире, сторона, вход?]
	if Factory.ports_on() and Factory.port_counts(t)[0] >= 0 and not beh in ["belt", "splitter", "merger", "junction", "pipe", "foundation"]:
		var lay := Factory.port_layout(t, Vector2i.ZERO, build_dir)
		var ctr := Vector3((sz - 1) * C * 0.5, 0, (sz - 1) * C * 0.5)
		var fp := false   # 1.1.12: все входы одинаковые (синие)
		for i in lay["in"].size():
			arrows.append([World.cell_to_world(lay["in"][i]) - World.cell_to_world(Vector2i.ZERO) - ctr, int(lay.in_side[i]), true, fp and i == lay["in"].size() - 1])
		for i in lay.out.size():
			arrows.append([World.cell_to_world(lay.out[i]) - World.cell_to_world(Vector2i.ZERO) - ctr, int(lay.out_side[i]), false])
	elif beh in ["crafter", "storage", "hq"] or (beh == "generator" and not pr.get("solar", false) and not pr.get("wind", false)):
		for rel in [1, 2, 3]:
			var sd: int = (build_dir + rel) % 4
			arrows.append([Vector3(Factory.DIRS[sd].x, 0, Factory.DIRS[sd].y) * (sz * C * 0.5 + C * 0.5), sd, true])
	var back := Basis(Vector3.UP, build_dir * PI * 0.5)   # мир → поворот призрака
	for a in arrows:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.25, 0.66, 1.0, 0.85) if a[2] else Color(0.36, 1.0, 0.55, 0.85)
		if a.size() > 3 and a[3]:
			m.albedo_color = Color(1.0, 0.6, 0.18, 0.9)   # 1.1.11: вход для топлива — оранжевый
		var dv := Vector3(Factory.DIRS[a[1]].x, 0, Factory.DIRS[a[1]].y)
		var off: Vector3 = a[0] - dv * C * 0.35   # стрелка у самой стены, на клетке порта
		var ang := atan2(-dv.z, dv.x) + (PI if a[2] else 0.0)   # вход — внутрь, выход — наружу
		var ar := MeshInstance3D.new()
		ar.mesh = ModelLib.unit_mesh("prism")
		ar.transform = Transform3D(back * Basis(Vector3.UP, ang) * Basis.from_euler(Vector3(-PI / 2, 0, -PI / 2)) * Basis.from_scale(Vector3(0.7, 0.8, 0.08)), back * off + Vector3(0, 0.12, 0))
		ar.material_override = m
		holder.add_child(ar)
