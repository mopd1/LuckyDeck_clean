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
	print("Debug: Handling login success with data:", response_data)
	
	if response_data.has("user"):
		current_user_id = response_data.user.id
		user_data = response_data.user
		
		# Initialize PlayerData with user data if available
		# Check for both "balance" and "chips" fields
		if response_data.user.has("balance"):
			print("Debug: Setting initial balance:", response_data.user.balance)
			PlayerData.player_data["total_balance"] = response_data.user.balance
		elif response_data.user.has("chips"):
			print("Debug: Setting initial chips balance:", response_data.user.chips)
			PlayerData.player_data["total_balance"] = response_data.user.chips
			
		if response_data.user.has("gems"):
			print("Debug: Setting initial gems balance:", response_data.user.gems)
			PlayerData.player_data["gems"] = response_data.user.gems
			
		emit_signal("user_logged_in", current_user_id)
		print("Debug: User logged in successfully with ID:", current_user_id)
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
