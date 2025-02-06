# JackpotSNGPanel.gd
extends "res://scripts/BaseGamePanel.gd"

signal unregister_requested(stake_level)
signal registration_timeout(stake_level)
signal start_game_requested(stake_level)  # New signal

const JACKPOT_STAKES = [50000, 100000, 300000, 1000000]
const REGISTRATION_TIMEOUT = 1800  # 30 minutes in seconds

@onready var unregister_button = $UnregisterButton
@onready var registration_timer = $RegistrationTimer
@onready var status_label = $StatusLabel

var registration_time_remaining = 0
var is_registered = false

func _ready():
	super._ready()
	stakes = JACKPOT_STAKES
	setup_stake_slider()
	
	unregister_button.pressed.connect(_on_unregister_pressed)
	registration_timer.timeout.connect(_on_registration_timeout)
	unregister_button.hide()

func get_required_balance(stake: int) -> int:
	return stake  # For Jackpot SNGs, required balance is the stake amount

# Override base class method
func _on_play_pressed():
	if not is_registered:
		is_registered = true
		unregister_button.show()
		status_label.text = "Waiting for opponents..."
		registration_time_remaining = REGISTRATION_TIMEOUT
		registration_timer.start(10.0)  # 10 seconds for testing
		emit_signal("play_pressed", game_type, stakes[stake_slider.value])

func _on_unregister_pressed():
	is_registered = false
	registration_timer.stop()
	unregister_button.hide()
	status_label.text = ""
	emit_signal("unregister_requested", stakes[stake_slider.value])

func _process(delta):
	if is_registered and registration_timer.time_left > 0:
		var minutes = floor(registration_timer.time_left / 60)
		var seconds = fmod(registration_timer.time_left, 60)
		status_label.text = "Waiting for opponents... %02d:%02d" % [minutes, seconds]

func _on_registration_timeout():
	if is_registered:
		is_registered = false
		status_label.text = "Starting game with AI players..."
		emit_signal("start_game_requested", stakes[stake_slider.value])
		unregister_button.hide()
