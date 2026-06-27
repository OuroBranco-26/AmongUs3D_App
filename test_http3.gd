extends SceneTree
func _init():
	var h = HTTPRequest.new()
	for m in h.get_method_list():
		print(m.name)
	quit()
