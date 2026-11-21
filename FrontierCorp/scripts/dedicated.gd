extends Node
## 1.0.9: выделенный сервер. Запуск: игра --headless -- --server [--server-config=путь/server.cfg]
## Без окна и без своего героя: мир живёт для подключившихся игроков. Настройки — в server.cfg (создаётся сам
## при первом запуске, с пояснениями по-русски): название, порт, пароль, список комнат в интернете, правила мира.
## Журнал — в консоль и в server.log. Команды — в консоль сервера или в файл server.cmd рядом с server.cfg
## (по строке): status, players, save, kick ник, say текст, stop. Игроки-администраторы: /admin пароль команда в чате.
## Узел — дочерний у Net (/root/Net/Server), живёт всё время работы сервера.

const SrvSet = preload("res://scripts/server_settings.gd")
const Saves = preload("res://scripts/ui/saves_ui.gd")
## Что из настроек мира задаётся в игре при создании (остальное — server.cfg: порт, список комнат, UPnP…)
const ROOM_FROM_GAME := ["name", "public", "password", "max_players", "start", "access", "wallets", "trade", "pranks", "size", "res", "seed", "modules", "ov"]

const SERVER_KEYS := [
	["name", "Сервер Project Aloverdoz", "Название сервера: так его видят в списке комнат"],
	["port", 24680, "UDP-порт. Его нужно открыть в брандмауэре сервера (ufw allow 24680/udp) и в панели хостинга. Порты ниже 1024 (например 443) на Linux требуют прав root"],
	["password", "", "Пароль для входа. Пусто — без пароля"],
	["max_players", 16, "Сколько игроков одновременно (2–64)"],
	["public", true, "true — сервер виден в общем списке комнат в интернете и в локальной сети; false — входят только по адресу или коду"],
	["lobby", true, "Объявлять сервер в общем списке комнат в интернете"],
	["lobby_url", "", "Адрес списка комнат (ntfy-совместимый сервер). Пусто — тот же, что у игры (https://ntfy.sh)"],
	["public_ip", "", "Внешний IP-адрес сервера для списка комнат и кода. Пусто — узнаётся сам через интернет"],
	["upnp", false, "Открыть порт на роутере через UPnP (дома за роутером). На VPS не нужно"],
	["punch", true, "Помогать игрокам за строгими роутерами («пробой» через список комнат)"],
	["admin_password", "", "Пароль администратора: управление сервером из игры («Сетевая игра» → «Управление сервером») и команды из чата /admin пароль status | save | kick ник | say текст | stop. Пусто — пароль задаёт первый, кто зайдёт в «Управление сервером» (как в Satisfactory)"],
	["world", "wait", "wait — продолжать сохранённый мир, а если его нет — ждать, пока администратор создаст мир из игры («Сетевая игра» → «Управление сервером»); auto — продолжать мир или сразу создать новый; new — каждый запуск новый мир (старый переименовывается)"],
	["save_slot", "server", "Имя файла мира в папке сохранений"],
	["saves_dir", "saves", "Папка сохранений (относительно папки сервера или полный путь)"],
	["autosave_min", 1.0, "Автосохранение раз в столько минут (а ещё — когда игрок входит или выходит и при остановке)"],
	["backup_min", 10.0, "Запасная копия мира (папка saves/backup) раз в столько минут; 0 — не делать"],
	["backup_keep", 48, "Сколько запасных копий хранить (старые удаляются)"],
	["pause_empty", true, "Ставить мир на паузу, когда на сервере никого нет"],
	["log_file", "server.log", "Журнал сервера (относительно папки сервера). Пусто — только в консоль"],
	["updates_dir", "updates", "Папка обновлений для лаунчера (manifest.txt, news.txt), относительно папки сервера. Новости лаунчера меняются из игры: «Управление сервером» → «Новости лаунчера»"],
]

const ROOM_KEYS := [
	["start", "together", "Старт: together — все у одного штаба; nearby — свои базы недалеко; far — свои базы далеко"],
	["access", "put", "Чужие ящики и машины: all — можно брать и класть; put — только класть; none — трогать нельзя"],
	["wallets", "own", "Деньги: own — у каждого свои; shared — общие на всех"],
	["trade", true, "Торговля между игроками (рынки, энергия, переводы)"],
	["pranks", true, "Подколы (снежки, краска, подушки, кирпичи…)"],
	["shared_scan", true, "Изученное в сканере — общее для всех"],
	["size", 384, "Размер карты нового мира, клеток: 256, 384, 512, 768…"],
	["res", "normal", "Ресурсов на карте: few — мало, normal — обычно, many — много"],
	["seed", 0, "Зерно карты нового мира. 0 — случайное"],
	["preset", "", "Заготовка правил: Мирный, Очень лёгкий, Лёгкий, Обычный, Сложный, Хардкор, Безумие, Песочница. Значения из [rules] ниже важнее заготовки. Пусто — без заготовки"],
]

var cfg_path := ""
var cfg_dir := ""
var cfg := ConfigFile.new()
var admin_pass := ""
var pause_empty := true
var slot := "server"
var game = null
var room := {}
var _log: FileAccess
var _thread: Thread
var _lines: Array = []
var _mutex := Mutex.new()
var _cmd_t := 0.0
var _stopping := false
var _t0 := 0
var _paused := false
# 1.6: управление из игры
var state := {}               # server_state.json: пароль администратора, миры и их настройки, активный мир
var http: Node = null
var idle := false             # мира нет — ждём администратора
var _restarting := false
var _boot_id := ""            # меняется при каждом запуске — игра видит, что сервер перезапустился


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_boot_id = "%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	cfg_path = DB.base_dir().path_join("server.cfg")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server-config="):
			cfg_path = a.substr(16)
	if cfg_path.is_relative_path():
		cfg_path = DB.base_dir().path_join(cfg_path)
	cfg_dir = cfg_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(cfg_dir)
	var fresh := not FileAccess.file_exists(cfg_path)
	if fresh:
		write_default(cfg_path)
	var err := cfg.load(cfg_path)
	var lf := str(cfg.get_value("server", "log_file", "server.log"))
	if lf != "":
		lf = lf if lf.is_absolute_path() else cfg_dir.path_join(lf)
		_log = FileAccess.open(lf, FileAccess.READ_WRITE) if FileAccess.file_exists(lf) else FileAccess.open(lf, FileAccess.WRITE)
		if _log:
			_log.seek_end()
	log_line("==== %s %s — выделенный сервер ====" % [DB.game_name(), DB.game_version()])
	if fresh:
		log_line("Создан файл настроек с настройками по умолчанию: %s" % cfg_path)
	if err != OK:
		log_line("ОШИБКА: не читается %s (код %d). Проверьте кавычки у текста и знаки = в строках. Запуск с настройками по умолчанию." % [cfg_path, err])
		cfg = ConfigFile.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wait_pid="):
			# перезапуск без скрипта: прежний процесс ещё освобождает порт
			var pid := int(a.substr(11))
			for i in 120:
				if not OS.is_process_running(pid):
					break
				OS.delay_msec(250)
	_boot.call_deferred()


func sv(key: String):
	for k in SERVER_KEYS:
		if k[0] == key:
			return cfg.get_value("server", key, k[1])
	return cfg.get_value("server", key, null)


func rv(key: String):
	for k in ROOM_KEYS:
		if k[0] == key:
			return cfg.get_value("room", key, k[1])
	return null


## Правила мира из server.cfg ([rules] и [modules]) с учётом заготовки.
func read_rules() -> Dictionary:
	var pr := SrvSet.preset(str(rv("preset"))) if str(rv("preset")) != "" else {"ov": {}, "modules": {}}
	var vals: Dictionary = pr.ov.duplicate()
	if cfg.has_section("rules"):
		for k in cfg.get_section_keys("rules"):
			var f := SrvSet.field(k)
			if f.is_empty():
				log_line("Внимание: в [rules] неизвестная настройка «%s» — пропущена" % k)
				continue
			var v = SrvSet.coerce(f.kind, cfg.get_value("rules", k))
			# в файле записаны все правила; заготовку перекрывают только изменённые вручную
			if pr.ov.has(k) and v == SrvSet.coerce(f.kind, SrvSet.base(k)):
				continue
			vals[k] = v
	var mods := {}
	for m in SrvSet.module_list():
		mods[m[0]] = SrvSet.module_default(m[0])
	mods.merge(pr.modules, true)
	if cfg.has_section("modules"):
		for k in cfg.get_section_keys("modules"):
			var v := bool(cfg.get_value("modules", k))
			if pr.modules.has(k) and v == SrvSet.module_default(k):
				continue
			mods[k] = v
	return {"ov": SrvSet.changed(vals), "modules": mods}


func _boot() -> void:
	var net = get_parent()
	var sd := str(sv("saves_dir"))
	DB.saves_override = sd if sd.is_absolute_path() else cfg_dir.path_join(sd)
	slot = str(sv("save_slot")).validate_filename().replace(" ", "_")
	if slot == "":
		slot = "server"
	admin_pass = str(sv("admin_password"))
	pause_empty = bool(sv("pause_empty"))
	var Lobby = preload("res://scripts/lobby.gd")
	Lobby.off = not bool(sv("lobby"))
	if str(sv("lobby_url")) != "":
		Lobby.url_override = str(sv("lobby_url"))
	if str(sv("public_ip")).is_valid_ip_address() and net.lobby:
		net.lobby.pub_ip = str(sv("public_ip"))
	net.nick = "Сервер"
	net.color = "#ffd040"
	load_state()
	http = preload("res://scripts/admin_http.gd").new()
	http.name = "Admin"
	add_child(http)
	var herr: String = http.listen(int(sv("port")))
	log_line(herr if herr != "" else "Управление из игры: «Сетевая игра» → «Управление сервером», адрес этого сервера и порт %d%s" % [
		int(sv("port")), "" if has_admin() else " (пароль администратора ещё не задан — его задаст первый, кто зайдёт)"])
	var create_new := false
	var w_room := {}
	if managed():
		slot = str(state.active)
		w_room = (state.get("worlds", {}) as Dictionary).get(slot, {}).get("room", {})
		create_new = slot != "" and (str(state.get("pending", "")) == slot or not Saves.exists(slot))
	if slot == "" or (not managed() and str(sv("world")) == "wait" and not Saves.exists(slot)):
		idle = true
		log_line("Мира пока нет. Создайте его в игре: «Сетевая игра» → «Управление сервером» (адрес %s:%d)" % [
			str(sv("public_ip")) if str(sv("public_ip")) != "" else "IP_СЕРВЕРА", int(sv("port"))])
		return
	var rules := read_rules()
	var ov: Dictionary = rules.ov
	room = {"name": str(sv("name")), "public": bool(sv("public")), "password": str(sv("password")), "max_players": clampi(int(sv("max_players")), 1, 64),
		"start": str(rv("start")), "access": str(rv("access")), "wallets": str(rv("wallets")), "trade": bool(rv("trade")), "pranks": bool(rv("pranks")),
		"shared_scan": bool(rv("shared_scan")), "upnp": bool(sv("upnp")), "punch": bool(sv("punch")), "port": int(sv("port")),
		"size": int(rv("size")), "res": str(rv("res")), "modules": rules.modules, "ov": ov}
	# мир, созданный из игры: его настройки важнее server.cfg
	for k in ROOM_FROM_GAME:
		if w_room.has(k):
			room[k] = w_room[k]
	room["max_players"] = clampi(int(room.max_players), 1, 64)
	ov = (room.ov as Dictionary).duplicate()
	ov["settings/coop/autosave_min"] = float(sv("autosave_min"))
	room["ov"] = ov
	if OS.get_cmdline_user_args().has("--no_upnp"):
		room["upnp"] = false
	var err: String = net.host(int(sv("port")), int(room.max_players), room.duplicate(true))
	if err != "":
		log_line("ОШИБКА: " + err)
		get_tree().quit(1)
		return
	if net.port_msg != "":
		log_line(net.port_msg)
	net.slot_override = slot
	log_line("Порт %d (UDP) открыт. Игроков до %d. Пароль: %s. Изменённых правил: %d" % [net.port, int(room.max_players), "есть" if str(room.password) != "" else "нет", ov.size()])
	var mode := str(sv("world"))
	if create_new:
		if Saves.exists(slot):
			_delete_kept(slot)
		state.erase("pending")
		save_state()
		var sd0 := int(room.get("seed", 0))
		log_line("Создаю мир «%s» (из игры): карта %d, ресурсы «%s», зерно %s" % [world_title(slot), int(room.size), str(room.res), str(sd0) if sd0 > 0 else "случайное"])
		DB.set_meta("new_game", {"profession": "engineer", "modules": room.modules, "size": int(room.size), "res": str(room.res),
			"seed": sd0 if sd0 > 0 else randi() % 999999 + 1})
		LoadingScreen.go(get_tree(), "res://scenes/main.tscn")
		return
	if mode != "new" and Saves.exists(slot):
		log_line("Загружаю мир «%s» из %s" % [slot, DB.saves_dir()])
		if Saves.start_from(get_tree(), slot):
			return
		# B-2 r6: файл мира повреждён — откладываем его и берём последнюю запасную копию
		var stamp0 := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		var broken := DB.saves_dir().path_join("%s_повреждён_%s.json" % [slot, stamp0])
		DirAccess.rename_absolute(DB.saves_dir().path_join(slot + ".json"), broken)
		log_line("Файл мира повреждён — отложен как %s" % broken.get_file())
		var bks := _backups_of(slot)
		while not bks.is_empty():
			var last: String = bks.pop_back()
			DirAccess.copy_absolute(DB.saves_dir().path_join("backup").path_join(last), DB.saves_dir().path_join(slot + ".json"))
			if Saves.start_from(get_tree(), slot):
				log_line("Мир загружен из запасной копии %s" % last)
				return
			log_line("Запасная копия %s тоже не читается" % last)
		DirAccess.remove_absolute(DB.saves_dir().path_join(slot + ".json"))
		log_line("Запасных копий нет — создаю новый мир")
	if Saves.exists(slot):
		var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		for ext in [".json", ".meta.json"]:
			DirAccess.rename_absolute(DB.saves_dir().path_join(slot + ext), DB.saves_dir().path_join("%s_%s%s" % [slot, stamp, ext]))
		log_line("Прежний мир сохранён как %s_%s" % [slot, stamp])
	var sd2 := int(rv("seed"))
	log_line("Создаю новый мир: карта %d, ресурсы «%s», зерно %s" % [int(room.size), str(room.res), str(sd2) if sd2 > 0 else "случайное"])
	DB.set_meta("new_game", {"profession": "engineer", "modules": room.modules, "size": int(room.size), "res": str(room.res),
		"seed": sd2 if sd2 > 0 else randi() % 999999 + 1})
	LoadingScreen.go(get_tree(), "res://scenes/main.tscn")


## Мир загружен (Net.attach): прячем героя-заглушку, печатаем адреса, включаем консоль.
func on_world(g) -> void:
	game = g
	var net = get_parent()
	var p = g.player
	p.visible = false
	p.alive = false
	p.god = true
	p.respawn = INF
	if g.factory.hq:
		p.position = g.factory.hq.center()
	if g.tutorial:
		g.tutorial.active = false
	var ov: Dictionary = net.room.get("ov", {})
	if ov.has("settings/difficulty"):
		g.difficulty = float(ov["settings/difficulty"])
	g.save_game("autosave", true)
	var cd: Dictionary = net.codes()
	log_line("Мир готов (день %d, зданий %d). Сохранение: %s" % [g.day_n, g.factory.all.size(), DB.saves_dir().path_join(slot + ".json")])
	for ip in net.lan_ips():
		log_line("  адрес в локальной сети: %s:%d" % [ip, net.port])
	if cd.has("lan"):
		log_line("  код для локальной сети: %s" % cd.lan)
	var pub := str(net.lobby.pub_ip) if net.lobby else ""
	if pub != "":
		log_line("  адрес в интернете: %s:%d   код: %s" % [pub, net.port, Net.make_code(pub, net.port)])
	else:
		log_line("  внешний адрес ещё неизвестен — появится в списке комнат, когда сервер его узнает")
	var Lobby = preload("res://scripts/lobby.gd")
	log_line("Список комнат в интернете: %s" % ((Lobby.base_url() + (" (сервер открытый)" if bool(net.room.get("public", true)) else " (сервер закрытый — не объявляется)")) if Lobby.enabled() else "выключен"))
	log_line("Команды: status, players, save, kick ник, say текст, stop (или строки в файле %s)" % cfg_dir.path_join("server.cmd"))
	if not OS.get_cmdline_user_args().has("--no_stdin"):
		_thread = Thread.new()
		_thread.start(_read_stdin)
	if pause_empty and net.peers.is_empty():
		_set_pause(true)


func _read_stdin() -> void:
	while true:
		var s := OS.read_string_from_stdin()
		if s == "":
			return     # консоли нет (служба, nohup) — команды через server.cmd
		_mutex.lock()
		_lines.append(s.strip_edges())
		_mutex.unlock()
		# после «stop» больше не читаем: иначе поток висит на чтении консоли и не даёт программе закрыться
		if s.strip_edges().to_lower() in ["stop", "quit", "exit", "стоп"]:
			return


func _process(delta: float) -> void:
	_mutex.lock()
	var ls := _lines.duplicate()
	_lines.clear()
	_mutex.unlock()
	for l in ls:
		if str(l) != "":
			var ans := command(str(l))
			if ans != "":
				log_line(ans)
	_cmd_t -= delta
	if _cmd_t <= 0.0:
		_cmd_t = 1.0
		var cf := cfg_dir.path_join("server.cmd")
		if FileAccess.file_exists(cf):
			var txt := FileAccess.get_file_as_string(cf)
			DirAccess.remove_absolute(cf)
			for l in txt.split("\n", false):
				if l.strip_edges() != "":
					log_line("> " + l.strip_edges())
					var ans := command(l.strip_edges())
					if ans != "":
						log_line(ans)


## Строка журнала: в консоль и в server.log.
func log_line(t: String) -> void:
	var line := "[%s] %s" % [Time.get_datetime_string_from_system(false, true), t]
	print(line)
	if _log:
		_log.store_line(line)
		_log.flush()


func _set_pause(on: bool) -> void:
	if on == _paused or game == null:
		return
	_paused = on
	if not on:
		_backup_in_pause = false
	get_tree().paused = on
	log_line("На сервере никого нет — мир на паузе" if on else "Мир снова идёт")


## Игрок стучится (Net.hello): снять паузу.
func wake() -> void:
	_set_pause(false)


## Игрок вышел (Net._on_peer_disconnected).
func on_left() -> void:
	var net = get_parent()
	if net.peers.is_empty() and game != null and not _stopping:
		save()
		if pause_empty:
			_set_pause(true)


func save() -> void:
	if game == null or not is_instance_valid(game):
		return
	game.save_game("autosave", true)
	if DB.write_failed != "":
		log_line("ОШИБКА: мир не сохранён (нет места на диске?) — прежний файл цел")   # B-1 r7
		return
	log_line("Мир сохранён (%s)" % DB.saves_dir().path_join(slot + ".json"))
	backup()


## 1.1.14: мир удаляют или пересоздают — сначала копия в saves/backup (вчера мир случайно пересоздали и всё стёрлось).
func _delete_kept(sl: String) -> void:
	sl = sl.get_file()   # B-3 r7
	var src := DB.saves_dir().path_join(sl + ".json")
	if FileAccess.file_exists(src):
		var dir := DB.saves_dir().path_join("backup")
		DirAccess.make_dir_recursive_absolute(dir)
		var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		var dst := dir.path_join("%s_удалён_%s.json" % [sl, stamp])
		if DirAccess.copy_absolute(src, dst) == OK:
			log_line("Копия мира перед удалением: %s" % dst)
	Saves.delete(sl)


## 1.1.14: запасные копии мира — если что-то пошло не так, можно вернуть мир на час-другой назад
## (скопировать файл из saves/backup на место saves/<мир>.json при остановленном сервере).
var _backup_last := -1.0
var _backup_in_pause := false

func backup(force := false) -> void:
	var every := float(sv("backup_min")) * 60.0
	if every <= 0.0 or slot == "":
		return
	if _paused and not force:
		# B-6 r6: мир на паузе не меняется — одна копия на паузу, а не по копии каждые N минут
		if _backup_in_pause:
			return
		_backup_in_pause = true
	var now := Time.get_unix_time_from_system()
	if not force and _backup_last >= 0.0 and now - _backup_last < every:
		return
	var src := DB.saves_dir().path_join(slot + ".json")
	if not FileAccess.file_exists(src):
		return
	_backup_last = now
	var dir := DB.saves_dir().path_join("backup")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var dst := dir.path_join("%s_%s.json" % [slot, stamp])
	if DirAccess.copy_absolute(src, dst) != OK:
		log_line("Не удалось сделать запасную копию мира: %s" % dst)
		return
	var mine := _backups_of(slot)   # B-1 r6: только копии этого мира (не «server_2»)
	mine.sort()
	while mine.size() > maxi(1, int(sv("backup_keep"))):
		DirAccess.remove_absolute(dir.path_join(mine.pop_front()))
	log_line("Запасная копия мира: %s" % dst)


func status() -> String:
	var net = get_parent()
	var up := (Time.get_ticks_msec() - _t0) / 1000
	var names: Array = net.peers.values().map(func(p): return str(p.nick))
	return "«%s» · порт %d · игроков %d из %d%s · день %d · работает %d ч %02d мин%s" % [str(net.room.get("name", "")), net.port, net.peers.size(),
		int(net.room.get("max_players", 8)), (": " + ", ".join(names)) if not names.is_empty() else "", game.day_n if game else 0,
		up / 3600, (up / 60) % 60, " · пауза" if _paused else (" · мира нет — создайте его в игре" if idle else "")]


## Команда консоли (или /admin из чата). Возвращает ответ.
func command(line: String) -> String:
	var net = get_parent()
	var p := line.strip_edges().split(" ", false, 1)
	if p.is_empty():
		return ""
	var cmd := p[0].to_lower().trim_prefix("/")
	var arg := p[1].strip_edges() if p.size() > 1 else ""
	match cmd:
		"help", "помощь", "?":
			return "Команды: status — состояние; players — игроки; save — сохранить; kick ник — выгнать; say текст — сообщение всем; stop — сохранить и выключить; admin_reset — сбросить пароль администратора"
		"status", "статус":
			return status()
		"players", "игроки", "list":
			var out := []
			for id in net.peers:
				var pp = net.puppets.get(id)
				out.append("%s (id %d%s)" % [net.peers[id].nick, id, (", у %d,%d" % [int(pp.position.x), int(pp.position.z)]) if pp != null else ""])
			return "Игроки: " + (", ".join(out) if not out.is_empty() else "никого")
		"save", "сохранить":
			save()
			return ""
		"kick", "выгнать":
			for id in net.peers:
				if str(net.peers[id].nick).to_lower() == arg.to_lower():
					net.kick(id)
					return "Игрок %s выгнан (до перезапуска сервера)" % net.peers[id].nick
			return "Нет такого игрока: %s" % arg
		"say", "сказать":
			if arg == "":
				return ""
			net.rpc("chat_msg", "Сервер", "#ffd040", arg)
			return "[чат] Сервер: %s" % arg
		"stop", "quit", "exit", "стоп":
			stop()
			return ""
		"admin_reset":
			# забыли пароль администратора: следующий вход в «Управление сервером» задаст новый
			state.erase("admin")
			save_state()
			return "Пароль администратора сброшен" + (" (но в server.cfg задан admin_password — он действует)" if str(sv("admin_password")) != "" else " — задайте новый в игре")
	return "Нет такой команды: %s (help — список)" % cmd


## /admin пароль команда — от игрока в чате.
func admin(who: String, text: String) -> String:
	var p := text.strip_edges().split(" ", false, 1)
	if not has_admin():
		return "Команды администратора выключены: пароль ещё не задан («Управление сервером» в игре или admin_password в server.cfg)"
	if p.is_empty() or not check_pass(p[0]):
		log_line("Неверный пароль администратора от %s" % who)
		return "Неверный пароль администратора"
	var c := p[1] if p.size() > 1 else "status"
	log_line("%s (администратор): %s" % [who, c])
	var ans := command(c)
	if ans != "":
		log_line(ans)
	return ans if ans != "" else "Готово"


## B-8 r8: перед последним сохранением гости присылают свежие рюкзаки и прогресс (раньше терялись 10–20 с).
func _collect_guests(net) -> void:
	if net.mode != "host" or net.peers.is_empty():
		return
	net.rpc("state_now")
	await get_tree().create_timer(1.5).timeout


## Сохранить мир, попрощаться и выключиться.
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	var net = get_parent()
	log_line("Остановка сервера…")
	if net.mode == "host":
		net.rpc("chat_msg", "Сервер", "#ffd040", "Сервер выключается. Мир сохранён — заходите позже")
	get_tree().paused = false
	await _collect_guests(net)
	save()
	if net.lobby:
		net.lobby.publish_closed()
	await get_tree().create_timer(1.0).timeout
	net.leave()
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()   # мир выгружается до выхода — без лишних сообщений движка
	await get_tree().process_frame
	await get_tree().process_frame
	log_line("Сервер остановлен")
	if _log:
		_log.close()
	if _thread != null:
		if _thread.is_alive():
			# поток ждёт строку из консоли (stop пришёл из server.cmd или из чата) — всё сохранено, закрываемся сразу
			OS.kill(OS.get_process_id())
			return
		_thread.wait_to_finish()
	get_tree().quit(0)


# ---------------------------------------------------------------- 1.6: управление из игры

## 1.7: папка, откуда лаунчер качает игру (её раздаёт служба frontiercorp-updates).
func updates_dir() -> String:
	var d := str(sv("updates_dir"))
	return d if d.is_absolute_path() else cfg_dir.path_join(d)


## Текущие новости лаунчера: [текст, свои ли (news.txt) или описание версии из manifest.txt].
func news() -> Array:
	var np := updates_dir().path_join("news.txt")
	if FileAccess.file_exists(np):
		return [FileAccess.get_file_as_string(np).strip_edges(), true]
	var mp := updates_dir().path_join("manifest.txt")
	if FileAccess.file_exists(mp):
		var f := FileAccess.open(mp, FileAccess.READ)
		while f and not f.eof_reached():
			var l := f.get_line()
			if l.begins_with("news\t"):
				return [l.substr(5).replace("\\n", "\n"), false]
			if l.begins_with("file\t"):
				break
	return ["", false]


func state_path() -> String:
	return cfg_dir.path_join("server_state.json")


func load_state() -> void:
	var d = DB.read_file(state_path()) if FileAccess.file_exists(state_path()) else null
	state = d if d is Dictionary else {}


func save_state() -> void:
	var tmp := state_path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		log_line("ОШИБКА: не записать %s" % state_path())
		return
	var txt := JSON.stringify(state, "\t")
	f.store_string(txt)
	var bad := f.get_error() != OK
	f.close()
	# B-1 r7: не хватило места — прежний файл не трогаем
	if bad or FileAccess.get_file_as_bytes(tmp).size() != txt.to_utf8_buffer().size():
		DirAccess.remove_absolute(tmp)
		log_line("ОШИБКА: не записать %s (нет места на диске?)" % state_path())
		return
	DirAccess.rename_absolute(tmp, state_path())


## Мирами уже управляли из игры (иначе — как раньше, по server.cfg).
func managed() -> bool:
	return state.has("active")


func has_admin() -> bool:
	return str(sv("admin_password")) != "" or state.has("admin")


func check_pass(pw: String) -> bool:
	if pw == "":
		return false
	if str(sv("admin_password")) != "":
		return pw == str(sv("admin_password"))
	var a: Dictionary = state.get("admin", {})
	return not a.is_empty() and (str(a.get("salt", "")) + pw).sha256_text() == str(a.get("hash", ""))


func set_admin(pw: String) -> void:
	var salt := str(randi()) + str(Time.get_ticks_usec())
	state["admin"] = {"salt": salt, "hash": (salt + pw).sha256_text()}
	save_state()


func world_title(sl: String) -> String:
	return str((state.get("worlds", {}) as Dictionary).get(sl, {}).get("title", sl))


## Все миры в папке сохранений сервера, свежие первыми.
func world_list() -> Array:
	var out := []
	var d := DirAccess.open(DB.saves_dir())
	if d == null:
		return out
	for fn in d.get_files():
		if fn.ends_with(".json") and not fn.ends_with(".meta.json"):
			var sl := fn.get_basename()
			var inf: Dictionary = Saves.info(sl)
			var w: Dictionary = (state.get("worlds", {}) as Dictionary).get(sl, {})
			var rm: Dictionary = w.get("room", {})
			out.append({"slot": sl, "title": world_title(sl), "desc": Saves.describe(inf), "mtime": int(inf.get("mtime", 0)),
				"day": int(inf.get("day", 0)), "active": sl == slot and not idle, "size": int(rm.get("size", 0)), "from_game": not w.is_empty()})
	out.sort_custom(func(a, b): return int(a.mtime) > int(b.mtime))
	return out


func info() -> Dictionary:
	var net = get_parent()
	var st := "idle" if idle else ("running" if game != null and is_instance_valid(game) else "loading")
	if _restarting:
		st = "restarting"
	return {"ok": true, "name": str(room.get("name", sv("name"))), "game": DB.game_name(), "version": DB.game_version(), "claimed": has_admin(),
		"state": st, "world": "" if idle else slot, "world_title": "" if idle else world_title(slot),
		"players": net.peers.values().map(func(p): return str(p.nick)), "max_players": int(room.get("max_players", sv("max_players"))),
		"day": game.day_n if st == "running" else 0, "port": int(sv("port")), "paused": _paused, "boot": _boot_id}


## Запрос из игры (admin_http.gd). Ответ — словарь; err_code "pass" — неверный пароль (считается для защиты от перебора).
func api(j: Dictionary, ip: String) -> Dictionary:
	var cmd := str(j.get("cmd", ""))
	if cmd == "info":
		return info()
	if cmd == "claim":
		if has_admin():
			return {"ok": false, "err": "Пароль администратора уже задан"}
		var np := str(j.get("new_pass", ""))
		if np.length() < 4:
			return {"ok": false, "err": "Пароль — хотя бы 4 знака"}
		set_admin(np)
		log_line("Пароль администратора задан из игры (%s)" % ip)
		return info()
	if not has_admin():
		return {"ok": false, "err": "Сначала задайте пароль администратора", "need_claim": true}
	if not check_pass(str(j.get("pass", ""))):
		log_line("Неверный пароль администратора (%s)" % ip)
		return {"ok": false, "err": "Неверный пароль администратора", "err_code": "pass"}
	if _restarting:
		return {"ok": false, "err": "Сервер перезапускается — подождите"}
	var sl := str(j.get("slot", ""))
	# B-3 r7: имя мира — только имя файла в папке сохранений (без «../», «/», «\\»)
	if sl != "" and (sl != sl.validate_filename() or ".." in sl or "/" in sl or "\\" in sl or sl.begins_with(".")):
		return {"ok": false, "err": "Нет такого мира"}
	match cmd:
		"auth", "status":
			var r := info()
			r["room_pass"] = str(room.get("password", "")) if not idle else ""
			r["worlds"] = world_list()
			var nw0 := news()
			r["news"] = nw0[0]
			r["news_custom"] = nw0[1]
			r["news_ok"] = DirAccess.dir_exists_absolute(updates_dir())
			r["defaults"] = {"size": int(rv("size")), "res": str(rv("res")), "start": str(rv("start")), "access": str(rv("access")), "wallets": str(rv("wallets"))}
			return r
		"worlds":
			return {"ok": true, "worlds": world_list()}
		"create":
			var title := str(j.get("title", "")).strip_edges().left(40)
			if title == "":
				title = "Мир"
			var base := title.validate_filename().replace(" ", "_")
			if base == "" or base.begins_with("."):
				base = "world"
			var ns := base
			var i := 2
			while Saves.exists(ns) or (state.get("worlds", {}) as Dictionary).has(ns):
				ns = "%s_%d" % [base, i]
				i += 1
			var rm := {}
			var src = j.get("room", {})
			if src is Dictionary:
				for k in ROOM_FROM_GAME:
					if src.has(k):
						rm[k] = src[k]
			if not rm.get("modules") is Dictionary:
				rm.erase("modules")
			if not rm.get("ov") is Dictionary:
				rm.erase("ov")
			if not state.has("worlds"):
				state["worlds"] = {}
			state.worlds[ns] = {"title": title, "room": rm, "created": Time.get_datetime_string_from_system()}
			state["active"] = ns
			state["pending"] = ns
			save_state()
			restart_soon("Администратор создаёт новый мир «%s»" % title)
			return {"ok": true, "slot": ns}
		"load":
			if not Saves.exists(sl):
				return {"ok": false, "err": "Нет такого мира"}
			state["active"] = sl
			state.erase("pending")
			save_state()
			restart_soon("Администратор загружает мир «%s»" % world_title(sl))
			return {"ok": true}
		"recreate":
			if not Saves.exists(sl) and not (state.get("worlds", {}) as Dictionary).has(sl):
				return {"ok": false, "err": "Нет такого мира"}
			if not (state.get("worlds", {}) as Dictionary).has(sl):
				# мир из server.cfg: запомнить его настройки, чтобы пересоздать таким же
				if not state.has("worlds"):
					state["worlds"] = {}
				var rm2 := {}
				for k in ROOM_FROM_GAME:
					if room.has(k) and sl == slot:
						rm2[k] = room[k]
				state.worlds[sl] = {"title": sl, "room": rm2}
			state["active"] = sl
			state["pending"] = sl
			save_state()
			restart_soon("Администратор пересоздаёт мир «%s» заново" % world_title(sl))
			return {"ok": true}
		"delete":
			if not Saves.exists(sl):
				return {"ok": false, "err": "Нет такого мира"}
			var was_active := sl == slot and not idle
			if was_active or not managed():
				state["active"] = "" if was_active else slot
			(state.get("worlds", {}) as Dictionary).erase(sl)
			save_state()
			if was_active:
				restart_soon("Администратор удаляет этот мир", false, sl)
			else:
				_delete_kept(sl)
				log_line("Мир «%s» удалён из игры" % sl)
			return {"ok": true}
		"stop_world":
			if idle:
				return {"ok": true}
			state["active"] = ""
			state.erase("pending")
			save_state()
			restart_soon("Администратор остановил мир (он сохранён)")
			return {"ok": true}
		"restart":
			restart_soon("Перезапуск сервера")
			return {"ok": true}
		"save":
			if idle:
				return {"ok": false, "err": "Мира нет — нечего сохранять"}
			save()
			return {"ok": true, "msg": "Мир сохранён"}
		"kick", "say":
			if idle:
				return {"ok": false, "err": "Мира нет"}
			return {"ok": true, "msg": command("%s %s" % [cmd, str(j.get("arg", ""))])}
		"news":
			# 1.7: новости в лаунчере — news.txt в папке обновлений (лаунчер берёт её вместо описания версии)
			if not DirAccess.dir_exists_absolute(updates_dir()):
				return {"ok": false, "err": "На сервере нет папки обновлений лаунчера (%s). Она появляется после install_server.sh с архивом Launcher_Updates" % updates_dir()}
			if j.has("text"):
				var tx := str(j.get("text", "")).strip_edges().left(3000)
				var np3 := updates_dir().path_join("news.txt")
				if tx == "":
					DirAccess.remove_absolute(np3)
					log_line("Новости лаунчера сброшены к описанию версии (%s)" % ip)
				else:
					var f := FileAccess.open(np3 + ".tmp", FileAccess.WRITE)
					if f == null:
						return {"ok": false, "err": "Не получилось записать %s (код %d)" % [np3, FileAccess.get_open_error()]}
					f.store_string(tx + "\n")
					f.close()
					DirAccess.rename_absolute(np3 + ".tmp", np3)
					log_line("Новости лаунчера изменены из игры (%s)" % ip)
			var nw := news()
			return {"ok": true, "news": nw[0], "custom": nw[1], "msg": "Новости сохранены — лаунчер покажет их при следующем запуске" if j.has("text") else ""}
		"set_pass":
			var np2 := str(j.get("new_pass", ""))
			if np2.length() < 4:
				return {"ok": false, "err": "Пароль — хотя бы 4 знака"}
			if str(sv("admin_password")) != "":
				return {"ok": false, "err": "Пароль записан в server.cfg (admin_password) — меняйте его там"}
			set_admin(np2)
			log_line("Пароль администратора изменён из игры (%s)" % ip)
			return {"ok": true}
	return {"ok": false, "err": "Нет такой команды: %s" % cmd}


## Предупредить игроков и перезапуститься (новый мир, другой мир, без мира).
func restart_soon(msg: String, do_save := true, delete_slot := "") -> void:
	if _restarting:
		return
	_restarting = true
	log_line(msg + " — перезапуск сервера")
	var net = get_parent()
	if net.mode == "host":
		net.rpc("chat_msg", "Сервер", "#ffd040", msg + ". Сервер перезапускается — зайдите снова через полминуты")
	await get_tree().create_timer(1.5).timeout
	_restart(do_save, delete_slot)


func _restart(do_save: bool, delete_slot: String) -> void:
	_stopping = true
	var net = get_parent()
	get_tree().paused = false
	if do_save:
		await _collect_guests(net)
		save()
	if net.lobby and net.mode == "host":
		net.lobby.publish_closed()
	if net.mode != "":
		net.leave()
	if http:
		http.stop()
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if delete_slot != "":
		_delete_kept(delete_slot)
		log_line("Мир «%s» удалён" % delete_slot)
	log_line("Перезапуск…")
	if _log:
		_log.close()
	var ua := OS.get_cmdline_user_args()
	if ua.has("--restart_loop"):
		# start_server.sh запускает сервер заново по коду 75
		get_tree().quit(75)
		return
	var args := PackedStringArray(OS.get_cmdline_args())
	args.append("--")
	for a in ua:
		if not a.begins_with("--wait_pid="):
			args.append(a)
	args.append("--wait_pid=%d" % OS.get_process_id())
	OS.create_process(OS.get_executable_path(), args)
	if _thread != null and _thread.is_alive():
		OS.kill(OS.get_process_id())
		return
	get_tree().quit(0)


# ---------------------------------------------------------------- server.cfg

static func _val(v) -> String:
	return var_to_str(v)


## Файл настроек по умолчанию: все ключи с пояснениями (текст в кавычках, да/нет — true/false).
static func default_text() -> String:
	var L := PackedStringArray()
	L.append("; Настройки выделенного сервера %s." % DB.game_name())
	L.append("; Строки с «;» — пояснения. Текст пишется в кавычках: name=\"Мой сервер\". Да/нет — true/false. Дробные числа — через точку.")
	L.append("; После правки перезапустите сервер. Удалите файл — при следующем запуске он создастся заново со значениями по умолчанию.")
	L.append("")
	L.append("[server]")
	L.append("")
	for k in SERVER_KEYS:
		L.append("; " + str(k[2]))
		L.append("%s=%s" % [k[0], _val(k[1])])
		L.append("")
	L.append("[room]")
	L.append("")
	for k in ROOM_KEYS:
		L.append("; " + str(k[2]))
		L.append("%s=%s" % [k[0], _val(k[1])])
		L.append("")
	L.append("[modules]")
	L.append("; Игровые модули: true — включён, false — выключен")
	L.append("")
	for m in SrvSet.module_list():
		L.append("; " + str(m[1]) + ((" — " + str(m[2])) if str(m[2]) != "" else ""))
		L.append("%s=%s" % [m[0], _val(SrvSet.module_default(m[0]))])
	L.append("")
	L.append("[rules]")
	L.append("; Правила мира. Здесь записаны обычные значения игры — меняйте нужные. Одинаковы для всех игроков.")
	L.append("")
	for t in SrvSet.TABS:
		L.append(";; ---------------- %s ----------------" % t[0])
		for e in SrvSet.entries(t[1]):
			if e.has("header"):
				L.append(";; " + str(e.header))
				continue
			var line := "; " + str(e.label)
			if str(e.kind).begins_with("enum:"):
				line += " — варианты: " + ", ".join(SrvSet.enum_items(e.kind).map(func(x): return "%s (%s)" % [x[0], x[1]] if x[0] != "" else "\"\""))
			if str(e.hint) != "":
				line += ". " + str(e.hint).replace("\n", " ")
			L.append(line)
			L.append("%s=%s" % [e.path, _val(SrvSet.base(e.path))])
		L.append("")
	return "\n".join(L) + "\n"


static func write_default(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(default_text())
		f.close()


# ---------------------------------------------------------------- автотест: обычный игрок заходит на выделенный сервер

## --dserver_client=КОД: найти сервер в общем списке комнат (если задан --lobby_url), затем войти по коду.
static func client_test(net, code: String) -> void:
	var tree: SceneTree = net.get_tree()
	var found := {}
	if net.Lobby_on():
		net.lobby.listing = true
		net.lobby.refresh()
		for i in 60:
			await tree.create_timer(0.5).timeout
			for d in net.lobby.search(""):
				if bool(d.get("ded", false)):
					found = d
			if not found.is_empty():
				break
			if i % 6 == 5:
				net.lobby.refresh()
		net.lobby.listing = false
	net.set_meta("ds_found", found)
	print("DSERVER lobby found=", not found.is_empty(), " name='", found.get("name", ""), "' port=", found.get("port", 0))
	var err: String = net.join(code, 0, "", false)
	if err != "":
		print("TEST dserver_client join_error='", err, "' FAIL")
		tree.quit()


## Мир у гостя загрузился: правила сервера пришли? Потом чат, команда администратора и выход.
static func client_check(net, g) -> void:
	var tree: SceneTree = net.get_tree()
	await tree.create_timer(1.0).timeout
	var world_ok: bool = g.factory.hq != null and g.factory.all.size() > 0
	var ov_ok: bool = int(DB.data.waves.get("interval", 0)) == 1234 and absf(float(DB.setting("hunger_rate", 0)) - 0.77) < 0.0001 \
		and str(DB.data.settings.get("death", {}).get("mode", "")) == "keep" and absf(float(DB.data.settings.get("world_bonus", {}).get("craft_speed", 0)) - 0.5) < 0.001
	var mod_ok: bool = g.module("survival") and not g.module("waves")
	var ded_ok: bool = bool(net.room.get("dedicated", false)) and not net.puppets.has(1) and not net.peers.has(1)
	var found: Dictionary = net.get_meta("ds_found", {})
	var lobby_ok: bool = not net.Lobby_on() or (str(found.get("name", "")) == "Тест-сервер" and bool(found.get("ded", false)))
	net.send_chat_text("привет сервер")
	net.rpc_id(1, "req_admin", "testpass status")
	var admin_ok := false
	for i in 40:
		await tree.create_timer(0.25).timeout
		for l in net.chat_log:
			if str(l[0]) == "Сервер" and str(l[2]).contains("Тест-сервер"):
				admin_ok = true
		if admin_ok:
			break
	# 1.1.11: админ-панель по паролю администратора сервера
	g.admin.login("wrongpass")
	await tree.create_timer(1.0).timeout
	var wrong_ok: bool = not g.admin.ok
	g.admin.login("testpass")
	for i in 20:
		await tree.create_timer(0.25).timeout
		if g.admin.ok and not g.admin.players.is_empty():
			break
	var login_ok: bool = g.admin.ok and g.admin.players.size() == 1 and str(g.admin.players[0].nick) == net.nick
	var tabs_ok := true
	for t in AdminPanel.TABS:
		g.admin.tab = t[0]
		g.admin.refresh()
		tabs_ok = tabs_ok and g.admin._win != null and g.admin._win.body.get_child_count() > 1
	var me: int = net.my_id()
	var gear0: int = g.player.inv.count("gear")
	g.admin.act("give", {"to": me, "item": "gear", "n": 77})
	g.admin.act("player", {"to": me, "set": {"level": 10}})
	g.admin.act("player", {"to": me, "set": {"free_build": true}})
	await tree.create_timer(1.5).timeout
	var give_ok: bool = g.player.inv.count("gear") == gear0 + 77
	var lvl_ok: bool = g.level == 10 and g.attr_points >= 18
	var fb_ok: bool = g.flags.get("free_build", false)
	# бесплатная стройка у гостя: пустой рюкзак, а сборщик строится
	g.player.inv.slots.fill(null)
	var pc: Vector2i = World.wc(World.world_to_cell(g.player.position) + Vector2i(4, 4))
	for dx in range(-1, 4):
		for dz in range(-1, 4):
			g.world.remove_node(World.wc(pc + Vector2i(dx, dz)))
	g.cmd("place", {"type": "chest_iron", "cell": pc, "dir": 0})
	await tree.create_timer(1.5).timeout
	var built = g.factory.building_at(pc)
	var free_ok: bool = built != null and built.type == "chest_iron"
	var adm_ok := wrong_ok and login_ok and tabs_ok and give_ok and lvl_ok and fb_ok and free_ok
	print("ADMIN111 wrong_refused=", wrong_ok, " login=", login_ok, " players=", g.admin.players, " tabs=", tabs_ok, " give=", give_ok, " level=", lvl_ok, " free_flag=", fb_ok,
		" free_build_place=", free_ok, " ", "OK" if adm_ok else "FAIL")
	var ok := world_ok and ov_ok and mod_ok and ded_ok and lobby_ok and admin_ok and adm_ok
	print("TEST dserver_client world=", world_ok, " rules=", ov_ok, " (interval=", DB.data.waves.get("interval"), " hunger=", DB.setting("hunger_rate"), ") modules=", mod_ok,
		" dedicated=", ded_ok, " lobby=", lobby_ok, " admin=", admin_ok, " admin_panel=", adm_ok, " ", "OK" if ok else "FAIL")
	await tree.create_timer(0.5).timeout
	net.leave()
	await tree.create_timer(0.5).timeout
	tree.quit()


## B-1 r6: запасные копии мира slot (имя «slot_ГГГГ-ММ-ДД_…»), по возрастанию.
func _backups_of(slot: String) -> Array:
	var dir := DB.saves_dir().path_join("backup")
	var rx := RegEx.create_from_string("^" + _rx_esc(slot) + "_\\d{4}-\\d{2}-\\d{2}_[0-9-]+\\.json$")
	var out := []
	for f in DirAccess.get_files_at(dir):
		if rx.search(f) != null:
			out.append(f)
	out.sort()
	return out


static func _rx_esc(s: String) -> String:
	var o := ""
	for ch in s:
		o += ("\\" + ch) if "\\^$.|?*+()[]{}".find(ch) >= 0 else ch
	return o
