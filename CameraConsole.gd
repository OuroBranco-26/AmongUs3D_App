extends StaticBody3D

var player_in_range = false

func _ready():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.3, 0.8) # Azul tecnológico
	
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(2.0, 1.5, 1.0)
	mesh.mesh = box
	mesh.set_surface_override_material(0, mat)
	mesh.position.y = 0.75
	add_child(mesh)
	
	# Tela do console
	var screen_mesh = MeshInstance3D.new()
	var screen_box = BoxMesh.new()
	screen_box.size = Vector3(1.8, 0.8, 0.1)
	screen_mesh.mesh = screen_box
	
	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.0, 0.8, 0.2)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.0, 0.8, 0.2)
	screen_mesh.set_surface_override_material(0, screen_mat)
	screen_mesh.position = Vector3(0, 1.8, -0.4)
	screen_mesh.rotation_degrees.x = -20
	add_child(screen_mesh)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 1.5, 1.0)
	col.shape = shape
	col.position.y = 0.75
	add_child(col)
	
	var area = Area3D.new()
	var area_col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 3.0
	area_col.shape = sphere
	area.add_child(area_col)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body):
	if body.name == str(multiplayer.get_unique_id()):
		player_in_range = true
		print("Player detectado nas Câmeras!")

func _on_body_exited(body):
	if body.name == str(multiplayer.get_unique_id()):
		player_in_range = false
		print("Player saiu das Câmeras!")

func _unhandled_input(event):
	if player_in_range and event.is_action_pressed("ui_interact"):
		if not get_tree().get_root().has_node("CamerasUI"):
			var ui_script = load("res://CamerasUI.gd")
			if ui_script:
				var ui = ui_script.new()
				ui.name = "CamerasUI"
				get_tree().get_root().add_child(ui)
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				get_viewport().set_input_as_handled()
