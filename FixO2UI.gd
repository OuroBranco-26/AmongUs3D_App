extends Control

var target_code = ""
var line_edit: LineEdit

func _ready():
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.2, 0.0, 0.0, 0.95)
	add_child(bg)
	
	var title = Label.new()
	title.text = "FALHA CRÍTICA DE O2\nInsira o código de emergência para restaurar"
	title.position = Vector2(300, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): 
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		queue_free()
	)
	add_child(close_btn)
	
	target_code = str(randi() % 90000 + 10000) # Número de 5 dígitos
	
	var sticky_note = ColorRect.new()
	sticky_note.color = Color(1, 1, 0)
	sticky_note.size = Vector2(150, 80)
	sticky_note.position = Vector2(200, 200)
	var code_label = Label.new()
	code_label.text = target_code
	code_label.add_theme_color_override("font_color", Color.BLACK)
	code_label.add_theme_font_size_override("font_size", 30)
	code_label.position = Vector2(30, 20)
	sticky_note.add_child(code_label)
	add_child(sticky_note)
	
	line_edit = LineEdit.new()
	line_edit.position = Vector2(400, 200)
	line_edit.custom_minimum_size = Vector2(200, 50)
	line_edit.placeholder_text = "Digite o código..."
	line_edit.text_changed.connect(_on_text_changed)
	add_child(line_edit)
	line_edit.grab_focus()

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_text_changed(new_text):
	if new_text == target_code:
		_win()

func _win():
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if main_node:
		var console = get_meta("console_node", null)
		if console:
			main_node.rpc("register_o2_fix", str(console.get_path()))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
