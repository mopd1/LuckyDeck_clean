extends Control

# Reference to name labels
@onready var player_name_label = $Players/Player1/Panel/NameLabel

func _ready():
	# Connect to the player_name_updated signal in PlayerData
	if not PlayerData.is_connected("player_name_updated", _on_player_name_updated):
		PlayerData.connect("player_name_updated", _on_player_name_updated)
	
	# Initialize with current player name
	update_player_name()

func update_player_name():
	if player_name_label:
		var display_name = PlayerData.player_data["name"]
		if display_name.is_empty():
			display_name = PlayerData.player_data.get("username", "Player")
		
		player_name_label.text = display_name

func _on_player_name_updated(new_name):
	if player_name_label:
		player_name_label.text = new_name
