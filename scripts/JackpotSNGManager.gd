extends Node

signal game_ready(players)
signal multiplier_selected(multiplier, prize)
signal player_eliminated(player_id)

# Constants
const MULTIPLIERS = {
	1.5: 0.6995,
	3.0: 0.165,
	5.0: 0.1,
	10.0: 0.03,
	100.0: 0.005,
	1000.0: 0.0005
}

const STARTING_CHIPS: int = 1000
const PLAYER_COUNT: int = 3

# Instance variables
var rng: CryptoRNG
var registered_players: Dictionary = {}  # Dictionary of stake_level: [players]
var current_game_state: Dictionary

func _init() -> void:
	rng = CryptoRNG.new()
	registered_players = {}
	current_game_state = {
		"stake_level": 0,
		"multiplier": 1.0,
		"prize": 0,
		"players": [],
		"blind_level": 0,
		"blind_timer": 0,
		"eliminated_players": []
	}

func get_current_game_state() -> Dictionary:
	print("Debug: Getting current game state:", current_game_state)
	return current_game_state

func register_player(player_id: int, stake_level: int) -> bool:
	print("Debug: Attempting to register player:", player_id, "for stake:", stake_level)
	# First check if player has enough chips
	if player_id == User.current_user_id and not PlayerData.has_sufficient_balance(stake_level):
		print("Debug: Insufficient balance for registration")
		return false
		
	if not registered_players.has(stake_level):
		registered_players[stake_level] = []
	
	# Check if player is already registered
	for player in registered_players[stake_level]:
		if player.id == player_id:
			print("Debug: Player already registered")
			return false
			
	# Deduct stake for human player
	if player_id == User.current_user_id:
		PlayerData.update_total_balance(-stake_level)
	
	registered_players[stake_level].append({
		"id": player_id,
		"stake": stake_level,
		"registration_time": Time.get_unix_time_from_system()
	})
	print("Debug: Current registered players for stake", stake_level, ":", registered_players[stake_level])

	# Check if enough players are registered to start the game
	if registered_players[stake_level].size() >= PLAYER_COUNT:
		_start_game(stake_level)

	return true

func unregister_player(player_id: int, stake_level: int) -> void:
	if registered_players.has(stake_level):
		var was_registered = false
		for player in registered_players[stake_level]:
			if player.id == player_id:
				was_registered = true
				break
				
		registered_players[stake_level] = registered_players[stake_level].filter(
			func(p): return p.id != player_id
		)
		
		# Only return chips if player was actually registered
		if was_registered and player_id == User.current_user_id:
			PlayerData.update_total_balance(stake_level)

func _select_multiplier() -> float:
	var random = rng.get_random_float()
	var cumulative_prob = 0.0
	
	for multiplier in MULTIPLIERS.keys():
		cumulative_prob += MULTIPLIERS[multiplier]
		if random <= cumulative_prob:
			return multiplier
			
	return 1.5  # Default fallback

func _start_game(stake_level: int) -> void:
	print("Debug: Starting game with stake level:", stake_level)
	var game_players = registered_players[stake_level]
	var selected_multiplier = _select_multiplier()
	var prize = int(stake_level * selected_multiplier)

	# Update the current game state
	current_game_state = {
		"stake_level": stake_level,
		"multiplier": selected_multiplier,
		"prize": prize,
		"players": game_players.duplicate(),  # Make sure to duplicate the array
		"blind_level": 0,
		"blind_timer": 0,
		"eliminated_players": []
	}

	print("Debug: Game state initialized:", current_game_state)

	# Emit signals to notify game start
	emit_signal("game_ready", game_players)
	emit_signal("multiplier_selected", selected_multiplier, prize)

	# Transition to the game scene
	GameData.set_game_data(current_game_state)
	SceneManager.goto_scene("res://scenes/JackpotSNGScene.tscn")

func calculate_prize(multiplier: float) -> int:
	if current_game_state and current_game_state.has("stake_level"):
		return int(current_game_state.stake_level * multiplier)
	return 0

func cleanup_game() -> void:
	# Clear game state
	current_game_state = {
		"stake_level": 0,
		"multiplier": 1.0,
		"prize": 0,
		"players": [],
		"blind_level": 0,
		"blind_timer": 0,
		"eliminated_players": []
	}
	
	# Clear registrations
	registered_players.clear()
