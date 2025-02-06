extends Control

signal reel_spin_completed(reel_index)

@onready var reels_container = $ReelsContainer

const REEL_COUNT = 5
const SYMBOL_COUNT = 3

var reel_components = []

func _ready():
	_setup_reels()

func _setup_reels():
	print("DEBUG: Setting up AI reels")
	# Clear any existing reels
	for child in reels_container.get_children():
		child.queue_free()
	reel_components.clear()
	
	# Create new reels
	for i in range(REEL_COUNT):
		var reel = preload("res://scenes/ReelComponent.tscn").instantiate()
		reel.reel_index = i
		reel.set_ai_mode(true)  # Mark as AI reel
		reels_container.add_child(reel)
		reel_components.append(reel)
		print("DEBUG: Created AI reel component", i, "is_ai_reel:", reel.is_ai_reel)

func highlight_winning_hand(positions: Array):
	print("DEBUG: AIReels highlighting positions:", positions)
	clear_highlights()
	
	for position in positions:
		if position.has("reel") and position.has("row"):
			var reel_index = position["reel"]
			var row_index = position["row"]
			if reel_index < reel_components.size():
				var reel = reel_components[reel_index]
				if reel:
					# Verify reel state before highlighting
					print("DEBUG: AI Reel", reel_index, "exists and is_ai_reel =", reel.is_ai_reel)
					# Force modulate to be visible
					reel.modulate = Color(1, 1, 1, 1)
					reel.highlight_symbol(row_index)

func clear_highlights():
	print("DEBUG: Clearing AI reel highlights")
	for reel in reel_components:
		if reel:
			reel.clear_highlights()

func update_symbols(symbols: Array):
	print("DEBUG: Updating AI reel symbols with count:", symbols.size())
	for i in range(reel_components.size()):
		if reel_components[i]:
			reel_components[i].set_symbols(symbols[i])
			# Verify symbol nodes after setting
			var symbol_nodes = reel_components[i].get_symbol_nodes()
			print("DEBUG: AI Reel", i, "has", symbol_nodes.size(), "symbol nodes")
			for j in range(symbol_nodes.size()):
				print("DEBUG: - Symbol", j, "visible:", symbol_nodes[j].visible)
				print("DEBUG: - Symbol", j, "modulate:", symbol_nodes[j].modulate)
