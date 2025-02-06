# GameManager.gd
extends Node

signal leaderboard_points_updated(points)
signal balance_update_failed(error_message)
signal hand_updated(hand_index)
signal game_state_changed(state)
signal chips_updated(player_index, new_amount)
signal betting_started
signal player_turn_started(player_index)
signal dealer_position_changed(new_position)

const ACTION_TIME_LIMIT = 10.0
const WARNING_THRESHOLD = 3.0
const FLASH_INTERVAL = 0.5

var Deck = preload("res://scripts/Deck.gd")
var HandEvaluator = preload("res://scripts/HandEvaluator.gd")

# Current table information
var table_id: String
var seat_index: int
var current_stake: int
var initial_stack: int

# Local game state tracking
var player_cards = []
var current_bet = 0
var last_action = ""
var is_my_turn = false

@onready var challenge_progress = get_node_or_null("../ChallengeProgressButton")
@onready var action_ui = get_node_or_null("../ActionUI")
@onready var hand_strength_label = get_node_or_null("../HandStrengthLabel")
@onready var winner_popup = get_node_or_null("../WinnerPopup")
@onready var return_to_lobby_button = get_node_or_null("../ReturnToLobbyButton")
@onready var pot_chip_display = get_node("../Pot/PotChipDisplay")

func _ready():
	if not _verify_required_nodes():
		push_error("Missing required nodes - game may not function correctly")
		return

	# Connect to TableManager signals
	TableManager.player_seated.connect(_on_player_seated)
	TableManager.player_left.connect(_on_player_left)
	TableManager.tables_updated.connect(_on_table_state_updated)

	# Initialize the game with data from GameData singleton
	var game_data = GameData.get_game_data()
	if game_data:
		initialize_game(game_data)
		GameData.clear_game_data()
	else:
		push_error("No game data available for initialization")
		return_to_lobby()

	# Set up action UI
	if action_ui:
		action_ui.setup(self)
		update_action_ui()

	# Connect to challenge points updated signal
	PlayerData.connect("challenge_points_updated", _on_challenge_points_updated)

	# Initialize challenge progress button
	if challenge_progress:
		challenge_progress.pressed.connect(_on_challenge_button_pressed)
		_update_challenge_points_display()

	return_to_lobby_button.pressed.connect(_on_return_to_lobby_pressed)

func initialize_game(game_data: Dictionary) -> void:
	print("Debug: Initializing game with data:", game_data)

	# Store table information
	table_id = game_data.table_id
	seat_index = game_data.seat_index
	current_stake = game_data.stake_level
	initial_stack = game_data.player_stack

	# Initialize local state
	player_cards.clear()
	current_bet = 0
	last_action = ""
	is_my_turn = false

	# Update UI with initial table state
	update_ui_from_table_state(game_data.table_state)

func _on_table_state_updated():
	var table_data = TableManager.get_table_data(table_id)
	if table_data.is_empty():
		push_error("Could not get table data for table: " + table_id)
		return

	update_ui_from_table_state(table_data)

	# Check if it's our turn
	if table_data.action_on == seat_index:
		start_player_turn()

func update_ui_from_table_state(table_data: Dictionary):
	# Update pot display
	update_pot_display(table_data.current_pot)

	# Update community cards
	update_community_cards(table_data.community_cards)

	# Update player displays
	update_player_displays(table_data)

	# Update dealer button
	move_dealer_button(table_data.dealer_position)

	# Update current bet information
	current_bet = table_data.current_bet

	# Update action UI if it's our turn
	if table_data.action_on == seat_index:
		update_action_ui()

	# Update hand strength label
	update_hand_strength_label()

func start_player_turn():
	is_my_turn = true
	var table_data = TableManager.get_table_data(table_id)
	
	# Enable action UI
	if action_ui:
		action_ui.update_bet_limits(
			table_data.current_bet,
			get_player_chips(),
			table_data.current_bet + current_stake  # Default raise amount is 1 BB
		)

	emit_signal("player_turn_started", seat_index)

func process_player_action(action: String, amount: int = 0) -> bool:
	if not is_my_turn:
		return false

	var success = TableManager.process_player_action(table_id, seat_index, action, amount)
	if success:
		is_my_turn = false
		last_action = action

	return success

func _on_fold_pressed():
	if is_my_turn:
		process_player_action("fold")

func _on_check_call_pressed():
	if is_my_turn:
		var call_amount = TableManager.get_table_data(table_id).current_bet
		process_player_action("call", call_amount)

func _on_raise_pressed():
	if is_my_turn and action_ui:
		var raise_amount = action_ui.get_bet_amount()
		process_player_action("raise", raise_amount)

# Helper methods

func update_pot_display(pot_amount: int):
	var pot_label = get_node("../Pot/PotLabel")
	if pot_label:
		pot_label.text = "Pot: " + Utilities.format_number(pot_amount)

	if pot_chip_display:
		if pot_amount > 0:
			pot_chip_display.visible = true
			pot_chip_display.set_amount(pot_amount, false)
		else:
			pot_chip_display.visible = false

func update_community_cards(cards: Array):
	for i in range(5):
		var card_node = get_node("../CommunityCards/Card" + str(i + 1))
		if card_node:
			if i < cards.size():
				var texture_path = "res://assets/cards/%s_of_%s.png" % [cards[i].rank.to_lower(), cards[i].suit.to_lower()]
				card_node.texture = load(texture_path)
				card_node.visible = true
			else:
				card_node.visible = false

func update_player_displays(table_data: Dictionary):
	var players = table_data.players
	for i in range(players.size()):
		var player_node = get_node("../Players/Player" + str(i + 1))
		if player_node:
			var player = players[i]
			if player != null:
				# Show cards only for our seat or during showdown
				var show_cards = i == seat_index or table_data.current_round == "showdown"
				player_node.update_display(player, i == table_data.action_on, show_cards)
			else:
				player_node.clear_cards()

func update_hand_strength_label():
	if hand_strength_label:
		var table_data = TableManager.get_table_data(table_id)
		if table_data.is_empty():
			hand_strength_label.text = ""
			return

		if seat_index >= 0 and table_data.players[seat_index] != null:
			var player = table_data.players[seat_index]
			if player.cards.size() >= 2:
				var hand_info
				match table_data.current_round:
					"preflop":
						hand_info = HandEvaluator.evaluate_preflop_hand(player.cards)
					_:
						hand_info = HandEvaluator.evaluate_hand(player.cards, table_data.community_cards)
				hand_strength_label.text = "Current Hand: " + HandEvaluator.hand_rank_to_string(hand_info)
			else:
				hand_strength_label.text = ""

func update_action_ui():
	if not action_ui or not is_my_turn:
		return

	var table_data = TableManager.get_table_data(table_id)
	if table_data.is_empty():
		return

	var player = table_data.players[seat_index]
	if player == null:
		return

	var min_raise = current_stake  # 1 BB minimum raise
	var call_amount = table_data.current_bet - player.bet
	var max_raise = player.chips + player.bet

	action_ui.update_bet_limits(call_amount, max_raise, table_data.current_bet + min_raise)

func get_player_chips() -> int:
	var table_data = TableManager.get_table_data(table_id)
	if not table_data.is_empty() and table_data.players[seat_index] != null:
		return table_data.players[seat_index].chips
	return 0

func award_challenge_points(is_winner: bool):
	var points = current_stake  # 1 point per hand * big blind
	if is_winner:
		points += current_stake * 10  # 10 additional points for winning * big blind
	PlayerData.update_challenge_points(points)

func _on_return_to_lobby_pressed():
	# Calculate final profit/loss
	var final_chips = get_player_chips()
	var profit_loss = final_chips - initial_stack
	var final_total_balance = PlayerData.get_balance() + final_chips

	# Update PlayerData
	PlayerData.player_data["total_balance"] = final_total_balance

	# Update server with final balance
	APIManager.update_server_balance(final_total_balance)
	APIManager.connect("balance_update_completed", _on_lobby_return_balance_updated, CONNECT_ONE_SHOT)

	# Remove player from table
	TableManager.remove_player(table_id, seat_index)

func _on_lobby_return_balance_updated(success: bool, message: String):
	if success:
		print("Debug: Balance updated successfully before lobby return")
	else:
		print("Debug: Failed to update balance before lobby return:", message)

	SceneManager.goto_scene("res://scenes/MainHub.tscn")

func return_to_lobby():
	SceneManager.goto_scene("res://scenes/MainHub.tscn")

# Challenge system handlers
func _on_challenge_points_updated(_points):
	_update_challenge_points_display()

func _update_challenge_points_display():
	if challenge_progress:
		challenge_progress.update_progress_display()

func _on_challenge_button_pressed():
	SceneManager.goto_scene("res://scenes/ChallengeScene.tscn")

# Add these methods to GameManager.gd

func _verify_required_nodes() -> bool:
	var required_nodes = {
		"ActionUI": action_ui,
		"HandStrengthLabel": hand_strength_label,
		"WinnerPopup": winner_popup,
		"ReturnToLobbyButton": return_to_lobby_button
	}
	
	var optional_nodes = {
		"ChallengeProgressButton": challenge_progress,
		"PotChipDisplay": pot_chip_display
	}

	var all_required_found = true
	for node_name in required_nodes:
		if not required_nodes[node_name]:
			push_error("Required node not found: " + node_name)
			all_required_found = false

	# Just log warnings for optional nodes
	for node_name in optional_nodes:
		if not optional_nodes[node_name]:
			print("Optional node not found: " + node_name)

	return all_required_found

func _on_player_seated(table_id: String, player_seat: int, player_data: Dictionary):
	if table_id != self.table_id:
		return
		
	print("Debug: Player seated at table ", table_id, " seat ", player_seat)
	_on_table_state_updated()

func _on_player_left(table_id: String, player_seat: int):
	if table_id != self.table_id:
		return
		
	print("Debug: Player left table ", table_id, " from seat ", player_seat)
	_on_table_state_updated()

func move_dealer_button(new_position: int):
	var dealer_button = get_node_or_null("../DealerButton")
	if not dealer_button:
		push_error("Dealer button not found!")
		return

	var dealer_button_positions = {
		0: Vector2(780, 675),   # Bottom center (You)
		1: Vector2(300, 680),   # Bottom left
		2: Vector2(280, 240),   # Top left
		3: Vector2(720, 220),   # Top center
		4: Vector2(1140, 300),  # Top right
		5: Vector2(1080, 680)   # Bottom right
	}

	var target_position = dealer_button_positions[new_position]

	# Create a Tween for smooth animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(dealer_button, "position", target_position, 0.5)
	
	emit_signal("dealer_position_changed", new_position)

func collect_pot_to_winner(winner_index: int):
	if pot_chip_display and pot_chip_display.visible:
		var winner_position = get_node("../Players/Player" + str(winner_index + 1)).position
		# Only animate pot collection if there are actual chips to collect
		var table_data = TableManager.get_table_data(table_id)
		if table_data and table_data.current_pot > 0:
			# Get the final pot amount after rake if hand was rake-eligible
			var pot_result = TableManager.process_pot_with_rake(table_id)
			var final_pot = pot_result.main_pot
			# Include any side pots
			for side_pot in pot_result.side_pots:
				final_pot += side_pot.amount
			
			pot_chip_display.set_amount(final_pot, false)  # Update to show actual winning amount
			pot_chip_display.move_to_winner(winner_position)
