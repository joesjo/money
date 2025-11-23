extends RigidBody3D

# These variables are synchronized via the MultiplayerSynchronizer in the scene
var sync_position: Vector3
var sync_rotation: Vector3
var sync_linear_velocity: Vector3
var sync_angular_velocity: Vector3

func _ready():
	# Initialize sync variables to current state to avoid initial jumps
	sync_position = global_position
	sync_rotation = global_rotation
	sync_linear_velocity = linear_velocity
	sync_angular_velocity = angular_velocity

func _physics_process(_delta):
	if is_multiplayer_authority():
		# Authority: Update sync variables from actual physics state
		sync_position = global_position
		sync_rotation = global_rotation
		sync_linear_velocity = linear_velocity
		sync_angular_velocity = angular_velocity
	else:
		# Non-Authority: Update actual physics state from sync variables
		# Note: For smoother movement, we could use interpolation here.
		# For now, we snap to the synced state as requested for correctness.
		global_position = sync_position
		global_rotation = sync_rotation
		linear_velocity = sync_linear_velocity
		angular_velocity = sync_angular_velocity
