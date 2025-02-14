extends Panel

signal item_added
signal item_traded(gems_amount: int)

const RARITY_TO_STARS = {
	"common": 1,
	"uncommon": 2,
	"rare": 3
}

@onready var item_name = $ItemName
@onready var item_image = $ItemImage
@onready var rarity_stars = $RarityStars
@onready var trade_value = $TradeValue
@onready var description = $Description
@onready var add_button = $ButtonContainer/AddButton
@onready var trade_button = $ButtonContainer/TradeButton

var item_data: Dictionary

func _ready():
	add_button.pressed.connect(_on_add_pressed)
	trade_button.pressed.connect(_on_trade_pressed)

func setup(data: Dictionary):
	item_data = data
	item_name.text = data.id.capitalize()
	item_image.texture = load(data.image)
	
	# Handle both old and new rarity formats
	var star_count = data.get("rarity_stars", RARITY_TO_STARS[data.rarity])
	_setup_rarity_stars(star_count)
	
	var trade_val = data.get("trade_value", 0)
	trade_value.text = str(trade_val)
	
	var desc = data.get("flavour_text", "")  # Changed from flavor_text to flavour_text
	description.text = desc

func _setup_rarity_stars(rarity: int):
	# Clear existing stars
	for child in rarity_stars.get_children():
		child.queue_free()
	
	# Add new stars based on rarity
	for i in range(rarity):
		var star = TextureRect.new()
		star.texture = load("res://assets/ui/rarity_star.png")
		star.custom_minimum_size = Vector2(10, 10)  # Adjust size as needed
		star.expand_mode = 1  # This corresponds to keep aspect centered
		rarity_stars.add_child(star)

func _on_add_pressed():
	emit_signal("item_added")

func _on_trade_pressed():
	emit_signal("item_traded", item_data.trade_value)
