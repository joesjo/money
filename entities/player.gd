extends CharacterBody3D


const RUN_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const BOB_FREQUENCY = 3.0
const BOB_AMPLITUDE = 0.05

const FOV_BASE = 75.0
const FOV_SPRINT_ADDER = 8.0

const DECEL_SPEED = 10.0
const AIR_DECEL_SPEED = 3.0

const FOV_CHANGE_SPEED = 8.0

var t_bob: float = 0.0

@onready var camera: Camera3D = $Camera3D

@export var mouse_sensitivity: float = 2

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity / 1000)
		camera.rotate_x(-event.relative.y * mouse_sensitivity / 1000)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	var speed = RUN_SPEED
	var target_fov = FOV_BASE
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
		target_fov = FOV_BASE + FOV_SPRINT_ADDER

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * DECEL_SPEED)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * DECEL_SPEED)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * AIR_DECEL_SPEED)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * AIR_DECEL_SPEED)

	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.position = _headbob(t_bob)

	camera.fov = lerp(camera.fov, target_fov, delta * FOV_CHANGE_SPEED)

	move_and_slide()

	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			c.get_collider().apply_central_impulse(-c.get_normal() * max(velocity.length(), 10.0) * 0.1)

func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQUENCY) * BOB_AMPLITUDE
	pos.x = cos(time * BOB_FREQUENCY / 2.0) * BOB_AMPLITUDE
	return pos
