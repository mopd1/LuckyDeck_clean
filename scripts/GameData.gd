# GameData.gd
extends Node

var current_game_data = null

func set_game_data(data: Dictionary):
	print("Debug: Setting game data in GameData:", data)
	current_game_data = data

func get_game_data():
	return current_game_data

func clear_game_data():
	current_game_data = null
