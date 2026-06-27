extends Control

var card_rect
var dragging = false
var drag_start_time = 0.0
var info_label
var start_x = 200
var end_x = 700
var drag_offset = 0

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	info_label = Label.new()
	info_label.text = "Por favor, passe o cartão"
	info_label.position = Vector2(400, 100)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info_label)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	var slot_bg = ColorRect.new()
	slot_bg.color = Color(0.2, 0.2, 0.2)
	slot_bg.size = Vector2(600, 50)
	slot_bg.position = Vector2(200, 250)
	add_child(slot_bg)
	
	card_rect = ColorRect.new()
	card_rect.color = Color(0.8, 0.8, 0.8)
	card_rect.size = Vector2(100, 150)
	card_rect.position = Vector2(start_x, 200)
	card_rect.gui_input.connect(_on_card_input)
	add_child(card_rect)

func _on_card_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start_time = Time.get_ticks_msec() / 1000.0
			drag_offset = get_local_mouse_position().x - card_rect.position.x
		else:
			dragging = false
			_validate_swipe()

func _process(delta):
	if dragging:
		var new_x = get_local_mouse_position().x - drag_offset
		new_x = clamp(new_x, start_x, end_x)
		card_rect.position.x = new_x

func _validate_swipe():
	if card_rect.position.x < end_x - 10:
		info_label.text = "Passagem incompleta!"
		card_rect.position.x = start_x
		return
		
	var time_taken = (Time.get_ticks_msec() / 1000.0) - drag_start_time
	print("Swipe time: ", time_taken)
	
	if time_taken < 0.4:
		info_label.text = "Muito rápido!"
		card_rect.position.x = start_x
		info_label.add_theme_color_override("font_color", Color.RED)
	elif time_taken > 1.2:
		info_label.text = "Muito devagar!"
		card_rect.position.x = start_x
		info_label.add_theme_color_override("font_color", Color.RED)
	else:
		info_label.text = "Aceito!"
		info_label.add_theme_color_override("font_color", Color.GREEN)
		card_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var source_console = get_meta("source_console", null)
		if source_console:
			source_console.mark_completed()
		var main_node = get_tree().get_root().get_node("Main")
		if main_node:
			main_node.finish_player_task(self)
		
		await get_tree().create_timer(1.0).timeout
		queue_free()
