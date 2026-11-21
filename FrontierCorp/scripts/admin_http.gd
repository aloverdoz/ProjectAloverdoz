extends Node
## 1.6: управление выделенным сервером из игры (как в Satisfactory). Маленький HTTP-сервер на TCP-порту
## с тем же номером, что и игра (UDP): POST /api, тело — JSON {"pass": пароль, "cmd": команда, ...}, ответ — JSON.
## Команды выполняет dedicated.gd (api()). Узел — дочерний у /root/Net/Server.

const MAX_BODY := 65536
const BAD_LIMIT := 5          # неверных паролей с одного адреса…
const BAD_WINDOW := 60.0      # …за столько секунд — дальше адрес ждёт BAD_WINDOW

var srv := TCPServer.new()
var port := 0
var _conns: Array = []        # [{peer, buf, t}]
var _bad := {}                # ip → [время неверного пароля…]


func listen(p: int) -> String:
	port = p
	var err := srv.listen(p, "*")
	if err != OK:
		return "TCP-порт %d для управления из игры занят (код %d)" % [p, err]
	return ""


func stop() -> void:
	for c in _conns:
		c.peer.disconnect_from_host()
	_conns.clear()
	srv.stop()


func _process(delta: float) -> void:
	while srv.is_listening() and srv.is_connection_available():
		var p := srv.take_connection()
		if p:
			_conns.append({"peer": p, "buf": PackedByteArray(), "t": 0.0})
	for c in _conns.duplicate():
		var p: StreamPeerTCP = c.peer
		p.poll()
		c.t += delta
		if p.get_status() != StreamPeerTCP.STATUS_CONNECTED or c.t > 15.0:
			p.disconnect_from_host()
			_conns.erase(c)
			continue
		var n := p.get_available_bytes()
		if n > 0:
			var r: Array = p.get_partial_data(n)
			if r[0] == OK:
				c.buf.append_array(r[1])
		if c.buf.size() > MAX_BODY + 4096:
			_reply(p, 413, {"ok": false, "err": "Слишком большой запрос"})
			_conns.erase(c)
			continue
		var req := _parse(c.buf)
		if req.is_empty():
			continue
		_conns.erase(c)
		_handle(p, req)


## Разобрать запрос, когда он пришёл целиком. {} — ещё не весь.
static func _parse(buf: PackedByteArray) -> Dictionary:
	var txt := buf.get_string_from_ascii()
	var he := txt.find("\r\n\r\n")
	if he < 0:
		return {}
	var head := txt.substr(0, he)
	var lines := head.split("\r\n")
	var first := lines[0].split(" ")
	var clen := 0
	for l in lines:
		if l.to_lower().begins_with("content-length:"):
			clen = int(l.substr(15).strip_edges())
	if buf.size() < he + 4 + clen:
		return {}
	var body := buf.slice(he + 4, he + 4 + clen).get_string_from_utf8()
	return {"method": first[0] if first.size() > 0 else "", "path": first[1] if first.size() > 1 else "/", "body": body}


func _handle(p: StreamPeerTCP, req: Dictionary) -> void:
	var ip := p.get_connected_host()
	if req.method == "GET":
		# проверка из браузера: адрес верный, сервер жив
		_reply(p, 200, {"ok": true, "game": DB.game_name(), "version": DB.game_version(), "hint": "Управление — в игре: «Сетевая игра» → «Управление сервером»"})
		return
	if req.method != "POST" or not str(req.path).begins_with("/api"):
		_reply(p, 404, {"ok": false, "err": "Нет такого адреса"})
		return
	var j = JSON.parse_string(str(req.body))
	if not j is Dictionary:
		_reply(p, 400, {"ok": false, "err": "Неверный запрос"})
		return
	var now := Time.get_ticks_msec() / 1000.0
	var bad: Array = (_bad.get(ip, []) as Array).filter(func(t): return now - float(t) < BAD_WINDOW)
	_bad[ip] = bad
	if bad.size() >= BAD_LIMIT:
		_reply(p, 429, {"ok": false, "err": "Слишком много неверных паролей — подождите минуту"})
		return
	var res: Dictionary = get_parent().api(j, ip)
	if str(res.get("err_code", "")) == "pass":
		bad.append(now)
	res.erase("err_code")
	_reply(p, 200, res)


static func _reply(p: StreamPeerTCP, code: int, data: Dictionary) -> void:
	var body := JSON.stringify(data).to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n" % [
		code, "OK" if code == 200 else "Error", body.size()]
	p.put_data(head.to_utf8_buffer())
	p.put_data(body)
	p.poll()
	p.disconnect_from_host()
