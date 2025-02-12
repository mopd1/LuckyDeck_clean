extends Panel

signal package_bought(index)

@onready var price_label = $PriceLabel
@onready var chips_label = $ChipsLabel
@onready var gems_label = $GemsLabel
@onready var buy_button = $BuyButton

var package_index: int

func setup(index: int, price: int, chips: int, gems: int):
	package_index = index
	price_label.text = "$" + str(price)
	chips_label.text = Utilities.format_number(chips) + " Chips"
	gems_label.text = Utilities.format_number(gems) + " Gems"
	buy_button.pressed.connect(on_buy_pressed)

func on_buy_pressed():
	emit_signal("package_bought", package_index)
