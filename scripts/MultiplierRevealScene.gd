# MultiplierRevealScene.gd
extends Control

signal reveal_completed

@onready var multiplier_label = $MultiplierLabel
@onready var prize_label = $PrizeLabel
@onready var player_containers = [
	$Player1Container,
	$Player2Container,
	$Player3Container
]
@onready var animation_player = $AnimationPlayer

var final_multiplier: float
var final_prize: int

func start_reveal(multiplier: float, prize: int, players: Array):
	final_multiplier = multiplier
	final_prize = prize
	
	# Setup player displays
	for i in range(players.size()):
		_setup_player_display(player_containers[i], players[i])
	
	# Start animation
	animation_player.play("multiplier_reveal")
	await get_tree().create_timer(5.0).timeout
	_show_final_result()

func _setup_player_display(container: Control, player_data: Dictionary):
	container.get_node("NameLabel").text = player_data.name
	# Setup avatar using existing avatar system
	
func _show_final_result():
	multiplier_label.text = str(final_multiplier) + "x"
	prize_label.text = "Prize: " + Utilities.format_number(final_prize) + " chips"
	emit_signal("reveal_completed")
