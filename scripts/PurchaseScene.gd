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
@onready var packages_grid = $PackagesScroll/PackagesGrid
@onready var packs_grid = $PacksGrid
@onready var message_label = $MessageLabel

var current_message_timer: SceneTreeTimer = null
var current_fade_tween: Tween = null
var is_message_showing: bool = false
var cooldown_timer_active = false
var is_fetching_data = false
var last_api_call_time = 0
var MIN_API_CALL_INTERVAL = 1.0  # Minimum time between API calls in seconds

func _ready():
	if APIManager.user_token.is_empty():
		SceneManager.goto_scene("res://scenes/LoginScene.tscn")
		return
		
	balance_display.hide()
	
	# Connect signals
	APIManager.user_data_received.connect(_on_user_data_received)
	APIManager.package_purchase_completed.connect(_on_package_purchase_completed)
	$TopBar/ReturnButton.pressed.connect(return_to_main_hub)
	claim_button.pressed.connect(claim_free_chips)
	
	# Initial setup
	setup_packages()
	setup_packs()
	update_claim_button()
	
	# Initialize message label
	message_label.text = ""
	message_label.add_theme_constant_override("outline_size", 1)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Fetch initial data with rate limiting
	fetch_user_data()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		_cleanup_signals()

func _cleanup_signals():
	if APIManager.user_data_received.is_connected(_on_user_data_received):
		APIManager.user_data_received.disconnect(_on_user_data_received)
	if APIManager.package_purchase_completed.is_connected(_on_package_purchase_completed):
		APIManager.package_purchase_completed.disconnect(_on_package_purchase_completed)

func fetch_user_data():
	var current_time = Time.get_unix_time_from_system()
	if is_fetching_data or (current_time - last_api_call_time) < MIN_API_CALL_INTERVAL:
		return
		
	is_fetching_data = true
	last_api_call_time = current_time
	APIManager.get_user_data()

func _process(delta):
	if cooldown_timer_active and PlayerData.can_claim_free_chips():
		cooldown_timer_active = false
		update_claim_button()
	elif cooldown_timer_active:
		update_cooldown_timer()

func _on_user_data_received(data):
	is_fetching_data = false
	
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Received data is not a dictionary")
		return
	
	if data.has("balance"):
		PlayerData.player_data["total_balance"] = data["balance"]
	elif data.has("chips"):
		PlayerData.player_data["total_balance"] = data["chips"]
	elif data.has("new_balance"):
		PlayerData.player_data["total_balance"] = data["new_balance"]
	
	if data.has("gems"):
		PlayerData.player_data["gems"] = data["gems"]
	elif data.has("new_gems"):
		PlayerData.player_data["gems"] = data["new_gems"]
	
	balance_display.show()
	update_balance_display()

func update_balance_display():
	chip_balance_label.text = "Chips: " + Utilities.format_number(PlayerData.player_data["total_balance"])
	gem_balance_label.text = "Flash: " + Utilities.format_number(PlayerData.player_data["gems"])

func update_gem_balance_display():
	gem_balance_label.text = "Flash: " + Utilities.format_number(PlayerData.player_data["gems"])

func setup_packages():
	for i in range(packages.size()):
		var package = packages[i]
		var package_panel = preload("res://scenes/PackagePanel.tscn").instantiate()
		packages_grid.add_child(package_panel)
		package_panel.setup(i, package["price"], package["chips"], package["gems"])
		package_panel.connect("package_bought", Callable(self, "buy_package"))

func setup_packs():
	for pack_type in Packs.PACK_TYPES:
		var pack_panel = preload("res://scenes/PackPanel.tscn").instantiate()
		packs_grid.add_child(pack_panel)
		pack_panel.setup(pack_type)
		pack_panel.connect("pack_bought", Callable(self, "buy_pack"))
		pack_panel.connect("info_button_pressed", Callable(self, "show_pack_info"))

func show_pack_info(pack_type: String):
	var pack_popup = preload("res://scenes/PackPanelPopup.tscn").instantiate()
	add_child(pack_popup)
	pack_popup.connect("pack_selected", Callable(self, "buy_pack"))

func buy_package(index: int) -> void:
	var package = packages[index]
	
	# Disable buy buttons while transaction is processing
	_set_buy_buttons_enabled(false)
	
	# Make purchase request through APIManager
	APIManager.purchase_package({
		"chips": package["chips"],
		"gems": package["gems"],
		"price": package["price"]
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

func _set_buy_buttons_enabled(enabled: bool) -> void:
	for child in packages_grid.get_children():
		if child.has_node("BuyButton"):
			child.get_node("BuyButton").disabled = not enabled

func buy_pack(pack_type: String):
	print("buy_pack called with: ", pack_type)  # Debug print
	var pack_data = Packs.PACK_TYPES[pack_type]
	
	if PlayerData.player_data["gems"] < pack_data.cost:
		_show_transaction_message("Not enough gems!", Color.RED)
		return
	
	# Determine rarity and select item
	var rarity = Packs.get_rarity_for_pack(pack_type)
	print("Selected rarity: ", rarity)  # Debug print
	var item = _select_random_item_of_rarity(rarity)
	
	if item == null:
		_show_transaction_message("Error selecting item!", Color.RED)
		return
	
	# Deduct gems
	PlayerData.update_gems(-pack_data.cost)
	update_gem_balance_display()
	
	# Add item to player's collection
	PlayerData.add_avatar_part(item.id)
	
	# Show reveal popup
	var reveal_popup = preload("res://scenes/PackRevealPopup.tscn").instantiate()
	add_child(reveal_popup)
	reveal_popup.reveal_item(pack_type, item)
	reveal_popup.connect("reveal_completed", Callable(self, "_on_reveal_completed"))

func _select_random_item_of_rarity(rarity: String) -> Dictionary:
	print("Selecting random item of rarity: ", rarity)  # Debug print
	var available_items = []
	
	# Load items from avatar_parts_store.json
	var file = FileAccess.open("res://data/avatar_parts_store.json", FileAccess.READ)
	if not file:
		push_error("Failed to open avatar_parts_store.json")
		return {}
		
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	if error == OK:
		var data = json.get_data()
		# Filter items by rarity
		for item in data.parts:
			if item.rarity == rarity:
				available_items.append(item)
	
	if available_items.size() > 0:
		var selected_item = available_items[randi() % available_items.size()]
		print("Selected item: ", selected_item)  # Debug print
		return selected_item
	
	print("No items found for rarity: ", rarity)  # Debug print
	return {}

func _on_reveal_completed():
	_show_transaction_message("Item added to your collection!", Color.GREEN)

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

func return_to_main_hub():
	_cleanup_signals()
	SceneManager.goto_scene("res://scenes/MainHub.tscn")
