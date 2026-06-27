extends Control

var output_vector = Vector2.ZERO
var is_dragging = false
var base_radius = 80.0
var stick_radius = 30.0
var stick_pos = Vector2.ZERO

func _ready():
	custom_minimum_size = Vector2(base_radius * 2, base_radius * 2)
	stick_pos = custom_minimum_size / 2.0
	
func _gui_input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			var center = custom_minimum_size / 2.0
			if event.position.distance_to(center) <= base_radius:
				is_dragging = true
				_update_joystick(event.position)
		else:
			is_dragging = false
			stick_pos = custom_minimum_size / 2.0
			output_vector = Vector2.ZERO
			queue_redraw()
			
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and is_dragging:
		_update_joystick(event.position)

func _update_joystick(pos: Vector2):
	var center = custom_minimum_size / 2.0
	var offset = pos - center
	
	if offset.length() > base_radius:
		offset = offset.normalized() * base_radius
		
	stick_pos = center + offset
	output_vector = offset / base_radius
	queue_redraw()

func _draw():
	var center = custom_minimum_size / 2.0
	# Base transparente
	draw_circle(center, base_radius, Color(0, 0, 0, 0.3))
	draw_arc(center, base_radius, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
	
	# Stick
	draw_circle(stick_pos, stick_radius, Color(1, 1, 1, 0.6))
	draw_arc(stick_pos, stick_radius, 0, TAU, 16, Color(1, 1, 1, 0.8), 2.0)

func get_vector() -> Vector2:
	return output_vector
