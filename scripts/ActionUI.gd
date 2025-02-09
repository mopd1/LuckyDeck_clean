# ActionUI.gd
extends HBoxContainer

signal fold_pressed
signal check_call_pressed
signal raise_pressed

var game_manager: Node = null
var is_updating = false

func _ready():
	$ActionButtons/FoldButton.pressed.connect(_on_fold_pressed)
	$ActionButtons/CheckCallButton.pressed.connect(_on_check_call_pressed)
	$ActionButtons/RaiseButton.pressed.connect(_on_raise_pressed)
	
	$BetControl/BetSlider.value_changed.connect(_on_bet_changed)
	$ActionButtons/BetAmount.value_changed.connect(_on_bet_changed)
	
	var bet_amount = $ActionButtons/BetAmount
	if bet_amount:
		# Get the internal LineEdit for the SpinBox
		var line_edit = bet_amount.get_line_edit()
		if line_edit:
			line_edit.context_menu_enabled = false
			line_edit.middle_mouse_paste_enabled = false
			line_edit.text_changed.connect(func(new_text: String):
				# Only allow numbers
				var cleaned_text = ""
				for c in new_text:
					if c.is_valid_int():
						cleaned_text += c
				if cleaned_text != new_text:
					line_edit.text = cleaned_text
					line_edit.caret_column = cleaned_text.length()
			)

func setup(manager: Node):
	game_manager = manager
	
	# Connect button signals to manager
	$ActionButtons/FoldButton.pressed.connect(game_manager._on_fold_pressed)
	$ActionButtons/CheckCallButton.pressed.connect(game_manager._on_check_call_pressed)
	$ActionButtons/RaiseButton.pressed.connect(game_manager._on_raise_pressed)
	
	_update_controls()

func _update_controls():
	if game_manager and game_manager.players and game_manager.current_player_index >= 0:
		update_bet_limits(
			game_manager.current_bet,
			game_manager.players[game_manager.current_player_index].chips,
			game_manager.current_bet + game_manager.last_bet_amount
		)
	else:
		push_error("GameManager or players not initialized in _update_controls()")

func _on_fold_pressed():
	emit_signal("fold_pressed")

func _on_check_call_pressed():
	emit_signal("check_call_pressed")

func _on_raise_pressed():
	emit_signal("raise_pressed")

func update_bet_limits(min_bet, max_bet, default_bet_amount = -1):
	print("DEBUG: Updating bet limits")
	print("- Min Bet:", min_bet)
	print("- Max Bet:", max_bet)
	print("- Default Bet Amount:", default_bet_amount)

	# Ensure min_bet does not exceed max_bet
	min_bet = min(min_bet, max_bet)

	$BetControl/BetSlider.min_value = min_bet
	$BetControl/BetSlider.max_value = max_bet
	$ActionButtons/BetAmount.min_value = min_bet
	$ActionButtons/BetAmount.max_value = max_bet

	# If min_bet equals max_bet, disable the controls
	var bet_controls_disabled = min_bet == max_bet
	$BetControl/BetSlider.editable = not bet_controls_disabled
	$ActionButtons/BetAmount.editable = not bet_controls_disabled

	# Set the default bet amount
	if default_bet_amount == -1:
		var current_value = $ActionButtons/BetAmount.value
		$ActionButtons/BetAmount.value = clamp(current_value, min_bet, max_bet)
	else:
		$ActionButtons/BetAmount.value = clamp(default_bet_amount, min_bet, max_bet)

	_on_bet_changed($ActionButtons/BetAmount.value)

func _on_bet_changed(value):
	print("DEBUG: _on_bet_changed called with value:", value)
	if is_updating:
		print("DEBUG: is_updating is true, returning")
		return

	is_updating = true

	$BetControl/BetSlider.value = value
	$ActionButtons/BetAmount.value = value

	if game_manager and game_manager.players:
		var current_player = game_manager.players[game_manager.current_player_index]
		if current_player:
			update_button_text(
				game_manager.current_bet,
				current_player.bet,
				value  # Use the selected bet amount
			)
		else:
			push_error("Current player is null")
	else:
		push_error("Could not find GameManager node or players not initialized")

	is_updating = false

func set_bet_amount(amount):
	is_updating = true
	$ActionButtons/BetAmount.value = amount
	$BetControl/BetSlider.value = amount
	is_updating = false

func update_button_text(current_bet: int, player_bet: int, bet_amount: int, can_meet_min_raise: bool = true):
	if not game_manager:
		return

	var current_player = game_manager.players[game_manager.current_player_index]
	var call_amount = current_bet - player_bet

	print("- call_amount calculated:", call_amount)
	# Use current_round instead of current_betting_round
	print("- can check:", call_amount == 0 or (
		game_manager.table_data.current_round == "preflop" and
		player_bet == game_manager.table_data.stake_level and
		current_bet == game_manager.table_data.stake_level))

	# Update CheckCall button
	var check_call_button = $ActionButtons/CheckCallButton
	if call_amount == 0 or (
		game_manager.table_data.current_round == "preflop" and
		player_bet == game_manager.table_data.stake_level and
		current_bet == game_manager.table_data.stake_level
	):
		check_call_button.text = "Check"
	else:
		var call_text = "All-In " if call_amount >= current_player.chips else "Call "
		check_call_button.text = call_text + Utilities.format_number(min(call_amount, current_player.chips))

	# Update Raise button
	var raise_button = $ActionButtons/RaiseButton
	if not can_meet_min_raise:
		raise_button.text = "All-In " + Utilities.format_number(current_player.chips + player_bet)
	else:
		if bet_amount >= current_player.chips + player_bet:
			raise_button.text = "All-In " + Utilities.format_number(bet_amount)
		else:
			if current_bet == 0:
				raise_button.text = "Bet " + Utilities.format_number(bet_amount)
			else:
				raise_button.text = "Raise to " + Utilities.format_number(bet_amount)
