extends SceneTree
func _init():
    ProjectSettings.load_resource_pack("res://Server.pck")
    var file = FileAccess.open("res://Main.gd", FileAccess.READ)
    if file:
        var text = file.get_as_text()
        var f2 = FileAccess.open("res://Main.gd_recovered", FileAccess.WRITE)
        f2.store_string(text)
        print("RECOVERED TRUE MAIN.GD SUCCESSFULLY!")
    else:
        print("FAILED")
    quit()
