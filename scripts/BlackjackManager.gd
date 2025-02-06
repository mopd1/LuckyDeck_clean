extends Node

# Game state signals
signal dealing_started(dealer_cards: Array, player_hands: Array)
signal dealer_hand_updated(cards: Array, is_reveal: bool)
signal player_turn_started(hand_index: int)
signal betting_started
signal dealer_turn_complete()

# Game data signals
signal hand_updated(hand_type: String, index: int, cards: Array)
signal chips_updated(new_amount: int)
signal betting_state_updated(current_bets: Array)
signal streak_updated(hand_index: int, streak_count: int, multiplier_active: bool)
signal game_result(results: Array)

enum HandResult {
	NONE,
	WIN,
	LOSE,
	PUSH,
	BLACKJACK,
	BUST
}

const MAX_HANDS = 3
const STREAK_MULTIPLIER = 2.5
const MIN_STREAK_BET = 10000
const MAX_STREAK = 4

var state_machine: BlackjackStateMachine
var deck: Array[Dictionary] = []
var dealer_hand: Array[Dictionary] = []
var player_hands: Array[Array] = []
var current_bets: Array[int] = [0, 0, 0]
var previous_bets: Array[int] = [0, 0, 0]
var streak_counts: Array[int] = [0, 0, 0]
var player_chips: int = 0
var current_hand_index: int = 0
var crypto_rng: CryptoRNG

# Initialization
func _ready() -> void:
	state_machine = BlackjackStateMachine.new()
	add_child(state_machine)
	
	state_machine.state_changed.connect(_on_state_changed)
	
	if not PlayerData.is_balance_initialized:
		await PlayerData.balance_initialized
	
	initialize_game()

func initialize_game() -> void:
	crypto_rng = CryptoRNG.new()
	player_chips = PlayerData.get_balance()
	reset_game_state()
	emit_signal("chips_updated", player_chips)
	emit_signal("betting_started")

func reset_game_state() -> void:
	reset_deck()
	reset_hands()
	current_hand_index = 0
	# Don't reset current_bets here either
	state_machine.change_state(BlackjackStateMachine.State.BETTING)

# State Management
func _on_state_changed(from_state: int, to_state: int) -> void:
	match to_state:
		BlackjackStateMachine.State.DEALING:
			_handle_dealing_state()
		BlackjackStateMachine.State.PLAYER_TURN:
			_handle_player_turn_state()
		BlackjackStateMachine.State.DEALER_TURN:
			_handle_dealer_turn_state()
		BlackjackStateMachine.State.GAME_OVER:
			_handle_game_over_state()

func _handle_dealing_state() -> void:
	deal_initial_hands()
	emit_signal("dealing_started", dealer_hand, player_hands)

func _handle_player_turn_state() -> void:
	current_hand_index = find_first_active_hand()
	if current_hand_index != -1:
		emit_signal("player_turn_started", current_hand_index)
	else:
		state_machine.change_state(BlackjackStateMachine.State.DEALER_TURN)

func _handle_dealer_turn_state() -> void:
	emit_signal("dealer_hand_updated", dealer_hand, true)
	play_dealer_turn()

func _handle_game_over_state() -> void:
	var results = determine_results()
	process_results(results)
	emit_signal("game_result", results)
	
	# Store current bets as previous bets
	previous_bets = current_bets.duplicate()
	
	# Reset deck and hands only
	reset_deck()
	reset_hands()
	
	# Don't clear current_bets here
	
	state_machine.change_state(BlackjackStateMachine.State.BETTING)
	emit_signal("betting_started")
	# Also emit betting state to ensure UI is updated
	emit_signal("betting_state_updated", current_bets)

# Game Actions
func start_game() -> void:
	print("\nDebug - start_game() called")
	print("Current bets before starting game: ", current_bets)
	
	var total_current_bet = current_bets.reduce(func(accum, bet): return accum + bet, 0)
	if total_current_bet == 0:
		# No current bets - try to use previous bets
		var total_previous_bet = previous_bets.reduce(func(accum, bet): return accum + bet, 0)
		print("Total previous bet: ", total_previous_bet)
		if total_previous_bet > 0:
			# Check if player can afford previous bets
			if total_previous_bet <= player_chips:
				current_bets = previous_bets.duplicate()
				print("Using previous bets: ", current_bets)
				emit_signal("betting_state_updated", current_bets)
			else:
				print("Debug - Not enough chips to repeat previous bets")
				return
		else:
			print("Debug - No previous bets available")
			return
	
	if deduct_bets():
		print("Bets deducted successfully: ", current_bets)
		var bet_points = calculate_challenge_points(current_bets.reduce(func(a, b): return a + b), 0)
		PlayerData.update_challenge_points(bet_points)
		state_machine.change_state(BlackjackStateMachine.State.DEALING)
	else:
		push_error("Failed to deduct bets")

func has_previous_bets() -> bool:
	return previous_bets.reduce(func(accum, bet): return accum + bet, 0) > 0

func hit(hand_index: int) -> void:
	if not state_machine.is_in_state(BlackjackStateMachine.State.PLAYER_TURN):
		return
		
	player_hands[hand_index].append(deal_card())
	emit_signal("hand_updated", "player", hand_index, player_hands[hand_index])
	
	if is_bust(player_hands[hand_index]) or is_twenty_one(player_hands[hand_index]):
		move_to_next_hand()

func stand() -> void:
	if not state_machine.is_in_state(BlackjackStateMachine.State.PLAYER_TURN):
		return
		
	move_to_next_hand()

func double_down(hand_index: int) -> void:
	if not state_machine.is_in_state(BlackjackStateMachine.State.PLAYER_TURN):
		return
		
	if player_chips >= current_bets[hand_index]:
		player_chips -= current_bets[hand_index]
		current_bets[hand_index] *= 2
		emit_signal("chips_updated", player_chips)
		emit_signal("betting_state_updated", current_bets)
		hit(hand_index)
		move_to_next_hand()

func split(hand_index: int) -> void:
	if not can_split(hand_index) or player_chips < current_bets[hand_index]:
		return
		
	player_chips -= current_bets[hand_index]
	var new_hand_index = find_empty_hand()
	
	if new_hand_index != -1:
		player_hands[new_hand_index] = [player_hands[hand_index].pop_back()]
		current_bets[new_hand_index] = current_bets[hand_index]
		
		# Deal new cards to both hands
		hit(hand_index)
		hit(new_hand_index)
		
		emit_signal("chips_updated", player_chips)
		emit_signal("betting_state_updated", current_bets)

# Betting Management
func place_bet(hand_index: int, amount: int) -> bool:
	print("Debug: place_bet called for hand %d with amount %d" % [hand_index, amount])
	
	# Basic validation first
	if hand_index < 0 or hand_index >= MAX_HANDS:
		print("Debug: Invalid hand index: %d" % hand_index)
		return false
		
	# Check if we're in the betting state
	if not state_machine or not state_machine.get_current_state() == BlackjackStateMachine.State.BETTING:
		print("Debug: Not in betting state")
		return false
		
	# Calculate the total bet if this bet is placed
	var total_bet = 0
	for i in range(MAX_HANDS):
		if i == hand_index:
			total_bet += amount
		else:
			total_bet += current_bets[i]
			
	print("Debug: Total bet would be: ", total_bet)
	
	if total_bet > player_chips:
		print("Debug: Not enough chips. Required: ", total_bet, " Available: ", player_chips)
		return false
		
	# Set the bet for the specific hand
	current_bets[hand_index] = amount
	print("Debug: Updated current_bets: ", current_bets)
	
	# Emit the betting state update signal
	emit_signal("betting_state_updated", current_bets)
	return true

func repeat_previous_bet() -> bool:
	print("\nDebug - repeat_previous_bet() called")
	if not has_previous_bets():
		print("Debug - No previous bets to repeat.")
		return false

	for i in range(MAX_HANDS):
		var bet_amount = previous_bets[i]
		if bet_amount > 0:
			var success = place_bet(i, bet_amount)
			if not success:
				print("Debug - Failed to place previous bet for Hand%d" % (i + 1))
				return false
	print("Debug - Successfully repeated previous bets: ", current_bets)
	return true

func deduct_bets() -> bool:
	var total_bet = current_bets.reduce(func(accum, bet): return accum + bet, 0)
	print("Debug - Deducting bets: Total bet = ", total_bet)
	
	if total_bet <= player_chips:
		player_chips -= total_bet
		# Store these as previous bets for next round
		previous_bets = current_bets.duplicate()
		print("Debug - Bets deducted. New player chips: ", player_chips)
		emit_signal("chips_updated", player_chips)
		return true
	
	print("Debug - Not enough chips to deduct bets.")
	return false

# Card Management
func create_deck() -> Array[Dictionary]:
	var new_deck: Array[Dictionary] = []
	var suits = ["hearts", "diamonds", "clubs", "spades"]
	var values = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
	for suit in suits:
		for value in values:
			new_deck.append({"suit": suit, "value": value})
	return new_deck

func shuffle_deck() -> void:
	deck = crypto_rng.shuffle_array(deck)

func deal_card() -> Dictionary:
	if deck.is_empty():
		deck = create_deck()
		shuffle_deck()
	return deck.pop_back()

func reset_hands() -> void:
	print("\nDebug - Resetting hands.")
	player_hands = []
	for i in range(MAX_HANDS):
		player_hands.append([])
	dealer_hand = []
	print("Debug - Hands reset. Current hands: ", player_hands)
	# Do not modify current_bets here

func deal_initial_hands() -> void:
	dealer_hand = [deal_card(), deal_card()]
	
	# Prepare hands with their values
	var player_hand_data = []
	for i in range(MAX_HANDS):
		if current_bets[i] > 0:
			player_hands[i] = [deal_card(), deal_card()]
			player_hand_data.append({
				"hand": player_hands[i],
				"value": calculate_hand_value(player_hands[i])
			})
		else:
			player_hand_data.append(null)
	
	emit_signal("dealing_started", dealer_hand, player_hands)  # Send original arrays
	
	state_machine.change_state(BlackjackStateMachine.State.PLAYER_TURN)

# Game Logic
func move_to_next_hand() -> void:
	current_hand_index = find_next_active_hand(current_hand_index + 1)
	
	if current_hand_index != -1:
		emit_signal("player_turn_started", current_hand_index)
	else:
		state_machine.change_state(BlackjackStateMachine.State.DEALER_TURN)

func play_dealer_turn() -> void:
	while calculate_hand_value(dealer_hand) < 17:
		dealer_hand.append(deal_card())
		emit_signal("dealer_hand_updated", dealer_hand, true)
	
	# Dealer's turn is complete, emit signal
	emit_signal("dealer_turn_complete")
	# Do not change state to GAME_OVER yet
	# state_machine.change_state(BlackjackStateMachine.State.GAME_OVER)


func determine_results() -> Array:
	var results = []
	var dealer_value = calculate_hand_value(dealer_hand)
	var dealer_blackjack = is_blackjack(dealer_hand)
	
	for i in range(MAX_HANDS):
		if not player_hands[i].is_empty():
			var player_value = calculate_hand_value(player_hands[i])
			var result = _determine_single_hand_result(i, player_value, dealer_value, dealer_blackjack)
			results.append(result)
			# Remove streak update from here if it exists
	
	return results

func process_results(results: Array) -> void:
	print("\nDebug - Processing game results:")
	for result in results:
		var hand_index = result.hand_index
		print("\nProcessing hand %d:" % hand_index)
		
		if "win_amount" in result:
			if result.outcome == HandResult.PUSH:
				# For push, just return the bet without updating streak
				player_chips += result.win_amount
				print("- Push outcome: returning bet without streak update")
			else:
				# First calculate potential multiplier
				var apply_multiplier = streak_counts[hand_index] >= MAX_STREAK
				
				# Then update streak
				update_streak(hand_index, result.outcome)
				
				# Apply multiplier if it was active before the streak update
				if apply_multiplier:
					result.win_amount = int(result.win_amount * STREAK_MULTIPLIER)
					print("- Applied streak multiplier. New win amount: %d" % result.win_amount)
				
				player_chips += result.win_amount
				print("- Win amount: %d" % result.win_amount)
		else:
			# Handle pure losses
			update_streak(hand_index, result.outcome)
	
	emit_signal("chips_updated", player_chips)
	PlayerData.player_data["total_balance"] = player_chips
	print("Debug - Final player chips after processing results: ", player_chips)


# Helper Functions
func calculate_hand_value(hand: Array) -> int:
	var value = 0
	var aces = 0
	
	for card in hand:
		if card.value in ["J", "Q", "K"]:
			value += 10
		elif card.value == "A":
			aces += 1
		else:
			value += int(card.value)
	
	for i in range(aces):
		if value + 11 <= 21:
			value += 11
		else:
			value += 1
	
	return value

func is_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and calculate_hand_value(hand) == 21

func is_twenty_one(hand: Array) -> bool:
	return calculate_hand_value(hand) == 21

func is_bust(hand: Array) -> bool:
	return calculate_hand_value(hand) > 21

func can_split(hand_index: int) -> bool:
	var hand = player_hands[hand_index]
	return hand.size() == 2 and hand[0].value == hand[1].value and find_empty_hand() != -1

func find_empty_hand() -> int:
	for i in range(MAX_HANDS):
		if player_hands[i].is_empty():
			return i
	return -1

func find_first_active_hand() -> int:
	for i in range(MAX_HANDS):
		if not player_hands[i].is_empty() and not is_twenty_one(player_hands[i]):
			return i
	return -1

func find_next_active_hand(start_index: int) -> int:
	for i in range(start_index, MAX_HANDS):
		if not player_hands[i].is_empty() and not is_twenty_one(player_hands[i]):
			return i
	return -1

func _determine_single_hand_result(hand_index: int, player_value: int, dealer_value: int, dealer_blackjack: bool) -> Dictionary:
	var result = {
		"hand_index": hand_index,
		"player_value": player_value,
		"dealer_value": dealer_value
	}
	
	if player_value > 21:
		result["outcome"] = HandResult.BUST
	elif dealer_value > 21:
		result["outcome"] = HandResult.WIN
		result["win_amount"] = current_bets[hand_index] * 2
	elif is_blackjack(player_hands[hand_index]) and not dealer_blackjack:
		result["outcome"] = HandResult.BLACKJACK
		result["win_amount"] = current_bets[hand_index] * 2.5
	elif dealer_blackjack and not is_blackjack(player_hands[hand_index]):
		result["outcome"] = HandResult.LOSE
	elif player_value > dealer_value:
		result["outcome"] = HandResult.WIN
		result["win_amount"] = current_bets[hand_index] * 2
	elif player_value < dealer_value:
		result["outcome"] = HandResult.LOSE
	else:
		result["outcome"] = HandResult.PUSH
		result["win_amount"] = current_bets[hand_index]
	
	return result

func update_streak(hand_index: int, outcome: HandResult) -> void:
	if current_bets[hand_index] < MIN_STREAK_BET:
		return
		
	print("Debug - Updating streak for hand %d:" % hand_index)
	print("- Previous streak count: %d" % streak_counts[hand_index])
	print("- Outcome: %s" % HandResult.keys()[outcome])
	
	var old_streak = streak_counts[hand_index]
	var multiplier_active = false
	
	match outcome:
		HandResult.WIN, HandResult.BLACKJACK:
			if streak_counts[hand_index] >= MAX_STREAK:
				# If we're already at max streak, apply multiplier and reset
				multiplier_active = true
				streak_counts[hand_index] = 0
				print("- Max streak achieved, applying multiplier and resetting to 0")
			else:
				# Normal increment
				streak_counts[hand_index] += 1
				print("- Incrementing streak to: %d" % streak_counts[hand_index])
				if streak_counts[hand_index] >= MAX_STREAK:
					multiplier_active = true
		HandResult.LOSE, HandResult.BUST:
			streak_counts[hand_index] = 0
			print("- Resetting streak to 0")
	
	# Only emit if streak changed or multiplier activated
	if old_streak != streak_counts[hand_index] or multiplier_active:
		emit_signal("streak_updated", hand_index, streak_counts[hand_index], multiplier_active)

func calculate_challenge_points(bet_amount: int, win_amount: int) -> int:
	return (bet_amount / 100) + (win_amount / 100) * 10

func get_total_bets() -> int:
	var total = current_bets.reduce(func(accum, bet): return accum + bet, 0)
	print("Debug: Total bets calculation: ", current_bets, " = ", total)
	return total

func get_bet_for_hand(hand_index: int) -> int:
	if hand_index >= 0 and hand_index < current_bets.size():
		return current_bets[hand_index]
	return 0

func dealer_reveal_complete() -> void:
	state_machine.change_state(BlackjackStateMachine.State.GAME_OVER)

func _validate_bets() -> bool:
	return current_bets.reduce(func(accum, bet): return accum + bet, 0) > 0

func reset_deck() -> void:
	deck = create_deck()
	shuffle_deck()

func _on_return_to_hub() -> void:
	# Reset previous bets when leaving the scene
	previous_bets = [0, 0, 0]
	current_bets = [0, 0, 0]
	
	# Update server balance as before
	APIManager.update_server_balance(player_chips)
