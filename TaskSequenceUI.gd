extends Control

var current_expected = 1
var buttons = []

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	var title = Label.new()
	title.text = "Pressione os números em ordem crescente"
	title.position = Vector2(0, 100)
	title.size = Vector2(1280, 50)
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(900, 100)
	close_btn.size = Vector2(60, 60)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	var grid = GridContainer.new()
	grid.columns = 3
	# Botões 90x90 (aumentados em 50%), Grid total = 300x300, Centralizado: (1280-300)/2 = 490, (720-300)/2 = 210
	grid.position = Vector2(490, 210)
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	add_child(grid)
	
	var numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	numbers.shuffle()
	
	for n in numbers:
		var b = Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(90, 90)
		b.add_theme_font_size_override("font_size", 32)
		b.pressed.connect(_on_btn_pressed.bind(b, n))
		grid.add_child(b)
		buttons.append(b)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_btn_pressed(btn, num):
	if num == current_expected:
		btn.disabled = true
		btn.modulate = Color.GREEN
		current_expected += 1
		if current_expected > 9:
			_win()
	else:
		# Errou! Pisca vermelho e reseta
		for b in buttons:
			b.modulate = Color.RED
		await get_tree().create_timer(0.5).timeout
		current_expected = 1
		for b in buttons:
			b.modulate = Color.WHITE
			b.disabled = false

func _win():
	var source_console = get_meta("source_console", null)
	if source_console:
		source_console.mark_completed()
	var main_node = get_tree().get_root().get_node("Main")
	if main_node:
		main_node.finish_player_task(self)
	queue_free()
