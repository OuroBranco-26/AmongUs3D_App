extends SceneTree
func _init():
	var h = HTTPRequest.new()
	for p in h.get_property_list():
		print(p.name)
	quit()
