# ChallengePointsDisplay.gd
extends Label

func _ready():
	update_display()
	if not PlayerData.is_connected("challenge_points_updated", update_display):
		PlayerData.connect("challenge_points_updated", update_display)
	
	# Style the label
	add_theme_color_override("font_color", Color(1, 0.8, 0, 1))  # Gold color
	add_theme_font_size_override("font_size", 24)

func update_display(_points = null):
	text = "Challenge Points: %d" % PlayerData.player_data["challenge_points"]
