extends Node
## Сетевая игра (кооператив). Один игрок создаёт комнату (хозяин), остальные находят её в списке комнат своей сети
## или подключаются по коду комнаты (в коде зашиты адрес и порт). 16: пароль, свои базы, права на чужие постройки,
## свои кошельки, торговля и подколы (coop.gd). Порт на роутере хозяин открывает сам через UPnP, если роутер даёт.
## Хозяин главный: он считает монстров, волны, события, рынок и хранит мир. Каждый игрок считает завод у себя
## (ленты и машины двигаются плавно), а хозяин раз в несколько секунд присылает точное содержимое зданий.
##  • Действия игроков (поставить, разобрать, повернуть, рецепт, забрать, положить, продать...) идут через game.cmd():
##    у подключившегося команда уходит хозяину вместе с рюкзаком игрока; хозяин выполняет её «от лица» этого игрока,
##    возвращает ему рюкзак и рассылает команду остальным.
##  • Монстры: хозяин присылает их положение 10 раз в секунду; удары игроков уходят хозяину.
##  • Игроки видят друг друга (ник и цвет над головой), есть чат (Enter) и список игроков.
## Узел — автозагрузка /root/Net, поэтому путь для вызовов одинаковый у всех.

const PORT := 24680              # запасной порт (если порт по умолчанию занят)
const OPEN_PORT := 443           # 1.0.8: порт по умолчанию — UDP 443 (как у QUIC/HTTP3): исходящие на него пускают почти все сети
const VERSION := 3            # 1.5: перенос вещей через хозяина, плавное движение — со старыми версиями не совместимо
const DISCOVERY_PORT := 24681    # 16: объявления комнат в локальной сети (UDP broadcast)
const CODE_ABC := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
## Команды, которые меняют общий мир: хозяин выполняет и рассылает всем.
const REPLICATED := ["place", "fuse", "detach", "demolish", "wire", "unwire", "reset_net", "rotate", "rotate_to", "junction_at", "bcfg", "bstate", "recipe", "drain", "tech_target", "zone_expand", "zone_patch", "coop_base", "paint", "repair", "ruin_extra"]
## 1.7: эти рассылаются остальным, только если у хозяина получилось (иначе у всех всплывает «нельзя»).
const MUST_SUCCEED := ["place", "fuse", "detach", "junction_at", "repair", "zone_expand", "zone_patch"]   # 1.1.15: зона — тоже
## Команды с рюкзаком игрока: хозяин выполняет от его лица и возвращает рюкзак.
const ACTOR := ["shore_salvage","shore_expand","shore_offer","shore_relight","shore_field","use_item", "take", "take_ready", "put", "put_all", "mv", "xmv", "take_slots", "btrash", "bag_up", "store_hq", "stash", "donate", "c_deliver", "sell", "buy", "pattern", "mbuy", "msell", "pay", "gift", "order_deal", "npc_trade"]
## 16: что нельзя делать с чужим зданием (правило комнаты «Чужие постройки»).
const OWN_CMDS := ["take", "take_ready", "take_slots", "xmv", "btrash", "drain", "demolish", "rotate", "rotate_to", "junction_at", "bcfg", "bstate", "recipe", "wire", "unwire", "reset_net", "fuse", "detach"]
const PUT_CMDS := ["put", "put_all"]

var mode := ""              # "" | "host" | "client"
var game = null             # main.gd, когда мир загружен
var join_addr := ""         # 1.3: куда подключились (сплитскрин ведёт второго игрока туда же)
var nick := "Игрок"
var color := "#ffa040"
var peers := {}             # id -> {nick, color}
var puppets := {}           # id -> RemotePlayer
var puppets2 := {}          # B-5 r8: id -> RemotePlayer второго игрока сплитскрина этого подключения
var _p2_sent := false
var saved := {}             # ник -> {pos, hp, inv} (хозяин помнит рюкзаки подключавшихся)
var applying := false       # сейчас применяется команда, пришедшая по сети
var actor := 0              # хозяин выполняет команду от лица этого игрока
var status := ""            # текст для меню: подключение, ошибка
var chat_log: Array = []    # [ник, цвет, текст]
var _acc_state := 0.0
var _acc_mon := 0.0
var _acc_world := 0.0
var _acc_bld := 0.0
var _acc_inv := 0.0
var _pending_t := -1.0        # 1.5: гость ждёт ответа хозяина на команду с вещами (секунды ожидания; -1 — не ждёт)
var _queue: Array = []        # 1.5: команды с вещами, которые уйдут следом
var _sent_n := 0              # B-1 r11: гость — сколько команд отправил хозяину
var _ack_n := 0               # B-1 r11: гость — на сколько пришёл ответ
var _done_n := {}             # B-1 r11: хозяин — id гостя -> сколько его команд выполнено
var _idle_cb: Array = []      # B-5/B-6 r11: гость — действия, ждущие, пока команды в пути получат ответ
var _stall_told := false
var _next_nid := 1
var _mon_by_nid := {}
var ui: CanvasLayer
var chat_box: VBoxContainer
var chat_edit: LineEdit
var list_lbl: Label
# 16: комнаты
var room := {}              # правила комнаты (у всех одинаковые; пароль знает только хозяин)
var password := ""          # хозяин: пароль комнаты; гость: пароль, который он отправит
var wallets := {}           # ник -> кредиты (правило «у каждого свои деньги»; хозяин)
var stores := {}            # ник -> Inventory: запасной склад, если аванпоста нет
var stats := {}             # ник -> {cr, bld, rep} — таблица игроков (хозяин рассылает)
var rep := {}               # ник -> репутация («спасибо»)
var banned := {}            # выгнанные ники (и "uid:…" — выгнанные игроки, 1.1.15)
var uids := {}              # 1.1.15: id подключения -> постоянный id игрока (только у хозяина, другим не рассылается)
var lan_rooms := {}         # "ip:порт" -> объявление комнаты
var lan_msg := ""
var ext_ip := ""            # внешний адрес (UPnP)
var upnp_msg := ""
var upnp_ok := false
var _upnp: UPNP
var _upnp_thread: Thread
var _bc: PacketPeerUDP
var _bc_t := 0.0
var _listen: PacketPeerUDP
var _join_t := -1.0
var _swap := {}             # пока хозяин выполняет команду гостя: {inv, credits} самого хозяина
var _vote := {}
var _thanks_t := {}
var _acc_stats := 0.0
var _empty := Inventory.new(1)
var _acc_mine := 0.0         # 18: гость шлёт хозяину свои вещи и прогресс
var _acc_save := 0.0         # 18: автосохранение мира комнаты у хозяина
var _save_soon := -1.0
var lobby: Node = null       # 18: общий список комнат в интернете (lobby.gd)
var slot_override := ""      # 18: ячейка мира этой комнаты (продолжение сетевого мира) — иначе создаётся новая
var port := PORT             # 1.0.8: порт этой комнаты (хозяин) или куда подключаемся (гость)
var port_msg := ""           # 1.0.8: «порт 443 занят — взял 24680»
var dedicated := false       # 1.0.9: выделенный сервер (--server): своего игрока нет, мир живёт для гостей
var server: Node = null      # 1.0.9: dedicated.gd — config, журнал, консоль


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): status = no_answer_text(); _reset())
	multiplayer.server_disconnected.connect(_on_server_gone)
	lobby = preload("res://scripts/lobby.gd").new()
	lobby.name = "Lobby"
	add_child(lobby)
	nick = str(Prefs.get_value("net_nick", "Игрок")) if Prefs.has_method("get_value") else "Игрок"
	color = str(Prefs.get_value("net_color", "#ffa040"))
	process_mode = Node.PROCESS_MODE_ALWAYS
	# для автотестов: --net_host (создать игру) и --net_join=адрес (подключиться)
	var args := OS.get_cmdline_user_args()
	# 1.0.9: выделенный сервер — без окна и своего героя, настройки из server.cfg
	for a in args:
		if a.begins_with("--server-write-config="):   # tools/build_server.sh: server.cfg по умолчанию
			preload("res://scripts/dedicated.gd").write_default(a.substr(22))
			print("server.cfg written: ", a.substr(22))
			get_tree().quit.call_deferred()
			return
	if args.has("--server") or OS.has_feature("server"):
		dedicated = true
		server = preload("res://scripts/dedicated.gd").new()
		server.name = "Server"
		add_child(server)
		return
	for a in args:
		if a.begins_with("--admin_test="):
			preload("res://scripts/admin_client.gd").run_test.call_deferred(self, a.substr(13))
		if a.begins_with("--dserver_client="):
			nick = "Гость"
			color = "#40c0ff"
			preload("res://scripts/dedicated.gd").client_test.call_deferred(self, a.substr(17))
		if a == "--net_host":
			# 16: проверочная комната с паролем, «только класть» и своими кошельками
			host(0, 8, {"name": "Проверка", "password": "123", "access": "put", "wallets": "own"} if args.has("--net_room_test") else
				({"name": "Стратегия", "ov": {"settings/strategy": true}} if args.has("--net_strategy") else {}))
		elif a.begins_with("--net_join="):
			nick = "Гость"
			color = "#40c0ff"
			var pw := ""
			for b in args:
				if b.begins_with("--nick="):
					nick = b.substr(7)     # 1.3: второй игрок сплитскрина
					color = "#7dff5a"
				elif b.begins_with("--net_pass="):
					pw = b.substr(11)
			join(a.substr(11), 0, pw)
		elif a == "--net_find":
			nick = "Гость"
			color = "#40c0ff"
			_find_test.call_deferred()


static func active() -> bool:
	return Engine.get_main_loop() != null and _self() != null and _self().mode != ""


static func is_host() -> bool:
	var n = _self()
	return n != null and n.mode == "host"


static func is_client() -> bool:
	var n = _self()
	return n != null and n.mode == "client"


static func _self():
	var ml = Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("Net")
	return null


func my_id() -> int:
	return multiplayer.get_unique_id() if mode != "" else 1


# ---------------------------------------------------------------- создать / подключиться / выйти

## Правила новой комнаты по умолчанию («Правила игры → coop»).
static func room_defaults() -> Dictionary:
	var c: Dictionary = DB.setting("coop", {})
	var out := {"name": "", "public": true, "max_players": int(c.get("max_players", 8))}
	for k in ["start", "access", "wallets", "trade", "pranks", "upnp", "shared_scan", "punch"]:
		out[k] = c.get(k, {"start": "together", "access": "put", "wallets": "own", "trade": true, "pranks": true, "upnp": true, "shared_scan": true, "punch": true}[k])
	out["port"] = default_port()
	out["modules"] = {}
	return out


## 1.0.8: порт по умолчанию: --port=N, потом «Порт» из меню (Prefs net_port), потом правило «Сетевая игра → Порт» (443).
static func default_port() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			return clampi(int(a.substr(7)), 1, 65535)
	var pp := int(Prefs.get_value("net_port", 0))
	if pp > 0 and pp < 65536:
		return pp
	var c = DB.setting("coop", {})
	var cp := int(c.get("port", OPEN_PORT)) if c is Dictionary else OPEN_PORT
	return cp if cp > 0 and cp < 65536 else PORT


## Создать комнату. rm — правила из меню (name, public, password, max_players, start, access, wallets, modules, port...).
## port 0 — порт комнаты из правил (rm.port) или порт по умолчанию. Занят — берётся запасной 24680.
func host(want_port := 0, max_players := 8, rm := {}) -> String:
	_reset()
	slot_override = ""
	room = room_defaults()
	room["max_players"] = max_players
	room.merge(rm, true)
	password = str(room.get("password", ""))
	room.erase("password")
	room["has_pass"] = password != ""
	room["host"] = nick
	if str(room.get("name", "")) == "":
		room["name"] = "Комната %s" % nick
	port = want_port if want_port > 0 else (int(room.get("port", 0)) if int(room.get("port", 0)) > 0 else default_port())
	port_msg = ""
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, int(room.max_players) + 2)
	if err != OK and port != PORT:
		# порт занят другой программой — берём запасной, а игроку говорим, какой вышел
		var busy := port
		p = ENetMultiplayerPeer.new()
		port = PORT
		err = p.create_server(port, int(room.max_players) + 2)
		if err == OK:
			port_msg = "Порт %d занят другой программой — комната открыта на порту %d." % [busy, port]
	if err != OK:
		return "Не удалось открыть порт %d (занят? уже запущена другая игра?). Укажите другой порт." % port
	room["port"] = port
	multiplayer.multiplayer_peer = p
	mode = "host"
	peers = {1: {"nick": nick, "color": color, "look": Player.my_look() if server == null else ""}}
	if dedicated:
		peers = {}               # у выделенного сервера своего игрока нет — места только для гостей
		room["dedicated"] = true
	wallets.clear()
	stores.clear()
	rep.clear()
	banned.clear()
	status = "Комната «%s» создана" % room.name + ((" · " + port_msg) if port_msg != "" else "")
	if bool(room.get("public", true)):
		_bc = PacketPeerUDP.new()
		_bc.set_broadcast_enabled(true)
		_bc.bind(0)
	if bool(room.get("upnp", true)) and not OS.get_cmdline_user_args().has("--no_upnp"):
		_start_upnp(port)
	return ""


## Подключиться: код комнаты (ABCDE-FGHJK), адрес или адрес:порт. to_port 0 — порт по умолчанию.
## 1.0.8: адрес в интернете — сначала «пробой роутера» (lobby.gd): хозяин сам шлёт пакет навстречу, и роутеры
## пропускают соединение без UPnP и ручного открытия порта (работает с большинством домашних роутеров).
func join(addr: String, to_port := 0, pw := "", punch := true) -> String:
	_reset()
	var a := addr.strip_edges()
	var pt := to_port if to_port > 0 else default_port()
	var dec := decode_code(a)
	if not dec.is_empty():
		a = dec[0]
		pt = dec[1]
	elif a.count(":") == 1:
		pt = int(a.get_slice(":", 1))
		a = a.get_slice(":", 0)
	if a == "" or not (a.is_valid_ip_address() or a.contains(".")) or pt <= 0 or pt > 65535:
		return "Неверный код или адрес"
	password = pw
	port = pt
	if punch and lobby != null and lobby.can_punch(a):
		status = "Пробиваю путь через роутер к %s:%d…" % [a, pt]
		lobby.punch_join(a, pt)       # сам вызовет join_direct
		return ""
	return join_direct(a, pt, 0)


## Подключиться прямо (local_port — свой порт, через который уже «пробит» роутер).
func join_direct(a: String, pt: int, local_port := 0) -> String:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer = null
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(a, pt, 0, 0, 0, local_port)
	if err != OK and local_port != 0:
		err = p.create_client(a, pt)
	if err != OK:
		mode = ""
		status = "Неверный адрес"
		return status
	multiplayer.multiplayer_peer = p
	mode = "client"
	port = pt
	join_addr = "%s:%d" % [a, pt]
	_join_t = 0.0
	status = "Подключение к %s:%d..." % [a, pt]
	return ""


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	if upnp_ok and _upnp != null:
		_upnp.delete_port_mapping(port, "UDP")
	upnp_ok = false
	_reset()
	# B-8 r6: записи игроков, кошельки и баны — принадлежат комнате; новая комната начинается с чистого листа
	saved.clear()
	wallets.clear()
	uids.clear()
	_vote = {}   # B-2 r7


func _reset() -> void:
	if multiplayer.multiplayer_peer != null and mode != "":
		multiplayer.multiplayer_peer = null
	mode = ""
	_join_t = -1.0
	_pending_t = -1.0
	_queue.clear()
	_seat_q.clear()
	_sent_n = 0
	_ack_n = 0
	_done_n.clear()
	_idle_cb.clear()
	_stall_told = false
	_debt.clear()
	_early_hello.clear()
	_bc = null
	if lobby != null:
		lobby.cancel_punch()
	peers.clear()
	for id in puppets:
		if is_instance_valid(puppets[id]):
			puppets[id].queue_free()
	puppets.clear()
	for id in puppets2:
		if is_instance_valid(puppets2[id]):
			puppets2[id].queue_free()
	puppets2.clear()
	_p2_sent = false
	_mon_by_nid.clear()


## Загрузка мира у гостя может «подвесить» игру на десяток секунд — не рвём связь из-за этого.
func _long_timeout(pid: int) -> void:
	var mp = multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var pr: ENetPacketPeer = mp.get_peer(pid)
		if pr:
			pr.set_timeout(64, 45000, 90000)


func _on_connected() -> void:
	_long_timeout(1)
	_join_t = -1.0
	status = "Подключено, получаем мир..."
	rpc_id(1, "hello", nick, color, VERSION, DB.game_name(), DB.game_version(), password, my_uid())
	rpc_id(1, "set_look", Player.my_look())


func _on_server_gone() -> void:
	status = "Хозяин игры отключился"
	if Prefs.split == "right":
		get_tree().quit()   # 1.3: окно второго игрока сплитскрина закрывается вместе с игрой первого
		return
	var g = game
	_reset()
	if g != null and is_instance_valid(g):
		g.notify("Связь с хозяином игры потеряна. Игра продолжается без сети", Color(1, 0.5, 0.4))


func _on_peer_connected(id: int) -> void:
	if mode == "host":
		_long_timeout(id)   # дальше ждём hello


func _on_peer_disconnected(id: int) -> void:
	if not peers.has(id):
		return
	var nm: String = peers[id].nick
	if mode == "host" and puppets.has(id):
		var pp = puppets[id]
		var rec: Dictionary = saved.get(nm, {})
		_merge_puppet(rec, pp)
		if str(uids.get(id, "")) != "":
			rec["uid"] = str(uids[id])
		saved[nm] = rec
		_save_soon = 1.0
	# 1.1.15: на выделенном сервере права по паролю — только на время подключения (иначе любой с тем же ником стал бы админом)
	if mode == "host" and game != null and game.admin != null:   # A-20: и в обычной комнате (ник ничем не защищён)
		game.admin.admin_nicks.erase(nm)
		game.admin.free_nicks.erase(nm)
	peers.erase(id)
	uids.erase(id)
	_done_n.erase(id)
	if puppets.has(id):
		puppets[id].queue_free()
		puppets.erase(id)
	_drop_p2(id)
	if mode == "host":
		rpc("peer_left", id)
	_note("%s вышел из игры" % nm)
	if server != null:
		server.on_left()


# ---------------------------------------------------------------- вход в мир

## Подключившийся представился. Хозяин присылает ему мир целиком (как сохранение), но с его рюкзаком.
@rpc("any_peer", "call_remote", "reliable")
func hello(n: String, c: String, ver: int, gname: String, gver: String, pw := "", uid := "") -> void:
	if mode != "host":
		return
	var id := multiplayer.get_remote_sender_id()
	if game == null:
		# B-1 r8: мир ещё грузится — гость получит его, как только мир будет готов (раньше висел вечно)
		if _early_hello.size() < 64:
			_early_hello.append([id, [n, c, ver, gname, gver, pw, uid]])
		return
	_early_hello = _early_hello.filter(func(e): return int(e[0]) != id)
	_hello_do(id, n, c, ver, gname, gver, pw, uid)


var _early_hello: Array = []

func _replay_hello() -> void:
	var q := _early_hello.duplicate()
	_early_hello.clear()
	for e in q:
		if game == null or mode != "host":
			return
		if multiplayer.multiplayer_peer == null or not multiplayer.get_peers().has(int(e[0])) or peers.has(int(e[0])):
			continue   # уже отключился или уже принят
		var a: Array = e[1]
		_hello_do(int(e[0]), a[0], a[1], a[2], a[3], a[4], a[5], a[6])


func _hello_do(id: int, n: String, c: String, ver: int, gname: String, gver: String, pw: String, uid: String) -> void:
	uid = uid.strip_edges().left(40)
	n = n.replace("[", "(").replace("]", ")").strip_edges().left(24)   # A-21: без разметки в нике
	if n == "" or n in ["Сервер", "Сеть", "Администратор"]:
		n = "Игрок"   # B-9 r3: служебные имена — не для игроков
	if not c.is_valid_html_color() or c.contains("]") or c.contains("["):
		c = "#ffffff"
	var why := ""
	if ver != VERSION or gname != DB.game_name() or gver != DB.game_version():
		why = "Другая версия игры: у хозяина %s %s" % [DB.game_name(), DB.game_version()]
	elif (uid == "" and banned.has(n)) or (uid != "" and banned.has("uid:" + uid)):
		why = "Вас выгнали из этой комнаты"
	elif password != "" and pw != password:
		why = "Неверный пароль комнаты"
	elif peers.size() - _ghosts_of(uid) >= int(room.get("max_players", 8)):
		why = "Комната заполнена (%d из %d)" % [peers.size(), int(room.get("max_players", 8))]
	if why != "":
		set_meta("refused_n", int(get_meta("refused_n", 0)) + 1)
		if server != null:
			server.log_line("Отказ игроку %s: %s" % [n, why])
		rpc_id(id, "refused", why)
		get_tree().create_timer(1.0).timeout.connect(func():
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer and mode == "host":
				(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id))
		return
	n = _assign_nick(n, uid, id)
	if server != null:
		server.wake()   # будим мир только принятому игроку, и уже после замены «висящего» подключения (B-10 r3)
	peers[id] = {"nick": n, "color": c}
	uids[id] = uid
	if own_wallets() and not wallets.has(n) and not _uid_has_record(uid, n):
		wallets[n] = int(DB.setting("coop", {}).get("start_credits", 150))
	elif own_wallets() and not wallets.has(n):
		wallets[n] = 0   # B-3 r10: тот же игрок (uid) под новым ником — стартовые деньги уже получал
	if separate() and not saved.has(n) and game.coop.outpost_of(n) == null:
		_make_base(n)
	var data: Dictionary = game.save_dict()
	data["player"] = _player_record(n)
	# 18: вернувшийся игрок получает свой уровень, навыки, профессию — как оставил
	var ext: Dictionary = saved.get(n, {}).get("me", {})
	data["pick_prof"] = not ext.has("profession")   # новый игрок выбирает профессию, вошедший раньше — со своей
	# 1.1.15: новый гость начинает с нуля, а не с копией хозяйского героя (уровень, очки, профессия, зелья)
	var fresh := {"level": 1, "xp": 0.0, "skill_points": 0, "skills": {}, "attrs": {}, "attr_points": 0, "profession": "engineer"}
	for k in ["level", "xp", "skill_points", "skills", "attrs", "attr_points", "profession", "quest_i", "tutorial"]:
		if ext.has(k):
			data[k] = ext[k]
		elif fresh.has(k):
			data[k] = fresh[k]
	data["effects"] = ext.get("effects", {})
	data["trade_earned"] = int(ext.get("trade_earned", 0))
	# 1.1.15: личное хозяина — не гостю: очередь крафта, вещи на земле и могилы (иначе предметы удваивались)
	data["craft_queue"] = ext.get("craft_queue", [])
	data["drops"] = []
	data.erase("net_players")   # записи других игроков (их рюкзаки) гостю не нужны
	data["split2"] = ext.get("split2", {})   # B-3 r8: второй игрок хозяина — не гостю; свой второй игрок гостя — ему
	# A-3/A-4: заказы, озноб, метки, вездеход и могила — у каждого свои (раньше гость получал хозяйские, а свою могилу терял)
	data["graves"] = ext.get("graves", [])
	data["orders"] = ext.get("orders", {})
	data["climate"] = ext.get("climate", {})
	data["marks"] = ext.get("marks", [])
	data["vehicle"] = ext.get("vehicle", {})
	# B-2 r4: счётчики для заданий у каждого свои (доставки, заработок, убитые)
	data["delivered"] = ext.get("delivered", {})
	data["earned"] = int(ext.get("earned", 0))
	data["kills"] = int(ext.get("kills", 0))
	if data.get("hazards") is Dictionary:
		var hz: Dictionary = (data.hazards as Dictionary).duplicate(true)
		hz["dose"] = float(ext.get("dose", 0.0))   # B-8 r3: доза радиации у каждого своя
		data["hazards"] = hz
	# 1.7: задания и обучение у каждого игрока свои (раньше гость получал хозяйские и задания засчитывались заново)
	if not ext.has("quest_i"):
		# A-1: новый гость на уже развитой общей базе не получает награды за задачи, которые сделали другие
		var qi := 0
		if not separate():
			qi = 0 if dedicated else int(game.quest_i)
			for sn in saved:
				if saved[sn] is Dictionary:
					qi = maxi(qi, int(saved[sn].get("me", {}).get("quest_i", 0)))
		data["quest_i"] = qi
	if not ext.has("tutorial"):
		data["tutorial"] = {"step": 0, "done": not bool(DB.data.settings.get("tutorial", {}).get("enabled", true)), "walked": 0.0}
	# изученное у каждого своё: гость получает своё (новый гость — с нуля), а не хозяйское
	if not shared_scan():
		data["scan"] = ext.get("scan", {"known": [], "researched": [], "prog": {}})
	data["net"] = {"peers": peers, "you": id, "room": room}
	if own_wallets():
		data["credits"] = int(wallets[n])
	var bytes := var_to_bytes(data).compress(FileAccess.COMPRESSION_ZSTD)
	rpc_id(id, "welcome", bytes, var_to_bytes(data).size())
	rpc("peer_joined", id, n, c)
	_spawn_puppet(id)
	if uid != "" and saved.has(n):
		saved[n]["uid"] = uid
	_note("%s подключился" % n)
	_save_soon = 3.0


## 1.1.15: постоянный id игрока (A-6): вернувшийся после обрыва входит тем же игроком, а не «ник NN» с нуля.
func my_uid() -> String:
	var u := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uid="):
			return a.substr(6)
	var real := DisplayServer.get_name() != "headless" and not " ".join(OS.get_cmdline_user_args()).contains("--test")
	if not real:
		if not has_meta("uid"):
			set_meta("uid", "t%08x%08x" % [randi(), randi()])   # тесты: у каждой копии игры свой
		return str(get_meta("uid"))
	u = str(Prefs.get_value("net_uid", ""))
	if u == "":
		u = "%08x%08x" % [randi(), randi()]
		Prefs.values["net_uid"] = u
		Prefs.save_file()
	return u + ("-r" if Prefs.split == "right" else "")


## Ник для вошедшего: свой, если свободен; тот же игрок с «висящим» старым подключением — заменяет его;
## занятый другим — постоянное «ник N» (тот же номер при каждом входе этого игрока).
func _assign_nick(n: String, uid: String, id: int) -> String:
	# B-3 r9: тот же игрок (uid) вернулся, а старое подключение ещё висит — заменить его, под каким бы ником оно ни было
	if uid != "":
		for k in peers.keys():
			if k != 1 and k != id and str(uids.get(k, "")) == uid:
				var old_nick := str(peers[k].nick)
				_on_peer_disconnected(k)
				if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
					(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(k)
				return old_nick
	var holder := -1
	for k in peers:
		if peers[k].nick == n:
			holder = k
	if holder < 0 and n != nick and str(saved.get(n, {}).get("uid", "")) in ["", uid]:   # B-4 r4: и пустой uid чужую запись не получает
		return n   # B-2 r3: ник занят записью другого игрока (другой uid) — ему «ник N», а не чужие вещи
	if holder >= 0 and holder != 1 and uid != "" and str(uids.get(holder, "")) == uid:
		_on_peer_disconnected(holder)   # тот же игрок вернулся, старое подключение ещё не отвалилось
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(holder)
		return n
	if uid != "":
		for sn in saved:
			if str(saved[sn].get("uid", "")) == uid and str(sn).begins_with(n) and not _nick_busy(str(sn)):
				return str(sn)
	for k in range(2, 1000):
		var cand := "%s %d" % [n, k]
		if not _nick_busy(cand) and (not saved.has(cand) or (uid != "" and str(saved[cand].get("uid", "")) == uid)) and not banned.has(cand):
			return cand
	return "%s %d" % [n, id]


## B-3 r10: у этого uid уже есть запись под другим ником.
func _uid_has_record(uid: String, n: String) -> bool:
	if uid == "":
		return false
	for sn in saved:
		if str(sn) != n and str(saved[sn].get("uid", "")) == uid:
			return true
	return false


## B-7 r8: «висящие» подключения этого же игрока (вылетел и сразу зашёл) — их место освободится.
func _ghosts_of(uid: String) -> int:
	if uid == "":
		return 0
	var k := 0
	for pid in peers:
		if pid != 1 and str(uids.get(pid, "")) == uid:
			k += 1
	return k


func _nick_busy(n: String) -> bool:
	if n == nick:
		return true
	for k in peers:
		if peers[k].nick == n:
			return true
	return false


func _player_record(n: String) -> Dictionary:
	if saved.has(n):
		var r: Dictionary = saved[n]
		var me: Dictionary = r.get("me", {})
		var out := {"pos": r.get("pos", me.get("pos", [0, 0])), "hp": r.get("hp", me.get("hp", 200)), "food": me.get("food", 100), "water": me.get("water", 100),
			"inv": r.get("inv", me.get("inv", [])), "hot_builds": me.get("hot_builds", []), "selected": me.get("selected", 0)}
		for k in ["clothes", "bag","hot_items"]:
			if me.has(k):
				out[k] = me[k]
		return out
	var inv := Inventory.new(36)
	if game.island != null: inv.add("salvage_rod",1)
	for k in DB.data.world.get("start_inventory", {}):
		inv.add(k, int(DB.data.world.start_inventory[k]))
	var hp: Vector3 = game.factory.hq.center() if game.factory.hq else game.player.position
	var ob = game.coop.outpost_of(n) if separate() else null
	if ob != null:
		hp = ob.center()
	var entry: Vector3 = game.island.landing() if game.island != null else hp+Vector3(randf_range(-6,6),0,8)
	return {"pos": [entry.x,entry.z], "hp": 200, "food": 100, "water": 100, "inv": inv.to_array(), "hot_builds": [], "selected": 0}


@rpc("authority", "call_remote", "reliable")
func refused(why: String) -> void:
	status = why
	set_meta("refused", why)
	leave()


@rpc("authority", "call_remote", "reliable")
func welcome(bytes: PackedByteArray, raw_size: int) -> void:
	var data = bytes_to_var(bytes.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
	if not data is Dictionary:
		status = "Мир не загрузился"
		leave()
		return
	peers = {}
	room = data.get("net", {}).get("room", {})
	var np: Dictionary = data.get("net", {}).get("peers", {})
	for k in np:
		peers[int(k)] = np[k]
	var you := int(data.get("net", {}).get("you", 0))
	if peers.has(you):
		nick = str(peers[you].nick)   # B-3 r3: хозяин мог переименовать («Игрок 2») — права на здания по этому нику
	status = "Загрузка мира..."
	DB.set_meta("new_game", {"save": data, "profession": data.get("profession", "engineer")})
	LoadingScreen.go(get_tree(), "res://scenes/main.tscn")


## Мир загружен (main.gd вызывает в конце _ready).
func attach(g) -> void:
	game = g
	if mode == "host" and not _early_hello.is_empty():
		get_tree().create_timer(3.0).timeout.connect(_replay_hello)   # B-1 r8: мир готов — через пару секунд, когда всё встанет на места
	# 1.1.15: команды хозяина, пришедшие пока мир гостя грузился, применяем сейчас (раньше терялись насовсем)
	if mode == "client" and not _pend.is_empty():
		var q := _pend.duplicate()
		_pend.clear()
		_replay_pend.call_deferred(q)
	lan_listen(false)
	if lobby:
		lobby.listing = false
	if mode == "":
		return
	_build_ui()
	if server != null:
		server.on_world(g)
	if mode == "host" and separate() and g.factory.hq:
		g.factory.hq.bstate["owner"] = nick   # штаб — база хозяина
	if mode == "host" and not dedicated:
		# B-8 r4: мир продолжен из одиночной игры — старые постройки хозяина без владельца становятся его
		for b in g.factory.all:
			if not b.dead and str(b.bstate.get("owner", "")) == "" and not b.p("wild", false) and b != g.factory.hq:
				b.bstate["owner"] = nick
	for id in peers:
		if id != my_id():
			_spawn_puppet(id)
	if mode == "client":
		g.notify("Вы в сетевой игре. Enter — чат", Color(0.6, 0.9, 1))
		# новый игрок на сервере выбирает профессию (раньше у всех гостей был «Инженер» без выбора)
		var ngm = DB.get_meta("new_game", {}) if DB.has_meta("new_game") else {}
		if ngm is Dictionary and bool(ngm.get("save", {}).get("pick_prof", false)) and g.module("professions") \
				and not DB.data.get("professions", {}).is_empty() and not OS.get_cmdline_user_args().has("--net_test=client"):
			preload("res://scripts/ui/prof_pick.gd").open.call_deferred(g)
		if OS.get_cmdline_user_args().has("--net_test=client"):
			_client_test.call_deferred()
		if OS.get_cmdline_user_args().has("--net_strat_probe"):
			_strat_probe.call_deferred(g)
		if OS.get_cmdline_user_args().has("--net_chest_probe"):
			_chest_probe.call_deferred(g)
		if OS.get_cmdline_user_args().has("--net_craft_probe"):
			_craft_probe.call_deferred(g)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--dserver_client="):
				preload("res://scripts/dedicated.gd").client_check.call_deferred(self, g)


## 1.1.20: гость смотрит ящик составного (конструктор + ящик): число не прыгает назад, «Забрать всё» кладёт в рюкзак.
func _chest_probe(g) -> void:
	var f = g.factory
	var h = null
	for i in 600:
		await get_tree().create_timer(0.1).timeout
		for b in f.all:
			if not b.dead and b.type == "constructor" and Fusion.chest_of(b) != null:
				h = b
		if h != null:
			break
	if h == null:
		for b in f.all:
			if not b.dead and b.type in ["constructor", "chest", "generator"]:
				print("HUNT guest sees ", b.type, " ", b.cell, " subs=", b.subs.size())
		print("TEST chest_guest120 FAIL(no composite)")
		get_tree().quit()
		return
	var last := -1
	var drops := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000:
		var n: int = Fusion.chest_of(h).inv.count("iron_rod")
		if n < last:
			drops += 1
		last = n
		await get_tree().process_frame
	for i in g.player.inv.slots.size():
		g.player.inv.slots[i] = null
	g.player.position = h.center() + Vector3(2, 0, 0)
	send_my_state()
	await get_tree().create_timer(1.0).timeout
	room["access"] = "all"   # комната «можно брать чужое» (у хозяина то же)
	var before: int = Fusion.chest_of(h).inv.count("iron_rod")
	print("HUNT guest take pending=", _pending_t, " q=", _queue.size())
	var tr = g.cmd("take", {"b": h})
	print("HUNT guest take ret=", tr, " pending=", _pending_t, " q=", _queue.size())
	await get_tree().create_timer(4.0).timeout
	var got: int = g.player.inv.count("iron_rod")
	var after: int = Fusion.chest_of(h).inv.count("iron_rod")
	var ok: bool = drops == 0 and before >= 5 and got >= before and after < before
	print("TEST chest_guest120 drops=", drops, " before=", before, " got=", got, " chest_after=", after, " ", "OK" if ok else "FAIL")
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()


## Проверка: гость крафтит и одновременно строит — вещи не должны выпадать на землю.
func _craft_probe(g) -> void:
	await get_tree().create_timer(4.0).timeout
	for c in g.get_children():
		if c is CanvasLayer and c.layer == 20:
			c.queue_free()
	var pl = g.player
	pl.inv.add("fiber", 30)
	pl.inv.add("log", 40)
	pl.inv.add("stone", 40)
	send_my_state()
	await get_tree().create_timer(1.0).timeout
	g.queue_craft("rope", 8, "hand")
	var base := World.world_to_cell(pl.position)
	for k in 6:
		await get_tree().create_timer(0.9).timeout
		g.cmd("place", {"type": "workbench", "cell": base + Vector2i(4 + k * 3, 5), "dir": 0})
	await get_tree().create_timer(12.0).timeout
	var inv := []
	for sl in pl.inv.slots:
		if sl != null:
			inv.append([sl.id, sl.n])
	var dr: Array = g.drops.list.map(func(d): return [d.id, d.n])
	print("TEST craft_guest115 inv=", inv, " drops=", dr, " ", "OK" if dr.is_empty() else "FAIL")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()


## Проверка: гость в комнате «Стратегия» — режим пришёл от хозяина, героя не видно, профессию спрашивают при входе.
func _strat_probe(g) -> void:
	await get_tree().create_timer(3.0).timeout
	var pick_open := false
	for c in g.get_children():
		if c is CanvasLayer and c.layer == 20 and c.get_child_count() >= 2:
			pick_open = true
	var ids: Array = DB.data.professions.keys()
	ids.sort()
	var want: String = "miner" if DB.data.professions.has("miner") else str(ids[-1])
	preload("res://scripts/ui/prof_pick.gd").choose(g, want, null)
	await get_tree().create_timer(2.0).timeout
	var ok: bool = g.strategy and not g.player.visible and pick_open and g.profession == want
	print("TEST strat_guest115 strategy=", g.strategy, " hidden=", not g.player.visible, " pick_open=", pick_open, " prof=", g.profession, " ", "OK" if ok else "FAIL")
	await get_tree().create_timer(6.0).timeout
	get_tree().quit()


var _pend: Array = []   # 1.1.15: [имя метода, аргументы] — пришло до загрузки мира


func _hold(fn: String, args: Array) -> void:
	if mode == "client" and _pend.size() < 4000:
		_pend.append([fn, args])


func _replay_pend(q: Array) -> void:
	for e in q:
		if game == null:
			return
		callv(str(e[0]), e[1])


func detach() -> void:
	game = null
	_pend.clear()
	for id in puppets:
		if is_instance_valid(puppets[id]):
			puppets[id].queue_free()
	puppets.clear()
	_mon_by_nid.clear()
	if ui:
		ui.queue_free()
		ui = null


@rpc("authority", "call_remote", "reliable")
func peer_joined(id: int, n: String, c: String) -> void:
	peers[id] = {"nick": n, "color": c}
	if id != my_id():
		_spawn_puppet(id)
		_note("%s подключился" % n)


@rpc("authority", "call_remote", "reliable")
func peer_left(id: int) -> void:
	_on_peer_disconnected(id)


## 1.3: модель героя игрока (выбор в меню «Герой»): гость сообщает хозяину, хозяин — всем.
@rpc("any_peer", "call_remote", "reliable")
func set_look(l: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode != "host":
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id) or str(peers[id].get("look", "")) == l:
		return
	peers[id]["look"] = l
	rpc("look_of", id, l)
	_relook(id)


@rpc("authority", "call_remote", "reliable")
func look_of(id: int, l: String) -> void:
	if not peers.has(id):
		return
	peers[id]["look"] = l
	_relook(id)


## Пересобрать героя другого игрока с новой моделью (на том же месте).
func _relook(id: int) -> void:
	if not puppets.has(id) or not is_instance_valid(puppets[id]):
		return
	var old = puppets[id]
	if old.look == str(peers[id].get("look", "")):
		return
	puppets.erase(id)
	_spawn_puppet(id)
	if puppets.has(id):
		puppets[id].position = old.position
		puppets[id].rotation = old.rotation
		puppets[id].net_pos = old.net_pos
		puppets[id].net_yaw = old.net_yaw
	old.queue_free()


func _spawn_puppet(id: int) -> void:
	if game == null or puppets.has(id) or id == my_id() or not peers.has(id):
		return
	var pp = preload("res://scripts/remote_player.gd").new()
	pp.game = game
	pp.peer = id
	pp.nick = peers[id].nick
	pp.look = str(peers[id].get("look", ""))
	pp.tint = DB.color(peers[id].color)
	game.add_child(pp)
	pp.build()
	pp.setup_label()
	pp.position = game.player.position + Vector3(3, 0, 3)
	puppets[id] = pp


## 18: изученное в сканере — общее для комнаты (раньше у каждого своё, и списки рецептов у друзей были короче).
func share_research(id: String) -> void:
	if not shared_scan():
		return
	if mode == "host":
		rpc("research_sync", id)
	elif mode == "client":
		rpc_id(1, "research_req", id)


## Правило комнаты «Изученное в сканере — общее» (по умолчанию да).
func shared_scan() -> bool:
	return mode != "" and bool(room.get("shared_scan", true))


@rpc("any_peer", "call_remote", "reliable")
func research_req(id: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode != "host" or not shared_scan() or not DB.data.items.has(id):
		return
	_research_apply(id)
	rpc("research_sync", id)


@rpc("authority", "call_remote", "reliable")
func research_sync(id: String) -> void:
	if game == null:
		_hold("research_sync", [id])   # B-2 r9: мир ещё грузится — иначе загрузка сотрёт изученное
		return
	_research_apply(id)


func _research_apply(id: String) -> void:
	if DB.researched.has(id) or not DB.data.items.has(id):
		return
	DB.known[id] = true
	DB.researched[id] = true
	if game != null and is_instance_valid(game):
		game.notify("Изучено в команде: %s" % DB.item_name(id), Color(0.5, 1.0, 0.6))
		game.hud.refresh_open()


## 18: ячейка сохранения мира этой комнаты.
func room_slot() -> String:
	if slot_override != "":
		return slot_override
	var nm := str(room.get("name", "")).strip_edges()
	if nm == "":
		nm = "Комната %s" % nick
	var safe := nm.validate_filename().replace(" ", "_").replace(".", "_")
	# новый мир — новая ячейка (старый мир этой же комнаты не затирается)
	slot_override = "net_%s_%s" % [safe.left(32), Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")]
	return slot_override


## 18: гость → хозяину: мои вещи, уровень, навыки (каждые 20 с, при сохранении и при выходе).
func send_my_state() -> void:
	if mode != "client" or game == null or not is_instance_valid(game):
		return
	var st: Dictionary = game.personal_state()
	rpc_id(1, "my_state", var_to_bytes(st).compress(FileAccess.COMPRESSION_ZSTD), var_to_bytes(st).size(), _ack_n)


@rpc("any_peer", "call_remote", "reliable")
func my_state(bytes: PackedByteArray, raw: int, ack := -1) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode != "host":
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	var st = bytes_to_var(bytes.decompress(raw, FileAccess.COMPRESSION_ZSTD))
	if not st is Dictionary:
		return
	var nm := str(peers[id].nick)
	var rec: Dictionary = saved.get(nm, {})
	if _stale_report(id, ack):
		# B-1 r11: отчёт ушёл до ответа на уже выполненную команду (положил и сразу вышел) — его рюкзак
		# ещё со стопкой; берём рюкзак, каким он стал у хозяина после этой команды
		var pp = puppets.get(id)
		var fresh: Array = pp.last_inv if pp != null and not (pp.last_inv as Array).is_empty() else rec.get("inv", [])
		st["inv"] = fresh
		# B12-1: и рюкзак второго игрока гостя — каким он стал у хозяина после команды
		var old2 = rec.get("me", {}).get("split2", {})
		if st.get("split2") is Dictionary and old2 is Dictionary and old2.has("inv"):
			st["split2"]["inv"] = old2.inv
	rec["me"] = st
	rec["inv"] = st.get("inv", rec.get("inv", []))
	rec["inv_ms"] = Time.get_ticks_msec()
	rec["pos"] = st.get("pos", rec.get("pos", [0, 0]))
	rec["hp"] = st.get("hp", rec.get("hp", 200))
	saved[nm] = rec


## B-1 r11: отчёт гостя отправлен раньше, чем он получил ответ на последнюю выполненную хозяином команду.
func _stale_report(id: int, ack: int) -> bool:
	return ack >= 0 and ack < int(_done_n.get(id, 0))


## 1.1.15: рюкзак гостя в записи — только если отчёт марионетки свежее того, что гость прислал сам
## (раньше на выходе запись перетиралась устаревшим, а у только что вошедшего — пустым рюкзаком).
func _merge_puppet(rec: Dictionary, pp) -> void:
	rec["pos"] = [pp.position.x, pp.position.z]
	rec["hp"] = pp.hp
	var pms := int(pp.get_meta("inv_ms", -1))
	if pms >= 0 and not (pp.last_inv as Array).is_empty() and pms > int(rec.get("inv_ms", -1)):
		rec["inv"] = pp.last_inv
		rec["inv_ms"] = pms
		if pp.has_meta("graves"):
			var me: Dictionary = rec.get("me", {})
			me["graves"] = pp.get_meta("graves")
			rec["me"] = me


## Хозяин запоминает рюкзаки игроков в сохранении.
func players_save() -> Dictionary:
	var out := saved.duplicate(true)
	for id in puppets:
		var pp = puppets[id]
		var rec: Dictionary = out.get(pp.nick, {})
		_merge_puppet(rec, pp)
		if str(uids.get(id, "")) != "":
			rec["uid"] = str(uids[id])   # B-1 r5: запись игрока в игре — с его uid (иначе после рестарта её получит любой)
		out[pp.nick] = rec
	for nk in wallets:
		if out.has(nk):
			out[nk]["cr"] = int(wallets[nk])
	return out


func players_load(d: Dictionary) -> void:
	saved = d.duplicate(true)
	for nk in saved:
		if saved[nk] is Dictionary:
			saved[nk].erase("inv_ms")   # время прошлого запуска — не сравнимо с нынешним
	for nk in saved:
		if saved[nk] is Dictionary and saved[nk].has("cr") and not wallets.has(nk):
			wallets[nk] = int(saved[nk].cr)


# ---------------------------------------------------------------- команды

## Вызывается из game.cmd(). true — команда ушла по сети, выполнять её здесь не надо.
func intercept(name: String, a: Dictionary) -> bool:
	if mode != "client" or applying:
		return false
	if not (name in REPLICATED or name in ACTOR):
		return false
	if name == "bag_up":
		a = a.duplicate()
		a["lvl"] = game.player.bag_level
	# 1.5: команды с вещами (взять/положить/перетащить) идут по одной: следующая уходит, когда хозяин ответил
	# на предыдущую, — с уже обновлённым рюкзаком (иначе двойной клик клал одну стопку дважды)
	var seat := _my_seat()
	# B-4 r10: и постройки (оплата из рюкзака) — по одной: следующая уходит с рюкзаком после ответа на предыдущую
	if _pending_t >= 0.0:
		_queue.append([name, _pack(a), seat])
		return true
	_pending_t = 0.0
	_send_req(name, _pack(a), seat)
	return true


## B-2 r8: место сплитскрина, которое отдаёт команду (ответ хозяина применяется к его рюкзаку).
var _seat_q: Array = []

func _my_seat() -> int:
	return game.split.seat_of(game.player) if game != null and game.split != null else 0


func _seat_player(seat: int):
	if game.split != null and game.split.active and seat == 1 and game.split.p2() != null:
		return game.split.p2()
	return game.split.p1() if game.split != null else game.player


func _send_req(name: String, pa: Dictionary, seat := 0) -> void:
	var pl = _seat_player(seat)
	if name == "bag_up":
		pa = pa.duplicate()
		pa["lvl"] = pl.bag_level   # B-5 r10: уровень — на момент отправки (после ответа на прошлое расширение)
	_seat_q.append(seat)
	_sent_n += 1
	rpc_id(1, "req_cmd", name, pa, pl.inv.to_array(), [pl.position.x, pl.position.y, pl.position.z], seat)


## 1.5: хозяин ответил на команду с вещами — отправить следующую из очереди.
func _req_done() -> void:
	_pending_t = -1.0
	_stall_told = false
	while not _queue.is_empty() and game != null:
		var q: Array = _queue.pop_front()
		if str(q[0]) in ACTOR and _unpack(q[1]) == null:
			continue   # здание уже снесли (постройки проверяет хозяин: поворот ленты в линии ждёт ещё не пришедшую ленту)
		_pending_t = 0.0
		_send_req(str(q[0]), q[1], int(q[2]) if q.size() > 2 else 0)
		return
	# B-5/B-6 r11: всё отвечено — выполнить то, что ждало (крафт, выход второго игрока)
	var cbs := _idle_cb.duplicate()
	_idle_cb.clear()
	for cb in cbs:
		if (cb as Callable).is_valid():
			(cb as Callable).call()


## B13: долг гостя — вещи, которые хозяин уже забрал командой, а гость за это время потратил у себя.
## Сначала снимаем надетое и вещи из свежей могилы, остальное — из того, что появится в рюкзаке.
var _debt := {}   # предмет -> [игрок, сколько]


func _owe(pl, id: String, n: int) -> void:
	if n <= 0 or pl == null:
		return
	if "clothes" in pl and str(pl.clothes) == id:
		pl.clothes = ""
		if pl.has_method("apply_clothes"):
			pl.apply_clothes()
		n -= 1
	if n > 0 and game != null and not game.graves.is_empty():
		var gi: Inventory = game.graves.back().inv
		n -= gi.take_up_to(id, n)
		gi._bump()
	if n > 0:
		var k := "%s|%d" % [id, pl.get_instance_id()]
		var cur: Array = _debt.get(k, [pl, 0])
		_debt[k] = [pl, int(cur[1]) + n]
	_settle_debt()


func _settle_debt() -> void:
	for k in _debt.keys():
		var pl = _debt[k][0]
		if pl == null or not is_instance_valid(pl):
			_debt.erase(k)
			continue
		var id := str(k).get_slice("|", 0)
		var got: int = pl.inv.take_up_to(id, int(_debt[k][1]))
		if got >= int(_debt[k][1]):
			_debt.erase(k)
		else:
			_debt[k][1] = int(_debt[k][1]) - got


## B-5/B-6 r11: у гостя есть команды без ответа хозяина (их вещи ещё числятся в рюкзаке).
func busy() -> bool:
	return mode == "client" and (_pending_t >= 0.0 or not _queue.is_empty())


## B-5/B-6 r11: выполнить, когда хозяин ответит на все команды в пути (сразу, если их нет).
func when_idle(cb: Callable) -> void:
	if busy():
		_idle_cb.append(cb)
	else:
		cb.call()


## После выполнения у хозяина: разослать всем остальным.
func after_cmd(name: String, a: Dictionary, result, pre = null) -> void:
	if mode != "host" or applying:
		return
	if name in REPLICATED:
		if name in MUST_SUCCEED and (result == null or (result is bool and not result)):
			return
		var pa: Dictionary = pre if pre is Dictionary else _pack(a)
		if name == "place" and result != null:
			pa["cell"] = result.cell   # улучшение ставится на клетку старого здания
			pa["owner"] = str(result.bstate.get("owner", ""))
		_bcast_cmd(name, pa)
	elif name in ACTOR:
		_send_shared()
		if a.has("b") and a.b is Object:
			send_bld_inv(a.b)   # 1.5: гости сразу видят, что хозяин взял или положил


@rpc("any_peer", "call_remote", "reliable")
func req_cmd(name: String, pa: Dictionary, inv_arr: Array, pos: Array, seat := 0) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode != "host" or game == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if OS.get_cmdline_user_args().has("--net_dbg"): print("NETDBG req_cmd ", name, " ", pa)
	_done_n[id] = int(_done_n.get(id, 0)) + 1   # B-1 r11
	if not (name in REPLICATED or name in ACTOR):
		rpc_id(id, "inv_delta", [], false)
		return
	var a = _unpack(pa)
	if a == null:
		rpc_id(id, "inv_delta", [], name in ACTOR)   # B-2 r8: ответ на каждую команду — гость сверяет очередь мест
		return
	var nk: String = str(peers[id].nick) if peers.has(id) else ""
	var why := deny(name, a, nk)
	if why != "":
		rpc_id(id, "toast", why, Color(1, 0.6, 0.4))
		rpc_id(id, "inv_delta", [], name in ACTOR)
		return
	# выполнить «от лица» игрока: его рюкзак, место, кошелёк и склад базы вместо героя хозяина
	var pl = game.player
	var my_inv: Inventory = pl.inv
	var my_pos: Vector3 = pl.position
	var tmp := Inventory.new(my_inv.size())
	tmp.from_array(inv_arr)
	pl.inv = tmp
	pl.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	_swap = {"inv": my_inv, "credits": game.credits}
	if own_wallets():
		game.credits = int(wallets.get(nk, 0))
	var f = game.factory
	if separate():
		var ob = game.coop.outpost_of(nk)
		f.personal = ob.inv if ob != null else store_of(nk)
		f.personal_b = ob
	var my_bag: int = pl.bag_level
	if name == "bag_up":
		pl.bag_level = int(a.get("lvl", 0))
	actor = id
	applying = true
	# 1.1.11: админ с бесплатной стройкой строит даром
	var free_was = game.flags.get("free_build", null)
	# 1.1.15: бесплатная стройка — только у того, кому её дали (раньше хозяйская действовала на всех гостей)
	game.flags["free_build"] = game.admin != null and game.admin.free_nicks.has(nk)
	var r = game._cmd_impl(name, a)
	if free_was == null:
		game.flags.erase("free_build")
	else:
		game.flags["free_build"] = free_was
	applying = false
	actor = 0
	var guest_bag: int = pl.bag_level
	pl.bag_level = my_bag
	f.personal = null
	f.personal_b = null
	if own_wallets():
		wallets[nk] = game.credits
		game.credits = int(_swap.credits)
	_swap = {}
	pl.inv = my_inv
	pl.position = my_pos
	var after := tmp.to_array()
	if puppets.has(id) and seat == 0:   # B-1 r9: рюкзак второго игрока гостя — не запись первого
		puppets[id].last_inv = after
		puppets[id].set_meta("inv_ms", Time.get_ticks_msec())
	elif seat == 1 and nk != "":
		# B12-2: рюкзак второго игрока гостя после команды — сразу в запись (раньше только из отчёта раз в 20 с)
		var rec2: Dictionary = saved.get(nk, {})
		var me2 = rec2.get("me", {})
		if not me2 is Dictionary:
			me2 = {}
		var sp2 = me2.get("split2", {})
		if not sp2 is Dictionary:
			sp2 = {}
		sp2["inv"] = after
		me2["split2"] = sp2
		rec2["me"] = me2
		saved[nk] = rec2
	if name == "bag_up" and guest_bag != int(a.get("lvl", 0)):
		rpc_id(id, "bag_set", guest_bag)
	# 1.5: в ответ — только изменившиеся ячейки (что гость успел поднять или скрафтить за это время, не затирается)
	rpc_id(id, "inv_delta", inv_diff(inv_arr, after), name in ACTOR)
	# здание, с которым работали, сразу у всех такое же, как у хозяина
	if a.has("b") and a.b is Object and name in ACTOR:
		send_bld_inv(a.b)
	if name in REPLICATED:
		if name in MUST_SUCCEED and (r == null or (r is bool and not r)):
			return
		if name == "place":
			pa["cell"] = r.cell
			pa["owner"] = str(r.bstate.get("owner", ""))
		_bcast_cmd(name, pa)
	else:
		_send_shared()


## Команда от хозяина: применить у себя (без оплаты — склад штаба и кредиты приходят вместе с ней).
@rpc("authority", "call_remote", "reliable")
func do_cmd(name: String, pa: Dictionary, hq_inv: Array, credits: int) -> void:
	if OS.get_cmdline_user_args().has("--net_dbg"): print("NETDBG do_cmd ", name, " ", pa)
	# credits < 0 — «у каждого свои деньги»: свой кошелёк приходит отдельно
	if game == null:
		_hold("do_cmd", [name, pa, hq_inv, credits])
		return
	var a = _unpack(pa)
	if a == null:
		return
	applying = true
	var free_was = game.flags.get("free_build", null)
	game.flags["free_build"] = true
	game._cmd_impl(name, a)
	if free_was == null:
		game.flags.erase("free_build")
	else:
		game.flags["free_build"] = free_was
	applying = false
	_apply_shared(hq_inv, credits)


@rpc("authority", "call_remote", "reliable")
func toast(text: String, col: Color) -> void:
	if game:
		game.hud.toast(text, col)


## 1.5: какие ячейки рюкзака поменялись: [[i, было, стало], ...]
static func inv_diff(before: Array, after: Array) -> Array:
	var out := []
	for i in maxi(before.size(), after.size()):
		var b = before[i] if i < before.size() else null
		var c = after[i] if i < after.size() else null
		if not _same_slot(b, c):
			out.append([i, b, c])
	if after.size() > before.size():
		out.append([-1, before.size(), after.size()])   # рюкзак стал больше
	return out


static func _same_slot(x, y) -> bool:
	if x == null or y == null:
		return x == null and y == null
	if not (x is Dictionary and y is Dictionary):
		return false
	return str(x.get("id", "")) == str(y.get("id", "")) and int(x.get("n", 0)) == int(y.get("n", 0)) \
		and is_equal_approx(float(x.get("dur", -1.0)), float(y.get("dur", -1.0))) and is_equal_approx(float(x.get("fresh", -1.0)), float(y.get("fresh", -1.0)))


## Применить ответ хозяина к своему рюкзаку. Ячейка, которая у гостя не менялась, просто заменяется;
## если гость её успел поменять сам — переносится только разница (убрать «было», добавить «стало»).
static func apply_inv_diff(inv: Inventory, diff: Array, short = null) -> Array:
	var spill := []
	for d in diff:
		if int(d[0]) == -1:
			if inv.size() < int(d[2]):
				inv.resize(int(d[2]))
	for d in diff:
		var i := int(d[0])
		if i < 0:
			continue
		if i >= inv.size():
			inv.resize(i + 1)
		var was = d[1]
		var now = d[2]
		if _same_slot(inv.slots[i], was):
			inv.slots[i] = now.duplicate() if now is Dictionary else null
			continue
		if was is Dictionary:
			var got := inv.take_up_to(str(was.id), int(was.n))
			# B13: не хватило — гость успел потратить (надеть, съесть, выстрелить, потерять в могилу) то, что хозяин
			# уже забрал командой; недостачу не прощаем
			if got < int(was.n) and short is Array:
				short.append([str(was.id), int(was.n) - got])
		if now is Dictionary:
			var left := inv.add_slot(now.duplicate())
			if left > 0:
				spill.append([str(now.id), left])
	inv._bump()
	return spill


@rpc("authority", "call_remote", "reliable")
func inv_delta(diff: Array, actor_cmd: bool) -> void:
	_ack_n += 1   # B-1 r11
	if game == null:
		_seat_q.pop_front()
		_req_done()
		return
	var seat: int = int(_seat_q.pop_front()) if not _seat_q.is_empty() else 0
	var pl = _seat_player(seat)   # B-2 r8: рюкзак того места, чья это была команда
	if pl == null:
		pl = game.player
	if not diff.is_empty():
		var short := []
		for sp in apply_inv_diff(pl.inv, diff, short):
			if pl == game.player:
				game.overflow(str(sp[0]), int(sp[1]), pl.position + Vector3(0, 1, 0))
			else:
				game.drops.spawn(str(sp[0]), int(sp[1]), pl.position + Vector3(0, 1, 0))
		for sh in short:
			_owe(pl, str(sh[0]), int(sh[1]))
	_req_done()   # B-4 r10: ответ приходит на каждую команду


@rpc("authority", "call_remote", "reliable")
func bag_set(level: int) -> void:
	if game == null:
		return
	var pl = _seat_player(int(_seat_q[0]) if not _seat_q.is_empty() else 0)   # B-2 r8
	if pl == null:
		pl = game.player
	pl.bag_level = level
	pl.apply_bag()


## 1.5: содержимое одного здания — всем гостям сразу после того, как в нём что-то взяли или положили.
func send_bld_inv(b) -> void:
	if mode != "host" or b == null or not is_instance_valid_b(b):
		return
	var hb = b.host if b.host != null else b
	var e := [hb.cell.x, hb.cell.y]
	for k in ["inv", "out", "fuel"]:
		var inv: Inventory = b.get(k)
		e.append(inv.to_array() if inv != null else [])
	e.append(hb.subs.find(b) if b.host != null else -1)   # B-7 r4: встроенная машина составного здания
	if b == game.factory.hq:
		_send_shared()
		return
	for pid in peers:
		if pid != 1:
			rpc_id(pid, "bld_inv", e)
	if b.host == null:
		for sb in b.subs:
			send_bld_inv(sb)   # 1.1.20: «Забрать всё» у составного берёт и из встроенного ящика


func is_instance_valid_b(b) -> bool:
	return b is Object and is_instance_valid(b) and not bool(b.get("dead"))


@rpc("authority", "call_remote", "reliable")
func bld_inv(e: Array) -> void:
	if game == null or e.size() < 5:
		return
	var b = game.factory.building_at(Vector2i(int(e[0]), int(e[1])))
	if b == null:
		return
	if e.size() >= 6 and int(e[5]) >= 0:
		if int(e[5]) >= b.subs.size():
			return
		b = b.subs[int(e[5])]
	var ks := ["inv", "out", "fuel"]
	for j in 3:
		var inv: Inventory = b.get(ks[j])
		if inv != null and e[2 + j] is Array:
			inv.from_array(e[2 + j])
			inv._bump()
	if game.hud.bld == b:
		game.hud.refresh_open()


@rpc("authority", "call_remote", "reliable")
func set_inv(arr: Array) -> void:
	if game == null:
		return
	game.player.inv.from_array(arr)
	game.player.inv.changed.emit()


## Хозяин раздаёт предметы игроку (возврат при разборе, добыча с убитого им монстра).
func give_to(id: int, item: String, n: int) -> void:
	rpc_id(id, "got_items", item, n)


## B17-1: лишнее гостя целой ячейкой (износ, свежесть) — в рюкзак, не влезло — на землю у гостя.
@rpc("authority", "call_remote", "reliable")
func got_slot(sl: Dictionary) -> void:
	if game == null or not sl.has("id") or not DB.data.items.has(str(sl.id)):
		return
	var left: int = game.player.inv.add_slot(sl.duplicate())
	game.player.inv.changed.emit()
	if left > 0:
		var rest: Dictionary = sl.duplicate()
		rest["n"] = left
		game.drops.spawn_slot(rest, game.player.position + Vector3(0, 1, 0))


@rpc("authority", "call_remote", "reliable")
func got_items(item: String, n: int) -> void:
	if game:
		game.factory.give_player(item, n)
	else:
		_hold("got_items", [item, n])   # B-6 r8: подарок, пришедший пока мир грузится


func _send_shared() -> void:
	var hq: Array = game.factory.hq.inv.to_array() if game.factory.hq else []
	for pid in peers:
		if pid != 1:
			rpc_id(pid, "shared", hq, credits_for(pid))


## Разослать команду: склад штаба и кредиты — каждому свои.
func _bcast_cmd(name: String, pa: Dictionary) -> void:
	var hq: Array = game.factory.hq.inv.to_array() if game.factory.hq else []
	for pid in peers:
		if pid != 1:
			rpc_id(pid, "do_cmd", name, pa, hq, credits_for(pid))


@rpc("authority", "call_remote", "reliable")
func shared(hq_inv: Array, credits: int) -> void:
	_apply_shared(hq_inv, credits)


func _apply_shared(hq_inv: Array, credits: int) -> void:
	if game == null:
		return
	if game.factory.hq and not hq_inv.is_empty():
		game.factory.hq.inv.from_array(hq_inv)
		game.factory.hq.inv.changed.emit()
	if credits >= 0:
		game.credits = credits


## Ссылки на здания (B) превращаются в клетки — по сети передаются только простые значения.
func _pack(a: Dictionary) -> Dictionary:
	var out := {}
	for k in a:
		var v = a[k]
		if v is Object and "cell" in v and "type" in v:
			out[k] = {"_b": [v.cell.x, v.cell.y]}
			# 1.1.15: встроенное в составное здание — по номеру в хозяине (клетка у них общая, и раньше ручка
			# тонкой настройки, рецепт и прочее у любой встроенной машины по сети попадали в само составное)
			if "host" in v and v.host != null:
				out[k]["_s"] = v.host.subs.find(v)
		else:
			out[k] = v
	return out


func _unpack(pa: Dictionary):
	var out := {}
	for k in pa:
		var v = pa[k]
		if v is Dictionary and v.has("_b"):
			var b = game.factory.building_at(Vector2i(int(v._b[0]), int(v._b[1])))
			if b == null:
				return null
			if v.has("_s"):
				if b.host != null:
					b = b.host
				var si := int(v._s)
				if si < 0 or si >= b.subs.size():
					return null
				b = b.subs[si]
			out[k] = b
		else:
			out[k] = v
	return out


# ---------------------------------------------------------------- ресурсы мира (деревья, камни)

## Игрок ударил ресурс: у себя — с добычей, у остальных — только урон.
func node_hit(c: Vector2i, power: float, tool: String) -> void:
	if mode == "":
		return
	rpc("node_hit_remote", c.x, c.y, power, tool)


@rpc("any_peer", "call_remote", "reliable")
func node_hit_remote(x: int, z: int, power: float, tool: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if game:
		game.world.hit_node(Vector2i(x, z), power, tool, true)
	else:
		_hold("node_hit_remote", [x, z, power, tool])   # B-6 r8


## 1.4: игрок посадил саженец — у остальных он появляется в той же клетке и растёт так же.
func node_plant(c: Vector2i, young: String, tree: String) -> void:
	if mode == "":
		return
	rpc("node_plant_remote", c.x, c.y, young, tree)


@rpc("any_peer", "call_remote", "reliable")
func node_plant_remote(x: int, z: int, young: String, tree: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if game:
		game.world.plant_at(Vector2i(x, z), young, tree)
	else:
		_hold("node_plant_remote", [x, z, young, tree])   # B-6 r8


# ---------------------------------------------------------------- монстры

func new_nid() -> int:
	_next_nid += 1
	return _next_nid


## Удар игрока по монстру у подключившегося: урон считает хозяин.
func hit_monster(e, dmg: float) -> void:
	rpc_id(1, "req_mhit", e.nid, dmg)


@rpc("any_peer", "call_remote", "reliable")
func req_mhit(nid: int, dmg: float) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode != "host" or game == null:
		return
	for e in game.enemies.list:
		if e.nid == nid:
			e.last_hitter = multiplayer.get_remote_sender_id()
			game.enemies.hit(e, dmg)
			return


## 1.7: гость выполнил своё задание — награду кладёт хозяин (в кошелёк гостя или в общие деньги).
func quest_reward(x: int) -> void:
	rpc_id(1, "req_quest_reward", clampi(x, 0, 100000))


@rpc("any_peer", "call_remote", "reliable")
func req_quest_reward(x: int) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode != "host" or game == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	# награда не больше самой крупной у задач, и за всё время не больше суммы всех наград (подделанный клиент)
	var mx := 0
	var total := 0
	for q in game.quests:
		mx = maxi(mx, int(q.get("reward", 0)))
		total += int(q.get("reward", 0))
	var nk := str(peers[id].nick)
	var rec: Dictionary = saved.get(nk, {})
	var paid := int(rec.get("quest_paid", 0))
	x = clampi(x, 0, mini(mx, maxi(0, total - paid)))
	if x <= 0:
		return
	rec["quest_paid"] = paid + x
	saved[nk] = rec
	if own_wallets():
		wallets[nk] = int(wallets.get(nk, 0)) + x
	else:
		game.credits += x
	_send_shared()


## 1.7: гость говорит с НПС — хозяин держит его на месте.
func npc_talk(e) -> void:
	rpc_id(1, "req_talk", e.nid, game.player.position)


@rpc("any_peer", "call_remote", "unreliable")
func req_talk(nid: int, pos: Vector3) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode != "host" or game == null:
		return
	for e in game.enemies.list:
		if e.nid == nid:
			e.talk_t = 1.5
			e.talk_to = pos
			return


## Монстр, которого добил игрок по сети: награда и добыча — ему.
func reward(id: int, credits: int, xp: float, drops: Array, pos: Vector3) -> void:
	rpc_id(id, "got_reward", xp, drops, pos)


@rpc("authority", "call_remote", "reliable")
func got_reward(xp: float, drops: Array, pos: Vector3) -> void:
	if game == null:
		return
	game.add_xp(xp)
	if game.enemies != null:
		game.enemies.kills += 1   # B18-3: монстра добил этот гость
	for d in drops:
		game.drops.spawn(str(d[0]), int(d[1]), pos + Vector3(randf_range(-0.6, 0.6), 0.8, randf_range(-0.6, 0.6)))


func _send_monsters() -> void:
	var types: Array = DB.data.enemies.keys()
	var arr := PackedFloat32Array()
	for e in game.enemies.list:
		if not e.alive:
			continue
		arr.append_array([e.nid, types.find(e.type), e.pos.x, e.pos.y, e.pos.z, e.yaw, e.hp / maxf(1.0, e.maxhp), (1.0 if e.moving else 0.0) + 2.0 * roundf(e.under * 20.0)])
	rpc("mon_snap", arr, game.enemies.wave, game.enemies.wave_timer)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func mon_snap(arr: PackedFloat32Array, wave: int, wave_timer: float) -> void:
	if game == null:
		return
	var E = game.enemies
	E.wave = wave
	E.wave_timer = wave_timer
	var types: Array = DB.data.enemies.keys()
	var seen := {}
	var i := 0
	while i + 7 < arr.size():
		var nid := int(arr[i])
		var t: String = types[int(arr[i + 1])] if int(arr[i + 1]) >= 0 and int(arr[i + 1]) < types.size() else ""
		var p := Vector3(arr[i + 2], arr[i + 3], arr[i + 4])
		seen[nid] = true
		var e = _mon_by_nid.get(nid)
		if e == null and t != "":
			e = E.spawn(t, p, false, true)
			if e != null:
				e.nid = nid
				_mon_by_nid[nid] = e
		if e != null:
			var tnow := Time.get_ticks_msec() * 0.001
			if e.net_pos != Vector3.INF and tnow > e.net_t:
				var mv: Vector3 = World.delta(e.net_pos, p)
				e.net_vel = mv / maxf(0.05, tnow - e.net_t) if mv.length() < 6.0 else Vector3.ZERO
			e.net_t = tnow
			e.net_pos = p
			e.net_yaw = arr[i + 5]
			e.hp = arr[i + 6] * e.maxhp
			e.moving = int(arr[i + 7]) % 2 == 1
			e.under = float(int(arr[i + 7]) / 2) / 20.0   # червь под землёй
		i += 8
	for nid in _mon_by_nid.keys():
		if not seen.has(nid):
			var e = _mon_by_nid[nid]
			_mon_by_nid.erase(nid)
			if e.alive:
				E.kill_visual(e)


# ---------------------------------------------------------------- игроки

func _send_state() -> void:
	if dedicated:
		return
	var sp = game.split
	var p = sp.p1() if sp != null and sp.active else game.player
	rpc("pstate", p.position, p.hips.rotation.y, Vector2(p.move_dir.x, p.move_dir.z), p.aim, p.alive, p.swing_t, p.shoot_t, p.hp, Time.get_ticks_msec())
	# B-5 r8: второй игрок сплитскрина — тоже виден остальным (своя марионетка)
	if sp != null and sp.active and sp.p2() != null:
		var q = sp.p2()
		rpc("pstate2", q.position, q.hips.rotation.y, Vector2(q.move_dir.x, q.move_dir.z), q.aim, q.alive, q.swing_t, q.shoot_t, q.hp, Time.get_ticks_msec(), q.look)
		_p2_sent = true
	elif _p2_sent:
		_p2_sent = false
		rpc("pstate2_gone")


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func pstate2(pos: Vector3, yaw: float, mv: Vector2, aim: Vector3, alive: bool, swing: float, shoot: float, hp: float, ts := 0, look := "") -> void:
	if not _authed():
		return
	var id := multiplayer.get_remote_sender_id()
	if game == null or not peers.has(id) or id == my_id():
		return
	var pp = puppets2.get(id)
	if pp == null or not is_instance_valid(pp):
		pp = preload("res://scripts/remote_player.gd").new()
		pp.game = game
		pp.peer = id
		pp.seat = 1
		pp.nick = str(peers[id].nick) + " 2"
		pp.look = look
		pp.tint = DB.color(peers[id].color)
		game.add_child(pp)
		pp.build()
		pp.setup_label()
		pp.position = pos
		puppets2[id] = pp
	pp.net_pos = pos
	pp.push_snap(pos, yaw, ts)
	pp.net_yaw = yaw
	pp.move_dir = Vector3(mv.x, 0, mv.y)
	pp.aim = aim
	pp.alive = alive
	pp.swing_t = swing
	pp.shoot_t = shoot
	pp.hp = hp


@rpc("any_peer", "call_remote", "reliable")
func pstate2_gone() -> void:
	_drop_p2(multiplayer.get_remote_sender_id())


func _drop_p2(id: int) -> void:
	if puppets2.has(id):
		if is_instance_valid(puppets2[id]):
			puppets2[id].queue_free()
		puppets2.erase(id)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func pstate(pos: Vector3, yaw: float, mv: Vector2, aim: Vector3, alive: bool, swing: float, shoot: float, hp: float, ts := 0) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	var id := multiplayer.get_remote_sender_id()
	var pp = puppets.get(id)
	if pp == null:
		_spawn_puppet(id)
		pp = puppets.get(id)
		if pp == null:
			return
		pp.position = pos
	pp.net_pos = pos
	pp.push_snap(pos, yaw, ts)
	pp.net_yaw = yaw
	pp.move_dir = Vector3(mv.x, 0, mv.y)
	pp.aim = aim
	pp.alive = alive
	pp.swing_t = swing
	pp.shoot_t = shoot
	pp.hp = hp


## B-8 r8: сервер сейчас сохранит мир — прислать свой рюкзак и личное.
@rpc("authority", "call_remote", "reliable")
func state_now() -> void:
	if mode == "client" and game != null:
		report_inv_now()
		send_my_state()


## Монстр хозяина ударил игрока по сети.
@rpc("authority", "call_remote", "reliable")
func hurt(dmg: float, seat := 0) -> void:
	if game:
		var pl = _seat_player(seat)   # B-5 r8: монстр хозяина ударил второго игрока
		(pl if pl != null else game.player).damage(dmg)


## Рюкзак и могилы — хозяину вместе, с одной отметкой времени (B-1 r3; B-3 r4: и сразу, как могила поменялась).
func report_inv_now() -> void:
	if mode != "client" or game == null:
		return
	var p1 = game.split.p1() if game.split != null else game.player   # B-1 r9: рюкзак первого игрока, даже если событие у второго
	rpc_id(1, "inv_report", p1.inv.to_array(), game.graves.map(func(g): return {"pos": [g.pos.x, g.pos.z], "inv": g.inv.to_array()}), _ack_n)


## Игрок присылает хозяину свой рюкзак (для сохранения мира).
@rpc("any_peer", "call_remote", "reliable")
func inv_report(arr: Array, graves = null, ack := -1) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	var sid := multiplayer.get_remote_sender_id()
	var pp = puppets.get(sid)
	if pp:
		if not _stale_report(sid, ack):   # B-1 r11: устаревший отчёт не перетирает рюкзак после команды
			pp.last_inv = arr
		pp.set_meta("inv_ms", Time.get_ticks_msec())
		if graves is Array:
			pp.set_meta("graves", graves)


# ---------------------------------------------------------------- мир: время, рынок, открытия, здания

func _send_world() -> void:
	var td: Dictionary = game.tech.to_dict()
	var ocean_drift: Array = game.island.fishing.records() if game.island != null else []
	var hq: Array = game.factory.hq.inv.to_array() if game.factory.hq else []
	for pid in peers:
		if pid != 1:
			rpc_id(pid, "world_tick", game.day_t, game.day_n, credits_for(pid), game.price_mult, td, game.events.active, hq, game.enemies.waves_survived, game.factory.hq.hp if game.factory.hq != null else -1.0, game.progress17.daily if game.progress17 != null else {},ocean_drift)


@rpc("authority", "call_remote", "reliable")
func world_tick(day_t: float, day_n: int, credits: int, prices: Dictionary, tech: Dictionary, ev: Dictionary, hq_inv: Array, waves := -1, hq_hp := -1.0, daily := {}, ocean_drift := []) -> void:
	if game == null:
		return
	if game.island != null: game.island.fishing.apply_snapshot(ocean_drift)
	if game.progress17 != null and not daily.is_empty():
		game.progress17.set_daily(daily)   # B-12 r5: заказ дня — хозяйский
	if waves >= 0:
		game.enemies.waves_survived = waves   # 1.1.15: отбитые волны — общие (задание «Отбейте 3 волны» у гостя)
	if hq_hp >= 0.0 and game.factory.hq != null and absf(game.factory.hq.hp - hq_hp) > 0.5:
		game.factory.hq.hp = hq_hp   # 1.1.15: прочность штаба видна гостям
		game.factory._tint(game.factory.hq)
	if hq_hp >= 0.0 and hq_hp <= 0.0 and game.factory.hq != null and not game.game_over:
		game.factory.hq.hp = 0.0
		game.on_hq_destroyed()   # A-15: вошёл в комнату, где штаб уже разрушен, — тоже поражение
	game.day_t = day_t
	game.day_n = day_n
	game.price_mult = prices
	var was_done: int = game.tech.done.size() + 1000 * game.tech.patterns.size()
	game.tech.from_dict(tech)
	if game.tech.done.size() + 1000 * game.tech.patterns.size() != was_done:
		game.tech.refresh_locks()
	for id in ev:
		if not game.events.active.has(id):
			game.events.start_visual(id)
	for id in game.events.active.keys():
		if not ev.has(id):
			game.events.finish(id)
	game.events.active = ev.duplicate()
	_apply_shared(hq_inv, credits)


## Содержимое и прочность зданий: у каждого завод считается сам, а хозяин поправляет расхождения.
func _send_buildings() -> void:
	# 1.1.11: только изменившиеся здания (раньше каждые 3 с уходили все — на большой базе это сотни КБ и рывки
	# у хозяина и гостей); раз в 15 с — все целиком, на случай потерь
	_bld_n += 1
	var raw := bld_payload(_bld_n % 5 == 0)
	if raw.is_empty():
		return
	rpc("bld_sync", raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size())


var _bld_sig := {}            # 1.1.11: здание → подпись последнего отправленного состояния
var _bld_n := 0
var bld_last := 0             # 1.1.11: сколько зданий ушло в последней рассылке (для проверок)


## Состояние зданий для гостей: full — все, иначе только изменившиеся (по версиям ячеек). Пусто — отправлять нечего.
func bld_payload(full: bool) -> PackedByteArray:
	var arr := []
	var seen := {}
	for b in game.factory.all:
		if b.dead or b.beh == "belt":
			continue
		var ssig := 0
		for sb in b.subs:
			ssig = hash([ssig, sb.inv.ver if sb.inv != null else -1, sb.out.ver if sb.out != null else -1, sb.fuel.ver if sb.fuel != null else -1])
		var sig := hash([b.hp, b.maxhp, ssig, b.inv.ver if b.inv != null else -1, b.out.ver if b.out != null else -1, b.fuel.ver if b.fuel != null else -1,
			b.cfg.hash() if not b.cfg.is_empty() else 0, b.bstate.hash() if not b.bstate.is_empty() and not b.blk else 0])
		seen[b] = sig
		if not full and _bld_sig.get(b, 0) == sig:
			continue
		var e := [b.cell.x, b.cell.y, b.hp]
		for k in ["inv", "out", "fuel"]:
			var inv: Inventory = b.get(k)
			e.append(inv.to_array() if inv != null else [])
		# 14.23: настройки и состояние (ручка настройки, НЛО, реактор, врата) — гостям тоже
		e.append(b.cfg.duplicate(true) if not b.cfg.is_empty() else {})
		e.append(b.bstate.duplicate(true) if not b.bstate.is_empty() and not b.blk else {})
		e.append(b.maxhp)   # A-16: прочность от бонусов хозяина — у всех одинаковая
		var sl := []
		for sb in b.subs:
			var se := []
			for k in ["inv", "out", "fuel"]:
				var si: Inventory = sb.get(k)
				se.append(si.to_array() if si != null else [])
			sl.append(se)
		e.append(sl)   # B-7 r4: содержимое встроенных машин
		arr.append(e)
	var hz: Dictionary = game.hazards.to_dict() if game.hazards else {}
	var hsig := hash(hz)
	if full or hsig != _bld_sig.get("hz", 0):
		arr.append(["hz", hz])
	bld_last = arr.size()
	seen["hz"] = hsig
	_bld_sig = seen
	if arr.is_empty():
		return PackedByteArray()
	return var_to_bytes(arr)


@rpc("authority", "call_remote", "reliable")
func bld_sync(bytes: PackedByteArray, size: int) -> void:
	if game == null:
		return
	var arr = bytes_to_var(bytes.decompress(size, FileAccess.COMPRESSION_ZSTD))
	if not arr is Array:
		return
	var f = game.factory
	for e in arr:
		if e.size() == 2 and str(e[0]) == "hz":
			if game.hazards and e[1] is Dictionary and not e[1].is_empty():
				var dose: float = game.hazards.dose
				game.hazards.from_dict(e[1])
				game.hazards.dose = dose   # доза у каждого своя
			continue
		var b = f.building_at(Vector2i(int(e[0]), int(e[1])))
		if b == null or b == f.hq:
			continue
		if e.size() >= 9 and float(e[8]) > 0.0:
			b.maxhp = float(e[8])
		if e.size() >= 10 and e[9] is Array and (e[9] as Array).size() == b.subs.size():
			for si in b.subs.size():
				var sb = b.subs[si]
				var ks2 := ["inv", "out", "fuel"]
				for j in 3:
					var inv2: Inventory = sb.get(ks2[j])
					if inv2 != null and e[9][si][j] is Array and inv2.to_array() != e[9][si][j]:
						inv2.from_array(e[9][si][j])
		if absf(b.hp - float(e[2])) > 0.5:
			b.hp = float(e[2])
			f._tint(b)
		var ks := ["inv", "out", "fuel"]
		for j in 3:
			var inv: Inventory = b.get(ks[j])
			if inv != null and e[3 + j] is Array and inv.to_array() != e[3 + j]:
				inv.from_array(e[3 + j])   # 1.1.11: то же самое не перезаписываем (лишние обновления окон и машин)
		if e.size() >= 8:
			if e[6] is Dictionary:
				b.cfg = e[6]
			if e[7] is Dictionary and not e[7].is_empty():
				b.bstate = e[7]


## Здание разрушено монстрами у хозяина.
func building_destroyed(b) -> void:
	if mode == "host":
		rpc("bld_gone", b.cell.x, b.cell.y)


@rpc("authority", "call_remote", "reliable")
func bld_gone(x: int, z: int) -> void:
	if game == null:
		_hold("bld_gone", [x, z])
		return
	var b = game.factory.building_at(Vector2i(x, z))
	if b != null and b != game.factory.hq:
		game.fx.explosion(b.center() + Vector3(0, 1, 0), 1.6 if b.size == 1 else 4.0, Color(1.0, 0.5, 0.15))
		if game.get("physics") != null:
			game.physics.debris(b)
		if game.builders:
			game.builders.add_ruin(b)
		game.factory.remove(b)


## 18: хозяин рассылает положения роботов-строителей (их считает только он).
func send_bots18(arr: PackedFloat32Array) -> void:
	if mode == "host" and peers.size() > 1:
		rpc("bots18", arr)


@rpc("authority", "call_remote", "unreliable")
func bots18(arr: PackedFloat32Array) -> void:
	if game != null and game.builders:
		game.builders.net_bots(arr)


## Событие мира началось у хозяина.
## 1.1.15: метеорит упал у хозяина — у гостей та же клетка.
func meteor(cell: Vector2i) -> void:
	if mode == "host":
		rpc("meteor_rpc", cell.x, cell.y)


@rpc("authority", "call_remote", "reliable")
func meteor_rpc(x: int, z: int) -> void:
	if game:
		game.events.meteor_land(Vector2i(x, z))
	else:
		_hold("meteor_rpc", [x, z])


## 1.1.15: новые камни/жилы на карте (событие «Богатая жила») — гостям тоже, вместе с меткой на карте.
## B-5 r5: квантовые жилы — гостям.
func qveins_sync(d: Dictionary) -> void:
	if mode == "host":
		rpc("qveins_rpc", d)


@rpc("authority", "call_remote", "reliable")
func qveins_rpc(d: Dictionary) -> void:
	if game == null:
		_hold("qveins_rpc", [d])
		return
	game.quantum.apply_net(d)


func nodes_added(res: String, cells: Array, mark: Dictionary) -> void:
	if mode == "host":
		rpc("nodes_rpc", res, cells, mark)


@rpc("authority", "call_remote", "reliable")
func nodes_rpc(res: String, cells: Array, mark: Dictionary) -> void:
	if game == null:
		_hold("nodes_rpc", [res, cells, mark])
		return
	for c in cells:
		game.world.add_node(res, Vector2i(int(c[0]), int(c[1])))
	if not mark.is_empty():
		game.marks.append(mark)
		game.fx.dirt(Vector3(float(mark.get("x", 0)), 0, float(mark.get("z", 0))), 1.5)


func event_started(id: String) -> void:
	if mode == "host":
		rpc("ev_start", id)


@rpc("authority", "call_remote", "reliable")
func ev_start(id: String) -> void:
	if game:
		game.events.start_visual(id)


# ---------------------------------------------------------------- цикл

func _process(delta: float) -> void:
	_poll_lan()
	if mode == "client" and _join_t >= 0.0:
		_join_t += delta
		if _join_t > float(DB.setting("coop", {}).get("join_timeout", 12)):
			status = no_answer_text()
			leave()
			return
	if mode == "host" and _bc != null:
		_bc_t -= delta
		if _bc_t <= 0.0:
			_bc_t = 1.5
			_announce()
	if mode == "" or game == null or not is_instance_valid(game):
		return
	if mode == "host":
		_acc_stats += delta
		if _acc_stats >= 2.0:
			_acc_stats = 0.0
			_send_stats()
		# 18: мир комнаты сохраняется сам каждые N минут и вскоре после входа или выхода игрока
		_acc_save += delta
		var due := _acc_save >= maxf(0.5, float(DB.setting("coop", {}).get("autosave_min", 1.0))) * 60.0   # A13-2: 0 — не каждый кадр
		if _save_soon > 0.0:
			_save_soon -= delta
			due = due or _save_soon <= 0.0
		if due:
			_acc_save = 0.0
			_save_soon = -1.0
			game.save_game("autosave", true)
			if server != null and DB.write_failed != "":
				server.log_line("ОШИБКА: мир не сохранён (нет места на диске?) — прежний файл цел")   # B-1 r7
			elif server != null:
				server.log_line("Мир сохранён (%s)" % room_slot())
				server.backup()
	elif mode == "client":
		if _pending_t >= 0.0:
			_pending_t += delta
			if _pending_t > 20.0 and not _stall_told:
				# B-2 r11: ответа нет — ждём дальше (новая команда со старым рюкзаком давала дюп); связь рвёт ENet
				_stall_told = true
				if game != null:
					game.notify("Хозяин не отвечает — действия выполнятся, когда связь вернётся", Color(1, 0.6, 0.4))
		if not _debt.is_empty() and Engine.get_process_frames() % 30 == 0:
			_settle_debt()
		_acc_mine += delta
		if _acc_mine >= 20.0:
			_acc_mine = 0.0
			send_my_state()
	# B-2 r7: голосование ведёт хозяин — срок проверяется у него (раньше — только в ветке гостя)
	if not _vote.is_empty() and Time.get_ticks_msec() > int(_vote.until):
		_finish_vote()
	_acc_state += delta
	if _acc_state >= 1.0 / 20.0:
		_acc_state = 0.0
		_send_state()
	if mode == "host":
		_acc_mon += delta
		if _acc_mon >= 0.1:
			_acc_mon = 0.0
			_send_monsters()
		_acc_world += delta
		if _acc_world >= 1.0:
			_acc_world = 0.0
			_send_world()
		_acc_bld += delta
		if _acc_bld >= float(DB.setting("net_sync_every", 3.0)):
			_acc_bld = 0.0
			_send_buildings()
	else:
		_acc_inv += delta
		if _acc_inv >= 10.0:
			_acc_inv = 0.0
			report_inv_now()
	_update_list()


## Все герои: свой и чужие (для монстров у хозяина).
func all_players() -> Array:
	var out: Array = (game.split.local_players() if game.split != null else [game.player]) if game and not dedicated else []
	for id in puppets:
		if is_instance_valid(puppets[id]):
			out.append(puppets[id])
	for id in puppets2:
		if is_instance_valid(puppets2[id]):
			out.append(puppets2[id])
	return out


# ---------------------------------------------------------------- чат и список игроков

func _build_ui() -> void:
	if ui:
		ui.queue_free()
	ui = CanvasLayer.new()
	ui.layer = 6
	game.add_child(ui)
	chat_box = VBoxContainer.new()
	chat_box.position = Vector2(16, 380)
	chat_box.custom_minimum_size = Vector2(460, 0)
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(chat_box)
	chat_edit = LineEdit.new()
	chat_edit.placeholder_text = "Сообщение (Enter — отправить, Esc — закрыть)"
	chat_edit.custom_minimum_size = Vector2(460, 30)
	chat_edit.position = Vector2(16, 560)
	chat_edit.visible = false
	chat_edit.text_submitted.connect(_send_chat)
	ui.add_child(chat_edit)
	list_lbl = Label.new()
	list_lbl.add_theme_font_size_override("font_size", 15)
	list_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	list_lbl.add_theme_constant_override("outline_size", 5)
	list_lbl.anchor_left = 1.0
	list_lbl.anchor_right = 1.0
	list_lbl.offset_left = -330
	list_lbl.offset_top = 460
	ui.add_child(list_lbl)


func _unhandled_input(ev: InputEvent) -> void:
	if mode == "" or game == null or chat_edit == null:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ENTER and not chat_edit.visible:
			chat_edit.visible = true
			chat_edit.grab_focus()
			get_viewport().set_input_as_handled()
		elif ev.keycode == KEY_ESCAPE and chat_edit.visible:
			chat_edit.visible = false
			chat_edit.release_focus()
			get_viewport().set_input_as_handled()


func _send_chat(t: String) -> void:
	chat_edit.text = ""
	chat_edit.visible = false
	chat_edit.release_focus()
	t = t.strip_edges()
	if t == "":
		return
	if game and game.coop and game.coop.chat_command(t):
		return
	rpc("chat_msg", nick, color, t)
	_show_chat(nick, color, t)


@rpc("any_peer", "call_remote", "reliable")
func chat_msg(n: String, c: String, t: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	var sid := multiplayer.get_remote_sender_id()
	if sid > 1:
		# A-5: имя и цвет гостя — те, под которыми он вошёл (не «Сервер», не «Сеть» и не чужой ник)
		if not peers.has(sid):
			return
		n = str(peers[sid].nick)
		c = str(peers[sid].get("color", c))
	_show_chat(n, c, t, sid <= 1)


## Показать строку чата (B-11 r3: служебные «Сеть»/«Сервер» от самого хозяина — без подмены имени).
func _show_chat(n: String, c: String, t: String, sys_ok := true) -> void:
	chat_log.append([n, c, t])
	if server != null and n != "Сеть":
		server.log_line("[чат] %s: %s" % [n, t])
	if chat_log.size() > 50:
		chat_log.pop_front()
	if chat_box == null:
		return
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(460, 0)
	n = n.replace("[", "(").replace("]", ")")
	if not c.is_valid_html_color() or c.contains("]"):
		c = "#ffffff"
	var sys: bool = sys_ok and n in ["Сервер", "Сеть", "Администратор"]
	l.text = "[outline_size=5][outline_color=black][color=%s]%s:[/color] %s[/outline_color][/outline_size]" % [c, Lang.t(n) if sys else n, (Lang.t(t) if sys else t).replace("[", "(")]
	chat_box.add_child(l)
	while chat_box.get_child_count() > 6:
		# 1.1.15: queue_free удаляет не сразу — раньше цикл не кончался и игра зависала на 7-й строке чата
		var old := chat_box.get_child(0)
		chat_box.remove_child(old)
		old.queue_free()
	get_tree().create_timer(float(DB.setting("net_chat_time", 20.0))).timeout.connect(func(): if is_instance_valid(l): l.queue_free())


## 1.1.15: RPC от игрока, который не вошёл в комнату (не прошёл пароль/бан/версию), хозяин не выполняет.
func _authed() -> bool:
	var sid := multiplayer.get_remote_sender_id()
	return mode != "host" or sid == 0 or sid == multiplayer.get_unique_id() or peers.has(sid)


func _note(t: String) -> void:
	_show_chat("Сеть", "#8fd4ff", t)
	if server != null:
		server.log_line(t)


func _update_list() -> void:
	if list_lbl == null:
		return
	var lines := ["«%s» · игроков %d из %d" % [str(room.get("name", "")), peers.size(), int(room.get("max_players", 8))]]
	if mode == "host":
		var cd := codes()
		lines.append("Код: %s" % (cd.get("net", cd.get("lan", "—"))))
	var tl: Dictionary = game.coop.titles() if game and game.coop else {}
	for id in peers:
		var p: Dictionary = peers[id]
		var s: Dictionary = stats.get(str(p.nick), {})
		var extra := ""
		if not s.is_empty():
			extra = " · %d кр · %d зд." % [int(s.get("cr", 0)), int(s.get("bld", 0))] if own_wallets() else " · %d зд." % int(s.get("bld", 0))
			if int(s.get("rep", 0)) > 0:
				extra += " · реп. %d" % int(s.rep)
		if tl.has(p.nick):
			extra += " [%s]" % tl[p.nick]
		lines.append("%s%s%s" % [p.nick, " (хозяин)" if id == 1 else (" (вы)" if id == my_id() else ""), extra])
	list_lbl.text = "\n".join(lines)


# ---------------------------------------------------------------- автотест подключившегося (вместе с --test=net_host у хозяина)

func _client_test() -> void:
	var tree := get_tree()
	var g = game
	g.quest_i = g.quests.size()   # награды за задания меняли бы кошелёк посреди проверок рынка
	var n_bld: int = g.factory.all.size()
	var world_ok: bool = n_bld > 0 and g.factory.hq != null
	# ждём монстра от хозяина
	var mon = null
	for i in 300:
		await tree.process_frame
		if not g.enemies.list.is_empty():
			mon = g.enemies.list[0]
			break
	var mon_ok: bool = mon != null and mon.nid > 0
	# ставим сундук: команда уходит хозяину и возвращается
	var cell: Vector2i = g.factory.hq.cell + Vector2i(9, 9)
	g.world.remove_node(cell)
	g.player.inv.add("plank", 20)
	g.cmd("place", {"type": "chest", "cell": cell, "dir": 0})
	var placed_ok := false
	var t_pl := Time.get_ticks_msec() + 40000   # под нагрузкой (хозяин сохраняет мир после входа гостя) ответ идёт дольше
	while Time.get_ticks_msec() < t_pl:
		await tree.process_frame
		var b = g.factory.building_at(cell)
		if b != null and b.type == "chest":
			placed_ok = true
			break
	# 1.4: гость сажает саженец — хозяин должен его увидеть
	var pcell: Vector2i = g.factory.hq.cell + Vector2i(12, 9)
	g.world.remove_node(pcell)
	g.world.plant_sapling("young_birch", "tree_birch", World.cell_to_world(pcell))
	# кладём в сундук доски (команда с рюкзаком)
	var planks0: int = g.player.inv.count("plank")
	if placed_ok:
		g.cmd("put", {"b": g.factory.building_at(cell), "id": "plank", "n": 5})
	var t0 := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < t0:
		await tree.process_frame
		if g.player.inv.count("plank") < planks0:
			break
	var put_ok: bool = g.player.inv.count("plank") == planks0 - 5
	# 1.5: двойной клик «положить» не дублирует, перетаскивание из сундука идёт через хозяина, рюкзак гостя расширяется
	var ok15 := true
	var msg15 := ""
	var ch = g.factory.building_at(cell)
	if ch != null:
		var left: int = g.player.inv.count("plank")
		g.cmd("put", {"b": ch, "id": "plank", "n": left})
		g.cmd("put", {"b": ch, "id": "plank", "n": left})
		var t1 := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < t1:
			await tree.process_frame
			if _pending_t < 0.0 and _queue.is_empty() and ch.inv.count("plank") >= 5 + left:
				break
		for i in 30:
			await tree.process_frame
		var dbl_ok: bool = g.player.inv.count("plank") == 0 and ch.inv.count("plank") == 5 + left
		msg15 += " dbl_put=%s(%d)" % [dbl_ok, ch.inv.count("plank")]
		var free_i := -1
		for i in range(g.player.inv.size() - 1, 9, -1):
			if g.player.inv.slots[i] == null:
				free_i = i
				break
		var si := -1
		for i in ch.inv.size():
			if ch.inv.slots[i] != null:
				si = i
				break
		g.hud.bld = ch
		if si >= 0 and free_i >= 0:
			g.hud.move_slot(ch.inv, si, g.player.inv, free_i)
		var t2 := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < t2:
			await tree.process_frame
			if g.player.inv.slots[free_i] != null:
				break
		for i in 30:
			await tree.process_frame
		var mv_ok: bool = free_i >= 0 and g.player.inv.slots[free_i] != null and g.player.inv.count("plank") + ch.inv.count("plank") == 5 + left
		msg15 += " drag=%s" % mv_ok
		g.hud.bld = null
		ok15 = dbl_ok and mv_ok
	var size0: int = g.player.inv.size()
	var st0 := Player.bag_next(g.player.bag_level)
	for it in st0.get("cost", {}):
		g.player.inv.add(it, int(st0.cost[it]))
	g.cmd("bag_up", {})
	var t3 := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < t3:
		await tree.process_frame
		if g.player.inv.size() > size0:
			break
	var bag_ok: bool = g.player.inv.size() > size0 and g.player.bag_level == 1
	msg15 += " bag=%d->%d" % [size0, g.player.inv.size()]
	ok15 = ok15 and bag_ok and ch != null
	print("TEST net_inv15", msg15, " ", "OK" if ok15 else "FAIL")
	# бьём монстра
	if mon != null and mon.alive:
		g.enemies.hit(mon, 7.0, true)
	_send_chat_text("привет от гостя")
	for i in 120:
		await tree.process_frame
	var sees_host: bool = puppets.has(1) and puppets[1].net_pos != Vector3.INF
	# 14.23: площадка НЛО хозяина: заказ, расписание и заражение приходят гостю; гость меняет заказ и ручку
	var pad = null
	for b in g.factory.all:
		if Starworks.is_pad(b):
			pad = b
	var ufo_ok := false
	var zone_ok := false
	for i in 900:
		await tree.process_frame
		ufo_ok = pad != null and float(Starworks.st(pad).ufo_t) > 3000.0 and (Starworks.st(pad).orders as Array).size() >= 1
		zone_ok = not g.hazards.zone.is_empty()
		if ufo_ok and zone_ok:
			break
	if pad != null:
		var no: Array = (Starworks.st(pad).orders as Array).duplicate(true)
		no.append({"id": "antimatter", "n": 1})
		g.cmd("bstate", {"b": pad, "key": "orders", "val": no})
		var nc: Dictionary = pad.cfg.duplicate(true)
		nc["tune"] = 77
		g.cmd("bcfg", {"b": pad, "cfg": nc})
	for i in 240:
		await tree.process_frame
	# 16: правила комнаты, чужой ящик, рынок хозяина, перевод, фишки, таблица игроков
	var host_chest = null
	var mk = null
	for b in g.factory.all:
		if b.type == "chest" and str(b.bstate.get("owner", "")) == "Игрок" and b.inv.count("stone") > 0:
			host_chest = b
		if b.type == "player_market":
			mk = b
	var room_ok: bool = str(room.get("access", "")) == "put" and own_wallets() and not room.has("password") and bool(room.get("has_pass", false))
	var cr0: int = g.credits
	var deny_local: bool = host_chest != null and g.cmd("take", {"b": host_chest}) == null and g.player.inv.count("stone") == 0
	if host_chest:
		rpc_id(1, "req_cmd", "take", _pack({"b": host_chest}), g.player.inv.to_array(), [g.player.position.x, g.player.position.y, g.player.position.z])
		g.player.inv.add("plank", 3)
		g.cmd("put", {"b": host_chest, "id": "plank", "n": 1})
	for i in 120:
		await tree.process_frame
	var deny_ok: bool = deny_local and g.player.inv.count("stone") == 0
	var iron0: int = g.player.inv.count("iron_ingot")
	if mk:
		g.cmd("mbuy", {"b": mk, "id": "iron_ingot", "n": 10})
	var bought := false
	var tb := Time.get_ticks_msec() + 20000   # 1.7: ждём по времени, а не по кадрам (без окна кадры идут очень быстро)
	while Time.get_ticks_msec() < tb:
		await tree.process_frame
		if g.player.inv.count("iron_ingot") >= iron0 + 10 and g.credits == cr0 - 50:
			bought = true
			break
	g.coop.chat_command("/pay Игрок 20")
	g.coop.fun("confetti", {"pos": g.player.position})
	g.coop.fun("emote", {"text": "Привет!"})
	var paid := false
	var stats_ok := false
	var tp := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < tp:
		await tree.process_frame
		paid = g.credits == cr0 - 70
		stats_ok = stats.has("Игрок") and stats.has(nick)
		if paid and stats_ok:
			break
	var lobby: Array = get_meta("lobby", [false, false])
	# 1.7: лента, протянутая гостем, поворачивается по линии; объединение зданий идёт через хозяина
	var A: Vector2i = g.factory.hq.cell + Vector2i(9, 14)
	for k in range(-1, 6):
		for j in range(-1, 4):
			g.world.remove_node(World.wc(A + Vector2i(k, j)))
	for it in g.factory.cost_of("belt"):
		g.player.inv.add(it, int(g.factory.cost_of("belt")[it]) * 6)
	for it in g.factory.cost_of("furnace"):
		g.player.inv.add(it, int(g.factory.cost_of("furnace")[it]) * 2)
	g.build_type = "belt"
	g.build_dir = 1
	g.hover_cell = A
	g.drag_last = A
	g.drag_new = A
	g.drag_placed = g.cmd("place", {"type": "belt", "cell": A, "dir": 1})
	g.hover_cell = A + Vector2i(3, 0)
	g._drag_world()
	g.build_type = ""
	var belts17 := false
	for i in 600:
		await tree.process_frame
		belts17 = true
		for k in 4:
			var bb = g.factory.building_at(A + Vector2i(k, 0))
			belts17 = belts17 and bb != null and bb.beh == "belt" and bb.dir == 0
		if belts17:
			break
	var B: Vector2i = A + Vector2i(0, 2)
	var fo := int(DB.building("furnace").get("size", 1))
	for k in range(-1, 2 * fo + 1):
		for j in range(-1, fo + 1):
			g.world.remove_node(World.wc(B + Vector2i(k, j)))
	g.cmd("place", {"type": "furnace", "cell": B, "dir": 0})
	g.cmd("place", {"type": "furnace", "cell": B + Vector2i(fo, 0), "dir": 0})
	var fused17 := false
	for i in 600:
		await tree.process_frame
		var f1 = g.factory.building_at(B)
		var f2 = g.factory.building_at(B + Vector2i(fo, 0))
		if f1 != null and f2 != null and f1 != f2 and not get_meta("fuse_sent", false):
			set_meta("fuse_sent", true)
			g.cmd("fuse", {"a": f1, "b": f2, "kind": "level"})
		if f1 != null and f1.lvl == 2:
			fused17 = true
			break
	print("TEST net_client17 guest_belt_line_turns=", belts17, " fuse_via_host=", fused17, " ", "OK" if belts17 and fused17 else "FAIL")
	# 18: мои вещи и уровень — хозяину (он хранит их в мире комнаты)
	g.level = 7
	send_my_state()
	share_research("quartz")
	for i in 240:
		await tree.process_frame
	var ok16: bool = room_ok and deny_ok and bought and paid and stats_ok and lobby[0] and lobby[1]
	print("TEST net_client16 found_in_list=", lobby[0], " wrong_pass_refused=", lobby[1], " room=", room_ok, " deny=", deny_ok, " bought=", bought, " paid=", paid, " stats=", stats_ok, " credits=", g.credits, " ",
		"OK" if ok16 else "FAIL")
	print("TEST net_client world=", world_ok, " buildings=", n_bld, " monster=", mon_ok, " placed=", placed_ok, " put=", put_ok, " sees_host=", sees_host, " ufo=", ufo_ok, " zone=", zone_ok, " ",
		"OK" if world_ok and mon_ok and placed_ok and put_ok and sees_host and ufo_ok and zone_ok and ok16 else "FAIL")
	var tq := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < tq and mode == "client":
		await tree.process_frame   # хозяин ещё проверяет, с какого порта пришёл гость (он закроет игру сам)
	tree.quit()


func _send_chat_text(t: String) -> void:
	rpc("chat_msg", nick, color, t)


# ================================================================ 16: правила комнаты, кошельки, свои базы

func own_wallets() -> bool:
	return mode != "" and str(room.get("wallets", "shared")) == "own"


func separate() -> bool:
	return mode != "" and str(room.get("start", "together")) != "together"


## Ник того, от чьего лица сейчас выполняется команда.
func actor_nick() -> String:
	if mode == "":
		return ""
	if actor != 0 and peers.has(actor):
		return str(peers[actor].nick)
	return nick


func credits_for(pid: int) -> int:
	if not own_wallets():
		return game.credits
	return int(wallets.get(str(peers[pid].nick) if peers.has(pid) else "", 0))


func wallet_get(nk: String) -> int:
	if not own_wallets() or nk == actor_nick():
		return game.credits
	if nk == nick:
		return int(_swap.credits) if not _swap.is_empty() else game.credits
	return int(wallets.get(nk, 0))


func wallet_add(nk: String, x: int) -> void:
	if not own_wallets():
		return   # общие деньги: перевод самому себе
	if nk == actor_nick():
		game.credits += x
	elif nk == nick:
		if not _swap.is_empty():
			_swap.credits = int(_swap.credits) + x
		else:
			game.credits += x
	elif nk != "":
		wallets[nk] = int(wallets.get(nk, 0)) + x


## Награда за монстра игроку по сети (свои кошельки).
func wallet_add_id(pid: int, x: int) -> void:
	if peers.has(pid):
		wallet_add(str(peers[pid].nick), x)


func store_of(nk: String) -> Inventory:
	if not stores.has(nk):
		stores[nk] = Inventory.new(1)
	return stores[nk]


func empty_store() -> Inventory:
	_empty.slots = [null]
	return _empty


## Почему игрок не может это сделать с чужим зданием ("" — можно).
func deny(name: String, a: Dictionary, who: String) -> String:
	if mode == "" or game == null:
		return ""
	if name in ["mbuy", "msell", "pay", "gift"] and not bool(room.get("trade", true)):
		return "Торговля выключена в правилах комнаты"
	var swap_into := ""   # 1.1.20 B14-4: перетаскивание из рюкзака на занятую ячейку другого предмета — это обмен (то есть «взять»)
	if name == "mv":
		if str(a.get("s", "")) == "p" and a.get("b") is Object:
			var dinv = a.b.get(str(a.get("d", "")))
			var di := int(a.get("di", -1))
			if dinv is Inventory and di >= 0 and di < dinv.slots.size() and dinv.slots[di] != null and (str(dinv.slots[di].id) != str(a.get("sid", "")) or dinv.slots[di].has("dur") or DB.stack_of(str(dinv.slots[di].id)) <= 1):   # B15-1/B16-1: инструмент (стопка 1) не складывается, а меняется местами; еда складывается (B16-2)
				swap_into = str(dinv.slots[di].id)
		name = "put" if str(a.get("s", "")) == "p" and swap_into == "" else "take"   # 1.5: перетаскивание — «взять» или «положить»
	if not (name in OWN_CMDS or name in PUT_CMDS or name == "place"):
		return ""
	var bs := []
	if name == "demolish" or name == "place":   # 1.1.15: улучшение или бортики поверх чужого здания — как снос
		var ob = game.factory.building_at(World.wc(a.cell))
		# B16-5: поставить здание на чужой фундамент — не снос (на нём и строят)
		if not (name == "place" and ob != null and ob.beh == "foundation" and str(DB.building(str(a.get("type", ""))).get("behavior", "")) != "foundation"):
			bs.append(ob)
	for k in ["b", "a", "h"]:
		if a.has(k) and a[k] is Object:
			bs.append(a[k])
	for b in bs:
		if b == null or not ("bstate" in b):
			continue
		if "host" in b and b.host != null:
			b = b.host   # 1.1.20 B14-6: владелец встроенного — владелец составного
		var own := str(b.bstate.get("owner", ""))
		if own == "" or own == who:
			continue
		if Coop.is_market(b) and not name in PUT_CMDS:
			return "Это рынок игрока %s — покупайте через окно рынка" % own
		var acc := str(room.get("access", "all"))
		if acc == "all":
			continue
		if acc == "put" and name in PUT_CMDS:
			continue
		return "Это здание игрока %s: %s" % [own, "можно только класть (правила комнаты)" if acc == "put" else "чужое трогать нельзя (правила комнаты)"]
	return ""


## Своя база нового игрока: точка в стороне от штаба, участок земли и аванпост с набором.
func _make_base(n: String) -> void:
	if game.island != null:
		for c in game.world.island_cells:
			if game.factory.can_place("outpost",c) == "":
				game.cmd("coop_base",{"cell":c,"rc":Vector2i.ZERO,"owner":n})
				return
		return
	# B-1 r4: участок — по числу уже созданных баз (а не подключённых), занятый чужим аванпостом пропускаем
	var k0 := 1
	for b in game.factory.all:
		if b.type == "outpost" and not b.dead:
			k0 += 1
	var cell := Vector2i.ZERO
	var rc := Vector2i.ZERO
	for k in range(k0, k0 + 16):
		var r: Array = _base_spot(k)
		cell = r[0]
		rc = r[1]
		# B-6 r5: участок свободен, только если на всём следе аванпоста нет построек и воды
		var free := true
		for q in game.factory.footprint("outpost", cell):
			q = World.wc(q)
			if game.factory.grid.has(q) or not game.world.in_bounds(q) or game.world.water_at(q):
				free = false
				break
		if free:
			break
	game.cmd("coop_base", {"cell": cell, "rc": rc, "owner": n})


func _base_spot(k: int) -> Array:
	var z = game.zone
	var c: Dictionary = DB.setting("coop", {})
	var far := str(room.get("start", "")) == "far"
	var ang := float(k) * 2.39996 + 0.7
	var dist: float = (z.half() if z and z.on() else 16.0) + float(c.get("far_dist" if far else "near_dist", 120 if far else 34))
	var c0: Vector3 = game.factory.hq.center()
	var p: Vector3 = c0 + Vector3(cos(ang), 0, sin(ang)) * dist
	var W: int = game.world.W
	if game.world.wrap:
		p = World.wrap_pos(p)
	else:
		p.x = clampf(p.x, 24.0, W * World.C - 24.0)
		p.z = clampf(p.z, 24.0, W * World.C - 24.0)
	var rc: Vector2i = z.patch_at(p) if z and z.on() else Vector2i.ZERO
	if z and z.on():
		p = z.patch_center(rc)
	return [World.world_to_cell(p), rc]


# ---------------------------------------------------------------- код комнаты, подсказки

## Код комнаты: адрес IPv4 и порт в 10 буквах-цифрах (без 0/O и 1/I), например K7Q2M-9XAB3.
static func make_code(ip: String, port := OPEN_PORT) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var v := 0
	for x in parts:
		v = v * 256 + clampi(int(x), 0, 255)
	v = v * 65536 + port
	var s := ""
	for i in 10:
		s = CODE_ABC[v & 31] + s
		v >>= 5
	return s.substr(0, 5) + "-" + s.substr(5)


static func decode_code(code: String) -> Array:
	var s := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if s.length() != 10:
		return []
	var v := 0
	for ch in s:
		var k := CODE_ABC.find(ch)
		if k < 0:
			return []
		v = (v << 5) | k
	var port := v & 0xFFFF
	v >>= 16
	return ["%d.%d.%d.%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255], port]


static func lan_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			out.append(a)
	return out


## Коды комнаты: lan — для своей сети (и Radmin VPN / ZeroTier), net — через интернет (если UPnP открыл порт).
func codes() -> Dictionary:
	var out := {}
	var ips := lan_ips()
	if not ips.is_empty():
		out["lan"] = make_code(ips[0], port)
	if ext_ip != "" and upnp_ok:
		out["net"] = make_code(ext_ip, port)
	elif lobby != null and lobby.pub_ip != "" and bool(room.get("punch", true)):
		out["net"] = make_code(lobby.pub_ip, port)   # 1.0.8: без UPnP — гости входят через «пробой роутера»
	return out


static func no_answer_text() -> String:
	var pt: int = _self().port if _self() != null else OPEN_PORT
	return "Хозяин не отвечает. Проверьте:\n• код или адрес набран без ошибок, комната ещё открыта;\n• у хозяина Windows спросил «Разрешить доступ» для игры — нужно нажать «Разрешить» (или добавить игру в брандмауэр);\n• через интернет игра сама пробует «пробить» роутер; если не вышло (у кого-то мобильный интернет или строгий роутер) — хозяину открыть порт %d UDP (UPnP или вручную) или сменить порт при создании комнаты;\n• если ничего не помогает — оба запустите Radmin VPN или ZeroTier: комната появится в списке, как дома по Wi-Fi." % pt


static func _private_ip(ip: String) -> bool:
	return ip.begins_with("10.") or ip.begins_with("192.168.") or ip.begins_with("100.") or ip == "" or (ip.begins_with("172.") and int(ip.get_slice(".", 1)) >= 16 and int(ip.get_slice(".", 1)) <= 31)


# ---------------------------------------------------------------- UPnP (порт на роутере)

func _start_upnp(port: int) -> void:
	upnp_msg = "Открываю порт на роутере (UPnP)…"
	upnp_ok = false
	ext_ip = ""
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(port: int) -> void:
	var u := UPNP.new()
	var r := u.discover(2000, 2, "InternetGatewayDevice")
	var ok := false
	var ip := ""
	var msg := ""
	if r != UPNP.UPNP_RESULT_SUCCESS or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
		msg = "Роутер не ответил на UPnP. Друзья в вашей сети (или в Radmin VPN / ZeroTier) видят комнату в списке; через интернет — откройте на роутере порт %d UDP." % port
	elif u.add_port_mapping(port, port, "Project Aloverdoz", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		msg = "Роутер не дал открыть порт (UPnP выключен в его настройках). Откройте порт %d UDP вручную или играйте через Radmin VPN / ZeroTier." % port
	else:
		ip = u.query_external_address()
		ok = true
		if _private_ip(ip):
			msg = "Порт открыт, но у провайдера общий адрес (%s) — из интернета к вам не подключиться. Выход: Radmin VPN / ZeroTier." % ip
			ok = false
		else:
			msg = "Порт %d открыт на роутере (UPnP), внешний адрес %s." % [port, ip]
	call_deferred("_upnp_done", u, ok, ip, msg)


func _upnp_done(u: UPNP, ok: bool, ip: String, msg: String) -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	_upnp = u
	upnp_ok = ok and mode == "host"
	ext_ip = ip
	upnp_msg = msg
	if game != null and is_instance_valid(game) and mode == "host":
		game.notify(msg, Color(0.6, 0.9, 1) if ok else Color(1, 0.8, 0.5))


# ---------------------------------------------------------------- список комнат в локальной сети

func _announce() -> void:
	var cd := codes()
	var info := {"fc": 2, "name": str(room.get("name", "")), "host": nick, "game": DB.game_name(), "ver": DB.game_version(), "port": port,
		"players": peers.size(), "max": int(room.get("max_players", 8)), "pass": bool(room.get("has_pass", false)),
		"start": str(room.get("start", "together")), "code": cd.get("lan", ""), "net_code": cd.get("net", ""), "ded": dedicated}
	var pkt := JSON.stringify(info).to_utf8_buffer()
	var dests := {"255.255.255.255": true, "127.0.0.1": true}
	for ip in lan_ips():
		var pp: PackedStringArray = ip.split(".")
		dests["%s.%s.%s.255" % [pp[0], pp[1], pp[2]]] = true
		if pp[0] in ["25", "26"]:
			dests["%s.255.255.255" % pp[0]] = true   # Hamachi, Radmin VPN
	for d in dests:
		_bc.set_dest_address(d, DISCOVERY_PORT)
		_bc.put_packet(pkt)


## Слушать объявления комнат (пока открыта страница «Сетевая игра»).
func lan_listen(on: bool) -> void:
	if on and _listen == null:
		_listen = PacketPeerUDP.new()
		if _listen.bind(DISCOVERY_PORT) != OK:
			_listen = null
			lan_msg = "Список комнат недоступен: порт %d занят (запущена вторая копия игры?). Подключайтесь по коду." % DISCOVERY_PORT
		else:
			lan_msg = ""
	elif not on and _listen != null:
		_listen.close()
		_listen = null
		lan_rooms.clear()


func _poll_lan() -> void:
	if _listen == null:
		return
	while _listen.get_available_packet_count() > 0:
		var pkt := _listen.get_packet()
		var ip := _listen.get_packet_ip()
		var d = JSON.parse_string(pkt.get_string_from_utf8())
		if d is Dictionary and int(d.get("fc", 0)) == 2:
			d["ip"] = ip
			d["seen"] = Time.get_ticks_msec()
			# одна и та же комната приходит по нескольким адресам (127.0.0.1, сеть, VPN) — храним один раз
			var key := str(d.get("code", "")) if str(d.get("code", "")) != "" else "%s:%d" % [ip, int(d.get("port", PORT))]
			if ip.begins_with("127.") and lan_rooms.has(key):
				d["ip"] = lan_rooms[key].ip
			lan_rooms[key] = d
	for k in lan_rooms.keys():
		if Time.get_ticks_msec() - int(lan_rooms[k].seen) > 5000:
			lan_rooms.erase(k)


# ---------------------------------------------------------------- кошелёк, подарки, таблица игроков

@rpc("authority", "call_remote", "reliable")
func set_wallet(cr: int) -> void:
	if game:
		game.credits = cr


## Отдать предметы игроку по нику (от лица того, кто сейчас действует).
func give_nick(nk: String, id: String, n: int) -> bool:
	if nk == nick:
		var inv: Inventory = _swap.inv if not _swap.is_empty() else game.player.inv
		var left: int = inv.add(id, n)
		inv.changed.emit()
		if left > 0:   # B15-4: рюкзак хозяина полон — в штаб, не влезло — на землю
			# B16-4: пока выполняется команда гостя, «склад» — аванпост гостя; хозяину — его штаб
			var hq_b = game.factory.hq
			var st = (hq_b.inv if hq_b != null else null) if not _swap.is_empty() else game.factory._store()
			if st != null:
				left = st.add(id, left)
			if left > 0:
				if _swap.is_empty():
					game.overflow(id, left, game.player.position + Vector3(0, 1, 0))
				else:
					game.drops.spawn(id, left, (hq_b.center() if hq_b != null else game.player.position) + Vector3(0, 1.5, 0))
		return true
	var pid: int = game.coop.peer_of(nk)
	if pid == 0:
		return false
	give_to(pid, id, n)
	return true


func _send_stats() -> void:
	var st := {}
	for id in peers:
		var nk := str(peers[id].nick)
		st[nk] = {"cr": credits_for(id) if id != 1 else game.credits, "bld": 0, "rep": int(rep.get(nk, 0))}
	for b in game.factory.all:
		var o := str(b.bstate.get("owner", ""))
		if o != "" and st.has(o) and b.beh != "belt":
			st[o].bld += 1
	stats = st
	rpc("stats_sync", st)


@rpc("authority", "call_remote", "reliable")
func stats_sync(st: Dictionary) -> void:
	stats = st


## Фишка (эмоция, снежок, салют…) от другого игрока.
@rpc("any_peer", "call_remote", "reliable")
func fun_remote(kind: String, d: Dictionary) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if game and game.coop:
		game.coop.on_fun(kind, d)


func req_roll(kind: String) -> void:
	if mode == "host":
		_do_roll(nick, kind)
	else:
		rpc_id(1, "req_roll_remote", kind)


@rpc("any_peer", "call_remote", "reliable")
func req_roll_remote(kind: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode == "host" and peers.has(multiplayer.get_remote_sender_id()):
		_do_roll(str(peers[multiplayer.get_remote_sender_id()].nick), kind)


func _do_roll(who: String, kind: String) -> void:
	var t := "%s бросил кубик: %d" % [who, randi_range(1, 6)] if kind == "roll" else "%s подбросил монетку: %s" % [who, "орёл" if randf() < 0.5 else "решка"]
	send_chat_raw(t)


@rpc("any_peer", "call_remote", "reliable")
func req_thanks(to: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	if mode == "host" and peers.has(multiplayer.get_remote_sender_id()):
		req_thanks_local(str(peers[multiplayer.get_remote_sender_id()].nick), to)


func req_thanks_local(from: String, to: String) -> void:
	if from == to or game.coop.peer_of(to) == 0:
		return
	var key := from + ">" + to
	if Time.get_ticks_msec() < int(_thanks_t.get(key, 0)):
		return
	_thanks_t[key] = Time.get_ticks_msec() + 60000
	rep[to] = int(rep.get(to, 0)) + 1
	send_chat_raw("%s говорит спасибо игроку %s (репутация %d)" % [from, to, int(rep[to])])


## Сообщение от «Сети» всем (и себе).
func send_chat_raw(t: String) -> void:
	if mode == "":
		return
	rpc("chat_msg", "Сеть", "#8fd4ff", t)
	_show_chat("Сеть", "#8fd4ff", t)


func send_chat_text(t: String) -> void:
	if mode == "":
		return
	rpc("chat_msg", nick, color, t)
	_show_chat(nick, color, t)


# ---------------------------------------------------------------- выгнать игрока

func start_vote(target: String) -> void:
	if mode == "host":
		_vote_begin(nick, target)
	else:
		rpc_id(1, "req_vote", target)


@rpc("any_peer", "call_remote", "reliable")
func req_vote(target: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	var sid := multiplayer.get_remote_sender_id()
	if mode == "host" and peers.has(sid):
		_vote_begin(str(peers[sid].nick), target)


func _vote_begin(from: String, target: String) -> void:
	var tid: int = game.coop.peer_of(target)
	if tid == 0 or tid == 1:
		send_chat_raw("Нет такого игрока: %s" % target if tid == 0 else "Хозяина комнаты выгнать нельзя")
		return
	if from == nick:
		kick(tid)
		return
	if not _vote.is_empty():
		return
	_vote = {"target": target, "yes": {from: true}, "no": {}, "until": Time.get_ticks_msec() + int(float(DB.setting("coop", {}).get("vote_time", 30)) * 1000)}
	send_chat_raw("%s предлагает выгнать %s. Напишите /yes или /no (30 с)" % [from, target])


func vote(yes: bool) -> void:
	if mode == "host":
		_vote_answer(nick, yes)
	else:
		rpc_id(1, "req_voteans", yes)


@rpc("any_peer", "call_remote", "reliable")
func req_voteans(yes: bool) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	var sid := multiplayer.get_remote_sender_id()
	if mode == "host" and peers.has(sid):
		_vote_answer(str(peers[sid].nick), yes)


func _vote_answer(who: String, yes: bool) -> void:
	if _vote.is_empty() or who == str(_vote.target):
		return
	_vote.yes.erase(who)
	_vote.no.erase(who)
	(_vote.yes if yes else _vote.no)[who] = true
	if _vote.yes.size() * 2 > _voters():
		_finish_vote()


func _finish_vote() -> void:
	var v := _vote
	_vote = {}
	var tid: int = game.coop.peer_of(str(v.target))
	if v.yes.size() * 2 > _voters() and tid > 1:
		send_chat_raw("%s выгнан голосованием" % v.target)
		kick(tid)
	else:
		send_chat_raw("Голосование не прошло: %s остаётся" % v.target)


## Сколько игроков голосует (все, кроме выгоняемого; у выделенного сервера хозяина среди игроков нет).
func _voters() -> int:
	return maxi(1, peers.size() - 1)   # B-2 r7: и на выделенном сервере выгоняемый не голосует


## 1.0.9: команда администратора выделенного сервера из чата: /admin пароль команда
@rpc("any_peer", "call_remote", "reliable")
func req_admin(text: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	var sid := multiplayer.get_remote_sender_id()
	if mode != "host" or server == null or not peers.has(sid):
		return
	if _admin_blocked(sid):
		rpc_id(sid, "chat_msg", "Сервер", "#ffd040", "Слишком много попыток — подождите минуту")
		return
	var ans: String = server.admin(str(peers[sid].nick), text)
	if ans == "Неверный пароль администратора":
		_admin_fail(sid)
	if ans != "":
		rpc_id(sid, "chat_msg", "Сервер", "#ffd040", ans)


## 1.1.11: админ-панель. Гость: admin пароль → хозяин проверяет пароль администратора сервера.
@rpc("any_peer", "call_remote", "reliable")
func req_admin_login(pw: String) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	var sid := multiplayer.get_remote_sender_id()
	if mode != "host" or game == null or not peers.has(sid):
		return
	if not game.admin.is_admin_peer(sid) and _admin_blocked(sid):
		rpc_id(sid, "admin_reply", false, "Слишком много попыток — подождите минуту")
		return
	var r: Array = game.admin.host_login(sid, str(peers[sid].nick), pw)
	if not r[0]:
		_admin_fail(sid)
	rpc_id(sid, "admin_reply", r[0], r[1])
	if r[0]:
		rpc_id(sid, "admin_players", game.admin.host_players())


## 1.1.15: не больше 5 попыток входа в админку в минуту с одного подключения (подбор пароля через игру).
var _adm_tries := {}
## A-8: считаем только неверные пароли и по адресу игрока (переподключение не даёт новых попыток).
func _adm_key(sid: int):
	var mp = multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var pr: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(sid)
		if pr != null:
			return pr.get_remote_address()
	return sid


func _admin_blocked(sid: int) -> bool:
	var now := Time.get_ticks_msec()
	var k = _adm_key(sid)
	var l: Array = (_adm_tries.get(k, []) as Array).filter(func(t): return now - int(t) < 60000)
	_adm_tries[k] = l
	return l.size() >= 5


func _admin_fail(sid: int) -> void:
	var k = _adm_key(sid)
	var l: Array = _adm_tries.get(k, [])
	l.append(Time.get_ticks_msec())
	_adm_tries[k] = l


## Совместимость со старыми пробами: попытка засчитана и разрешена ли.
func _admin_rate(sid: int) -> bool:
	if _admin_blocked(sid):
		return false
	_admin_fail(sid)
	return true


## B-6 r3: хозяин провёл сделку по заказу гостя — заказ можно убрать.
@rpc("authority", "call_remote", "reliable")
func order_done(oid: int, text: String) -> void:
	if game != null and game.orders != null:
		game.orders.done_remote(oid, text)


## 1.1.15: гость продал (на хозяине) — его заработок и опыт.
@rpc("authority", "call_remote", "reliable")
func trade_credit(total: int, xp: float) -> void:
	if game == null:
		return
	game.trade_earned += total
	if own_wallets():
		game.earned += total   # B17-2
	game.add_xp(xp)
	game.notify("Продано за %d кр" % total, Color(1, 0.85, 0.3))


## 1.1.15: штаб разрушен — поражение у всех.
func hq_lost() -> void:
	if mode == "host":
		rpc("hq_lost_rpc")


@rpc("authority", "call_remote", "reliable")
func hq_lost_rpc() -> void:
	if game != null and not game.game_over:
		game.on_hq_destroyed()


@rpc("authority", "call_remote", "reliable")
func admin_reply(ok: bool, msg: String) -> void:
	if game != null:
		game.admin.on_reply(ok, msg)


@rpc("any_peer", "call_remote", "reliable")
func req_admin_act(name: String, d: Dictionary) -> void:
	if not _authed():
		return   # 1.1.15: от не вошедшего (неверный пароль, бан) — ничего не принимаем
	var sid := multiplayer.get_remote_sender_id()
	if mode != "host" or game == null:
		return
	if not game.admin.is_admin_peer(sid):
		rpc_id(sid, "admin_reply", false, "Нет прав администратора")
		return
	var msg: String = game.admin.host_act(name, d, sid)
	if msg != "":
		rpc_id(sid, "toast", msg, Color(1, 0.85, 0.35))
	# список игроков — после изменений (с небольшой задержкой: гость успеет прислать свой уровень)
	get_tree().create_timer(0.6 if name == "player" else 0.05).timeout.connect(func():
		if peers.has(sid) and game != null:
			rpc_id(sid, "admin_players", game.admin.host_players()))


@rpc("authority", "call_remote", "reliable")
func admin_players(list: Array) -> void:
	if game != null:
		game.admin.set_players(list)


## Хозяин → гость: изменить героя (уровень, очки, лечение, бессмертие, бесплатная стройка, телепорт).
@rpc("authority", "call_remote", "reliable")
func admin_apply(ch: Dictionary) -> void:
	if game != null:
		game.admin.apply_self(ch)
		send_my_state()


func kick(pid: int) -> void:
	if not peers.has(pid):
		return
	if str(uids.get(pid, "")) != "":
		banned["uid:" + str(uids[pid])] = true   # A-14/B-4 r3: банится сам игрок, а не ник (у многих ник «Игрок»)
	banned[str(peers[pid].nick)] = true   # B-4 r4: ник — для входа без uid (с uid проверяется только uid)
	rpc_id(pid, "refused", "Вас выгнали из комнаты")
	get_tree().create_timer(0.8).timeout.connect(func():
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer and mode == "host":
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(pid))


## Проверка гостя: найти комнату в списке своей сети, войти с неверным паролем (отказ), затем с верным.
func Lobby_on() -> bool:
	if lobby == null:
		return false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lobby_url="):
			return true
	return false


func _find_test() -> void:
	var tree := get_tree()
	lan_listen(true)
	var d := {}
	var t_end := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < t_end:
		await tree.process_frame
		if not lan_rooms.is_empty():
			d = lan_rooms.values()[0]
			break
	var found := not d.is_empty() and str(d.get("name", "")) == "Проверка" and bool(d.get("pass", false))
	var addr: String = str(d.get("code", "")) if str(d.get("code", "")) != "" else str(d.get("ip", "127.0.0.1"))
	if d.is_empty():
		addr = "127.0.0.1"
	join(addr, 0, "неверный", false)
	var refused_ok := false
	for i in 900:
		await tree.process_frame
		if str(get_meta("refused", "")).contains("пароль"):
			refused_ok = true
			break
	await tree.create_timer(1.5).timeout
	set_meta("lobby", [found, refused_ok])
	print("NET find code=", addr, " found=", found, " refused=", refused_ok)
	# 18: та же комната — в общем списке комнат в интернете (сервер объявлений из --lobby_url)
	if Lobby_on():
		lobby.listing = true
		lobby.refresh()
		var net_found := {}
		for i in 40:
			await tree.create_timer(0.5).timeout
			var res: Array = lobby.search("пров")
			if not res.is_empty():
				net_found = res[0]
				break
			if i % 6 == 5:
				lobby.refresh()
		var none: bool = lobby.search("нет-такой-комнаты").is_empty()
		lobby.listing = false
		print("TEST net_lobby18 found=", not net_found.is_empty(), " name='", net_found.get("name", ""), "' ip=", net_found.get("ip", ""), " pass=", net_found.get("pass", false), " search_none=", none, " ",
			"OK" if not net_found.is_empty() and str(net_found.get("name", "")) == "Проверка" and bool(net_found.get("pass", false)) and none else "FAIL")
		set_meta("nf", net_found)
	# 1.0.8: с --net_punch входим «через интернет» — с пробоем роутера через сервер объявлений
	var nf: Dictionary = get_meta("nf", {})
	if not nf.is_empty() and OS.get_cmdline_user_args().has("--net_punch"):
		join(str(nf.ip), int(nf.get("port", 0)), "123")
	else:
		join(addr, 0, "123", false)


@rpc("authority","call_remote","reliable")
func shore_event(data: Dictionary, added: Array, removed: Array) -> void:
	if game == null or game.island == null: return
	if not added.is_empty() or not removed.is_empty():
		game.island.change_land(added,removed)
	game.island.read_state(data)

@rpc("authority","call_remote","reliable")
func shore_door(cell: Vector2i) -> void:
	if game != null and game.island != null: game.island.show_door(cell)

@rpc("authority","call_remote","reliable")
func shore_fire(cell: Vector2i, lit: bool) -> void:
	if game == null or game.island == null: return
	var b = game.factory.grid.get(cell)
	if b != null and b.type == "campfire": game.island.set_fire(b,lit)

@rpc("authority","call_remote","reliable")
func shore_field(cell: Vector2i, idx: int, span: int, quality: String, next_price: int, count: int) -> void:
	if game == null or game.island == null: return
	var w = game.world
	for c in w.field_cells(cell,span):
		w.set_deposit(c,idx)
		w.set_purity(c,quality)
	w.ordered_fields[cell] = [idx,span,quality]
	w.order_price = next_price
	w.orders_placed = count
