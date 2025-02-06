extends Node

signal texture_loaded(card_id: String, texture: Texture2D)

var _texture_cache := {}
var _loading_queue := []
var _is_loading := false
var _load_completed := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func get_card_texture(suit: String, value: String) -> Texture2D:
	if not _load_completed:
		push_error("Attempting to get card texture before preload completed")
		return null
		
	var card_id = _get_card_id(suit, value)
	return _texture_cache[card_id]

func preload_card_textures() -> bool:
	print("Starting card texture preload")
	var loaded_count := 0
	_load_completed = false
	
	for suit in ["hearts", "diamonds", "clubs", "spades"]:
		for value in ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]:
			var card_id = _get_card_id(suit, value)
			var texture_path = "res://assets/cards/%s_of_%s.png" % [value.to_lower(), suit.to_lower()]
			var texture = load(texture_path)
			if texture:
				_texture_cache[card_id] = texture
				loaded_count += 1
			else:
				push_error("Failed to load texture for %s of %s" % [value, suit])
	
	print("Card texture preload completed. Loaded %d textures" % loaded_count)
	_load_completed = true
	return loaded_count == 52 # Now the return type matches the function declaration

func _get_card_id(suit: String, value: String) -> String:
	return "%s_%s" % [value.to_lower(), suit.to_lower()]

# Add verification method
func verify_textures() -> bool:
	if not _load_completed:
		return false
		
	for suit in ["hearts", "diamonds", "clubs", "spades"]:
		for value in ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]:
			var card_id = _get_card_id(suit, value)
			if not _texture_cache.has(card_id) or not _texture_cache[card_id]:
				push_error("Missing texture for %s of %s" % [value, suit])
				return false
	return true
