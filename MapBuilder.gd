extends Node3D

func p(x: float, y: float) -> Vector2:
	return Vector2(x, y)

func rect(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([p(x1, y1), p(x2, y1), p(x2, y2), p(x1, y2)])

func _ready():
	# === PORTAS FÍSICAS (SABOTAGEM) ===
	var add_door = func(pos: Vector3, group_name: String, width: float, is_rotated: bool):
		var DoorScript = load("res://Door.gd")
		var door = DoorScript.new()
		door.room_group = group_name
		door.position = pos
		if is_rotated:
			door.rotation_degrees.y = 90
		add_child(door)
		door.set_door_size(width)
		
	add_door.call(Vector3(0, 0, -16), "CAFETERIA", 6.0, false)
	add_door.call(Vector3(-16, 0, -30), "CAFETERIA", 4.0, true)
	add_door.call(Vector3(16, 0, -30), "CAFETERIA", 4.0, true)
	
	add_door.call(Vector3(0, 0, 5), "STORAGE", 6.0, false)
	add_door.call(Vector3(-14, 0, 26), "STORAGE", 4.0, true)
	add_door.call(Vector3(14, 0, 26), "STORAGE", 4.0, true)
	
	add_door.call(Vector3(-20, 0, -16), "MEDBAY", 4.0, false)
	add_door.call(Vector3(-36, 0, 3), "SECURITY", 4.0, true)
	add_door.call(Vector3(-18, 0, 22), "ELECTRICAL", 4.0, true)
	
	add_door.call(Vector3(-36, 0, -30), "UPPER ENGINE", 4.0, true)
	add_door.call(Vector3(-39, 0, -16), "UPPER ENGINE", 6.0, false)
	
	add_door.call(Vector3(-36, 0, 26), "LOWER ENGINE", 4.0, true)
	add_door.call(Vector3(-39, 0, 14), "LOWER ENGINE", 6.0, false)
	
	# === DEFINIÇÃO DE MATERIAIS ===
	var mat_hull = StandardMaterial3D.new()
	mat_hull.albedo_color = Color(0.25, 0.25, 0.25)
	mat_hull.metallic = 0.4
	mat_hull.roughness = 0.8
	
	var n_wall = FastNoiseLite.new()
	n_wall.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n_wall.frequency = 0.05
	
	var tex_color = NoiseTexture2D.new()
	tex_color.noise = n_wall
	tex_color.seamless = true
	mat_hull.albedo_texture = tex_color
	mat_hull.uv1_scale = Vector3(0.5, 0.5, 0.5)
	
	# === SHADERS PROCEDURAIS PARA PISOS VARIADOS ===
	var create_shader_mat = func(code: String) -> ShaderMaterial:
		var s = Shader.new(); s.code = "shader_type spatial;\n" + code
		var m = ShaderMaterial.new(); m.shader = s
		return m
		
	# 1. Quadriculado (Cafeteria)
	var m_cafe = create_shader_mat.call("""
	void fragment() {
		vec2 pos = floor(UV * 20.0);
		float pattern = mod(pos.x + pos.y, 2.0);
		ALBEDO = mix(vec3(0.1, 0.3, 0.5), vec3(0.05, 0.15, 0.3), pattern);
		ROUGHNESS = 0.3;
	}
	""")
	
	# 2. Piso Metálico Listrado (Corredores / Storage)
	var m_storage = create_shader_mat.call("""
	void fragment() {
		float pattern = step(0.8, fract(UV.x * 25.0 + UV.y * 25.0));
		ALBEDO = mix(vec3(0.25, 0.25, 0.25), vec3(0.1, 0.1, 0.1), pattern);
		METALLIC = 0.8; ROUGHNESS = 0.4;
	}
	""")
	var m_floor_corridor = m_storage
	
	# 3. Grade Industrial (Elétrica / Motor / Reactor)
	var m_elec = create_shader_mat.call("""
	void fragment() {
		vec2 grid = fract(UV * 40.0);
		float line = step(0.8, grid.x) + step(0.8, grid.y);
		ALBEDO = mix(vec3(0.15, 0.15, 0.15), vec3(0.05, 0.05, 0.05), clamp(line, 0.0, 1.0));
		METALLIC = 0.9; ROUGHNESS = 0.2;
	}
	""")
	var m_reactor = m_elec
	
	# 4. Azulejos Médicos / Laboratório (Medbay / Security / Admin)
	var m_medbay = create_shader_mat.call("""
	void fragment() {
		vec2 grid = fract(UV * 15.0);
		float edge = step(0.95, grid.x) + step(0.95, grid.y);
		ALBEDO = mix(vec3(0.8, 0.9, 0.9), vec3(0.5, 0.6, 0.6), clamp(edge, 0.0, 1.0));
		METALLIC = 0.1; ROUGHNESS = 0.1;
	}
	""")
	
	var m_prop_table = StandardMaterial3D.new()
	m_prop_table.albedo_color = Color(0.8, 0.8, 0.8)
	m_prop_table.metallic = 0.6
	m_prop_table.roughness = 0.4
	
	var m_prop_box = StandardMaterial3D.new()
	m_prop_box.albedo_color = Color(0.7, 0.5, 0.3)
	
	# Todas as geometrias das salas e corredores serão armazenadas aqui para união
	var all_polys : Array[PackedVector2Array] = []
	
	# Função auxiliar para escavar com Polígonos 2D
	var carve_poly = func(pts: PackedVector2Array, room_mat: Material, light_color: Color = Color.WHITE, light_energy: float = 1.0, room_name: String = "", center: Vector2 = Vector2.ZERO):
		all_polys.append(pts)
		
		var floor_poly = CSGPolygon3D.new()
		floor_poly.polygon = pts
		floor_poly.depth = 0.2
		floor_poly.rotation_degrees.x = 90
		floor_poly.position = Vector3(0, 0.2, 0) # Fica levemente acima do chão
		floor_poly.use_collision = true
		floor_poly.material = room_mat
		add_child(floor_poly)
		
		# Teto
		var ceil_poly = CSGPolygon3D.new()
		ceil_poly.polygon = pts
		ceil_poly.depth = 0.2
		ceil_poly.rotation_degrees.x = 90
		ceil_poly.position = Vector3(0, 6.0, 0) # Tampa as paredes no Y=6.0
		ceil_poly.use_collision = true
		ceil_poly.material = mat_hull
		add_child(ceil_poly)
		
		if room_name != "":
			var label = Label3D.new()
			label.text = room_name
			label.font_size = 400
			label.outline_size = 20
			label.outline_render_priority = 0
			label.modulate = Color(1, 1, 1, 0.9)
			label.rotation_degrees.x = -90
			label.position = Vector3(center.x, 5.4, center.y) # Coloca logo abaixo do radar (5.5) e acima do chão
			label.double_sided = true
			label.layers = 2
			label.no_depth_test = true
			add_child(label)
			
		if light_energy > 0.0:
			var light = OmniLight3D.new()
			light.light_color = light_color
			light.light_energy = light_energy * 3.0 # Mais forte
			light.omni_range = 30.0
			light.shadow_enabled = true # Ativa sombras para a luz não atravessar paredes!
			light.light_specular = 0.1 # Reduz o brilho exagerado no chão
			light.position = Vector3(center.x, 4.5, center.y) # Abaixo do teto (Y=6.0)
			light.add_to_group("map_lights")
			
			if room_name in ["REACTOR", "MEDBAY", "WEAPONS"]:
				var flicker_script = GDScript.new()
				flicker_script.source_code = """
extends OmniLight3D
var base_energy: float
var is_on: bool = true
var time_left: float = 0.0

func _ready():
	base_energy = light_energy
	time_left = 2.0 + randf() * 2.0

func _process(delta):
	time_left -= delta
	if time_left <= 0.0:
		is_on = not is_on
		if is_on:
			light_energy = base_energy
			time_left = 2.0 + randf() * 2.0 # Liga por ~3s
		else:
			light_energy = base_energy * 0.1 # Fica bem fraca quase apagada
			time_left = 0.5 + randf() * 1.0 # Apaga por ~1s
"""
				flicker_script.reload()
				light.set_script(flicker_script)
				light.set_process(true)
				
			add_child(light)

	# === AS 14 SALAS EXATAS DA SKELD ===
	carve_poly.call(PackedVector2Array([p(-6,-44), p(6,-44), p(16,-34), p(16,-26), p(6,-16), p(-6,-16), p(-16,-26), p(-16,-34)]), m_cafe, Color(1,1,0.9), 1.8, "CAFETERIA", p(0, -30))
	carve_poly.call(PackedVector2Array([p(-6,5), p(6,5), p(6,12), p(14,20), p(14,28), p(4,34), p(-4,34), p(-14,28), p(-14,20), p(-6,12)]), m_storage, Color(1,0.8,0.6), 1.2, "STORAGE", p(0, 20))
	carve_poly.call(rect(8,-5, 22,8), m_medbay, Color(0.8,1,0.8), 1.2, "ADMIN", p(15, 2))
	carve_poly.call(rect(-32,10, -18,24), m_elec, Color(1,1,0.5), 1.0, "ELECTRICAL", p(-25, 16))
	carve_poly.call(rect(-26,-16, -14,-4), m_medbay, Color(0.8,1,1), 2.0, "MEDBAY", p(-20, -10))
	carve_poly.call(rect(-35,-2, -26,6), mat_hull, Color(0.8,0.8,1), 1.0, "SECURITY", p(-31, 3))
	carve_poly.call(PackedVector2Array([p(-50,-4), p(-50,6), p(-54,10), p(-62,10), p(-62,-8), p(-54,-8)]), m_reactor, Color(1,0.3,0.3), 2.0, "REACTOR", p(-56, 1))
	carve_poly.call(PackedVector2Array([p(-46,-36), p(-36,-36), p(-36,-16), p(-46,-16), p(-52,-22), p(-52,-30)]), m_elec, Color(0.9,0.9,1), 1.2, "UPPER ENGINE", p(-44, -26))
	carve_poly.call(PackedVector2Array([p(-46,14), p(-36,14), p(-36,34), p(-46,34), p(-52,28), p(-52,20)]), m_elec, Color(0.9,0.9,1), 1.2, "LOWER ENGINE", p(-44, 24))
	carve_poly.call(PackedVector2Array([p(32,-40), p(42,-40), p(48,-34), p(48,-30), p(42,-24), p(32,-24)]), mat_hull, Color(1,1,1), 1.2, "WEAPONS", p(40, -32))
	carve_poly.call(rect(30,-12, 38,-2), m_medbay, Color(0.7,0.9,1), 1.0, "O2", p(34, -7))
	carve_poly.call(PackedVector2Array([p(48,-16), p(56,-16), p(64,-10), p(64,-2), p(56,4), p(48,4)]), mat_hull, Color(0.8,0.8,1), 1.0, "NAVIGATION", p(56, -6))
	carve_poly.call(PackedVector2Array([p(32,14), p(44,14), p(44,22), p(38,28), p(32,28)]), m_elec, Color(0.8,0.8,1), 1.0, "SHIELDS", p(38, 20))
	carve_poly.call(rect(18,28, 30,38), mat_hull, Color(0.8,0.8,0.8), 1.0, "COMMUNICATIONS", p(24, 33))

	# === CORREDORES EXATOS ===
	var carve_corr = func(pts: PackedVector2Array): carve_poly.call(pts, m_floor_corridor, Color.WHITE, 0.0)
	
	carve_corr.call(rect(-3, -16, 3, 5)) # Cafe -> Storage
	carve_corr.call(rect(-36, -32, -16, -28)) # Cafe -> Upper Engine
	carve_corr.call(rect(-22, -28, -18, -16)) # Medbay -> Upper Engine Corridor
	carve_corr.call(rect(-36, 24.5, -14, 28)) # Storage -> Elec -> Lower Engine
	carve_corr.call(rect(-18, 20, -14, 24.5)) # Storage diag -> Elec
	carve_corr.call(rect(-42, -16, -36, 14)) # Continuous Hallway: Upper Engine -> Lower Engine
	carve_corr.call(rect(-36, 1, -35, 5)) # Doorway para a Security
	carve_corr.call(rect(-50, 0, -42, 4)) # Hallway -> Reactor
	
	carve_corr.call(rect(16, -32, 32, -28)) # Cafe -> Weapons
	carve_corr.call(rect(32, -24, 36, -12)) # Weapons -> O2
	carve_corr.call(rect(3, -2, 8, 2)) # Center -> Admin
	carve_corr.call(rect(38, -8, 48, -4)) # O2 -> Nav
	carve_corr.call(rect(44, 16, 52, 20)) # Shields -> Nav H
	carve_corr.call(rect(48, 4, 52, 16))  # Nav -> Shields V (O corredor vertical que faltava!)
	carve_corr.call(rect(18, 14, 24, 28)) # Comms -> Shields
	carve_corr.call(rect(14, 24, 32, 28)) # Storage -> Comms -> Shields
	
	# === SISTEMA DE PAREDES MATEMÁTICO (Sub-Segment Raycast Check) ===
	# Verifica fatias de 25cm de cada aresta. Se a fatia der para o vazio, constrói parede. Se der pra outra sala, é passagem!
	var build_wall = func(p1: Vector2, dir: Vector2, start_d: float, end_d: float):
		var w_dist = end_d - start_d
		var w_mid_d = start_d + w_dist / 2.0
		var w_mid = p1 + dir * w_mid_d
		var wall = CSGBox3D.new()
		wall.size = Vector3(w_dist + 0.5, 6.0, 0.5) # +0.5 para preencher os cantos
		wall.position = Vector3(w_mid.x, 3.0, w_mid.y)
		wall.rotation.y = -dir.angle()
		wall.use_collision = true
		wall.material = mat_hull
		add_child(wall)

	for pts in all_polys:
		for i in range(pts.size()):
			var p1 = pts[i]
			var p2 = pts[(i + 1) % pts.size()]
			var dist = p1.distance_to(p2)
			if dist < 0.1: continue
			
			var vec = p2 - p1
			var dir = vec.normalized()
			var normal = Vector2(vec.y, -vec.x).normalized()
			
			var step = 0.25
			var current_dist = 0.0
			var wall_start = -1.0
			
			while current_dist < dist:
				var segment_end = min(current_dist + step, dist)
				var segment_mid = current_dist + (segment_end - current_dist) / 2.0
				var mid_point = p1 + dir * segment_mid
				var check_point = mid_point + normal * 0.2
				
				var is_shared = false
				for other in all_polys:
					if Geometry2D.is_point_in_polygon(check_point, other):
						is_shared = true
						break
				
				if not is_shared:
					if wall_start < 0.0: wall_start = current_dist
				else:
					if wall_start >= 0.0:
						build_wall.call(p1, dir, wall_start, current_dist)
						wall_start = -1.0
						
				current_dist += step
				
			if wall_start >= 0.0:
				build_wall.call(p1, dir, wall_start, dist)
	
	# === PROPS E MOBÍLIA ===
	var add_table = func(pos: Vector3):
		var leg = CSGCylinder3D.new(); leg.radius = 0.3; leg.height = 1.0; leg.position = pos + Vector3(0, 0.5, 0); leg.material = m_prop_table; leg.use_collision = true; add_child(leg)
		var top = CSGCylinder3D.new(); top.radius = 2.0; top.height = 0.2; top.position = pos + Vector3(0, 1.0, 0); top.material = m_prop_table; top.use_collision = true; add_child(top)
		# Cadeiras envolta da mesa
		for i in range(4):
			var chair = CSGBox3D.new(); chair.size = Vector3(0.6, 0.6, 0.6); 
			var angle = i * (PI/2)
			chair.position = pos + Vector3(cos(angle)*1.5, 0.3, sin(angle)*1.5)
			chair.material = m_prop_box; chair.use_collision = true; add_child(chair)
		
	var add_server = func(pos: Vector3):
		var server = CSGBox3D.new(); server.size = Vector3(2.0, 3.5, 1.5); server.position = pos + Vector3(0, 1.75, 0)
		var mat = StandardMaterial3D.new(); mat.albedo_color = Color(0.1, 0.3, 0.5); mat.metallic = 0.9
		server.material = mat; server.use_collision = true; add_child(server)
	
	add_table.call(Vector3(0, 0, -30)) # Cafe Centro
	add_table.call(Vector3(-6, 0, -34)); add_table.call(Vector3(6, 0, -34))
	add_table.call(Vector3(-6, 0, -24)); add_table.call(Vector3(6, 0, -24))
	add_table.call(Vector3(15, 0, 2)) # Admin
	
	var add_box = func(pos: Vector3):
		var b = CSGBox3D.new(); b.size = Vector3(1.5, 1.5, 1.5); b.position = pos + Vector3(0, 0.75, 0); b.material = m_prop_box; b.use_collision = true; add_child(b)
		
	# MUITAS Caixas no Storage
	add_box.call(Vector3(0, 0, 20)); add_box.call(Vector3(-2, 0, 18)); add_box.call(Vector3(2, 0, 22))
	add_box.call(Vector3(0, 1.5, 20)); add_box.call(Vector3(-2, 1.5, 18))
	add_box.call(Vector3(4, 0, 16)); add_box.call(Vector3(4, 0, 18)); add_box.call(Vector3(4, 1.5, 18))
	add_box.call(Vector3(-6, 0, 24)); add_box.call(Vector3(-4, 0, 24)); add_box.call(Vector3(-6, 1.5, 24))
	add_box.call(Vector3(0, 0, 26)); add_box.call(Vector3(2, 0, 26));
	
	# Servidor da Elétrica e Segurança
	add_server.call(Vector3(-25, 0, 16))
	add_server.call(Vector3(-31, 0, 3)) # Security
	
	# Medbay Camas e Scanner
	var add_bed = func(pos: Vector3):
		var bed = CSGBox3D.new(); bed.size = Vector3(1.2, 0.8, 2.5); bed.position = pos + Vector3(0, 0.4, 0); bed.material = m_medbay; bed.use_collision = true; add_child(bed)
	add_bed.call(Vector3(-22, 0, -10)); add_bed.call(Vector3(-18, 0, -10))
	add_bed.call(Vector3(-22, 0, -6)); add_bed.call(Vector3(-18, 0, -6))
	
	var scanner = CSGCylinder3D.new(); scanner.radius = 1.5; scanner.height = 0.2; scanner.position = Vector3(-20, 0.1, -14); scanner.material = m_elec; add_child(scanner)
	
	# Reator Central
	var reactor_core = CSGCylinder3D.new()
	reactor_core.radius = 1.8; reactor_core.height = 12.0; reactor_core.position = Vector3(-56, 6, 1)
	var m_core = StandardMaterial3D.new(); m_core.albedo_color = Color(1, 0, 0); m_core.emission_enabled = true; m_core.emission = Color(1, 0.2, 0.2); m_core.emission_energy_multiplier = 2.0
	reactor_core.material = m_core; reactor_core.use_collision = true; add_child(reactor_core)
	
	# Motores
	var add_engine = func(pos: Vector3):
		var eng = CSGBox3D.new(); eng.size = Vector3(4, 4, 4); eng.position = pos + Vector3(0, 2, 0); eng.material = m_prop_table; eng.use_collision = true; add_child(eng)
	add_engine.call(Vector3(-41, 0, -26)) # Upper
	add_engine.call(Vector3(-41, 0, 24)) # Lower
	
	# O2 Planta Gigante
	var m_plant = StandardMaterial3D.new(); m_plant.albedo_color = Color(0.2, 0.8, 0.2)
	var m_trunk = StandardMaterial3D.new(); m_trunk.albedo_color = Color(0.4, 0.2, 0.1)
	var trunk = CSGCylinder3D.new(); trunk.radius = 0.4; trunk.height = 3.0; trunk.position = Vector3(34, 1.5, -7); trunk.material = m_trunk; trunk.use_collision = true; add_child(trunk)
	var leaves = CSGSphere3D.new(); leaves.radius = 2.5; leaves.position = Vector3(34, 4.0, -7); leaves.material = m_plant; add_child(leaves)

	# Weapons Arma de Asteroides
	var gun_base = CSGBox3D.new(); gun_base.size = Vector3(2, 2, 2); gun_base.position = Vector3(40, 1, -30); gun_base.material = m_prop_box; gun_base.use_collision = true; add_child(gun_base)
	var gun_barrel = CSGCylinder3D.new(); gun_barrel.radius = 0.5; gun_barrel.height = 4.0; gun_barrel.rotation_degrees.x = 90; gun_barrel.position = Vector3(40, 2, -32); gun_barrel.material = mat_hull; add_child(gun_barrel)
	
	# Shields Geradores
	var m_shield = StandardMaterial3D.new(); m_shield.albedo_color = Color(0.5, 0.8, 1.0); m_shield.emission_enabled = true; m_shield.emission = Color(0.5, 0.8, 1.0)
	var add_shield_gen = func(pos: Vector3):
		var gen = CSGCylinder3D.new(); gen.radius = 1.0; gen.height = 2.0; gen.position = pos + Vector3(0, 1.0, 0); gen.material = m_shield; gen.use_collision = true; add_child(gen)
	add_shield_gen.call(Vector3(38, 0, 17)); add_shield_gen.call(Vector3(38, 0, 23))
	
	# Navigation Pilotos e Cadeira
	var nav_console = CSGBox3D.new(); nav_console.size = Vector3(6, 1.5, 2); nav_console.position = Vector3(60, 0.75, -6); nav_console.material = m_prop_box; nav_console.use_collision = true; add_child(nav_console)
	var nav_chair1 = CSGBox3D.new(); nav_chair1.size = Vector3(1, 1, 1); nav_chair1.position = Vector3(58, 0.5, -6); nav_chair1.material = m_prop_table; nav_chair1.use_collision = true; add_child(nav_chair1)
	var nav_chair2 = CSGBox3D.new(); nav_chair2.size = Vector3(1, 1, 1); nav_chair2.position = Vector3(62, 0.5, -6); nav_chair2.material = m_prop_table; nav_chair2.use_collision = true; add_child(nav_chair2)
	
	# Communications Mesa Central Longa
	var comms_table = CSGBox3D.new(); comms_table.size = Vector3(2, 1, 6); comms_table.position = Vector3(24, 0.5, 33); comms_table.material = m_prop_table; comms_table.use_collision = true; add_child(comms_table)

	# WORKAROUND FOR GODOT 4 HEADLESS SERVER PHYSICS BUG:
	# CSG Nodes do not generate collisions in headless mode. We manually inject StaticBody3D for physics.
	var fix_headless_physics = func(node: Node, self_ref: Callable):
		for child in node.get_children():
			if child is CSGBox3D and child.use_collision:
				var sb = StaticBody3D.new()
				var col = CollisionShape3D.new()
				var sh = BoxShape3D.new()
				sh.size = child.size
				col.shape = sh
				sb.add_child(col)
				child.add_child(sb)
			elif child is CSGCylinder3D and child.use_collision:
				var sb = StaticBody3D.new()
				var col = CollisionShape3D.new()
				var sh = CylinderShape3D.new()
				sh.radius = child.radius
				sh.height = child.height
				col.shape = sh
				sb.add_child(col)
				child.add_child(sb)
			self_ref.call(child, self_ref)
	
	fix_headless_physics.call(self, fix_headless_physics)
	
	# Massive flat floor for headless physics raycasting to build the AStar grid safely
	var global_floor_sb = StaticBody3D.new()
	var global_floor_col = CollisionShape3D.new()
	var global_floor_sh = BoxShape3D.new()
	global_floor_sh.size = Vector3(200, 0.4, 200)
	global_floor_col.shape = global_floor_sh
	global_floor_sb.position = Vector3(0, 0, 0)
	global_floor_sb.add_child(global_floor_col)
	add_child(global_floor_sb)
