class_name ChipVisual
extends Node2D

signal animation_completed

const CHIP_VALUES = {
	500: preload("res://assets/table/500chip.png"),
	1000: preload("res://assets/table/1000chip.png"),
	10000: preload("res://assets/table/10000chip.png"),
	100000: preload("res://assets/table/100000chip.png"),
	1000000: preload("res://assets/table/1000000chip.png"),
	10000000: preload("res://assets/table/10000000chip.png"),
	100000000: preload("res://assets/table/100000000chip.png")
}

var amount: int
var bet_type: String
var sprite: Sprite2D
var value_label: Label
var original_position: Vector2

func _init(p_amount: int, p_bet_type: String, p_position: Vector2):
	amount = p_amount
	bet_type = p_bet_type
	position = p_position
	original_position = p_position
	
	setup_visuals()

func setup_visuals():
	# Create main chip sprite
	sprite = Sprite2D.new()
	sprite.texture = get_chip_texture(amount)
	add_child(sprite)
	
	# Create value label
	value_label = Label.new()
	value_label.text = str(amount)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color.BLACK)
	value_label.add_theme_font_size_override("font_size", 14)
	add_child(value_label)
	
	# Center the label on the chip
	value_label.position = Vector2(-value_label.size.x / 2, -value_label.size.y / 2)

func get_chip_texture(value: int) -> Texture2D:
	# Find the highest denomination chip that fits
	var best_value = 1
	for chip_value in CHIP_VALUES.keys():
		if chip_value <= value and chip_value > best_value:
			best_value = chip_value
	return CHIP_VALUES[best_value]

func animate_to_position(target_pos: Vector2, duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	emit_signal("animation_completed")

func animate_collect(target_pos: Vector2) -> void:
	var tween = create_tween()
	# Move to target position while fading out
	tween.tween_property(self, "position", target_pos, 0.5)\
		.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()

func animate_win() -> void:
	var tween = create_tween()
	# Bounce effect
	tween.tween_property(self, "position:y", position.y - 20, 0.15)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y, 0.15)\
		.set_ease(Tween.EASE_IN)
	# Scale effect
	tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)\
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_ease(Tween.EASE_IN)
	await tween.finished
	emit_signal("animation_completed")

func animate_loss() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()

func update_amount(new_amount: int) -> void:
	amount = new_amount
	sprite.texture = get_chip_texture(amount)
	value_label.text = str(amount)
