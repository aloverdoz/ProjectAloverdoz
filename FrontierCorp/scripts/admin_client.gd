extends Node
## 1.6: «Управление сервером» в игре — запросы к выделенному серверу (admin_http.gd на сервере).
## Адрес — как для входа в игру: IP или IP:порт (TCP-порт с тем же номером, что и игровой UDP).

const DEFAULT_PORT := 443

var addr := ""       # «ip:port»
var pw := ""


## «1.2.3.4», «1.2.3.4:443», «host:24680» → «хост:порт». "" — адрес не похож на адрес.
static func norm_addr(t: String) -> String:
	t = t.strip_edges().trim_prefix("http://").trim_suffix("/")
	if t == "":
		return ""
	var host := t
	var port := DEFAULT_PORT
	var i := t.rfind(":")
	if i > 0 and t.substr(i + 1).is_valid_int():
		host = t.substr(0, i)
		port = int(t.substr(i + 1))
	if host == "" or host.contains(" ") or port <= 0 or port > 65535:
		return ""
	return "%s:%d" % [host, port]


func host() -> String:
	return addr.substr(0, addr.rfind(":"))


func port() -> int:
	return int(addr.substr(addr.rfind(":") + 1))


## Запрос к серверу. Ответ — словарь {ok, err?, …}.
func api(cmd: String, args := {}) -> Dictionary:
	var d: Dictionary = args.duplicate()
	d["cmd"] = cmd
	d["pass"] = pw
	var h := HTTPRequest.new()
	h.timeout = 12.0
	add_child(h)
	var err := h.request("http://%s/api" % addr, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(d))
	if err != OK:
		h.queue_free()
		return {"ok": false, "err": "Не получилось отправить запрос (код %d)" % err, "offline": true}
	var r: Array = await h.request_completed
	h.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "offline": true, "err": "Сервер %s не отвечает. Проверьте адрес и что на сервере открыт TCP-порт %d (не только UDP)" % [addr, port()]}
	var j = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if not j is Dictionary:
		return {"ok": false, "err": "Сервер ответил непонятно (код %d) — это точно сервер %s?" % [int(r[1]), DB.game_name()]}
	return j


# ---------------------------------------------------------------- автотест (tools/test_admin.sh)

## --admin_test=адрес: первый вход (пароль), новый мир с настройками, вход в игру — правила пришли,
## второй мир, загрузка первого, удаление второго, остановка мира.
static func run_test(net, a: String) -> void:
	var tree: SceneTree = net.get_tree()
	var c = load("res://scripts/admin_client.gd").new()
	net.add_child(c)
	c.addr = norm_addr(a)
	var r: Dictionary = await c.api("info")
	var idle0: bool = str(r.get("state", "")) == "idle" and not bool(r.get("claimed", true))
	r = await c.api("auth")
	var need: bool = bool(r.get("need_claim", false))
	r = await c.api("claim", {"new_pass": "abcd1"})
	var claimed: bool = bool(r.get("ok", false))
	r = await c.api("claim", {"new_pass": "hack"})
	var reclaim_refused: bool = not bool(r.get("ok", true))
	c.pw = "wrong"
	r = await c.api("auth")
	var wrong_refused: bool = not bool(r.get("ok", true))
	c.pw = "abcd1"
	r = await c.api("auth")
	var boot: String = str(r.get("boot", ""))
	var room := {"name": "Админ-сервер", "password": "rp", "size": 256, "res": "few", "max_players": 5, "modules": {"waves": false, "survival": true},
		"ov": {"waves/interval": 1111.0, "settings/hunger_rate": 0.66}}
	r = await c.api("create", {"title": "Тест мир", "room": room})
	var s1 := str(r.get("slot", ""))
	var st: Dictionary = await _wait(c, boot, tree)
	var created: bool = str(st.get("state", "")) == "running" and str(st.get("world", "")) == s1 and str(st.get("room_pass", "")) == "rp" \
		and str(st.get("name", "")) == "Админ-сервер" and int(st.get("max_players", 0)) == 5
	# вход в игру: правила мира пришли с сервера
	net.nick = "Админ"
	var jerr: String = net.join(c.host(), c.port(), "rp", false)
	var joined := false
	var rules := false
	for i in 240:
		await tree.create_timer(0.5).timeout
		if net.game != null and is_instance_valid(net.game) and net.game.factory.hq != null:
			await tree.create_timer(1.0).timeout
			joined = true
			rules = int(DB.data.waves.get("interval", 0)) == 1111 and absf(float(DB.setting("hunger_rate", 0)) - 0.66) < 0.001 \
				and net.game.module("survival") and not net.game.module("waves")
			break
	net.leave()
	await tree.create_timer(2.0).timeout
	boot = str(st.get("boot", ""))
	r = await c.api("create", {"title": "Второй", "room": {"size": 256}})
	var s2 := str(r.get("slot", ""))
	st = await _wait(c, boot, tree)
	var second: bool = str(st.get("world", "")) == s2 and (st.get("worlds", []) as Array).size() == 2
	boot = str(st.get("boot", ""))
	r = await c.api("load", {"slot": s1})
	st = await _wait(c, boot, tree)
	var loaded: bool = str(st.get("world", "")) == s1 and str(st.get("room_pass", "")) == "rp"
	r = await c.api("delete", {"slot": s2})
	st = await c.api("auth")
	var deleted: bool = bool(r.get("ok", false)) and (st.get("worlds", []) as Array).size() == 1
	# 1.7: новости лаунчера — описание версии из manifest.txt, свой текст в news.txt, сброс обратно
	var n0: bool = str(st.get("news", "")) == "Описание версии" and not bool(st.get("news_custom", true)) and bool(st.get("news_ok", false))
	r = await c.api("news", {"text": "Рестарт в 20:00"})
	var n1: bool = bool(r.get("ok", false)) and str(r.get("news", "")) == "Рестарт в 20:00" and bool(r.get("custom", false))
	r = await c.api("auth")
	var n2: bool = str(r.get("news", "")) == "Рестарт в 20:00"
	r = await c.api("news", {"text": ""})
	var n3: bool = bool(r.get("ok", false)) and str(r.get("news", "")) == "Описание версии" and not bool(r.get("custom", true))
	var news_ok := n0 and n1 and n2 and n3
	boot = str(st.get("boot", ""))
	r = await c.api("stop_world")
	st = await _wait(c, boot, tree)
	var stopped: bool = str(st.get("state", "")) == "idle" and (st.get("worlds", []) as Array).size() == 1
	var ok := idle0 and need and claimed and reclaim_refused and wrong_refused and created and jerr == "" and joined and rules and second and loaded and deleted and stopped and news_ok
	print("TEST admin16 idle=", idle0, " claim=", need, "/", claimed, "/", reclaim_refused, " wrong=", wrong_refused, " created=", created, " joined=", joined,
		" rules=", rules, " second=", second, " loaded=", loaded, " deleted=", deleted, " news=", [n0, n1, n2, n3], " stopped=", stopped, " ", "OK" if ok else "FAIL")
	tree.quit()


static func _wait(c, old_boot: String, tree: SceneTree) -> Dictionary:
	for i in 150:
		await tree.create_timer(1.0).timeout
		var r: Dictionary = await c.api("auth")
		if bool(r.get("ok", false)) and str(r.get("boot", "")) != old_boot and str(r.get("state", "")) in ["idle", "running"]:
			return r
	return {}
