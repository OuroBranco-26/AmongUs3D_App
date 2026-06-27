extends StaticBody3D

@export var task_type = 0 # 0=Download, 1=Fios, 2=Cartão, 3=Asteroides
var player_in_range = false
var task_completed = false
var _cached_player: Node = null # PERF-04: Cache do Player

func _ready():
	# Mudar a cor dependendo da tarefa
	var mat = StandardMaterial3D.new()
	if task_type == 0:
		mat.albedo_color = Color(1, 1, 0) # Amarelo (Download)
	elif task_type == 1:
		mat.albedo_color = Color(0, 0, 1) # Azul (Fios)
	elif task_type == 2:
		mat.albedo_color = Color(1, 0, 1) # Roxo (Cartão)
	elif task_type == 3:
		mat.albedo_color = Color(1, 0.5, 0) # Laranja (Asteroides)
	elif task_type == 4:
		mat.albedo_color = Color(0, 1, 1) # Ciano (Teclado)
	elif task_type == 5:
		mat.albedo_color = Color(0.5, 0, 0.5) # Roxo Escuro (Sequência)
	elif task_type == 6 or task_type == 12:
		mat.albedo_color = Color(0.5, 1, 0) # Verde Limão (Motor)
	elif task_type == 7:
		mat.albedo_color = Color(1, 1, 1) # Branco (Energia)
	elif task_type == 8:
		mat.albedo_color = Color(0.5, 0.3, 0.1) # Marrom (Lixo)
	elif task_type == 9:
		mat.albedo_color = Color(1, 0, 0.5) # Rosa (Navegação)
	elif task_type == 10:
		mat.albedo_color = Color(0.6, 0.8, 1) # Azul Claro (Oxigênio)
	elif task_type == 11:
		mat.albedo_color = Color(1, 0.2, 0.2) # Vermelho Claro (Escudos)
		
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	$MeshInstance3D.set_surface_override_material(0, mat)

	var area = $Area3D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	add_to_group("consoles")
	
	# O ícone é criado oculto e só aparece se a task for atribuída
	var map_icon = Label3D.new()
	map_icon.name = "MapIcon"
	map_icon.text = "!"
	map_icon.font_size = 600 # 50% menor
	map_icon.outline_size = 40
	map_icon.modulate = Color.YELLOW
	map_icon.outline_modulate = Color.BLACK
	map_icon.rotation_degrees.x = -90
	map_icon.position.y = 5.0
	map_icon.layers = 2 # Apenas a câmera do radar consegue enxergar
	map_icon.no_depth_test = true
	map_icon.visible = false # Inicia invisível
	
	# Fundo de Círculo Azul com Borda Neon
	var bg_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.5, 2.5) # Tamanho do quadrado
	bg_mesh.mesh = quad
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.65, 0.7, 0.85, 1.0])
	grad.colors = PackedColorArray([
		Color(0.05, 0.15, 0.3, 0.85), # Círculo interior Azul Escuro Translúcido
		Color(0.05, 0.15, 0.3, 0.85), # Limite do círculo interior
		Color(0.0, 0.8, 1.0, 1.0),    # Anel (Contorno) Neon Ciano Forte
		Color(0.0, 0.5, 1.0, 0.4),    # Glow vazando para fora do anel
		Color(0.0, 0.0, 0.0, 0.0)     # Borda totalmente transparente
	])
	
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.9, 0.5)
	tex.width = 128
	tex.height = 128
	
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_texture = tex
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mesh.material_override = bg_mat
	bg_mesh.position.z = -0.1 # Fica atrás do texto
	bg_mesh.layers = 2
	map_icon.add_child(bg_mesh)
	
	add_child(map_icon)
		
func refresh_task_status():
	if task_completed:
		if has_node("MapIcon"): get_node("MapIcon").visible = false
		return
		
	var player = get_tree().get_root().get_node_or_null("Main/Players/" + str(multiplayer.get_unique_id()))
	if player and player.has_meta("assigned_tasks"):
		var assigned = player.get_meta("assigned_tasks")
		var has_t = false
		for t in assigned:
			if int(t) == task_type:
				has_t = true
				break
		if has_t:
			if has_node("MapIcon"): get_node("MapIcon").visible = true
		else:
			if has_node("MapIcon"): get_node("MapIcon").visible = false
	else:
		if has_node("MapIcon"): get_node("MapIcon").visible = false

func _process(delta):
	if has_node("MapIcon") and get_node("MapIcon").visible:
		var map_icon = get_node("MapIcon")
		# PERF-04: Usa cache do player em vez de buscar todo frame
		if not is_instance_valid(_cached_player):
			if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
				return
			_cached_player = get_tree().get_root().get_node_or_null("Main/Players/" + str(multiplayer.get_unique_id()))
		if _cached_player:
			# A posição real do Console no mundo
			var target_pos = global_position
			target_pos.y = 5.0
			
			# Diferença entre a Tarefa e o Jogador
			var diff = target_pos - _cached_player.global_position
			
			# O minimapa tem câmera.size = 30 (vai de -15 a +15). Vamos prender no limite de 13 para não sumir da tela
			var limit = 13.0
			
			if abs(diff.x) > limit or abs(diff.z) > limit:
				# Prende o ícone na borda quadrada do radar (Bússola)
				var max_comp = max(abs(diff.x), abs(diff.z))
				var scale = limit / max_comp
				diff *= scale
			
			# Move o ícone fisicamente para ficar sempre em volta do jogador
			map_icon.global_position = _cached_player.global_position + diff
			map_icon.global_position.y = 5.0

func _on_body_entered(body):
	if body.name == str(multiplayer.get_unique_id()):
		player_in_range = true
		print("Player perto. Pressione E para a tarefa!")

func _on_body_exited(body):
	if body.name == str(multiplayer.get_unique_id()):
		player_in_range = false

func mark_completed():
	task_completed = true
	var mat = $MeshInstance3D.get_surface_override_material(0)
	mat.albedo_color = Color(0.2, 0.2, 0.2) # Cinza
	mat.emission_enabled = false
	if has_node("MapIcon"):
		get_node("MapIcon").visible = false

func _unhandled_input(event):
	if player_in_range and not task_completed and event.is_action_pressed("ui_interact"):
		var player = get_tree().get_root().get_node_or_null("Main/Players/" + str(multiplayer.get_unique_id()))
		if player and player.is_impostor:
			print("Impostores não podem fazer tasks!")
			return # Bloqueia o impostor de abrir a interface
			
		var assigned = player.get_meta("assigned_tasks") if player.has_meta("assigned_tasks") else []
		var has_task = false
		for t in assigned:
			if int(t) == task_type:
				has_task = true
				break
		if not has_task:
			print("Você não tem essa tarefa!")
			return
			
		_open_task_ui()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _open_task_ui():
	if get_tree().get_root().has_node("TaskUI"):
		return
	
	var script_path = "res://TaskUI.gd"
	if task_type == 1:
		script_path = "res://TaskWiringUI.gd"
	elif task_type == 2:
		script_path = "res://TaskCardUI.gd"
	elif task_type == 3:
		script_path = "res://TaskAsteroidsUI.gd"
	elif task_type == 4:
		script_path = "res://TaskKeypadUI.gd"
	elif task_type == 5:
		script_path = "res://TaskSequenceUI.gd"
	elif task_type == 6 or task_type == 12:
		script_path = "res://TaskEngineUI.gd"
	elif task_type == 7:
		script_path = "res://TaskPowerUI.gd"
	elif task_type == 8:
		script_path = "res://TaskGarbageUI.gd"
	elif task_type == 9:
		script_path = "res://TaskNavUI.gd"
		
	var task_ui_script = load(script_path)
	if task_ui_script:
		var task_ui = task_ui_script.new()
		task_ui.name = "TaskUI"
		task_ui.set_meta("source_console", self)
		
		var canvas = CanvasLayer.new()
		canvas.layer = 90 # Fica acima do HUD do jogador, mas atrás do Menu de Pause
		
		var screen_bg = ColorRect.new()
		screen_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen_bg.color = Color(0, 0, 0, 0.85)
		canvas.add_child(screen_bg)
		
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(center)
		
		# O CenterContainer ignora a escala dos filhos diretos. 
		# Então criamos um wrapper com o tamanho final (1280*1.5, 720*1.5)
		var wrapper = Control.new()
		
		wrapper.custom_minimum_size = Vector2(1280, 720)
		task_ui.scale = Vector2(1.0, 1.0)
		
		task_ui.custom_minimum_size = Vector2(1280, 720)
		task_ui.size = Vector2(1280, 720) # Força o tamanho para as âncoras internas funcionarem
		task_ui.position = Vector2(0, 0)
		
		wrapper.add_child(task_ui)
		center.add_child(wrapper)
		
		get_tree().get_root().add_child(canvas)
		
		# Destrói o CanvasLayer (o fundo e o container) quando a Task se auto-destruir (queue_free)
		task_ui.tree_exited.connect(func(): canvas.queue_free())
