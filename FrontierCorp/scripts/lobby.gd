extends Node
## 18: общий список комнат в интернете. Хозяин открытой комнаты раз в несколько минут публикует короткое объявление
## (название, ник, адрес и порт, игроки, пароль да/нет, версия) на общий сервер объявлений; игроки на странице
## «Сетевая игра» видят все свежие объявления и ищут по названию и нику.
## Сервер — любой ntfy-совместимый (по умолчанию бесплатный https://ntfy.sh, свой можно поднять из tools/lobby_server.py):
##   публикация: POST <адрес>/<тема>  (тело — JSON объявления)
##   список:     GET  <адрес>/<тема>/json?poll=1&since=<сек>s  (по строке JSON на сообщение, поле message — объявление)
## Правится: «Настройки» → «Сетевая игра»: адрес, тема, как часто объявлять, сколько секунд считать объявление свежим.
## Подключение всё равно идёт напрямую к хозяину: у него должен быть открыт порт (UPnP или вручную) или общий VPN.

var rooms := {}          # id комнаты → объявление (+ "seen" — когда получено)
var msg := ""            # что показать в меню (ошибка сети, «обновлено»)
var listing := false     # страница «Сетевая игра» открыта — обновляем список
var my_id := ""          # id нашей комнаты (хозяин)
var pub_ip := ""         # внешний адрес хозяина (UPnP или сервис «мой IP»)
var _pub: HTTPRequest
var _get: HTTPRequest
var _ip: HTTPRequest
var _pub_t := 0.0
var _get_t := 0.0
var _last_players := -1
var _busy_get := false
var _busy_pub := false
var updated_at := 0      # мс, когда список последний раз обновился
# 1.0.8: «пробой роутера» (UDP hole punching). Гость узнаёт свой внешний адрес и порт (STUN), кладёт их в тему
# «<тема>_p_<адрес хозяина>_<порт>» на том же сервере объявлений; хозяин читает её и шлёт гостю пакеты со своего
# игрового порта — его роутер начинает пропускать гостя, и подключение идёт напрямую без UPnP и ручного порта.
var _pget: HTTPRequest
var _ppub: HTTPRequest
var _pget_t := 0.0
var _busy_pget := false
var _seen_punch := {}     # id запроса → true
var _targets: Array = []  # [{ip, port, until}] — куда хозяин шлёт пакеты
var _shoot_t := 0.0
var punched := 0          # сколько гостей хозяин «пропустил» (для проверки)
var punch_ports := {}     # порт гостя → true (для проверки)
var _pj := {}             # гость: {ip, port, local, stage, t}
var _pj_thread: Thread
var punch_msg := ""
static var url_override := ""   # 1.0.9: выделенный сервер: адрес списка комнат из server.cfg
static var off := false          # 1.0.9: server.cfg → lobby=false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pub = HTTPRequest.new()
	_pub.timeout = 10.0
	add_child(_pub)
	_pub.request_completed.connect(_on_pub)
	_get = HTTPRequest.new()
	_get.timeout = 12.0
	add_child(_get)
	_get.request_completed.connect(_on_get)
	_ip = HTTPRequest.new()
	_ip.timeout = 8.0
	add_child(_ip)
	_ip.request_completed.connect(_on_ip)
	_pget = HTTPRequest.new()
	_pget.timeout = 8.0
	add_child(_pget)
	_pget.request_completed.connect(_on_pget)
	_ppub = HTTPRequest.new()
	_ppub.timeout = 8.0
	add_child(_ppub)
	_ppub.request_completed.connect(func(_r, _c, _h, _b): pass)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lobby_ip="):
			pub_ip = a.substr(11)   # для автотеста: свой адрес без сервиса «мой IP»


static func cfg() -> Dictionary:
	var c = DB.setting("coop", {})
	return c if c is Dictionary else {}


static func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--no_lobby") or off:
		return false
	if url_override != "":
		return true
	for a in args:
		if a.begins_with("--lobby_url="):
			return true
	return bool(cfg().get("lobby", true)) and str(cfg().get("lobby_url", "")) != ""


static func base_url() -> String:
	if url_override != "":
		return url_override.trim_suffix("/")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lobby_url="):
			return a.substr(12).trim_suffix("/")
	return str(cfg().get("lobby_url", "https://ntfy.sh")).trim_suffix("/")


static func topic() -> String:
	return str(cfg().get("lobby_topic", "frontiercorp_rooms_v2")).validate_filename().replace(" ", "_")


func _process(delta: float) -> void:
	_punch_tick(delta)
	if not enabled():
		return
	var net = get_parent()
	# хозяин открытой комнаты: объявить сразу, потом раз в N секунд и когда меняется число игроков (не чаще раза в 30 с)
	if net.mode == "host" and bool(net.room.get("public", true)):
		_pub_t -= delta
		var np: int = net.peers.size()
		if _pub_t <= 0.0 or (np != _last_players and _pub_t < float(cfg().get("lobby_every", 240)) - 30.0):
			publish()
	elif my_id != "" and net.mode != "host":
		publish_closed()
	if listing:
		_get_t -= delta
		if _get_t <= 0.0:
			refresh()
	for k in rooms.keys():
		if Time.get_unix_time_from_system() - float(rooms[k].get("t", 0)) > float(cfg().get("lobby_window", 300)) + 30.0:
			rooms.erase(k)


func _info() -> Dictionary:
	var net = get_parent()
	var addr: String = net.ext_ip if net.ext_ip != "" else pub_ip
	return {"fc": 18, "id": my_id, "name": str(net.room.get("name", "")), "host": net.nick, "game": DB.game_name(), "ver": DB.game_version(),
		"ip": addr, "port": net.port, "punch": bool(net.room.get("punch", true)), "players": net.peers.size(), "max": int(net.room.get("max_players", 8)), "pass": bool(net.room.get("has_pass", false)),
		"start": str(net.room.get("start", "together")), "upnp": bool(net.upnp_ok), "ded": bool(net.dedicated), "lang": str(Prefs.get_value("lang", "ru")),
		"t": int(Time.get_unix_time_from_system()), "kh": _key_hash(_key)}


## B-7 r11: ключ комнаты. В объявлениях — только его хэш, ключ открывается в «закрыто»: чужой не закроет
## комнату и не подменит её адрес (объявление с другим хэшем отбрасывается).
var _key := ""


static func _key_hash(k: String) -> String:
	return k.sha256_text().left(16)


func publish() -> void:
	var net = get_parent()
	_pub_t = float(cfg().get("lobby_every", 240))
	_last_players = net.peers.size()
	if my_id == "":
		my_id = "%08x%04x" % [randi(), randi() % 65536]
		_key = Crypto.new().generate_random_bytes(12).hex_encode()
	if net.ext_ip == "" and pub_ip == "":
		_ask_ip()
		_pub_t = 3.0            # объявим, как только узнаем свой адрес
		return
	_send(_info())


func publish_closed() -> void:
	if my_id == "":
		return
	_send({"fc": 18, "id": my_id, "closed": true, "t": int(Time.get_unix_time_from_system()), "key": _key})
	my_id = ""
	_last_players = -1


func _send(d: Dictionary) -> void:
	if _busy_pub:
		return
	_busy_pub = true
	var err := _pub.request("%s/%s" % [base_url(), topic()], ["Content-Type: text/plain"], HTTPClient.METHOD_POST, JSON.stringify(d))
	if err != OK:
		_busy_pub = false


func _on_pub(result: int, code: int, _h, _b) -> void:
	_busy_pub = false
	var net = get_parent()
	if result != HTTPRequest.RESULT_SUCCESS or code >= 300:
		if net.mode == "host" and net.game != null:
			net.game.notify_once("lobby_pub", "Общий список комнат недоступен (%s). Друзья могут войти по коду комнаты." % _why(result, code), Color(1, 0.8, 0.5))
		_pub_t = minf(_pub_t, 60.0)


func _ask_ip() -> void:
	var u := str(cfg().get("ip_url", "https://api.ipify.org"))
	if u == "" or _ip.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_ip.request(u)


func _on_ip(result: int, code: int, _h, body: PackedByteArray) -> void:
	var s := body.get_string_from_utf8().strip_edges()
	if result == HTTPRequest.RESULT_SUCCESS and code < 300 and s.is_valid_ip_address():
		pub_ip = s
	else:
		pub_ip = ""


## Обновить список (страница «Сетевая игра» делает это сама раз в 15 с; кнопка «Обновить» — сразу).
func refresh() -> void:
	_get_t = 15.0
	if _busy_get:
		return
	_busy_get = true
	var url := "%s/%s/json?poll=1&since=%ds" % [base_url(), topic(), int(cfg().get("lobby_window", 300))]
	if _get.request(url) != OK:
		_busy_get = false
		msg = "Не удалось запросить список комнат"


func _on_get(result: int, code: int, _h, body: PackedByteArray) -> void:
	_busy_get = false
	if result != HTTPRequest.RESULT_SUCCESS or code >= 300:
		msg = "Общий список комнат недоступен (%s). Можно войти по коду комнаты." % _why(result, code)
		return
	parse(body.get_string_from_utf8())
	msg = ""
	updated_at = Time.get_ticks_msec()


## Строки ответа сервера → комнаты (последнее объявление каждой комнаты; закрытые и чужие версии отбрасываются).
func parse(text: String) -> void:
	var latest := {}
	var kh := {}   # B-7 r11: id комнаты -> хэш ключа из первого её объявления
	var closed := {}
	var now := Time.get_unix_time_from_system()
	for line in text.split("\n", false):
		var ev = JSON.parse_string(line)
		if not ev is Dictionary or str(ev.get("event", "message")) != "message":
			continue
		var d = JSON.parse_string(str(ev.get("message", "")))
		if not d is Dictionary or int(d.get("fc", 0)) != 18 or str(d.get("id", "")) == "":
			continue
		var id := str(d.id)
		# B-7 r11: время — то, что поставил сервер списка (своё «t» в сообщении можно подделать из будущего)
		if ev.has("time"):
			d["t"] = float(ev.time)
		elif float(d.get("t", 0)) > now + 120.0:
			continue
		if bool(d.get("closed", false)):
			closed[id] = str(d.get("key", ""))
			continue
		var h := str(d.get("kh", ""))
		if not kh.has(id):
			kh[id] = h
		elif kh[id] != h:
			continue   # чужое объявление под тем же id
		if latest.has(id) and float(latest[id].get("t", 0)) > float(d.get("t", 0)):
			continue
		latest[id] = d
	for id in closed:
		if latest.has(id) and (str(kh.get(id, "")) == "" or _key_hash(str(closed[id])) == str(kh[id])):
			latest[id]["closed"] = true
	rooms.clear()
	for id in latest:
		var d: Dictionary = latest[id]
		if bool(d.get("closed", false)) or now - float(d.get("t", 0)) > float(cfg().get("lobby_window", 300)) + 30.0:
			continue
		if str(d.get("game", "")) != DB.game_name() or str(d.get("ip", "")) == "" or not str(d.get("ip", "")).is_valid_ip_address():
			continue
		if rooms.size() >= 200:
			break
		d["name"] = str(d.get("name", "")).left(48)
		d["host"] = str(d.get("host", "")).left(24)
		rooms[id] = d


## Комнаты под строку поиска (название или ник), с фильтрами; сначала с местами и без пароля, потом по числу игроков.
func search(q: String, no_pass := false, free_only := false) -> Array:
	var out := []
	var s := q.strip_edges().to_lower()
	for id in rooms:
		var d: Dictionary = rooms[id]
		if id == my_id:
			continue
		if s != "" and not (str(d.get("name", "")).to_lower().contains(s) or str(d.get("host", "")).to_lower().contains(s)):
			continue
		if no_pass and bool(d.get("pass", false)):
			continue
		if free_only and int(d.get("players", 0)) >= int(d.get("max", 8)):
			continue
		out.append(d)
	out.sort_custom(func(a, b):
		var fa: bool = int(a.get("players", 0)) < int(a.get("max", 8))
		var fb: bool = int(b.get("players", 0)) < int(b.get("max", 8))
		if fa != fb:
			return fa
		return int(a.get("players", 0)) > int(b.get("players", 0)))
	return out


static func _why(result: int, code: int) -> String:
	if result == HTTPRequest.RESULT_CANT_CONNECT or result == HTTPRequest.RESULT_CANT_RESOLVE:
		return "нет связи с сервером"
	if result == HTTPRequest.RESULT_TIMEOUT:
		return "сервер не ответил"
	if code == 429:
		return "сервер просит подождать"
	return "ошибка %d/%d" % [result, code]


# ---------------------------------------------------------------- 1.0.8: пробой роутера

static func punch_on() -> bool:
	return enabled() and bool(cfg().get("punch", true))


static func _lan_ip(ip: String) -> bool:
	return ip.begins_with("10.") or ip.begins_with("192.168.") or ip.begins_with("127.") or ip.begins_with("169.254.") \
		or ip.begins_with("25.") or ip.begins_with("26.") or (ip.begins_with("172.") and int(ip.get_slice(".", 1)) >= 16 and int(ip.get_slice(".", 1)) <= 31)


## Пробивать ли роутер к этому адресу: только интернет-адреса (своя сеть и VPN и так видны). --net_punch — для проверки.
func can_punch(ip: String) -> bool:
	if not punch_on() or not ip.is_valid_ip_address():
		return false
	return OS.get_cmdline_user_args().has("--net_punch") or not _lan_ip(ip)


static func punch_topic(ip: String, port: int) -> String:
	return "%s_p_%s_%d" % [topic(), ip.replace(".", "_").replace(":", "_"), port]


func cancel_punch() -> void:
	_pj = {}


## Гость: узнать свой внешний адрес (в отдельном потоке), отправить запрос хозяину, через секунду подключиться.
func punch_join(ip: String, port: int) -> void:
	var local := 20000 + randi() % 30000
	_pj = {"ip": ip, "port": port, "local": local, "stage": "stun", "t": 0.0, "pub": "", "pub_port": 0}
	punch_msg = ""
	if _pj_thread != null and _pj_thread.is_started():
		_pj_thread.wait_to_finish()
	_pj_thread = Thread.new()
	_pj_thread.start(_stun_work.bind(local, _pj))


func _stun_work(local: int, job: Dictionary) -> void:
	var r: Array = [] if OS.get_cmdline_user_args().has("--no_stun") else stun(local)
	call_deferred("_stun_done", job, r)


func _stun_done(job: Dictionary, r: Array) -> void:
	if _pj_thread != null:
		_pj_thread.wait_to_finish()
		_pj_thread = null
	if job != _pj or _pj.is_empty():
		return
	if r.size() == 2:
		_pj.pub = str(r[0])
		_pj.pub_port = int(r[1])
	elif pub_ip != "":
		_pj.pub = pub_ip                 # STUN недоступен — считаем, что роутер не меняет порт (так у большинства)
		_pj.pub_port = int(_pj.local)
	else:
		_ask_ip()
		_pj.stage = "ip"
		return
	_send_punch()


func _send_punch() -> void:
	var d := {"fc": 18, "punch": true, "id": "%08x" % randi(), "ip": _pj.pub, "port": _pj.pub_port, "nick": get_parent().nick,
		"t": int(Time.get_unix_time_from_system())}
	_ppub.cancel_request()
	_ppub.request("%s/%s" % [base_url(), punch_topic(_pj.ip, _pj.port)], ["Content-Type: text/plain"], HTTPClient.METHOD_POST, JSON.stringify(d))
	_pj.stage = "wait"
	_pj.t = float(cfg().get("punch_wait", 2.5))   # хозяин читает запросы раз в 2 с — даём ему начать слать пакеты
	print("PUNCH request ", _pj.pub, ":", _pj.pub_port, " -> ", _pj.ip, ":", _pj.port)


func _punch_tick(delta: float) -> void:
	var net = get_parent()
	# гость: ждём адрес / хозяина, потом подключаемся со «своего» порта
	if not _pj.is_empty():
		if _pj.stage == "ip":
			if pub_ip != "":
				_pj.pub = pub_ip
				_pj.pub_port = int(_pj.local)
				_send_punch()
			else:
				_pj.t += delta
				if _pj.t > 8.0:
					_pj.stage = "wait"
					_pj.t = 0.0
		elif _pj.stage == "wait":
			_pj.t -= delta
			if _pj.t <= 0.0:
				var j := _pj
				_pj = {}
				net.join_direct(str(j.ip), int(j.port), int(j.local))
	# хозяин: читаем запросы гостей и шлём им пакеты со своего игрового порта
	if net.mode != "host" or not punch_on() or not bool(net.room.get("punch", true)):
		_targets.clear()
		return
	var my_ip: String = net.ext_ip if net.ext_ip != "" else pub_ip
	if my_ip == "":
		if _ip.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED and Engine.get_process_frames() % 300 == 0:
			_ask_ip()
	else:
		_pget_t -= delta
		if _pget_t <= 0.0 and not _busy_pget:
			_pget_t = float(cfg().get("punch_poll", 2.0))
			_busy_pget = true
			if _pget.request("%s/%s/json?poll=1&since=40s" % [base_url(), punch_topic(my_ip, net.port)]) != OK:
				_busy_pget = false
	if _targets.is_empty():
		return
	_shoot_t -= delta
	if _shoot_t > 0.0:
		return
	_shoot_t = 0.2
	var mp = net.multiplayer.multiplayer_peer
	if not mp is ENetMultiplayerPeer or mp.host == null:
		return
	var now := Time.get_ticks_msec()
	for t in _targets.duplicate():
		if now > int(t.until):
			_targets.erase(t)
			continue
		mp.host.socket_send(str(t.ip), int(t.port), "FCPUNCH".to_utf8_buffer())


func _on_pget(result: int, code: int, _h, body: PackedByteArray) -> void:
	_busy_pget = false
	if result != HTTPRequest.RESULT_SUCCESS or code >= 300:
		return
	var now := Time.get_unix_time_from_system()
	for line in body.get_string_from_utf8().split("\n", false):
		var ev = JSON.parse_string(line)
		if not ev is Dictionary or str(ev.get("event", "message")) != "message":
			continue
		var d = JSON.parse_string(str(ev.get("message", "")))
		if not d is Dictionary or not bool(d.get("punch", false)) or _seen_punch.has(str(d.get("id", ""))):
			continue
		if now - float(d.get("t", 0)) > 40.0 or not str(d.get("ip", "")).is_valid_ip_address():
			continue
		var pt := int(d.get("port", 0))
		if pt <= 0 or pt > 65535 or _targets.size() >= 32:
			continue
		_seen_punch[str(d.id)] = true
		_targets.append({"ip": str(d.ip), "port": pt, "until": Time.get_ticks_msec() + int(float(cfg().get("punch_time", 15.0)) * 1000)})
		punched += 1
		punch_ports[pt] = true
		print("PUNCH host -> ", d.ip, ":", pt, " (", str(d.get("nick", "")), ")")


## STUN (RFC 5389): спросить у публичного сервера, с какого адреса и порта он видит наш UDP-порт local.
## Блокирует до пары секунд — вызывается в отдельном потоке. Пусто — не удалось.
static func stun(local: int) -> Array:
	var servers = cfg().get("stun", ["stun.l.google.com:19302", "stun.cloudflare.com:3478", "stun.nextcloud.com:443"])
	if not servers is Array:
		return []
	for srv in servers:
		var host := str(srv).get_slice(":", 0)
		var sp := int(str(srv).get_slice(":", 1)) if str(srv).contains(":") else 3478
		var ip := IP.resolve_hostname(host, IP.TYPE_IPV4)
		if ip == "":
			continue
		var u := PacketPeerUDP.new()
		if u.bind(local) != OK:
			return []
		u.set_dest_address(ip, sp)
		var tid := PackedByteArray()
		for i in 12:
			tid.append(randi() % 256)
		var req := PackedByteArray([0, 1, 0, 0, 0x21, 0x12, 0xA4, 0x42])
		req.append_array(tid)
		for attempt in 3:
			u.put_packet(req)
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 450:
				if u.get_available_packet_count() > 0:
					var res := parse_stun(u.get_packet(), tid)
					if res.size() == 2:
						u.close()
						return res
				OS.delay_msec(10)
		u.close()
	return []


## Ответ STUN → [адрес, порт] (XOR-MAPPED-ADDRESS, а у старых серверов MAPPED-ADDRESS).
static func parse_stun(r: PackedByteArray, tid: PackedByteArray) -> Array:
	if r.size() < 20 or r[0] != 0x01 or r[1] != 0x01 or r.slice(8, 20) != tid:
		return []
	var i := 20
	var plain := []
	while i + 4 <= r.size():
		var at := (r[i] << 8) | r[i + 1]
		var ln := (r[i + 2] << 8) | r[i + 3]
		var v := r.slice(i + 4, i + 4 + ln)
		if v.size() >= 8 and v[1] == 0x01:
			if at == 0x0020:
				var pt := ((v[2] << 8) | v[3]) ^ 0x2112
				return ["%d.%d.%d.%d" % [v[4] ^ 0x21, v[5] ^ 0x12, v[6] ^ 0xA4, v[7] ^ 0x42], pt]
			if at == 0x0001:
				plain = ["%d.%d.%d.%d" % [v[4], v[5], v[6], v[7]], (v[2] << 8) | v[3]]
		i += 4 + ((ln + 3) / 4) * 4
	return plain
