$content = Get-Content -Path Main.gd -Raw
$idx = $content.IndexOf('var astar: AStar3D')
if ($idx -gt -1) {
    $content = $content.Substring(0, $idx).TrimEnd()
}

$astar_code = "

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
					shape.height = 1.9
					var shape_query = PhysicsShapeQueryParameters3D.new()
					shape_query.shape = shape
					shape_query.transform = Transform3D(Basis(), Vector3(x, hit_y + 1.0, z))
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
				var neighbors = [str(x + step) + "," + str(z), str(x - step) + "," + str(z), str(x) + "," + str(z + step), str(x) + "," + str(z - step), str(x + step) + "," + str(z + step), str(x - step) + "," + str(z - step), str(x + step) + "," + str(z - step), str(x - step) + "," + str(z + step)]
				for n in neighbors:
					if valid_points.has(n):
						var n_id = valid_points[n]
						if not astar.are_points_connected(id, n_id):
							astar.connect_points(id, n_id, true)
			z += step
		x += step
	print("AStar Grid Construido com ", astar.get_point_count(), " pontos!")

func get_astar_path_to(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	if not astar: return PackedVector3Array()
	var id_from = astar.get_closest_point(from_pos)
	var id_to = astar.get_closest_point(to_pos)
	if id_from == -1 or id_to == -1: return PackedVector3Array()
	return astar.get_point_path(id_from, id_to)
"
$content = $content + $astar_code
Set-Content -Path Main.gd -Value $content -Encoding UTF8
