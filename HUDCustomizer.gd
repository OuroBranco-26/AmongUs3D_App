extends Control

var selected_node: Control = null
var selected_key: String = ""
var is_dragging = false
var drag_offset = Vector2.ZERO

var hud_elements = {}
var default_positions = {}

var scale_slider: HSlider
var save_btn: Button
var reset_btn: Button
var selected_label: Label

func _init():
	name = "HUDCustomizer"
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	
	var info_label = Label.new()
	info_label.text = "Toque e arraste para mover.\nSelecione um botão e use a barra para mudar o tamanho."
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.set_anchors_preset(PRESET_TOP_WIDE)
	info_label.position.y = 10
	info_label.add_theme_font_size_override("font_size", 24)
	add_child(info_label)
	
	selected_label = Label.new()
	selected_label.text = "Selecionado: Nenhum"
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.position = Vector2(300, 55)
	selected_label.size = Vector2(680, 30)
	selected_label.add_theme_font_size_override("font_size", 20)
	selected_label.add_theme_color_override("font_color", Color.CYAN)
	add_child(selected_label)
	
	scale_slider = HSlider.new()
	scale_slider.position = Vector2(300, 90)
	scale_slider.size = Vector2(680, 40)
	scale_slider.min_value = 0.5
	scale_slider.max_value = 2.0
	scale_slider.step = 0.1
	scale_slider.value = 1.0
	scale_slider.value_changed.connect(_on_scale_changed)
	add_child(scale_slider)
	
	save_btn = Button.new()
	save_btn.text = "SALVAR E SAIR"
	save_btn.position = Vector2(1000, 90)
	save_btn.size = Vector2(250, 60)
	save_btn.add_theme_font_size_override("font_size", 24)
	save_btn.add_theme_color_override("font_color", Color.GREEN)
	save_btn.pressed.connect(_save_and_exit)
	add_child(save_btn)
	
	reset_btn = Button.new()
	reset_btn.text = "RESTAURAR"
	reset_btn.position = Vector2(50, 90)
	reset_btn.size = Vector2(200, 60)
	reset_btn.add_theme_font_size_override("font_size", 24)
	reset_btn.add_theme_color_override("font_color", Color.RED)
	reset_btn.pressed.connect(_reset_defaults)
	add_child(reset_btn)

func _ready():
	_load_mock_elements()

func _load_mock_elements():
	var screen_size = get_viewport_rect().size
	
	# Posições padrão em coordenadas absolutas de tela
	default_positions["joystick"] = Vector2(50, screen_size.y - 210)
	default_positions["use"] = Vector2(screen_size.x - 150, screen_size.y - 150)
	default_positions["report"] = Vector2(screen_size.x - 300, screen_size.y - 150)
	default_positions["jump"] = Vector2(screen_size.x - 150, screen_size.y - 450)
	default_positions["crouch"] = Vector2(screen_size.x - 300, screen_size.y - 450)
	default_positions["kill"] = Vector2(screen_size.x - 150, screen_size.y - 300)
	default_positions["sabotage"] = Vector2(screen_size.x - 300, screen_size.y - 300)
	default_positions["mic"] = Vector2(screen_size.x - 150, screen_size.y - 600)
	
	default_positions["task_list"] = Vector2(20, 250)
	default_positions["radar"] = Vector2(screen_size.x - 270, 20)
	default_positions["progress_bar"] = Vector2(20, 20)
	
	# Joystick
	hud_elements["joystick"] = _create_mock_btn("JOYSTICK", default_positions["joystick"], Color.GRAY, Vector2(160, 160))
	
	# Interface
	hud_elements["task_list"] = _create_mock_btn("TAREFAS", default_positions["task_list"], Color(0.2, 0.2, 0.2, 0.8), Vector2(300, 200))
	hud_elements["radar"] = _create_mock_btn("RADAR", default_positions["radar"], Color(0.0, 0.5, 0.5, 0.8), Vector2(250, 250))
	hud_elements["progress_bar"] = _create_mock_btn("BARRA PROGR.", default_positions["progress_bar"], Color.GREEN, Vector2(350, 25))
	
	# Botões
	hud_elements["use"] = _create_mock_btn("USE", default_positions["use"], Color.YELLOW)
	hud_elements["report"] = _create_mock_btn("REPORT", default_positions["report"], Color.RED)
	hud_elements["jump"] = _create_mock_btn("JUMP", default_positions["jump"], Color(0.2, 0.6, 1.0))
	hud_elements["crouch"] = _create_mock_btn("CROUCH", default_positions["crouch"], Color(0.2, 0.6, 1.0))
	hud_elements["kill"] = _create_mock_btn("KILL", default_positions["kill"], Color.DARK_RED)
	hud_elements["sabotage"] = _create_mock_btn("SABOTAGE", default_positions["sabotage"], Color.ORANGE)
	hud_elements["mic"] = _create_mock_btn("MIC", default_positions["mic"], Color.GREEN)
	
	# Carrega configurações salvas
	var config = ConfigFile.new()
	var err = config.load("user://mobile_hud.cfg")
	var def_scale = Vector2(1.0, 1.0)
	
	for key in hud_elements.keys():
		var node = hud_elements[key]
		if config.has_section_key("HUD", key + "_pos"):
			var rel = config.get_value("HUD", key + "_pos")
			var abs_pos = rel
			
			if key == "joystick":
				abs_pos = Vector2(rel.x, rel.y + screen_size.y)
			elif key == "radar":
				abs_pos = Vector2(rel.x + screen_size.x, rel.y)
			elif key == "task_list" or key == "progress_bar":
				abs_pos = rel
			else:
				abs_pos = Vector2(rel.x + screen_size.x, rel.y + screen_size.y)
				
			hud_elements[key].position = abs_pos
				
		if config.has_section_key("HUD", key + "_scale"):
			var saved_scale = config.get_value("HUD", key + "_scale")
			if saved_scale.x > 1.2:
				hud_elements[key].scale = Vector2(1.0, 1.0)
			else:
				hud_elements[key].scale = saved_scale
		else:
			hud_elements[key].scale = def_scale

func _create_mock_btn(txt, def_pos, color, btn_size = Vector2(120, 120)):
	var p = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	style.border_width_bottom = 6
	style.border_color = color.darkened(0.5)
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	
	p.add_theme_stylebox_override("panel", style)
	p.size = btn_size
	p.position = def_pos
	p.pivot_offset = btn_size / 2.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var l = Label.new()
	l.text = txt
	l.set_anchors_preset(PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	add_child(p)
	
	return p

func _input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		# Ignora cliques na área superior (slider, botões de controle) para eles funcionarem
		if event.position.y < 160:
			return
			
		get_viewport().set_input_as_handled() # Previne que a câmera e o joystick rodem
		if event.pressed:
			# Encontra qual elemento foi tocado
			for key in hud_elements:
				var node = hud_elements[key]
				var rect = Rect2(node.global_position, node.size * node.scale)
				if rect.has_point(event.position):
					selected_node = node
					selected_key = key
					is_dragging = true
					drag_offset = node.position - event.position
					scale_slider.value = node.scale.x
					selected_label.text = "Selecionado: " + key.to_upper()
					
					# Efeito visual no selecionado
					for k in hud_elements:
						hud_elements[k].modulate = Color(1, 1, 1, 0.5)
					node.modulate = Color(1, 1, 1, 1)
					return
		else:
			is_dragging = false
			
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		# Ignora drag na área superior (slider) para o HSlider funcionar
		if event.position.y < 160:
			return
			
		get_viewport().set_input_as_handled() # Previne que a câmera e o joystick rodem
		if is_dragging and selected_node:
			selected_node.position = event.position + drag_offset

func _on_scale_changed(val):
	if selected_node:
		selected_node.scale = Vector2(val, val)

func _reset_defaults():
	for key in hud_elements.keys():
		hud_elements[key].position = default_positions[key]
		hud_elements[key].scale = Vector2(1, 1)
	scale_slider.value = 1.0
	selected_label.text = "Selecionado: Nenhum"

func _save_and_exit():
	var config = ConfigFile.new()
	var screen_size = get_viewport_rect().size
	
	for key in hud_elements.keys():
		var node = hud_elements[key]
		var rel_pos = node.position
		
		# Converte de posição absoluta (tela do Customizer) para offset relativo
		if key == "joystick":
			# Joystick fica ancorado no BOTTOM_LEFT
			rel_pos = Vector2(node.position.x, node.position.y - screen_size.y)
		elif key == "radar":
			# Radar no TOP_RIGHT
			rel_pos = Vector2(node.position.x - screen_size.x, node.position.y)
		elif key == "task_list" or key == "progress_bar":
			# Top Left
			rel_pos = node.position
		else:
			# Botões ficam ancorados no BOTTOM_RIGHT
			rel_pos = Vector2(node.position.x - screen_size.x, node.position.y - screen_size.y)
			
		config.set_value("HUD", key + "_pos", rel_pos)
		config.set_value("HUD", key + "_scale", node.scale)
	config.save("user://mobile_hud.cfg")
	
	# Atualiza a interface do jogo em tempo real sem precisar reiniciar
	var root = get_tree().get_root()
	var main = root.find_child("Main", true, false)
	if main and main.has_method("reload_hud"):
		main.reload_hud()
		
	var minimap = root.find_child("MiniMap", true, false)
	if minimap and minimap.has_method("reload_hud"):
		minimap.reload_hud()
		
	var player_hud = root.find_child("PlayerHUD", true, false)
	if player_hud and player_hud.has_method("_load_custom_hud"):
		player_hud._load_custom_hud()
		
	queue_free()
