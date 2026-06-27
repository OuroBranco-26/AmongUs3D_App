extends SceneTree
func _init():
	var h = HTTPRequest.new()
	for m in h.get_method_list():
		if m.name == "request":
			print(m.args)
	quit()
