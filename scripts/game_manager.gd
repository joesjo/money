extends Node3D

@onready var players_node = $Players

func _ready():
	# Only the server spawns players
	if multiplayer.is_server():
		NetworkManager.player_connected.connect(_spawn_player)
		NetworkManager.player_disconnected.connect(_remove_player)
		
		# Spawn self
		_spawn_player(1, {})
		
		# Spawn already connected players (if any)
		for id in multiplayer.get_peers():
			_spawn_player(id, {})

func _spawn_player(peer_id, _player_info):
	var player = preload("res://entities/player.tscn").instantiate()
	player.name = str(peer_id)
	# Randomize spawn position slightly to avoid stacking
	player.position = Vector3(0, 2, 0) + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	players_node.add_child(player)

func _remove_player(peer_id):
	var player = players_node.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
