extends Control

# Onready vars for UI elements
@onready var chip_balance_label = $GameArea/TopSection/Stats/ChipBalanceLabel
@onready var last_win_label = $GameArea/TopSection/Stats/LastWinLabel
@onready var bet_amount_label = $GameArea/TopSection/Stats/BetAmountLabel
@onready var reels_container = $GameArea/MainSection/PlayerSection/ReelsContainer
@onready var ai_reels = $GameArea/MainSection/AISection/AIReels
@onready var joker_meter = $GameArea/MainSection/VBoxContainer/JokerMeter
@onready var control_panel = $GameArea/BottomSection/ControlPanel
@onready var win_display = $UI_Overlays/WinDisplay
@onready var paytable_panel = $UI_Overlays/PaytablePanel
@onready var hand_strength_label = $GameArea/TopSection/Stats/HandStrengthLabel
@onready var ai_hand_strength_label = $GameArea/TopSection/Stats/AIHandStrengthLabel
@onready var return_to_hub_button = $ReturnToHubButton

# Constants
const REEL_COUNT = 5
const SYMBOL_COUNT = 3

# State variables
var slot_machine = preload("res://scripts/slot_machine.gd").new()
var reel_components = []
var is_spinning = false
var auto_play_active = false
var current_multiplier = 1
var ai_reel_components = []

func _ready():
	print("Starting SlotMachineScene initialization")
	add_child(slot_machine)
	_setup_reels()
	_connect_signals()
	_initialize_ui()
	return_to_hub_button.pressed.connect(_on_return_to_hub_button_pressed)
	
	# Connect AI reels spin completion if needed
	if ai_reels:
		ai_reels.connect("reel_spin_completed", _on_ai_reel_spin_completed)
	
	# Hide overlay panels initially
	if win_display:
		win_display.hide()
	if paytable_panel:
		paytable_panel.hide()

func _setup_reels():
	# Clear any existing reels first
	for child in reels_container.get_children():
		child.queue_free()
	reel_components.clear()
	
	# Now add new reels
	for i in range(REEL_COUNT):
		var reel = preload("res://scenes/ReelComponent.tscn").instantiate()
		reel.reel_index = i
		reels_container.add_child(reel)
		reel_components.append(reel)
		if reel.has_signal("spin_completed"):
			reel.connect("spin_completed", _on_reel_spin_completed)

func _connect_signals():
	print("DEBUG: Connecting signals in SlotMachineScene")
	# Slot machine signals
	if not slot_machine.is_connected("spin_completed", _on_spin_completed):
		slot_machine.connect("spin_completed", _on_spin_completed)
		print("DEBUG: Connected spin_completed signal")
		
	if not slot_machine.is_connected("win_evaluated", _on_win_evaluated):
		slot_machine.connect("win_evaluated", _on_win_evaluated)
		print("DEBUG: Connected win_evaluated signal")
	
	# Control panel signals
	if control_panel:
		print("Connecting control panel signals")
		# Connect all signals with error checking
		_safely_connect(control_panel, "spin_pressed", _on_spin_pressed)
		_safely_connect(control_panel, "auto_play_toggled", _on_auto_play_toggled)
		_safely_connect(control_panel, "bet_changed", _on_bet_changed)
		_safely_connect(control_panel, "max_bet_pressed", _on_max_bet_pressed)
		_safely_connect(control_panel, "paytable_requested", _on_paytable_requested)
	else:
		push_error("Control panel node not found")

func _safely_connect(source: Object, signal_name: String, method: Callable) -> void:
	if source.has_signal(signal_name):
		if not source.is_connected(signal_name, method):
			source.connect(signal_name, method)
			print("Successfully connected signal: ", signal_name)
	else:
		push_error("Signal not found: " + signal_name)

func _initialize_ui():
	if chip_balance_label:
		update_balance_display()
	if bet_amount_label:
		update_bet_display()
	if last_win_label:
		last_win_label.text = "Last Win: 0"

func _on_spin_pressed():
	if is_spinning:
		return
	
	var bet_amount = control_panel.current_bet
	if PlayerData.has_sufficient_balance(bet_amount):
		start_spin()
	else:
		_show_message("Insufficient funds!")

func start_spin():
	is_spinning = true
	var bet_amount = control_panel.current_bet
	control_panel.set_betting_enabled(false)  # Only disable during actual spin
	PlayerData.update_total_balance(-bet_amount)
	update_balance_display()
	
	# Start spin animation for each reel with slight delay
	for i in range(reel_components.size()):
		reel_components[i].start_spin(i * 0.2)
	
	# Start the actual slot machine spin
	slot_machine.start_spin(bet_amount)

func _on_reel_spin_completed(reel_index: int):
	print("Reel ", reel_index, " completed spinning")

func _on_ai_reel_spin_completed(reel_index: int):
	print("AI Reel ", reel_index, " completed spinning")
	# We can add additional AI-specific spin completion logic here if needed

func _on_spin_completed(result: Dictionary):
	print("DEBUG: Spin completed signal received")
	print("Spin completed with result: ", result)
	
	# Update player reels
	for i in range(reel_components.size()):
		var reel_symbols = []
		for j in range(SYMBOL_COUNT):
			reel_symbols.append(result.visible_symbols[i][j])
		reel_components[i].set_symbols(reel_symbols)
	
	# Update AI reels
	if ai_reels and result.has("ai_symbols"):
		ai_reels.update_symbols(result.ai_symbols)
		
		# If AI hand info is available, display it
		if result.has("ai_hand_type"):
			var ai_hand_label = $GameArea/TopSection/Stats/AIHandStrengthLabel
			if ai_hand_label:
				ai_hand_label.text = "AI Hand: " + format_hand_type(result.ai_hand_type)
	
	# Highlight winning hands
	_highlight_winning_symbols(result.wins)

func _highlight_winning_symbols(wins: Array):
	# Clear previous highlights
	for reel in reel_components:
		reel.clear_highlights()

	# Find the highest value win
	var best_win = null
	for win in wins:
		if !best_win or win["hand_rank_value"] > best_win["hand_rank_value"]:
			best_win = win
	
	# Highlight only the best winning hand
	if best_win != null:
		print("DEBUG: Highlighting best winning hand:", best_win["hand_type"])
		print("DEBUG: With value:", best_win["hand_rank_value"])
		var winning_positions = best_win["winning_positions"]
		for position in winning_positions:
			var reel_index = position["reel"]
			var row_index = position["row"]
			print("DEBUG: Highlighting player reel:", reel_index, "row:", row_index)
			if reel_index < reel_components.size():
				reel_components[reel_index].highlight_symbol(row_index)

func _on_win_evaluated(result: Dictionary):
	print("DEBUG: Win evaluation started")
	print("DEBUG: Player hand type:", result.player_best_hand_type)
	print("DEBUG: AI hand type:", result.ai_hand_type)
	print("DEBUG: Player beats AI:", result.player_beats_ai)

	if result.total_win > 0:
		# Calculate base multiplier (from Jokers etc.)
		var multiplier = calculate_current_multiplier(result)
		
		# Add 50% bonus if player beats AI
		if result.player_beats_ai:
			multiplier *= 1.5
			_show_message("50% Bonus - Your Hand Beats the AI!")
		
		var final_win = int(result.total_win * multiplier)  # Convert to int for whole chip amounts
		
		if final_win > 0:
			_show_win(final_win)
			PlayerData.update_total_balance(final_win)
			update_balance_display()

	# Display hands and highlight winning combinations
	if hand_strength_label:
		hand_strength_label.text = "Your Hand: " + format_hand_type(result.player_best_hand_type)
		
	# Highlight player's winning hand
	_highlight_winning_symbols(result.wins)
	
	# Highlight AI's best hand
	if result.has("ai_best_hand") and result.ai_best_hand != null:
		print("DEBUG: Processing AI hand highlighting:")
		print("- Hand type:", result.ai_best_hand["hand_type"])
		print("- Winning positions:", result.ai_best_hand.get("winning_positions", []))
		
		var ai_reels_node = $GameArea/MainSection/AISection/AIReels
		if ai_reels_node:
			if result.ai_best_hand.has("winning_positions") and not result.ai_best_hand["winning_positions"].is_empty():
				ai_reels_node.highlight_winning_hand(result.ai_best_hand["winning_positions"])
			else:
				print("DEBUG: No winning positions for AI hand")
		else:
			push_error("AI reels node not found")

	# Display comparison result
	var comparison_label = $GameArea/MainSection/ComparisonLabel
	if comparison_label:
		if result.player_beats_ai:
			comparison_label.text = "Your Hand Wins! (50% Bonus Applied)"
			comparison_label.modulate = Color.GREEN
		else:
			comparison_label.text = "AI Hand Wins"
			comparison_label.modulate = Color.RED

	is_spinning = false
	control_panel.set_betting_enabled(true)

	if auto_play_active:
		await get_tree().create_timer(1.0).timeout
		_on_spin_pressed()

func format_hand_type(hand_type: String) -> String:
	var words = hand_type.split("_")
	for i in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)

func calculate_current_multiplier(result: Dictionary) -> float:
	var multiplier = 1.0
	
	# Apply Joker multiplier
	#var jokers_collected = joker_meter.get_collected_jokers()
	#match jokers_collected:
		#1:
			#multiplier *= 2.0  # 2x payout
		#2:
			#multiplier *= 3.0  # 3x payout
		#3:
			#multiplier *= 5.0  # 5x payout
			# Trigger Joker bonus round if applicable
			#trigger_joker_bonus_round()
	
	# Apply AI bonus
	if result.player_beats_ai:
		multiplier *= 1.5  # 50% bonus
	
	return multiplier


func _show_win(amount: int):
	last_win_label.text = "Last Win: " + Utilities.format_number(amount)
	if win_display:
		win_display.show()
		if win_display.has_node("WinAmount"):
			win_display.get_node("WinAmount").text = Utilities.format_number(amount)
		await get_tree().create_timer(2.0).timeout
		win_display.hide()

func _show_message(message: String):
	print(message)  # For now, just print to console

func update_balance_display():
	chip_balance_label.text = "Balance: " + Utilities.format_number(PlayerData.get_balance())

func update_bet_display():
	if control_panel:
		bet_amount_label.text = "Bet: " + Utilities.format_number(control_panel.current_bet)

func _on_auto_play_toggled(enabled: bool):
	auto_play_active = enabled
	if enabled:
		_on_spin_pressed()

func _on_bet_changed(amount: int):
	update_bet_display()

func _on_max_bet_pressed():
	update_bet_display()

func _on_paytable_requested():
	if paytable_panel:
		paytable_panel.visible = !paytable_panel.visible

func _on_multiplier_changed(value: int):
	current_multiplier = value

func _on_return_to_hub_button_pressed():
	auto_play_active = false
	if APIManager and not APIManager.user_token.is_empty():
		APIManager.update_server_balance(PlayerData.get_balance())
	SceneManager.return_to_main_hub()

func test_basic_spin():
	print("Testing basic spin mechanism")
	start_spin()
