extends Node

var capture_effect: AudioEffectCapture
var send_timer: Timer
@onready var mic_player = $MicPlayer
var is_muted: bool = false
var debug_label: Label
var mic_volume_multiplier: float = 1.0
var mic_is_dead: bool = false
var dead_frames_counter: int = 0

func _ready():
	if DisplayServer.get_name() == "headless":
		return
		
	if OS.get_name() == "Android":
		var granted = OS.get_granted_permissions()
		if "android.permission.RECORD_AUDIO" in granted:
			get_tree().create_timer(2.0).timeout.connect(_setup_hardware)
		else:
			OS.request_permissions()
			get_tree().create_timer(4.0).timeout.connect(_setup_hardware)
	else:
		_setup_hardware()
		
	var canvas = CanvasLayer.new()
	canvas.layer = 100 # Acima de tudo
	debug_label = Label.new()
	# Posicionado à frente da barra de progresso padrão (que está em x=20, size=350)
	debug_label.position = Vector2(380, 20)
	debug_label.add_theme_font_size_override("font_size", 24)
	canvas.add_child(debug_label)
	add_child(canvas)
				
	send_timer = Timer.new()
	send_timer.wait_time = 0.1
	send_timer.autostart = true
	send_timer.timeout.connect(_on_send_timer_timeout)
	add_child(send_timer)

func _setup_hardware():
	if mic_player and is_instance_valid(mic_player):
		mic_player.play()
	
	var record_bus_idx = AudioServer.get_bus_index("Record")
	if record_bus_idx != -1:
		for i in range(AudioServer.get_bus_effect_count(record_bus_idx) - 1, -1, -1):
			AudioServer.remove_bus_effect(record_bus_idx, i)
			
		capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(record_bus_idx, capture_effect)

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mic_player and is_instance_valid(mic_player):
			mic_player.stop()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if OS.get_name() == "Android":
			get_tree().create_timer(1.0).timeout.connect(_setup_hardware)
		else:
			_setup_hardware()

func _on_send_timer_timeout():
	if not capture_effect or not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return
		
	if multiplayer.get_peers().is_empty():
		return
		
	var frames_available = capture_effect.get_frames_available()
	
	if frames_available == 0 and OS.get_name() == "Android":
		dead_frames_counter += 1
		if dead_frames_counter > 50:
			mic_is_dead = true
	else:
		dead_frames_counter = 0
		mic_is_dead = false
	
	if frames_available > 0:
		var pcm_data = capture_effect.get_buffer(frames_available)
		var mix_rate = AudioServer.get_mix_rate()
		var target_rate = 11025.0
		var ratio = float(mix_rate) / target_rate
		
		var downsampled = PackedFloat32Array()
		var i = 0.0
		var has_sound = false
		var peak = 0.0
		
		while i < pcm_data.size():
			var idx = int(i)
			if idx < pcm_data.size():
				var mono = (pcm_data[idx].x + pcm_data[idx].y) * 0.5 * mic_volume_multiplier
				downsampled.append(mono)
				if abs(mono) > peak: peak = abs(mono)
				if abs(mono) > 0.002: # Noise Gate Bem sensível
					has_sound = true
			i += ratio
		
		if is_instance_valid(debug_label):
			if peak > 0.1 and not is_muted:
				debug_label.text = "🎤🟢"
			else:
				debug_label.text = "🎤🔴"
		
		if has_sound and not is_muted:
			var main_node = get_tree().get_root().find_child("Main", true, false)
			if main_node and is_instance_valid(main_node):
				var my_id = multiplayer.get_unique_id()
				main_node.rpc_id(1, "receive_voice_packet", my_id, downsampled)
