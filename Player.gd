extends CharacterBody3D

@export var death_rotation = Vector3(-PI/2, 0, 0)

var camera_angle = 0.0
@export var WALK_SPEED = 3.0
@export var RUN_SPEED = 6.0
@export var CROUCH_SPEED = 1.5
@export var JUMP_VELOCITY = 5.0

@export var walk_anim_speed = 1.5 # Ajuste isso no Inspector se o pé deslizar!
@export var run_anim_speed = 1.2  # Ajuste isso no Inspector se o pé deslizar!

@export var sync_anim_name: String = "idle"
@export var sync_anim_speed: float = 1.0

var current_speed = WALK_SPEED

# Obtém a gravidade do projeto
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var spring_arm = $SpringArm3D

# Variável para controlar a animação de "andar"
var walk_time = 0.0
var model_node = null
var is_impostor = false
@export var sync_task_string: String = ""
var kill_cooldown = 0.0
var is_stabbing = false
var is_stunned = false # Trava o jogador antes de morrer
var is_in_vent = false
var is_dead = false
var is_ghost = false
var body_reported = false
var spectating_targets = []
var spectate_idx = 0
var role = "CREWMATE"

var footstep_timer: float = 0.0
var _last_sync_pos: Vector3 = Vector3.ZERO

var player_name: String = ""
var base_color: Color = Color.WHITE
var name_label: Label3D
var speaker_label: Label3D
var flashlight: OmniLight3D

var voice_player: AudioStreamPlayer3D
var voice_playback: AudioStreamGeneratorPlayback
var speaking_time_left: float = 0.0

func _enter_tree():
	# Configura autoridade de rede baseada no nome (o nome do node deve ser o ID do peer)
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready():
	add_to_group("players")
	
	# Cria a luz individual para quando acabar a luz da nave
	flashlight = OmniLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_energy = 0.0 # Apagada por padrão
	flashlight.omni_range = 3.0
	flashlight.position = Vector3(0, 1.5, 0)
	flashlight.shadow_enabled = true
	add_child(flashlight)
	
	# Adiciona o AudioStreamPlayer3D dinamicamente para voz!
	voice_player = AudioStreamPlayer3D.new()
	voice_player.name = "VoicePlayer"
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 11025
	voice_player.stream = generator
	voice_player.autoplay = true
	voice_player.unit_size = 2.0
	voice_player.max_distance = 15.0
	add_child(voice_player)
	voice_player.play()
	if get_parent().name != "root":
		get_tree().create_timer(0.1).timeout.connect(func(): voice_playback = voice_player.get_stream_playback())

	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# Define a posição inicial em volta da mesa da Cafeteria localmente (já que o cliente é a autoridade do movimento)
		position = Vector3(randf_range(-2.5, 2.5), 2.0, randf_range(-40, -36))
		var cam = get_node_or_null("SpringArm3D/Camera3D")
		if cam:
			cam.current = true
	else:
		# Se não sou eu, desativa a câmera e os raycasts
		if get_node_or_null("SpringArm3D/Camera3D"):
			get_node("SpringArm3D/Camera3D").current = false
			get_node("SpringArm3D/Camera3D").queue_free()
		if get_node_or_null("SpringArm3D"):
			get_node("SpringArm3D").queue_free()
	
	# Procura automaticamente qualquer nó 3D que seja o modelo visual
	for child in get_children():
		if child is Node3D and not child is CollisionShape3D and not child is SpringArm3D and not child is OmniLight3D:
			model_node = child
			break
			
	if model_node and is_multiplayer_authority():
		_disable_shadows(model_node)
			
	var nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	nav_agent.target_desired_distance = 0.5 # Para ele antes de colar no ponto
	add_child(nav_agent)
	
	# O FBX já tem as animações certinhas
	if model_node != null:
		_force_animation_loop(model_node)
	
	_inject_animations(model_node)
	
	name_label = Label3D.new()
	name_label.position = Vector3(0, 2.2, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 60
	name_label.outline_size = 15
	name_label.text = "Carregando..."
	add_child(name_label)
	
	speaker_label = Label3D.new()
	speaker_label.position = Vector3(0, 2.6, 0)
	speaker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speaker_label.font_size = 80
	speaker_label.outline_size = 15
	speaker_label.text = "🔊"
	speaker_label.modulate = Color(0, 1, 0, 1) # Verde para indicar que tá falando
	speaker_label.visible = false
	add_child(speaker_label)
	
@rpc("any_peer", "call_local")
func rpc_init_visuals(p_name: String, hex_color: String):
	player_name = p_name
	base_color = Color(hex_color)
	if is_instance_valid(name_label):
		name_label.text = p_name
		name_label.modulate = base_color
	
	if model_node:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = base_color
		_set_material_recursive(model_node, mat)

@rpc("any_peer", "call_remote")
func receive_tasks(tasks: Array):
	var int_arr = []
	for x in tasks: int_arr.append(int(x))
	set_meta("assigned_tasks", int_arr)

@rpc("any_peer", "call_remote")
func request_my_tasks():
	if multiplayer.is_server() and has_meta("assigned_tasks"):
		rpc_id(multiplayer.get_remote_sender_id(), "receive_tasks", get_meta("assigned_tasks"))

var last_task_request = 0

func _process(delta):
	if not multiplayer.is_server() and name == str(multiplayer.get_unique_id()):
		if not has_meta("assigned_tasks"):
			var time_now = Time.get_ticks_msec()
			if time_now - last_task_request > 1000:
				last_task_request = time_now
				var main_node = get_tree().get_root().get_node_or_null("Main")
				if main_node:
					main_node.rpc_id(1, "request_tasks_from_main")
				
	if sync_task_string != "" and not has_meta("assigned_tasks"):
		var arr = JSON.parse_string(sync_task_string)
		if typeof(arr) == TYPE_ARRAY:
			var int_arr = []
			for x in arr: int_arr.append(int(x))
			set_meta("assigned_tasks", int_arr)
		if is_impostor:
			role = "IMPOSTOR"
		else:
			role = "CREWMATE"

func _input(event):
	if not is_multiplayer_authority(): return
	# Clique Esquerdo para recapturar o mouse — _input roda ANTES de qualquer UI
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var root = get_tree().get_root()
		var voting = root.find_child("VotingUI", true, false)
		if not root.has_node("TaskUI") and not root.has_node("SabotageUI") and not root.has_node("VentUI") and (not voting or not voting.visible):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Tecla Q para Matar (ui_kill)
	if event.is_action_pressed("ui_kill"):
		var voting = get_tree().get_root().find_child("VotingUI", true, false)
		if voting and voting.visible: return
		if is_impostor and kill_cooldown <= 0.0:
			var enemies = get_tree().get_nodes_in_group("enemies")
			var players = get_tree().get_nodes_in_group("players")
			var all_targets = enemies + players
			var closest_enemy = null
			var min_dist = 3.0
			for e in all_targets:
				if e == self: continue
				if not e.is_dead and not e.get("is_impostor"):
					var dist = global_position.distance_to(e.global_position)
					if dist < min_dist:
						closest_enemy = e
						min_dist = dist
			if closest_enemy != null:
				kill_cooldown = 15.0 # Segundos
				is_stabbing = true
				
				# Cinematic Lock
				if "state" in closest_enemy: closest_enemy.state = "STUNNED"
				if "is_stunned" in closest_enemy: closest_enemy.is_stunned = true
				closest_enemy.velocity = Vector3.ZERO
				
				if model_node:
					var dir_to_enemy = (closest_enemy.global_position - global_position).normalized()
					model_node.rotation.y = atan2(dir_to_enemy.x, dir_to_enemy.z)
				if closest_enemy.model_node:
					var dir_to_player = (global_position - closest_enemy.global_position).normalized()
					closest_enemy.model_node.rotation.y = atan2(dir_to_player.x, dir_to_player.z)
				
				_disable_ik(model_node)
				_play_animation(model_node, "stab", 1.0)
				
				# Toca o som de facada Global para o Jogador quando ELE matar alguém
				get_tree().create_timer(0.4).timeout.connect(func():
					var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
					if sm: sm.play_sound("kill", 12.0)
				)
				
				var ap = _get_ap(model_node)
				var s_len = 1.2
				if ap and ap.has_animation("custom/stab"):
					s_len = ap.get_animation("custom/stab").length
				get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(closest_enemy) and closest_enemy.has_method("die"): 
					if "rpc" in closest_enemy:
						closest_enemy.rpc("die")
					else:
						closest_enemy.die()
				)
				get_tree().create_timer(s_len).timeout.connect(func(): if is_instance_valid(self): is_stabbing = false)
			else:
				print("Longe demais para matar!")

	if event.is_action_pressed("ui_report"):
		var bodies = get_tree().get_nodes_in_group("dead_bodies")
		var found_body = false
		for b in bodies:
			if global_position.distance_to(b.global_position) < 5.0:
				found_body = true
				break
		
		if found_body:
			print("Corpo reportado!")
					
			var voting = get_tree().get_root().find_child("VotingUI", true, false)
			if not voting or not voting.visible:
					var main_node = get_node_or_null("/root/Main")
					if main_node and main_node.has_method("start_meeting"):
						main_node.rpc("start_meeting")
		else:
			print("Nenhum corpo próximo para reportar.")

	# Tecla M para Sabotagem (ui_sabotage)
	if event.is_action_pressed("ui_sabotage") and is_impostor and not is_in_vent:
		var main_node = get_node_or_null("/root/Main")
		if main_node and main_node.global_sabotage_cooldown > 0:
			print("Sabotagem em recarga!")
			return
		
		var voting = get_tree().get_root().find_child("VotingUI", true, false)
		if not get_tree().get_root().has_node("SabotageUI") and (not voting or not voting.visible):
			var sab_ui = load("res://SabotageUI.gd").new()
			sab_ui.name = "SabotageUI"
			get_tree().get_root().add_child(sab_ui)

	# Tecla F ou E para Duto (ui_vent ou ui_interact)
	if (event.is_action_pressed("ui_vent") or event.is_action_pressed("ui_interact")) and is_impostor:
		if not is_in_vent:
			# Tenta entrar num duto
			var vents = get_tree().get_nodes_in_group("vents")
			var closest_vent = null
			for v in vents:
				if global_position.distance_to(v.global_position) < 2.5:
					closest_vent = v
					break
			
			if closest_vent != null:
				is_in_vent = true
				if model_node: model_node.visible = false
				if name_label: name_label.visible = false
				if speaker_label: speaker_label.visible = false
				$CollisionShape3D.disabled = true
				# Abre UI de Vent
				if not get_tree().get_root().has_node("VentUI"):
					var vent_ui = load("res://VentUI.gd").new()
					vent_ui.name = "VentUI"
					vent_ui.set_meta("current_vent", closest_vent)
					vent_ui.set_meta("player", self)
					get_tree().get_root().add_child(vent_ui)
		else:
			# Sair do duto
			is_in_vent = false
			if model_node: model_node.visible = true
			if name_label: name_label.visible = true
			if speaker_label and speaking_time_left > 0: speaker_label.visible = true
			$CollisionShape3D.disabled = false
			# Fecha UI se estiver aberta
			var vent_ui = get_tree().get_root().find_child("VentUI", true, false)
			if vent_ui: vent_ui.queue_free()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_ghost:
			_cycle_spectate()
			
	if event is InputEventMouseMotion:
		var can_rotate = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		
		# Permite virar a câmera com o botão direito enquanto vota (mouse solto)
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var voting = get_tree().get_root().find_child("VotingUI", true, false)
			if voting and voting.visible:
				can_rotate = true
				
		if get_tree().get_root().has_node("TaskUI") or get_tree().get_root().has_node("SabotageUI") or get_tree().get_root().has_node("VentUI"):
			can_rotate = false
			
		if can_rotate:
			spring_arm.rotation.y -= event.relative.x * 0.005
			spring_arm.rotation.x -= event.relative.y * 0.005
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/3, PI/4)
			
	if event is InputEventScreenDrag:
		var can_rotate = true
		if get_tree().get_root().has_node("TaskUI") or get_tree().get_root().has_node("SabotageUI") or get_tree().get_root().has_node("VentUI"):
			can_rotate = false
			
		var half_width = get_viewport().get_visible_rect().size.x / 2.0
		if can_rotate and event.position.x > half_width:
			spring_arm.rotation.y -= event.relative.x * 0.005
			spring_arm.rotation.x -= event.relative.y * 0.005
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/3, PI/4)

func _cycle_spectate():
	spectating_targets = []
	var enemies = get_tree().get_nodes_in_group("enemies")
	var players_group = get_tree().get_nodes_in_group("players")
	var all_targets = enemies + players_group
	for e in all_targets:
		if e == self: continue
		if not e.is_dead:
			spectating_targets.append(e)
	if spectating_targets.size() > 0:
		spectate_idx = (spectate_idx + 1) % spectating_targets.size()

func _set_material_recursive(node, mat):
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_set_material_recursive(child, mat)

@rpc("any_peer", "call_local")
func die():
	if is_dead: return
	is_dead = true
	
	# Spawn Corpse (Clona o próprio modelo)
	if model_node:
		var corpse = model_node.duplicate()
		corpse.add_to_group("dead_bodies")
		get_tree().get_root().add_child(corpse)
		corpse.global_position = global_position
		_play_animation(corpse, "faint", 1.0)
		var ap = _get_ap(corpse)
		if ap:
			var f_len = 1.0
			if ap.has_animation("custom/faint"): f_len = ap.get_animation("custom/faint").length
			get_tree().create_timer(f_len - 0.1).timeout.connect(func(): if is_instance_valid(ap): ap.speed_scale = 0.0)
		var dead_mat = StandardMaterial3D.new()
		dead_mat.albedo_color = Color(0.5, 0.5, 0.5)
		_set_material_recursive(corpse, dead_mat)
	
	# Transforma o player original em câmera espectadora (Fantasma)
	is_ghost = true
	if model_node: model_node.visible = false
	$CollisionShape3D.disabled = true
	_cycle_spectate()
	
@rpc("any_peer", "call_local")
func eject():
	if is_dead: return
	is_dead = true
	is_ghost = true
	if model_node: model_node.visible = false
	$CollisionShape3D.disabled = true
	_cycle_spectate()

func _physics_process(delta):
	if speaking_time_left > 0:
		speaking_time_left -= delta
		if is_instance_valid(speaker_label) and not is_in_vent and not is_dead:
			speaker_label.visible = true
	else:
		if is_instance_valid(speaker_label):
			speaker_label.visible = false
			
	if not is_multiplayer_authority():
		if model_node: model_node.visible = not (is_dead or is_in_vent)
		if name_label: name_label.visible = not (is_dead or is_in_vent)
		if is_in_vent or is_dead:
			if is_instance_valid(speaker_label):
				speaker_label.visible = false
				
		# Se não sou eu, apenas continuo processando a animação com base no sync
		if model_node:
			if is_stabbing:
				_play_animation(model_node, "stab", 1.0)
			elif is_dead:
				pass
			else:
				_play_animation(model_node, sync_anim_name, sync_anim_speed)
		return

	if is_ghost:
		if spectating_targets.size() > 0 and spectate_idx < spectating_targets.size():
			var target = spectating_targets[spectate_idx]
			if is_instance_valid(target) and not target.is_dead:
				global_position = lerp(global_position, target.global_position, delta * 10.0)
			else:
				_cycle_spectate()
		return

	if is_in_vent or is_dead:
		velocity = Vector3.ZERO
		return
		
	var voting = get_tree().get_root().find_child("VotingUI", true, false)
	if voting and voting.visible:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var hud = get_tree().get_root().find_child("PlayerHUD", true, false)
	
	if (Input.is_key_pressed(KEY_SPACE) or (hud and hud.get("jump_pressed"))) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var is_crouching = false
	var is_sprinting = false
	# Permite agachar/correr mesmo com mouse solto (ex: ao focar a janela)
	var no_blocking_ui = true
	var voting_check = get_tree().get_root().find_child("VotingUI", true, false)
	if voting_check and voting_check.visible:
		no_blocking_ui = false
	if get_tree().get_root().has_node("TaskUI") or get_tree().get_root().has_node("SabotageUI"):
		no_blocking_ui = false
	if no_blocking_ui:
		is_crouching = Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL) or (hud and hud.get("crouch_pressed"))
		is_sprinting = Input.is_key_pressed(KEY_SHIFT)

	if kill_cooldown > 0:
		kill_cooldown -= delta

	var input_dir = Vector2.ZERO
	if no_blocking_ui and not is_stabbing and not is_stunned:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# Suporte ao Joystick Virtual Mobile
		if hud and "joystick" in hud and hud.joystick:
			var joy_vec = hud.joystick.get_vector()
			if joy_vec.length() > 0.05:
				input_dir = joy_vec
				if joy_vec.length() > 0.9: # Corre se puxar tudo
					is_sprinting = true

	if is_crouching:
		current_speed = CROUCH_SPEED
		# Abaixa a colisão
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 1.0, delta * 10.0)
		$CollisionShape3D.position.y = lerp($CollisionShape3D.position.y, 0.5, delta * 10.0)
	else:
		if is_sprinting:
			current_speed = RUN_SPEED
		else:
			current_speed = WALK_SPEED
		# Restaura a colisão
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 2.0, delta * 10.0)
		$CollisionShape3D.position.y = lerp($CollisionShape3D.position.y, 1.0, delta * 10.0)
	
	var direction = (spring_arm.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0
	direction = direction.normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		# Som de passos temporizado com precisão real (sem sobreposição)
		if is_on_floor():
			footstep_timer -= delta
			if footstep_timer <= 0:
				footstep_timer = 0.35 if is_sprinting else 0.55
				var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
				if sm: sm.play_3d_footstep(self, is_sprinting)
		
		# Virar o boneco para a direção do movimento (Corrigido para não andar de costas)
		if model_node != null:
			var target_rotation = atan2(direction.x, direction.z)
			model_node.global_rotation.y = lerp_angle(model_node.global_rotation.y, target_rotation, delta * 15.0)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		
		# Corta o áudio imediatamente ao parar de andar
		var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
		if sm: sm.stop_3d_footsteps(self)
		
	# Agachamento Visual (Amasar o modelo já que não tem animação)
	if model_node != null:
		if is_crouching:
			model_node.scale.y = lerp(model_node.scale.y, 0.6, delta * 15.0)
		else:
			model_node.scale.y = lerp(model_node.scale.y, 1.0, delta * 15.0)

	# Decidir a animação correta baseada nos nomes REAIS do GodotRobot
	var anim_to_play = "Idle"
	var anim_speed = 1.0
	
	var debug_str = "Anim: " + anim_to_play + " | is_sprinting: " + str(is_sprinting) + " | speed: " + str(current_speed)
	
	if not is_on_floor():
		anim_to_play = "jump"
	else:
		if direction:
			if is_sprinting:
				anim_to_play = "run"
				anim_speed = run_anim_speed
			elif is_crouching:
				anim_to_play = "crouch"
			else:
				anim_to_play = "walk"
				anim_speed = walk_anim_speed
		else:
			if is_crouching:
				anim_to_play = "crouch"
			else:
				anim_to_play = "Idle"
				
	if not is_stabbing:
		_play_animation(self, anim_to_play, anim_speed)
		sync_anim_name = anim_to_play
		sync_anim_speed = anim_speed

	if model_node:
		if sync_anim_name == "crouch":
			model_node.scale.y = lerp(model_node.scale.y, 0.6, delta * 15.0)
		else:
			model_node.scale.y = lerp(model_node.scale.y, 1.0, delta * 15.0)
	
	# Atualiza o HUD
	if hud:
		var can_use = false
		for c in get_tree().get_nodes_in_group("consoles"):
			if position.distance_to(c.position) < 3.0 and not c.task_completed:
				can_use = true
				break
		if not can_use:
			for v in get_tree().get_nodes_in_group("vents"):
				if position.distance_to(v.position) < 2.5:
					can_use = true
					break
		if not can_use:
			for s in get_tree().get_nodes_in_group("sabotage_consoles"):
				if position.distance_to(s.position) < 3.0 and s.is_active:
					can_use = true
					break
					
		var can_report = false
		for b in get_tree().get_nodes_in_group("dead_bodies"):
			if global_position.distance_to(b.global_position) < 5.0:
				can_report = true
				break
		var can_kill = (is_impostor and kill_cooldown <= 0.0)
		
		# O Impostor pode sempre abrir a sabotagem (tecla M), exceto no duto.
		var main_node = get_node_or_null("/root/Main")
		var sab_ready = main_node and main_node.global_sabotage_cooldown <= 0.0
		var can_sabotage = is_impostor and not is_in_vent and sab_ready
		hud.update_buttons(can_use, can_report, can_kill, can_sabotage)
		
	move_and_slide()

func _play_animation(node, anim_name, custom_speed = 1.0):
	if node is AnimationPlayer:
		var target = "custom/" + anim_name.to_lower()
		if not node.has_animation(target):
			target = ""
			for a in node.get_animation_list():
				if anim_name.to_lower() in a.to_lower():
					target = a
					break
					
		if Input.is_key_pressed(KEY_P):
			print("--- DEBUG DA ANIMAÇÃO ---")
			print("Target: " + target)
			print("Current: " + node.current_animation)
			print("Len: " + str(node.current_animation_length))
			print("Speed: " + str(node.speed_scale))
			print("-------------------------")
			
		if target != "":
			node.active = true
			if node.current_animation != target:
				node.play(target)
				if "jump" in target:
					# Pula o agachamento inicial da animação de salto para sincronizar com a física
					node.seek(0.5, true)
			node.speed_scale = custom_speed
		else:
			node.active = false
			node.stop()
			
		return
	for child in node.get_children():
		_play_animation(child, anim_name, custom_speed)



func _disable_ik(node):
	if node is SkeletonIK3D:
		node.stop()
		node.process_mode = Node.PROCESS_MODE_DISABLED
	elif node is SkeletonModifier3D and "active" in node:
		node.active = false
	for c in node.get_children():
		_disable_ik(c)

func _get_ap(n):
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var res = _get_ap(c)
		if res: return res
	return null

func _get_skeleton(n):
	if n is Skeleton3D: return n
	for c in n.get_children():
		var res = _get_skeleton(c)
		if res: return res
	return null

func _inject_animations(node):
	var target_ap = _get_ap(node)
	if not target_ap: return
	
	var f_log = FileAccess.open("user://anim_log.txt", FileAccess.WRITE)
	f_log.store_line("Starting anim inject...")
	
	var lib = AnimationLibrary.new()
	target_ap.add_animation_library("custom", lib)
	
	var root_n = target_ap.get_node(target_ap.root_node)
	var skel = _get_skeleton(root_n)
	var valid_path = ""
	if skel:
		valid_path = String(root_n.get_path_to(skel))
	f_log.store_line("Valid Path is: " + valid_path)
	if skel:
		var b_log = FileAccess.open("user://skel_bones.txt", FileAccess.WRITE)
		for i in range(skel.get_bone_count()):
			b_log.store_line("Bone: " + skel.get_bone_name(i))
		
	var faint_scene = load("res://Faint.fbx")
	if not faint_scene: faint_scene = load("res://Faint.glb")
	if not faint_scene: faint_scene = load("res://Faint.dae")
	if faint_scene:
		f_log.store_line("Faint.dae loaded.")
		var f_inst = faint_scene.instantiate()
		var f_ap = _get_ap(f_inst)
		if f_ap and f_ap.get_animation_list().size() > 0:
			var an_name = ""
			for a_name in f_ap.get_animation_list():
				if a_name != "RESET":
					an_name = a_name
					break
			if an_name == "": an_name = f_ap.get_animation_list()[0]
			
			f_log.store_line("Faint anim found: " + str(an_name))
			var source_anim = f_ap.get_animation(an_name).duplicate()
			for i in range(source_anim.get_track_count()):
				var old_p = String(source_anim.track_get_path(i))
				if ":" in old_p:
					var parts = old_p.split(":")
					var raw_bone = parts[1]
					var clean_bone = raw_bone.replace("mixamorig_", "").replace("mixamorig:", "")
					var final_bone = raw_bone
					if skel:
						if skel.find_bone("mixamorig_" + clean_bone) != -1:
							final_bone = "mixamorig_" + clean_bone
						elif skel.find_bone(clean_bone) != -1:
							final_bone = clean_bone
					if valid_path != "":
						var new_path = valid_path + ":" + final_bone
						for j in range(2, parts.size()):
							new_path += ":" + parts[j]
						source_anim.track_set_path(i, NodePath(new_path))
			lib.add_animation("faint", source_anim)
			var anim = lib.get_animation("faint")
			anim.loop_mode = Animation.LOOP_NONE
		else:
			f_log.store_line("Faint AP is null or empty")
	else:
		f_log.store_line("Faint.dae failed to load.")
	
	var stab_scene = load("res://Stab.fbx")
	if not stab_scene: stab_scene = load("res://Stab.glb")
	if not stab_scene: stab_scene = load("res://Stab.dae")
	if stab_scene:
		var s_inst = stab_scene.instantiate()
		var s_ap = _get_ap(s_inst)
		if s_ap and s_ap.get_animation_list().size() > 0:
			var an_name = ""
			for a_name in s_ap.get_animation_list():
				if a_name != "RESET":
					an_name = a_name
					break
			if an_name == "": an_name = s_ap.get_animation_list()[0]
			var source_anim = s_ap.get_animation(an_name).duplicate()
			for i in range(source_anim.get_track_count()):
				var old_p = String(source_anim.track_get_path(i))
				if ":" in old_p:
					var parts = old_p.split(":")
					var raw_bone = parts[1]
					var clean_bone = raw_bone.replace("mixamorig_", "").replace("mixamorig:", "")
					var final_bone = raw_bone
					if skel:
						if skel.find_bone("mixamorig_" + clean_bone) != -1:
							final_bone = "mixamorig_" + clean_bone
						elif skel.find_bone(clean_bone) != -1:
							final_bone = clean_bone
					if valid_path != "":
						var new_path = valid_path + ":" + final_bone
						for j in range(2, parts.size()):
							new_path += ":" + parts[j]
						source_anim.track_set_path(i, NodePath(new_path))
			lib.add_animation("stab", source_anim)
			var anim = lib.get_animation("stab")
			anim.loop_mode = Animation.LOOP_NONE

	for an_data in [["res://Idle", "idle", true], ["res://Walk", "walk", true], ["res://Run", "run", true], ["res://Jumping", "jump", false]]:
		var d_scene = load(an_data[0] + ".fbx")
		if not d_scene: d_scene = load(an_data[0] + ".glb")
		if not d_scene: d_scene = load(an_data[0] + ".dae")
		if d_scene:
			var d_inst = d_scene.instantiate()
			var d_ap = _get_ap(d_inst)
			if d_ap and d_ap.get_animation_list().size() > 0:
				var an_name = ""
				for a_name in d_ap.get_animation_list():
					if a_name != "RESET":
						an_name = a_name
						break
				if an_name == "": an_name = d_ap.get_animation_list()[0]
				var src = d_ap.get_animation(an_name).duplicate()
				for i in range(src.get_track_count()):
					var old_p = String(src.track_get_path(i))
					if ":" in old_p:
						var parts = old_p.split(":")
						var raw_bone = parts[1]
						var clean_bone = raw_bone.replace("mixamorig_", "").replace("mixamorig:", "")
						var final_bone = raw_bone
						
						# Força "In-Place" cancelando o deslocamento X e Z do quadril (Hips)
						if "Hips" in clean_bone and src.track_get_type(i) == Animation.TYPE_POSITION_3D:
							if src.track_get_key_count(i) > 0:
								for k in range(src.track_get_key_count(i)):
									var val = src.track_get_key_value(i, k)
									val.x = 0.0
									val.z = 0.0
									src.track_set_key_value(i, k, val)

						if skel:
							if skel.find_bone("mixamorig_" + clean_bone) != -1:
								final_bone = "mixamorig_" + clean_bone
							elif skel.find_bone(clean_bone) != -1:
								final_bone = clean_bone
						if valid_path != "":
							var new_path = valid_path + ":" + final_bone
							for j in range(2, parts.size()):
								new_path += ":" + parts[j]
							src.track_set_path(i, NodePath(new_path))
				lib.add_animation(an_data[1], src)
				var a = lib.get_animation(an_data[1])
				a.loop_mode = Animation.LOOP_LINEAR if an_data[2] else Animation.LOOP_NONE
	
	target_ap.clear_caches()
	
	f_log.store_line("Final Target AP Anims: " + str(target_ap.get_animation_list()))
	if target_ap.has_animation("custom/walk"):
		var w_anim = target_ap.get_animation("custom/walk")
		f_log.store_line("Walk track count: " + str(w_anim.get_track_count()))
		for i in range(min(5, w_anim.get_track_count())):
			f_log.store_line("Walk track " + str(i) + ": " + String(w_anim.track_get_path(i)))
	f_log.close()

func _force_animation_loop(node):
	if node is AnimationPlayer:
		for anim_name in node.get_animation_list():
			var anim = node.get_animation(anim_name)
			# Repete tudo menos o pulo
			if anim != null and "jump" not in anim_name.to_lower():
				anim.loop_mode = Animation.LOOP_LINEAR
		return
	for child in node.get_children():
		_force_animation_loop(child)

@rpc("any_peer", "call_remote", "unreliable")
func rpc_receive_voice(sender_id: int, pcm_data: PackedFloat32Array, is_meeting: bool):
	if not voice_playback:
		return

	if not has_node("VoiceStream"):
		var player = AudioStreamPlayer3D.new()
		player.name = "VoiceStream"
		player.unit_size = 5.0
		player.max_distance = 15.0
		player.bus = "Voice"
		add_child(player)
	
	var main_node = get_tree().get_root().find_child("Main", true, false)
	var my_player = null
	if main_node:
		my_player = main_node.get_node_or_null("Players/" + str(multiplayer.get_unique_id()))
	
	if my_player:
		if my_player.is_ghost and not is_ghost:
			pass # Vivo falando, morto ouvindo. OK!
		if not my_player.is_ghost and is_ghost:
			return # Morto falando, vivo tentando ouvir. BLOQUEIA!

	# Ativa indicador visual de voz por 200ms
	speaking_time_left = 0.2

	if is_meeting:
		voice_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice_player.volume_db = 0.0
	else:
		voice_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		voice_player.volume_db = 0.0
		# RayCast Occlusion (som abafado se houver parede)
		if my_player:
			var space_state = get_world_3d().direct_space_state
			var from = my_player.global_position + Vector3(0, 1.5, 0)
			var to = global_position + Vector3(0, 1.5, 0)
			var query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(query)
			if result and result.collider != self and result.collider != my_player:
				if not result.collider.is_in_group("players") and not result.collider.is_in_group("enemies"):
					voice_player.volume_db = -12.0 # Reduz volume e abafa

	var frames = PackedVector2Array()
	for mono_sample in pcm_data:
		frames.append(Vector2(mono_sample, mono_sample))
	voice_playback.push_buffer(frames)


func _disable_shadows(node):
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)
