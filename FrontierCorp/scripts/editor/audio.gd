class_name EdAudio
extends RefCounted
## Прослушивание звуков в редакторе.

static var _player: AudioStreamPlayer
static var _loader: Sfx


static func play(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or path == "":
		return
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		tree.root.add_child(_player)
		_loader = Sfx.new()
		tree.root.add_child(_loader)
	_player.stream = _loader.stream(path)
	_player.play()


## Звук из базы по id: случайный файл из списка.
static func play_id(id: String) -> void:
	var d: Dictionary = DB.data.sounds.get(id, {})
	var files: Array = d.get("files", [])
	if not files.is_empty():
		play(str(files.pick_random()))
		if _player:
			_player.volume_db = float(d.get("volume", 0))


static func stop() -> void:
	if _player and is_instance_valid(_player):
		_player.stop()
