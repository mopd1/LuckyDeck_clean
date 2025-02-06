extends Control

@onready var error_label = $ErrorLabel
@onready var retry_button = $RetryButton
@onready var return_button = $ReturnButton

func _ready():
	retry_button.pressed.connect(_on_retry_pressed)
	return_button.pressed.connect(_on_return_pressed)
	
	# Show last error if available
	if not ErrorManager.error_history.is_empty():
		var last_error = ErrorManager.error_history[0]
		error_label.text = "An error occurred in %s. Please try again." % last_error.node
	
	# In development, show more details
	if ConfigManager.is_development():
		error_label.text += "\n\nDebug Info:\n" + JSON.stringify(ErrorManager.error_history[0], "\t")

func _on_retry_pressed():
	# Attempt to reload the current scene
	get_tree().reload_current_scene()

func _on_return_pressed():
	# Return to main menu
	SceneManager.goto_scene("res://scenes/MainHub.tscn")
