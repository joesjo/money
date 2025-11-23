extends CharacterBody3D

const RUN_SPEED = 3.0
const SPRINT_SPEED = 5.0
const JUMP_VELOCITY = 4.5

const DECEL_SPEED = 10.0
const AIR_DECEL_SPEED = 3.0

const BOB_FREQUENCY = 3.0
const BOB_AMPLITUDE = 0.05

const FOV_BASE = 75.0
const FOV_SPRINT_ADDER = 8.0
const FOV_CHANGE_SPEED = 8.0

const GRAB_DISTANCE = 2.0
const GRAB_OFFSET = 1.5
const GRAB_STIFFNESS = 80.0
const GRAB_DAMPING = 6.0
const GRAB_FORCE_MULTIPLIER = 10.0
const GRAB_VISUAL_SPEED = 20.0
const MAX_GRAB_STRETCH = 0.1
const PLAYER_MASS = 80.0

@export var mouse_sensitivity: float = 2.0

@onready var camera: Camera3D = $Camera3D
@onready var hand: Node3D = $Hand

var camera_height: float
var t_bob: float = 0.0

var hand_local_position: Vector3 = Vector3.ZERO
var hand_target_position: Vector3 = Vector3.ZERO

# Synced Variables
var grabbed_object_path: NodePath = NodePath("")
var grabbed_object_local_position: Vector3 = Vector3.ZERO

# Local Reference
var grabbed_object: RigidBody3D = null
var time_since_last_grab: float = 0.0


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$InputSynchronizer.set_multiplayer_authority(str(name).to_int())
	$ServerSynchronizer.set_multiplayer_authority(1)


func _ready() -> void:
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
	
	camera_height = camera.position.y
	hand_local_position = hand.position
	hand_target_position = hand_local_position


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
		
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	
	if event.is_action_pressed("grab"):
		if grabbed_object:
			_handle_release_input()
		else:
			_handle_grab_input()


func _process(delta: float) -> void:
	_resolve_grabbed_object()
	
	if grabbed_object:
		# Visual update for hand target
		hand_target_position = to_local(grabbed_object.to_global(grabbed_object_local_position))
	
	_update_hand_position(delta)


func _physics_process(delta: float) -> void:
	_resolve_grabbed_object()
	
	# Gravity (Always apply)
	_apply_gravity(delta)
	
	# Movement (Only Authority)
	if is_multiplayer_authority():
		_handle_jump()
		
		var speed = _get_movement_speed()
		var target_fov = _get_target_fov()
		var direction = _get_movement_direction()
		
		_apply_movement(direction, speed, delta)
		_apply_headbob(delta)
		_update_camera_fov(target_fov, delta)
		
		# Apply reaction force locally if we are holding something
		if grabbed_object:
			_apply_reaction_force()
		
		move_and_slide()
	
	# Grabbing Physics (Run if we are the authority of the object)
	if grabbed_object:
		if grabbed_object.is_multiplayer_authority():
			_update_grab_physics()
	
	_update_grab_timer(delta)
	_apply_collision_forces()


func _resolve_grabbed_object() -> void:
	if grabbed_object_path.is_empty():
		if grabbed_object:
			# Client detected release via sync
			grabbed_object = null
			hand_target_position = hand_local_position
			time_since_last_grab = 0.0
		return
		
	if grabbed_object and grabbed_object.get_path() == grabbed_object_path:
		return
		
	var node = get_node_or_null(grabbed_object_path)
	if node is RigidBody3D:
		grabbed_object = node
	else:
		grabbed_object = null


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	rotate_y(-event.relative.x * mouse_sensitivity / 1000.0)
	camera.rotate_x(-event.relative.y * mouse_sensitivity / 1000.0)
	camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)


func _handle_grab_input() -> void:
	if grabbed_object == null:
		request_grab.rpc_id(1)


func _handle_release_input() -> void:
	request_release.rpc_id(1)


@rpc("call_local")
func request_grab():
	if not multiplayer.is_server():
		return
	_try_grab()


@rpc("call_local")
func request_release():
	if not multiplayer.is_server():
		return
	_release_grab()


@rpc("any_peer", "call_local", "reliable")
func set_grabbed_object_authority(obj_path: NodePath, authority_id: int):
	# Security: Only allow the Server (1) to set authority on the Client
	# Exception: The Server calls this on itself (sender_id 0 or 1)
	var sender = multiplayer.get_remote_sender_id()
	if sender != 1 and sender != 0:
		return
		
	var node = get_node_or_null(obj_path)
	if node and node is RigidBody3D:
		node.set_multiplayer_authority(authority_id)
		
		# Also update the MultiplayerSynchronizer if it exists
		var synchronizer = node.get_node_or_null("MultiplayerSynchronizer")
		if synchronizer:
			synchronizer.set_multiplayer_authority(authority_id)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY


func _update_grab_timer(delta: float) -> void:
	if grabbed_object:
		time_since_last_grab += delta


func _get_movement_speed() -> float:
	if Input.is_action_pressed("sprint"):
		return SPRINT_SPEED
	return RUN_SPEED


func _get_target_fov() -> float:
	if Input.is_action_pressed("sprint"):
		return FOV_BASE + FOV_SPRINT_ADDER
	return FOV_BASE


func _get_movement_direction() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()


func _apply_movement(direction: Vector3, speed: float, delta: float) -> void:
	var acceleration_multiplier = 2.0 if direction else 1.0
	var decel_speed = DECEL_SPEED if is_on_floor() else AIR_DECEL_SPEED
	
	if is_on_floor():
		velocity.x = lerp(velocity.x, direction.x * speed, delta * decel_speed * acceleration_multiplier)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * decel_speed * acceleration_multiplier)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * decel_speed)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * decel_speed)


func _apply_headbob(delta: float) -> void:
	t_bob += delta * max(velocity.length(), 0.5) * float(is_on_floor())
	camera.position = _headbob(t_bob) + Vector3.UP * camera_height


func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQUENCY) * BOB_AMPLITUDE
	pos.x = cos(time * BOB_FREQUENCY / 2.0) * BOB_AMPLITUDE
	return pos


func _update_camera_fov(target_fov: float, delta: float) -> void:
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_CHANGE_SPEED)


func _update_grab_physics() -> void:
	if grabbed_object:
		_grab_update()


func _update_hand_position(delta: float) -> void:
	var lerp_threshold = (1.0 / GRAB_VISUAL_SPEED) * 4.0
	
	if time_since_last_grab < lerp_threshold:
		hand.position = lerp(hand.position, hand_target_position, delta * GRAB_VISUAL_SPEED)
	else:
		hand.position = hand_target_position


func _apply_collision_forces() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is RigidBody3D:
			var impulse_magnitude = max(velocity.length(), 10.0) * 0.1
			collider.apply_central_impulse(-collision.get_normal() * impulse_magnitude)


func _grab_update() -> void:
	var target_position = camera.global_position + camera.global_transform.basis.z * -GRAB_OFFSET
	var from_position = grabbed_object.to_global(grabbed_object_local_position)
	var displacement = target_position - from_position
	
	var force = displacement * GRAB_STIFFNESS - grabbed_object.linear_velocity * GRAB_DAMPING
	var force_offset = from_position - grabbed_object.global_position
	
	grabbed_object.apply_force(force, force_offset)


func _apply_reaction_force() -> void:
	# Calculate the force that WOULD be applied to the object, and apply the opposite to player
	# This runs on Client (Authority)
	
	var target_position = camera.global_position + camera.global_transform.basis.z * -GRAB_OFFSET
	var from_position = grabbed_object.to_global(grabbed_object_local_position)
	var displacement = target_position - from_position
	
	# We don't have access to object's linear velocity perfectly synced, but we can approximate or ignore damping for reaction
	# Or we can use the visual displacement
	
	var force = displacement * GRAB_STIFFNESS
	# Ignore damping for reaction force to keep it simple and stable on client
	
	var stretch_distance = displacement.length()
	if stretch_distance > MAX_GRAB_STRETCH:
		var stretch_amount = stretch_distance - MAX_GRAB_STRETCH
		var reaction_acceleration = (-force / PLAYER_MASS) * pow(stretch_amount, 2)
		
		if not is_on_floor():
			reaction_acceleration *= 0.1
			
		velocity += reaction_acceleration


func _try_grab() -> void:
	var from = camera.global_position
	var to = from + camera.global_transform.basis * Vector3.FORWARD * GRAB_DISTANCE
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	
	if not result:
		return
	
	if not result.collider is RigidBody3D:
		return
	
	# Set synced variables
	grabbed_object = result.collider
	grabbed_object_path = grabbed_object.get_path()
	grabbed_object_local_position = grabbed_object.to_local(result.position)
	
	# Smart Authority Transfer: Only transfer if Server currently owns it
	var current_auth = grabbed_object.get_multiplayer_authority()
	
	if current_auth == 1:
		var sender_id = multiplayer.get_remote_sender_id()
		set_grabbed_object_authority.rpc(grabbed_object_path, sender_id)


func _release_grab() -> void:
	if grabbed_object:
		# Smart Authority Return: Only return if WE (the releaser) own it
		if grabbed_object.get_multiplayer_authority() == multiplayer.get_remote_sender_id():
			set_grabbed_object_authority.rpc(grabbed_object_path, 1)
			
	grabbed_object = null
	grabbed_object_path = NodePath("")
	grabbed_object_local_position = Vector3.ZERO
	hand_target_position = hand_local_position
	time_since_last_grab = 0.0
