extends SceneTree

func _init():
	var root = get_root()
	var viewport = root.get_viewport()
	viewport.transparent_bg = false
	
	var MapBuilder = load("res://MapBuilder.gd")
	var map = MapBuilder.new()
	root.add_child(map)
	
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 150
	cam.position = Vector3(0, 80, 0)
	cam.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	root.add_child(cam)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, 45, 0)
	root.add_child(light)
	
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(self._on_timeout)
	root.add_child(timer)

func _on_timeout():
	var root = get_root()
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("res://map_topdown.png")
	print("Screenshot saved to res://map_topdown.png")
	quit()
