extends Node
func _ready():
	var root = get_tree().root
	var main_menu = load("res://MainMenu.tscn").instantiate()
	root.add_child(main_menu)
	main_menu._on_join_pressed("64.181.162.108")
	await get_tree().create_timer(2).timeout
	main_menu._on_start_pressed()
	
	await get_tree().create_timer(4).timeout
	var player = get_tree().get_root().find_child(str(main_menu.multiplayer.get_unique_id()), true, false)
	if player:
		print("DEBUG_RUNNER: Found player node!")
		print("DEBUG_RUNNER: Player has assigned_tasks: ", player.has_meta("assigned_tasks"))
	else:
		print("DEBUG_RUNNER: Player node not found!")
		
	var main_node = get_tree().get_root().get_node_or_null("Main")
	if main_node:
		print("DEBUG_RUNNER: Main node found!")
	else:
		print("DEBUG_RUNNER: Main node not found!")
	
	await get_tree().create_timer(11).timeout
	if player:
		print("DEBUG_RUNNER (15s): Player has assigned_tasks: ", player.has_meta("assigned_tasks"))
	get_tree().quit()
