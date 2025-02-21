class_name Player extends CharacterBody3D

@export_category("Player")
@export_range(1, 35, 1) var speed: float = 3 # m/s
@export_range(10, 400, 1) var acceleration: float = 100 # m/s^2
@export_range(1, 35, 1) var sprint_speed: float = 6 # Sprinting speed
@export_range(0.5, 3.0, 0.1) var crouch_speed: float = 1.5 # Crouching speed

@export_range(0.1, 3.0, 0.1) var jump_height: float = 1 # m
@export_range(0.1, 3.0, 0.1, "or_greater") var camera_sens: float = 1

@export var interaction_distance: float = 999.0  # Max distance to interact with the door
@onready var raycast: RayCast3D = $RayCast3D

@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@export var footstep_sound: AudioStream
var can_play_footstep: bool = true

var jumping: bool = false
var mouse_captured: bool = false
var sprinting: bool = false
var crouching: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_dir: Vector2 # Input direction for movement
var look_dir: Vector2 # Input direction for look/aim

var walk_vel: Vector3 # Walking velocity 
var grav_vel: Vector3 # Gravity velocity 
var jump_vel: Vector3 # Jumping velocity

@onready var camera: Camera3D = $Camera
@onready var collision_shape: CollisionShape3D = $CShape
@onready var Flashlight = %Flashlight

@export var interaction_ray_length: float = 2.5  # Shorter, more reasonable distance
@export var interaction_dot_threshold: float = 0.5  # For wider interaction angle
var original_height: float

# Define the timeout function first
func _on_footstep_timer_timeout() -> void:
	can_play_footstep = true
	
func _ready() -> void:
	capture_mouse()
	original_height = collision_shape.shape.height
	print("ready")
	
	# Set up footstep timer
	var timer = Timer.new()
	timer.name = "FootstepTimer"
	add_child(timer)
	timer.timeout.connect(_on_footstep_timer_timeout)
	timer.wait_time = 1.5  # Adjust this to match your walking speed
	timer.one_shot = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		look_dir = event.relative * 0.001
		if mouse_captured: _rotate_camera()
	if Input.is_action_just_pressed("jump") and is_on_floor(): jumping = true
	if Input.is_action_just_pressed("exit"): get_tree().quit()
	if Input.is_action_pressed("sprint"): 
		sprinting = true
		footstep_player.stop()
	else: sprinting = false
	if Input.is_action_just_pressed("flash"): Flashlight.visible = not Flashlight.visible

func _physics_process(delta: float) -> void:
	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	move_and_slide()
	
	if is_on_floor() and (Vector2(velocity.x, velocity.z).length() > 0.1) and can_play_footstep:
		play_footstep()
		can_play_footstep = false
		$FootstepTimer.start()
	elif not (Vector2(velocity.x, velocity.z).length() > 0.1) and footstep_player.playing:
		footstep_player.stop()
		
	if Input.is_action_just_pressed("interact"):
			var camera_forward = -camera.global_transform.basis.z
			raycast.global_transform.origin = camera.global_transform.origin
			raycast.target_position = Vector3.FORWARD * interaction_ray_length
			raycast.global_transform.basis = camera.global_transform.basis
			
			if raycast.is_colliding():
				var collision_point = raycast.get_collision_point()
				var collision_normal = raycast.get_collision_normal()
				var distance = camera.global_transform.origin.distance_to(collision_point)
				
				# Check if we're looking somewhat towards the door
				var dot_product = camera_forward.dot(-collision_normal)
				
				if distance <= interaction_ray_length and dot_product > interaction_dot_threshold:
					var collider = raycast.get_collider()
					var door = collider.get_parent().get_parent()
					if door.has_method("toggle_door"):
						door.toggle_door()

func play_footstep() -> void:
	footstep_player.play()
	
func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func _rotate_camera(sens_mod: float = 1.0) -> void:
	camera.rotation.y -= look_dir.x * camera_sens * sens_mod
	camera.rotation.x = clamp(camera.rotation.x - look_dir.y * camera_sens * sens_mod, -1.5, 1.5)

func _walk(delta: float) -> Vector3:
	move_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backwards")
	var _forward: Vector3 = camera.global_transform.basis * Vector3(move_dir.x, 0, move_dir.y)
	var walk_dir: Vector3 = Vector3(_forward.x, 0, _forward.z).normalized()
	
	var current_speed = crouch_speed if crouching else sprint_speed if sprinting else speed
	walk_vel = walk_vel.move_toward(walk_dir * current_speed * move_dir.length(), acceleration * delta)
	return walk_vel

func _gravity(delta: float) -> Vector3:
	grav_vel = Vector3.ZERO if is_on_floor() else grav_vel.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta * 1.6)
	return grav_vel

func _jump(delta: float) -> Vector3:
	if jumping:
		if is_on_floor(): jump_vel = Vector3(0, sqrt(4 * jump_height * gravity), 0)
		jumping = false
		return jump_vel
	jump_vel = Vector3.ZERO if is_on_floor() else jump_vel.move_toward(Vector3.ZERO, gravity * delta)
	return jump_vel
