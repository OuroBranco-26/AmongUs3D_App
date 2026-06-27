extends Control

var win_type = "IMPOSTOR" # ou "CREWMATE"
var reason = ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Engine.time_scale = 0.0 # Trava o mundo 3D
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	if win_type == "IMPOSTOR":
		bg.color = Color(0.2, 0.0, 0.0, 0.9)
	else:
		bg.color = Color(0.0, 0.2, 0.4, 0.9)
	add_child(bg)
	
	var title = Label.new()
	var color_title = Color.RED if win_type == "IMPOSTOR" else Color.CYAN
	var text_title = "DERROTA" if (win_type == "IMPOSTOR" and not get_meta("is_player_impostor", false)) else "VITÓRIA"
	
	# Caso especial: Se eu sou impostor e o impostor ganhou = VITÓRIA.
	# Se eu sou tripulante e o tripulante ganhou = VITÓRIA.
	if (win_type == "IMPOSTOR" and get_meta("is_player_impostor", false)) or (win_type == "CREWMATE" and not get_meta("is_player_impostor", false)):
		text_title = "VITÓRIA"
		color_title = Color.CYAN
	else:
		text_title = "DERROTA"
		color_title = Color.RED
		
	# Override universal para ficar bonito
	if win_type == "IMPOSTOR":
		text_title = "O IMPOSTOR VENCEU"
		color_title = Color.RED
	else:
		text_title = "A TRIPULAÇÃO VENCEU"
		color_title = Color.CYAN

	title.text = text_title + "\n" + reason
	title.position = Vector2(0, 200)
	title.size = Vector2(1280, 200)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", color_title)
	add_child(title)
	
	var btn_menu = Button.new()
	btn_menu.text = "VOLTAR AO MENU"
	btn_menu.position = Vector2(440, 500)
	btn_menu.size = Vector2(400, 80)
	btn_menu.add_theme_font_size_override("font_size", 32)
	btn_menu.pressed.connect(_on_menu_pressed)
	add_child(btn_menu)

func _on_menu_pressed():
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://MainMenu.tscn")
	queue_free()
