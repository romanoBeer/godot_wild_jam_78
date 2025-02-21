extends Node3D

@onready var spot_light = $SpotLight3D

var rotation_speed = 1.5  # Rotations per second
var is_active = true

func _process(delta):
	if is_active:
		rotate_y(rotation_speed * TAU * delta)

func activate():
	is_active = true

func deactivate():
	is_active = false
