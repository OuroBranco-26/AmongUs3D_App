extends Control

var hold_progress = 0.0
var is_holding = false
var is_done = false
var pb

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	var title = Label.new()
	title.text = "Segure a alavanca para esvaziar o lixo"
	title.position = Vector2(350, 50)
	add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	pb = ProgressBar.new()
	pb.custom_minimum_size = Vector2(300, 40)
	pb.position = Vector2(350, 150)
	pb.max_value = 100
	pb.value = 0
	add_child(pb)
	
	var lever_btn = Button.new()
	lever_btn.text = "Segurar (Esvaziar)"
	lever_btn.custom_minimum_size = Vector2(200, 100)
	lever_btn.position = Vector2(400, 250)
	lever_btn.button_down.connect(func(): is_holding = true)
	lever_btn.button_up.connect(func(): is_holding = false)
	add_child(lever_btn)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if is_holding:
		hold_progress += delta * 33.0 # ~3 segundos
		if hold_progress >= 100.0:
			hold_progress = 100.0
			is_holding = false
			_win()
	else:
		hold_progress -= delta * 50.0
		if hold_progress < 0:
			hold_progress = 0
	
	pb.value = hold_progress

func _win():
	if is_done: return
	is_done = true
	var source_console = get_meta("source_console", null)
	if source_console:
		source_console.mark_completed()
	var main_node = get_tree().get_root().get_node("Main")
	if main_node:
		main_node.finish_player_task(self)
	await get_tree().create_timer(0.5).timeout
	queue_free()
