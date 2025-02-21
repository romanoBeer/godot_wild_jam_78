extends CharacterBody3D

enum State {
WANDER,
CHASE
}

@export_group("Movement")
@export var walking_speed: float = 4.0
@export var chasing_speed: float = 8.0
@export var acceleration: float = 10.0
@export var wander_radius: float = 40.0
@export var wander_time: float = 60.0

@onready var player: Node3D = get_tree().get_first_node_in_group("Player")
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var is_chasing: bool
@onready var is_searching: bool
@onready var radar: int = 0
@onready var bigger_detector = $BiggerDetector
@onready var anim = $wendigo_character/AnimationPlayer
@onready var SPEED = chasing_speed
@onready var you_are_fucked := false
@onready var wander_timer = wander_time
@onready var current_state: State = State.WANDER
@onready var random_pos: Vector3

var is_in_bigger_detector: bool
var last_pos: Vector3
var has_seen: bool

func _ready() -> void:
	if !player:
		push_error("Player node not found! Ensure there's a node in the 'Player' group")
		return
	
# Initialize random position after we confirm player exists
	random_pos = Vector3(
		randf_range(-75, 50),
		global_position.y,
		randf_range(-85, 20)
	)
	wandering(0)

func _process(delta: float) -> void:
	if !player:
		return
		
	match current_state:
		State.CHASE:
			chase()
			SPEED = chasing_speed
			anim.speed_scale = 2.0
		State.WANDER:
			wandering(delta)
			SPEED = walking_speed
			anim.speed_scale = 1.0

	var direction = nav_agent.get_next_path_position() - global_position
	direction = direction.normalized()

	velocity = velocity.lerp(direction * SPEED, delta * acceleration)

	move_and_slide()

func chase() -> void:
	if !player:
		return
		
	var look_dir: Vector3 = player.global_position - global_position
	look_dir.y = 0
	if look_dir != Vector3.ZERO:
		global_transform = global_transform.looking_at(
			global_position + look_dir,
			Vector3.UP
		)
		if !anim.is_playing() or anim.current_animation != "run_1":
			anim.play("run_1")
			
	nav_agent.target_position = player.global_position

func wandering(delta: float) -> void:
	if !player:
		return
		
	if velocity != Vector3.ZERO:
		look_at(global_position + velocity)
		if !anim.is_playing() or anim.current_animation != "walk":
			anim.play("walk")
	else:
		if !anim.is_playing() or anim.current_animation != "idle":
			anim.play("idle")

	nav_agent.target_position = random_pos

	var distance_to_target := Vector2(
		random_pos.x - global_position.x,
		random_pos.z - global_position.z
	).length()

	if distance_to_target <= 5.0 or wander_timer <= 0.0:
		var random_angle := randf() * TAU
		var random_radius := randf_range(20.0, wander_radius)
		var offset := Vector2.from_angle(random_angle) * random_radius
		
		random_pos = Vector3(
			clamp(player.global_position.x + offset.x, -75.0, 50.0),
			global_position.y,
			clamp(player.global_position.z + offset.y, -85.0, 20.0)
		)
		wander_timer = wander_time

	wander_timer -= delta

func _on_bigger_detector_body_entered(body: Node3D) -> void:
	is_in_bigger_detector = true

func _on_bigger_detector_body_exited(body: Node3D) -> void:
	is_in_bigger_detector = false
	current_state = State.WANDER
	is_chasing = false

func _on_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		current_state = State.CHASE
		is_chasing = true

func _on_detector_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		last_pos = body.global_position
		random_pos = last_pos
		current_state = State.WANDER
		is_chasing = false
