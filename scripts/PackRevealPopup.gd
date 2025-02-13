extends Control

signal reveal_completed
signal item_traded(gems_amount: int)

@onready var pack_sprite = $CenterContainer/PopupPanel/PackSprite
@onready var animation_player = $AnimationPlayer
@onready var item_card = $CenterContainer/PopupPanel/ItemCard

var revealed_item = null

func _ready():
	item_card.item_added.connect(_on_item_added)
	item_card.item_traded.connect(_on_item_traded)


func reveal_item(pack_type: String, item_data: Dictionary):
	revealed_item = item_data
	
	# Setup item card
	item_card.setup(item_data)
	
	# Load pack sprite
	var pack_texture_path = "res://assets/packs/" + pack_type + ".png"
	if ResourceLoader.exists(pack_texture_path):
		pack_sprite.texture = load(pack_texture_path)
	
	# Start reveal animation
	play_reveal_animation()

func play_reveal_animation():
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Pack entrance
	tween.tween_property(pack_sprite, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(pack_sprite, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Pack opening effect
	tween.tween_property(pack_sprite, "rotation_degrees", 5, 0.1)
	tween.tween_property(pack_sprite, "rotation_degrees", -5, 0.1)
	tween.tween_property(pack_sprite, "rotation_degrees", 0, 0.1)
	
	# Pack fade out and card reveal
	tween.tween_property(pack_sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(item_card, "modulate:a", 1.0, 0.5)

func _on_item_added():
	emit_signal("reveal_completed")
	queue_free()

func _on_item_traded(gems_amount: int):
	emit_signal("item_traded", gems_amount)
	emit_signal("reveal_completed")
	queue_free()
