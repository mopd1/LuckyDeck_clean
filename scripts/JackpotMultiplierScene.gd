# JackpotMultiplierScene.gd
extends Control

@onready var multiplier_label = $MainContainer/MultiplierContainer/MultiplierLabel
@onready var prize_label = $MainContainer/MultiplierContainer/PrizeLabel
@onready var animation_player = $AnimationPlayer
@onready var players_container = $MainContainer/PlayersContainer

var final_multiplier: float
var final_prize: int

func _ready():
	print("Debug: JackpotMultiplierScene ready")

	# Hide values initially
	multiplier_label.text = "?"
	prize_label.text = "Prize: ?"

	# Start multiplier selection process
	var state = JackpotSNGManager.get_current_game_state()
	if state:
		setup_players(state.players)
		start_reveal(state.multiplier, state.prize)
	else:
		push_error("No game state found in JackpotMultiplierScene")
		SceneManager.return_to_main_hub()

# Add missing setup_players function
func setup_players(players_data: Array) -> void:
	print("Debug: Setting up players display")
	print("Debug: Players data:", players_data)
	
	# Get all player panels
	var player_panels = players_container.get_children()
	
	# Setup each player panel
	for i in range(player_panels.size()):
		var panel = player_panels[i]
		
		# Find the name label in the panel
		var name_label = panel.get_node_or_null("PlayerVBox/NameLabel")
		if name_label:
			if i < players_data.size():
				var player_data = players_data[i]
				var player_name = "Player " + str(i + 1)
				
				# Add "(You)" for the human player
				if str(player_data.id) == str(User.current_user_id):
					player_name += " (You)"
				
				name_label.text = player_name
				print("Debug: Set player", i + 1, "name to:", player_name)
			else:
				# Hide or disable panels for non-existent players
				panel.visible = false
		else:
			push_error("Could not find NameLabel for player " + str(i + 1))

func create_reveal_animation() -> void:
	print("Debug: Creating reveal animation")
	
	# Create new animation library
	var library = AnimationLibrary.new()
	
	# Create the animation
	var animation = Animation.new()
	animation.length = 5.0  # 5 seconds total

	# Add track for MultiplierLabel text
	var multiplier_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(multiplier_track, "MultiplierContainer/MultiplierLabel:text")
	
	# Add track for PrizeLabel text
	var prize_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(prize_track, "MultiplierContainer/PrizeLabel:text")
	
	# Add track for label modulation (for flashing effect)
	var color_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(color_track, "MultiplierContainer/MultiplierLabel:modulate")
	
	# Setup multiplier reveal sequence
	var possible_multipliers = JackpotSNGManager.MULTIPLIERS.keys()
	var time_per_change = 0.2
	var current_time = 0.0
	
	# First 4 seconds: Rapid multiplier changes
	while current_time < 4.0:
		var random_multiplier = possible_multipliers[randi() % possible_multipliers.size()]
		animation.track_insert_key(multiplier_track, current_time, str(random_multiplier) + "x")
		
		# Add flashing effect
		var flash_color = Color(1, 1, 1, 1) if int(current_time / 0.2) % 2 == 0 else Color(1, 0.8, 0, 1)
		animation.track_insert_key(color_track, current_time, flash_color)
		
		current_time += time_per_change
	
	# At 4.0 seconds: Show final multiplier
	animation.track_insert_key(multiplier_track, 4.0, str(final_multiplier) + "x")
	animation.track_insert_key(color_track, 4.0, Color(1, 0.8, 0, 1))  # Golden color for final value
	
	# At 4.5 seconds: Show prize
	animation.track_insert_key(prize_track, 4.5, "Prize: " + Utilities.format_number(final_prize))
	
	# Add animation to library
	library.add_animation("multiplier_reveal", animation)
	
	# Add library to animation player
	animation_player.add_animation_library("", library)
	print("Debug: Animation created successfully")

func start_reveal(multiplier: float, prize: int) -> void:
	print("Debug: Starting multiplier reveal with multiplier:", multiplier, "prize:", prize)
	final_multiplier = multiplier
	final_prize = prize

	if animation_player:
		# Create animation if it doesn't exist
		if not animation_player.has_animation("multiplier_reveal"):
			create_reveal_animation()

		print("Debug: Playing animation")
		animation_player.play("multiplier_reveal")
		
		# Connect to animation finished signal
		if not animation_player.is_connected("animation_finished", _on_animation_finished):
			animation_player.connect("animation_finished", _on_animation_finished)
	else:
		push_error("No AnimationPlayer found in JackpotMultiplierScene")
		_show_final_result()

func _on_animation_finished(anim_name: String):
	print("Debug: Animation finished:", anim_name)
	_show_final_result()

func _show_final_result():
	print("Debug: Showing final result")
	multiplier_label.text = str(final_multiplier) + "x"
	prize_label.text = "Prize: " + Utilities.format_number(final_prize)
	
	# Wait a moment before transitioning to game
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(_transition_to_game)

func _transition_to_game():
	print("Debug: Transitioning to Jackpot SNG game")
	SceneManager.goto_scene("res://scenes/JackpotSNGScene.tscn")
