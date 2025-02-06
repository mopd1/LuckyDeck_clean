# BaseGamePanel.gd
extends Panel

signal play_pressed(game_type, stake)

@onready var title_label = $TitleLabel
@onready var stake_slider = $StakeSlider
@onready var min_balance_label = $MinBalanceLabel
@onready var play_button = $PlayButton

var game_type: String
var available: bool = false
var stakes = []

func _ready():
	show()
	print("BaseGamePanel initialized: ", game_type if game_type else "No game type set")

func setup_stake_slider():
	print("Debug: Setting up stake slider with stakes:", stakes)
	stake_slider.min_value = 0
	stake_slider.max_value = stakes.size()
	stake_slider.step = 1
	stake_slider.value = 0
	stake_slider.show()

	if not stake_slider.is_connected("value_changed", _on_stake_changed):
		stake_slider.value_changed.connect(_on_stake_changed)

	_on_stake_changed(stake_slider.value)

func _on_stake_changed(value: float):
	var stake_index = clamp(int(value), 0, stakes.size() - 1)
	var stake = stakes[stake_index]
	var required_balance = get_required_balance(stake)
	min_balance_label.text = "Required Balance: " + Utilities.format_number(required_balance)
	_update_play_button_state()

func get_required_balance(stake: int) -> int:
	return stake  # Override in child classes

func _update_play_button_state():
	if not available:
		play_button.disabled = true
		return

	var stake_index = clamp(int(stake_slider.value), 0, stakes.size() - 1)
	var stake = stakes[stake_index]
	var required_balance = get_required_balance(stake)
	play_button.disabled = not PlayerData.has_sufficient_balance(required_balance)

func _on_play_pressed():
	if not available:
		return

	var stake_index = clamp(int(stake_slider.value), 0, stakes.size() - 1)
	var stake = stakes[stake_index]
	emit_signal("play_pressed", game_type, stake)

func set_game_type(type: String, is_available: bool):
	game_type = type
	available = is_available
	
	if title_label:
		title_label.text = type
		title_label.show()

	if available:
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
		if stake_slider:
			stake_slider.hide()
		if min_balance_label:
			min_balance_label.hide()
		if play_button:
			play_button.text = "Coming Soon"
			play_button.disabled = true
			play_button.show()
