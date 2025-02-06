extends VBoxContainer

signal fold_pressed
signal check_call_pressed
signal raise_pressed

@onready var fold_button = $ActionButtons/FoldButton
@onready var check_call_button = $ActionButtons/CheckCallButton
@onready var raise_button = $ActionButtons/RaiseButton
@onready var bet_slider = $BetControl/BetSlider
@onready var bet_amount = $BetControl/BetAmount

func _ready():
	# Connect button signals
	fold_button.pressed.connect(_on_fold_pressed)
	check_call_button.pressed.connect(_on_check_call_pressed)
	raise_button.pressed.connect(_on_raise_pressed)
	
	# Connect bet control signals
	bet_slider.value_changed.connect(_on_bet_slider_changed)
	bet_amount.value_changed.connect(_on_bet_amount_changed)

func _on_fold_pressed():
	print("Debug: Fold button pressed in ActionUI")
	emit_signal("fold_pressed")

func _on_check_call_pressed():
	print("Debug: Check/Call button pressed in ActionUI")
	emit_signal("check_call_pressed")

func _on_raise_pressed():
	print("Debug: Raise button pressed in ActionUI")
	emit_signal("raise_pressed")
	
func update_bet_limits(min_bet: int, max_bet: int, default_bet: int = -1):
	# Get current player's total chips
	var current_player = get_node("/root/JackpotSNGGameManager").players[0]  # Player 1 is human
	var max_possible_bet = current_player.chips + current_player.bet
	
	bet_slider.min_value = min_bet
	bet_slider.max_value = max_possible_bet
	bet_amount.min_value = min_bet
	bet_amount.max_value = max_possible_bet
	
	if default_bet != -1:
		bet_slider.value = min(default_bet, max_possible_bet)
		bet_amount.value = min(default_bet, max_possible_bet)
	else:
		bet_slider.value = min_bet
		bet_amount.value = min_bet

func _on_bet_slider_changed(value: float):
	if bet_amount.value != value:
		bet_amount.value = value

func _on_bet_amount_changed(value: float):
	if bet_slider.value != value:
		bet_slider.value = value

func enable_controls(enabled: bool = true):
	fold_button.disabled = not enabled
	check_call_button.disabled = not enabled
	raise_button.disabled = not enabled
	bet_slider.editable = enabled
	bet_amount.editable = enabled

func update_call_button_text(text: String):
	check_call_button.text = text

func update_raise_button_text(text: String):
	raise_button.text = text
