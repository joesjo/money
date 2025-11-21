extends RigidBody3D

# This script synchronizes RigidBody3D physics across the network
# The server is authoritative - it simulates physics and sends updates to clients

@onready var sync_position: Vector3 = position
@onready var sync_rotation: Vector3 = rotation
@onready var sync_linear_velocity: Vector3 = linear_velocity
@onready var sync_angular_velocity: Vector3 = angular_velocity

var is_server: bool = false
var predicted_position: Vector3 = Vector3.ZERO
var predicted_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	is_server = multiplayer.is_server()
	
	if not is_server:
		# Clients don't simulate physics - they receive updates from server
		freeze = true
		# But we still want collision detection for grabbing
		contact_monitor = true
		max_contacts_reported = 4
		predicted_position = position
		predicted_rotation = rotation


func _physics_process(delta: float) -> void:
	if is_server:
		# Server: Update sync variables with current state
		sync_position = position
		sync_rotation = rotation
		sync_linear_velocity = linear_velocity
		sync_angular_velocity = angular_velocity
	else:
		# Clients: Use prediction + interpolation for smoother movement
		
		# Predict next position based on velocity
		predicted_position += sync_linear_velocity * delta
		predicted_rotation += sync_angular_velocity * delta
		
		# Interpolate between predicted and actual synced position
		var target_pos = sync_position.lerp(predicted_position, 0.2)
		var target_rot = sync_rotation.lerp(predicted_rotation, 0.2)
		
		# Smooth interpolation to target
		position = position.lerp(target_pos, 0.5)
		rotation = rotation.lerp(target_rot, 0.5)
		
		# Gradually correct prediction toward synced values
		predicted_position = predicted_position.lerp(sync_position, 0.2)
		predicted_rotation = predicted_rotation.lerp(sync_rotation, 0.2)

