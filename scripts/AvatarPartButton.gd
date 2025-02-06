extends Control

signal part_purchased(part)

var part_data
var can_purchase: bool = true
const PURCHASE_COOLDOWN: float = 0.5

func _ready():
	print("AvatarPartButton _ready called")
	var buy_button = get_node("BuyButton")
	if buy_button:
		buy_button.connect("pressed", Callable(self, "_on_buy_button_pressed"))
	else:
		print("Error: BuyButton not found")

func setup(part):
	print("Setting up AvatarPartButton for:", part["id"])
	part_data = part
	
	var name_label = get_node("NameLabel")
	var price_label = get_node("PriceLabel")
	var image = get_node("TextureRect")
	var buy_button = get_node("BuyButton")
	
	if name_label:
		name_label.text = part["id"]
	else:
		print("Error: NameLabel not found")
	
	if price_label:
		price_label.text = str(part["price"]) + " Gems"
	else:
		print("Error: PriceLabel not found")
	
	if image:
		print("Attempting to load image for", part["id"], ":", part["image"])
		var image_texture = load(part["image"])
		if image_texture:
			print("Successfully loaded image for", part["id"])
			image.texture = image_texture
		else:
			print("Failed to load image for", part["id"])
			var placeholder_path = "res://assets/avatars/placeholder.png"
			var placeholder = load(placeholder_path)
			if placeholder:
				image.texture = placeholder
	else:
		print("Error: TextureRect not found")
	
	# Check if player owns this part
	if buy_button:
		if part["id"] in PlayerData.get_owned_avatar_parts():
			set_owned_state()  # Use the new method
		else:
			buy_button.text = "Buy"
			buy_button.disabled = false
			can_purchase = true
	else:
		print("Error: BuyButton not found")

func on_buy_pressed():
	if APIManager.user_token.is_empty():
		print("Error: Cannot purchase avatar part - no user token")
		return
	if !User.current_user_id:
		print("Error: Cannot purchase avatar part - no user ID")
		return
		
	print("Attempting to purchase part: ", part_data["id"])
	emit_signal("part_purchased", part_data)

func _on_buy_button_pressed():
	if not can_purchase:
		return
		
	if part_data["id"] in PlayerData.get_owned_avatar_parts():
		print("Part already owned:", part_data["id"])
		return
		
	can_purchase = false
	var buy_button = get_node("BuyButton")
	if buy_button:
		buy_button.disabled = true
	
	print("Buy button pressed for: ", part_data["id"])
	emit_signal("part_purchased", part_data)

# Add this new method to update the button state
func set_owned_state():
	var buy_button = get_node("BuyButton")
	if buy_button:
		buy_button.text = "Already Owned"
		buy_button.disabled = true
		can_purchase = false
