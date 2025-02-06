extends Node2D  # or Control

func _ready():
	var avatar_customizer = $AvatarCustomizer
	avatar_customizer.connect("customization_complete", Callable(self, "_on_customization_complete"))

func _on_customization_complete(avatar_data):
	print("Customization completed with data: ", avatar_data)
