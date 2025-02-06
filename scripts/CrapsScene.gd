extends Control

# Signals
signal bet_placed(area: String, amount: int, position: Vector2)
signal bet_removed(area: String, amount: int)
signal bet_won(area: String, amount: int, payout: int)
signal bet_lost(area: String, amount: int)
signal dice_rolled(die1: int, die2: int)
signal game_state_changed(state: String)

# Onready variables
@onready var table = $Table
@onready var betting_areas = $Table/BettingAreas
@onready var dice_container = $DiceContainer
@onready var bet_amount_selector = $Controls/BetAmountSelector
@onready var roll_button = $Controls/RollButton
@onready var balance_label = $UI/BalanceLabel
@onready var current_point_label = $UI/CurrentPointLabel
@onready var last_roll_label = $UI/LastRollLabel
@onready var chip_container = $ChipContainer
@onready var dice_manager: DiceManager = $DiceManager
@onready var bet_manager: BetManager = $BetManager
@onready var chips_container = $ChipsContainer
@onready var chip_manager: ChipManager = $ChipManager

# Game state variables
var current_point: int = 0
var game_phase: String = "come_out" # come_out or point
var active_bets: Dictionary = {}
var current_bet_type: String = ""
var current_bet_amount: int = 0
var come_point_bets: Dictionary = {}
var dont_come_point_bets: Dictionary = {}

# Constants for bet types and payouts
const PAYOUTS = {
	"pass_line": 1,
	"dont_pass": 1,
	"come": 1,
	"dont_come": 1,
	"field": {
		"normal": 1,
		"double": 2,  # For 2
		"triple": 3   # For 12
	},
	"hardways": {
		"4": 7,
		"6": 9,
		"8": 9,
		"10": 7
	}
}

func _ready():
	initialize_betting_areas()
	initialize_controls()
	update_balance_display()
	connect_signals()
	dice_manager.roll_completed.connect(_on_dice_roll_completed)
	setup_bet_manager()
	setup_chip_manager()

func initialize_betting_areas():
	# Setup collision/detection areas for each betting region
	for area in betting_areas.get_children():
		area.connect("input_event", _on_betting_area_input_event.bind(area.name))

func initialize_controls():
	roll_button.disabled = true
	bet_amount_selector.value = 1
	bet_amount_selector.connect("value_changed", _on_bet_amount_changed)
	roll_button.connect("pressed", _on_roll_pressed)

func connect_signals():
	# Connect to player data signals
	PlayerData.balance_updated.connect(_on_balance_updated)

func place_bet(area: String, amount: int):
	if not can_place_bet(area, amount):
		return
		
	# Deduct bet amount from player balance
	PlayerData.update_total_balance(-amount)
	
	# Add bet to active bets
	if not active_bets.has(area):
		active_bets[area] = 0
	active_bets[area] += amount
	
	# Create and position chip visual
	create_chip_visual(get_betting_area_position(area), amount)
	
	# Enable roll button if this is a valid starting bet
	update_roll_button_state()
	
	# Emit signal for bet placement
	emit_signal("bet_placed", area, amount)

func can_place_bet(area: String, amount: int) -> bool:
	# Check if player has enough balance
	if PlayerData.get_balance() < amount:
		return false
		
	# Check if bet is valid for current game phase
	match game_phase:
		"come_out":
			if not (area in ["pass_line", "dont_pass", "field"]):
				return false
		"point":
			if area in ["pass_line", "dont_pass"]:
				return false
				
	return true

func _on_roll_pressed():
	roll_dice()

func roll_dice():
	if not can_roll():
		return
		
	roll_button.disabled = true
	dice_manager.roll()

func can_roll() -> bool:
	if dice_manager.is_rolling:
		return false
	
	# Check if player has valid bets
	if active_bets.is_empty():
		return false
		
	# Additional game state checks can be added here
	return true

func _on_dice_roll_completed(die1: int, die2: int):
	var total = die1 + die2
	
	# Update UI
	last_roll_label.text = "Last Roll: %d + %d = %d" % [die1, die2, total]
	
	# Process the roll result
	process_roll_result(total)
	
	# Re-enable roll button if appropriate
	update_roll_button_state()

func process_come_out_roll(total: int):
	match total:
		7, 11:
			pay_pass_line_bets()
			collect_dont_pass_bets()
		2, 3:
			collect_pass_line_bets()
			pay_dont_pass_bets()
		12:
			collect_pass_line_bets()
			return_dont_pass_bets()  # Push on 12
		_:
			current_point = total
			game_phase = "point"
			emit_signal("game_state_changed", "point")

func process_point_roll(total: int):
	if total == current_point:
		pay_pass_line_bets()
		collect_dont_pass_bets()
		reset_game()
	elif total == 7:
		collect_pass_line_bets()
		pay_dont_pass_bets()
		reset_game()

func update_roll_button_state():
	roll_button.disabled = not can_roll()

func update_balance_display():
	balance_label.text = "Balance: " + str(PlayerData.get_balance())

func _on_balance_updated(new_balance: int):
	update_balance_display()
	update_bet_controls_state()

func update_bet_controls_state():
	var balance = PlayerData.get_balance()
	bet_amount_selector.max_value = min(balance, 1000)  # Set maximum bet
	bet_amount_selector.disabled = balance <= 0

func setup_bet_manager():
	if not bet_manager:
		push_error("BetManager node not found")
		return
		
	if bet_manager.is_connected("bet_placed", _on_bet_placed):
		bet_manager.disconnect("bet_placed", _on_bet_placed)
	if bet_manager.is_connected("bet_won", _on_bet_won):
		bet_manager.disconnect("bet_won", _on_bet_won)
	if bet_manager.is_connected("bet_lost", _on_bet_lost):
		bet_manager.disconnect("bet_lost", _on_bet_lost)
	if bet_manager.is_connected("bet_removed", _on_bet_removed):
		bet_manager.disconnect("bet_removed", _on_bet_removed)
	
	bet_manager.bet_placed.connect(_on_bet_placed)
	bet_manager.bet_won.connect(_on_bet_won)
	bet_manager.bet_lost.connect(_on_bet_lost)
	bet_manager.bet_removed.connect(_on_bet_removed)

func _on_bet_placed(bet_type: String, amount: int, position: Vector2):
	create_chip_visual(position, amount)

func create_chip_visual(position: Vector2, amount: int):
	var chip_sprite = Sprite2D.new()
	chip_sprite.texture = load("res://assets/chips/chip_%d.png" % get_chip_texture_value(amount))
	chip_sprite.position = position
	chips_container.add_child(chip_sprite)

func remove_chip_visual(bet_type: String):
	# Implementation depends on how you're tracking chip visuals
	pass

# Update process_roll_result to use BetManager
func process_roll_result(total: int):
	match game_phase:
		"come_out":
			bet_manager.process_come_out_roll(total)
			if total in [7, 11]:
				reset_game()
			elif total in [2, 3, 12]:
				reset_game()
			else:
				current_point = total
				game_phase = "point"
				current_point_label.text = "Point: %d" % total
		"point":
			bet_manager.process_point_roll(total, current_point)
			if total == current_point or total == 7:
				reset_game()
	
	update_game_state_display()

func reset_game():
	current_point = 0
	game_phase = "come_out"
	current_point_label.text = "Point: Come Out"
	bet_manager.reset_bets()

func setup_chip_manager():
	if not chip_manager:
		push_error("ChipManager node not found")
		return
		
	if chip_manager.is_connected("chips_animated", _on_chips_animated):
		chip_manager.disconnect("chips_animated", _on_chips_animated)
		
	chip_manager.chips_animated.connect(_on_chips_animated)

func _on_betting_area_input_event(_viewport, event: InputEvent, _shape_idx, area_name: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_position = get_local_mouse_position()
		attempt_place_bet(area_name, current_bet_amount, local_position)

func attempt_place_bet(bet_type: String, amount: int, position: Vector2) -> void:
	if not bet_manager.can_place_bet(bet_type, amount, game_phase, current_point):
		return
	
	if PlayerData.get_balance() < amount:
		# Show insufficient funds message
		return
	
	if bet_manager.place_bet(bet_type, amount, position):
		PlayerData.update_total_balance(-amount)
		chip_manager.place_bet(bet_type, amount, position)
		update_roll_button_state()

func _on_bet_won(bet_type: String, bet_amount: int, payout: int):
	PlayerData.update_total_balance(bet_amount + payout)
	chip_manager.collect_chips(bet_type, true)

func _on_bet_lost(bet_type: String, _amount: int):
	chip_manager.collect_chips(bet_type, false)

func _on_bet_removed(bet_type: String, amount: int):
	PlayerData.update_total_balance(amount)  # Return the bet
	chip_manager.collect_chips(bet_type, false)

func _on_chips_animated():
	update_roll_button_state()

func _on_bet_amount_changed(value: int) -> void:
	current_bet_amount = value
	update_roll_button_state()

func update_game_state_display() -> void:
	match game_phase:
		"come_out":
			current_point_label.text = "Point: Come Out"
		"point":
			current_point_label.text = "Point: %d" % current_point

# These functions should be in BetManager instead of CrapsScene
func pay_pass_line_bets() -> void:
	if active_bets.has("pass_line"):
		var amount = active_bets["pass_line"]
		PlayerData.update_total_balance(amount * 2)  # Return bet plus winnings
		active_bets.erase("pass_line")

func collect_pass_line_bets() -> void:
	active_bets.erase("pass_line")

func pay_dont_pass_bets() -> void:
	if active_bets.has("dont_pass"):
		var amount = active_bets["dont_pass"]
		PlayerData.update_total_balance(amount * 2)  # Return bet plus winnings
		active_bets.erase("dont_pass")

func collect_dont_pass_bets() -> void:
	active_bets.erase("dont_pass")

func return_dont_pass_bets() -> void:
	if active_bets.has("dont_pass"):
		var amount = active_bets["dont_pass"]
		PlayerData.update_total_balance(amount)  # Return original bet
		active_bets.erase("dont_pass")

# Fix the chip texture value function
func get_chip_texture_value(amount: int) -> int:
	# Define chip denominations
	var denominations = [1, 5, 25, 100, 500, 1000, 5000]
	# Find the highest denomination that's less than or equal to amount
	var best_value = 1
	for denom in denominations:
		if denom <= amount and denom > best_value:
			best_value = denom
	return best_value

func get_betting_area_position(area: String) -> Vector2:
	if betting_areas.has_node(area):
		return betting_areas.get_node(area).global_position
	return Vector2.ZERO
