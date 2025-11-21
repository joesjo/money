extends Control

@onready var ip_input: LineEdit = $CenterContainer/VBoxContainer/IPContainer/IPInput
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var server_button: Button = $CenterContainer/VBoxContainer/Server
@onready var client_button: Button = $CenterContainer/VBoxContainer/Client


func _ready() -> void:
	# Connect to NetworkHandler signals
	NetworkHandler.server_started.connect(_on_server_started)
	NetworkHandler.client_connected.connect(_on_client_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)


func _on_server_pressed() -> void:
	_disable_buttons()
	status_label.text = "Starting server..."
	NetworkHandler.start_server()


func _on_client_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "localhost"
	
	# Update NetworkHandler IP
	NetworkHandler.IP_ADDRESS = ip
	
	_disable_buttons()
	status_label.text = "Connecting to " + ip + "..."
	NetworkHandler.start_client()


func _on_server_started() -> void:
	status_label.text = "Server started! Loading game..."


func _on_client_connected() -> void:
	status_label.text = "Connected! Loading game..."


func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"
	status_label.modulate = Color.RED
	await get_tree().create_timer(2.0).timeout
	_enable_buttons()
	status_label.text = " "
	status_label.modulate = Color.WHITE


func _disable_buttons() -> void:
	server_button.disabled = true
	client_button.disabled = true
	ip_input.editable = false


func _enable_buttons() -> void:
	server_button.disabled = false
	client_button.disabled = false
	ip_input.editable = true
