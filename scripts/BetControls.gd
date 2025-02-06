class_name BetControls
extends Control

signal bet_updated(hand_index: int, new_amount: int)

var hand_index: int
var blackjack_manager = BlackjackManager

# Use @onready for node references
@onready var bet_label = $BetLabel
@onready var bet_10k = $HBoxContainer/Bet10kButton
@onready var bet_100k = $HBoxContainer/Bet100kButton
@onready var bet_1m = $HBoxContainer/Bet1mButton

# Variable to track bet history
var bet_history = []

func _ready():
	# Wait for scene tree to be ready
	await get_tree().process_frame

	print("Debug - BetControls init:")
	print("- Hand index: ", hand_index)
	print("- BlackjackManager found: ", is_instance_valid(blackjack_manager))
	print("- Current node path: ", get_path())

	# Verify all required nodes exist
	if not _verify_nodes():
		push_error("Required nodes not found in BetControls")
		return
		
	# Connect button signals
	_connect_signals()
	
	# Initialize display with current state from BlackjackManager
	update_display()
	update_button_states()

func _verify_nodes() -> bool:
	print("Debug - Verifying BetControls nodes for hand ", hand_index)
	var all_nodes_present = true
	
	if not bet_label:
		push_error("BetLabel node not found")
		all_nodes_present = false
	else:
		print("- BetLabel found")
	
	if not bet_10k:
		push_error("Bet10kButton node not found")
		all_nodes_present = false
	else:
		print("- Bet10kButton found")
		
	if not bet_100k:
		push_error("Bet100kButton node not found")
		all_nodes_present = false
	else:
		print("- Bet100kButton found")
		
	if not bet_1m:
		push_error("Bet1mButton node not found")
		all_nodes_present = false
	else:
		print("- Bet1mButton found")
	
	return all_nodes_present

func _connect_signals():
	print("Debug - Connecting signals for BetControls ", hand_index)

	# First disconnect any existing connections to avoid duplicates
	if bet_10k.pressed.is_connected(_on_10k_pressed):
		bet_10k.pressed.disconnect(_on_10k_pressed)
	if bet_100k.pressed.is_connected(_on_100k_pressed):
		bet_100k.pressed.disconnect(_on_100k_pressed)
	if bet_1m.pressed.is_connected(_on_1m_pressed):
		bet_1m.pressed.disconnect(_on_1m_pressed)

	# Connect button signals
	bet_10k.pressed.connect(_on_10k_pressed)
	bet_100k.pressed.connect(_on_100k_pressed)
	bet_1m.pressed.connect(_on_1m_pressed)

	print("Debug - Signals connected for BetControls ", hand_index)

func _on_10k_pressed():
	print("Debug - 10k button pressed for hand ", hand_index)
	add_bet(10000)

func _on_100k_pressed():
	print("Debug - 100k button pressed for hand ", hand_index)
	add_bet(100000)

func _on_1m_pressed():
	print("Debug - 1M button pressed for hand ", hand_index)
	add_bet(1000000)

func add_bet(amount: int):
	print("Debug - Adding bet for hand %d: Amount: %d" % [hand_index, amount])
	
	var current_bet = get_current_bet()
	var new_bet = current_bet + amount
	
	print("Debug - Current bet: %d, New bet will be: %d" % [current_bet, new_bet])
	set_current_bet(new_bet, false)

func get_current_bet() -> int:
	return bet_history.reduce(func(accum, amount): return accum + amount, 0)

func get_max_additional_bet() -> int:
	if not is_instance_valid(blackjack_manager):
		return 0
		
	var total_other_bets = blackjack_manager.get_total_bets() - get_current_bet()
	return blackjack_manager.player_chips - total_other_bets

func undo_last_bet() -> bool:
	if bet_history.is_empty():
		return false
		
	print("Debug - Undoing last bet for hand %d" % hand_index)
	print("- Current bet history: ", bet_history)
	
	# Clear the entire bet
	bet_history.clear()
	var success = blackjack_manager.place_bet(hand_index, 0)
	
	print("- Bet history after undo: ", bet_history)
	update_display()
	update_button_states()
	
	return success

func update_display():
	var current_bet = get_current_bet()
	if bet_label:
		bet_label.text = "Bet: " + Utilities.format_number(current_bet)
	print("Debug - Updated display for hand %d: %d" % [hand_index, current_bet])

func update_button_states():
	if not is_instance_valid(blackjack_manager):
		blackjack_manager = BlackjackManager
	if not is_instance_valid(blackjack_manager):
		push_error("BlackjackManager not found when updating button states")
		return
	
	# Get maximum allowed additional bet
	var max_additional = get_max_additional_bet()
	
	print("Debug - Hand %d button state update:" % hand_index)
	print("- Current bet: %d" % get_current_bet())
	print("- Max additional bet allowed: %d" % max_additional)
	
	if bet_10k:
		bet_10k.disabled = max_additional < 10000
	if bet_100k:
		bet_100k.disabled = max_additional < 100000
	if bet_1m:
		bet_1m.disabled = max_additional < 1000000

func set_bet_enabled(enable: bool) -> void:
	if bet_10k:
		bet_10k.disabled = not enable
	if bet_100k:
		bet_100k.disabled = not enable
	if bet_1m:
		bet_1m.disabled = not enable

func set_current_bet(amount: int, from_manager: bool = false):
	print("Debug - Setting current bet for hand %d to %d (from_manager=%s)" % [hand_index, amount, str(from_manager)])
	
	if from_manager:
		# Manager-initiated update
		bet_history.clear()
		if amount > 0:
			bet_history.append(amount)
		update_display()
		update_button_states()
		return
	
	# User-initiated update
	if amount == 0:
		bet_history.clear()
	elif amount > 0:
		bet_history = [amount]  # Just store the total amount
		
	var success = blackjack_manager.place_bet(hand_index, amount)
	if success:
		print("Debug - Current bets after set_current_bet: ", blackjack_manager.current_bets)
		update_display()
		update_button_states()
		emit_signal("bet_updated", hand_index, amount)
	else:
		print("Debug - Failed to place bet for Hand%d" % (hand_index + 1))
		bet_history.clear()  # Reset history if bet failed

func reset_bet(clear_history: bool = true):
	if clear_history:
		bet_history.clear()
	if blackjack_manager.place_bet(hand_index, 0):
		update_display()
		update_button_states()
