extends Node3D

var spawn_points: Array[Vector3] = [
	Vector3(0, 1, 0),
	Vector3(5, 1, 5),
	Vector3(-5, 1, 5),
	Vector3(5, 1, -5),
	Vector3(-5, 1, -5)
]

var spawn_index: int = 0


func _ready() -> void:
	# Connect to NetworkHandler signals
	NetworkHandler.player_connected.connect(_on_player_connected)
	NetworkHandler.player_disconnected.connect(_on_player_disconnected)
	
	# Spawn the local player
	if multiplayer.is_server():
		# Server spawns immediately
		_spawn_local_player()
	else:
		# Client waits a moment then requests to spawn
		await get_tree().create_timer(0.1).timeout
		request_spawn_for_client.rpc_id(1)


func _spawn_local_player() -> void:
	var peer_id = multiplayer.get_unique_id()
	var spawn_pos = _get_next_spawn_point()
	NetworkHandler.spawn_player(peer_id, spawn_pos)


@rpc("any_peer", "call_local", "reliable")
func request_spawn_for_client() -> void:
	if not multiplayer.is_server():
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	print("Server: Received spawn request from peer ", peer_id)
	
	# Spawn the requesting player on all clients
	var spawn_pos = _get_next_spawn_point()
	spawn_player_on_clients.rpc(peer_id, spawn_pos)
	
	# Send all existing players to the new client
	for existing_peer_id in NetworkHandler.players.keys():
		if existing_peer_id != peer_id and is_instance_valid(NetworkHandler.players[existing_peer_id]):
			var existing_player = NetworkHandler.players[existing_peer_id]
			spawn_player_on_clients.rpc_id(peer_id, existing_peer_id, existing_player.position)


@rpc("authority", "call_local", "reliable")
func spawn_player_on_clients(peer_id: int, spawn_pos: Vector3) -> void:
	print("Spawning player ", peer_id, " at ", spawn_pos)
	NetworkHandler.spawn_player(peer_id, spawn_pos)


func _on_player_connected(peer_id: int) -> void:
	print("Main scene: Player connected: ", peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	print("Main scene: Player disconnected: ", peer_id)


func _get_next_spawn_point() -> Vector3:
	var spawn_pos = spawn_points[spawn_index % spawn_points.size()]
	spawn_index += 1
	return spawn_pos


func _input(event: InputEvent) -> void:
	# Allow ESC to release mouse
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

