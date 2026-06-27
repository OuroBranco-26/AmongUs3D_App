extends Control

var target_slider_idx = 0
var sliders = []

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	var title = Label.new()
	title.text = "Desvie energia para o painel iluminado"
	title.position = Vector2(350, 50)
	add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(300, 150)
	hbox.add_theme_constant_override("separation", 50)
	add_child(hbox)
	
	target_slider_idx = randi() % 5
	
	for i in range(5):
		var vbox = VBoxContainer.new()
		
		var indicator = ColorRect.new()
		indicator.custom_minimum_size = Vector2(20, 20)
		if i == target_slider_idx:
			indicator.color = Color.RED
		else:
			indicator.color = Color.DARK_GRAY
		vbox.add_child(indicator)
		
		var s = VSlider.new()
		s.custom_minimum_size = Vector2(50, 200)
		s.min_value = 0
		s.max_value = 100
		s.value = 0
		if i != target_slider_idx:
			s.editable = false
		else:
			s.value_changed.connect(_on_slider_changed)
		vbox.add_child(s)
		
		hbox.add_child(vbox)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_slider_changed(value):
	if value >= 95:
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
