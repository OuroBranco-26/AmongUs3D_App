extends Control

var slider

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	var title = Label.new()
	title.text = "Alinhe o motor no centro (0)"
	title.position = Vector2(400, 50)
	add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	slider = HSlider.new()
	slider.min_value = -100
	slider.max_value = 100
	slider.value = randf_range(30, 100) * (1 if randi() % 2 == 0 else -1)
	slider.custom_minimum_size = Vector2(400, 50)
	slider.position = Vector2(300, 250)
	slider.drag_ended.connect(_on_drag_ended)
	add_child(slider)
	
	var center_line = ColorRect.new()
	center_line.color = Color.GREEN
	center_line.size = Vector2(4, 80)
	center_line.position = Vector2(500, 235)
	add_child(center_line)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_drag_ended(value_changed):
	if abs(slider.value) < 5:
		slider.value = 0
		slider.editable = false
		_win()

func _win():
	var source_console = get_meta("source_console", null)
	if source_console:
		source_console.mark_completed()
	var main_node = get_tree().get_root().get_node("Main")
	if main_node:
		main_node.finish_player_task(self)
	await get_tree().create_timer(0.5).timeout
	queue_free()
