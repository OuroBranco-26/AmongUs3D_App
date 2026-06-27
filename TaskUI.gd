extends Control

var progress_bar: ProgressBar
var button: Button
var is_downloading = false
var progress = 0.0

func _ready():
	# Garantir que a UI pegue os cliques do mouse e não deixe o boneco andar
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Fundo Translucido Geral
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(1280, 720)
	bg.color = Color(0, 0, 0, 0.8)
	add_child(bg)
	
	# Fundo da Tarefa
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(500, 300)
	panel.position = Vector2(1280, 720) / 2.0 - Vector2(250, 150)
	add_child(panel)
	
	# Titulo
	var label = Label.new()
	label.text = "Download de Dados"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 20)
	label.size = Vector2(500, 40)
	label.add_theme_font_size_override("font_size", 24)
	panel.add_child(label)
	
	# Barra de Progresso
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(50, 120)
	progress_bar.size = Vector2(400, 40)
	panel.add_child(progress_bar)
	
	# Botão
	button = Button.new()
	button.text = "Fazer Download"
	button.position = Vector2(150, 200)
	button.size = Vector2(200, 50)
	button.pressed.connect(_on_button_pressed)
	panel.add_child(button)

func _on_button_pressed():
	if not is_downloading:
		is_downloading = true
		button.text = "Baixando..."

func _process(delta):
	if is_downloading:
		progress += delta * 33.3 # Enche em cerca de 3 segundos
		progress_bar.value = progress
		if progress >= 100.0:
			# Tarefa concluída!
			var main_node = get_tree().get_root().get_node("Main")
			if main_node:
				main_node.finish_player_task(self)
			queue_free() # Fecha a janela
