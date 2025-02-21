# GameJoiner.gd
extends Node

signal game_joined(game_data)
signal join_failed(reason)

const AVAILABLE_STAKES = [1000, 3000, 5000, 10000]

# Game types and their availability
var available_game_types = {
	"NL Hold'em Cash Game": true,
	"Pot Limit Omaha Cash Game": false,  # Not implemented yet
	"Jackpot SNG": true,
	"Multi Table Tournament": false  # Not implemented yet
}

func _ready():
	# Ensure minimum tables exist for each stake level
	for stake in AVAILABLE_STAKES:
		TableManager.ensure_minimum_tables(stake)

func get_game_types() -> Array:
	return available_game_types.keys()

func get_stakes(game_type: String) -> Array:
	if game_type in available_game_types and available_game_types[game_type]:
		return AVAILABLE_STAKES
	return []

func join_game(player_data: Dictionary, game_type: String, stake: int) -> void:
	print("\nDebug: Join game called with:")
	print("- Game type:", game_type)
	print("- Stake:", stake)
	print("- Player data:", player_data)
	
	# Validate game type
	if not game_type in available_game_types:
		print("Debug: Invalid game type")
		emit_signal("join_failed", "Invalid game type")
		return
	
	if not available_game_types[game_type]:
		print("Debug: Game type not available")
		emit_signal("join_failed", "Game type not available")
		return
	
	# Convert stake to int for comparison
	var stake_int = int(stake)
	if stake_int not in AVAILABLE_STAKES:
		print("Debug: Invalid stake level")
		emit_signal("join_failed", "Invalid stake level")
		return
	
	# Calculate required stack
	var required_stack = stake_int * 100  # 100 big blinds minimum
	
	# Request balance update if not initialized
	if not PlayerData.is_balance_initialized:
		print("Debug: Requesting balance update...")
		PlayerData.update_balance_from_server()
		# Wait for a maximum of 5 seconds for balance initialization
		var start_time = Time.get_ticks_msec()
		while not PlayerData.is_balance_initialized and (Time.get_ticks_msec() - start_time) < 5000:
			await get_tree().create_timer(0.1).timeout
		
		if not PlayerData.is_balance_initialized:
			print("Debug: Balance initialization timeout")
			emit_signal("join_failed", "Failed to initialize balance")
			return
	
	# Check balance
	if not PlayerData.has_sufficient_balance(required_stack):
		print("Debug: Insufficient balance")
		emit_signal("join_failed", "Insufficient balance for this stake level")
		return
	
	# Set up player data for the table
	var table_player_data = {
		"user_id": User.current_user_id,
		"name": PlayerData.player_data["name"],
		"chips": required_stack,  # Starting stack is exactly 100 BB
		"bet": 0,
		"folded": false,
		"sitting_out": false,
		"cards": [],
		"auto_post_blinds": true,
		"last_action": "",
		"last_action_amount": 0,
		"time_bank": 30.0,
		"avatar_data": PlayerData.get_avatar_data()
	}
	print("\nDebug: Setting up player data for table")
	print("Debug: Player name:", table_player_data.name)
	print("Debug: Avatar data:", table_player_data.avatar_data)
	print("Debug: Finding optimal table...")
	# Find optimal table
	var table = TableManager.find_optimal_table(stake_int, table_player_data)
	print("Debug: Found table:", table)
	if not table:
		print("Debug: No suitable table available")
		emit_signal("join_failed", "No suitable table available")
		return
	
	print("Debug: Attempting to seat player at table", table.id)
	# Try to seat the player
	var seat_index = TableManager.seat_player(table.id, table_player_data)
	print("Debug: Seat index assigned:", seat_index)
	if seat_index == -1:
		print("Debug: Failed to seat player")
		emit_signal("join_failed", "Failed to seat player")
		return
	
	# Update player's table balance
	PlayerData.player_data["total_balance"] -= required_stack
	
	# Prepare game data for client
	var game_data = {
		"table_id": table.id,
		"stake_level": stake_int,
		"seat_index": seat_index,
		"player_stack": required_stack,
		"min_buyin": table.min_buyin,
		"max_buyin": table.max_buyin,
		"game_type": game_type,
		"table_state": TableManager.get_table_data(table.id)
	}
	
	# Store in GameData for scene transition
	GameData.set_game_data(game_data)
	
	print("Debug: Successfully joined table:", table.id)
	emit_signal("game_joined", game_data)

func get_available_stakes_for_balance(game_type: String) -> Array:
	if not available_game_types.get(game_type, false):
		return []
		
	var available_stakes = []
	var current_balance = PlayerData.get_balance()
	
	for stake in AVAILABLE_STAKES:
		var required_stack = stake * 100  # 100 big blinds
		if current_balance >= required_stack:
			available_stakes.append(stake)
	
	return available_stakes

func is_stake_available(stake: int) -> bool:
	var required_stack = stake * 100
	return PlayerData.has_sufficient_balance(required_stack)
