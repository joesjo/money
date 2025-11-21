extends Node

var IP_ADDRESS: String = "localhost"
const PORT: int = 42069

var peer: ENetMultiplayerPeer
var player_scene = preload("res://entities/player.tscn")
var players: Dictionary = {}

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_started
signal client_connected

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		push_error("Failed to create server: " + str(error))
		return
	
	multiplayer.multiplayer_peer = peer
	print("Server started on port ", PORT)
	server_started.emit()
	
	# Load the game scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(IP_ADDRESS, PORT)
	if error != OK:
		push_error("Failed to create client: " + str(error))
		return
	
	multiplayer.multiplayer_peer = peer
	print("Connecting to server at ", IP_ADDRESS, ":", PORT)

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	player_disconnected.emit(id)
	
	# Clean up disconnected player
	if players.has(id):
		if is_instance_valid(players[id]):
			players[id].queue_free()
		players.erase(id)

func _on_connected_to_server() -> void:
	print("Successfully connected to server!")
	client_connected.emit()
	
	# Load the game scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_connection_failed() -> void:
	push_error("Failed to connect to server")
	multiplayer.multiplayer_peer = null

func spawn_player(peer_id: int, spawn_position: Vector3 = Vector3.ZERO) -> void:
	if players.has(peer_id):
		return  # Player already spawned
	
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.position = spawn_position
	
	# Set authority to the owning peer
	player.set_multiplayer_authority(peer_id)
	
	# Add to scene
	get_tree().current_scene.add_child(player)
	players[peer_id] = player
	
	print("Spawned player for peer ", peer_id)

func get_player(peer_id: int) -> Node:
	return players.get(peer_id, null)

func get_local_player() -> Node:
	return get_player(multiplayer.get_unique_id())
