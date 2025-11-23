extends RigidBody3D

func _process(delta):
	# Debug print every 60 frames (approx 1 sec) to avoid spam
	if Engine.get_physics_frames() % 60 == 0:
		if get_multiplayer_authority() != 1:
			print("Box ", name, " Auth: ", get_multiplayer_authority(), " | Pos: ", global_position, " | Vel: ", linear_velocity.length(), " | Sleep: ", sleeping)
