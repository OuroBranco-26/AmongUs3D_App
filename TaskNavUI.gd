extends Control

var ship
var target_zone
var dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	var title = Label.new()
	title.text = "Navegação: Arraste a nave até o radar verde"
	title.position = Vector2(300, 50)
	add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	target_zone = ColorRect.new()
	target_zone.color = Color(0, 1, 0, 0.5)
	target_zone.size = Vector2(100, 100)
	target_zone.position = Vector2(700, 300)
	add_child(target_zone)
	
	ship = ColorRect.new()
	ship.color = Color.CYAN
	ship.size = Vector2(50, 50)
	ship.position = Vector2(100, 300)
	ship.gui_input.connect(_on_ship_input)
	add_child(ship)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if dragging:
		ship.position = get_local_mouse_position() - drag_offset

func _on_ship_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = get_local_mouse_position() - ship.position
		else:
			dragging = false
			_check_win()

func _check_win():
	var ship_center = ship.position + ship.size / 2
	var target_rect = Rect2(target_zone.position, target_zone.size)
	
	if target_rect.has_point(ship_center):
		ship.position = target_zone.position + target_zone.size/2 - ship.size/2
		ship.color = Color.WHITE
		_win()

func _win():
	var source_console = get_meta("source_console", null)
	if source_console:
		source_console.mark_completed()
	var main_node = get_tree().get_root().get_node("Main")
	if main_node:
		main_node.finish_player_task(self)
	await get_tree().create_timer(0.5).timeout
	queue_free()
