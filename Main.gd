extends Node3D

@export var sync_json_data: String = ""

var global_progress: ProgressBar
var total_tasks = 0 # Inicializado em 0 para forçar o cliente a pedir os dados
var completed_tasks = 0
var target_progress_val = 0.0

var _server_player_data = {}

var o2_timer = 0.0
var o2_active = false
var sync_interval: float = 0.05
var time_since_last_sync: float = 0.0
var global_sabotage_cooldown: float = 0.0

var monitor_lamps = {}
var monitor_timers = {}

var o2_label: Label
var o2_fixes_needed = 0

var player_role_is_impostor = false
var global_impostor_name = ""
var game_over = false
var play_with_bots = false # Desativado pelo usuÃƒÂ¡rio
var host_impostor_count = 1

var lobby_player_data = {}

func _ready():
	get_tree().create_timer(1.0).timeout.connect(func(): _build_astar_grid())
	
	var monitors = {
		"Cafeteria": Vector3(0, 2.5, -30),
		"Corredor ADM": Vector3(3, 2.5, 0),
		"Storage": Vector3(0, 2.5, 20)
	}
	
	for m_name in monitors:
		var lamp = CSGSphere3D.new()
		lamp.radius = 0.5
		lamp.position = monitors[m_name]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.RED
		mat.emission_enabled = true
		mat.emission = Color.RED
		lamp.material = mat
		lamp.visible = false # Esconde as lâmpadas de teste do mapa
		add_child(lamp)
		monitor_lamps[m_name] = lamp
		monitor_timers[m_name] = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().has_meta("play_with_bots"):
		play_with_bots = get_tree().get_meta("play_with_bots")
	
	var sm = load("res://SoundManager.gd").new()
	sm.name = "SoundManager"
	add_child(sm)
	
	# Configurar Inputs Ã¢â‚¬â€ cada um verificado independentemente (BUG-04 fix)
	var input_actions = [["ui_report", KEY_R], ["ui_vent", KEY_F], ["ui_sabotage", KEY_M], ["ui_interact", KEY_E], ["ui_kill", KEY_Q]]
	for action_data in input_actions:
		if not InputMap.has_action(action_data[0]):
			InputMap.add_action(action_data[0])
			var ev = InputEventKey.new()
			ev.physical_keycode = action_data[1]
			InputMap.action_add_event(action_data[0], ev)

	# ConfiguraÃƒÂ§ÃƒÂ£o Global de IluminaÃƒÂ§ÃƒÂ£o (Luzes podem ser sabotadas)
	var env = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.02) # Mais escuro
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.65, 0.7) # Luz clara de hospital
	env.environment = environment
	add_child(env)
	
	# Luz geral de hospital no teto da nave inteira (fraca, sem sombra pra não pesar)
	var global_light = DirectionalLight3D.new()
	global_light.name = "HospitalLight"
	global_light.light_color = Color(0.9, 0.95, 1.0) # Branco limpo
	global_light.light_energy = 0.5
	global_light.shadow_enabled = false
	global_light.rotation_degrees = Vector3(-90, 0, 0) # Aponta direto pra baixo (luz de teto)
	global_light.add_to_group("map_lights") # Se apaga na sabotagem
	add_child(global_light)
		
	# Configurar NavMesh Dinamicamente
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	# IMPORTANTE: Ensina a malha a ler as fÃƒÂ­sicas dos CSGs gerados pelo MapBuilder, nÃƒÂ£o sÃƒÂ³ meshes!
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	
	# Adiciona o Gerador de Mapa
	var MapBuilderScript = load("res://MapBuilder.gd")
	var map_builder = MapBuilderScript.new()
	map_builder.name = "MapBuilder"
	nav_region.add_child(map_builder)
	
	# Esconde a Layer 2 (Nomes das Salas) de todas as CÃƒÂ¢meras padrÃƒÂ£o do jogo (como a do Player)
	for cam in get_tree().get_root().find_children("*", "Camera3D", true, false):
		if cam.name != "MiniMapCamera" and cam.name != "camera":
			cam.cull_mask &= ~2
	var ConsoleScene = load("res://TaskConsole.tscn")
	if ConsoleScene:
		var add_task = func(t_type: int, pos: Vector3):
			var console = ConsoleScene.instantiate()
			console.task_type = t_type
			console.position = pos
			nav_region.add_child(console)
			
		# Distribuindo as tasks pelas 14 salas (movendo-as para as paredes/cantos para nÃƒÂ£o bugar nos props)
		add_task.call(7, Vector3(0, 0, -42))   # Cafeteria: Lixo (Parede Norte)
		add_task.call(8, Vector3(0, 0, 12))	# Storage: Lixo (Parede Norte)
		add_task.call(2, Vector3(15, 0, -3))   # Admin: CartÃƒÂ£o (Parede Norte)
		add_task.call(10, Vector3(10, 0, -3))  # Admin: Filtro de OxigÃƒÂªnio (Parede Norte, ÃƒÂ  esquerda)
		add_task.call(1, Vector3(-30, 0, 16))  # Electrical: Fios (Parede Leste)
		add_task.call(0, Vector3(-25, 0, -10)) # Medbay: Download (Parede Oeste, longe das camas)
		add_task.call(1, Vector3(-35, 0, 3))   # Security: Fios (Parede Oeste)
		add_task.call(4, Vector3(-62, 0, 0))  # Reactor: Teclado (Meio da parede Oeste, longe dos dutos)
		add_task.call(5, Vector3(-56, 0, 8))   # Reactor: Sequência (Encostado na parede direita da entrada inferior do Reator)
		add_task.call(6, Vector3(-50, 0, -26)) # Upper Engine: Motor (Parede Oeste)
		add_task.call(12, Vector3(-50, 0, 24))  # Lower Engine: Motor (Parede Oeste)
		add_task.call(3, Vector3(40, 0, -38))  # Weapons: Asteroides (Parede Norte)
		add_task.call(10, Vector3(34, 0, -10)) # O2: Filtro de OxigÃƒÂªnio (Parede Norte)
		add_task.call(9, Vector3(63, 0, -8))   # Navigation: Navegação (Parede Leste, longe dos dutos)
		add_task.call(11, Vector3(42, 0, 20))  # Shields: Ligar Escudos (Parede Leste)
		add_task.call(0, Vector3(24, 0, 36))   # Communications: Download (Parede Sul)

	# Adiciona os 14 Dutos Oficiais com ConexÃƒÂµes Exatas (The Skeld Vents)
	var VentScript = load("res://Vent.gd")
	
	_wait_and_build_grid()

	var vent_list = [
		[Vector3(-50, 0, -22), "Upper Engine", [1]],	   # ID 0
		[Vector3(-60, 0, -6), "Reactor (Cima)", [0]],	  # ID 1
		[Vector3(-60, 0, 8), "Reactor (Baixo)", [3]],	  # ID 2
		[Vector3(-50, 0, 20), "Lower Engine", [2]],		# ID 3
		[Vector3(-28, 0, 2), "Security", [5, 6]],		  # ID 4
		[Vector3(-16, 0, -6), "MedBay", [4, 6]],		   # ID 5
		[Vector3(-30, 0, 12), "Electrical", [4, 5]],	   # ID 6
		[Vector3(10, 0, -38), "Cafeteria", [8, 9]],		# ID 7
		[Vector3(10, 0, 6), "Admin", [7, 9]],			  # ID 8
		[Vector3(32, 0, -10), "O2", [7, 8]],			   # ID 9
		[Vector3(34, 0, -38), "Weapons", [11]],			# ID 10
		[Vector3(56, 0, -12), "Navigation (Cima)", [10, 12]], # ID 11
		[Vector3(60, 0, -4), "Navigation (Baixo)", [11, 13]], # ID 12
		[Vector3(42, 0, 16), "Shields", [12]]			  # ID 13
	]
	
	for i in range(vent_list.size()):
		var v_data = vent_list[i]
		var v = VentScript.new()
		v.vent_id = i
		v.room_name = v_data[1]
		v.connected_vents = v_data[2]
		v.position = v_data[0]
		add_child(v)

	# Adiciona Consoles de Sabotagem
	var SabConsole = load("res://SabotageConsole.gd")
	var sab_lights = SabConsole.new()
	sab_lights.sabotage_type = "LIGHTS"
	sab_lights.position = Vector3(-25, 0, 16) # Electrical
	nav_region.add_child(sab_lights)
	
	var sab_o2 = SabConsole.new()
	sab_o2.sabotage_type = "O2"
	sab_o2.position = Vector3(34, 0, -7) # O2
	add_child(sab_o2)
	
	var sab_o2_2 = SabConsole.new()
	sab_o2_2.sabotage_type = "O2"
	sab_o2_2.position = Vector3(15, 0, -3) # Admin
	add_child(sab_o2_2)

	var CamConsoleScript = load("res://CameraConsole.gd")
	if CamConsoleScript:
		var cam_console = CamConsoleScript.new()
		cam_console.position = Vector3(-31, 0, -1)
		cam_console.rotation_degrees.y = 0
		add_child(cam_console)
		
	var players_node = Node3D.new()
	players_node.name = "Players"
	add_child(players_node)
	
	var spawner = MultiplayerSpawner.new()
	spawner.name = "PlayerSpawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(players_node)
	spawner.add_spawnable_scene("res://Player.tscn")
	
	players_node.child_entered_tree.connect(_on_player_spawned)
	
	if multiplayer.is_server():
		if DisplayServer.get_name() != "headless":
			_spawn_player(multiplayer.get_unique_id())
		
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)
		
		multiplayer.peer_connected.connect(func(id): if id != 1 or DisplayServer.get_name() != "headless": _spawn_player(id))
		multiplayer.peer_disconnected.connect(_remove_player)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	if play_with_bots:
		var all_colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.DEEP_PINK, Color.ORANGE, Color.PURPLE, Color.CYAN, Color.LIME_GREEN, Color.BLACK]
		var color_names = ["Vermelho", "Azul", "Verde", "Amarelo", "Rosa", "Laranja", "Roxo", "Ciano", "Lima", "Preto"]
		
		var num_real_players = 0
		for p_id in lobby_player_data.keys():
			var p_name = lobby_player_data[p_id]["name"]
			if p_name == "Servidor Headless" or p_name == "Servidor": continue
			
			num_real_players += 1
			var p_color = lobby_player_data[p_id]["color"]
			var idx = all_colors.find(p_color)
			if idx != -1:
				all_colors.remove_at(idx)
				color_names.remove_at(idx)
				
		var bots_needed = 10 - num_real_players
		
		var spawn_positions = [
			Vector3(2.5, 0, -36), Vector3(-2.5, 0, -36),
			Vector3(3, 0, -38), Vector3(-3, 0, -38),
			Vector3(2.5, 0, -40), Vector3(-2.5, 0, -40),
			Vector3(1.5, 0, -35.5), Vector3(-1.5, 0, -35.5),
			Vector3(1.5, 0, -40.5), Vector3(-1.5, 0, -40.5)
		]
		
		for i in range(min(bots_needed, all_colors.size())):
			_spawn_enemy(color_names[i], all_colors[i], spawn_positions[i])
	
	var is_dedicated_srv = DisplayServer.get_name() == "headless"
	var local_player = get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
	if not local_player and not is_dedicated_srv:
		for i in range(20):
			await get_tree().create_timer(0.5).timeout
			local_player = get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
			if local_player:
				break
	
	var all_players = []
	for p in get_node("Players").get_children():
		all_players.append(p)
	
	if play_with_bots:
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			all_players.append(e)
			
	if multiplayer.is_server():
		var game_seed = randi()
		all_players.shuffle()
		var num_impostors = host_impostor_count
		if num_impostors > all_players.size() - 1 and all_players.size() > 1:
			num_impostors = all_players.size() - 1
			
		var impostor_ids = []
		for i in range(num_impostors):
			if i < all_players.size():
				impostor_ids.append(str(all_players[i].name))
				
		var human_crew = 0
		for p in get_node("Players").get_children():
			if not impostor_ids.has(str(p.name)):
				human_crew += 1
				
		var t_tasks = 7
		if human_crew > 0:
			t_tasks = human_crew * 7
			
		var data_dict = {"game_seed": game_seed, "impostor_ids": impostor_ids, "t_tasks": t_tasks}
		sync_json_data = JSON.stringify(data_dict)
		_assign_tasks_locally.call_deferred(game_seed, impostor_ids, t_tasks)
		
	var canvas = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)
	
	var MiniMapScript = load("res://MiniMapUI.gd")
	var minimap = MiniMapScript.new()
	canvas.add_child(minimap)
	
	var HUDScript = load("res://PlayerHUD.gd")
	var hud = HUDScript.new()
	hud.name = "PlayerHUD"
	canvas.add_child(hud)
	
	o2_label = Label.new()
	o2_label.position = Vector2(400, 50)
	o2_label.add_theme_font_size_override("font_size", 40)
	o2_label.add_theme_color_override("font_color", Color.RED)
	o2_label.visible = false
	canvas.add_child(o2_label)
	
	global_progress = ProgressBar.new()
	global_progress.name = "GlobalTaskProgress"
	global_progress.position = Vector2(20, 20)
	global_progress.size = Vector2(350, 25)
	global_progress.scale = Vector2(1.0, 1.0)
	global_progress.value = 0
	global_progress.show_percentage = false
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_bg.corner_radius_top_left = 12
	style_bg.corner_radius_top_right = 12
	style_bg.corner_radius_bottom_left = 12
	style_bg.corner_radius_bottom_right = 12
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.1, 0.8, 0.2, 0.9)
	style_fill.corner_radius_top_left = 12
	style_fill.corner_radius_top_right = 12
	style_fill.corner_radius_bottom_left = 12
	style_fill.corner_radius_bottom_right = 12
	
	global_progress.add_theme_stylebox_override("background", style_bg)
	global_progress.add_theme_stylebox_override("fill", style_fill)
	canvas.add_child(global_progress)
	
	reload_hud()

func reload_hud():
	if not is_instance_valid(global_progress): return
	var config = ConfigFile.new()
	if config.load("user://mobile_hud.cfg") == OK:
		if config.has_section_key("HUD", "progress_bar_pos"):
			global_progress.position = config.get_value("HUD", "progress_bar_pos")
			
		global_progress.pivot_offset = global_progress.size / 2.0 # Escala a partir do centro
		
		if config.has_section_key("HUD", "progress_bar_scale"):
			global_progress.scale = config.get_value("HUD", "progress_bar_scale")
	
func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		var root = get_tree().get_root()
		var voting = root.find_child("VotingUI", true, false)
		var has_ui_open = root.has_node("TaskUI") or root.has_node("SabotageUI") or root.has_node("VentUI") or root.has_node("CamerasUI")
		if not has_ui_open and (not voting or not voting.visible):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _show_role_splash(canvas):
	var splash = ColorRect.new()
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.color = Color(0, 0, 0, 0.0) # Começa invisível
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.modulate = Color(1, 1, 1, 0) # Começa invisível
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 100)
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("outline_color", Color.BLACK)
	
	var subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 36)
	subtitle.add_theme_constant_override("outline_size", 8)
	subtitle.add_theme_color_override("outline_color", Color.BLACK)
	
	var bg_target = Color.BLACK
	if player_role_is_impostor:
		title.text = "IMPOSTOR"
		title.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1)) # Vermelho forte
		subtitle.text = "Sabote e elimine a tripulação"
		subtitle.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
		bg_target = Color(0.2, 0.0, 0.0, 0.95) # Fundo avermelhado escuro e ameaçador
	else:
		title.text = "TRIPULANTE"
		title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0)) # Azul ciano
		subtitle.text = "Faça as tarefas e descubra o assassino"
		subtitle.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		bg_target = Color(0.0, 0.1, 0.2, 0.95) # Fundo azulado espacial
		
	vbox.add_child(title)
	vbox.add_child(subtitle)
	center.add_child(vbox)
	splash.add_child(center)
	canvas.add_child(splash)
	
	# Animações de entrada Premium
	var tw = get_tree().create_tween().set_parallel(true)
	tw.tween_property(splash, "color", bg_target, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(center, "modulate", Color(1, 1, 1, 1), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Remove suavemente após 4 segundos
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(splash):
			var tw2 = get_tree().create_tween()
			tw2.tween_property(splash, "modulate:a", 0.0, 0.5)
			tw2.tween_callback(func(): splash.queue_free())
	)

func _set_material_recursive(node, mat):
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_set_material_recursive(child, mat)

func _spawn_enemy(e_name, color, pos):
	var EnemyScript = load("res://Enemy.gd")
	var enemy = EnemyScript.new()
	enemy.name = "Bot_" + str(e_name)
	enemy.position = pos
	enemy.color_name = e_name
	enemy.base_color = color
	
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape = CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	collision.shape = shape
	collision.position.y = 1.0
	enemy.add_child(collision)
	
	var sync = MultiplayerSynchronizer.new()
	sync.name = "EnemySync"
	sync.root_path = NodePath("..")
	var rep = SceneReplicationConfig.new()
	rep.add_property(NodePath(".:position"))
	rep.add_property(NodePath(".:rotation"))
	rep.add_property(NodePath(".:velocity"))
	rep.add_property(NodePath(".:is_dead"))
	rep.add_property(NodePath(".:is_stabbing"))
	rep.add_property(NodePath(".:is_stunned"))
	rep.add_property(NodePath(".:state"))
	sync.replication_config = rep
	enemy.add_child(sync)
	
	var model_scene = load("res://Personagem.fbx")
	if not model_scene: model_scene = load("res://Personagem.glb")
	if not model_scene: model_scene = load("res://Personagem.dae")
	if model_scene:
		var model = model_scene.instantiate()
		model.name = "Model"
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		_set_material_recursive(model, mat)
		enemy.add_child(model)
	
	var ray = RayCast3D.new()
	ray.position.y = 1.0
	ray.name = "RayCast3D"
	enemy.add_child(ray)
	enemy.add_to_group("enemies")
	add_child(enemy)

@rpc("any_peer", "call_local")
func complete_task():
	completed_tasks += 1
	target_progress_val = float(completed_tasks) / float(total_tasks) * 100.0
	if has_node("SoundManager"):
		get_node("SoundManager").play_sound("task_done", -5.0)

func finish_player_task(ui_node):
	rpc("complete_task")
	if ui_node.has_meta("source_console"):
		var console = ui_node.get_meta("source_console")
		if is_instance_valid(console):
			console.mark_completed()
			var player = get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
			if player and player.has_meta("assigned_tasks"):
				var assigned = player.get_meta("assigned_tasks")
				var idx = -1
				for i in range(assigned.size()):
					if int(assigned[i]) == console.task_type:
						idx = i
						break
				if idx != -1:
					assigned.remove_at(idx)
					player.set_meta("assigned_tasks", assigned)
					if player.has_node("PlayerHUD"):
						player.get_node("PlayerHUD").update_task_list(assigned, false)
					for c in get_tree().get_nodes_in_group("consoles"):
						if c.has_method("refresh_task_status"):
							c.refresh_task_status()

@rpc("any_peer", "call_local")
func trigger_sabotage_lights():
	global_sabotage_cooldown = 40.0
	for l in get_tree().get_nodes_in_group("map_lights"):
		l.visible = false
	var env = get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment.ambient_light_energy = 0.0
		
	# Esconde nomes de todo mundo
	for p in get_tree().get_nodes_in_group("players"):
		if p.get("name_label"):
			p.name_label.visible = false
			
	var player = get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
	if player and player.get("flashlight"):
		player.flashlight.light_energy = 1.0
		if player.get("is_impostor"):
			player.flashlight.omni_range = 10.0 # Impostor enxerga longe
		else:
			player.flashlight.omni_range = 3.0 # Tripulante enxerga perto
			
	for c in get_tree().get_nodes_in_group("sabotage_consoles"):
		if c.get("sabotage_type") == "LIGHTS":
			c.activate()

@rpc("any_peer", "call_local")
func fix_sabotage_lights():
	for l in get_tree().get_nodes_in_group("map_lights"):
		l.visible = true
	var env = get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment.ambient_light_energy = 1.0
		
	# Mostra nomes de novo
	for p in get_tree().get_nodes_in_group("players"):
		if p.get("name_label"):
			p.name_label.visible = true
			
	var player = get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
	if player and player.get("flashlight"):
		player.flashlight.light_energy = 0.0
		
	for c in get_tree().get_nodes_in_group("sabotage_consoles"):
		if c.get("sabotage_type") == "LIGHTS":
			c.deactivate()

@rpc("any_peer", "call_local")
func trigger_sabotage_o2():
	if not o2_active:
		global_sabotage_cooldown = 40.0
		o2_active = true
		o2_timer = 30.0
		o2_fixes_needed = 2
		o2_label.visible = true
		for c in get_tree().get_nodes_in_group("sabotage_consoles"):
			if c.get("sabotage_type") == "O2":
				c.activate()

@rpc("any_peer", "call_local")
func register_o2_fix(console_path: String):
	var console_node = get_node_or_null(console_path)
	if console_node:
		console_node.deactivate()
	o2_fixes_needed -= 1
	if o2_fixes_needed <= 0:
		fix_sabotage_o2()

@rpc("any_peer", "call_local")
func fix_sabotage_o2():
	o2_active = false
	o2_label.visible = false
	for c in get_tree().get_nodes_in_group("sabotage_consoles"):
		if c.get("sabotage_type") == "O2":
			c.deactivate()

@rpc("any_peer", "call_local")
func trigger_sabotage_doors(room_group: String):
	global_sabotage_cooldown = 40.0
	for door in get_tree().get_nodes_in_group("doors"):
		if door.get("room_group") == room_group:
			door.close_door()
	get_tree().create_timer(12.0).timeout.connect(func():
		for door in get_tree().get_nodes_in_group("doors"):
			if door.get("room_group") == room_group:
				door.open_door()
	)

@rpc("any_peer", "call_local")
func start_meeting():
	var root = get_tree().get_root()
	var uis_to_close = ["CamerasUI", "TaskUI", "SabotageUI", "VentUI", "MapMenuUI", "MiniMapUI"]
	for ui_name in uis_to_close:
		var node = root.get_node_or_null(ui_name)
		if node: node.queue_free()
			
	var hud = get_node_or_null("CanvasLayer/PlayerHUD")
	if hud: hud.visible = false
	var minimap = get_node_or_null("CanvasLayer/MiniMap")
	if minimap: minimap.visible = false
			
	var existing = root.find_child("VotingUI", true, false)
	if existing:
		existing.visible = true
	else:
		var VotingScript = load("res://VotingUI.gd")
		if VotingScript:
			var voting_ui = VotingScript.new()
			voting_ui.name = "VotingUI"
			var canvas = get_node_or_null("CanvasLayer")
			if canvas: canvas.add_child(voting_ui)
			else: root.add_child(voting_ui)
			voting_ui.visible = true
		
	var players_node = get_node_or_null("Players")
	if players_node:
		for p in players_node.get_children():
			if p.is_multiplayer_authority() and not p.get("is_dead"):
				p.global_position = Vector3(randf_range(-2.5, 2.5), 2.0, randf_range(-40, -36))
				p.velocity = Vector3.ZERO
	
	if multiplayer.is_server():
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.get("is_dead"):
				e.global_position = Vector3(randf_range(-2.5, 2.5), 2.0, randf_range(-40, -36))
				e.velocity = Vector3.ZERO
		
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func check_win_conditions():
	if game_over: return
	if completed_tasks >= total_tasks:
		end_game("CREWMATE", "Todas as tarefas foram concluidas!")
		return
	var alive_crew = 0
	var alive_impostors = 0
	var players_node = get_node_or_null("Players")
	if players_node:
		for p in players_node.get_children():
			if not p.get("is_dead"):
				if p.get("is_impostor"): alive_impostors += 1
				else: alive_crew += 1
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.get("is_dead"):
			if enemy.get("is_impostor"): alive_impostors += 1
			else: alive_crew += 1
	if alive_impostors == 0:
		end_game("CREWMATE", "O Impostor foi neutralizado!")
		return
	if alive_crew <= 1 and alive_impostors > 0:
		end_game("IMPOSTOR", "A tripulacao foi dizimada!")

func _assign_tasks_locally(game_seed: int, impostor_ids: Array, t_tasks: int):
	total_tasks = t_tasks
	
	var is_dedicated = DisplayServer.get_name() == "headless"
	var local_player = get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
	if not local_player and not is_dedicated:
		for i in range(40):
			await get_tree().create_timer(0.25).timeout
			local_player = get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
			if local_player: break
	
	var all_players = []
	for p in get_node("Players").get_children():
		all_players.append(p)
	if get("play_with_bots"):
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			all_players.append(e)
			
	for p in all_players:
		var p_name = str(p.name)
		var is_imp = impostor_ids.has(p_name)
		p.set("is_impostor", is_imp)
		p.set("role", "IMPOSTOR" if is_imp else "CREWMATE")
		
		var p_tasks = []
		if not is_imp:
			seed(game_seed + p_name.hash())
			var pool_tasks = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
			pool_tasks.shuffle()
			p_tasks = pool_tasks.slice(0, 7)
			
		p.set_meta("assigned_tasks", p_tasks)
		if multiplayer.is_server() and p.has_method("receive_tasks") and p.name.is_valid_int():
			p.rpc_id(p.name.to_int(), "receive_tasks", p_tasks)
		p.set("sync_task_string", JSON.stringify(p_tasks))
		p.set("is_impostor", is_imp)
		p.set("sync_is_impostor", is_imp)
		
		if p_name == str(multiplayer.get_unique_id()):
			player_role_is_impostor = is_imp
		
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		for i in range(20):
			await get_tree().create_timer(0.5).timeout
			canvas = get_node_or_null("CanvasLayer")
			if canvas: break
			
	if canvas:
		var hud = canvas.get_node_or_null("PlayerHUD")
		if hud and hud.has_method("_update_task_list"):
			hud._update_task_list()
			
	for c in get_tree().get_nodes_in_group("consoles"):
		if c.has_method("refresh_task_status"):
			c.refresh_task_status()
			
	if canvas:
		_show_role_splash(canvas)

@rpc("any_peer", "call_remote")
func request_tasks_from_main():
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		var player = get_node_or_null("Players/" + str(sender_id))
		if player and player.has_meta("assigned_tasks"):
			if player.has_method("receive_tasks"):
				player.rpc_id(sender_id, "receive_tasks", player.get_meta("assigned_tasks"))

@rpc("authority", "call_remote")
func sync_game_data_str(json_str: String):
	var data = JSON.parse_string(json_str)
	if typeof(data) == TYPE_DICTIONARY:
		_assign_tasks_locally(int(data["game_seed"]), data["impostor_ids"], int(data["t_tasks"]))

@rpc("any_peer", "call_remote")
func request_game_data_str():
	if multiplayer.is_server() and sync_json_data != "":
		rpc_id(multiplayer.get_remote_sender_id(), "sync_game_data_str", sync_json_data)

func end_game(winner, reason_text):
	game_over = true
	var GameOverScript = load("res://GameOverUI.gd")
	if GameOverScript:
		var ui = GameOverScript.new()
		if has_node("SoundManager"):
			if winner == "IMPOSTOR": get_node("SoundManager").play_sound("defeat", 0.0)
			else: get_node("SoundManager").play_sound("win", 0.0)
		ui.win_type = winner
		ui.reason = reason_text
		ui.name = "GameOverUI"
		ui.set_meta("is_player_impostor", player_role_is_impostor)
		get_tree().get_root().add_child(ui)

func _spawn_player(id: int):
	var player_scene = load("res://Player.tscn")
	if player_scene:
		var player = player_scene.instantiate()
		player.name = str(id)
		player.position = Vector3(randf_range(-2.5, 2.5), 2, randf_range(-40, -36))
		player.set_multiplayer_authority(id)
		
		if multiplayer.is_server() and sync_json_data != "":
			var data = JSON.parse_string(sync_json_data)
			if typeof(data) == TYPE_DICTIONARY:
				var game_seed = int(data["game_seed"])
				var impostor_ids = data["impostor_ids"]
				var p_name = str(id)
				var is_imp = impostor_ids.has(p_name)
				
				player.set("is_impostor", is_imp)
				player.set("sync_is_impostor", is_imp)
				
				var p_tasks = []
				if not is_imp:
					seed(game_seed + p_name.hash())
					var pool_tasks = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
					pool_tasks.shuffle()
					p_tasks = pool_tasks.slice(0, 7)
				
				player.set_meta("assigned_tasks", p_tasks)
				player.set("sync_task_string", JSON.stringify(p_tasks))
				
		get_node("Players").add_child(player, true)
		if multiplayer.is_server() and player.has_meta("assigned_tasks") and player.has_method("receive_tasks"):
			player.rpc_id(id, "receive_tasks", player.get_meta("assigned_tasks"))
	if multiplayer.is_server() and id != 1:
		rpc_id(id, "receive_full_state_rpc", completed_tasks, o2_active, global_sabotage_cooldown, o2_timer, o2_fixes_needed)

@rpc("any_peer", "call_local")
func receive_full_state_rpc(c_tasks: int, o2_act: bool, sab_cd: float, o2_t: float, o2_fixes: int):
	completed_tasks = c_tasks
	target_progress_val = float(completed_tasks) / float(total_tasks) * 100.0
	o2_active = o2_act
	global_sabotage_cooldown = sab_cd
	o2_timer = o2_t
	o2_fixes_needed = o2_fixes
	if o2_active:
		o2_label.visible = true
		for c in get_tree().get_nodes_in_group("sabotage_consoles"):
			if c.get("sabotage_type") == "O2":
				c.activate()

func _remove_player(id: int):
	if get_node("Players").has_node(str(id)):
		get_node("Players").get_node(str(id)).queue_free()
	if multiplayer.is_server():
		var players_left = 0
		for p in get_node("Players").get_children():
			if not p.is_queued_for_deletion() and not p.name.begins_with("Bot_") and p.name != str(id):
				players_left += 1
		if players_left == 0:
			get_tree().call_deferred("change_scene_to_file", "res://MainMenu.tscn")

@rpc("any_peer", "call_remote")
func leave_server_rpc():
	var id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		_remove_player(id)
		multiplayer.multiplayer_peer.disconnect_peer(id)

func _on_server_disconnected():
	get_tree().change_scene_to_file("res://MainMenu.tscn")

var _last_o2_alarm_second = -1
var _win_check_timer = 0.0

func _process(delta):
	if not multiplayer.is_server() and total_tasks == 0:
		if not has_meta("req_time") or Time.get_ticks_msec() - get_meta("req_time") > 1000:
			set_meta("req_time", Time.get_ticks_msec())
			rpc_id(1, "request_game_data_str")

	for m_name in monitor_timers:
		if monitor_timers[m_name] > 0:
			monitor_timers[m_name] -= delta
			if monitor_timers[m_name] <= 0:
				if is_instance_valid(monitor_lamps[m_name]):
					var mat = monitor_lamps[m_name].material as StandardMaterial3D
					mat.albedo_color = Color.RED
					mat.emission = Color.RED

	if is_instance_valid(global_progress):
		global_progress.value = lerp(global_progress.value, target_progress_val, delta * 3.0)
		
	_win_check_timer += delta
	if _win_check_timer >= 0.5:
		_win_check_timer = 0.0
		if multiplayer.is_server():
			check_win_conditions()
	
	if o2_active and not game_over:
		o2_timer -= delta
		o2_label.text = "FALHA DE O2: " + str(int(o2_timer)) + "s (" + str(2 - o2_fixes_needed) + "/2)"
		var current_second = int(o2_timer)
		if current_second != _last_o2_alarm_second:
			_last_o2_alarm_second = current_second
			if has_node("SoundManager"):
				get_node("SoundManager").play_sound("sabotage_alarm", -25.0)
		if o2_timer <= 0 and multiplayer.is_server():
			o2_active = false
			o2_label.text = "O IMPOSTOR VENCEU! (OXIGENIO ESGOTADO)"
			end_game("IMPOSTOR", "O Oxigenio acabou!")
				
	if global_sabotage_cooldown > 0:
		global_sabotage_cooldown -= delta

@rpc("authority", "call_local")
func rpc_flash_monitor(m_name: String):
	if monitor_lamps.has(m_name):
		var mat = monitor_lamps[m_name].material as StandardMaterial3D
		mat.albedo_color = Color.GREEN
		mat.emission = Color.GREEN
		monitor_timers[m_name] = 0.2

func _on_player_spawned(node: Node):
	await get_tree().process_frame
	var id = node.name.to_int()
	if lobby_player_data.has(id):
		var data = lobby_player_data[id]
		if node.has_method("rpc_init_visuals"):
			node.rpc_init_visuals(data["name"], data["color"].to_html(false))

@rpc("any_peer", "call_remote", "unreliable")
func receive_voice_packet(sender_id: int, pcm_data: PackedFloat32Array):
	if multiplayer.is_server():
		var sender_player = get_node_or_null("Players/" + str(sender_id))
		if not sender_player: return
		var is_meeting = false
		var voting = get_tree().get_root().find_child("VotingUI", true, false)
		if voting and voting.visible: is_meeting = true
		
		# --- AUDIO MONITORS LOGIC ---
		if pcm_data.size() > 0:
			var peak = 0.0
			for mono in pcm_data:
				if abs(mono) > peak:
					peak = abs(mono)
			
			# Imprime DEBUG de todo pacote que chega
			print("[DEBUG-VOICE] Pacote de voz recebido. Peak: ", peak, " is_meeting: ", is_meeting)
			
			if not is_meeting and peak > 0.0001: # Threshold bem menor
				var base_db = linear_to_db(peak)
				var monitors = {
					"Cafeteria": Vector3(0, 2.5, -30),
					"Corredor ADM": Vector3(3, 2.5, 0),
					"Storage": Vector3(0, 2.5, 20)
				}
				var space_state = get_world_3d().direct_space_state
				
				for monitor_name in monitors:
					var m_pos = monitors[monitor_name]
					var p_pos = sender_player.global_position
					var dist = p_pos.distance_to(m_pos)
					
					var dist_factor = max(dist, 1.0)
					var dist_db_loss = linear_to_db(1.0 / dist_factor)
					var final_db = base_db + dist_db_loss
					
					var from = p_pos + Vector3(0, 1.5, 0)
					var to = m_pos # A lâmpada já está no alto (Y=2.5)
					var query = PhysicsRayQueryParameters3D.create(from, to)
					var result = space_state.intersect_ray(query)
					if result and result.collider != sender_player:
						if not result.collider.is_in_group("players") and not result.collider.is_in_group("enemies"):
							final_db -= 12.0
							
					if final_db > -90.0:
						print("[AUDIO MONITOR - %s] Som detectado! Origem: %s | Intensidade: %.2f dB | Distância: %.1fm" % [monitor_name, sender_player.player_name, final_db, dist])
						rpc("rpc_flash_monitor", monitor_name)
		# -----------------------------
		
		for peer in multiplayer.get_peers():
			if peer != sender_id:
				sender_player.rpc_id(peer, "rpc_receive_voice", sender_id, pcm_data, is_meeting)

var astar: AStar3D

func _build_astar_grid():
	astar = AStar3D.new()
	var space_state = get_world_3d().direct_space_state
	var step = 1.5
	var start_x = -65.0
	var end_x = 85.0
	var start_z = -55.0
	var end_z = 65.0
	
	var point_id = 0
	var valid_points = {}
	
	var x = start_x
	while x <= end_x:
		var z = start_z
		while z <= end_z:
			var from = Vector3(x, 5.0, z)
			var to = Vector3(x, -5.0, z)
			var ray_query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(ray_query)
			if result:
				var hit_y = result.position.y
				if hit_y > -1.0 and hit_y < 1.0:
					var shape = CapsuleShape3D.new()
					shape.radius = 0.45
					shape.height = 1.5
					var shape_query = PhysicsShapeQueryParameters3D.new()
					shape_query.shape = shape
					shape_query.transform = Transform3D().translated(Vector3(x, hit_y + 1.1, z))
					var shape_results = space_state.intersect_shape(shape_query)
					if shape_results.size() == 0:
						astar.add_point(point_id, Vector3(x, hit_y, z))
						valid_points[str(x) + "," + str(z)] = point_id
						point_id += 1
			z += step
		x += step
	
	x = start_x
	while x <= end_x:
		var z = start_z
		while z <= end_z:
			var key = str(x) + "," + str(z)
			if valid_points.has(key):
				var id = valid_points[key]
				var neighbors = [
					str(x + step) + "," + str(z), str(x - step) + "," + str(z),
					str(x) + "," + str(z + step), str(x) + "," + str(z - step),
					str(x + step) + "," + str(z + step), str(x - step) + "," + str(z - step),
					str(x + step) + "," + str(z - step), str(x - step) + "," + str(z + step)
				]
				for n in neighbors:
					if valid_points.has(n):
						var n_id = valid_points[n]
						if not astar.are_points_connected(id, n_id):
							astar.connect_points(id, n_id, true)
			z += step
		x += step
	print("AStar Grid Construido com ", astar.get_point_count(), " pontos!")
	var f = FileAccess.open("user://astar_debug.txt", FileAccess.WRITE)
	f.store_string("AStar Points: " + str(astar.get_point_count()))
	f.close()
func get_astar_path_to(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	if not astar: return PackedVector3Array()
	var id_from = astar.get_closest_point(from_pos)
	var id_to = astar.get_closest_point(to_pos)
	if id_from == -1 or id_to == -1: return PackedVector3Array()
	return astar.get_point_path(id_from, id_to)

func _wait_and_build_grid():
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build_astar_grid()
