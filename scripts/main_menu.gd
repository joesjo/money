extends Control

@onready var ip_input = $CenterContainer/VBoxContainer/IPInput

func _ready():
	NetworkManager.connected_to_server.connect(_on_connected_to_server)

func _on_host_pressed():
	var error = NetworkManager.host_game()
	if error == OK:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_join_pressed():
	var input_text = ip_input.text.strip_edges()
	var ip = "127.0.0.1"
	var port = 7000
	
	if not input_text.is_empty():
		var parts = input_text.split(":")
		ip = parts[0]
		if parts.size() > 1:
			port = int(parts[1])
			
	NetworkManager.join_game(ip, port)

func _on_connected_to_server():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
