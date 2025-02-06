# PokerTestScene.gd
extends Control

var current_table_id: String
var test_players = []
var current_player_index = 0

@onready var test_output = $TestOutput
@onready var raise_amount = $TestControls/RaiseAmount
@onready var return_to_hub_button = $ReturnToHubButton
@onready var dealer_button = $DealerButton

func _ready():
	# Connect button signals
	$TestControls/AddPlayerButton.pressed.connect(_on_add_player_pressed)
	$TestControls/RemovePlayerButton.pressed.connect(_on_remove_player_pressed)
	$TestControls/StartHandButton.pressed.connect(_on_start_hand_pressed)
	$TestControls/SimulateHandButton.pressed.connect(_on_simulate_hand_pressed)
	$TestControls/TestAllInButton.pressed.connect(_on_test_all_in_pressed)
	$TestControls/TestSidePotButton.pressed.connect(_on_test_side_pot_pressed)
	$TestControls/ClearButton.pressed.connect(_on_clear_pressed)
	$TestControls/FoldButton.pressed.connect(_on_fold_pressed)
	$TestControls/CallButton.pressed.connect(_on_call_pressed)
	$TestControls/RaiseButton.pressed.connect(_on_raise_pressed)
	return_to_hub_button.pressed.connect(_on_return_to_hub_pressed)
	
	# Connect to TableManager signals
	TableManager.tables_updated.connect(_on_tables_updated)
	TableManager.player_seated.connect(_on_player_seated)
	TableManager.player_left.connect(_on_player_left)
	
	# Initialize test table
	_initialize_test_table()

func _initialize_test_table():
	# Create a test table with 1000 chip stake level
	var table = TableManager.find_optimal_table(1000, {})
	current_table_id = table.id
	log_message("Created test table: " + current_table_id)

func _on_add_player_pressed():
	if test_players.size() >= 6:
		log_message("Table is full")
		return
	
	var player_data = {
		"user_id": str(test_players.size() + 1),
		"name": "Test Player " + str(test_players.size() + 1),
		"chips": 10000,
		"bet": 0,
		"folded": false,
		"sitting_out": false,
		"cards": [],
		"auto_post_blinds": true,
		"last_action": "",
		"last_action_amount": 0,
		"time_bank": 30.0,
		"avatar_data": {}
	}
	
	var seat_index = TableManager.seat_player(current_table_id, player_data)
	if seat_index != -1:
		test_players.append(player_data)
		log_message("Added player " + player_data.name + " at seat " + str(seat_index))
	else:
		log_message("Failed to add player")

func _on_remove_player_pressed():
	if test_players.is_empty():
		log_message("No players to remove")
		return
	
	var table = TableManager.get_table_data(current_table_id)
	for i in range(table.players.size()):
		if table.players[i] != null:
			TableManager.remove_player(current_table_id, i)
			test_players.pop_back()
			log_message("Removed player from seat " + str(i))
			return

func _on_start_hand_pressed():
	if test_players.size() < 2:
		log_message("Need at least 2 players to start a hand")
		return
	
	TableManager.start_new_hand(current_table_id)
	log_message("Started new hand")
	_update_table_display()

func _on_simulate_hand_pressed():
	if test_players.size() < 2:
		log_message("Need at least 2 players to simulate a hand")
		return
	
	# Start new hand
	TableManager.start_new_hand(current_table_id)
	
	# Simulate preflop actions
	_simulate_betting_round()
	
	# Simulate flop
	if _should_continue():
		TableManager.next_betting_round(TableManager.get_table_data(current_table_id))
		_simulate_betting_round()
	
	# Simulate turn
	if _should_continue():
		TableManager.next_betting_round(TableManager.get_table_data(current_table_id))
		_simulate_betting_round()
	
	# Simulate river
	if _should_continue():
		TableManager.next_betting_round(TableManager.get_table_data(current_table_id))
		_simulate_betting_round()
	
	log_message("Hand simulation complete")
	_update_table_display()

func _simulate_betting_round():
	var table = TableManager.get_table_data(current_table_id)
	while table.action_on != -1:
		var action = _get_random_action()
		var amount = 0
		if action == "raise":
			amount = table.current_bet + table.stake_level
		
		TableManager.process_player_action(current_table_id, table.action_on, action, amount)
		table = TableManager.get_table_data(current_table_id)

func _get_random_action() -> String:
	var actions = ["fold", "call", "raise"]
	return actions[randi() % actions.size()]

func _should_continue() -> bool:
	var table = TableManager.get_table_data(current_table_id)
	var active_players = 0
	for player in table.players:
		if player != null and not player.folded:
			active_players += 1
	return active_players > 1

func _on_test_all_in_pressed():
	if test_players.size() < 2:
		log_message("Need at least 2 players for all-in test")
		return
	
	var table = TableManager.get_table_data(current_table_id)
	
	# Set up players with different stack sizes
	for i in range(test_players.size()):
		if table.players[i] != null:
			table.players[i].chips = (i + 1) * 1000
	
	TableManager.start_new_hand(current_table_id)
	log_message("Set up all-in scenario")
	_update_table_display()

func _on_test_side_pot_pressed():
	if test_players.size() < 3:
		log_message("Need at least 3 players for side pot test")
		return
	
	var table = TableManager.get_table_data(current_table_id)
	
	# Set up players with different stack sizes
	for i in range(test_players.size()):
		if table.players[i] != null:
			table.players[i].chips = (i + 1) * 1000
	
	TableManager.start_new_hand(current_table_id)
	log_message("Set up side pot scenario")
	_update_table_display()

func _on_clear_pressed():
	for i in range(test_players.size()):
		TableManager.remove_player(current_table_id, i)
	test_players.clear()
	log_message("Cleared table")
	_update_table_display()

func _on_fold_pressed():
	_process_player_action("fold")

func _on_call_pressed():
	_process_player_action("call")

func _on_raise_pressed():
	var table = TableManager.get_table_data(current_table_id)
	if table.is_empty() or table.action_on == -1:
		return
	
	var raise_to_amount = int($TestControls/RaiseAmount.value)
	print("\nDEBUG: Attempting raise")
	print("- Raise to amount: ", raise_to_amount)
	print("- Current bet: ", table.current_bet)
	
	var success = TableManager.process_player_action(current_table_id, table.action_on, "raise", raise_to_amount)
	if success:
		print("DEBUG: Raise successful")
	else:
		print("DEBUG: Raise failed")

func _process_player_action(action: String, amount: float = 0):
	var table = TableManager.get_table_data(current_table_id)
	if table.action_on == -1:
		log_message("No player to act")
		return
	
	var success = TableManager.process_player_action(current_table_id, table.action_on, action, amount)
	if success:
		log_message("Player " + str(table.action_on) + " " + action + 
				   (": " + str(amount) if amount > 0 else ""))
	else:
		log_message("Invalid action")
	
	_update_table_display()

func _on_tables_updated():
	var table = TableManager.get_table_data(current_table_id)
	if table.is_empty():
		return
		
	# Move dealer button to new position
	move_dealer_button(table.dealer_position)
	
	_update_table_display()

func _on_player_seated(_table_id: String, seat_index: int, _player_data: Dictionary):
	log_message("Player seated at index " + str(seat_index))
	_update_table_display()

func _on_player_left(_table_id: String, seat_index: int):
	log_message("Player left from index " + str(seat_index))
	_update_table_display()

func _update_table_display():
	var table = TableManager.get_table_data(current_table_id)
	if table.is_empty():
		return
	
	var output = ""
	output += "Table State:\n"
	output += "Current Round: " + table.current_round + "\n"
	output += "Pot: " + str(table.current_pot) + "\n"
	output += "Current Bet: " + str(table.current_bet) + "\n"
	output += "Action On: " + str(table.action_on) + "\n"
	output += "Dealer Position: " + str(table.dealer_position) + "\n\n"
	
	output += "Community Cards: "
	for card in table.community_cards:
		output += format_card(card) + " "
	output += "\n\n"
	
	output += "Players:\n"
	for i in range(table.players.size()):
		var player = table.players[i]
		if player != null:
			output += "Seat " + str(i) + ": " + player.name + "\n"
			output += "  Chips: " + str(player.chips) + "\n"
			output += "  Bet: " + str(player.bet) + "\n"
			output += "  Folded: " + str(player.folded) + "\n"
			output += "  Cards: "
			for card in player.cards:
				output += format_card(card) + " "
			output += "\n\n"
	
	test_output.text = output

func format_card(card: Dictionary) -> String:
	var rank = card.rank
	var suit = card.suit[0].to_upper()  # First letter of suit capitalized
	return "[" + rank + suit + "]"

func log_message(message: String):
	var timestamp = Time.get_time_string_from_system()
	test_output.text = "[" + timestamp + "] " + message + "\n" + test_output.text

func _on_return_to_hub_pressed():
	# Clean up any active game state
	if current_table_id:
		for i in range(test_players.size()):
			TableManager.remove_player(current_table_id, i)
		test_players.clear()
	
	# Return to hub
	SceneManager.goto_scene("res://scenes/MainHub.tscn")

var dealer_button_positions = {
	0: Vector2(780, 675),   # Bottom center (Seat 0)
	1: Vector2(300, 680),   # Bottom left (Seat 1)
	2: Vector2(280, 240),   # Top left (Seat 2)
	3: Vector2(720, 220),   # Top center (Seat 3)
	4: Vector2(1140, 300),  # Top right (Seat 4)
	5: Vector2(1080, 680)   # Bottom right (Seat 5)
}

func move_dealer_button(new_position: int):
	if not dealer_button:
		push_error("Dealer button not found!")
		return

	var target_position = dealer_button_positions[new_position]

	# Create a Tween for smooth animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(dealer_button, "position", target_position, 0.5)
