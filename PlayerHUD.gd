extends Control

var use_btn: Button
var rep_btn: Button
var kill_btn: Button
var sab_btn: Button
var jump_btn: Button
var crouch_btn: Button
var mic_btn: Button
var leave_btn: Button
var joystick: Control

var jump_pressed = false
var crouch_pressed = false

var task_list_label: RichTextLabel
var task_panel: ColorRect

func _init():
	name = "PlayerHUD"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Adiciona Joystick
	var joystick_script = load("res://MobileJoystick.gd")
	if joystick_script:
		joystick = joystick_script.new()
		joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		joystick.position = Vector2(50, -250)
		joystick.pivot_offset = Vector2(80, 80)
		joystick.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(joystick)
	
	task_panel = ColorRect.new()
	task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_panel.color = Color(0, 0, 0, 0.5)
	task_panel.position = Vector2(20, 60)
	task_panel.size = Vector2(300, 200)
	task_panel.pivot_offset = Vector2(150, 100)
	add_child(task_panel)
	
	task_list_label = RichTextLabel.new() # Modificado para RichTextLabel para suportar BBCode
	task_list_label.bbcode_enabled = true
	task_list_label.text = "Carregando Tarefas..."
	task_list_label.position = Vector2(10, 10)
	task_list_label.size = Vector2(280, 180)
	task_list_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_panel.add_child(task_list_label)
	
	# Botões Base
	use_btn = _create_btn("USE [E]", Vector2(-150, -150), Color.YELLOW, "ui_interact")
	rep_btn = _create_btn("REPORT [R]", Vector2(-300, -150), Color.RED, "ui_report")
	
	# Botões de Movimento
	jump_btn = _create_btn("JUMP", Vector2(-150, -450), Color(0.2, 0.6, 1.0), "")
	crouch_btn = _create_btn("CROUCH", Vector2(-300, -450), Color(0.2, 0.6, 1.0), "")
	
	# Eventos de Pular/Agachar segurados
	jump_btn.button_down.connect(func(): jump_pressed = true)
	jump_btn.button_up.connect(func(): jump_pressed = false)
	crouch_btn.button_down.connect(func(): crouch_pressed = true)
	crouch_btn.button_up.connect(func(): crouch_pressed = false)
	
	# Botões Impostor (Inicialmente ocultos)
	kill_btn = _create_btn("KILL [Q]", Vector2(-150, -300), Color.DARK_RED, "ui_kill")
	kill_btn.visible = false
	
	sab_btn = _create_btn("SABOTAGE [M]", Vector2(-300, -300), Color.ORANGE, "ui_sabotage")
	sab_btn.visible = false
	
	mic_btn = _create_btn("MIC ON [V]", Vector2(-150, -600), Color.GREEN, "")
	mic_btn.button_down.connect(_toggle_mic)
	
	var menu_btn = _create_btn("MENU", Vector2(0, 0), Color.DIM_GRAY, "")
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -150
	menu_btn.offset_top = 20
	menu_btn.offset_right = -30
	menu_btn.offset_bottom = 100
	
	var settings_panel = ColorRect.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.color = Color(0, 0, 0, 0.8)
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.size = Vector2(400, 300)
	settings_panel.position = -settings_panel.size / 2.0
	settings_panel.visible = false
	add_child(settings_panel)
	
	menu_btn.button_down.connect(func(): settings_panel.visible = not settings_panel.visible)
	add_child(menu_btn)
	
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		if joystick: joystick.visible = false
		use_btn.visible = false
		rep_btn.visible = false
		jump_btn.visible = false
		crouch_btn.visible = false
		mic_btn.visible = false
	
	var title = Label.new()
	title.text = "CONFIGURAÇÕES"
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(100, 10)
	settings_panel.add_child(title)
	
	var mic_lbl = Label.new()
	mic_lbl.text = "Volume de Saída de Voz (Meu Mic)"
	mic_lbl.position = Vector2(20, 60)
	settings_panel.add_child(mic_lbl)
	
	var mic_slider = HSlider.new()
	mic_slider.min_value = 0.0
	mic_slider.max_value = 3.0
	mic_slider.step = 0.1
	mic_slider.value = 1.0
	mic_slider.size = Vector2(360, 30)
	mic_slider.position = Vector2(20, 85)
	mic_slider.value_changed.connect(func(v): get_node("/root/VoiceManager").mic_volume_multiplier = v)
	settings_panel.add_child(mic_slider)
	
	var other_lbl = Label.new()
	other_lbl.text = "Volume de Voz dos Demais Jogadores"
	other_lbl.position = Vector2(20, 130)
	settings_panel.add_child(other_lbl)
	
	var other_slider = HSlider.new()
	other_slider.min_value = 0.0
	other_slider.max_value = 2.0
	other_slider.step = 0.1
	other_slider.value = 1.0
	other_slider.size = Vector2(360, 30)
	other_slider.position = Vector2(20, 155)
	var voice_bus_idx = AudioServer.get_bus_index("Voice")
	if voice_bus_idx != -1:
		other_slider.value_changed.connect(func(v): AudioServer.set_bus_volume_db(voice_bus_idx, linear_to_db(v)))
	settings_panel.add_child(other_slider)
	
	var restart_mic_btn = Button.new()
	restart_mic_btn.text = "REINICIAR MICROFONE"
	restart_mic_btn.size = Vector2(360, 40)
	restart_mic_btn.position = Vector2(20, 190)
	restart_mic_btn.add_theme_color_override("font_color", Color.WHITE)
	restart_mic_btn.add_theme_stylebox_override("normal", _create_style(Color.ORANGE))
	restart_mic_btn.add_theme_stylebox_override("hover", _create_style(Color.ORANGE.lightened(0.2)))
	restart_mic_btn.add_theme_stylebox_override("pressed", _create_style(Color.ORANGE.darkened(0.2)))
	restart_mic_btn.button_down.connect(func():
		var vm = get_node_or_null("/root/VoiceManager")
		if vm and vm.has_method("_setup_hardware"):
			vm._setup_hardware()
	)
	settings_panel.add_child(restart_mic_btn)
	
	if OS.get_name() == "Android":
		var android_warning = Label.new()
		android_warning.text = "⚠️ MICROFONE TRAVOU?\nVá nas Configurações do Celular > Aplicativos >\nPermissões. Desligue e Ligue o Microfone para destravar\n(Você não perderá seus dados ou IP da sala!)"
		android_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		android_warning.add_theme_font_size_override("font_size", 14)
		android_warning.add_theme_color_override("font_color", Color.YELLOW)
		android_warning.position = Vector2(10, 240)
		settings_panel.add_child(android_warning)
	
	var customize_btn = Button.new()
	customize_btn.text = "⚙️ PERSONALIZAR HUD"
	customize_btn.size = Vector2(360, 50)
	customize_btn.add_theme_color_override("font_color", Color.CYAN)
	customize_btn.add_theme_stylebox_override("normal", _create_style(Color(0.2, 0.2, 0.2)))
	customize_btn.add_theme_stylebox_override("hover", _create_style(Color(0.3, 0.3, 0.3)))
	customize_btn.add_theme_stylebox_override("pressed", _create_style(Color(0.1, 0.1, 0.1)))
	customize_btn.button_down.connect(func():
		settings_panel.visible = false # Fecha o menu de config
		var customizer = load("res://HUDCustomizer.gd").new()
		
		# Oculta as UIs reais do jogo para não poluir a tela do Customizador
		self.visible = false
		var root = get_tree().get_root()
		var progress = root.find_child("GlobalTaskProgress", true, false)
		if progress: progress.visible = false
		var minimap = root.find_child("MiniMap", true, false)
		if minimap: minimap.visible = false
		
		# Restaura tudo quando fechar
		customizer.tree_exiting.connect(func():
			if is_instance_valid(self): self.visible = true
			var p = get_tree().get_root().find_child("GlobalTaskProgress", true, false)
			if p: p.visible = true
			var m = get_tree().get_root().find_child("MiniMap", true, false)
			if m: m.visible = true
		)
		
		get_tree().get_root().add_child(customizer) # Anexa na raiz para ficar acima de tudo
	)
	settings_panel.add_child(customize_btn)
	
	var disconnect_btn = Button.new()
	disconnect_btn.text = "DESCONECTAR"
	disconnect_btn.size = Vector2(360, 50)
	
	if OS.get_name() == "Android":
		settings_panel.size = Vector2(400, 440)
		customize_btn.position = Vector2(20, 310)
		disconnect_btn.position = Vector2(20, 370)
	else:
		settings_panel.size = Vector2(400, 370)
		customize_btn.position = Vector2(20, 240)
		disconnect_btn.position = Vector2(20, 300)
	
	disconnect_btn.add_theme_color_override("font_color", Color.WHITE)
	disconnect_btn.add_theme_stylebox_override("normal", _create_style(Color.RED))
	disconnect_btn.add_theme_stylebox_override("hover", _create_style(Color.RED.lightened(0.2)))
	disconnect_btn.add_theme_stylebox_override("pressed", _create_style(Color.RED.darkened(0.2)))
	disconnect_btn.button_down.connect(_on_leave_pressed)
	settings_panel.add_child(disconnect_btn)
	
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		pass
	
	_load_custom_hud()

func _create_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func _load_custom_hud():
	var config = ConfigFile.new()
	var err = config.load("user://mobile_hud.cfg")
	if err == OK:
		var elements = {
			"joystick": joystick,
			"use": use_btn,
			"report": rep_btn,
			"jump": jump_btn,
			"crouch": crouch_btn,
			"kill": kill_btn,
			"sabotage": sab_btn,
			"mic": mic_btn,
			"task_list": task_panel
		}
		
		var screen_size = get_viewport_rect().size
		for key in elements.keys():
			var node = elements[key]
			if node:
				if config.has_section_key("HUD", key + "_pos"):
					var rel = config.get_value("HUD", key + "_pos")
					
					# Proteção contra saves antigos
					if key != "joystick" and key != "task_list" and rel.x > 0:
						continue
						
					if key == "joystick":
						node.offset_left = rel.x
						node.offset_top = rel.y
						node.offset_right = rel.x + node.size.x
						node.offset_bottom = rel.y + node.size.y
					elif key == "task_list":
						node.offset_left = rel.x
						node.offset_top = rel.y
						node.offset_right = rel.x + node.size.x
						node.offset_bottom = rel.y + node.size.y
					else:
						node.offset_left = rel.x
						node.offset_top = rel.y
						node.offset_right = rel.x + node.size.x
						node.offset_bottom = rel.y + node.size.y
						
				var def_scale = Vector2(1.0, 1.0)
				node.pivot_offset = node.size / 2.0 # Garante escala centralizada!
				
				if config.has_section_key("HUD", key + "_scale"):
					var saved_scale = config.get_value("HUD", key + "_scale")
					if saved_scale.x > 1.2:
						node.scale = Vector2(1.0, 1.0)
					else:
						node.scale = saved_scale
				else:
					node.scale = def_scale

func _on_leave_pressed():
	if multiplayer.multiplayer_peer:
		if multiplayer.is_server() == false:
			# Avisa o servidor explicitamente que estou saindo, pra ele me remover agora e não esperar timeout
			get_node("/root/Main").rpc_id(1, "leave_server_rpc")
		
		# Espera uns milissegundos pro RPC chegar antes de matar a conexão
		await get_tree().create_timer(0.2).timeout
		multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _create_btn(txt, offset_pos, color, action_name):
	var p = Button.new()
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	style.border_width_bottom = 6
	style.border_color = color.darkened(0.5) # Efeito 3D (Borda mais escura embaixo)
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(4, 4)
	
	p.add_theme_stylebox_override("normal", style)
	p.add_theme_stylebox_override("hover", style)
	p.add_theme_stylebox_override("pressed", style)
	p.add_theme_stylebox_override("disabled", style)
	p.add_theme_stylebox_override("focus", style)
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.offset_left = offset_pos.x
	p.offset_top = offset_pos.y
	p.offset_right = offset_pos.x + 120
	p.offset_bottom = offset_pos.y + 120
	p.pivot_offset = Vector2(60, 60)
	p.focus_mode = Control.FOCUS_NONE
	
	p.text = txt
	p.add_theme_font_size_override("font_size", 22)
	p.add_theme_color_override("font_color", Color.WHITE)
	p.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	p.add_theme_constant_override("shadow_offset_x", 2)
	p.add_theme_constant_override("shadow_offset_y", 2)
	
	# Simula as ações originais de input ao pressionar o botão na tela de toque
	if action_name != "":
		p.button_down.connect(func():
			var ev = InputEventAction.new()
			ev.action = action_name
			ev.pressed = true
			Input.parse_input_event(ev)
		)
		p.button_up.connect(func():
			var ev = InputEventAction.new()
			ev.action = action_name
			ev.pressed = false
			Input.parse_input_event(ev)
		)
	
	# Transparente quando inativo
	p.modulate.a = 0.4
	add_child(p)
	return p

var _hud_update_timer = 0.0
var _last_task_text = "Carregando Tarefas..."

func _toggle_mic():
	if get_node("/root/VoiceManager").is_muted:
		get_node("/root/VoiceManager").is_muted = false
		mic_btn.text = "MIC ON [V]"
		mic_btn.get_theme_stylebox("normal").bg_color = Color.GREEN
		mic_btn.get_theme_stylebox("hover").bg_color = Color.GREEN
		mic_btn.get_theme_stylebox("pressed").bg_color = Color.GREEN
	else:
		get_node("/root/VoiceManager").is_muted = true
		mic_btn.text = "MIC OFF [V]"
		mic_btn.get_theme_stylebox("normal").bg_color = Color.DARK_RED
		mic_btn.get_theme_stylebox("hover").bg_color = Color.DARK_RED
		mic_btn.get_theme_stylebox("pressed").bg_color = Color.DARK_RED

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			_toggle_mic()

func _process(delta):
	_hud_update_timer += delta
	if _hud_update_timer >= 0.5:
		_hud_update_timer = 0.0
		_update_task_list()

var task_names = {
	0: "Download de Dados",
	1: "Unir Fios",
	2: "Passar Cartão",
	3: "Desviar Asteroides",
	4: "Teclado do Reator",
	5: "Sequência do Reator",
	6: "Alinhar Motor",
	7: "Desviar Energia",
	8: "Esvaziar Lixo",
	9: "Estabilizar Navegação",
	10: "Limpar Filtro de O2",
	11: "Ligar Escudos",
	12: "Alinhar Motor (Inferior)"
}

func _update_task_list():
	if not is_instance_valid(task_list_label): return
	
	var player = null
	var main_node = get_tree().get_root().get_node_or_null("Main")
	if main_node:
		player = main_node.get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
	if not player:
		player = get_tree().get_root().find_child(str(multiplayer.get_unique_id()), true, false)
		
	if not player:
		task_list_label.text = "ERRO: Jogador nao encontrado (ID: " + str(multiplayer.get_unique_id()) + ")"
		return
		
	if not player.has_meta("assigned_tasks"):
		task_list_label.text = "Aguardando servidor..."
		return
	
	if player.get("is_impostor") == true:
		var txt = "Tarefas Falsas:\n- Desviar Asteroides\n- Passar Cartão\n- Unir Fios"
		if _last_task_text != txt:
			_last_task_text = txt
			task_list_label.clear()
			task_list_label.append_text(txt)
			task_list_label.add_theme_color_override("font_color", Color.RED)
		return
		
	var assigned = player.get_meta("assigned_tasks")
	var consoles = get_tree().get_nodes_in_group("consoles")
	
	var completed_types = []
	for c in consoles:
		if c.get("task_completed") == true:
			completed_types.append(c.task_type)
			
	var txt = ""
	for t in assigned:
		var t_int = int(t)
		var t_name = task_names.get(t_int, "Tarefa " + str(t_int))
		if t_int in completed_types:
			txt += "[color=green][s]- " + t_name + "[/s][/color]\n"
		else:
			txt += "- " + t_name + "\n"
			
	# Só atualiza se o texto mudou (evita spam de gutter errors)
	if _last_task_text != txt:
		_last_task_text = txt
		task_list_label.clear()
		task_list_label.append_text(txt)

func set_impostor(is_impostor):
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		kill_btn.visible = is_impostor
		sab_btn.visible = is_impostor
	else:
		kill_btn.visible = false
		sab_btn.visible = false
	
	if is_impostor:
		task_list_label.text = "Tarefas Falsas:\n- Desviar Asteroides\n- Passar Cartão\n- Unir Fios"
		task_list_label.add_theme_color_override("font_color", Color.RED)

func update_buttons(can_use, can_report, can_kill, can_sabotage):
	use_btn.modulate.a = 1.0 if can_use else 0.4
	rep_btn.modulate.a = 1.0 if can_report else 0.4
	if kill_btn.visible:
		kill_btn.modulate.a = 1.0 if can_kill else 0.4
	if sab_btn.visible:
		sab_btn.modulate.a = 1.0 if can_sabotage else 0.4
