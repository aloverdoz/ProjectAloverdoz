class_name Sfx
extends Node
## Звук и музыка. Всё задаётся в файлах:
##  sounds.json — звук по имени: файлы (можно несколько вариантов), громкость, разброс тона, 3D, дальность;
##  music.json  — плейлисты для меню, дня, ночи и волны, фоновые звуки.
## Свои файлы (OGG, WAV, MP3) кладутся в папку проекта или мода и указываются в редакторе.

const BUSES := ["Music", "Effects", "Ambient", "UI"]

var game
var listener: AudioListener3D
var pool3d: Array = []
var pool2d: Array = []
var pool_i := 0
var pool2_i := 0
var last := {}
var cache := {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var music_state := ""
var music_track := ""
var ambient: AudioStreamPlayer
var ambient_id := ""
var hum: AudioStreamPlayer
var hum_level := 0.0
## Звуки работы зданий: несколько зацикленных голосов, каждый — у ближайшей машины своего вида.
const WORK_VOICES := 6
var work_players: Array = []   # [{p: AudioStreamPlayer3D, id: String, vol: float}]


func setup() -> void:
	game = get_parent()
	ensure_buses()
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Effects"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 14.0
		p.max_distance = 100.0
		p.panning_strength = 0.8
		add_child(p)
		pool3d.append(p)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		pool2d.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	for m in [music_a, music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
	ambient = AudioStreamPlayer.new()
	ambient.bus = "Ambient"
	add_child(ambient)
	hum = AudioStreamPlayer.new()
	hum.bus = "Effects"
	hum.volume_db = -80.0
	add_child(hum)
	for i in WORK_VOICES:
		var wp := AudioStreamPlayer3D.new()
		wp.bus = "Effects"
		wp.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		wp.unit_size = 6.0
		wp.max_distance = 45.0
		wp.volume_db = -80.0
		add_child(wp)
		work_players.append({"p": wp, "id": "", "vol": 0.0})


static func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


## Громкость канала 0..1 (из меню настроек).
static func set_volume(bus: String, v: float) -> void:
	ensure_buses()
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(max(0.0001, v)))
		AudioServer.set_bus_mute(i, v <= 0.001)


## Загрузить звук: из ресурсов игры или из файла проекта/мода.
func stream(path: String) -> AudioStream:
	if cache.has(path):
		return cache[path]
	var s: AudioStream = null
	var full := ModelLib.resolve_path(path)
	if full.begins_with("res://") and ResourceLoader.exists(full):
		s = load(full)
	elif FileAccess.file_exists(full):
		match full.get_extension().to_lower():
			"ogg":
				s = AudioStreamOggVorbis.load_from_file(full)
			"mp3":
				var mp := AudioStreamMP3.new()
				mp.data = FileAccess.get_file_as_bytes(full)
				s = mp
			"wav":
				s = _load_wav(FileAccess.get_file_as_bytes(full))
	cache[path] = s
	return s


## Простое чтение WAV (PCM 8/16 бит) — для звуков, добавленных в редакторе.
static func _load_wav(b: PackedByteArray) -> AudioStreamWAV:
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var w := AudioStreamWAV.new()
	var i := 12
	while i + 8 <= b.size():
		var id := b.slice(i, i + 4).get_string_from_ascii()
		var sz := b.decode_u32(i + 4)
		if id == "fmt ":
			w.stereo = b.decode_u16(i + 10) == 2
			w.mix_rate = b.decode_u32(i + 12)
			var bits := b.decode_u16(i + 22)
			w.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
		elif id == "data":
			var d := b.slice(i + 8, i + 8 + sz)
			if w.format == AudioStreamWAV.FORMAT_8_BITS:
				for k in d.size():
					d[k] = (d[k] + 128) & 0xff
			w.data = d
		i += 8 + sz + (sz & 1)
	return w


func _def(id: String) -> Dictionary:
	return DB.data.get("sounds", {}).get(id, {})


func _pick(d: Dictionary, id: String) -> AudioStream:
	var files: Array = d.get("files", [])
	if files.is_empty():
		files = ["res://sounds/%s.wav" % id]
	return stream(files[randi() % files.size()])


## Проиграть звук по имени в точке мира.
func play(id: String, pos: Vector3, pitch_k := 1.0) -> void:
	if id == "":
		return
	var d := _def(id)
	var now := Time.get_ticks_msec()
	if now - last.get(id, 0) < int(d.get("cooldown", 40)):
		return
	var s := _pick(d, id)
	if s == null:
		return
	last[id] = now
	if not d.get("positional", true) or game == null or game.player == null:
		play_ui(id, pitch_k)
		return
	var maxd := float(d.get("max_dist", 100))
	if World.dist(pos, game.player.position) > maxd:
		return
	var p: AudioStreamPlayer3D = pool3d[pool_i]
	pool_i = (pool_i + 1) % pool3d.size()
	p.stream = s
	# в зацикленном мире звук ставим с той стороны, откуда он ближе
	p.global_position = game.player.position + World.delta(game.player.position, pos)
	p.max_distance = maxd
	p.volume_db = float(d.get("volume", -8.0))
	var pv := float(d.get("pitch", 0.08))
	p.pitch_scale = randf_range(1.0 - pv, 1.0 + pv) * float(d.get("pitch_base", 1.0)) * pitch_k
	p.play()


## Звук интерфейса (без положения в мире).
func play_ui(id: String, pitch_k := 1.0) -> void:
	var d := _def(id)
	var s := _pick(d, id)
	if s == null:
		return
	var p: AudioStreamPlayer = pool2d[pool2_i]
	pool2_i = (pool2_i + 1) % pool2d.size()
	p.stream = s
	p.volume_db = float(d.get("volume", -8.0))
	var pv := float(d.get("pitch", 0.0))
	p.pitch_scale = randf_range(1.0 - pv, 1.0 + pv) * pitch_k
	p.play()


# ---------------------------------------------------------------- музыка и фон

func _looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if w.stereo else 1)
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	return s


## Состояние музыки: menu, day, night, wave. Смена — плавная.
func set_music(state: String) -> void:
	if state == music_state:
		return
	music_state = state
	var md: Dictionary = DB.data.get("music", {})
	var list: Array = md.get(state, [])
	if list.is_empty():
		_crossfade(null)
		return
	var path: String = list[randi() % list.size()]
	if path == music_track:
		return
	music_track = path
	_crossfade(_looped(stream(path)))


func _crossfade(s: AudioStream) -> void:
	var md: Dictionary = DB.data.get("music", {})
	var t := float(md.get("crossfade", 3.0))
	var vol := float(md.get("volume", -6.0))
	var old := music_a
	music_a = music_b
	music_b = old
	var tw := create_tween().set_parallel(true)
	tw.tween_property(music_b, "volume_db", -80.0, t)
	if s != null:
		music_a.stream = s
		music_a.volume_db = -60.0
		music_a.play()
		tw.tween_property(music_a, "volume_db", vol, t)


func set_ambient(id: String) -> void:
	if id == ambient_id:
		return
	ambient_id = id
	if id == "":
		ambient.stop()
		return
	var d := _def(id)
	var s := _pick(d, id)
	if s == null:
		return
	ambient.stream = _looped(s)
	ambient.volume_db = float(d.get("volume", -20.0))
	ambient.play()


## Каждый кадр: слушатель у героя, гул машин рядом, музыка по времени суток.
func update(delta: float, cam_basis: Basis) -> void:
	if game == null or game.player == null:
		return
	listener.global_transform = Transform3D(cam_basis, game.player.position + Vector3(0, 6, 0))
	var md: Dictionary = DB.data.get("music", {})
	if game.enemies.wave_live > 0:
		set_music("wave")
	else:
		set_music("night" if game.is_night() else "day")
	set_ambient(md.get("ambient_night", "wind") if game.is_night() else md.get("ambient_day", "wind"))
	_update_work(delta)
	# общий гул — только если у машин рядом нет своих звуков работы
	var target := clampf(game.factory.active_near(game.player.position, 18.0) / 6.0, 0.0, 1.0)
	if not game.factory.work_near.is_empty():
		target = 0.0
	hum_level = move_toward(hum_level, target, delta)
	if hum_level > 0.01:
		if not hum.playing:
			var d := _def("machine")
			var s := _pick(d, "machine")
			if s:
				hum.stream = _looped(s)
				hum.play()
		hum.volume_db = float(_def("machine").get("volume", -14.0)) + linear_to_db(max(0.001, hum_level))
	elif hum.playing:
		hum.stop()



## Каждой машине — свой звук: печь плавит, бур сверлит, пила пилит. Слышны ближайшие виды (до WORK_VOICES сразу).
## Чем больше одинаковых машин рядом, тем громче (но не бесконечно).
func _update_work(delta: float) -> void:
	var wn: Dictionary = game.factory.work_near
	var ids := wn.keys()
	ids.sort_custom(func(a, b): return float(wn[a].d) < float(wn[b].d))
	if ids.size() > WORK_VOICES:
		ids.resize(WORK_VOICES)
	# голоса, чей звук больше не нужен, затихают
	for v in work_players:
		if v.id != "" and not ids.has(v.id):
			v.vol = move_toward(v.vol, 0.0, delta * 2.0)
			v.p.volume_db = _work_db(v.id, v.vol, 1)
			if v.vol <= 0.0:
				v.p.stop()
				v.id = ""
	for id in ids:
		var v = null
		for x in work_players:
			if x.id == id:
				v = x
		if v == null:
			for x in work_players:
				if x.id == "":
					v = x
					break
			if v == null:
				continue
			var s := _pick(_def(id), id)
			if s == null:
				continue
			v.id = id
			v.vol = 0.0
			v.p.stream = _looped(s)
			v.p.pitch_scale = float(_def(id).get("pitch_base", 1.0))
			v.p.play(randf() * 3.0)
		var w: Dictionary = wn[id]
		v.vol = move_toward(v.vol, 1.0, delta * 1.5)
		v.p.global_position = game.player.position + World.delta(game.player.position, w.pos)
		v.p.max_distance = float(_def(id).get("max_dist", 40))
		v.p.volume_db = _work_db(id, v.vol, int(w.n))


func _work_db(id: String, vol: float, n: int) -> float:
	return float(_def(id).get("volume", -12.0)) + linear_to_db(maxf(0.001, vol)) + minf(6.0, 2.0 * log(float(maxi(1, n))) / log(2.0))
