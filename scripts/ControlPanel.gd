extends Control

# Signals must be declared at the top of the script
signal spin_pressed
signal auto_play_toggled(enabled: bool)
signal bet_changed(amount: int)
signal max_bet_pressed
signal paytable_requested

# Properties
var min_bet: int = 100
var max_bet: int = 10000
var current_bet: int = min_bet
var bet_increment: int = 100
var is_auto_playing: bool = false

# Onready vars
@onready var bet_amount_display = $BetControls/BetAmountDisplay
@onready var spin_button = $BetControls/SpinButton
@onready var auto_play_button = $ActionButtons/AutoPlayButton
@onready var max_bet_button = $ActionButtons/MaxBetButton
@onready var paytable_button = $PaytableButton

func _ready():
	print("ControlPanel: Script initialized")
	custom_minimum_size = Vector2(700, 100)
	_update_display()
	_connect_signals()
	set_betting_enabled(true)  # Make sure buttons start enabled

func _connect_signals():
	print("ControlPanel: Connecting button signals")  # Debug print
	
	if spin_button:
		spin_button.pressed.connect(func(): emit_signal("spin_pressed"))
		print("Connected spin button")
	
	if auto_play_button:
		auto_play_button.pressed.connect(_on_auto_play_pressed)
		print("Connected auto play button")
	
	if max_bet_button:
		max_bet_button.pressed.connect(_on_max_bet_pressed)
		print("Connected max bet button")
	
	if paytable_button:
		paytable_button.pressed.connect(_on_paytable_pressed)
		print("Connected paytable button")
	
	var bet_down = $BetControls/BetDownButton
	var bet_up = $BetControls/BetUpButton
	
	if bet_down:
		bet_down.pressed.connect(_on_bet_down)
		print("Connected bet down button")
	
	if bet_up:
		bet_up.pressed.connect(_on_bet_up)
		print("Connected bet up button")

func set_betting_enabled(enabled: bool):
	$BetControls/BetDownButton.disabled = !enabled
	$BetControls/BetUpButton.disabled = !enabled
	spin_button.disabled = !enabled
	max_bet_button.disabled = !enabled

func _update_display():
	if bet_amount_display:
		bet_amount_display.text = "Bet: " + Utilities.format_number(current_bet)

func _on_bet_down():
	if current_bet > min_bet:
		current_bet -= bet_increment
		_update_display()
		emit_signal("bet_changed", current_bet)

func _on_bet_up():
	if current_bet < max_bet:
		current_bet += bet_increment
		_update_display()
		emit_signal("bet_changed", current_bet)

func _on_spin_pressed():
	emit_signal("spin_pressed")

func _on_auto_play_pressed():
	is_auto_playing = !is_auto_playing
	auto_play_button.text = "Stop" if is_auto_playing else "Auto"
	emit_signal("auto_play_toggled", is_auto_playing)

func _on_max_bet_pressed():
	current_bet = max_bet
	_update_display()
	emit_signal("bet_changed", current_bet)
	emit_signal("max_bet_pressed")

func _on_paytable_pressed():
	emit_signal("paytable_requested")
