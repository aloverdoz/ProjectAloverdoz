class_name Console
extends CanvasLayer
## Консоль разработчика (клавиша «~»).
## Команды описаны в commands.json: у каждой — описание и список действий.
## Своя команда в редакторе собирается из готовых действий (см. ACTIONS).
## В аргументах действий: $1, $2 ... — слова после команды, $* — весь текст, "$2|1" — значение по умолчанию.

const ACTIONS := {
	"help": "Список команд",
	"clear": "Очистить консоль",
	"echo": "Вывести текст (text)",
	"give": "Выдать предмет герою (item, n)",
	"give_all": "Положить в штаб все предметы (n)",
	"credits": "Добавить кредиты (n)",
	"xp": "Добавить опыт (n)",
	"skill_points": "Добавить очки навыков (n)",
	"heal": "Вылечить героя, накормить, напоить",
	"attr_points": "Добавить очки характеристик (n)",
	"die": "Герой погибает (проверка сундука с вещами)",
	"spawn_pack": "Призвать бродячую стаю рядом (dist)",
	"toggle": "Переключить флаг: god, free_build, no_waves, show_fps (flag)",
	"toggle_pref": "Переключить настройку игрока (key)",
	"pref": "Изменить настройку игрока (key, value)",
	"setting": "Изменить правило игры до перезапуска (key, value)",
	"tp": "Телепорт в клетку (x, z)",
	"tp_hq": "Телепорт к штабу",
	"time": "Время суток 0..1 (t)",
	"timescale": "Скорость игры (x)",
	"wave": "Начать волну",
	"spawn": "Призвать монстров (enemy, n)",
	"kill_all": "Убить всех монстров",
	"cam": "Камера: what = pitch | dist | fov | max, v = значение",
	"zone": "Зона за бурей: n — сделать N×N блоков (0 — расширить на 1 бесплатно)",
	"save": "Сохранить игру",
	"open": "Открыть окно интерфейса (window)",
	"notify": "Сообщение на экране (text)",
	"sound": "Проиграть звук (key, x, z)",
	"boost": "Усилить героя на время (key, v, t)",
	"run": "Выполнить другую команду (text)",
	"drop": "Выбросить предмет на землю (item, n, x, z)",
	"explode": "Взрыв: урон монстрам рядом (x, z, v, dist)",
	"hurt": "Ранить героя (n)",
	"chance": "Дальше — только с шансом (v)",
	"place": "Построить здание (key, x, z)",
	"research": "Добавить очки исследований (n)",
	"event": "Начать событие мира (key)",
	"end_event": "Закончить событие мира (key, пусто — все)",
	"order": "Выставить заказ на станции (key = sell|buy, item, n, v — цена)",
	"npc": "Привести НПС к базе (enemy, n)",
	"scout": "Дрон-разведчик летит туда, куда смотрит камера (dist)",
	"unlock_rare": "Открыть редкое здание по чертежу (key)",
	"season": "Перейти к сезону по названию или номеру (key: Зима или 4)",
	"reveal": "Открыть карту вокруг клетки (x, z, dist — радиус в метрах; пусто — вся карта)",
}

var game
var panel: PanelContainer
var log_lbl: RichTextLabel
var input: LineEdit
var history: Array = []
var hist_i := 0
var _open := false


func _ready() -> void:
	layer = 50
	panel = UI.panel(0.93)
	panel.theme = UI.theme()
	panel.visible = false
	add_child(panel)
	var v := UI.vbox(4)
	panel.add_child(v)
	log_lbl = RichTextLabel.new()
	log_lbl.bbcode_enabled = true
	log_lbl.scroll_following = true
	log_lbl.custom_minimum_size = Vector2(0, 300)
	log_lbl.add_theme_font_size_override("normal_font_size", 14)
	v.add_child(log_lbl)
	input = LineEdit.new()
	input.placeholder_text = "Введите команду (help — список, Tab — дополнить, ↑↓ — история)" if unlocked() else ""
	input.text_submitted.connect(_submit)
	input.gui_input.connect(_input_keys)
	v.add_child(input)
	if unlocked():
		print_line("[color=#ffa040]Консоль. Введите help, чтобы увидеть команды.[/color]")


func visible_now() -> bool:
	return _open


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		# «ё» на русской раскладке — та же клавиша: пока игрок печатает в поле ввода, консоль не открываем
		if not _open and game != null and game.typing():
			return
		var k: int = ev.physical_keycode
		var want := str(Prefs.get_value("key_console", "QuoteLeft"))
		if OS.get_keycode_string(k) == want or k == KEY_QUOTELEFT:
			toggle()
			get_viewport().set_input_as_handled()
		elif _open and k == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	_open = not _open
	panel.visible = _open
	if _open:
		var vs := panel.get_viewport_rect().size
		panel.position = Vector2(20, 20)
		panel.size = Vector2(vs.x - 40, 0)
		panel.custom_minimum_size = Vector2(vs.x - 40, 0)
		input.text = ""
		input.grab_focus()
	else:
		input.release_focus()


func print_line(t: String) -> void:
	log_lbl.append_text(t + "\n")


func _input_keys(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	match ev.keycode:
		KEY_UP:
			if not history.is_empty():
				hist_i = max(0, hist_i - 1)
				input.text = history[hist_i]
				input.caret_column = input.text.length()
			input.accept_event()
		KEY_DOWN:
			if not history.is_empty():
				hist_i = min(history.size(), hist_i + 1)
				input.text = history[hist_i] if hist_i < history.size() else ""
				input.caret_column = input.text.length()
			input.accept_event()
		KEY_TAB:
			_complete()
			input.accept_event()


func _complete() -> void:
	var t := input.text.strip_edges()
	var parts := t.split(" ", false)
	if parts.size() <= 1:
		var m := []
		for c in DB.data.commands:
			if c.begins_with(t):
				m.append(c)
		if m.size() == 1:
			input.text = m[0] + " "
		elif m.size() > 1:
			print_line("  ".join(m))
	else:
		# дополнение id предмета или монстра
		var last := parts[parts.size() - 1]
		var pool: Array = DB.data.items.keys() + DB.data.enemies.keys() + DB.data.buildings.keys()
		var m2 := pool.filter(func(x): return str(x).begins_with(last))
		if m2.size() == 1:
			parts[parts.size() - 1] = m2[0]
			input.text = " ".join(parts) + " "
		elif m2.size() > 1:
			print_line("  ".join(m2.slice(0, 30)))
	input.caret_column = input.text.length()


## 1.6: команды разработчика работают только после ключа (нигде не упоминается). Редактор и автотесты — без ключа.
const _K := "cea9d0d9c3b1b7cd3d1bfc132a3f4308"
static var test_locked := false   # автотест: проверить замок


static func unlocked() -> bool:
	if test_locked:
		return bool(Prefs.get_value("dev_console", false))
	return DB.studio or bool(Prefs.get_value("dev_console", false)) or Array(OS.get_cmdline_user_args()).any(func(x): return str(x).begins_with("--test"))


static func _key_ok(t: String) -> bool:
	return (t.strip_edges().to_lower() + "fc").md5_text() == _K


func _submit(t: String) -> void:
	t = t.strip_edges()
	input.text = ""
	if t == "":
		return
	var w0 := t.split(" ", false)[0].to_lower()
	if w0 in ["admin", "админ"] and game != null and game.admin != null:
		# 1.1.11: админ-панель — по паролю администратора сервера (пароль в журнал консоли не пишется)
		print_line("[color=#8a93a3]> %s[/color]" % w0)
		print_line("[color=#ffd040]%s[/color]" % game.admin.login(t.substr(w0.length()).strip_edges()))
		toggle()
		return
	if w0 in ["camera", "камера"] and game != null:
		# 1.1.15: свободная камера для съёмки (не чит, работает в любой игре)
		print_line("[color=#8a93a3]> %s[/color]" % w0)
		toggle()
		game.free_camera()
		return
	if not unlocked():
		if _key_ok(t):
			Prefs.set_value("dev_console", true)
			input.placeholder_text = "Введите команду (help — список, Tab — дополнить, ↑↓ — история)"
			print_line("[color=#ffa040]Консоль. Введите help, чтобы увидеть команды.[/color]")
			return
		print_line("[color=#8a93a3]> %s[/color]" % t)
		print_line("[color=#ff6b5a]Нет такой команды: %s[/color]" % t.split(" ", false)[0])
		return
	history.append(t)
	hist_i = history.size()
	print_line("[color=#8a93a3]> %s[/color]" % t)
	run(t)


## Выполнить строку консоли (её же вызывают кнопки своих окон и автотесты).
func run(line: String) -> void:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var name := parts[0].to_lower()
	var args := parts.slice(1)
	var c: Dictionary = DB.data.commands.get(name, {})
	if c.is_empty():
		print_line("[color=#ff6b5a]Нет такой команды: %s (help — список)[/color]" % name)
		return
	if c.get("cheat", false) and not DB.studio and not bool(DB.data.settings.get("cheats", true)):
		print_line("[color=#ff6b5a]Читы отключены в этой игре[/color]")
		return
	if c.get("cheat", false) and not DB.studio and Net.is_client() and not (game.admin != null and game.admin.ok):
		print_line("[color=#ff6b5a]В сетевой игре читы — только у администратора комнаты[/color]")   # A-22
		return
	_run_list(c.get("actions", []), args, " ".join(args), {})


## Действия от здания или предмета: $x, $z в значениях — клетка, где это случилось.
func run_actions(actions: Array, vars := {}) -> void:
	_run_list(actions, [], "", vars)


func _run_list(actions: Array, args: Array, all: String, vars: Dictionary) -> void:
	for a0 in actions:
		if not a0 is Dictionary:
			continue
		var a: Dictionary = a0
		if not vars.is_empty():
			a = a0.duplicate()
			for k in a:
				if a[k] is String:
					for vk in vars:
						a[k] = a[k].replace("$" + vk, str(vars[vk]))
		if a.get("do", "") == "chance":
			if randf() > float(_arg(a.get("v", "0.5"), args, all)):
				return
			continue
		_do(a, args, all)


func _arg(v, args: Array, all: String) -> String:
	var s := str(v)
	var def := ""
	if "|" in s:
		var p := s.split("|", true, 1)
		s = p[0]
		def = p[1]
	if s == "$*":
		return all if all != "" else def
	if s.begins_with("$"):
		var i := int(s.substr(1)) - 1
		return str(args[i]) if i >= 0 and i < args.size() else def
	return s


func _do(a: Dictionary, args: Array, all: String) -> void:
	var g = game
	var get := func(k: String, def := "") -> String:
		return _arg(a.get(k, def), args, all)
	match a.get("do", ""):
		"help":
			var ids: Array = DB.data.commands.keys()
			ids.sort()
			for id in ids:
				var c: Dictionary = DB.data.commands[id]
				print_line("[color=#ffa040]%s[/color] — %s  [color=#8a93a3]%s[/color]" % [c.get("usage", id), c.get("desc", ""), "(чит)" if c.get("cheat", false) else ""])
		"clear":
			log_lbl.clear()
		"echo":
			print_line(get.call("text"))
		"give":
			var id: String = get.call("item")
			if not DB.data.items.has(id):
				print_line("[color=#ff6b5a]Нет предмета %s[/color]" % id)
				return
			g.factory.give_player(id, int(get.call("n", "1")))
			print_line("Выдано: %s × %s" % [DB.item_name(id), get.call("n", "1")])
		"give_all":
			var n := int(get.call("n", "50"))
			for id in DB.data.items:
				g.factory.hq.inv.add(id, n)
			print_line("В штаб положено по %d каждого предмета (если хватило места)" % n)
		"credits":
			g.add_credits(int(get.call("n", "100")))
		"xp":
			g.add_xp(float(get.call("n", "100")))
		"skill_points":
			g.skill_points += int(get.call("n", "1"))
		"attr_points":
			g.attr_points += int(get.call("n", "5"))
		"die":
			g.player.god = false
			g.flags["god"] = false
			g.player.damage(999999.0)
		"spawn_pack":
			var dd := float(get.call("dist", "30"))
			var ang2 := randf() * TAU
			var pk = g.enemies.spawn_pack(g.player.position + Vector3(cos(ang2), 0, sin(ang2)) * dd)
			print_line("Стая призвана: %d монстров" % (pk.members.size() if pk else 0))
		"heal":
			g.player.hp = g.player.maxhp
			g.player.food = 100.0
			g.player.water = 100.0
			if not g.player.alive:
				g.player.respawn = 0.0
		"toggle":
			var f: String = get.call("flag")
			g.flags[f] = not g.flags.get(f, false)
			if f == "god":
				g.player.god = g.flags[f]
			print_line("%s: %s" % [f, "ВКЛ" if g.flags[f] else "выкл"])
		"toggle_pref":
			var k: String = get.call("key")
			Prefs.set_value(k, not bool(Prefs.get_value(k, false)))
			print_line("%s = %s" % [k, Prefs.get_value(k)])
		"pref":
			var k: String = get.call("key")
			var v = _parse(get.call("value"))
			Prefs.set_value(k, v)
			print_line("%s = %s" % [k, v])
		"setting":
			var k: String = get.call("key")
			DB.data.settings[k] = _parse(get.call("value"))
			print_line("Правило %s = %s (до перезапуска)" % [k, DB.data.settings[k]])
		"tp":
			var c := Vector2i(int(get.call("x", "0")), int(get.call("z", "0")))
			g.player.position = World.cell_to_world(World.wc(c))
			g.cam_focus = g.player.position
		"tp_hq":
			if g.factory.hq:
				g.player.position = g.factory.hq.center() + Vector3(6, 0, 6)
				g.cam_focus = g.player.position
		"time":
			g.day_t = fposmod(float(get.call("t", "0.5")), 1.0)
			g._apply_sky()
		"timescale":
			Engine.time_scale = clampf(float(get.call("x", "1")), 0.05, 20.0)
		"wave":
			g.enemies.start_wave()
		"spawn":
			var e: String = get.call("enemy", "crawler")
			var n2 := int(get.call("n", "1"))
			for i in n2:
				var ang := randf() * TAU
				g.enemies.spawn(e, g.player.position + Vector3(cos(ang), 0, sin(ang)) * randf_range(10, 16))
		"kill_all":
			for e in g.enemies.list.duplicate():
				g.enemies.hit(e, 999999.0)
		"camera":
			toggle()
			g.free_camera()
		"cam":
			var what: String = get.call("what")
			var v2 := float(get.call("v", "0"))
			match what:
				"pitch": g.cam_pitch_override = v2
				"dist":
					g.cam_dist_target = v2
					g.cam_max = max(g.cam_max, v2)
				"fov": g.camera.fov = clampf(v2, 10, 120)
				"max": g.cam_max = v2
		"zone":
			var zn := int(get.call("n", "0"))
			if zn > 0:
				g.zone.set_blocks(zn)
			else:
				g.zone.expand(true)
		"save":
			g.save_game()
		"open":
			g.hud.toggle(get.call("window"))
		"notify":
			g.notify(get.call("text"), Color(1, 0.85, 0.4))
		"unlock_rare":
			var bk := str(get.call("key", ""))
			if g.tech.unlock_rare(bk):
				g.notify("Чертёж изучен: можно строить «%s»" % str(DB.building(bk).get("name", bk)), Color(1.0, 0.85, 0.3))
			else:
				g.notify("Этот чертёж уже изучен", Color(0.8, 0.85, 0.9))
		"season":
			var sk := str(get.call("key", ""))
			var ss: Array = DB.setting("seasons", [])
			var day := 1
			for i in ss.size():
				if str(ss[i].get("name", "")) == sk or str(i + 1) == sk:
					g.day_n = day
					g.climate._vis_init = false
					g.notify("Сезон: %s" % str(ss[i].get("name", "")), Color(0.8, 0.9, 1.0))
					break
				day += maxi(1, int(ss[i].get("days", 5)))
		"scout":
			var fw: Vector3 = -g.camera.global_transform.basis.z
			g.fog.launch_scout(g.player.position, fw, float(get.call("dist", "0")))
		"reveal":
			var rd: String = str(get.call("dist", ""))
			if rd == "":
				g.fog.bits.fill(255)
				g.fog.dirty = true
			else:
				g.fog.reveal(_at(get, g), float(rd))
		"sound":
			g.sfx.play(get.call("key"), _at(get, g))
		"boost":
			g.add_effect(get.call("key", "move"), float(get.call("v", "0.2")), float(get.call("t", "30")), get.call("key", "move"))
		"run":
			run(get.call("text"))
		"drop":
			var id2: String = get.call("item")
			if DB.data.items.has(id2):
				g.drops.spawn(id2, int(get.call("n", "1")), _at(get, g) + Vector3(0, 1, 0))
		"explode":
			var at := _at(get, g)
			var r := float(get.call("dist", "4")) * World.C
			g.fx.explosion(at + Vector3(0, 1, 0), r * 0.4, Color(1.0, 0.55, 0.2))
			g.sfx.play("boom", at)
			# B18-3: граната гостя (хозяин выполняет за него) — добыча и опыт гостю
			var gact: int = int(Net._self().actor) if Net.is_host() and Net._self().applying else 0
			for e in g.enemies.list.duplicate():
				if World.dist(e.pos, at) < r:
					if gact > 1:
						e.last_hitter = gact
						g.enemies.hit(e, float(get.call("v", "50")))
					else:
						g.enemies.hit(e, float(get.call("v", "50")), true)
		"hurt":
			g.player.damage(float(get.call("n", "10")))
		"place":
			var bt: String = get.call("key")
			var cell := World.wc(Vector2i(int(get.call("x", "0")), int(get.call("z", "0"))))
			if DB.building(bt).is_empty():
				print_line("[color=#ff6b5a]Нет здания %s[/color]" % bt)
			elif g.factory.can_place(bt, cell) == "":
				g.factory.place(bt, cell, 0)
		"research":
			g.tech.research += int(get.call("n", "10"))
			print_line("Очки исследований: %d" % g.tech.research)
		"event":
			var ev: String = get.call("key")
			if not g.events.start(ev):
				print_line("[color=#ff6b5a]Нет события %s. Есть: %s[/color]" % [ev, ", ".join(DB.data.get("events", {}).keys())])
		"order":
			var o: Dictionary = g.orders.place(get.call("key", "sell"), get.call("item"), int(get.call("n", "10")), int(get.call("v", "100")))
			print_line("Заказ выставлен" if not o.is_empty() else "[color=#ff6b5a]Не получилось: проверьте предмет и числа[/color]")
		"npc":
			var got: Array = g.npcs.spawn_visit(get.call("enemy", "trader"), int(get.call("n", "1")))
			print_line("Идут к базе: %d" % got.size())
		"end_event":
			var ev2: String = get.call("key")
			for id in g.events.active.keys():
				if ev2 == "" or id == ev2:
					g.events.finish(id)
		_:
			print_line("[color=#ff6b5a]Неизвестное действие: %s[/color]" % a.get("do", ""))


## Точка для действия: клетка x, z, если заданы, иначе — где герой.
func _at(get: Callable, g) -> Vector3:
	var xs: String = get.call("x", "")
	var zs: String = get.call("z", "")
	if xs.is_valid_int() and zs.is_valid_int():
		return World.cell_to_world(World.wc(Vector2i(int(xs), int(zs))))
	return g.player.position


func _parse(s: String):
	if s == "true" or s == "on":
		return true
	if s == "false" or s == "off":
		return false
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return float(s)
	return s
