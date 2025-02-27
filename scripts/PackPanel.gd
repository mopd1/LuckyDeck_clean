extends Panel

signal pack_bought(pack_type)
signal info_button_pressed(pack_type)

@onready var name_label = $NameLabel
@onready var cost_label = $CostLabel
@onready var buy_button = $BuyButton
@onready var icon = $Icon
@onready var info_button = $InfoButton

var pack_type: String
var cost: int

func _ready():
	if not buy_button.pressed.is_connected(_on_buy_button_pressed):
		buy_button.pressed.connect(_on_buy_button_pressed)
	
	# Connect the info button signal
	if not info_button.pressed.is_connected(_on_info_button_pressed):
		info_button.pressed.connect(_on_info_button_pressed)

func setup(type: String):
	pack_type = type
	var pack_data = Packs.PACK_TYPES[type]
	
	name_label.text = pack_data.name
	cost_label.text = str(pack_data.cost) + " Flash"
	cost = pack_data.cost
	
	# Load appropriate icon based on pack type
	var icon_path = "res://assets/packs/" + type + ".png"
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)

func _on_buy_button_pressed():
	print("Buy button pressed") # Debug print
	if PlayerData.player_data["gems"] >= cost:
		print("Sufficient gems, emitting signal") # Debug print
		emit_signal("pack_bought", pack_type)
	else:
		var message_label = get_node_or_null("/root/PurchaseScene/MessageLabel")
		if message_label:
			message_label.text = "Not enough Flash!"
			message_label.modulate = Color.RED

func _on_info_button_pressed():
	emit_signal("info_button_pressed", pack_type)
