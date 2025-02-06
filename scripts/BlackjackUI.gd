extends Node

# Constants
const BetControls = preload("res://scripts/BetControls.gd")
const CARD_REVEAL_DELAY = 0.3
const MAX_CARDS = 10
const MAX_HANDS = 3

# Onready Variables - Card Display
@onready var dealer_cards: Array[TextureRect] = []
@onready var player_hand_cards: Array[Array] = []
@onready var dealer_score = $"../GameArea/DealerArea/DealerScore"
@onready var player_hands = [$"../GameArea/PlayerArea/Hand1", $"../GameArea/PlayerArea/Hand2", $"../GameArea/PlayerArea/Hand3"]
@onready var player_hand_scores = [
	$"../GameArea/PlayerArea/HandScore1",
	$"../GameArea/PlayerArea/HandScore2",
	$"../GameArea/PlayerArea/HandScore3"
]

# Onready Variables - UI Controls
@onready var deal_button = $"../GameArea/BettingArea/DealButton"
@onready var action_buttons = {
	"hit": $"../GameArea/ActionArea/HitButton",
	"stand": $"../GameArea/ActionArea/StandButton",
	"double": $"../GameArea/ActionArea/DoubleButton",
	"split": $"../GameArea/ActionArea/SplitButton"
}
@onready var chip_balance = $"../GameArea/GameInfo/ChipBalance"
@onready var current_bet = $"../GameArea/GameInfo/CurrentBet"
@onready var game_status = $"../GameArea/GameInfo/GameStatus"
@onready var challenge_progress_button = $"../ChallengeProgressButton"
@onready var return_to_hub_button = $"../ReturnToHubButton"
@onready var undo_button = $"UndoButton"

# Onready Variables - Animations and Visual Effects
@onready var dealing_timer = $DealingTimer
@onready var hand_result_labels = [
	$"../GameArea/PlayerArea/Hand1/ResultLabel",
	$"../GameArea/PlayerArea/Hand2/ResultLabel",
	$"../GameArea/PlayerArea/Hand3/ResultLabel"
]
@onready var streak_meters = [
	$"../GameArea/PlayerArea/Hand1/StreakMeterContainer",
	$"../GameArea/PlayerArea/Hand2/StreakMeterContainer",
	$"../GameArea/PlayerArea/Hand3/StreakMeterContainer"
]

# Onready Variables - Avatar Display
@onready var avatar_viewport = $"../UIOverlay/AvatarViewport"
@onready var avatar_scene = avatar_viewport.get_node_or_null("AvatarScene")
@onready var player_avatar = $"../UIOverlay/PlayerAvatar"

# Betting Controls Management
var bet_controls = {
	0: {
		"bet_10k": null,
		"bet_100k": null,
		"bet_1m": null,
		"bet_label": null
	},
	1: {
		"bet_10k": null,
		"bet_100k": null,
		"bet_1m": null,
		"bet_label": null
	},
	2: {
		"bet_10k": null,
		"bet_100k": null,
		"bet_1m": null,
		"bet_label": null
	}
}

# Betting History
var bet_history = {
	0: [],
	1: [],
	2: []
}

# Animation State
var dealing_in_progress := false
var _current_dealer_reveal_index: int = 0
var _total_dealer_cards: int = 0
var _is_revealing_dealer_cards = false
var _dealer_reveal_delay = 0.0
var _dealer_reveal_index = 2
var _dealer_cards_to_reveal = []
var _is_waiting_to_evaluate = false
var _is_game_active = false
var _is_waiting_to_clear = false
var _clear_delay = 0.0

func _ready() -> void:
	_initialize_nodes()
	_connect_signals()
	_setup_betting_controls()
	
	# Reset all bets when scene loads
	reset_all_bets()
	
	_initialize_ui()

func _process(delta):
	# Handle revealing dealer cards
	if _is_revealing_dealer_cards:
		_dealer_reveal_delay -= delta
		if _dealer_reveal_delay <= 0.0:
			if _dealer_reveal_index < _dealer_cards_to_reveal.size():
				_reveal_next_dealer_card()
				_dealer_reveal_index += 1
				_dealer_reveal_delay = 1.0  # Set delay for next card
			else:
				# All dealer cards revealed
				_is_revealing_dealer_cards = false
				_is_waiting_to_evaluate = true
				_dealer_reveal_delay = 0.5  # Delay before evaluating game result
	elif _is_waiting_to_evaluate:
		_dealer_reveal_delay -= delta
		if _dealer_reveal_delay <= 0.0:
			_is_waiting_to_evaluate = false
			# Notify BlackjackManager to evaluate the game result
			BlackjackManager.dealer_reveal_complete()
	
	# Handle clearing hands and bets after game result
	if _is_waiting_to_clear:
		_clear_delay -= delta
		if _clear_delay <= 0.0:
			_is_waiting_to_clear = false
			# Clear the hands but keep the ResultLabels
			clear_all_hands(false)  # Pass 'false' to keep ResultLabels visible

			# Clear bets
			reset_all_bets()

			# Update bet displays
			update_all_bet_displays()

			# Now the game is interactive again
			_is_game_active = true

			# Re-enable betting controls
			set_betting_area_enabled(true)
			# Enable or disable the DealButton based on whether any bets are placed
			deal_button.disabled = not (_is_game_active and any_bets_placed())

func _initialize_nodes() -> void:
	# Initialize dealer card references
	for i in range(MAX_CARDS):
		var card = get_node("../GameArea/DealerArea/DealerCards/DealerCard" + str(i + 1))
		if card:
			dealer_cards.append(card)

	# Initialize player hand card references
	for hand in range(3):
		var hand_cards = []
		for i in range(MAX_CARDS):
			var card = get_node("../GameArea/PlayerArea/Hand" + str(hand + 1) + "/Cards/Card" + str(i + 1))
			if card:
				hand_cards.append(card)
		player_hand_cards.append(hand_cards)

	# Initialize betting controls with proper hand indices
	for i in range(3):
		var base_path = "../GameArea/PlayerArea/Hand%d/BetControls" % (i + 1)
		var bet_control_node = get_node(base_path)
		
		if bet_control_node:
			print("Debug: Found BetControls node for hand %d at path %s" % [i, bet_control_node.get_path()])
			
			# Use has_method to verify we have the correct node type
			if bet_control_node.has_method("add_bet"):
				print("Debug: Successfully verified BetControls script for hand %d" % i)
				
				# Get button references
				var bet_10k = bet_control_node.get_node_or_null("HBoxContainer/Bet10kButton")
				var bet_100k = bet_control_node.get_node_or_null("HBoxContainer/Bet100kButton")
				var bet_1m = bet_control_node.get_node_or_null("HBoxContainer/Bet1mButton")
				var bet_label = bet_control_node.get_node_or_null("BetLabel")

				# Verify all nodes were found
				if not bet_10k or not bet_100k or not bet_1m or not bet_label:
					push_error("Failed to find all required nodes for BetControls %d:" % i)
					if not bet_10k: push_error("- Missing Bet10kButton")
					if not bet_100k: push_error("- Missing Bet100kButton")
					if not bet_1m: push_error("- Missing Bet1mButton")
					if not bet_label: push_error("- Missing BetLabel")
					continue

				print("Debug: All button nodes found for hand %d" % i)
				
				# Store the node references
				bet_controls[i] = {
					"bet_10k": bet_10k,
					"bet_100k": bet_100k,
					"bet_1m": bet_1m,
					"bet_label": bet_label,
					"control": bet_control_node
				}
				
				# Set hand index directly on the node
				bet_control_node.hand_index = i
				
				# Connect signals
				if not bet_control_node.is_connected("bet_updated", _on_bet_updated):
					bet_control_node.connect("bet_updated", _on_bet_updated)
			else:
				push_error("Node at %s does not have BetControls script methods" % base_path)
		else:
			push_error("Failed to find BetControls node for hand %d at path: %s" % [i, base_path])

func _initialize_ui() -> void:
	# Initial UI setup
	clear_all_hands(true)
	update_all_bet_displays()
	set_betting_area_enabled(true)
	deal_button.disabled = true

	_is_game_active = true

	# Update avatar if available
	if PlayerData.is_balance_initialized:
		_update_player_avatar()

	# Initialize streak meters
	for meter in streak_meters:
		if meter:
			meter.visible = true
			meter.custom_minimum_size = Vector2(100, 20)
			meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			meter.reset_streak()
	
	_update_chip_balance()

func _update_chip_balance() -> void:
	if PlayerData.is_balance_initialized:
		chip_balance.text = Utilities.format_number(PlayerData.get_balance())
	else:
		# Connect to balance_initialized signal to update when ready
		PlayerData.balance_initialized.connect(_on_balance_initialized)

func _on_balance_initialized():
	chip_balance.text = Utilities.format_number(PlayerData.get_balance())
	# Disconnect the signal to prevent future unnecessary calls
	PlayerData.disconnect("balance_initialized", Callable(self, "_on_balance_initialized"))

func _connect_signals() -> void:
	# Connect BlackjackManager signals
	if BlackjackManager:
		BlackjackManager.dealing_started.connect(_on_dealing_started)
		BlackjackManager.dealer_hand_updated.connect(_on_dealer_hand_updated)
		BlackjackManager.player_turn_started.connect(_on_player_turn_started)
		BlackjackManager.betting_started.connect(_on_betting_started)
		BlackjackManager.hand_updated.connect(_on_hand_updated)
		BlackjackManager.chips_updated.connect(_on_chips_updated)
		BlackjackManager.betting_state_updated.connect(_on_betting_state_updated)
		BlackjackManager.streak_updated.connect(_on_streak_updated)
		BlackjackManager.game_result.connect(_on_game_result)
		BlackjackManager.dealer_turn_complete.connect(_on_dealer_turn_complete)

	# Connect UI button signals
	deal_button.pressed.connect(_on_deal_pressed)
	action_buttons["hit"].pressed.connect(_on_hit_pressed)
	action_buttons["stand"].pressed.connect(_on_stand_pressed)
	action_buttons["double"].pressed.connect(_on_double_pressed)
	action_buttons["split"].pressed.connect(_on_split_pressed)
	return_to_hub_button.pressed.connect(_on_return_to_hub_pressed)

# Connect undo button
	if undo_button:
		undo_button.pressed.connect(_on_undo_pressed)
	else:
		push_error("Undo button not found in scene")

	# Connect timers
	dealing_timer.timeout.connect(_on_dealing_timer_timeout)

	# Connect PlayerData signals
	PlayerData.connect("avatar_updated", _on_avatar_updated)
	PlayerData.connect("challenge_points_updated", _on_challenge_points_updated)

func _setup_betting_controls() -> void:
	for hand_index in bet_controls.keys():
		var controls = bet_controls[hand_index]
		
		# Initialize labels
		controls["bet_label"].text = "Bet: 0"
		update_button_states(hand_index)

# Betting Management
func _on_betting_started() -> void:
	# Don't clear old bets anymore
	for hand_index in bet_controls.keys():
		var bet_control_node = bet_controls[hand_index]["control"]
		if bet_control_node:
			bet_control_node.update_display()
			bet_control_node.update_button_states()
	
	# Enable betting controls
	set_betting_area_enabled(true)
	
	# Update deal button state based on current/previous bets
	update_deal_button_state()
	
	game_status.text = "Place your bets"
	
	# Reset hand highlights
	for hand in player_hands:
		hand.modulate = Color(1, 1, 1)

func _on_bet_pressed(hand_index: int, amount: int) -> void:
	if BlackjackManager.state_machine.is_in_state(BlackjackStateMachine.State.BETTING):
		# Clear result labels when new bets are placed
		if bet_history[hand_index].is_empty():
			hand_result_labels[hand_index].text = ""
			hand_result_labels[hand_index].visible = false
		
		bet_history[hand_index].append(amount)
		update_bet_display(hand_index)
		update_button_states(hand_index)
		BlackjackManager.place_bet(hand_index, get_current_bet(hand_index))
		deal_button.disabled = not any_bets_placed()

func update_bet_display(hand_index: int) -> void:
	var total_bet = get_current_bet(hand_index)
	bet_controls[hand_index]["bet_label"].text = "Bet: " + Utilities.format_number(total_bet)
	current_bet.text = "Current Bet: " + Utilities.format_number(get_total_bets())

func update_button_states(hand_index: int) -> void:
	var remaining_chips = BlackjackManager.player_chips - get_total_bets() + get_current_bet(hand_index)
	var controls = bet_controls[hand_index]
	
	controls["bet_10k"].disabled = remaining_chips < 10000
	controls["bet_100k"].disabled = remaining_chips < 100000
	controls["bet_1m"].disabled = remaining_chips < 1000000

func undo_last_bet(hand_index: int) -> bool:
	if bet_history[hand_index].is_empty():
		return false
	
	bet_history[hand_index].pop_back()
	update_bet_display(hand_index)
	update_button_states(hand_index)
	BlackjackManager.place_bet(hand_index, get_current_bet(hand_index))
	deal_button.disabled = not any_bets_placed()
	return true

func get_current_bet(hand_index: int) -> int:
	var bet_control_node = bet_controls[hand_index]["control"]
	if bet_control_node:
		return bet_control_node.get_current_bet()
	return 0

func get_total_bets() -> int:
	var total = 0
	for hand_index in bet_controls.keys():
		var bet_control_node = bet_controls[hand_index]["control"]
		if bet_control_node:
			total += bet_control_node.get_current_bet()
	print("Debug: Total bets calculation: ", [get_current_bet(0), get_current_bet(1), get_current_bet(2)], " = ", total)
	return total

func any_bets_placed() -> bool:
	for hand_index in bet_controls.keys():
		if get_current_bet(hand_index) > 0:
			return true
	return false

func print_node_tree(node: Node, indent: String = "") -> void:
	print(indent + node.name + " (" + node.get_class() + ")")
	var script = node.get_script()
	if script:
		print(indent + "  Script: " + script.resource_path)
	for child in node.get_children():
		print_node_tree(child, indent + "  ")

# Card Display and Animation
func _on_dealing_started(dealer_cards_data: Array, player_hands_data: Array) -> void:
	dealing_in_progress = true
	clear_all_hands(true)
	
	# Start dealing animation sequence
	dealing_timer.start()
	_handle_initial_deal(dealer_cards_data, player_hands_data)

func _handle_initial_deal(dealer_cards_data: Array, player_hands_data: Array) -> void:
	# Deal dealer's cards
	var dealer_card = dealer_cards_data[0]
	var texture_path = "res://assets/cards/%s_of_%s.png" % [dealer_card.value, dealer_card.suit]
	dealer_cards[0].texture = load(texture_path)
	dealer_cards[0].visible = true
	
	# Show dealer's second card face down
	dealer_cards[1].texture = load("res://assets/cards/card_back.png")
	dealer_cards[1].visible = true
	
	# Deal player cards and update scores
	for hand_index in range(player_hands_data.size()):
		var hand = player_hands_data[hand_index]
		if not hand.is_empty():
			# Display cards
			for card_index in range(hand.size()):
				var card = hand[card_index]
				var card_texture_path = "res://assets/cards/%s_of_%s.png" % [card.value, card.suit]
				player_hand_cards[hand_index][card_index].texture = load(card_texture_path)
				player_hand_cards[hand_index][card_index].visible = true
			
			# Update hand score
			if hand_index < player_hand_scores.size():
				var hand_value = BlackjackManager.calculate_hand_value(hand)
				player_hand_scores[hand_index].text = str(hand_value)

func _on_hand_updated(hand_type: String, index: int, cards: Array) -> void:
	if hand_type == "player":
		# Update cards
		for i in range(cards.size()):
			if i < player_hand_cards[index].size():
				var texture_path = "res://assets/cards/%s_of_%s.png" % [cards[i].value, cards[i].suit]
				player_hand_cards[index][i].texture = load(texture_path)
				player_hand_cards[index][i].visible = true
		
		# Always update hand score
		var hand_value = BlackjackManager.calculate_hand_value(cards)
		if index < player_hand_scores.size():
			player_hand_scores[index].text = str(hand_value)

func _on_dealer_hand_updated(cards: Array, is_reveal: bool) -> void:
	if is_reveal:
		_reveal_dealer_hand(cards)
	else:
		_update_dealer_hand(cards)

func _reveal_dealer_hand(cards: Array) -> void:
	_total_dealer_cards = cards.size()
	
	# Ensure the first dealer card remains visible
	# Update the second dealer card (which was face down) to show its actual card
	if _total_dealer_cards > 1:
		var second_card = cards[1]
		var texture_path = "res://assets/cards/%s_of_%s.png" % [
			second_card.value,
			second_card.suit
		]
		dealer_cards[1].texture = load(texture_path)
		dealer_cards[1].visible = true
	else:
		# Handle cases where there's only one dealer card
		pass
	
	# Update dealer score with the first two cards
	var current_cards = cards.slice(0, min(2, _total_dealer_cards))
	var dealer_hand_value = BlackjackManager.calculate_hand_value(current_cards)
	dealer_score.text = str(dealer_hand_value)
	
	# Hide dealer cards from index 2 onwards
	for i in range(2, dealer_cards.size()):
		dealer_cards[i].visible = false
		dealer_cards[i].texture = null

func _reveal_next_dealer_card():
	var index = _dealer_reveal_index
	if index >= dealer_cards.size():
		# Ensure we don't exceed the number of dealer card slots available
		return

	var card = _dealer_cards_to_reveal[index]
	var texture_path = "res://assets/cards/%s_of_%s.png" % [
		card.value,
		card.suit
	]
	dealer_cards[index].texture = load(texture_path)
	dealer_cards[index].visible = true

	# Update dealer score
	var current_cards = _dealer_cards_to_reveal.slice(0, index + 1)
	var dealer_hand_value = BlackjackManager.calculate_hand_value(current_cards)
	dealer_score.text = str(dealer_hand_value)


func _update_dealer_hand(cards: Array) -> void:
	for i in range(MAX_CARDS):
		if i < cards.size():
			var texture_path = "res://assets/cards/%s_of_%s.png" % [cards[i].value, cards[i].suit]
			dealer_cards[i].texture = load(texture_path)
			dealer_cards[i].visible = true
		else:
			dealer_cards[i].visible = false

# UI State Management
func _on_player_turn_started(hand_index: int) -> void:
	highlight_active_hand(hand_index)
	update_action_buttons(hand_index)
	game_status.text = "Player's turn - Hand " + str(hand_index + 1)

func _on_bet_updated(hand_index: int, new_amount: int) -> void:
	print("Debug - Bet updated for hand %d: %d" % [hand_index, new_amount])
	# Update deal button state
	update_deal_button_state()
	# Update total bet display
	current_bet.text = "Current Bet: " + Utilities.format_number(get_total_bets())
	# Update the display for this hand
	update_bet_display(hand_index)
	# Update button states for this hand
	update_button_states(hand_index)

func _on_betting_state_updated(current_bets: Array) -> void:
	for i in range(current_bets.size()):
		var bet_control_node = bet_controls[i]["control"]
		if bet_control_node:
			# Pass 'true' to indicate this is an external update
			bet_control_node.set_current_bet(current_bets[i], true)
			update_bet_display(i)
			update_button_states(i)
	
	# Update deal button state
	update_deal_button_state()

func highlight_active_hand(hand_index: int) -> void:
	for i in range(player_hands.size()):
		if i == hand_index:
			player_hands[i].modulate = Color(1, 1, 0.5)  # Highlight color
		else:
			player_hands[i].modulate = Color(1, 1, 1)    # Normal color

func update_action_buttons(hand_index: int) -> void:
	var can_act = BlackjackManager.state_machine.is_in_state(BlackjackStateMachine.State.PLAYER_TURN)
	
	for button in action_buttons.values():
		button.disabled = not can_act
	
	if can_act:
		action_buttons["split"].disabled = not BlackjackManager.can_split(hand_index)
		action_buttons["double"].disabled = BlackjackManager.player_hands[hand_index].size() != 2

func _on_dealer_turn_complete() -> void:
	# Start the dealer reveal process
	_is_revealing_dealer_cards = true
	_dealer_reveal_delay = 0.0  # Start immediately
	_dealer_reveal_index = 2  # Start from the third card (index 2)
	_dealer_cards_to_reveal = BlackjackManager.dealer_hand

	# Keep the first dealer card visible
	# Update the second dealer card to show its actual card
	if _dealer_cards_to_reveal.size() > 1:
		var second_card = _dealer_cards_to_reveal[1]
		var texture_path = "res://assets/cards/%s_of_%s.png" % [
			second_card.value,
			second_card.suit
		]
		dealer_cards[1].texture = load(texture_path)
		dealer_cards[1].visible = true
	else:
		# Handle cases where there's only one dealer card
		pass

	# Update dealer score with the first two cards
	var current_cards = _dealer_cards_to_reveal.slice(0, min(2, _dealer_cards_to_reveal.size()))
	var dealer_hand_value = BlackjackManager.calculate_hand_value(current_cards)
	dealer_score.text = str(dealer_hand_value)

	# Hide dealer cards from index 2 onwards
	for i in range(2, dealer_cards.size()):
		dealer_cards[i].visible = false
		dealer_cards[i].texture = null


# Player Actions
func _on_deal_pressed() -> void:
	if not _is_game_active:
		return  # Ignore input if the game is not active

	if not dealing_in_progress and BlackjackManager.state_machine.is_in_state(BlackjackStateMachine.State.BETTING):
		# If no bets are placed, attempt to repeat previous bets
		if get_total_bets() == 0:
			if BlackjackManager.repeat_previous_bet():
				# Update the bet controls to reflect the repeated bets
				for i in range(MAX_HANDS):
					var bet_control_node = bet_controls[i]["control"]
					if bet_control_node:
						bet_control_node.set_current_bet(BlackjackManager.current_bets[i])
				update_all_bet_displays()
			else:
				# No previous bets or not enough chips
				# Optionally show a message to the user
				print("No previous bets to repeat or not enough chips")
				return

		# Clear result labels when starting a new hand
		for label in hand_result_labels:
			if label:
				label.text = ""
				label.visible = false

		# Don't reset streak meters here - they should persist between hands

		set_betting_area_enabled(false)
		BlackjackManager.start_game()

func update_deal_button_state():
	var can_afford_bets = true
	var total_bet = get_total_bets()
	
	if total_bet == 0:
		# Check if we can afford previous bets
		total_bet = BlackjackManager.previous_bets.reduce(func(accum, bet): return accum + bet, 0)
		can_afford_bets = total_bet > 0 and total_bet <= BlackjackManager.player_chips
	else:
		can_afford_bets = total_bet <= BlackjackManager.player_chips
	
	deal_button.disabled = not (_is_game_active and can_afford_bets)

func _on_hit_pressed() -> void:
	BlackjackManager.hit(BlackjackManager.current_hand_index)

func _on_stand_pressed() -> void:
	BlackjackManager.stand()

func _on_double_pressed() -> void:
	BlackjackManager.double_down(BlackjackManager.current_hand_index)

func _on_split_pressed() -> void:
	BlackjackManager.split(BlackjackManager.current_hand_index)

	if BlackjackManager.repeat_previous_bet():
		update_all_bet_displays()
		# Enable the DealButton if bets are placed
		deal_button.disabled = not (_is_game_active and any_bets_placed())

# Results and Cleanup
func _on_game_result(results: Array) -> void:
	_is_game_active = false  # Disable interaction during the delay

	for result in results:
		display_hand_result(result)
	
	# Start the delay before clearing hands and bets
	_is_waiting_to_clear = true
	_clear_delay = 2.0

func _on_dealing_timer_timeout() -> void:
	if dealer_cards.size() > 1 and dealer_cards[1].visible:
		dealing_in_progress = false
	else:
		dealing_timer.start()

func _on_challenge_points_updated(_points: int) -> void:
	if challenge_progress_button:
		challenge_progress_button.update_progress_display()

func reset_all_bets() -> void:
	for hand_index in bet_controls.keys():
		var bet_control_node = bet_controls[hand_index]["control"]
		if bet_control_node:
			# Don't reset the bets between rounds anymore
			update_bet_display(hand_index)
			update_button_states(hand_index)
	
	update_deal_button_state()

func clear_result_labels() -> void:
	for label in hand_result_labels:
		if label:
			label.text = ""
			label.visible = false

func display_hand_result(result: Dictionary) -> void:
	var hand_index = result.hand_index
	if hand_index >= 0 and hand_index < hand_result_labels.size():
		var label = hand_result_labels[hand_index]
		if label:
			var text = ""
			match result.outcome:
				BlackjackManager.HandResult.WIN, BlackjackManager.HandResult.BLACKJACK:
					text = "Win " + Utilities.format_number(result.win_amount)
				BlackjackManager.HandResult.LOSE:
					text = "Lose " + Utilities.format_number(BlackjackManager.current_bets[hand_index])
				BlackjackManager.HandResult.PUSH:
					text = "Push"
				BlackjackManager.HandResult.BUST:
					text = "Bust - Lose " + Utilities.format_number(BlackjackManager.current_bets[hand_index])
			
			label.text = text
			label.visible = true

# Streak Management
func _on_streak_updated(hand_index: int, streak_count: int, multiplier_active: bool) -> void:
	print("\nDebug - UI Streak Update:")
	print("- Hand Index: %d" % hand_index)
	print("- New Streak Count: %d" % streak_count)
	print("- Multiplier Active: %s" % str(multiplier_active))
	
	if hand_index >= 0 and hand_index < streak_meters.size():
		var meter = streak_meters[hand_index]
		if meter and meter.has_method("update_streak"):
			print("- Updating streak meter display")
			meter.update_streak(streak_count)
			
			# Get the ProgressBar node
			var progress_bar = meter.get_node("ProgressBar")
			if progress_bar:
				if multiplier_active:
					print("- Applying glow effect")
					_apply_glow_to_progress_bar(progress_bar)
				else:
					print("- Removing glow effect")
					_remove_glow_from_progress_bar(progress_bar)
	else:
		push_error("Invalid hand index for streak update: %d" % hand_index)

# Helper Functions
func clear_all_hands(clear_results: bool = false) -> void:
	# Clear dealer cards
	for card in dealer_cards:
		card.visible = false
		card.texture = null
	
	# Clear player cards
	for hand in player_hand_cards:
		for card in hand:
			card.visible = false
			card.texture = null
	
	# Clear scores
	dealer_score.text = ""
	for score_label in player_hand_scores:
		score_label.text = ""
	
	if clear_results:
		for label in hand_result_labels:
			if label:
				label.text = ""
				label.visible = false

func set_betting_area_enabled(enable: bool) -> void:
	# Only enable controls if _is_game_active is true
	var actual_enable = enable and _is_game_active

	# For each bet control
	for hand_index in bet_controls.keys():
		var bet_control_node = bet_controls[hand_index]["control"]
		if bet_control_node:
			bet_control_node.set_bet_enabled(actual_enable)

	# Update the DealButton
	update_deal_button_state()

func update_all_bet_displays() -> void:
	for hand_index in bet_controls.keys():
		update_bet_display(hand_index)
		update_button_states(hand_index)

func _on_chips_updated(new_amount: int) -> void:
	chip_balance.text = Utilities.format_number(new_amount)
	# Update betting buttons based on new balance
	for hand_index in bet_controls.keys():
		update_button_states(hand_index)

func _on_return_to_hub_pressed() -> void:
	# Reset streak meters before leaving
	for meter in streak_meters:
		if meter:
			meter.reset_streak()
	
	BlackjackManager._on_return_to_hub()
	SceneManager.return_to_main_hub()

# Avatar Management
func _on_avatar_updated(_avatar_id) -> void:
	_update_player_avatar()

func _update_player_avatar() -> void:
	var avatar_data = PlayerData.get_avatar_data()
	if avatar_scene and avatar_data:
		_update_avatar_scene(avatar_scene, avatar_data)
		if player_avatar:
			player_avatar.texture = avatar_viewport.get_texture()

func _update_avatar_scene(scene: Node, data: Dictionary) -> void:
	for part in ["face", "clothing", "hair", "hat", "ear_accessories", "mouth_accessories"]:
		var sprite = scene.get_node_or_null(part.capitalize())
		if sprite and data.get(part):
			var texture_path = "res://assets/avatars/%s/%s.png" % [part, data[part]]
			var texture = load(texture_path)
			if texture:
				sprite.texture = texture
				sprite.visible = true
			else:
				sprite.visible = false

func _apply_glow_to_progress_bar(progress_bar: ProgressBar) -> void:
	# Create glow style
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 0.8, 0.0, 0.8)  # Golden color for glow
	glow_style.set_corner_radius_all(5)
	glow_style.border_width_top = 2
	glow_style.border_width_bottom = 2
	glow_style.border_width_left = 2
	glow_style.border_width_right = 2
	glow_style.border_color = Color(1.0, 0.9, 0.0, 0.9)
	
	progress_bar.add_theme_stylebox_override("fill", glow_style)

func _remove_glow_from_progress_bar(progress_bar: ProgressBar) -> void:
	# Create default style
	var default_style = StyleBoxFlat.new()
	default_style.bg_color = Color(0.3, 0.7, 1.0, 0.8)  # Default blue color
	default_style.set_corner_radius_all(5)
	
	progress_bar.add_theme_stylebox_override("fill", default_style)

func _on_undo_pressed() -> void:
	if BlackjackManager.state_machine.is_in_state(BlackjackStateMachine.State.BETTING):
		print("\nDebug - Undo button pressed")
		print("Current bets before undo:")
		for hand_index in range(MAX_HANDS):
			var bet_control_node = bet_controls[hand_index]["control"]
			if bet_control_node:
				print("- Hand %d: Current bet = %d, Bet history = %s" % [
					hand_index,
					bet_control_node.get_current_bet(),
					str(bet_control_node.bet_history)
				])

		# Find the last hand with a non-zero bet
		for hand_index in range(MAX_HANDS - 1, -1, -1):
			var bet_control_node = bet_controls[hand_index]["control"]
			if bet_control_node and bet_control_node.get_current_bet() > 0:
				print("Found bet to undo in Hand %d" % hand_index)
				if bet_control_node.undo_last_bet():
					break

		# Update deal button state
		update_deal_button_state()
		# Update the total bet display
		current_bet.text = "Current Bet: " + Utilities.format_number(get_total_bets())
