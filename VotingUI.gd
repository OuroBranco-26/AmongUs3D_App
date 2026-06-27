extends Control

var all_players = [] 
var phase = "DISCUSSION" # DISCUSSION, VOTING, RESULTS
var time_left = 30.0
var user_has_voted = false

var chat_history: RichTextLabel
var chat_input: LineEdit
var time_label: Label
var players_grid: GridContainer

var bot_phrases = [
	"Onde foi o corpo?",
	"Quem?",
	"Acho que vi alguém perto da elétrica...",
	"Eu tava na navegação fazendo task.",
	"Alguém tem scan?",
	"Muito suspeito...",
	"Vou dar skip dessa vez",
	"Foi o impostor com certeza",
	"Aonde?",
	"Por que apertaram o botão?"
]

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var sm = get_tree().get_root().get_node_or_null("Main/SoundManager")
	if sm: sm.play_sound("report", 0.0)
	
	# Fundo Translucido
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.08, 0.15, 0.95)
	add_child(bg)
	
	_gather_players()
	_build_ui()
	
	# Agenda as falas iniciais dos Bots
	for i in range(all_players.size()):
		var p = all_players[i]
		if not p["is_player"] and not p["is_dead"] and p["name"] != "PULAR VOTO":
			_schedule_bot_chat(p)

func _process(delta):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	for p in all_players:
		if p.has("speaker_icon") and is_instance_valid(p["speaker_icon"]):
			var node = p.get("node")
			if is_instance_valid(node) and node.get("speaking_time_left") != null:
				p["speaker_icon"].visible = (node.speaking_time_left > 0)
	
	if phase == "RESULTS":
		return
		
	time_left -= delta
	if time_left <= 0:
		if phase == "DISCUSSION":
			phase = "VOTING"
			time_left = 60.0
			_enable_voting_buttons()
			_schedule_ai_votes()
			_add_chat_message("SISTEMA", "A Votação começou!", Color.YELLOW)
		elif phase == "VOTING":
			_force_skip_unvoted()
			_calculate_results()
			
	if is_instance_valid(time_label):
		if phase == "DISCUSSION":
			time_label.text = "Tempo de Discussão: " + str(int(time_left)) + "s"
			time_label.add_theme_color_override("font_color", Color.AQUA)
		elif phase == "VOTING":
			time_label.text = "Tempo de Votação: " + str(int(time_left)) + "s"
			time_label.add_theme_color_override("font_color", Color.ORANGE)

func _gather_players():
	var players_node = get_tree().get_root().find_child("Players", true, false)
	if players_node:
		for p in players_node.get_children():
			var p_name = p.get("player_name")
			if p_name == null or p_name == "": p_name = "Jogador"
			var p_color = p.get("base_color")
			if p_color == null: p_color = Color.CYAN
			
			var is_me = (p.name == str(multiplayer.get_unique_id()))
			
			all_players.append({
				"name": p_name,
				"is_player": true,
				"node": p,
				"is_dead": p.get("is_dead"),
				"color": p_color,
				"votes": 0,
				"has_voted": false,
				"is_me": is_me
			})
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		all_players.append({
			"name": e.get("color_name"),
			"is_player": false,
			"node": e,
			"is_dead": e.get("is_dead"),
			"color": e.get("base_color"),
			"votes": 0,
			"has_voted": false,
			"is_me": false
		})
		
	# Teleporta todo mundo vivo para a mesa da Cafeteria em círculo
	var spawn_center = Vector3(0, 0, -32)
	var alive_count = 0
	for p in all_players:
		if not p["is_dead"]:
			alive_count += 1
			
	var current_idx = 0
	var radius = 2.5
	for p in all_players:
		if not p["is_dead"] and is_instance_valid(p["node"]):
			var angle = (float(current_idx) / alive_count) * TAU
			var pos = spawn_center + Vector3(cos(angle) * radius, 2.0, sin(angle) * radius)
			p["node"].global_position = pos
			p["node"].look_at(spawn_center, Vector3.UP)
			p["node"].rotation.x = 0
			p["node"].rotation.z = 0
			current_idx += 1
			
	# Adiciona o Pular Voto
	all_players.append({
		"name": "PULAR VOTO",
		"is_player": false,
		"node": null,
		"is_dead": false,
		"color": Color.GRAY,
		"votes": 0,
		"has_voted": false
	})

func _build_ui():
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	main_hbox.add_theme_constant_override("separation", 20)
	
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		pass
		
	add_child(main_hbox)
	
	# === COLUNA ESQUERDA: JOGADORES ===
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_vbox)
	
	var title = Label.new()
	title.text = "QUEM É O IMPOSTOR?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	left_vbox.add_child(title)
	
	time_label = Label.new()
	time_label.text = "Tempo: " + str(int(time_left))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 20)
	left_vbox.add_child(time_label)
	
	var scroll_players = ScrollContainer.new()
	scroll_players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll_players)
	
	players_grid = GridContainer.new()
	players_grid.columns = 2
	players_grid.add_theme_constant_override("h_separation", 20)
	players_grid.add_theme_constant_override("v_separation", 15)
	scroll_players.add_child(players_grid)
	
	for i in range(all_players.size()):
		var p = all_players[i]
		
		# Placa do Jogador
		var panel = PanelContainer.new()
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
		p_style.corner_radius_top_left = 10
		p_style.corner_radius_top_right = 10
		p_style.corner_radius_bottom_left = 10
		p_style.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", p_style)
		players_grid.add_child(panel)
		
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(230, 60)
		panel.add_child(hbox)
		
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(40, 40)
		color_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		color_rect.color = p["color"]
		hbox.add_child(color_rect)
		
		var speaker_icon = Label.new()
		speaker_icon.text = "🔊"
		speaker_icon.add_theme_font_size_override("font_size", 20)
		speaker_icon.add_theme_color_override("font_color", Color.GREEN)
		speaker_icon.visible = false
		hbox.add_child(speaker_icon)
		p["speaker_icon"] = speaker_icon
		
		var btn = Button.new()
		if p.get("is_me", false):
			btn.text = p["name"] + " (Você)"
			btn.add_theme_color_override("font_color", Color.CYAN)
		else:
			btn.text = p["name"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = true # Desativado durante discussão
		
		# Salva a referência do botão no dicionário para ativá-lo depois
		p["button"] = btn
		
		if p["is_dead"]:
			btn.text += " (MORTO)"
			btn.add_theme_color_override("font_disabled_color", Color.RED)
		else:
			btn.pressed.connect(_on_vote.bind(i))
		
		hbox.add_child(btn)
		
		# Label de contagem de votos em tempo real
		var vote_label = Label.new()
		vote_label.name = "VoteLabel"
		vote_label.text = "0"
		vote_label.add_theme_font_size_override("font_size", 22)
		vote_label.add_theme_color_override("font_color", Color.YELLOW)
		vote_label.custom_minimum_size = Vector2(30, 0)
		vote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(vote_label)
		p["vote_label"] = vote_label
		
		# Container para mostrar bolinhas de votos
		var votes_container = HBoxContainer.new()
		votes_container.name = "VotesContainer"
		hbox.add_child(votes_container)
		p["votes_container"] = votes_container

	# === COLUNA DIREITA: CHAT ===
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(350, 0)
	main_hbox.add_child(right_vbox)
	
	var chat_title = Label.new()
	chat_title.text = "CHAT"
	chat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chat_title.add_theme_font_size_override("font_size", 24)
	right_vbox.add_child(chat_title)
	
	var chat_panel = PanelContainer.new()
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0, 0, 0, 0.5)
	c_style.corner_radius_top_left = 10
	c_style.corner_radius_top_right = 10
	c_style.corner_radius_bottom_left = 10
	c_style.corner_radius_bottom_right = 10
	chat_panel.add_theme_stylebox_override("panel", c_style)
	right_vbox.add_child(chat_panel)
	
	var chat_scroll = ScrollContainer.new()
	chat_panel.add_child(chat_scroll)
	
	chat_history = RichTextLabel.new()
	chat_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_history.bbcode_enabled = true
	chat_history.scroll_following = true
	chat_scroll.add_child(chat_history)
	
	var input_hbox = HBoxContainer.new()
	right_vbox.add_child(input_hbox)
	
	chat_input = LineEdit.new()
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.placeholder_text = "Digite sua mensagem..."
	chat_input.text_submitted.connect(_on_chat_submit)
	input_hbox.add_child(chat_input)
	
	var send_btn = Button.new()
	send_btn.text = "ENVIAR"
	send_btn.pressed.connect(func(): _on_chat_submit(chat_input.text))
	input_hbox.add_child(send_btn)
	
	_add_chat_message("SISTEMA", "Reunião de Emergência Convocada!", Color.RED)

# === SISTEMA DE CHAT ===
@rpc("any_peer", "call_local")
func rpc_send_chat(sender_name: String, msg: String, hex_color: String):
	var bbcode = "[color=#%s][b]%s:[/b][/color] %s\n" % [hex_color, sender_name, msg]
	chat_history.append_text(bbcode)

func _add_chat_message(sender_name: String, msg: String, color: Color):
	rpc("rpc_send_chat", sender_name, msg, color.to_html(false))

func _on_chat_submit(msg: String):
	if msg.strip_edges() == "": return
	var my_name = "Jogador"
	for p in all_players:
		if p.get("is_me", false):
			my_name = p["name"]
			break
	_add_chat_message(my_name, msg, Color.WHITE)
	chat_input.text = ""

func _schedule_bot_chat(bot_p):
	# Bot envia mensagem num momento aleatório entre 2s e 25s da fase de discussão
	var wait_time = randf_range(2.0, 25.0)
	get_tree().create_timer(wait_time).timeout.connect(func():
		if phase == "DISCUSSION" and is_instance_valid(self):
			var msg = bot_phrases[randi() % bot_phrases.size()]
			_add_chat_message(bot_p["name"], msg, bot_p["color"])
	)

# === SISTEMA DE VOTAÇÃO ===
func _enable_voting_buttons():
	for p in all_players:
		if is_instance_valid(p.get("button")) and not p["is_dead"]:
			p["button"].disabled = false

@rpc("any_peer", "call_local")
func rpc_register_vote(voter_name: String, target_name: String):
	for p in all_players:
		if p["name"] == target_name:
			p["votes"] += 1
			if not p.has("voters"):
				p["voters"] = []
			
			var voter_color = Color.WHITE
			for vp in all_players:
				if vp["name"] == voter_name:
					voter_color = vp["color"]
					vp["has_voted"] = true
					break
			p["voters"].append(voter_color)
			
			# Atualiza contagem visual em tempo real
			if is_instance_valid(p.get("vote_label")):
				p["vote_label"].text = str(p["votes"])
				if p["votes"] >= 2:
					p["vote_label"].add_theme_color_override("font_color", Color.RED)
			
			# Adiciona bolinha colorida do votante
			if is_instance_valid(p.get("votes_container")):
				var dot = ColorRect.new()
				dot.custom_minimum_size = Vector2(12, 12)
				dot.color = voter_color
				p["votes_container"].add_child(dot)
			break

func _on_vote(idx_voted):
	if user_has_voted or phase != "VOTING": return
	user_has_voted = true
	
	var target_name = all_players[idx_voted]["name"]
	var my_name = "Jogador"
	for p in all_players:
		if p.get("is_me", false):
			my_name = p["name"]
			break
	rpc("rpc_register_vote", my_name, target_name)
	
	# Desativa botões do jogador
	for p in all_players:
		if is_instance_valid(p.get("button")):
			p["button"].disabled = true
			
	_add_chat_message("SISTEMA", "Você votou. Aguardando outros jogadores...", Color.GRAY)

func _schedule_ai_votes():
	var valid_targets = []
	for i in range(all_players.size()):
		if not all_players[i]["is_dead"]:
			valid_targets.append(i)
			
	for p in all_players:
		if not p["is_player"] and not p["is_dead"] and p["name"] != "PULAR VOTO":
			var wait_time = randf_range(5.0, 50.0) # Votação dura 60s
			get_tree().create_timer(wait_time).timeout.connect(func():
				if phase == "VOTING" and not p["has_voted"] and is_instance_valid(self):
					p["has_voted"] = true
					var random_target = valid_targets[randi() % valid_targets.size()]
					var target_name = all_players[random_target]["name"]
					rpc("rpc_register_vote", p["name"], target_name)
					_add_chat_message("SISTEMA", p["name"] + " votou.", Color.GRAY)
			)

func _force_skip_unvoted():
	var skip_idx = all_players.size() - 1 # Pular Voto é o último
	var target_name = all_players[skip_idx]["name"]
	for p in all_players:
		if not p["is_dead"] and not p["has_voted"]:
			p["has_voted"] = true
			rpc("rpc_register_vote", p["name"], target_name)

func _calculate_results():
	phase = "RESULTS"
	
	# Exibe as bolinhas de voto (Colored Dots)
	for p in all_players:
		if p.has("voters") and is_instance_valid(p.get("votes_container")):
			for vc in p["voters"]:
				var dot = ColorRect.new()
				dot.custom_minimum_size = Vector2(15, 15)
				dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				dot.color = vc
				p["votes_container"].add_child(dot)
	
	# Desativa botões para mostrar os resultados
	for p in all_players:
		if is_instance_valid(p.get("button")):
			p["button"].disabled = true
			p["button"].text += " (" + str(p["votes"]) + " votos)"
			
	var highest_votes = -1
	var highest_idx = -1
	var is_tie = false
	
	for i in range(all_players.size()):
		var v = all_players[i]["votes"]
		if v > highest_votes:
			highest_votes = v
			highest_idx = i
			is_tie = false
		elif v == highest_votes:
			is_tie = true
			
	var result_label = Label.new()
	result_label.set_anchors_preset(PRESET_CENTER)
	result_label.position = Vector2(400, 300)
	result_label.add_theme_font_size_override("font_size", 30)
	add_child(result_label)
	
	if is_tie or all_players[highest_idx]["name"] == "PULAR VOTO":
		result_label.text = "Ninguém foi ejetado. (Empate ou Pularam)"
	else:
		var ejected = all_players[highest_idx]
		result_label.text = ejected["name"] + " foi ejetado com " + str(highest_votes) + " votos!"
		
		if ejected["is_player"]:
			result_label.text += "\n\nVOCÊ FOI EJETADO!"
			result_label.add_theme_color_override("font_color", Color.RED)
			if ejected["node"].has_method("eject"):
				ejected["node"].rpc("eject")
		else:
			if ejected["node"].has_method("eject"):
				ejected["node"].rpc("eject")
	
	await get_tree().create_timer(7.0).timeout
	_end_meeting()

func _end_meeting():
	var root = get_tree().get_root()
	var player = root.find_child(str(multiplayer.get_unique_id()), true, false)
	if player:
		# Volta pra posição aleatória na cafeteria
		player.global_position = Vector3(randf_range(-2, 2), 2, randf_range(-28, -24))
	
	for e in get_tree().get_nodes_in_group("enemies"):
		e.global_position = Vector3(randf_range(-4, 4), 0, randf_range(-32, -26))
		if e.has_method("_pick_random_target"):
			e._pick_random_target()
		e.set("body_reported", false) # Reseta flag
		
	# Limpa os corpos
	for child in get_tree().get_nodes_in_group("dead_bodies"):
		child.queue_free()
			
	var hud = root.get_node_or_null("Main/CanvasLayer/PlayerHUD")
	if hud:
		hud.visible = true
	var minimap = root.get_node_or_null("Main/CanvasLayer/MiniMap")
	if minimap:
		minimap.visible = true
			
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
