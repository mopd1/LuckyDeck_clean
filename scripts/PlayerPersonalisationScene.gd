extends Control

const AVATAR_COUNT = 8

var avatar_customizer_scene = preload("res://scenes/AvatarCustomizer.tscn")
var avatar_customizer

@onready var avatar_grid = $ScrollContainer/AvatarGrid
@onready var return_button = $ReturnButton

func _ready():
	setup_avatar_customizer()
	return_button.pressed.connect(_on_return_button_pressed)
	_setup_avatars()

func setup_avatar_customizer():
	avatar_customizer = avatar_customizer_scene.instantiate()
	$AvatarCustomizerContainer.add_child(avatar_customizer)
	
	# Connect signals from AvatarCustomizer
	avatar_customizer.connect("customization_complete", Callable(self, "_on_customization_complete"))

	# Load existing avatar data if any
	var existing_avatar_data = PlayerData.get_avatar_data()
	avatar_customizer.load_avatar_data(existing_avatar_data)

func _on_customization_complete(avatar_data):
	print("PlayerPersonalisationScene received avatar data: ", avatar_data)
	PlayerData.set_avatar_data(avatar_data)
	SceneManager.goto_scene("res://scenes/MainHub.tscn")

func _setup_avatars():
	for i in range(AVATAR_COUNT):
		var avatar_button = avatar_grid.get_node("AvatarButton" + str(i + 1))
		avatar_button.texture_normal = load("res://assets/avatars/avatar_" + str(i + 1) + ".png")
		avatar_button.pressed.connect(_on_avatar_selected.bind(i + 1))

func _on_avatar_selected(avatar_id):
	PlayerData.set_avatar(avatar_id)
	PlayerData.save_player_data()
	SceneManager.goto_scene("res://scenes/MainHub.tscn")

func _on_return_button_pressed():
	if avatar_customizer:
		avatar_customizer.queue_free()
	SceneManager.goto_scene("res://scenes/MainHub.tscn")
