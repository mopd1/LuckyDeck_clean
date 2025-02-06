# User.gd
extends Node

signal user_logged_in(user_id)
signal user_logged_out

var current_user_id = null
var user_data = {}  # Add this to store user data

func sign_up(username, password):
	# Implement sign-up logic
	pass

func login(username: String, password: String):
	# Store credentials temporarily
	user_data = {
		"username": username
	}
	# The actual user_id will be set when we receive the API response
	pass

# Add this new method to handle successful login
func handle_login_success(response_data: Dictionary):
	if response_data.has("user") and response_data.user.has("id"):
		current_user_id = response_data.user.id
		user_data = response_data.user
		emit_signal("user_logged_in", current_user_id)
		print("User logged in successfully with ID:", current_user_id)
	else:
		push_error("Login response missing user data")

func logout():
	current_user_id = null
	user_data.clear()
	emit_signal("user_logged_out")

func get_current_user_data():
	return user_data

func save_user_data(data):
	if current_user_id != null:
		user_data = data
		# Implement actual save logic here
		print("Saving user data for user:", current_user_id)
	else:
		push_error("No user logged in. Cannot save user data.")
