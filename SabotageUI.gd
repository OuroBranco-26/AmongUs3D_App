extends Control

func _ready():
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.1, 0, 0, 0.9)
	add_child(bg)
	
	var title = Label.new()
	title.text = "SISTEMA DE SABOTAGEM\nEscolha o alvo"
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
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(400, 150)
	vbox.add_theme_constant_override("separation", 30)
	add_child(vbox)
	
	var btn_lights = Button.new()
	btn_lights.text = "Cortar Energia (Apagar Luzes)"
	btn_lights.custom_minimum_size = Vector2(300, 60)
	btn_lights.pressed.connect(_on_sabotage_lights)
	vbox.add_child(btn_lights)
	
	var btn_o2 = Button.new()
	btn_o2.text = "Falha Crítica de O2 (30s para vencer)"
	btn_o2.custom_minimum_size = Vector2(300, 60)
	btn_o2.pressed.connect(_on_sabotage_o2)
	vbox.add_child(btn_o2)
	
	var label_doors = Label.new()
	label_doors.text = "--- TRANCAR PORTAS (12s) ---"
	label_doors.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_doors)
	
	var grid = GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)
	
	var doors = ["CAFETERIA", "STORAGE", "MEDBAY", "SECURITY", "ELECTRICAL", "UPPER ENGINE", "LOWER ENGINE"]
	for d in doors:
		var btn = Button.new()
		btn.text = "Portas: " + d
		btn.custom_minimum_size = Vector2(140, 40)
		btn.pressed.connect(func(): _on_sabotage_door(d))
		grid.add_child(btn)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_sabotage_lights():
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if main_node and main_node.has_method("trigger_sabotage_lights"):
		main_node.rpc("trigger_sabotage_lights")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()

func _on_sabotage_o2():
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if main_node and main_node.has_method("trigger_sabotage_o2"):
		main_node.rpc("trigger_sabotage_o2")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()

func _on_sabotage_door(room_name: String):
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if main_node and main_node.has_method("trigger_sabotage_doors"):
		main_node.rpc("trigger_sabotage_doors", room_name)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
