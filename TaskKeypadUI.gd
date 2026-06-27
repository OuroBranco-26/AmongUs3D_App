extends Control

var target_code = ""
var current_input = ""
var display_label

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	target_code = str(randi() % 90000 + 10000) # 5 dígitos
	
	var sticky_note = ColorRect.new()
	sticky_note.color = Color(1, 1, 0.5)
	sticky_note.size = Vector2(200, 100)
	sticky_note.position = Vector2(100, 200)
	add_child(sticky_note)
	
	var note_label = Label.new()
	note_label.text = "Senha do O2:\n" + target_code
	note_label.add_theme_color_override("font_color", Color.BLACK)
	note_label.position = Vector2(10, 10)
	sticky_note.add_child(note_label)
	
	display_label = Label.new()
	display_label.text = "_ _ _ _ _"
	display_label.position = Vector2(500, 100)
	add_child(display_label)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(500, 200)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	
	for i in range(1, 10):
		_add_button(grid, str(i))
	
	_add_button(grid, "C")
	_add_button(grid, "0")
	_add_button(grid, "OK")

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _add_button(grid, text):
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(50, 50)
	b.pressed.connect(_on_key_pressed.bind(text))
	grid.add_child(b)

func _on_key_pressed(key):
	if key == "C":
		current_input = ""
	elif key == "OK":
		if current_input == target_code:
			display_label.text = "ACEITO!"
			display_label.add_theme_color_override("font_color", Color.GREEN)
			_win()
		else:
			display_label.text = "ERRO!"
			display_label.add_theme_color_override("font_color", Color.RED)
			await get_tree().create_timer(1.0).timeout
			current_input = ""
			display_label.add_theme_color_override("font_color", Color.WHITE)
	elif current_input.length() < 5:
		current_input += key
	
	if key != "OK" and key != "C":
		display_label.text = current_input

func _win():
	var source_console = get_meta("source_console", null)
	if source_console:
		source_console.mark_completed()
	var main_node = get_tree().get_root().get_node("Main")
	if main_node:
		main_node.finish_player_task(self)
	await get_tree().create_timer(1.0).timeout
	queue_free()
