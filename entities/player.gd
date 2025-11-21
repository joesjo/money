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

var grabbed_object: RigidBody3D = null
var grabbed_object_local_position: Vector3 = Vector3.ZERO
var time_since_last_grab: float = 0.0

# Multiplayer variables
var camera_rotation: float = 0.0
var is_local_player: bool = false
var grab_target_position: Vector3 = Vector3.ZERO  # For network sync
var smoothed_grab_target: Vector3 = Vector3.ZERO  # Smoothed target for network
var last_rpc_time: float = 0.0  # Rate limiting for RPCs


func _ready() -> void:
	# Check if this is the local player
	is_local_player = is_multiplayer_authority()
	
	if is_local_player:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
	else:
		# Disable camera for remote players
		camera.current = false
		# Make remote players visible
		$MeshInstance3D.material_override = load_remote_material()
	
	camera_height = camera.position.y
	hand_local_position = hand.position
	hand_target_position = hand_local_position


func load_remote_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.8, 1.0)  # Blue tint for other players
	return mat


func _input(event: InputEvent) -> void:
	if not is_local_player:
		return
	
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	
	if event.is_action_pressed("grab"):
		_handle_grab_input()
	elif event.is_action_released("grab"):
		_handle_release_input()


func _process(delta: float) -> void:
	if grabbed_object:
		hand_target_position = to_local(grabbed_object.to_global(grabbed_object_local_position))
	
	# Update hand position for all players
	_update_hand_position(delta)
	
	# Sync position and rotation to other clients
	if is_local_player:
		sync_transform.rpc(position, rotation.y, camera_rotation, hand.position)


@rpc("any_peer", "unreliable", "call_remote")
func sync_transform(pos: Vector3, rot_y: float, cam_rot: float, hand_pos: Vector3) -> void:
	# Only remote players receive and apply this
	# Interpolate position for smooth movement
	position = position.lerp(pos, 0.3)
	rotation.y = lerp_angle(rotation.y, rot_y, 0.3)
	camera_rotation = lerp_angle(camera_rotation, cam_rot, 0.3)
	camera.rotation.x = camera_rotation
	
	# Sync hand position (already interpolated, so set directly for smooth appearance)
	hand_target_position = hand_pos


func _physics_process(delta: float) -> void:
	if not is_local_player:
		return  # Remote players are controlled via network sync
	
	_apply_gravity(delta)
	_handle_jump()
	_update_grab_timer(delta)
	
	var speed = _get_movement_speed()
	var target_fov = _get_target_fov()
	var direction = _get_movement_direction()
	
	_apply_movement(direction, speed, delta)
	_apply_headbob(delta)
	_update_camera_fov(target_fov, delta)
	_update_grab_physics()
	
	move_and_slide()
	
	_apply_collision_forces()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	rotate_y(-event.relative.x * mouse_sensitivity / 1000.0)
	camera.rotate_x(-event.relative.y * mouse_sensitivity / 1000.0)
	camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)
	camera_rotation = camera.rotation.x


func _handle_grab_input() -> void:
	if grabbed_object == null:
		_try_grab()


func _handle_release_input() -> void:
	if grabbed_object != null:
		_release_grab()


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
			var impulse = -collision.get_normal() * impulse_magnitude
			
			# Apply physics on server
			if multiplayer.is_server():
				collider.apply_central_impulse(impulse)
			else:
				apply_collision_impulse_on_server.rpc_id(1, collider.name, impulse)


func _grab_update() -> void:
	grab_target_position = camera.global_position + camera.global_transform.basis.z * -GRAB_OFFSET
	
	if multiplayer.is_server():
		# Server calculates forces and applies them to object
		var from_position = grabbed_object.to_global(grabbed_object_local_position)
		var displacement = grab_target_position - from_position
		
		var force = displacement * GRAB_STIFFNESS - grabbed_object.linear_velocity * GRAB_DAMPING
		var force_offset = from_position - grabbed_object.global_position
		
		# Apply force (small deadzone to prevent micro-jitter)
		if force.length() > 0.1:
			grabbed_object.apply_force(force, force_offset)
		
		# Apply player stretch reaction
		var stretch_distance = displacement.length()
		if stretch_distance > MAX_GRAB_STRETCH:
			var stretch_amount = stretch_distance - MAX_GRAB_STRETCH
			var reaction_acceleration = (-force / PLAYER_MASS) * pow(stretch_amount, 2)
			
			if not is_on_floor():
				reaction_acceleration *= 0.1
			
			velocity += reaction_acceleration
	else:
		# Client: Send grab target to server with minimal smoothing
		smoothed_grab_target = smoothed_grab_target.lerp(grab_target_position, 0.5)
		
		# Rate limit RPC calls to reduce bandwidth (but not too much)
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_rpc_time > 0.033:  # Max 30 updates per second
			# Send object name instead of full path to avoid path resolution issues
			var object_name = grabbed_object.name
			update_grab_target_on_server.rpc_id(1, object_name, grabbed_object_local_position, smoothed_grab_target)
			last_rpc_time = current_time
		
		# Client still calculates stretch reaction locally for responsive feel
		var from_position = grabbed_object.to_global(grabbed_object_local_position)
		var displacement = grab_target_position - from_position
		var stretch_distance = displacement.length()
		
		if stretch_distance > MAX_GRAB_STRETCH:
			var stretch_amount = stretch_distance - MAX_GRAB_STRETCH
			# Estimate force for reaction
			var estimated_force = displacement * GRAB_STIFFNESS * 0.8  # Slightly reduced for client
			var reaction_acceleration = (-estimated_force / PLAYER_MASS) * pow(stretch_amount, 2)
			
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
	
	print(result)
	
	grabbed_object = result.collider
	grabbed_object_local_position = grabbed_object.to_local(result.position)
	
	# Initialize smoothed target to current position (prevents initial jerk)
	grab_target_position = camera.global_position + camera.global_transform.basis.z * -GRAB_OFFSET
	smoothed_grab_target = grab_target_position
	
	# Notify other clients about the grab
	if is_local_player:
		sync_grab.rpc(grabbed_object.name, grabbed_object_local_position)


func _release_grab() -> void:
	grabbed_object = null
	grabbed_object_local_position = Vector3.ZERO
	hand_target_position = hand_local_position
	time_since_last_grab = 0.0
	
	# Notify other clients about the release
	if is_local_player:
		sync_release.rpc()


@rpc("any_peer", "call_remote")
func sync_grab(object_name: String, local_pos: Vector3) -> void:
	# Find object by name in the main scene
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
	
	var obj = main_scene.get_node_or_null(object_name)
	if obj and obj is RigidBody3D:
		grabbed_object = obj
		grabbed_object_local_position = local_pos


@rpc("any_peer", "call_remote")
func sync_release() -> void:
	grabbed_object = null
	grabbed_object_local_position = Vector3.ZERO
	hand_target_position = hand_local_position
	time_since_last_grab = 0.0


@rpc("any_peer", "unreliable")
func update_grab_target_on_server(object_name: String, obj_local_pos: Vector3, target_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	
	# Server finds object by name in the main scene
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
	
	var obj = main_scene.get_node_or_null(object_name)
	if obj and obj is RigidBody3D and not obj.freeze:
		var from_position = obj.to_global(obj_local_pos)
		var displacement = target_pos - from_position
		
		# Use slightly higher damping for network grabs to reduce oscillation
		var network_damping = GRAB_DAMPING * 1.2
		var force = displacement * GRAB_STIFFNESS - obj.linear_velocity * network_damping
		var force_offset = from_position - obj.global_position
		
		# Apply force (small deadzone to prevent micro-jitter)
		if force.length() > 0.1:
			obj.apply_force(force, force_offset)


@rpc("any_peer", "unreliable")
func apply_collision_impulse_on_server(object_name: String, impulse: Vector3) -> void:
	if not multiplayer.is_server():
		return
	
	# Server finds object by name in the main scene
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
	
	var obj = main_scene.get_node_or_null(object_name)
	if obj and obj is RigidBody3D and not obj.freeze:
		obj.apply_central_impulse(impulse)
