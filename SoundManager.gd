extends Node

# Mapa de AudioStreams carregados da raiz do projeto
var sounds = {}
var ambient_player: AudioStreamPlayer

func _ready():
	# Carregar todos os MP3 baixados pelo usuário
	sounds["step"] = load("res://soundreality-footsteps-walking-boots-parquet-1-420135.mp3")
	sounds["step_fast"] = load("res://freesounds123-running-363346.mp3")
	sounds["task_done"] = load("res://denielcz-done-463074.mp3")
	sounds["win"] = load("res://scratchonix-victory-chime-366449.mp3")
	sounds["defeat"] = load("res://phatphrogstudio-defeat-outros-game-sounds-collection-477823.mp3")
	sounds["kill"] = load("res://Stabbing.mp3")
	sounds["sabotage_alarm"] = load("res://alexis_gaming_cam-among-us-alarme-sabotage-393155.mp3")
	sounds["report"] = load("res://delon_boomkin-among-us-role-reveal-sound-effect-359833.mp3")
	
	# Inicializar o som de ambiente de fundo contínuo em Playlist Aleatória
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -15.0
	ambient_player.bus = "Master"
	add_child(ambient_player)
	
	_play_next_ambient()
	ambient_player.finished.connect(_play_next_ambient)

func _play_next_ambient():
	var tracks = [
		load("res://absolutesound-suspense-tense-atmosphere-514617.mp3"),
		load("res://absolutesound-suspense-tension-514626.mp3")
	]
	ambient_player.stream = tracks[randi() % tracks.size()]
	ambient_player.play()

func play_sound(type: String, volume_db: float = 0.0):
	if sounds.has(type) and sounds[type] != null:
		var p = AudioStreamPlayer.new()
		p.stream = sounds[type]
		p.volume_db = volume_db
		p.bus = "Master"
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func play_sound_slice(type: String, start_time: float, duration: float, volume_db: float = 0.0):
	if sounds.has(type) and sounds[type] != null:
		var p = AudioStreamPlayer.new()
		p.stream = sounds[type]
		p.volume_db = volume_db
		p.bus = "Master"
		add_child(p)
		p.play(start_time)
		get_tree().create_timer(duration).timeout.connect(p.queue_free)

func play_3d_sound(type: String, origin: Node3D, volume_db: float = 0.0, max_dist: float = 20.0):
	if sounds.has(type) and sounds[type] != null:
		var p = AudioStreamPlayer3D.new()
		p.stream = sounds[type]
		p.volume_db = volume_db
		# Configurações de propagação de som 3D
		p.unit_size = 5.0 # Quão longe o som começa a cair (em metros)
		p.max_distance = max_dist # Distância máxima em que ainda dá pra escutar
		p.attenuation_filter_cutoff_hz = 20500 # Sem abafar muito o som
		p.bus = "Master"
		
		origin.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func play_3d_footstep(origin: Node3D, is_running: bool = false):
	var type = "step_fast" if is_running else "step"
	var vol = 8.0 if is_running else 0.0 # Passo correndo muito mais alto
	
	# Parar os sons de passos atuais para não sobrepor (evita som de andar e correr ao mesmo tempo)
	stop_3d_footsteps(origin)
	
	play_3d_sound(type, origin, vol, 15.0)

func stop_3d_footsteps(origin: Node3D):
	if not sounds.has("step") or not sounds.has("step_fast"): return
	for child in origin.get_children():
		if child is AudioStreamPlayer3D:
			if child.stream == sounds["step"] or child.stream == sounds["step_fast"]:
				child.stop()
				child.queue_free()
