extends ColorRect

@onready var winner_label = $WinnerLabel

func _ready():
	hide()

func show_winner(winner_name: String, hand_description: String, pot_amount: int):
	var display_text = ""
	
	if winner_name == "Multiple Winners":
		# For multiple winners, hand_description contains the full breakdown
		display_text = "Multiple Winners\n"
		display_text += hand_description + "\n"
	else:
		# For single winner
		display_text = "%s wins!\n" % winner_name
		display_text += "Hand: %s\n" % hand_description
	
	display_text += "Pot: %s chips" % Utilities.format_number(pot_amount)
	
	winner_label.text = display_text
	show()
	
	# Create a new timer instead of connecting to an existing one
	var timer = get_tree().create_timer(3.0)  # Show for 3 seconds instead of 1
	timer.timeout.connect(hide)
	timer.timeout.connect(func(): winner_label.text = "")  # Clear text when hiding
