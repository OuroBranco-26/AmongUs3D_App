extends SubViewportContainer

var camera: Camera3D
var player: Node3D

func _init():
	name = "MiniMap"
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -270
	offset_top = 20
	offset_right = -20
	offset_bottom = 270
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg_panel = Panel.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.02, 0.05, 0.1, 0.6) # Fundo translúcido escuro
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_panel)
	
	var viewport = SubViewport.new()
	viewport.size = Vector2(250, 250)
	viewport.transparent_bg = true
	add_child(viewport)
	
	# Borda Neon por Cima do Mapa
	var border_panel = Panel.new()
	border_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var border_style = StyleBoxFlat.new()
	border_style.draw_center = false # Oco no meio para ver o mapa
	border_style.border_color = Color(0.0, 0.8, 1.0, 0.9) # Ciano Neon
	border_style.border_width_left = 3
	border_style.border_width_right = 3
	border_style.border_width_top = 3
	border_style.border_width_bottom = 3
	border_style.shadow_color = Color(0.0, 0.6, 1.0, 0.5) # Glow
	border_style.shadow_size = 15
	border_panel.add_theme_stylebox_override("panel", border_style)
	border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border_panel)
	
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0 # Quão longe ele vê
	camera.position.y = 5.5 # Abaixo do teto (Y=6.0) para não ser bloqueado
	camera.rotation_degrees.x = -90 # Olhando perfeitamente para baixo
	camera.cull_mask = 1048575 # Enxerga tudo
	viewport.add_child(camera)

func _ready():
	reload_hud()

func reload_hud():
	var config = ConfigFile.new()
	if config.load("user://mobile_hud.cfg") == OK:
		if config.has_section_key("HUD", "radar_pos"):
			set_anchors_preset(Control.PRESET_TOP_LEFT) # Remove âncoras para usar posição absoluta livremente
			var rel = config.get_value("HUD", "radar_pos")
			var screen_size = get_viewport_rect().size
			position = Vector2(rel.x + screen_size.x, rel.y)
			
		pivot_offset = size / 2.0 # Escala a partir do centro
		
		if config.has_section_key("HUD", "radar_scale"):
			scale = config.get_value("HUD", "radar_scale")
		else:
			scale = Vector2(1.0, 1.0)
	else:
		scale = Vector2(1.0, 1.0)

func _process(_delta):
	if not player:
		if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			return
		player = get_tree().get_root().find_child(str(multiplayer.get_unique_id()), true, false)
	
	if player:
		camera.position.x = player.position.x
		camera.position.z = player.position.z
