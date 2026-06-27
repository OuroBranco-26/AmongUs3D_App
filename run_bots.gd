extends SceneTree
func _init():
    var main = load("res://Main.tscn").instantiate()
    root.add_child(main)
    main.play_with_bots = true
    create_timer(12.0).timeout.connect(func(): quit())
