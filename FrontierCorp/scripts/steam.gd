extends Node
## Связь со Steam (автозагрузка «SteamBridge»).
##
## Игра работает и без Steam: если плагина GodotSteam нет или Steam не запущен,
## все функции здесь просто ничего не делают.
##
## Чтобы включить достижения, оверлей-паузу и язык из Steam, положите плагин
## GodotSteam GDExtension (для Godot 4.3) в папку addons/godotsteam/ и соберите игру заново.
## Настройки и список достижений — в редакторе: «Правила игры» → «Steam».
## Ключи достижений (api) должны совпадать с теми, что заведены в Steamworks.

signal overlay_changed(active: bool)

var steam: Object = null      # синглтон GodotSteam, если он есть
var on_steam := false         # Steam запущен и игра в нём авторизована
var user_name := ""
var got := {}                 # api -> true: уже открытые достижения
var _acc := 0.0
var _paused_by_overlay := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _testing():
		return
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
	if steam == null or not _cfg().get("enabled", true):
		return
	var app_id := int(_cfg().get("app_id", 0))
	# запуск не через Steam: попросить Steam перезапустить игру (только если указан App ID)
	if app_id > 0 and bool(_cfg().get("restart_if_needed", false)) and not OS.has_feature("editor"):
		if steam.call("restartAppIfNecessary", app_id):
			get_tree().quit()
			return
	var res = _init_steam(app_id)
	on_steam = res is Dictionary and int(res.get("status", 1)) == 0
	if not on_steam:
		print("Steam: не подключён (%s) — игра работает без Steam" % [str(res.get("verbal", "")) if res is Dictionary else str(res)])
		return
	user_name = str(steam.call("getPersonaName"))
	if steam.has_signal("overlay_toggled"):
		steam.connect("overlay_toggled", _on_overlay)
	_pick_language()
	print("Steam: подключён, игрок ", user_name)


## В разных версиях GodotSteam у steamInitEx разные аргументы — подбираем по списку методов.
func _init_steam(app_id: int):
	for m in steam.get_method_list():
		if m.name == "steamInitEx":
			var args: Array = m.args
			if args.size() > 0 and int(args[0].type) == TYPE_BOOL:
				return steam.call("steamInitEx", false, app_id, false)
			if args.size() >= 2:
				return steam.call("steamInitEx", app_id, false)
			return steam.call("steamInitEx")
	if steam.has_method("steamInit"):
		return steam.call("steamInit")
	return {"status": 1, "verbal": "нет steamInitEx"}


func _process(delta: float) -> void:
	if not on_steam:
		return
	steam.call("run_callbacks")
	_acc += delta
	if _acc < 2.0:
		return
	_acc = 0.0
	_check_achievements()


func _cfg() -> Dictionary:
	var s = DB.data.get("settings", {}).get("steam", {})
	return s if s is Dictionary else {}


func _testing() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test") or a.begins_with("--net_test"):
			return true
	return false


## Первый запуск: язык игры берётся из языка Steam, если игрок его ещё не выбирал.
func _pick_language() -> void:
	if Prefs.has("language") or not steam.has_method("getCurrentGameLanguage"):
		return
	var map := {"russian": "ru", "ukrainian": "ru", "english": "en"}
	var l := str(steam.call("getCurrentGameLanguage"))
	if map.has(l):
		Prefs.values["language"] = map[l]
		Prefs.save_file()
		Lang.apply_locale()


func _on_overlay(active: bool, _user_initiated = false, _app_id = 0) -> void:
	overlay_changed.emit(active)
	if not bool(_cfg().get("pause_on_overlay", true)):
		return
	var main = get_tree().current_scene
	if main == null or not "paused" in main:
		return
	# пауза только в одиночной игре: в сетевой мир идёт дальше
	if Net.active():
		return
	if active and not main.paused:
		main.paused = true
		_paused_by_overlay = true
	elif not active and _paused_by_overlay:
		main.paused = false
		_paused_by_overlay = false


## Достижения описаны как задачи (цель + сколько), проверяются раз в 2 секунды.
func _check_achievements() -> void:
	var main = get_tree().current_scene
	if main == null or not main.has_method("quest_progress"):
		return
	for a in _cfg().get("achievements", []):
		if not a is Dictionary:
			continue
		var api := str(a.get("api", ""))
		if api == "" or got.has(api):
			continue
		var q := {"goal": str(a.get("goal", "waves")), "n": int(a.get("n", 1)), "item": str(a.get("item", "")),
			"buildings": a.get("buildings", []) if a.get("buildings", []) is Array else []}
		var p: Array = main.quest_progress(q)
		if p[0] >= p[1]:
			achieve(api)


## Открыть достижение по ключу из Steamworks (например ACH_FIRST_WAVE).
func achieve(api: String) -> void:
	got[api] = true
	if not on_steam:
		return
	steam.call("setAchievement", api)
	steam.call("storeStats")


## Числовая статистика Steam (если заведена в Steamworks).
func set_stat(name: String, value: int) -> void:
	if on_steam:
		steam.call("setStatInt", name, value)
		steam.call("storeStats")


## Открыть страницу игры в оверлее Steam (например, кнопка «Оставить отзыв»).
func open_store_page() -> void:
	var app_id := int(_cfg().get("app_id", 0))
	if on_steam and app_id > 0:
		steam.call("activateGameOverlayToStore", app_id, 0)
