class_name Tutorial
extends Node
## Обучение для новичков: карточка с шагом, прогресс, подсветка нужной части экрана.
## Шаги правятся в редакторе: Данные → Настройки → «Обучение для новичков».
## Цели шага: next (кнопка «Далее»), move (пройти N м), have (иметь предмет), build (поставить здание),
## open (открыть окно), scan (изучить предметов), zone (расширить зону), bag (расширить рюкзак), wave (пережить волн).

var game
var step := 0
var active := false
var done := false
var walked := 0.0
var _last := Vector3.INF
var _done_t := -1.0          # шаг выполнен — через полсекунды следующий
var card: PanelContainer
var demolished := 0      # 1.7: сколько зданий снесено с начала шага
var glow: Glow
var _sig := ""
var _t := 0.0
var _bar: ProgressBar
var _goal_lbl: Label
var _next_btn: Button


static func cfg() -> Dictionary:
	var c = DB.setting("tutorial", {})
	return c if c is Dictionary else {}


static func steps(island_mode := false) -> Array:
	var s = cfg().get("island_steps" if island_mode else "steps", [])
	return s if s is Array else []


func setup(g) -> void:
	game = g
	glow = Glow.new()
	game.hud.root.add_child(glow)
	card = PanelContainer.new()
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	game.hud.root.add_child(card)


## Новая игра: обучение начинается, если включено в настройках.
func start_new() -> void:
	step = 0
	walked = 0.0
	done = not bool(cfg().get("enabled", true)) or steps(game != null and game.island != null).is_empty()
	if game != null and bool(game.get("strategy")):
		done = true   # A16-5: обучение — для героя; в «Стратегии» героя нет
	active = not done
	_enter()


func restart() -> void:
	done = false
	active = not steps(game != null and game.island != null).is_empty()
	step = 0
	walked = 0.0
	_enter()
	game.notify("Обучение начато заново", UI.ACCENT)


func skip() -> void:
	active = false
	done = true
	card.visible = false
	glow.target = null
	game.notify("Обучение пропущено. Вернуть: окно «Как играть» → «Пройти обучение»", UI.DIM)


func to_dict() -> Dictionary:
	return {"step": step, "done": done, "walked": walked}


func load_dict(d) -> void:
	if not d is Dictionary:
		done = true    # старое сохранение — игрок уже умеет играть
		active = false
		card.visible = false
		return
	step = int(d.get("step", 0))
	done = bool(d.get("done", false)) or step >= steps(game != null and game.island != null).size()
	active = not done
	_enter()
	walked = float(d.get("walked", 0.0))   # A-6 r10: после _enter (он обнуляет пройденное на новом шаге)


func _enter() -> void:
	_last = game.player.position if game.player else Vector3.INF
	_done_t = -1.0
	_sig = ""
	demolished = 0
	if active and step >= steps(game != null and game.island != null).size():
		active = false
		done = true
	card.visible = active
	if not active:
		glow.target = null
		return
	_build_card()
	if str(cur().get("goal", "next")) == "move":
		walked = 0.0


func cur() -> Dictionary:
	var s := steps(game != null and game.island != null)
	return s[step] if step < s.size() and s[step] is Dictionary else {}


## Прогресс текущего шага: [сделано, нужно].
func progress() -> Array:
	var s := cur()
	var n := maxi(1, int(s.get("n", 1)))
	var it := str(s.get("item", ""))
	var cnt := 0
	match str(s.get("goal", "next")):
		"next":
			return [0, 1]
		"move":
			cnt = int(walked)
		"have":
			cnt = game.player.inv.count(it) + (game.factory.hq.inv.count(it) if game.factory.hq else 0)
		"build":
			cnt = game._count(str(s.get("building", "")))
		"open":
			cnt = 1 if game.hud.is_open(str(s.get("window", ""))) else 0
			n = 1
		"scan":
			if not DB.discovery:
				return [n, n]
			cnt = game.scanner.researched_count()
		"scan_item":
			# 18: изучить конкретный предмет (сканер, клавиша I)
			n = maxi(1, DB.scan_need(it))
			if not DB.discovery or DB.is_researched(it):
				return [n, n]
			cnt = game.scanner.progress(it)
		"island_expand":
			cnt = 1 if game.island != null and game.world.island_cells.size()>game.island.start_span*game.island.start_span else 0
		"zone":
			if not game.zone.on():
				return [n, n]
			cnt = game.zone.blocks - int(game.zone.cfg().get("start_blocks", 10))
		"bag":
			cnt = game.player.bag_level
		"tech":
			# 1.5: открыть узел дерева открытий (J)
			if not game.tech.enabled() or game.tech.done.has(str(s.get("tech", ""))):
				return [n, n]
			cnt = 0
		"wave":
			cnt = game.enemies.waves_survived
		"demolish":
			cnt = demolished
		"powered":
			# 1.7: столько зданий получают энергию (бур в круге станции, связанной с генератором)
			for b in game.factory.consumers:
				var ni: Dictionary = game.factory.net_info(b)
				if not b.dead and b.net >= 0 and (not game.factory.stations_mode() or b.feeder != null) \
						and float(ni.get("supply", 0.0)) > 0.0 and game.factory.sat_c(b) > 0.0:   # A-3 r4: генератор реально даёт энергию
					cnt += 1
	return [mini(cnt, n), n]


## Текст с подстановкой клавиш: {key:inventory} → клавиша из настроек управления.
static func keys(t: String) -> String:
	var re := RegEx.new()
	re.compile("\\{key:([a-z_]+)\\}")
	var out := t
	for m in re.search_all(t):
		out = out.replace(m.get_string(0), "[" + str(Prefs.get_value("key_" + m.get_string(1), "?")) + "]")
	return out


func goal_text() -> String:
	var s := cur()
	var p := progress()
	var it := str(s.get("item", ""))
	match str(s.get("goal", "next")):
		"next":
			return "Нажмите «Далее», когда будете готовы"
		"move":
			return "Пройдено: %d / %d м" % p
		"have":
			return "%s: %d / %d" % [DB.item_name(it), p[0], p[1]]
		"build":
			return "%s: %d / %d" % [DB.building(str(s.get("building", ""))).get("name", s.get("building", "")), p[0], p[1]]
		"open":
			return "Откройте окно" if p[0] == 0 else "Окно открыто"
		"scan":
			return "Изучено: %d / %d" % p
		"scan_item":
			return "Изучить в сканере: %s %d / %d" % [DB.item_name(it), p[0], p[1]]
		"island_expand":
			return "Куплено клеток: %d / %d" % p
		"zone":
			return "Расширений зоны: %d / %d" % p
		"bag":
			return "Расширений рюкзака: %d / %d" % p
		"tech":
			return "Открыть в дереве открытий: «%s»" % str(game.tech.nodes().get(str(s.get("tech", "")), {}).get("name", s.get("tech", "")))
		"wave":
			return "Волн отбито: %d / %d" % p
		"demolish":
			return "Снесено: %d / %d" % p
		"powered":
			return "Зданий с энергией: %d / %d" % p
	return ""


func _build_card() -> void:
	UI.clear(card)
	var s := cur()
	var st := UI.theme().get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
	st.border_color = UI.ACCENT
	st.set_border_width_all(2)
	st.border_width_left = 6
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(UI.ws(400), 0)
	card.size = Vector2.ZERO
	_card_h = 0.0
	_small_ms = -1
	_built_f = Engine.get_process_frames()
	var v := UI.vbox(8)
	card.add_child(v)
	var top := UI.hbox(8)
	var tag := UI.label("ОБУЧЕНИЕ · ШАГ %d ИЗ %d" % [step + 1, steps(game != null and game.island != null).size()], 12, UI.ACCENT)
	tag.add_theme_font_override("font", UI.bold())
	top.add_child(tag)
	top.add_child(UI.spacer())
	var sk := UI.button("Пропустить обучение", skip, "Обучение можно пройти заново: окно «Как играть» (F1)")
	sk.add_theme_font_size_override("font_size", UI.fs(12))
	top.add_child(sk)
	v.add_child(top)
	var t := UI.title(DB.t(str(s.get("title", ""))), 21)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var body := UI.rich(keys(Lang.t(DB.t(str(s.get("text", ""))))), 15)   # A-3 r5: сначала перевод, потом клавиши
	body.custom_minimum_size = Vector2(UI.ws(370), 0)
	v.add_child(body)
	if str(s.get("hint", "")) != "":
		var h := UI.label(Lang.t("Совет") + ": " + keys(Lang.t(DB.t(str(s.hint)))), 13, Color(0.6, 0.85, 1.0))
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size = Vector2(UI.ws(370), 0)
		v.add_child(h)
	var gr := UI.hbox(10)
	_goal_lbl = UI.label("", 15, UI.TEXT)
	_goal_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 1.7: цель переносится по словам, а не раздвигает карточку (карточка больше не «дышит»)
	_goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_lbl.custom_minimum_size = Vector2(UI.ws(200), 0)
	gr.add_child(_goal_lbl)
	_next_btn = UI.button("Пропустить шаг", next_step)
	_next_btn.custom_minimum_size.x = _next_btn.get_combined_minimum_size().x
	gr.add_child(_next_btn)
	v.add_child(gr)
	_bar = UI.bar(null, UI.ACCENT, 8)
	v.add_child(_bar)
	_place()


var _card_h := 0.0
var _small_ms := -1
var _built_f := 0


## 1.1.10: высота карточки — по тексту, без «прыжков». Раньше карточку каждый кадр сжимали до нуля (reset_size):
## текст на миг переносился по узкой ширине, замер выходил огромным — карточка скакала из большой в нормальную.
## Теперь ширина постоянная, высота берётся из уже разложенного текста; первые кадры после смены шага
## (пока текст раскладывается) карточка прозрачна.
func _place() -> void:
	if card.get_child_count() == 0:
		return
	var vs := get_viewport().get_visible_rect().size
	var v := card.get_child(0) as Control
	var sb := card.get_theme_stylebox("panel")
	var h := v.get_combined_minimum_size().y + (sb.get_minimum_size().y if sb != null else 0.0)
	var w := maxf(UI.ws(400), v.get_combined_minimum_size().x + (sb.get_minimum_size().x if sb != null else 0.0))
	var f := Engine.get_process_frames()
	var settling := f - _built_f < 3
	var now := Time.get_ticks_msec()
	if settling or h > _card_h + 0.5:
		_card_h = h
		_small_ms = -1
	elif h < _card_h - 1.0:
		# короче стало по-настоящему (например, цель стала в одну строку) — сжимаемся через 0.3 с
		if _small_ms < 0:
			_small_ms = now
		elif now - _small_ms > 300:
			_card_h = h
			_small_ms = -1
	else:
		_small_ms = -1
	card.modulate.a = 0.0 if settling else 1.0
	if card.custom_minimum_size != Vector2(UI.ws(400), 0):
		card.custom_minimum_size = Vector2(UI.ws(400), 0)
	if absf(card.size.y - _card_h) > 0.5 or absf(card.size.x - w) > 0.5:
		card.size = Vector2(w, _card_h)
	var bottom: float = game.hud._windows_bottom(vs)
	# 1.1.15: не выше нижнего края панели корпорации (на 1280×720 карточка закрывала кредиты)
	var top_min := 80.0
	var corp = game.hud.panels.get("corp")
	if corp != null and corp.visible:
		top_min = maxf(top_min, corp.position.y + corp.size.y * corp.scale.y + 8.0)
	var vit = game.hud.panels.get("vitals")
	if vit != null and vit.visible and vit.position.y > top_min + 100.0:
		bottom = minf(bottom, vit.position.y + 8.0)   # и не на панель здоровья
	# не влезает между панелями (низкий экран) — карточка чуть уменьшается, а не закрывает панели и быструю панель
	var k := clampf((bottom - 16.0 - top_min) / maxf(1.0, _card_h), 0.72, 1.0)
	if absf(card.scale.x - k) > 0.01:
		card.scale = Vector2(k, k)
	var y := maxf(top_min, bottom - _card_h * k - 16)
	if absf(card.position.y - y) > 1.5 or card.position.x != 16:
		card.position = Vector2(16, y)


func next_step() -> void:
	if not active:
		return
	step += 1
	game.sfx.play_ui("click")
	_enter()


func _process(delta: float) -> void:
	if not active or game == null or game.player == null:
		return
	_t += delta
	var pp: Vector3 = game.player.position
	if _last != Vector3.INF:
		var d := Vector2(pp.x - _last.x, pp.z - _last.z).length()
		if d < 5.0:   # телепорт не считаем
			walked += d
	_last = pp
	var s := cur()
	var goal := str(s.get("goal", "next"))
	var p := progress()
	var ok: bool = goal != "next" and p[0] >= p[1]
	var sig := "%d|%d|%d" % [step, p[0], p[1]]
	if sig != _sig:
		_sig = sig
		_goal_lbl.text = ("✓ " if ok else "▸ ") + goal_text()
		_goal_lbl.add_theme_color_override("font_color", UI.GOOD if ok else UI.TEXT)
		_bar.max_value = p[1]
		_bar.value = p[0]
		# 1.7: полоса и кнопка не исчезают, а становятся прозрачными — место под ними остаётся
		_bar.modulate.a = 1.0 if goal != "next" and goal != "open" else 0.0
		var nb_on: bool = goal == "next" or bool(s.get("can_skip", false))
		_next_btn.modulate.a = 1.0 if nb_on else 0.0
		_next_btn.disabled = not nb_on
		_next_btn.text = "Далее  ▶" if goal == "next" else "Пропустить шаг"
	if ok and _done_t < 0.0:
		_done_t = 0.9
		game.sfx.play_ui("coin")
	if _done_t >= 0.0:
		_done_t -= delta
		if _done_t < 0.0:
			next_step()
			return
	_place()
	glow.target = _target(str(s.get("highlight", "")))


## Что подсветить: панель HUD (hotbar, minimap, quests, corp, storage, wave, info) или окно (window:inventory).
func _target(id: String) -> Control:
	if id == "":
		return null
	if id.begins_with("window:"):
		var w = game.hud.windows.get(id.substr(7))
		return w if w and w.visible else null
	var p = game.hud.panels.get(id)
	return p if p and p.visible else null


## Пульсирующая рамка вокруг подсвеченной части экрана.
class Glow extends Control:
	var target: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_d: float) -> void:
		visible = target != null and is_instance_valid(target) and target.is_visible_in_tree()
		if visible:
			get_parent().move_child(self, -1)
			queue_redraw()

	func _draw() -> void:
		if target == null or not is_instance_valid(target):
			return
		var r := target.get_global_rect().grow(6)
		r.position -= get_global_rect().position
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		var c := Color(UI.ACCENT, 0.5 + 0.5 * k)
		draw_rect(r.grow(k * 4.0), c, false, 3.0)
		draw_rect(r.grow(10 + k * 6.0), Color(UI.ACCENT, 0.15 * (1.0 - k)), false, 6.0)
		var lbl := "СЮДА"
		var f := ThemeDB.fallback_font
		var fsz := UI.fs(14)
		var tw := f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var lp := Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y - 12 - k * 4.0)
		if lp.y < 20:
			lp.y = r.end.y + 24 + k * 4.0
		draw_string_outline(f, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 6, Color.BLACK)
		draw_string(f, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, UI.ACCENT)
