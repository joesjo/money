extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected
signal connected_to_server
signal connection_failed

const PORT = 7000
const MAX_CLIENTS = 10

var _players_spawn_node: Node3D

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port = PORT):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		print("Failed to create server: " + str(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Server started on port " + str(port))
	return OK

func join_game(address = "127.0.0.1", port = PORT):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		print("Failed to create client: " + str(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Joining server at " + address + ":" + str(port))
	return OK

func _on_peer_connected(id):
	print("Peer connected: " + str(id))
	player_connected.emit(id, {})

func _on_peer_disconnected(id):
	print("Peer disconnected: " + str(id))
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("Connected to server!")
	connected_to_server.emit()

func _on_connection_failed():
	print("Connection failed!")
	connection_failed.emit()

func _on_server_disconnected():
	print("Server disconnected!")
	server_disconnected.emit()
	multiplayer.multiplayer_peer = null
