class_name ChipManager
extends Node2D

signal chips_animated

# Dictionary to track chips by bet type
var active_chips: Dictionary = {}

func place_bet(bet_type: String, amount: int, position: Vector2) -> void:
	var chip = create_chip(amount, bet_type, position)
	
	if not active_chips.has(bet_type):
		active_chips[bet_type] = []
	active_chips[bet_type].append(chip)
	
	add_child(chip)
	# Animate from bottom of screen to position
	var start_pos = Vector2(position.x, get_viewport_rect().size.y + 50)
	chip.position = start_pos
	chip.animate_to_position(position)

func create_chip(amount: int, bet_type: String, position: Vector2) -> ChipVisual:
	return ChipVisual.new(amount, bet_type, position)

func collect_chips(bet_type: String, won: bool = false) -> void:
	if not active_chips.has(bet_type):
		return
	
	var chips = active_chips[bet_type]
	active_chips.erase(bet_type)
	
	for chip in chips:
		if won:
			await chip.animate_win()
			var target_pos = Vector2(get_viewport_rect().size.x / 2, -50)
			chip.animate_collect(target_pos)
		else:
			chip.animate_loss()
	
	emit_signal("chips_animated")

func collect_all_chips() -> void:
	for bet_type in active_chips.keys():
		collect_chips(bet_type)
	active_chips.clear()

func get_bet_amount(bet_type: String) -> int:
	if not active_chips.has(bet_type):
		return 0
	
	var total = 0
	for chip in active_chips[bet_type]:
		total += chip.amount
	return total

func has_active_bets() -> bool:
	return not active_chips.is_empty()
