extends Control

func _ready():
	set_anchors_preset(PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Esconde o HUD do jogador ao abrir câmeras
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if main_node:
		var hud = main_node.get_node_or_null("CanvasLayer/PlayerHUD")
		if hud:
			hud.visible = false
		var minimap = main_node.get_node_or_null("CanvasLayer/MiniMap")
		if minimap:
			minimap.visible = false
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.05, 0.95)
	add_child(bg)
	
	var grid = GridContainer.new()
	grid.columns = 4
	grid.set_anchors_preset(PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.offset_left = 50
	grid.offset_right = -50
	grid.offset_top = 50
	grid.offset_bottom = -50
	add_child(grid)
	
	# Posições e Rotações das 8 Câmeras Solicitadas
	var cam_data = [
		{"name": "ELETRICA", "pos": Vector3(-25, 6, 20), "rot": Vector3(-60, 0, 0)},
		{"name": "MEDBAY", "pos": Vector3(-20, 6, -6), "rot": Vector3(-60, 0, 0)},
		{"name": "REATOR", "pos": Vector3(-50, 6, 1), "rot": Vector3(-60, 90, 0)},
		{"name": "ADMIN", "pos": Vector3(15, 6, 6), "rot": Vector3(-60, 0, 0)},
		{"name": "CAFETERIA", "pos": Vector3(0, 5, -30), "rot": Vector3(-60, 0, 0)},
		{"name": "WEAPONS", "pos": Vector3(40, 5, -32), "rot": Vector3(-60, 0, 0)},
		{"name": "SHIELDS", "pos": Vector3(38, 5, 20), "rot": Vector3(-60, 0, 0)},
		{"name": "STORAGE", "pos": Vector3(0, 5, 20), "rot": Vector3(-60, 0, 0)}
	]
	
	var main_world = get_viewport().world_3d
	
	for i in range(8):
		var vpc = SubViewportContainer.new()
		vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vpc.stretch = true
		grid.add_child(vpc)
		
		var vp = SubViewport.new()
		vp.world_3d = main_world
		vp.size = Vector2(320, 240) # PERF-01: Resolução baixa para performance
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vpc.add_child(vp)
		
		var cam = Camera3D.new()
		cam.position = cam_data[i]["pos"]
		cam.rotation_degrees = cam_data[i]["rot"]
		cam.fov = 112.0 # FOV aumentado em 50% (padrão 75°)
		# Evitar renderizar coisas exclusivas de UI (Layer 2)
		cam.cull_mask &= ~2
		vp.add_child(cam)
		cam.current = true
		
		# Overlay do nome da câmera
		var label = Label.new()
		label.text = cam_data[i]["name"]
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.position = Vector2(10, 10)
		vpc.add_child(label)
		
		# Indicador de gravação piscando
		var rec_dot = ColorRect.new()
		rec_dot.size = Vector2(15, 15)
		rec_dot.color = Color.RED
		rec_dot.position = Vector2(10, 45)
		vpc.add_child(rec_dot)
		
		var tw = get_tree().create_tween().set_loops()
		tw.tween_property(rec_dot, "modulate:a", 0.0, 0.5)
		tw.tween_property(rec_dot, "modulate:a", 1.0, 0.5)

	# Botão de Fechar
	var close_btn = Button.new()
	close_btn.text = " FECHAR "
	close_btn.add_theme_font_size_override("font_size", 30)
	close_btn.set_anchors_preset(PRESET_TOP_RIGHT)
	close_btn.offset_left = -200
	close_btn.offset_top = 20
	close_btn.offset_right = -20
	close_btn.offset_bottom = 80
	close_btn.pressed.connect(func(): _restore_hud(); queue_free())
	add_child(close_btn)

func _restore_hud():
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if main_node:
		var hud = main_node.get_node_or_null("CanvasLayer/PlayerHUD")
		if hud:
			hud.visible = true
		var minimap = main_node.get_node_or_null("CanvasLayer/MiniMap")
		if minimap:
			minimap.visible = true

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_restore_hud()
		queue_free()

func _exit_tree():
	_restore_hud()
