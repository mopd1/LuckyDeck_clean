extends Node

# Existing constants - NO CHANGES
const CURRENT_DATA_VERSION = 1
const SAVE_PATH = "user://player_data.save"
const FREE_CHIPS_AMOUNT = 100000
const FREE_CHIPS_COOLDOWN = 4 * 60 * 60 # 4 hours in seconds

# Existing signals
signal action_points_updated(new_points)
signal gem_balance_updated(new_balance)
signal avatar_updated(new_avatar_id)
signal balance_updated(new_balance)
signal package_purchase_completed(success, data)
# New signal for balance initialization
signal balance_initialized

# Existing variables
var avatar_data = {}
var player_data = {
	"version": CURRENT_DATA_VERSION,
	"name": "Player1",
	"total_balance": 0,  # Will be updated from server but maintains compatibility
	"table_balance": 0,
	"challenge_points": 0,
	"action_points": 0,
	"gems": 0,
	"last_free_chips_claim": 0,
	"owned_avatar_parts": [],
	"avatar_data": {
		"face": null,
		"clothing": null,
		"hair": null,
		"hat": null,
		"ear_accessories": null,
		"mouth_accessories": null
	}
}

# New variable for tracking initialization
var is_balance_initialized = false

func _ready():
	# Keep existing initialization
	load_player_data()
	
	# Add server sync
	if not APIManager.is_connected("user_data_received", _on_user_data_received):
		APIManager.connect("user_data_received", _on_user_data_received)

# New server sync handler
func _on_user_data_received(data):
	print("Debug: PlayerData received user data update:", data)
	if data.has("balance"):
		var old_balance = player_data["total_balance"]
		player_data["total_balance"] = data.balance
		
		if not is_balance_initialized:
			print("Debug: Initializing balance:", data.balance)
			is_balance_initialized = true
			emit_signal("balance_initialized")
		
		if old_balance != data.balance:
			emit_signal("balance_updated", player_data["total_balance"])
	elif data.has("chips"):  # Alternative field name
		var old_balance = player_data["total_balance"]
		player_data["total_balance"] = data.chips
		
		if not is_balance_initialized:
			print("Debug: Initializing balance (chips):", data.chips)
			is_balance_initialized = true
			emit_signal("balance_initialized")
		
		if old_balance != data.chips:
			emit_signal("balance_updated", player_data["total_balance"])

	if data.has("action_points"):
		var old_points = player_data["action_points"]
		player_data["action_points"] = data.action_points
		if old_points != data.action_points:
			emit_signal("action_points_updated", player_data["action_points"])

# Modified balance methods
func get_balance() -> int:
	if not is_balance_initialized:
		# If balance isn't initialized, try to get it from server
		APIManager.get_user_data()
	return player_data["total_balance"]

func update_balance_from_server():
	print("Debug: Requesting balance update from server")
	APIManager.get_user_data()

# Keep existing balance update but add server sync preparation
func update_total_balance(change: int):
	var old_balance = player_data["total_balance"]
	player_data["total_balance"] += change
	
	print("Debug: Balance update:")
	print("- Old balance:", old_balance)
	print("- Change:", change)
	print("- New balance:", player_data["total_balance"])
	
	# Safeguard against unintended balance changes
	if player_data["total_balance"] < 0:
		print("Debug: Prevented negative balance")
		player_data["total_balance"] = old_balance
		push_error("Attempted to set negative balance")
		return false
		
	emit_signal("balance_updated", player_data["total_balance"])
	return true

# New helper method
func has_sufficient_balance(required_amount: int) -> bool:
	return get_balance() >= required_amount

# ALL EXISTING METHODS REMAIN UNCHANGED BELOW
func update_challenge_points(points_to_add):
	# Update both for backwards compatibility
	player_data["challenge_points"] += points_to_add
	player_data["action_points"] += points_to_add
	emit_signal("challenge_points_updated", player_data["challenge_points"])
	emit_signal("action_points_updated", player_data["action_points"])

func update_action_points(points_to_add):
	player_data["action_points"] += points_to_add
	emit_signal("action_points_updated", player_data["action_points"])

func get_action_points() -> int:
	return player_data["action_points"]

func set_action_points(points: int):
	player_data["action_points"] = points
	emit_signal("action_points_updated", player_data["action_points"])

func update_book_points(points: int):
	# Update action points which seem to be used instead of book points
	update_action_points(points)

func set_table_balance(balance):
	player_data["table_balance"] = balance

func update_gems(change):
	player_data["gems"] += change
	emit_signal("gem_balance_updated", player_data["gems"])

func get_last_free_chips_claim():
	return player_data["last_free_chips_claim"]

func set_last_free_chips_claim(time):
	player_data["last_free_chips_claim"] = time

func can_claim_free_chips():
	var current_time = Time.get_unix_time_from_system()
	return current_time - get_last_free_chips_claim() >= FREE_CHIPS_COOLDOWN

func claim_free_chips():
	if can_claim_free_chips():
		update_total_balance(FREE_CHIPS_AMOUNT)
		set_last_free_chips_claim(Time.get_unix_time_from_system())
		return true
	return false

func get_time_until_next_free_chips():
	var current_time = Time.get_unix_time_from_system()
	var time_since_last_claim = current_time - get_last_free_chips_claim()
	return max(0, FREE_CHIPS_COOLDOWN - time_since_last_claim)

# Avatar methods remain unchanged
func set_avatar(avatar_id):
	player_data["avatar_id"] = avatar_id
	emit_signal("avatar_updated", avatar_id)

func get_avatar():
	return player_data.get("avatar_id", 1)

func set_avatar_data(new_avatar_data):
	player_data["avatar_data"] = new_avatar_data
	save_player_data()
	emit_signal("avatar_updated", new_avatar_data)

func get_avatar_data():
	return player_data["avatar_data"].duplicate()

func add_avatar_part(part_id):
	print("Adding avatar part:", part_id)
	if part_id not in player_data["owned_avatar_parts"]:
		player_data["owned_avatar_parts"].append(part_id)
		save_player_data()
		print("Avatar part added successfully")
	else:
		print("Avatar part already owned")

func get_owned_avatar_parts():
	return player_data["owned_avatar_parts"]

# Save/Load functionality remains unchanged
func load_player_data():
	var user_id = User.current_user_id
	if user_id:
		var data = User.get_current_user_data()
		if data:
			player_data = data
			emit_signal("avatar_updated", player_data["avatar_data"])
		else:
			print("No data found for current user. Using default data.")
	else:
		print("No user logged in. Using default player data.")

func save_player_data():
	if User.current_user_id:
		User.save_user_data(player_data)
	else:
		# Check if we have a valid token even if user_id isn't set
		if not APIManager.user_token.is_empty():
			print("Warning: Have valid token but no user_id, attempting to retrieve user data")
			APIManager.get_user_data()
		else:
			push_error("No user logged in. Cannot save player data.")
