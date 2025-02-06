extends Control

signal spin_completed(reel_index)

@onready var symbol_1 = $Symbol1
@onready var symbol_2 = $Symbol2
@onready var symbol_3 = $Symbol3

var reel_index: int = 0
var is_spinning: bool = false
var symbol_nodes = []
var is_ai_reel = false

func _ready():
	print("DEBUG: ReelComponent initialized, is_ai_reel:", is_ai_reel)
	custom_minimum_size = Vector2(114, 280)  # Match the mockup dimensions
	symbol_nodes = [symbol_1, symbol_2, symbol_3]

func get_symbol_nodes():
	return symbol_nodes

func set_symbols(symbols: Array):
	for i in range(symbol_nodes.size()):
		if i < symbols.size():
			var symbol = symbols[i]
			var texture_path = "res://assets/cards/%s_of_%s.png" % [symbol["symbol"].to_lower(), symbol["suit"]]
			var texture = load(texture_path)
			if texture:
				symbol_nodes[i].texture = texture
				symbol_nodes[i].visible = true
				# Ensure symbol is fully visible
				symbol_nodes[i].modulate = Color(1, 1, 1, 1)
			else:
				push_error("Failed to load texture: " + texture_path)

func set_ai_mode(enabled: bool):
	is_ai_reel = enabled
	print("DEBUG: Setting AI mode to:", enabled)
	# Add a visual distinction
	modulate = Color(0.9, 0.9, 1.0) if enabled else Color(1, 1, 1)

func highlight_symbol(row_index: int):
	print("DEBUG: ReelComponent", reel_index, "highlighting row", row_index, "is_ai_reel:", is_ai_reel)
	if row_index >= 0 and row_index < symbol_nodes.size():
		var symbol = symbol_nodes[row_index]
		if symbol:
			# Force symbol to be fully visible before highlighting
			symbol.visible = true
			symbol.modulate = Color(1.5, 0.3, 0.3) if is_ai_reel else Color(1.5, 1.5, 0.3)
			print("DEBUG: Symbol modulate set to:", symbol.modulate)

func clear_highlights():
	for symbol in symbol_nodes:
		if symbol:
			symbol.modulate = Color(1, 1, 1)  # Reset to default color

func start_spin(delay: float = 0.0):
	is_spinning = true
	# For now, just immediately complete the spin
	await get_tree().create_timer(delay).timeout
	emit_signal("spin_completed", reel_index)
	is_spinning = false

func get_visible_symbols() -> Array:
	var symbols = []
	for i in range(3):
		var symbol_node = get_node("Symbol" + str(i + 1))
		if symbol_node and symbol_node.texture:
			symbols.append(symbol_node.texture)
	return symbols
