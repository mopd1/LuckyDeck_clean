extends Control

signal meter_filled
signal multiplier_changed(value)

@onready var joker_slots = [$Slot1, $Slot2, $Slot3]
@onready var multiplier_label = $MultiplierLabel

var filled_slots: int = 0
var current_multiplier: int = 1

func _ready():
	custom_minimum_size = Vector2(60, 300)  # Match mockup dimensions
	_update_display()

func add_joker() -> bool:
	if filled_slots >= 3:
		return false
		
	filled_slots += 1
	_update_display()
	_update_multiplier()
	
	if filled_slots == 3:
		emit_signal("meter_filled")
	
	return true

func clear_meter():
	filled_slots = 0
	current_multiplier = 1
	_update_display()
	emit_signal("multiplier_changed", current_multiplier)

func _update_display():
	for i in range(joker_slots.size()):
		joker_slots[i].modulate = Color.WHITE if i < filled_slots else Color(0.5, 0.5, 0.5, 0.5)

func _update_multiplier():
	match filled_slots:
		1: current_multiplier = 2
		2: current_multiplier = 3
		3: current_multiplier = 5
		_: current_multiplier = 1
	
	multiplier_label.text = str(current_multiplier) + "x"
	emit_signal("multiplier_changed", current_multiplier)
