extends Control

@onready var card_sprite = $CardSprite
@onready var card_back = $CardBack

var suit: String
var value: String
var is_face_up: bool = true

func _ready():
	update_visibility()

func set_card(new_suit: String, new_value: String):
	suit = new_suit
	value = new_value
	var texture_path = "res://assets/cards/%s_of_%s.png" % [value.to_lower(), suit.to_lower()]
	card_sprite.texture = load(texture_path)

func set_face_up(face_up: bool):
	is_face_up = face_up
	update_visibility()

func update_visibility():
	card_sprite.visible = is_face_up
	card_back.visible = not is_face_up

func get_card_info() -> Dictionary:
	return {"suit": suit, "value": value}
