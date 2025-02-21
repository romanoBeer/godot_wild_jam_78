extends Node3D

@export var open_angle: float = 135.0  # Angle to rotate the door
@export var rotation_speed: float = 2.0  # Speed of rotation

var is_open: bool = false
var target_rotation: float = 0.0

func _ready():
	print("Door1 script initialized on:", name)
	add_to_group("door")  # Add this if you haven't already
	
func _process(delta: float):
	# Smoothly rotate the door to the target rotation
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func toggle_door():
	
	if is_open:
		target_rotation = 0.0  # Close the door
		is_open = true
	else:
		target_rotation = deg_to_rad(open_angle)  # Open the door
	is_open = !is_open
