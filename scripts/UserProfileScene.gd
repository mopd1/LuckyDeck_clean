# UserProfileScene.gd
extends Control

@onready var email_field = $VBoxContainer/EmailSection/EmailField
@onready var current_password_field = $VBoxContainer/PasswordSection/CurrentPasswordField
@onready var new_password_field = $VBoxContainer/PasswordSection/NewPasswordField
@onready var confirm_password_field = $VBoxContainer/PasswordSection/ConfirmPasswordField
@onready var crm_opt_in_check = $VBoxContainer/CRMSection/CRMOptInCheck
@onready var save_button = $VBoxContainer/SaveButton
@onready var back_button = $VBoxContainer/BackButton
@onready var message_label = $VBoxContainer/MessageLabel

func _ready():
	back_button.pressed.connect(_on_back_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	APIManager.connect("user_data_received", _on_user_data_received)
	APIManager.connect("profile_update_completed", _on_profile_update_completed)
	load_user_data()

func load_user_data():
	APIManager.get_user_data()

func _on_user_data_received(user_data):
	print("Received user data: ", user_data)  # Debug print
	if user_data is Dictionary:
		email_field.text = user_data.get("email", "")
		crm_opt_in_check.button_pressed = user_data.get("crm_opt_in", false)
	else:
		print("Error: Received user data is not a dictionary")
		message_label.text = "Error loading user data"

func _on_save_button_pressed():
	var new_email = email_field.text
	var current_password = current_password_field.text
	var new_password = new_password_field.text
	var confirm_password = confirm_password_field.text
	var crm_opt_in = crm_opt_in_check.button_pressed

	if new_password != confirm_password:
		message_label.text = "New passwords do not match."
		return

	var update_data = {
		"email": new_email,
		"current_password": current_password,
		"new_password": new_password if new_password else null,
		"crm_opt_in": crm_opt_in
	}

	APIManager.update_user_profile(update_data)
	message_label.text = "Updating profile..."

func _on_profile_update_completed(success: bool, message: String):
	if success:
		message_label.text = "Profile updated successfully. Please check your email for verification."
	else:
		message_label.text = "Failed to update profile: " + message

func _on_back_button_pressed():
	SceneManager.goto_scene("res://scenes/MainHub.tscn")
