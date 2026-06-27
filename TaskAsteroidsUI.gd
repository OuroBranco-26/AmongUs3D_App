extends Control

var score = 0
var target_score = 10
var score_label
var game_area
var spawner_timer

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	score_label = Label.new()
	score_label.text = "Asteroides Destruídos: 0 / " + str(target_score)
	score_label.position = Vector2(50, 50)
	add_child(score_label)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	game_area = Control.new()
	game_area.custom_minimum_size = Vector2(1280, 720)
	game_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_area)
	
	spawner_timer = Timer.new()
	spawner_timer.wait_time = 0.5
	spawner_timer.autostart = true
	spawner_timer.timeout.connect(_spawn_asteroid)
	add_child(spawner_timer)
	_spawn_asteroid()

func _spawn_asteroid():
	var ast = Button.new()
	ast.text = "[*]"
	ast.size = Vector2(50, 50)
	ast.position = Vector2(900, randf_range(100, 500))
	ast.pressed.connect(_on_asteroid_clicked.bind(ast))
	game_area.add_child(ast)
	
	var tween = create_tween()
	tween.tween_property(ast, "position:x", -100.0, randf_range(2.0, 4.0))
	tween.tween_callback(ast.queue_free)

func _on_asteroid_clicked(ast):
	if not is_instance_valid(ast):
		return
	ast.queue_free()
	score += 1
	score_label.text = "Asteroides Destruídos: " + str(score) + " / " + str(target_score)
	
	if score >= target_score:
		spawner_timer.stop()
		var source_console = get_meta("source_console", null)
		if source_console:
			source_console.mark_completed()
		var main_node = get_tree().get_root().get_node("Main")
		if main_node:
			main_node.finish_player_task(self)
		queue_free()

func _process(delta):
	# Evita que um clique perdido capture o mouse de volta para o jogador
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

