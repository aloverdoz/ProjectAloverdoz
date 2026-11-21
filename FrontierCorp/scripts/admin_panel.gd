class_name AdminPanel
extends RefCounted
## 1.1.11: админ-панель. В консоли («~») или в чате: admin пароль — открывается окно с вкладками:
## игроки (уровень, очки характеристик и навыков, опыт, лечение, бессмертие, бесплатная стройка, телепорт, кредиты, выгнать),
## ресурсы (любой предмет любому игроку или в штаб), здания (всё и бесплатно), мир (время, волны, монстры, технологии, сохранение).
## Пароль — пароль администратора выделенного сервера («Управление сервером»). В одиночной игре и у хозяина комнаты пароль не нужен.
## Всё выполняет хозяин: гость шлёт req_admin_act, хозяин проверяет права и рассылает изменения.

const TABS := [["players", "Игроки"], ["items", "Ресурсы"], ["builds", "Здания"], ["world", "Мир"]]

var game
var ok := false              # у этого игрока есть права администратора
var tab := "players"
var target := 0              # id игрока, с которым работаем (0 — ещё не выбран)
var players: Array = []      # [{id, nick, level, admin}] — список от хозяина
var amount := 100
var item_q := ""
var build_q := ""
var build_cat := ""         # 1.1.15: вкладка категории зданий
var _sig := ""              # 1.1.15: окно перестраивается только когда что-то поменялось (раньше — каждый кадр)
var to_hq := false
var say_text := ""
var free_nicks := {}         # хозяин: ники с бесплатной стройкой
var admin_nicks := {}        # хозяин: ники с правами (вошли по паролю или выдал хозяин)
var _win = null


func _init(g) -> void:
	game = g


func net():
	return Net._self()


func online() -> bool:
	return Net.active()


# ---------------------------------------------------------------- вход

## Команда admin из консоли или чата.
func login(pw: String) -> String:
	pw = pw.strip_edges()
	if ok:
		open()
		return "Админ-панель открыта"
	if not online() or Net.is_host():
		# своя игра или своя комната — мир ваш, пароль не нужен
		_granted("")
		return "Админ-панель открыта"
	if pw == "":
		return "Введите: admin пароль (пароль администратора сервера)"
	net().rpc_id(1, "req_admin_login", pw)
	return "Проверяю пароль…"


## Ответ хозяина на вход (или хозяин сам выдал права).
func _granted(msg: String) -> void:
	ok = true
	if msg != "":
		game.notify(msg, Color(1, 0.85, 0.35))
	if target == 0:
		target = net().my_id() if online() else 1
	open()


func on_reply(granted: bool, msg: String) -> void:
	if granted:
		_granted(msg)
	else:
		ok = false
		game.notify(msg, Color(1, 0.5, 0.4))
		if game.console:
			game.console.print_line("[color=#ff6b5a]%s[/color]" % msg)
		if _win != null and game.hud.is_open("admin"):
			game.hud.close("admin")


## Хозяин: проверить пароль гостя.
func host_login(sid: int, nk: String, pw: String) -> Array:
	var srv = net().server
	if srv != null:
		if not srv.has_admin():
			return [false, "Пароль администратора ещё не задан: «Сетевая игра → Управление сервером»"]
		if not srv.check_pass(pw):
			srv.log_line("Неверный пароль админ-панели от %s" % nk)
			return [false, "Неверный пароль администратора"]
		srv.log_line("%s вошёл в админ-панель" % nk)
		admin_nicks[nk] = true
		return [true, "Админ-панель: права администратора получены"]
	if admin_nicks.has(nk):
		return [true, "Админ-панель: права администратора получены"]
	return [false, "В этой комнате права администратора выдаёт хозяин (админ-панель → Игроки)"]


func is_admin_peer(sid: int) -> bool:
	if not net().peers.has(sid):
		return false
	return admin_nicks.has(str(net().peers[sid].nick))


# ---------------------------------------------------------------- действия

## Выполнить действие: у хозяина — сразу, у гостя — просьба хозяину.
func act(name: String, d := {}) -> void:
	if not ok:
		return
	if online() and Net.is_client():
		net().rpc_id(1, "req_admin_act", name, d)
		return
	var msg := host_act(name, d, net().my_id() if online() else 1)
	if msg != "":
		game.notify(msg, Color(1, 0.85, 0.35))
	_refresh_soon()


## Хозяин: список игроков для панели.
func host_players() -> Array:
	var out := []
	if not online():
		return [{"id": 1, "nick": "Вы", "level": game.level, "admin": true}]
	var n = net()
	if not n.dedicated:
		out.append({"id": n.my_id(), "nick": n.nick, "level": game.level, "admin": true})
	for pid in n.peers:
		if pid == n.my_id():
			continue
		var nk := str(n.peers[pid].nick)
		var me: Dictionary = n.saved.get(nk, {}).get("me", {})
		out.append({"id": pid, "nick": nk, "level": int(me.get("level", 1)), "admin": admin_nicks.has(nk), "free": free_nicks.has(nk)})
	return out


func _nick_of(pid: int) -> String:
	if not online():
		return "Вы"
	var n = net()
	if pid == n.my_id():
		return n.nick
	return str(n.peers[pid].nick) if n.peers.has(pid) else ""


func _pos_of(pid: int):
	var n = net()
	if not online() or (pid == n.my_id() and not n.dedicated):
		return game.player.position
	if n.puppets.has(pid) and is_instance_valid(n.puppets[pid]):
		return n.puppets[pid].position
	return null


func _is_me(pid: int) -> bool:
	return not online() or (pid == net().my_id() and not net().dedicated)


## Хозяин выполняет действие администратора sid. Ответ — текст для администратора.
func host_act(name: String, d: Dictionary, sid: int) -> String:
	var n = net()
	var to := int(d.get("to", sid))
	var who := _nick_of(to)
	if online() and n.server != null:
		n.server.log_line("Админ %s: %s %s" % [_nick_of(sid), name, d])
	match name:
		"players":
			return ""
		"give":
			var id := str(d.get("item", ""))
			var k := clampi(int(d.get("n", 1)), 1, 1000000)
			if not DB.data.items.has(id):
				return "Нет такого предмета"
			if bool(d.get("hq", false)):
				if game.factory.hq == null:
					return "Штаба нет"
				var left: int = game.factory.hq.inv.add(id, k)
				if online():
					n._send_shared()
				return "В штаб: %s × %d%s" % [DB.item_name(id), k - left, " (не влезло %d)" % left if left > 0 else ""]
			if who == "":
				return "Игрок не найден"
			if _is_me(to):
				game.factory.give_player(id, k)
			else:
				n.give_to(to, id, k)
			return "%s: %s × %d" % [who, DB.item_name(id), k]
		"give_all":
			var k2 := clampi(int(d.get("n", 50)), 1, 100000)
			if game.factory.hq == null:
				return "Штаба нет"
			for id2 in DB.data.items:
				if not DB.is_fluid(id2):
					game.factory.hq.inv.add(id2, k2)
			if online():
				n._send_shared()
			return "В штаб положено по %d каждого предмета (сколько влезло)" % k2
		"player":
			# изменения героя: уровень, очки, лечение, бессмертие, бесплатная стройка
			if who == "":
				return "Игрок не найден"
			var ch: Dictionary = d.get("set", {})
			if ch.has("free_build"):
				if bool(ch.free_build):
					free_nicks[who] = true
				else:
					free_nicks.erase(who)
			if _is_me(to):
				apply_self(ch)
			else:
				n.rpc_id(to, "admin_apply", ch)
			return "%s: %s" % [who, _describe(ch)]
		"tp_to":
			var p = _pos_of(to)
			if p == null:
				return "Игрок не найден"
			var ch2 := {"pos": [p.x, p.y, p.z + 3.0]}
			if _is_me(sid):
				apply_self(ch2)
			else:
				n.rpc_id(sid, "admin_apply", ch2)
			return "Телепорт к игроку %s" % who
		"bring":
			var p2 = _pos_of(sid)
			if p2 == null or who == "":
				return "Игрок не найден"
			var ch3 := {"pos": [p2.x + 3.0, p2.y, p2.z]}
			if _is_me(to):
				apply_self(ch3)
			else:
				n.rpc_id(to, "admin_apply", ch3)
			return "%s перенесён к вам" % who
		"tp_hq":
			if game.factory.hq == null or who == "":
				return "Штаба нет"
			var hp: Vector3 = game.factory.hq.center() + Vector3(6, 0, 6)
			var ch4 := {"pos": [hp.x, hp.y, hp.z]}
			if _is_me(to):
				apply_self(ch4)
			else:
				n.rpc_id(to, "admin_apply", ch4)
			return "%s — у штаба" % who
		"credits":
			var c := int(d.get("n", 1000))
			if online() and n.own_wallets() and not _is_me(to):
				n.wallet_add(who, c)
			else:
				game.add_credits(c)
			return "%s: +%d кредитов" % [who, c]
		"make_admin":
			if not online() or who == "" or _is_me(to):
				return ""
			if bool(d.get("on", true)):
				admin_nicks[who] = true
				n.rpc_id(to, "admin_reply", true, "Хозяин выдал вам права администратора: консоль → admin")
				return "%s теперь администратор" % who
			admin_nicks.erase(who)
			free_nicks.erase(who)
			n.rpc_id(to, "admin_reply", false, "Права администратора сняты")
			return "%s больше не администратор" % who
		"kick":
			if not online() or who == "" or _is_me(to):
				return ""
			n.kick(to)
			return "%s выгнан" % who
		"time":
			game.day_t = fposmod(float(d.get("t", 0.3)), 1.0)
			game._apply_sky()
			return "Время суток изменено"
		"waves":
			game.flags["no_waves"] = not bool(d.get("on", true))
			return "Волны монстров: %s" % ("включены" if not game.flags.no_waves else "выключены")
		"wave":
			game.enemies.start_wave()
			return "Волна началась"
		"kill_all":
			var k3 := 0
			for e in game.enemies.list.duplicate():
				if e.peaceful:
					continue   # A-18: мирных торговцев и путников не трогаем
				k3 += 1
				game.enemies.hit(e, 999999.0)
			return "Монстров убито: %d" % k3
		"tech_all":
			game.tech.unlock_all()
			if game.hud:
				game.hud.refresh_open()
			return "Все технологии открыты"
		"save":
			if online() and n.server != null:
				n.server.save()
			else:
				game.save_game("autosave" if Net.is_host() else "save1")   # A-17: в комнате — в ячейку комнаты, а не в личную «1»
			return "Мир сохранён"
		"say":
			var t := str(d.get("text", "")).strip_edges()
			if t == "":
				return ""
			if online():
				n.rpc("chat_msg", "Администратор", "#ffd040", t)
				n._show_chat("Администратор", "#ffd040", t)
			game.notify("Администратор: " + t, Color(1, 0.85, 0.35))
			return ""
	return "Неизвестное действие: " + name


func _describe(ch: Dictionary) -> String:
	var parts := []
	if ch.has("level"):
		parts.append("уровень %d" % int(ch.level))
	if ch.has("level_add"):
		parts.append("уровень +%d" % int(ch.level_add))
	if ch.has("xp"):
		parts.append("опыт +%d" % int(ch.xp))
	if ch.has("attr_points"):
		parts.append("очки характеристик +%d" % int(ch.attr_points))
	if ch.has("skill_points"):
		parts.append("очки навыков +%d" % int(ch.skill_points))
	if ch.has("heal"):
		parts.append("вылечен")
	if ch.has("god"):
		parts.append("бессмертие " + ("вкл" if ch.god else "выкл"))
	if ch.has("free_build"):
		parts.append("бесплатная стройка " + ("вкл" if ch.free_build else "выкл"))
	if ch.has("reset"):
		parts.append("навыки и характеристики сброшены")
	return ", ".join(parts)


## Применить изменения к своему герою (у гостя — по команде хозяина).
func apply_self(ch: Dictionary) -> void:
	var g = game
	var maxl := int(DB.data.levels.get("max_level", 50))
	var ppl := int(DB.data.levels.get("points_per_level", 1))
	var apl := int(DB.data.levels.get("attr_points_per_level", 2))
	if ch.has("level_add") or ch.has("level"):
		var want: int = clampi(int(ch.get("level", g.level + int(ch.get("level_add", 0)))), 1, maxl)
		if want > g.level:
			# за каждый новый уровень — очки, как при обычном росте
			g.skill_points += (want - g.level) * ppl
			g.attr_points += (want - g.level) * apl
		g.level = want
		g.xp = 0.0
	if ch.has("xp"):
		g.add_xp(float(ch.xp))
	if ch.has("attr_points"):
		g.attr_points = maxi(0, g.attr_points + int(ch.attr_points))
	if ch.has("skill_points"):
		g.skill_points = maxi(0, g.skill_points + int(ch.skill_points))
	if ch.has("reset"):
		# сброс: всё вложенное возвращается очками
		var sp := 0
		for k in g.skills:
			sp += int(g.skills[k])
		var ap := 0
		for k in g.attrs:
			ap += int(g.attrs[k])
		g.skills.clear()
		g.attrs.clear()
		g.skill_points += sp
		g.attr_points += ap
		if g.has_method("apply_attrs"):
			g.apply_attrs()
	if ch.has("heal"):
		g.player.hp = g.player.maxhp
		g.player.food = 100.0
		g.player.water = 100.0
		if not g.player.alive:
			g.player.respawn = 0.0
	if ch.has("god"):
		g.flags["god"] = bool(ch.god)
		g.player.god = bool(ch.god)
	if ch.has("free_build"):
		if bool(ch.free_build):
			g.flags["free_build"] = true
		else:
			g.flags.erase("free_build")
	if ch.has("pos"):
		var p: Array = ch.pos
		g.player.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		g.cam_focus = g.player.position
	var msg := _describe(ch)
	if msg != "" and online() and Net.is_client():
		g.notify("Администратор: " + msg, Color(1, 0.85, 0.35))
	if g.hud:
		g.hud.refresh_open()


# ---------------------------------------------------------------- окно

func open() -> void:
	if game.hud == null:
		return
	if _win == null:
		_win = game.hud._win("admin", "АДМИН-ПАНЕЛЬ", 880, _live)
	if online() and Net.is_client():
		act("players")
	else:
		players = host_players()
	_sig = ""
	game.hud.open("admin")


var _soon := false
func _refresh_soon() -> void:
	if _soon or _win == null:
		return
	_soon = true
	await game.get_tree().create_timer(0.15).timeout
	_soon = false
	if game.hud.is_open("admin"):
		if not (online() and Net.is_client()):
			players = host_players()
		refresh()


func set_players(list: Array) -> void:
	players = list
	_refresh_soon()


## Окно открыто — HUD зовёт это каждый кадр. 1.1.15: раньше здесь каждый кадр заново строилось всё окно
## (а на вкладке «Здания» — 170 карточек с подсказками), отсюда и лаги с открытой панелью.
func _live() -> void:
	if _sig != _state_sig():
		refresh()


func _state_sig() -> String:
	var np: int = net().peers.size() if online() else 0
	return "%s|%d|%d|%s|%s|%s|%s|%s|%d|%d|%d|%d|%d|%s" % [tab, target, amount, item_q, build_q, build_cat, to_hq,
		game.flags.get("free_build", false), game.level, game.attr_points, game.skill_points, players.hash(), np, DB.locked.size()]


func _tab_btn(text: String, on: bool, cb: Callable) -> Button:
	var b := UI.button(text, cb)
	if on:
		b.add_theme_color_override("font_color", UI.theme().get_color("font_pressed_color", "Button"))
		b.add_theme_stylebox_override("normal", UI.theme().get_stylebox("pressed", "Button"))
		b.add_theme_stylebox_override("hover", UI.theme().get_stylebox("pressed", "Button"))
	return b


## Сетка одинаковых кнопок: ровные колонки вместо длинных и узких вперемешку.
func _grid(body: Control, cols := 4) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	body.add_child(g)
	return g


func _gbtn(g: Control, text: String, cb: Callable, tip := "") -> Button:
	var b := UI.button(text, cb, tip)
	b.custom_minimum_size = Vector2(UI.ws(200), UI.fs(34))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if tip == "":
		b.tooltip_text = text
	g.add_child(b)
	return b


func refresh() -> void:
	if _win == null:
		return
	_sig = _state_sig()
	var body: VBoxContainer = _win.body
	UI.clear(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	for t in TABS:
		var tid: String = t[0]
		var tb := _tab_btn(t[1], tab == tid, func(): tab = tid; refresh())
		tb.custom_minimum_size = Vector2(UI.ws(130), UI.fs(36))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tb)
	body.add_child(top)
	if tab in ["players", "items"]:
		_target_row(body)
	match tab:
		"players":
			_tab_players(body)
		"items":
			_tab_items(body)
		"builds":
			_tab_builds(body)
		"world":
			_tab_world(body)


func _target_row(body: Control) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	row.add_child(UI.label("Игрок:", 15, UI.DIM))
	var found := false
	for p in players:
		var pid := int(p.id)
		found = found or pid == target
		var txt := "%s · ур. %d%s" % [p.nick, int(p.get("level", 1)), " ★" if p.get("admin", false) else ""]
		row.add_child(_tab_btn(txt, pid == target, func(): target = pid; refresh()))
	if not found and not players.is_empty():
		target = int(players[0].id)
	row.add_child(UI.button("⟳", _reload_players, "Обновить список игроков"))
	body.add_child(row)


func _reload_players() -> void:
	if online() and Net.is_client():
		act("players")
	else:
		_refresh_soon()


func _amount_row(body: Control, label: String) -> void:
	var row := UI.hbox(6)
	row.add_child(UI.label(label, 15, UI.DIM))
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 1000000
	sp.value = amount
	sp.custom_minimum_size = Vector2(UI.ws(130), 0)
	sp.value_changed.connect(func(v): amount = int(v))
	row.add_child(sp)
	for k in [1, 10, 100, 1000, 10000]:
		var kk: int = k
		var b := _tab_btn(str(k), amount == k, func(): amount = kk; refresh())
		b.custom_minimum_size = Vector2(UI.ws(64), 0)
		row.add_child(b)
	body.add_child(row)


func _tab_players(body: Control) -> void:
	var me: bool = not online() or target == net().my_id()
	var info: Dictionary = {}
	for p in players:
		if int(p.id) == target:
			info = p
	if me:
		body.add_child(UI.rich("Уровень [b]%d[/b] · очков характеристик [b]%d[/b] · очков навыков [b]%d[/b]" % [game.level, game.attr_points, game.skill_points], 15))
	elif not info.is_empty():
		body.add_child(UI.rich("[b]%s[/b] · уровень %d%s" % [info.nick, int(info.get("level", 1)), " · администратор" if info.get("admin", false) else ""], 15))
	_amount_row(body, "Сколько:")
	var n := amount
	var P := func(ch: Dictionary): act("player", {"to": target, "set": ch})
	body.add_child(UI.section("Уровень и очки"))
	var g1 := _grid(body)
	_gbtn(g1, "Уровень +1", func(): P.call({"level_add": 1}))
	_gbtn(g1, "Уровень +%d" % n, func(): P.call({"level_add": amount}))
	_gbtn(g1, "Уровень = %d" % n, func(): P.call({"level": amount}))
	_gbtn(g1, "Опыт +%d" % n, func(): P.call({"xp": amount}))
	_gbtn(g1, "Очки характ. +%d" % n, func(): P.call({"attr_points": amount}), "Очки характеристик + «сколько»")
	_gbtn(g1, "Очки навыков +%d" % n, func(): P.call({"skill_points": amount}))
	_gbtn(g1, "Кредиты +%d" % n, func(): act("credits", {"to": target, "n": amount}))
	_gbtn(g1, "Сбросить навыки", func(): P.call({"reset": true}), "Сбросить навыки и характеристики (очки вернутся)")
	body.add_child(UI.section("Состояние"))
	var g2 := _grid(body)
	_gbtn(g2, "Вылечить, накормить", func(): P.call({"heal": true}))
	_gbtn(g2, "Бессмертие: вкл", func(): P.call({"god": true}))
	_gbtn(g2, "Бессмертие: выкл", func(): P.call({"god": false}))
	_gbtn(g2, "Беспл. стройка: вкл", func(): P.call({"free_build": true}), "Бесплатная стройка: все здания открыты и ничего не стоят")
	_gbtn(g2, "Беспл. стройка: выкл", func(): P.call({"free_build": false}))
	body.add_child(UI.section("Перемещение"))
	var g3 := _grid(body)
	_gbtn(g3, "Телепорт к игроку", func(): act("tp_to", {"to": target}))
	_gbtn(g3, "Перенести ко мне", func(): act("bring", {"to": target}))
	_gbtn(g3, "Отправить к штабу", func(): act("tp_hq", {"to": target}))
	if online() and not me:
		body.add_child(UI.section("Права"))
		var g4 := _grid(body)
		if Net.is_host():
			_gbtn(g4, "Сделать админом", func(): act("make_admin", {"to": target, "on": true}), "Сделать администратором")
			_gbtn(g4, "Снять админа", func(): act("make_admin", {"to": target, "on": false}), "Снять права администратора")
		_gbtn(g4, "Выгнать с сервера", func(): act("kick", {"to": target}))


const ITEMS_MAX := 120   # больше кнопок сразу не строим — уточните поиском


func _tab_items(body: Control) -> void:
	_amount_row(body, "Сколько:")
	var row := UI.hbox(6)
	var se := LineEdit.new()
	se.placeholder_text = "Поиск предмета…"
	se.text = item_q
	se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	se.text_changed.connect(func(t): item_q = t; _refresh_soon())
	row.add_child(se)
	var cb := CheckBox.new()
	cb.text = "В штаб"
	cb.tooltip_text = "Класть в штаб, а не игроку"
	cb.button_pressed = to_hq
	cb.toggled.connect(func(v): to_hq = v)
	row.add_child(cb)
	var all := UI.button("Всего по %d в штаб" % amount, func(): act("give_all", {"n": amount}), "По «сколько» каждого предмета в штаб")
	row.add_child(all)
	body.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, UI.fs(400))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3   # длинные названия руд не обрезаются
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	var ids: Array = DB.data.items.keys().filter(func(i): return not DB.is_fluid(i))
	ids.sort_custom(func(a, b): return DB.item_name(a) < DB.item_name(b))
	var q := item_q.strip_edges().to_lower()
	var shown := 0
	var more := 0
	for id in ids:
		if q != "" and not DB.item_name(id).to_lower().contains(q) and not str(id).contains(q):
			continue
		if shown >= ITEMS_MAX:
			more += 1
			continue
		shown += 1
		var iid: String = id
		var bt := _gbtn(grid, DB.item_name(iid), func(): act("give", {"to": target, "item": iid, "n": amount, "hq": to_hq}), "%s — выдать %d шт." % [DB.item_name(iid), amount])
		bt.custom_minimum_size = Vector2(UI.ws(250), UI.fs(34))
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tex := Icons.get_icon("item:" + iid)
		if tex:
			bt.icon = tex
			bt.expand_icon = true
			bt.add_theme_constant_override("icon_max_width", UI.fs(24))
	if shown == 0:
		grid.add_child(UI.small("Ничего не найдено"))
	if more > 0:
		body.add_child(UI.small("И ещё %d — уточните поиск." % more))
	if q != "":
		_focus.call_deferred(se)


## Категории зданий по порядку (только те, где есть строящиеся здания).
func _build_cats() -> Array:
	var have := {}
	for id in DB.data.buildings:
		var d: Dictionary = DB.data.buildings[id]
		if d.get("params", {}).get("buildable", true) and DB.data.categories.has(str(d.get("category", ""))):
			have[str(d.get("category", ""))] = true   # 1.1.15: без категории (развалины, капсулы) — не показываем
	var cats: Array = have.keys()
	cats.sort_custom(func(a, b): return int(DB.data.categories.get(a, {}).get("order", 99)) < int(DB.data.categories.get(b, {}).get("order", 99)))
	return cats


func _tab_builds(body: Control) -> void:
	var free: bool = game.flags.get("free_build", false)
	var row := UI.hbox(6)
	row.add_child(UI.label("Бесплатная стройка: %s" % ("включена" if free else "выключена"), 15))
	var me: int = net().my_id() if online() else 1
	row.add_child(UI.button("Выключить" if free else "Включить", func(): act("player", {"to": me, "set": {"free_build": not free}}), "Все здания открыты и ничего не стоят"))
	var se := LineEdit.new()
	se.placeholder_text = "Поиск здания…"
	se.text = build_q
	se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	se.text_changed.connect(func(t): build_q = t; _refresh_soon())
	row.add_child(se)
	body.add_child(row)
	var q := build_q.strip_edges().to_lower()
	var cats := _build_cats()
	if build_cat == "" or not build_cat in cats:
		build_cat = str(cats[0]) if not cats.is_empty() else ""
	if q == "":
		var cr := HFlowContainer.new()
		cr.add_theme_constant_override("h_separation", 4)
		cr.add_theme_constant_override("v_separation", 4)
		for cid in cats:
			var cc: String = cid
			cr.add_child(_tab_btn(str(DB.data.categories.get(cc, {}).get("name", cc)), cc == build_cat, func(): build_cat = cc; refresh()))
		body.add_child(cr)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, UI.fs(380))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var ids: Array = []
	for id in DB.data.buildings:
		var d: Dictionary = DB.data.buildings[id]
		if not d.get("params", {}).get("buildable", true):
			continue
		if not DB.data.categories.has(str(d.get("category", ""))):
			continue
		if q != "":
			if not str(d.get("name", id)).to_lower().contains(q) and not str(id).contains(q):
				continue
		elif str(d.get("category", "")) != build_cat:
			continue
		ids.append(id)
	ids.sort_custom(func(a, b): return str(DB.building(a).get("name", a)) < str(DB.building(b).get("name", b)))
	for id in ids:
		var bid: String = id
		var pick := func() -> void:
			if not game.flags.get("free_build", false):
				game.flags["free_build"] = true   # сразу у себя (у гостя хозяин ответит чуть позже)
				act("player", {"to": me, "set": {"free_build": true}})
			game.select_build(bid)
			game.hud.close("admin")
		var bt := _gbtn(grid, str(DB.building(bid).get("name", bid)), pick, "%s\n%s\n\nКлик — строить" % [DB.building(bid).get("name", bid), DB.building(bid).get("desc", "")])
		bt.custom_minimum_size = Vector2(UI.ws(190), UI.fs(48))
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tex := Icons.get_icon("building:" + bid)
		if tex:
			bt.icon = tex
			bt.expand_icon = true
			bt.add_theme_constant_override("icon_max_width", UI.fs(38))
		if not free and Tech.building_locked(bid):
			bt.modulate = Color(1, 1, 1, 0.6)
	if ids.is_empty():
		grid.add_child(UI.small("Ничего не найдено"))
	body.add_child(UI.small("Клик по зданию — строить (бесплатная стройка включится сама)."))
	if q != "":
		_focus.call_deferred(se)


func _focus(se: LineEdit) -> void:
	if is_instance_valid(se) and se.is_inside_tree() and se.is_visible_in_tree():
		se.grab_focus()
		se.caret_column = se.text.length()


func _tab_world(body: Control) -> void:
	body.add_child(UI.section("Время суток"))
	var g1 := _grid(body)
	for t in [["Утро", 0.27], ["День", 0.45], ["Вечер", 0.7], ["Ночь", 0.92]]:
		var tv: float = t[1]
		_gbtn(g1, t[0], func(): act("time", {"t": tv}))
	body.add_child(UI.section("Монстры"))
	var g2 := _grid(body, 3)
	_gbtn(g2, "Волны: вкл", func(): act("waves", {"on": true}))
	_gbtn(g2, "Волны: выкл", func(): act("waves", {"on": false}))
	_gbtn(g2, "Волна сейчас", func(): act("wave"))
	_gbtn(g2, "Убить всех монстров", func(): act("kill_all"))
	body.add_child(UI.section("Мир"))
	var g3 := _grid(body, 3)
	_gbtn(g3, "Открыть все технологии", func(): act("tech_all"))
	_gbtn(g3, "Сохранить мир", func(): act("save"))
	body.add_child(UI.section("Объявление всем"))
	var r4 := UI.hbox(6)
	var le := LineEdit.new()
	le.text = say_text
	le.placeholder_text = "Текст объявления…"
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t): say_text = t)
	le.text_submitted.connect(func(t): act("say", {"text": t}); say_text = ""; le.text = "")
	r4.add_child(le)
	r4.add_child(UI.button("Отправить", func(): act("say", {"text": say_text}); say_text = ""; le.text = ""))
	body.add_child(r4)
	body.add_child(UI.small("Всё, что делает администратор, записывается в журнал сервера."))
