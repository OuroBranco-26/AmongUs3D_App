extends Control

var switches = []

func _ready():
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.2, 0.2, 0.2, 0.95)
	add_child(bg)
	
	var title = Label.new()
	title.text = "CONSERTO DE ENERGIA\nLigue todos os disjuntores"
	title.position = Vector2(350, 50)
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
	
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(300, 200)
	hbox.add_theme_constant_override("separation", 50)
	add_child(hbox)
	
	for i in range(5):
		var btn = CheckButton.new()
		btn.text = "Chave " + str(i+1)
		btn.button_pressed = (randi() % 2 == 0) # Random state
		btn.toggled.connect(_on_switch_toggled)
		hbox.add_child(btn)
		switches.append(btn)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_switch_toggled(toggled_on):
	var all_on = true
	for s in switches:
		if not s.button_pressed:
			all_on = false
			break
	
	if all_on:
		_win()

func _win():
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if is_instance_valid(main_node) and main_node.has_method("fix_sabotage_lights"):
		main_node.rpc("fix_sabotage_lights")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
