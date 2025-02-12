extends Control

signal reveal_completed

@onready var pack_sprite = $CenterContainer/PopupPanel/PackSprite
@onready var item_sprite = $CenterContainer/PopupPanel/ItemSprite
@onready var item_name_label = $CenterContainer/PopupPanel/ItemNameLabel
@onready var rarity_label = $CenterContainer/PopupPanel/RarityLabel
@onready var close_button = $CenterContainer/PopupPanel/CloseButton
@onready var animation_player = $AnimationPlayer

var revealed_item = null

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	close_button.hide()  # Hide initially until animation is done
	
	# Set initial states
	item_sprite.modulate.a = 0
	item_name_label.modulate.a = 0
	rarity_label.modulate.a = 0

func reveal_item(pack_type: String, item_data: Dictionary):
	revealed_item = item_data
	
	# Set up item data
	item_sprite.texture = load(item_data.image)
	item_name_label.text = item_data.id.capitalize()
	rarity_label.text = item_data.rarity.capitalize()
	
	# Set rarity color
	match item_data.rarity:
		"common":
			rarity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		"uncommon":
			rarity_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		"rare":
			rarity_label.add_theme_color_override("font_color", Color(0.2, 0.2, 1.0))
	
	# Load pack sprite
	var pack_texture_path = "res://assets/packs/" + pack_type + ".png"
	if ResourceLoader.exists(pack_texture_path):
		pack_sprite.texture = load(pack_texture_path)
	
	# Start reveal animation
	play_reveal_animation()

func play_reveal_animation():
	# Create reveal animation sequence
	var tween = create_tween()
	tween.set_parallel(false)  # Make animations sequential
	
	# Pack entrance
	tween.tween_property(pack_sprite, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(pack_sprite, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Pack opening effect
	tween.tween_property(pack_sprite, "rotation_degrees", 5, 0.1)
	tween.tween_property(pack_sprite, "rotation_degrees", -5, 0.1)
	tween.tween_property(pack_sprite, "rotation_degrees", 0, 0.1)
	
	# Pack fade out and item reveal
	tween.tween_property(pack_sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(item_sprite, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(item_name_label, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(rarity_label, "modulate:a", 1.0, 0.5)
	
	# Show close button after animation
	tween.tween_callback(func(): close_button.show())

func _on_close_pressed():
	# Optional exit animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		emit_signal("reveal_completed")
		queue_free()
	)
