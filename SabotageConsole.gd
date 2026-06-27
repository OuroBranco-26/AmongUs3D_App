extends StaticBody3D

@export var sabotage_type = "LIGHTS" # ou "O2"
var is_active = false
var player_in_range = false
var flash_timer = 0.0

func _ready():
	add_to_group("sabotage_consoles")
	
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2) # Apagado por padrão
	mat.emission_enabled = false
	mesh_inst.mesh = mesh
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position.y = 0.5
	add_child(mesh_inst)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	col.shape = shape
	col.position.y = 0.5
	add_child(col)
	
	var area = Area3D.new()
	area.name = "Area3D"
	var area_col = CollisionShape3D.new()
	var area_shape = BoxShape3D.new()
	area_shape.size = Vector3(3, 2, 3)
	area_col.position.y = 1.0
	area_col.shape = area_shape
	area.add_child(area_col)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)
	
	# Ícone do Radar (Sabotagem)
	var map_icon = Label3D.new()
	map_icon.name = "MapIcon"
	map_icon.text = "!"
	map_icon.font_size = 800
	map_icon.outline_size = 50
	map_icon.modulate = Color.RED
	map_icon.outline_modulate = Color.DARK_RED
	map_icon.rotation_degrees.x = -90
	map_icon.position.y = 5.0
	map_icon.layers = 2 # Apenas no minimapa
	map_icon.no_depth_test = true
	map_icon.visible = false
	add_child(map_icon)

func _process(delta):
	if is_active:
		flash_timer += delta * 5.0
		var mat = $MeshInstance3D.get_surface_override_material(0)
		if int(flash_timer) % 2 == 0:
			mat.albedo_color = Color(1, 0, 0)
			mat.emission_enabled = true
			mat.emission = Color(1, 0, 0)
		else:
			mat.albedo_color = Color(0.2, 0.2, 0.2)
			mat.emission_enabled = false
			
		# Radar Alert Pulsing
		if has_node("MapIcon"):
			var icon = get_node("MapIcon")
			icon.visible = true
			# Faz o Alpha pulsar entre 0.3 e 1.0
			var pulse = 0.65 + 0.35 * sin(flash_timer)
			icon.modulate.a = pulse
			icon.outline_modulate.a = pulse
			icon.scale = Vector3(pulse, pulse, pulse) * 1.5
	else:
		var mat = $MeshInstance3D.get_surface_override_material(0)
		mat.albedo_color = Color(0.2, 0.2, 0.2)
		mat.emission_enabled = false
		if has_node("MapIcon"):
			get_node("MapIcon").visible = false

func activate():
	is_active = true

func deactivate():
	is_active = false

func _on_body_entered(body):
	if body.name == str(multiplayer.get_unique_id()):
		player_in_range = true

func _on_body_exited(body):
	if body.name == str(multiplayer.get_unique_id()):
		player_in_range = false

func _unhandled_input(event):
	if is_active and player_in_range and event.is_action_pressed("ui_interact"):
		if get_tree().get_root().has_node("FixUI"):
			return
			
		var ui_script = null
		if sabotage_type == "LIGHTS":
			ui_script = load("res://FixLightsUI.gd")
		elif sabotage_type == "O2":
			ui_script = load("res://FixO2UI.gd")
			
		if ui_script:
			var ui = ui_script.new()
			ui.name = "FixUI"
			ui.set_meta("console_node", self)
			get_tree().get_root().add_child(ui)
