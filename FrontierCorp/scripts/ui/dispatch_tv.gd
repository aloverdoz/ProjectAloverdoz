extends Control

const DURATION := 30.0
static var messages: Array = []
var next_in := 65.0
var remaining := 0.0
var cursor := -1
var hud
var line: Label
var screen: Control

class TestCard extends Control:
	func _draw() -> void:
		var palette := ["#d9dbcb","#dccb64","#68c6c8","#68b974","#bf75ad","#b05f60","#4b688e"]
		draw_rect(Rect2(Vector2.ZERO,size),Color("#16262c"))
		for i in palette.size():
			draw_rect(Rect2(5+i*(size.x-10)/7,5,(size.x-10)/7+1,size.y*.43),Color(palette[i]))
		for y in range(6,int(size.y)-4,4):
			draw_line(Vector2(4,y),Vector2(size.x-4,y),Color(0,0,0,.20))
		draw_string(ThemeDB.fallback_font,Vector2(3,size.y*.68),"ЦЕНТР",HORIZONTAL_ALIGNMENT_CENTER,size.x-6,16,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(3,size.y*.85),"УПРАВЛЕНИЯ",HORIZONTAL_ALIGNMENT_CENTER,size.x-6,16,Color.WHITE)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	screen = TestCard.new()
	screen.custom_minimum_size = Vector2(174,96)
	row.add_child(screen)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(UI.label("ЦЕНТР УПРАВЛЕНИЯ",18,UI.ACCENT))
	line = UI.label("",21)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(line)
	for child in find_children("*","Control",true,false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func transmit() -> void:
	if messages.is_empty():
		messages = JSON.parse_string(FileAccess.get_file_as_string("res://catalog/broadcasts.json"))
	if cursor < 0:
		cursor = randi_range(maxi(0,messages.size()-32),messages.size()-1)
	line.text = str(messages[cursor])
	cursor = (cursor+1879)%messages.size()
	remaining = DURATION
	visible = true

func _process(delta: float) -> void:
	if hud == null or hud.game == null:
		return
	var parent_size: Vector2 = get_parent().size
	var width := minf(720,parent_size.x-20)
	position = Vector2(parent_size.x-width-10,maxf(4,parent_size.y-272))
	size = Vector2(width,168)
	if hud.any_window_open() or not hud.root.visible:
		visible = false
		return
	if remaining > 0:
		remaining = maxf(0,remaining-delta)
		visible = remaining > 0
		if not visible:
			next_in = randf_range(115,210)
	else:
		next_in -= delta
		if next_in <= 0:
			transmit()
