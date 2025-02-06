extends Control

var packages = [
	{"price": 2, "chips": 200000, "gems": 0},
	{"price": 5, "chips": 500000, "gems": 30},
	{"price": 10, "chips": 1200000, "gems": 60},
	{"price": 20, "chips": 2500000, "gems": 150},
	{"price": 50, "chips": 7000000, "gems": 1000},
	{"price": 100, "chips": 15000000, "gems": 2000}
]

@onready var balance_display = $TopBar/BalanceDisplay
@onready var chip_balance_label = $TopBar/BalanceDisplay/ChipBalance
@onready var gem_balance_label = $TopBar/BalanceDisplay/GemBalance
@onready var claim_button = $FreeChipsSection/ClaimButton
@onready var cooldown_timer = $FreeChipsSection/CooldownTimer
@onready var packages_grid = $PackagesGrid
@onready var avatar_parts_grid = $AvatarPartsSection/AvatarPartsGrid
@onready var refresh_time_label = $AvatarPartsSection/RefreshTimeLabel
@onready var message_label = $MessageLabel

var current_message_timer: SceneTreeTimer = null
var current_fade_tween: Tween = null
var is_message_showing: bool = false
var cooldown_timer_active = false
var avatar_parts_data = []
var displayed_parts = []
var refresh_time = 0

func _ready():
	print("Project resource path: ", ProjectSettings.get_setting("application/config/name"))
	if APIManager.user_token.is_empty():
		SceneManager.goto_scene("res://scenes/LoginScene.tscn")
		return
		
	# Hide balance display until we have data
	$TopBar/BalanceDisplay.hide()
	
	# Fetch fresh data
	APIManager.get_user_data()
	APIManager.connect("user_data_received", Callable(self, "_on_user_data_received"))
	print("Project resource path: ", ProjectSettings.get_setting("application/config/name"))
	update_balance_display()
	setup_packages()
	update_claim_button()
	$TopBar/ReturnButton.pressed.connect(return_to_main_hub)
	claim_button.pressed.connect(claim_free_chips)
	load_avatar_parts_data()
	refresh_avatar_parts()
	update_refresh_time_label()
	
	# Initialize message label
	message_label.text = ""
	message_label.add_theme_constant_override("outline_size", 1)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Connect to the API manager signals
	APIManager.connect("package_purchase_completed", Callable(self, "_on_package_purchase_completed"))

func _process(delta):
	if cooldown_timer_active and PlayerData.can_claim_free_chips():
		cooldown_timer_active = false
		update_claim_button()
	elif cooldown_timer_active:
		update_cooldown_timer()
	update_refresh_time_label()

func _on_user_data_received(data):
	PlayerData.player_data["total_balance"] = data.chips
	PlayerData.player_data["gems"] = data.gems
	
	$TopBar/BalanceDisplay.show()
	update_balance_display()

func update_balance_display():
	chip_balance_label.text = "Chips: " + Utilities.format_number(PlayerData.player_data["total_balance"])
	gem_balance_label.text = "Gems: " + Utilities.format_number(PlayerData.player_data["gems"])

func update_gem_balance_display():
	gem_balance_label.text = "Gems: " + Utilities.format_number(PlayerData.player_data["gems"])

func setup_packages():
	for i in range(packages.size()):
		var package = packages[i]
		var package_panel = preload("res://scenes/PackagePanel.tscn").instantiate()
		packages_grid.add_child(package_panel)
		package_panel.setup(i, package["price"], package["chips"], package["gems"])
		package_panel.connect("package_bought", Callable(self, "buy_package"))

func buy_package(index: int) -> void:
	var package = packages[index]
	
	# Debug: Print package details before purchase
	print("Attempting to purchase package:", package)
	
	# Disable buy buttons while transaction is processing
	_set_buy_buttons_enabled(false)
	
	# Make purchase request through APIManager
	APIManager.purchase_package({
		"chips": package["chips"],
		"gems": package["gems"],
		"price": package["price"]  # Make sure to include the price
	})

func _on_package_purchase_completed(success: bool, data: Dictionary) -> void:
	# Re-enable buy buttons
	_set_buy_buttons_enabled(true)
	
	if success:
		# Update both chips and gems if provided in the response
		if data.has("new_balance"):
			PlayerData.player_data["total_balance"] = data["new_balance"]
			update_balance_display()
			
		if data.has("new_gems"):
			PlayerData.player_data["gems"] = data["new_gems"]
			update_gem_balance_display()
			
		# Show success message
		_show_transaction_message("Purchase successful!", Color.GREEN)
	else:
		# Show error message to user
		var error_msg = data.get("message", "Unknown error occurred")
		_show_transaction_message("Purchase failed: " + error_msg, Color.RED)
		push_error("Purchase failed: " + error_msg)

# Helper function to manage buy button states
func _set_buy_buttons_enabled(enabled: bool) -> void:
	for child in packages_grid.get_children():
		if child.has_node("BuyButton"):
			child.get_node("BuyButton").disabled = not enabled

# Helper function to show transaction messages
func _show_transaction_message(message: String, color: Color = Color.WHITE) -> void:
	if not message_label:
		return
		
	# Cancel any existing fade animation
	if current_fade_tween:
		current_fade_tween.kill()
		current_fade_tween = null
	
	# Cancel any existing timer
	if is_message_showing and current_message_timer:
		if current_message_timer.is_connected("timeout", _fade_out_message):
			current_message_timer.timeout.disconnect(_fade_out_message)
	
	# Show new message
	message_label.text = message
	message_label.modulate = color
	message_label.modulate.a = 1.0  # Full opacity
	is_message_showing = true
	
	# Create new timer
	current_message_timer = get_tree().create_timer(2.0)  # Show for 2 seconds
	current_message_timer.timeout.connect(_fade_out_message, CONNECT_ONE_SHOT)

func _fade_out_message() -> void:
	if not message_label:
		return
	
	is_message_showing = false
	
	# Create a new fade tween
	if current_fade_tween:
		current_fade_tween.kill()
	
	current_fade_tween = create_tween()
	current_fade_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)  # Fade out over 0.5 seconds
	current_fade_tween.tween_callback(func(): 
		message_label.text = ""
		current_fade_tween = null
	)

func update_claim_button():
	if PlayerData.can_claim_free_chips():
		claim_button.disabled = false
		cooldown_timer.text = "Free chips available!"
		cooldown_timer_active = false
	else:
		claim_button.disabled = true
		cooldown_timer_active = true

func update_cooldown_timer():
	var time_remaining = PlayerData.get_time_until_next_free_chips()
	var hours = int(time_remaining) / 3600
	var minutes = (int(time_remaining) % 3600) / 60
	var seconds = int(time_remaining) % 60
	cooldown_timer.text = "Next claim in: %02d:%02d:%02d" % [hours, minutes, seconds]

func claim_free_chips():
	if PlayerData.claim_free_chips():
		update_balance_display()
		update_claim_button()
		cooldown_timer_active = true
		update_cooldown_timer()

func load_avatar_parts_data():
	if not FileAccess.file_exists("res://data/avatar_parts_store.json"):
		print("Error: avatar_parts_store.json does not exist")
		return

	var file = FileAccess.open("res://data/avatar_parts_store.json", FileAccess.READ)
	if not file:
		print("Error: Failed to open avatar_parts_store.json")
		return

	var content = file.get_as_text()
	file.close()
	
	print("JSON content: ", content)
	
	var json = JSON.new()
	var error = json.parse(content)
	if error == OK:
		var data = json.get_data()
		if typeof(data) == TYPE_DICTIONARY and data.has("parts"):
			avatar_parts_data = data["parts"]
			print("Parsed avatar parts: ", avatar_parts_data)
		else:
			print("Error: Invalid JSON structure")
	else:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())

func refresh_avatar_parts():
	displayed_parts.clear()
	var available_parts = avatar_parts_data.duplicate()
	for i in range(3):
		if available_parts.size() > 0:
			var index = randi() % available_parts.size()
			displayed_parts.append(available_parts[index])
			available_parts.remove_at(index)
	
	refresh_time = Time.get_unix_time_from_system() + 86400 # 24 hours
	update_avatar_parts_display()

func update_avatar_parts_display():
	print("Updating avatar parts display")
	for child in avatar_parts_grid.get_children():
		child.queue_free()
	
	print("Displaying parts:", displayed_parts)
	
	for part in displayed_parts:
		var part_button = preload("res://scenes/AvatarPartButton.tscn").instantiate()
		if part_button:
			avatar_parts_grid.add_child(part_button)
			part_button.setup(part)
			# Verify signal connection
			if not part_button.is_connected("part_purchased", _on_part_purchased):
				part_button.connect("part_purchased", _on_part_purchased)
				print("Connected part_purchased signal for:", part["id"])

func _on_part_purchased(part):
	print("Part purchase signal received for:", part["id"])
	print("Current gems balance:", PlayerData.player_data["gems"])
	print("Part price:", part["price"])
	
	# First check if the part is already owned
	if part["id"] in PlayerData.get_owned_avatar_parts():
		print("Part already owned, purchase cancelled")
		_show_transaction_message("You already own this item!", Color.YELLOW)
		return
	
	if PlayerData.player_data["gems"] >= part["price"]:
		print("Processing purchase...")
		PlayerData.update_gems(-part["price"])
		PlayerData.add_avatar_part(part["id"])
		update_gem_balance_display()
		
		# Immediately update the button state
		for child in avatar_parts_grid.get_children():
			if child.part_data["id"] == part["id"]:
				child.set_owned_state()  # Use the new method
				break
		
		_show_transaction_message("Avatar part purchased successfully!", Color.GREEN)
	else:
		print("Insufficient gems for purchase")
		_show_transaction_message("Not enough gems to purchase this item", Color.RED)
		# Re-enable the button if purchase failed
		for child in avatar_parts_grid.get_children():
			if child.part_data["id"] == part["id"]:
				var buy_button = child.get_node("BuyButton")
				if buy_button:
					buy_button.disabled = false
					buy_button.text = "Buy"
					child.can_purchase = true
				break

func update_refresh_time_label():
	var current_time = Time.get_unix_time_from_system()
	var time_left = refresh_time - current_time
	if time_left <= 0:
		refresh_avatar_parts()
	else:
		var hours = int(time_left) / 3600
		var minutes = int(time_left) % 3600 / 60
		var seconds = int(time_left) % 60
		refresh_time_label.text = "Refreshes in: %02d:%02d:%02d" % [hours, minutes, seconds]

func return_to_main_hub():
	SceneManager.goto_scene("res://scenes/MainHub.tscn")
