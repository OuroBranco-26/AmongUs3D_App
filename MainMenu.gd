extends Control

const GAME_VERSION = "1.6.79"

var _play_with_bots = false
var _impostor_count = 1
var in_lobby = false
var lobby_panel: PanelContainer
var players_list: VBoxContainer
var btn_start_game: Button
var connected_players = {} # Agora é um DICIONÁRIO: { id: {"name": "X", "color": Color} }
var public_ip_label: Label
var _name_input: LineEdit
var _debug_label: Label
var color_picker_box: HBoxContainer

var available_colors = [
	Color(1, 0, 0), Color(0, 0, 1), Color(0, 1, 0), Color(1, 1, 0),
	Color(1, 0, 1), Color(1, 0.5, 0), Color(0.5, 0, 0.5), Color(0, 1, 1),
	Color(0.2, 0.2, 0.2), Color(0.9, 0.9, 0.9)
]

func _ready():
	if _check_server_mode():
		return
		
	_check_for_updates()
		
	# Limpa cache RPC para evitar erro na segunda conexao
	get_tree().set_multiplayer(SceneMultiplayer.new())
	
	_build_lobby_ui()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Engine.time_scale = 1.0
	
	var version_lbl = Label.new()
	version_lbl.text = "v" + GAME_VERSION
	version_lbl.add_theme_font_size_override("font_size", 24)
	version_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	version_lbl.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	version_lbl.offset_left = -100
	version_lbl.offset_top = -50
	add_child(version_lbl)
	
	# Fundo do Espaço (Translúcido para mostrar o 3D atrás)
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.08, 0.0) # Transparente!
	add_child(bg)
	
	# === APRESENTAÇÃO 3D (TRIPULANTES FLUTUANDO NO ESPAÇO) ===
	var root_3d = Node3D.new()
	add_child(root_3d)
	
	var cam = Camera3D.new()
	cam.position = Vector3(0, 0, 10)
	
	# Garante que o fundo do espaço seja totalmente PRETO (ao invés do cinza padrão)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	cam.environment = env
	
	root_3d.add_child(cam)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	root_3d.add_child(light)
	
	var colors = [
		Color(1, 0, 0), Color(0, 0, 1), Color(0, 1, 0), Color(1, 1, 0),
		Color(1, 0, 1), Color(1, 0.5, 0), Color(0.5, 0, 0.5), Color(0, 1, 1),
		Color(0.2, 0.2, 0.2), Color(0.9, 0.9, 0.9)
	]
	for i in range(10):
		var EnemyScript = load("res://Enemy.gd")
		var model_scene = load("res://Personagem.fbx")
		if not model_scene: model_scene = load("res://Personagem.glb")
		if not model_scene: model_scene = load("res://Personagem.dae")
		
		if EnemyScript and model_scene:
			var enemy = EnemyScript.new()
			enemy.color_name = "MenuBot"
			enemy.base_color = colors[i]
			enemy.set_process(false)
			enemy.set_physics_process(false)
			
			var model = model_scene.instantiate()
			model.name = "Model"
			var mat = StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			_set_material_recursive(model, mat)
			enemy.add_child(model)
			
			enemy.position = Vector3(randf_range(-12, 12), randf_range(-6, 6), randf_range(-8, 2))
			enemy.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
			
			# Rotação suave contínua no espaço
			var tw = get_tree().create_tween().set_loops()
			tw.tween_property(enemy, "rotation_degrees", enemy.rotation_degrees + Vector3(360, 360, 0), randf_range(20.0, 40.0))
			
			# Movimento de translação suave (flutuando de um lado pro outro)
			var tw_pos = get_tree().create_tween().set_loops()
			tw_pos.tween_property(enemy, "position", enemy.position + Vector3(randf_range(-3, 3), randf_range(-3, 3), 0), randf_range(10.0, 15.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw_pos.tween_property(enemy, "position", enemy.position, randf_range(10.0, 15.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			
			root_3d.add_child(enemy)
			_trigger_float_anim(enemy)
	# ==========================================================
	
	# Estrelas (Partículas)
	var screen_size = get_viewport_rect().size
	var stars = CPUParticles2D.new()
	stars.position = screen_size / 2.0
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	stars.emission_rect_extents = screen_size / 2.0
	stars.amount = 250
	stars.lifetime = 4.0
	stars.spread = 180.0
	stars.gravity = Vector2(0, 0)
	stars.initial_velocity_min = 10.0
	stars.initial_velocity_max = 50.0
	stars.scale_amount_min = 1.0
	stars.scale_amount_max = 3.0
	stars.color = Color(1, 1, 1, 0.5)
	add_child(stars)
	
	# Título
	var title = Label.new()
	title.text = "AMONG BOTS"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.5
	title.anchor_bottom = 0.5
	title.offset_left = -640
	title.offset_right = 640
	title.offset_top = -280
	title.offset_bottom = -80
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color.RED)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	title.pivot_offset = Vector2(640, 100) # Centro do label
	add_child(title)
	
	_debug_label = Label.new()
	_debug_label.position = Vector2(10, 10)
	_debug_label.add_theme_font_size_override("font_size", 20)
	_debug_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(_debug_label)
	
	# Animação do Título (Breathe effect)
	var tween = get_tree().create_tween().set_loops()
	tween.tween_property(title, "scale", Vector2(1.05, 1.05), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -250
	vbox.offset_right = 250
	vbox.offset_top = -60
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	var bot_toggle = CheckButton.new()
	bot_toggle.text = "Preencher com Bots"
	bot_toggle.add_theme_font_size_override("font_size", 18)
	bot_toggle.toggled.connect(func(toggled_on): _play_with_bots = toggled_on)
	bot_toggle.button_pressed = false
	bot_toggle.visible = false # Esconde a opção de bots
	_play_with_bots = false
	vbox.add_child(bot_toggle)
	
	var btn_join = Button.new()
	btn_join.text = "ENTRAR (JOIN)"
	btn_join.custom_minimum_size = Vector2(0, 60)
	btn_join.add_theme_font_size_override("font_size", 30)
	
	var impostor_count_btn = OptionButton.new()
	impostor_count_btn.name = "ImpostorCountOption"
	impostor_count_btn.add_item("Número de Impostores: 1", 0)
	impostor_count_btn.add_item("Número de Impostores: 2", 1)
	impostor_count_btn.custom_minimum_size = Vector2(0, 50)
	impostor_count_btn.add_theme_font_size_override("font_size", 24)
	impostor_count_btn.item_selected.connect(func(index): _impostor_count = index + 1)
	
	var btn_customize = Button.new()
	btn_customize.text = "⚙️ PERSONALIZAR HUD"
	btn_customize.custom_minimum_size = Vector2(250, 50)
	btn_customize.add_theme_font_size_override("font_size", 20)
	btn_customize.add_theme_color_override("font_color", Color.CYAN)
	
	# Coloca no canto superior direito pra não sumir no Mobile
	btn_customize.set_anchors_preset(PRESET_TOP_RIGHT)
	btn_customize.position = Vector2(1000, 20)
	btn_customize.anchor_left = 1.0
	btn_customize.anchor_right = 1.0
	btn_customize.anchor_top = 0.0
	btn_customize.anchor_bottom = 0.0
	btn_customize.offset_left = -270
	btn_customize.offset_right = -20
	btn_customize.offset_top = 20
	btn_customize.offset_bottom = 70
	
	btn_customize.pressed.connect(func():
		var customizer = load("res://HUDCustomizer.gd").new()
		add_child(customizer)
		customizer.move_to_front()
	)
	add_child(btn_customize)
	
	var name_input = LineEdit.new()
	name_input.placeholder_text = "Seu Nome (Obrigatório)"
	name_input.custom_minimum_size = Vector2(0, 50)
	name_input.add_theme_font_size_override("font_size", 24)
	
	var ip_input = LineEdit.new()
	ip_input.placeholder_text = "IP do Servidor (ex: 64.181.162.108)"
	ip_input.text = "64.181.162.108"
	ip_input.custom_minimum_size = Vector2(0, 50)
	ip_input.add_theme_font_size_override("font_size", 24)
	
	# Salva referência pro nome
	_name_input = name_input
	
	# Estilo do Botão
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.8, 0.1, 0.1, 0.8) # Vermelho translúcido
	style_normal.border_width_bottom = 8
	style_normal.border_color = Color(0.5, 0.0, 0.0)
	style_normal.corner_radius_top_left = 20
	style_normal.corner_radius_top_right = 20
	style_normal.corner_radius_bottom_left = 20
	style_normal.corner_radius_bottom_right = 20
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(1.0, 0.2, 0.2, 1.0)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.5, 0.0, 0.0, 1.0)
	style_pressed.border_width_bottom = 0
	
	var btn_quit = Button.new()
	btn_quit.text = "SAIR DO JOGO"
	btn_quit.custom_minimum_size = Vector2(0, 60)
	btn_quit.add_theme_font_size_override("font_size", 30)
	
	for btn in [btn_join, btn_quit]:
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		
	btn_join.pressed.connect(func(): _on_join_pressed(ip_input.text))
	btn_quit.pressed.connect(_graceful_quit)
	
	vbox.add_child(name_input)
	vbox.add_child(ip_input)
	vbox.add_child(impostor_count_btn)
	vbox.add_child(btn_join)
	vbox.add_child(btn_quit)

func _graceful_quit():
	var vm = get_node_or_null("/root/VoiceManager")
	if vm:
		var mp = vm.get("mic_player")
		if mp and is_instance_valid(mp):
			mp.stop()
		var record_bus_idx = AudioServer.get_bus_index("Record")
		if record_bus_idx != -1:
			for i in range(AudioServer.get_bus_effect_count(record_bus_idx) - 1, -1, -1):
				AudioServer.remove_bus_effect(record_bus_idx, i)
	get_tree().quit()

func _show_msg(msg: String):
	if is_instance_valid(_debug_label):
		_debug_label.text = msg
	print(msg)

func _build_lobby_ui():
	lobby_panel = PanelContainer.new()
	lobby_panel.set_anchors_preset(PRESET_CENTER)
	lobby_panel.position = Vector2(440, 160) # Posição inicial (Godot vai ancorar ao centro se parent for control)
	# Garante que centraliza de verdade:
	lobby_panel.anchor_left = 0.5
	lobby_panel.anchor_right = 0.5
	lobby_panel.anchor_top = 0.5
	lobby_panel.anchor_bottom = 0.5
	lobby_panel.offset_left = -200
	lobby_panel.offset_right = 200
	lobby_panel.offset_top = -250
	lobby_panel.offset_bottom = 250
	
	lobby_panel.custom_minimum_size = Vector2(400, 500)
	lobby_panel.pivot_offset = Vector2(200, 250) # Centro do panel (metade de 400x500)
	lobby_panel.scale = Vector2(1.0, 1.0)
	lobby_panel.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	lobby_panel.add_theme_stylebox_override("panel", style)
	add_child(lobby_panel)
	
	var vbox = VBoxContainer.new()
	lobby_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "LOBBY DE ESPERA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)
	
	players_list = VBoxContainer.new()
	players_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(players_list)
	
	public_ip_label = Label.new()
	public_ip_label.text = "Seu IP: Carregando..."
	public_ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	public_ip_label.add_theme_color_override("font_color", Color.YELLOW)
	public_ip_label.visible = false
	vbox.add_child(public_ip_label)
	
	var color_label = Label.new()
	color_label.text = "Escolha sua Cor:"
	color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(color_label)
	
	color_picker_box = HBoxContainer.new()
	color_picker_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(color_picker_box)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer)
	
	btn_start_game = Button.new()
	btn_start_game.text = "▶ INICIAR PARTIDA"
	btn_start_game.custom_minimum_size = Vector2(0, 60)
	btn_start_game.add_theme_font_size_override("font_size", 24)
	btn_start_game.add_theme_color_override("font_color", Color.GREEN)
	btn_start_game.pressed.connect(_on_start_pressed)
	vbox.add_child(btn_start_game)

func _on_host_pressed():
	if _name_input.text.strip_edges() == "":
		_show_msg("ERRO: Digite seu nome primeiro!")
		return
	# Tenta abrir as portas automaticamente via UPnP para jogar via Internet
	var upnp = UPNP.new()
	var err = upnp.discover()
	var external_ip = ""
	if err == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			upnp.add_port_mapping(8910, 8910, "AmongBots", "UDP")
			external_ip = upnp.query_external_address()
			
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(8910)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_enter_lobby()
	
	if external_ip != "":
		public_ip_label.text = "Mande este IP: " + external_ip
		public_ip_label.visible = true
	else:
		public_ip_label.text = "UPnP falhou. Use Radmin/Hamachi ou LAN."
		public_ip_label.visible = true

func _on_join_pressed(ip_input_text: String):
	if _name_input.text.strip_edges() == "":
		_show_msg("ERRO: Digite seu nome primeiro!")
		return
		
	var ip = ip_input_text.strip_edges()
	
	# Se o IP estiver em branco, assume que o jogador quer criar a própria sala (Host) local
	if ip == "":
		_on_host_pressed()
		return
		
	_show_msg("Tentando conectar em: " + ip)
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
		
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, 8910)
	if err != OK:
		_show_msg("ERRO fatal ao criar cliente: " + str(err))
		return
		
	multiplayer.multiplayer_peer = peer
	
	if not multiplayer.connected_to_server.is_connected(_on_join_connected):
		multiplayer.connected_to_server.connect(_on_join_connected)
	if not multiplayer.connection_failed.is_connected(_on_join_failed):
		multiplayer.connection_failed.connect(_on_join_failed)
		
	_show_msg("Aguardando resposta do servidor " + ip + "...")

func _on_join_connected():
	_show_msg("Conectado com sucesso!")
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_enter_lobby()
	rpc_id(1, "rpc_register_player", _name_input.text.strip_edges())

func _on_join_failed():
	_show_msg("ERRO: Falha ao conectar. Tempo esgotado ou rede bloqueada.")
	multiplayer.multiplayer_peer = null

func _enter_lobby():
	in_lobby = true
	# Esconde o menu principal
	for child in get_children():
		if child != lobby_panel and child is CanvasItem:
			child.visible = false
	lobby_panel.visible = true
	
	# Só o Host pode iniciar
	btn_start_game.visible = multiplayer.is_server()
	
	connected_players.clear()
	if multiplayer.is_server():
		var is_headless = (DisplayServer.get_name() == "headless")
		connected_players[1] = {"name": _name_input.text.strip_edges(), "color": available_colors[0], "is_leader": not is_headless}
	_update_lobby_list()

func _on_peer_connected(id):
	pass # Gerenciado via rpc_register_player

func _on_peer_disconnected(id):
	var was_leader = false
	if connected_players.has(id):
		was_leader = connected_players[id].get("is_leader", false)
	connected_players.erase(id)
	
	if was_leader and multiplayer.is_server():
		# Passa a liderança pro próximo jogador real
		for p_id in connected_players.keys():
			if str(p_id) != "1":
				connected_players[p_id]["is_leader"] = true
				break
				
	_update_lobby_list()
	if multiplayer.is_server():
		rpc("rpc_sync_lobby", connected_players)

@rpc("any_peer", "call_local")
func rpc_sync_lobby(players_dict):
	connected_players = players_dict
	_update_lobby_list()

@rpc("any_peer", "call_remote")
func rpc_register_player(player_name: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	var used_colors = []
	for p_id in connected_players.keys():
		used_colors.append(connected_players[p_id]["color"])
		
	var assigned_color = Color.WHITE
	for c in available_colors:
		if not used_colors.has(c):
			assigned_color = c
			break
			
	var is_first_real_player = true
	for p_id in connected_players.keys():
		if str(p_id) != "1":
			is_first_real_player = false
			break
			
	connected_players[sender_id] = {"name": player_name, "color": assigned_color, "is_leader": is_first_real_player}
	_update_lobby_list()
	rpc("rpc_sync_lobby", connected_players)

@rpc("any_peer", "call_local")
func rpc_request_color(hex_color: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	
	var requested_color = Color(hex_color)
	var is_taken = false
	for p_id in connected_players.keys():
		if connected_players[p_id]["color"] == requested_color:
			is_taken = true
			break
			
	if not is_taken and connected_players.has(sender_id):
		connected_players[sender_id]["color"] = requested_color
		_update_lobby_list()
		rpc("rpc_sync_lobby", connected_players)

func _on_color_button_pressed(hex_color: String):
	if multiplayer.is_server():
		rpc_request_color(hex_color)
	else:
		rpc_id(1, "rpc_request_color", hex_color)

func _update_lobby_list():
	if not is_instance_valid(players_list):
		return # Servidor dedicado headless não tem GUI
		
	# Atualiza Estado do Botão INICIAR
	var my_id = multiplayer.get_unique_id()
	
	# Exibe o status
	if is_instance_valid(public_ip_label):
		public_ip_label.text = "Seu ID: " + str(my_id)
		public_ip_label.visible = true

	# Qualquer um pode iniciar a partida agora!
	if is_instance_valid(btn_start_game):
		btn_start_game.visible = true
		btn_start_game.disabled = false
		btn_start_game.text = "▶ INICIAR PARTIDA"
		
	for child in players_list.get_children():
		child.queue_free()
		
	for id in connected_players.keys():
		var hbox = HBoxContainer.new()
		
		var crect = ColorRect.new()
		crect.custom_minimum_size = Vector2(25, 25)
		crect.color = connected_players[id]["color"]
		crect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(crect)
		
		var lbl = Label.new()
		var p_name = connected_players[id]["name"]
		
		if p_name == "Servidor Headless" or p_name == "Servidor":
			lbl.text = " [SERVIDOR DEDICADO]"
			lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
			crect.color = Color.BLACK
		else:
			if id == multiplayer.get_unique_id():
				if id == 1:
					lbl.text = " " + p_name + " (Você/Host)"
					lbl.add_theme_color_override("font_color", Color.YELLOW)
				else:
					lbl.text = " " + p_name + " (Você)"
					lbl.add_theme_color_override("font_color", Color.CYAN)
			else:
				lbl.text = " " + p_name
				lbl.add_theme_color_override("font_color", Color.WHITE)
				
		lbl.add_theme_font_size_override("font_size", 22)
		hbox.add_child(lbl)
		players_list.add_child(hbox)
	# Atualizar botões de cores
	if is_instance_valid(color_picker_box):
		for child in color_picker_box.get_children():
			child.queue_free()
			
		var taken_colors = []
		for p_id in connected_players.keys():
			taken_colors.append(connected_players[p_id]["color"])
			
		for c in available_colors:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(30, 30)
			
			var style = StyleBoxFlat.new()
			style.bg_color = c
			style.corner_radius_top_left = 5
			style.corner_radius_top_right = 5
			style.corner_radius_bottom_left = 5
			style.corner_radius_bottom_right = 5
			
			if taken_colors.has(c):
				style.bg_color = c.darkened(0.6)
				btn.disabled = true
				btn.text = "X"
				btn.add_theme_color_override("font_disabled_color", Color.WHITE)
			else:
				btn.pressed.connect(_on_color_button_pressed.bind(c.to_html(false)))
				
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style)
			btn.add_theme_stylebox_override("pressed", style)
			btn.add_theme_stylebox_override("disabled", style)
			color_picker_box.add_child(btn)

func _on_start_pressed():
	if multiplayer.is_server():
		rpc("rpc_start_game", _impostor_count)
	else:
		# Cliente pede ao servidor
		rpc_id(1, "rpc_request_start", _impostor_count)

@rpc("any_peer")
func rpc_request_start(req_imp_count = 1):
	if multiplayer.is_server():
		print("[SERVIDOR] Jogador pediu para iniciar!")
		rpc("rpc_start_game", req_imp_count)

@rpc("any_peer", "call_local")
func rpc_start_game(final_imp_count = 1):
	var main_packed = load("res://Main.tscn")
	var main_scene = main_packed.instantiate()
	main_scene.set("play_with_bots", _play_with_bots)
	main_scene.set("host_impostor_count", final_imp_count)
	main_scene.set("lobby_player_data", connected_players.duplicate())
	get_tree().root.add_child(main_scene)
	get_tree().current_scene = main_scene
	queue_free()

func _set_material_recursive(node, mat):
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_set_material_recursive(child, mat)

func _trigger_float_anim(enemy):
	await get_tree().process_frame
	await get_tree().process_frame # Espera a injeção terminar
	if is_instance_valid(enemy) and enemy.model_node:
		var ap = enemy._get_ap(enemy.model_node)
		if ap:
			var anims = []
			for a in ap.get_animation_list():
				if "RESET" not in a:
					anims.append(a)
			
			if anims.size() > 0:
				var random_anim = anims[randi() % anims.size()]
				ap.play(random_anim)
				
				# Garante que a animação sorteada fique em loop
				var anim_obj = ap.get_animation(random_anim)
				if anim_obj:
					anim_obj.loop_mode = Animation.LOOP_LINEAR

# === SERVIDOR DEDICADO ===
func _check_server_mode() -> bool:
	var debug_file = FileAccess.open("user://debug_entry.txt", FileAccess.WRITE)
	debug_file.store_line("Entered _check_server_mode")
	debug_file.store_line("DisplayServer: " + DisplayServer.get_name())
	
	if DisplayServer.get_name() != "headless":
		var has_server = false
		for arg in OS.get_cmdline_args():
			if "--server" in arg: has_server = true
		for arg in OS.get_cmdline_user_args():
			if "--server" in arg: has_server = true
		if not has_server:
			debug_file.store_line("Not headless and no --server. Returning false.")
			debug_file.close()
			return false
			
	debug_file.store_line("Past headless check")
	
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		debug_file.store_line("Server already running. Reusing.")
		in_lobby = true
		connected_players.clear()
		connected_players[1] = {"name": "Servidor Headless", "color": Color.BLACK}
		
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
			
		debug_file.close()
		return true

	var peer = ENetMultiplayerPeer.new()
	debug_file.store_line("Created ENetMultiplayerPeer")
	
	var err = peer.create_server(8910)
	debug_file.store_line("Called create_server: " + str(err))
	debug_file.close()
	
	if err != OK:
		print("[SERVIDOR DEDICADO] ERRO ao criar servidor: ", err)
		return true
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	in_lobby = true
	connected_players.clear()
	connected_players[1] = {"name": "Servidor Headless", "color": Color.BLACK}
	print("[SERVIDOR DEDICADO] Servidor criado com sucesso!")
	
	return true

# --- AUTO UPDATER ---
var update_link = ""

func _check_for_updates():
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_update_response)
	# IP_DO_ORACLE: Troque pelo seu IP futuramente se quiser, ex: http://123.45.67.89:8080/version.json
	http.request("http://64.181.162.108:8080/version.json")

func _on_update_response(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		if parse_result == OK:
			var data = json.get_data()
			if data.has("version") and data.has("link"):
				if data["version"] != GAME_VERSION:
					_show_update_screen(data["version"], data["link"])

func _show_update_screen(new_ver, link):
	update_link = link
	
	var block_panel = Panel.new()
	block_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Garante que vai sobrepor todo o resto
	block_panel.z_index = 100 
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	block_panel.add_theme_stylebox_override("panel", style)
	add_child(block_panel)
	
	var lbl = Label.new()
	lbl.text = "Atualização Necessária!\n\nUma nova versão do jogo (" + new_ver + ") está disponível.\nSua versão atual é " + GAME_VERSION + "."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	block_panel.add_child(lbl)
	
	var btn = Button.new()
	btn.text = "BAIXAR ATUALIZAÇÃO"
	btn.custom_minimum_size = Vector2(400, 80)
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.position.y += 100
	btn.add_theme_font_size_override("font_size", 24)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color.GREEN.darkened(0.2)
	btn_style.corner_radius_top_left = 15
	btn_style.corner_radius_top_right = 15
	btn_style.corner_radius_bottom_left = 15
	btn_style.corner_radius_bottom_right = 15
	btn.add_theme_stylebox_override("normal", btn_style)
	
	btn.pressed.connect(func(): OS.shell_open(update_link))
	block_panel.add_child(btn)
