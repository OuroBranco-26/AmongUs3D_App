extends Node3D

var is_closed = false
var room_group = ""

var door_mesh: CSGBox3D

func _init():
	door_mesh = CSGBox3D.new()
	door_mesh.size = Vector3(4.0, 4.0, 0.5) # Tamanho padrão da porta
	door_mesh.position = Vector3(0, -4.0, 0) # Escondida embaixo do chão
	door_mesh.use_collision = true
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2)
	mat.metallic = 0.8
	mat.roughness = 0.2
	door_mesh.material = mat
	add_child(door_mesh)

func _ready():
	add_to_group("doors")

func set_door_size(width: float):
	door_mesh.size.x = width

func close_door():
	if is_closed: return
	is_closed = true
	# Sobe a porta
	var tween = create_tween()
	tween.tween_property(door_mesh, "position:y", 2.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func open_door():
	if not is_closed: return
	is_closed = false
	# Desce a porta
	var tween = create_tween()
	tween.tween_property(door_mesh, "position:y", -4.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
