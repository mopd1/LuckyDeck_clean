extends Control

signal pack_selected(pack_type)

@onready var close_button = $Panel/CloseButton
@onready var pack1_buy_button = $Panel/Pack1BuyButton
@onready var pack2_buy_button = $Panel/Pack2BuyButton
@onready var pack3_buy_button = $Panel/Pack3BuyButton

func _ready():
	# Connect the close button signal
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Connect the buy buttons signals
	pack1_buy_button.pressed.connect(func(): _on_pack_buy_button_pressed("envelope"))
	pack2_buy_button.pressed.connect(func(): _on_pack_buy_button_pressed("holdall"))
	pack3_buy_button.pressed.connect(func(): _on_pack_buy_button_pressed("briefcase"))

func _on_close_button_pressed():
	# Hide this popup and return to the PurchaseScene
	queue_free()

func _on_pack_buy_button_pressed(pack_type: String):
	# Emit the pack_selected signal with the pack type
	emit_signal("pack_selected", pack_type)
	
	# Close the popup after selecting a pack
	queue_free()
