extends CSGBox3D

@export var vent_id = 0
@export var connected_vents = []
@export var room_name = ""

func _ready():
	add_to_group("vents")
	
	size = Vector3(1.5, 0.1, 1.5)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2) # Volta para Grade Cinza Escuro
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.1, 0.1)
	material = mat
	
	# Posição Y = 0.45 para uma caixa de 0.1 de altura repousar exatamente na superfície (Y=0.4)
	position.y = 0.45
	use_collision = true

