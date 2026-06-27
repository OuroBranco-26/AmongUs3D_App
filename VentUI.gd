extends Control

func _ready():
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	var title = Label.new()
	title.text = "SISTEMA DE DUTOS\nEscolha um duto para emergir"
	title.position = Vector2(350, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func():
		var player = get_meta("player", null)
		if player:
			player.is_in_vent = false
			if player.model_node: player.model_node.visible = true
			player.get_node("CollisionShape3D").disabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		queue_free()
	)
	add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(400, 150)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	var current_vent = get_meta("current_vent", null)
	if current_vent:
		update_connections(current_vent)

func update_connections(current_vent):
	set_meta("current_vent", current_vent)
	var vbox = get_node("VBox")
	for child in vbox.get_children():
		child.queue_free()
		
	var allowed_connections = current_vent.connected_vents
	var vents = get_tree().get_nodes_in_group("vents")
	for i in range(vents.size()):
		var v = vents[i]
		if not v.vent_id in allowed_connections:
			continue
			
		var btn = Button.new()
		var r_name = v.room_name if v.room_name != "" else "Duto " + str(v.vent_id)
		btn.text = "Mover para: " + r_name
		btn.custom_minimum_size = Vector2(250, 50)
		btn.pressed.connect(_on_vent_selected.bind(v))
		vbox.add_child(btn)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_vent_selected(vent_node):
	var player = get_meta("player", null)
	if player:
		# Teleporta
		player.global_position = vent_node.global_position
		player.global_position.y += 0.5
	
	# Atualiza a interface para o novo duto em vez de fechar
	update_connections(vent_node)
