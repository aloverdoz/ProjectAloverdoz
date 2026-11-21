extends RefCounted
## Запись ролика в файл .avi (Motion JPEG): каждый кадр — картинка JPEG.
## Такой файл открывают обычные проигрыватели (Кино и ТВ, VLC) и видеоредакторы.

var f: FileAccess
var w := 0
var h := 0
var fps := 30
var frames := 0
var index: Array = []        # [смещение, размер]
var movi_pos := 0            # где начинается «movi» (для индекса)
var _avih_frames := 0
var _strh_len := 0
var _avih_us := 0
var _strh_rate := 0
var path := ""


func _u32(v: int) -> void:
	f.store_32(v)


func _u16(v: int) -> void:
	f.store_16(v)


func _cc(s: String) -> void:
	f.store_buffer(s.to_ascii_buffer())


func open(p: String, width: int, height: int, rate: int) -> bool:
	f = FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	path = p
	w = width
	h = height
	fps = rate
	_cc("RIFF"); _u32(0); _cc("AVI ")
	_cc("LIST"); _u32(4 + 64 + 12 + 64 + 48); _cc("hdrl")
	_cc("avih"); _u32(56)
	_avih_us = f.get_position()
	_u32(int(1000000.0 / fps)); _u32(0); _u32(0); _u32(0x10)
	_avih_frames = f.get_position()
	_u32(0); _u32(0); _u32(1); _u32(w * h * 3); _u32(w); _u32(h)
	_u32(0); _u32(0); _u32(0); _u32(0)
	_cc("LIST"); _u32(4 + 64 + 48); _cc("strl")
	_cc("strh"); _u32(56)
	_cc("vids"); _cc("MJPG"); _u32(0); _u16(0); _u16(0); _u32(0); _u32(1)
	_strh_rate = f.get_position()
	_u32(fps); _u32(0)
	_strh_len = f.get_position()
	_u32(0); _u32(w * h * 3); _u32(0xFFFFFFFF); _u32(0)
	_u16(0); _u16(0); _u16(w); _u16(h)
	_cc("strf"); _u32(40)
	_u32(40); _u32(w); _u32(h); _u16(1); _u16(24); _cc("MJPG"); _u32(w * h * 3); _u32(0); _u32(0); _u32(0); _u32(0)
	_cc("LIST"); _u32(0)
	movi_pos = f.get_position()
	_cc("movi")
	return true


func add_jpeg(data: PackedByteArray) -> void:
	if f == null:
		return
	var off := f.get_position() - movi_pos
	_cc("00dc"); _u32(data.size())
	f.store_buffer(data)
	if data.size() % 2 == 1:
		f.store_8(0)
	index.append([off, data.size()])
	frames += 1


func add_image(img: Image, quality := 0.85) -> void:
	if img.get_width() != w or img.get_height() != h:
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	add_jpeg(img.save_jpg_to_buffer(quality))


## Дописать индекс и размеры. real_fps — сколько кадров в секунду получилось на самом деле.
func close(real_fps := 0) -> void:
	if f == null:
		return
	var movi_end := f.get_position()
	_cc("idx1"); _u32(index.size() * 16)
	for e in index:
		_cc("00dc"); _u32(0x10); _u32(e[0]); _u32(e[1])
	var end := f.get_position()
	f.seek(4); _u32(end - 8)
	f.seek(movi_pos - 4); _u32(movi_end - movi_pos)
	f.seek(_avih_frames); _u32(frames)
	f.seek(_strh_len); _u32(frames)
	if real_fps > 0:
		f.seek(_avih_us); _u32(int(1000000.0 / real_fps))
		f.seek(_strh_rate); _u32(real_fps)
	f.close()
	f = null
