extends Panel

signal play_pressed(game_type, stake)

@onready var title_label = $TitleLabel
@onready var stake_slider = $StakeSlider
@onready var min_balance_label = $MinBalanceLabel
@onready var play_button = $PlayButton

var game_type: String
var available: bool = false
var stakes = GameJoiner.AVAILABLE_STAKES

func _ready():
	show()
	print("GamePanel initialized: ", game_type if game_type else "No game type set")
	print("Debug: Available stakes:", stakes)

func setup_stake_slider():
	print("Debug: Setting up stake slider with stakes:", stakes)
	stake_slider.min_value = 0
	stake_slider.max_value = stakes.size()  # Changed from size() - 1
	stake_slider.step = 1
	stake_slider.value = 0  # Start with lowest stake
	stake_slider.show()
	
	# Connect signals
	if not stake_slider.is_connected("value_changed", _on_stake_changed):
		stake_slider.value_changed.connect(_on_stake_changed)
	
	# Initialize with first value
	_on_stake_changed(stake_slider.value)
	print("Debug: Stake slider setup complete. Current value:", stake_slider.value)

func _on_stake_changed(value: float):
	var stake_index = clamp(int(value), 0, stakes.size() - 1)
	var stake = stakes[stake_index]
	print("Debug: Stake slider value:", value)
	print("Debug: Mapped to stake index:", stake_index)
	print("Debug: Selected stake amount:", stake)
	var required_balance = stake * 100
	min_balance_label.text = "Required Balance: " + Utilities.format_number(required_balance)
	_update_play_button_state()

func _update_play_button_state():
	if not available:
		play_button.disabled = true
		return
		
	var stake_index = clamp(int(stake_slider.value), 0, stakes.size() - 1)
	var stake = stakes[stake_index]
	var required_balance = stake * 100
	play_button.disabled = not PlayerData.has_sufficient_balance(required_balance)
	print("Debug: Updated play button state. Disabled:", play_button.disabled)

func _on_play_pressed():
	if not available:
		return
		
	var stake_index = clamp(int(stake_slider.value), 0, stakes.size() - 1)
	var stake = stakes[stake_index]
	print("Debug: Play pressed - Stake Index:", stake_index)
	print("Debug: Play pressed - Stakes Array:", stakes)
	print("Debug: Play pressed - Selected Stake:", stake)
	emit_signal("play_pressed", game_type, stake)

func set_game_type(type: String, is_available: bool):
	print("Debug: Setting game type: ", type, " Available: ", is_available)
	game_type = type
	available = is_available
	
	if title_label:
		title_label.text = type
		title_label.show()
		print("Debug: Set title label to: ", type)
	
	# Show/hide elements based on availability
	if available:
		print("Debug: Showing game elements for available game")
		if stake_slider:
			stake_slider.show()
			setup_stake_slider()
		if min_balance_label:
			min_balance_label.show()
		if play_button:
			play_button.text = "Play"
			play_button.disabled = false
			play_button.show()
			if not play_button.is_connected("pressed", _on_play_pressed):
				play_button.pressed.connect(_on_play_pressed)
	else:
		print("Debug: Hiding game elements for unavailable game")
		if stake_slider:
			stake_slider.hide()
		if min_balance_label:
			min_balance_label.hide()
		if play_button:
			play_button.text = "Coming Soon"
			play_button.disabled = true
			play_button.show()
