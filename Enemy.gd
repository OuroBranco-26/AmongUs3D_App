extends CharacterBody3D

@export var color_name: String = "Vermelho"
@export var base_color: Color = Color(1, 0, 0)

var raycast: RayCast3D
var nav_agent: NavigationAgent3D
var player_node: Node3D = null

var is_dead = false
var is_impostor = false
var kill_cooldown = 15.0
var state = "IDLE"
var idle_timer = 2.0 # Aguarda a compilaÃ§Ã£o do mapa
var model_node = null
var is_stabbing = false
var body_reported = false # Nova flag para evitar loops de reporte
var is_stunned = false

var footstep_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var current_path: PackedVector3Array = []
var current_path_idx: int = 0

func _ready():
	# Cria o RayCast3D dinamicamente (nÃ£o existe na cena quando spawnado pelo Main.gd)
	raycast = get_node_or_null("RayCast3D")
	if not raycast:
		raycast = RayCast3D.new()
		raycast.name = "RayCast3D"
		raycast.position.y = 1.0
		raycast.enabled = true
		add_child(raycast)
	
	# Procura o jogador local pelo ID do multiplayer
	var players_node = get_tree().get_root().get_node_or_null("Main/Players")
	if players_node:
		for p in players_node.get_children():
			if p.is_multiplayer_authority():
				player_node = p
				break
	if not player_node:
		player_node = get_tree().get_root().find_child("Player", true, false)
	
	# Adiciona IA de NavegaÃ§Ã£o Dinamicamente
	# Removido NavigationAgent3D, usaremos o AStar3D do Main.gd
	await get_tree().process_frame
	model_node = get_node_or_null("Model")
	if model_node:
		_force_animation_loop(model_node)
		_inject_animations(model_node)
	
	var name_label = Label3D.new()
	name_label.position = Vector3(0, 2.2, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 60
	name_label.outline_size = 15
	name_label.text = color_name
	name_label.modulate = base_color
	add_child(name_label)
	
	pass

func _process(delta):
	if player_node != null and raycast != null:
		# O RayCast sai do meio do inimigo e vai atÃ© o meio do jogador (y = 1)
		var target_pos = player_node.global_position
		target_pos.y += 1.0 
		
		# to_local converte a posiÃ§Ã£o global do jogador para a posiÃ§Ã£o relativa ao RayCast
		raycast.target_position = raycast.to_local(target_pos)
		raycast.force_raycast_update()
		
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider == player_node:
				visible = true
			else:
				# AtrÃ¡s da parede, fica totalmente invisÃ­vel (Fog of War)
				visible = false
		else:
			visible = true

func _find_local_player():
	var players_node = get_tree().get_root().get_node_or_null("Main/Players")
	if players_node:
		for p in players_node.get_children():
			if p.is_multiplayer_authority():
				return p
	return null

func _physics_process(delta):
	if is_dead: return
	if multiplayer.is_server():
		var voting = get_tree().get_root().find_child("VotingUI", true, false)
		if voting and voting.visible:
			velocity = Vector3.ZERO
			if not is_on_floor():
				velocity.y -= 9.8 * delta
			move_and_slide()
			return
		
		if is_impostor:
			kill_cooldown -= delta
			if kill_cooldown <= 0:
				if _try_kill_target():
					pass # Matou alguÃ©m
				else:
					# NÃ£o conseguiu matar â€” navega atÃ© o alvo mais prÃ³ximo
					kill_cooldown = 3.0 # Tenta de novo em 3s
					_hunt_nearest_target()
				
		if state == "WANDER" or state == "IDLE":
			if not is_impostor:
				_check_for_dead_bodies()
		
		if state == "IDLE":
			velocity = Vector3.ZERO
			move_and_slide()
			idle_timer -= delta
			if idle_timer <= 0:
				if _pick_random_target():
					state = "WANDER"
					print("[BOT DEBUGS] ", name, " went to WANDER. Path size: ", current_path.size())
		elif state == "WANDER":
			# Detecta se o bot travou (nÃ£o se moveu nos Ãºltimos 8s)
			_stuck_timer += delta
			if _stuck_timer >= 8.0:
				if global_position.distance_to(_last_position) < 1.0:
					# Travou! Escolhe novo destino
					print("[BOT DEBUGS] ", name, " is STUCK! Distance: ", global_position.distance_to(_last_position))
					state = "IDLE"
					idle_timer = 0.5
				_stuck_timer = 0.0
				_last_position = global_position
			
			if current_path_idx >= current_path.size():
				state = "IDLE"
				idle_timer = randf_range(2.0, 5.0)
			else:
				var current_location = global_position
				var next_location = current_path[current_path_idx]
				var direction = (next_location - current_location)
				direction.y = 0
				
				if direction.length() < 1.0:
					current_path_idx += 1
					if current_path_idx >= current_path.size():
						velocity = Vector3.ZERO
					else:
						# Continua iterando no proximo frame
						pass
				else:
					direction = direction.normalized()
					velocity = direction * 3.0
				
				if not is_on_floor():
					velocity.y -= 9.8 * delta
				
				print("[BOT DEBUGS] ", name, " pos: ", position, " vel: ", velocity, " next_idx: ", current_path_idx)
				
				if is_on_floor():
					footstep_timer -= delta
					if footstep_timer <= 0:
						footstep_timer = 0.55
						var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
						if sm: sm.play_3d_footstep(self, false)
				
				if direction and model_node:
					var target_rot = atan2(direction.x, direction.z)
					model_node.rotation.y = lerp_angle(model_node.rotation.y, target_rot, delta * 15.0)
				
				move_and_slide()
	else:
		# Cliente apenas gerencia som de passos
		if velocity.length() > 0.1:
			footstep_timer -= delta
			if footstep_timer <= 0:
				footstep_timer = 0.55
				var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
				if sm: sm.play_3d_footstep(self, false)
	
	if model_node:
		if not is_stabbing and state != "STUNNED":
			if velocity.length() > 0.1:
				_play_animation(model_node, "walk", 1.8)
			else:
				_play_animation(model_node, "idle", 1.0)
				var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
				if sm: sm.stop_3d_footsteps(self)

func _pick_random_target() -> bool:
	var rooms = [
		Vector3(0, 0, -32), # Cafeteria
		Vector3(0, 0, 16), # Storage
		Vector3(-25, 0, 16), # Electrical
		Vector3(-35, 0, -7), # Security
		Vector3(-25, 0, -16), # MedBay
		Vector3(-35, 0, -25), # Upper Engine
		Vector3(-35, 0, 20), # Lower Engine
		Vector3(15, 0, 2), # Admin
		Vector3(34, 0, -7), # O2
		Vector3(40, 0, -38), # Weapons
		Vector3(60, 0, -6), # Navigation
		Vector3(42, 0, 20), # Shields
		Vector3(24, 0, 36) # Communications
	]
	
	var chosen_room = rooms[randi() % rooms.size()]
	var random_offset = Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
	var target_pos = chosen_room + random_offset
	
	var main = get_tree().get_root().get_node_or_null("Main")
	if main and main.has_method("get_astar_path_to"):
		current_path = main.get_astar_path_to(global_position, target_pos)
		current_path_idx = 0
		if current_path.size() > 0:
			return true
	return false

func _try_kill_target() -> bool:
	var targets = []
	var player = _find_local_player()
	if player and not player.is_dead and not player.is_impostor:
		targets.append(player)
		
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e != self and not e.is_dead and not e.is_impostor:
			targets.append(e)
			
	for t in targets:
		if global_position.distance_to(t.global_position) < 2.5:
			kill_cooldown = 15.0 # Reseta
			is_stabbing = true
			
			# Cinematic Lock
			if "is_stunned" in t:
				t.is_stunned = true
			elif "state" in t:
				t.state = "STUNNED"
			t.velocity = Vector3.ZERO
			
			if model_node:
				var dir_to_target = (t.global_position - global_position).normalized()
				model_node.rotation.y = atan2(dir_to_target.x, dir_to_target.z)
			if t.model_node:
				var dir_to_self = (global_position - t.global_position).normalized()
				t.model_node.rotation.y = atan2(dir_to_self.x, dir_to_self.z)
				
			_disable_ik(model_node)
			_play_animation(model_node, "stab", 1.0)
			
			# Atrasa o som para bater junto com o impacto da animaÃ§Ã£o (0.4s)
			get_tree().create_timer(0.4).timeout.connect(func():
				var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
				if sm: sm.play_3d_sound("kill", self, 15.0, 25.0)
			)
			
			var ap = _get_ap(model_node)
			var s_len = 1.2
			if ap and ap.has_animation("custom/stab"):
				s_len = ap.get_animation("custom/stab").length
			get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(t) and t.has_method("die"): 
				if "rpc" in t:
					t.rpc("die")
				else:
					t.die()
			)
			get_tree().create_timer(s_len).timeout.connect(func():
				if is_instance_valid(self):
					is_stabbing = false
					_flee_from_crime_scene()
			)
			return true # Matou
	
	return false # NinguÃ©m perto

func _hunt_nearest_target():
	# Navega atÃ© o tripulante mais prÃ³ximo
	var closest: Node3D = null
	var min_dist = 999.0
	
	var player = _find_local_player()
	if player and not player.is_dead and not player.is_impostor:
		var d = global_position.distance_to(player.global_position)
		if d < min_dist:
			min_dist = d
			closest = player
	
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and not e.is_dead and not e.is_impostor:
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				closest = e
	
	if closest:
		nav_agent.target_position = closest.global_position
		state = "WANDER"

func _check_for_dead_bodies():
	if body_reported: return
	if get_tree().get_root().find_child("VotingUI", true, false): return
	var bodies = get_tree().get_nodes_in_group("dead_bodies")
			
	for b in bodies:
		if global_position.distance_to(b.global_position) < 4.5: # Visão de 4.5 metros
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), b.global_position + Vector3(0, 0.5, 0))
			query.exclude = [self.get_rid()]
			var result = space_state.intersect_ray(query)
			
			# Se a linha de visão não bateu em nada (parede) ou bateu muito perto do corpo
			if not result or (result.position.distance_to(b.global_position) < 1.0):
				body_reported = true
				state = "IDLE"
				velocity = Vector3.ZERO
				
				# Adiciona 1.5s de tempo de reação (susto) antes de apertar o botão
				get_tree().create_timer(1.5).timeout.connect(func():
					body_reported = false
					if is_dead or get_tree().get_root().find_child("VotingUI", true, false): return
					
					print("Bot " + color_name + " reportou um corpo com atraso!")
					var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
					if sm: sm.play_sound("report")
					
					var main_node = get_node_or_null("/root/Main")
					if main_node and main_node.has_method("start_meeting"):
						main_node.rpc("start_meeting")
				)
				break

func _flee_from_crime_scene():
	var vents = get_tree().get_nodes_in_group("vents")
	var closest_vent = null
	var min_v_dist = 6.0 # DistÃ¢ncia mÃ¡xima que o bot alcanÃ§a um duto
	for v in vents:
		var d = global_position.distance_to(v.global_position)
		if d < min_v_dist:
			closest_vent = v
			min_v_dist = d
			
	if closest_vent != null and closest_vent.connected_vents.size() > 0:
		print("Bot " + color_name + " usou o duto apÃ³s matar!")
		var target_id = closest_vent.connected_vents[randi() % closest_vent.connected_vents.size()]
		for v in vents:
			if v.vent_id == target_id:
				global_position = v.global_position
				break
				
	# Independente de usar duto ou nÃ£o, escolhe um novo lugar para ir bem rÃ¡pido
	state = "WANDER"
	_pick_random_target()

func _set_material_recursive(node, mat):
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_set_material_recursive(child, mat)

func _play_animation(node, anim_name, custom_speed = 1.0):
	if node is AnimationPlayer:
		var target = "custom/" + anim_name.to_lower()
		if not node.has_animation(target):
			target = ""
			for a in node.get_animation_list():
				if anim_name.to_lower() in a.to_lower():
					target = a
					break
		if target != "":
			node.active = true
			if node.current_animation != target:
				node.play(target)
			node.speed_scale = custom_speed
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
	
	var lib = AnimationLibrary.new()
	target_ap.add_animation_library("custom", lib)
	
	var root_n = target_ap.get_node(target_ap.root_node)
	var skel = _get_skeleton(root_n)
	var valid_path = ""
	if skel:
		valid_path = String(root_n.get_path_to(skel))
	
	var faint_scene = load("res://Faint.fbx")
	if not faint_scene: faint_scene = load("res://Faint.glb")
	if not faint_scene: faint_scene = load("res://Faint.dae")
	if faint_scene:
		var f_inst = faint_scene.instantiate()
		var f_ap = _get_ap(f_inst)
		if f_ap and f_ap.get_animation_list().size() > 0:
			var an_name = ""
			for a_name in f_ap.get_animation_list():
				if a_name != "RESET":
					an_name = a_name
					break
			if an_name == "": an_name = f_ap.get_animation_list()[0]
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

	for an_data in [["res://Idle", "idle", true], ["res://Walk", "walk", true], ["res://Run", "run", true]]:
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
						
						# ForÃ§a "In-Place" cancelando o deslocamento X e Z do quadril (Hips)
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

func _force_animation_loop(node):
	if node is AnimationPlayer:
		for anim_name in node.get_animation_list():
			var anim = node.get_animation(anim_name)
			if anim != null and "jump" not in anim_name.to_lower():
				anim.loop_mode = Animation.LOOP_LINEAR
		return
	for child in node.get_children():
		_force_animation_loop(child)

@rpc("any_peer", "call_local")
func die():
	if is_dead: return
	is_dead = true
	
	if model_node:
		var corpse = model_node.duplicate()
		corpse.add_to_group("dead_bodies")
		get_tree().get_root().add_child(corpse)
		corpse.global_position = global_position
		
		_play_animation(corpse, "faint", 1.0)
		var ap = _get_ap(corpse)
		if ap:
			var f_len = 1.0
			if ap.has_animation("custom/faint"):
				f_len = ap.get_animation("custom/faint").length
			get_tree().create_timer(f_len - 0.1).timeout.connect(func(): if is_instance_valid(ap): ap.speed_scale = 0.0)
		var dead_mat = StandardMaterial3D.new()
		dead_mat.albedo_color = Color(0.5, 0.5, 0.5)
		_set_material_recursive(corpse, dead_mat)
		
		# Oculta o modelo do bot que continua andando fantasma
		model_node.visible = false
	
	# Desabilita colisÃ£o para o jogador nÃ£o tropeÃ§ar no corpo
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
