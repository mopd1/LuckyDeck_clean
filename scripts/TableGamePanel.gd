extends Panel

signal play_pressed(game_type: String)

@onready var title_label = $TitleLabel
@onready var game_image = $GameImage
@onready var play_button = $PlayButton
@onready var coming_soon_label = $ComingSoonLabel

var game_type: String

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	if coming_soon_label:
		coming_soon_label.hide()

func set_game_type(type: String, enabled: bool = false):
	game_type = type
	title_label.text = type
	
	# Load appropriate game image
	var image_path = "res://assets/table_games/" + type.to_lower().replace(" ", "_") + ".png"
	var texture = load(image_path)
	if texture:
		game_image.texture = texture
	
	if enabled:
		play_button.show()
		coming_soon_label.hide()
	else:
		play_button.hide()
		coming_soon_label.show()
		coming_soon_label.text = "Coming Soon"

func _on_play_pressed():
	emit_signal("play_pressed", game_type)
