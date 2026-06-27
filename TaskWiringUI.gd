extends Control

var colors = [Color.RED, Color.BLUE, Color.YELLOW, Color.GREEN]
var left_nodes = []
var right_nodes = []
var connections = {}
var current_drag_start = -1
var mouse_pos = Vector2.ZERO
var dragging = false

func _ready():
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var title = Label.new()
	title.text = "Ligar Fios"
	title.position = Vector2(50, 50)
	add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(800, 50)
	close_btn.pressed.connect(func(): queue_free())
	add_child(close_btn)
	
	colors.shuffle()
	var right_colors = colors.duplicate()
	right_colors.shuffle()
	
	for i in range(4):
		var btn_l = ColorRect.new()
		btn_l.color = colors[i]
		btn_l.size = Vector2(40, 40)
		btn_l.position = Vector2(200, 150 + i * 100)
		btn_l.gui_input.connect(_on_left_node_input.bind(i))
		add_child(btn_l)
		left_nodes.append(btn_l)
		
		var btn_r = ColorRect.new()
		btn_r.color = right_colors[i]
		btn_r.size = Vector2(40, 40)
		btn_r.position = Vector2(600, 150 + i * 100)
		btn_r.gui_input.connect(_on_right_node_input.bind(i))
		add_child(btn_r)
		right_nodes.append(btn_r)

func _process(delta):
	if dragging:
		mouse_pos = get_local_mouse_position()
		queue_redraw()

func _draw():
	# Desenha o fundo antes de desenhar as linhas para que elas não fiquem escuras
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.8))
	
	for i in connections:
		var p1 = left_nodes[i].position + left_nodes[i].size / 2
		var p2 = right_nodes[connections[i]].position + right_nodes[connections[i]].size / 2
		draw_line(p1, p2, left_nodes[i].color, 10)
	
	if dragging and current_drag_start != -1:
		var p1 = left_nodes[current_drag_start].position + left_nodes[current_drag_start].size / 2
		draw_line(p1, mouse_pos, left_nodes[current_drag_start].color, 10)

func _on_left_node_input(event, idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			current_drag_start = idx
			dragging = true
			connections.erase(idx)
		else:
			if dragging and current_drag_start != -1:
				# Descobre se soltou em cima de um nó direito
				for r_idx in range(4):
					var r_node = right_nodes[r_idx]
					var mouse_local = r_node.get_local_mouse_position()
					if mouse_local.x >= 0 and mouse_local.x <= r_node.size.x and mouse_local.y >= 0 and mouse_local.y <= r_node.size.y:
						if left_nodes[current_drag_start].color == r_node.color:
							connections[current_drag_start] = r_idx
							check_win()
			dragging = false
			current_drag_start = -1
		queue_redraw()

func _on_right_node_input(event, idx):
	pass # O evento de soltar o mouse fica preso no nó esquerdo que iniciou o drag!

func check_win():
	if connections.size() == 4:
		print("Fios Completados!")
		var source_console = get_meta("source_console", null)
		if source_console:
			source_console.mark_completed()
		var main_node = get_tree().get_root().get_node("Main")
		if main_node:
			main_node.finish_player_task(self)
		queue_free()
