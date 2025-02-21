extends Control

@onready var name_label = $Panel/NameLabel
@onready var chip_count_label = $Panel/ChipCountLabel
@onready var card1 = $Cards/Card1
@onready var card2 = $Cards/Card2
@onready var avatar = $Panel/AvatarDisplay
@onready var avatar_viewport = $Panel/AvatarViewport
@onready var timer_bar = $Panel/TimerBar
@onready var panel = $Panel
@onready var chip_stack_display = $Panel/ChipStackDisplay

# Define offsets from the panel's center
const PLAYER_BET_OFFSETS = {
	0: Vector2(200, -240),    # Bottom player (You) - above panel
	1: Vector2(180, -120),   # Bottom left
	2: Vector2(180, -480),     # Top left
	3: Vector2(-720, -480),     # Top right
	4: Vector2(-720, -480)    # Bottom right
}

var avatar_layers = ["face", "sunglasses", "eyebrows", "eyes", "nose", "mouth", "hair", "hat", "ear_accessories", "mouth_accessories", "clothing"]
var player_index: int

func _ready():
	PlayerData.connect("avatar_updated", _on_avatar_updated)
	_update_avatar()
	
	# Initialize timer bar
	if timer_bar:
		timer_bar.min_value = 0
		timer_bar.max_value = 1
		timer_bar.value = 1
		timer_bar.show_percentage = false
		timer_bar.visible = false  # Hide initially
	
	# Initialize chip_stack_display
	if chip_stack_display:
		chip_stack_display.visible = false
	
	# Style the progress bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	timer_bar.add_theme_stylebox_override("background", style_box)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1, 1, 0)
	timer_bar.add_theme_stylebox_override("fill", fill_style)
	
	timer_bar.custom_minimum_size = Vector2(0, 20)
	timer_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	#if panel:
		#timer_bar.custom_minimum_size.x = panel.size.x
		#timer_bar.position.y = 0

func update_timer_display(progress: float, is_warning: bool):
	if !timer_bar:
		return
		
	# Don't make visible here - visibility is controlled by update_display
	timer_bar.value = progress
	
	# Get the fill style
	var fill_style = timer_bar.get_theme_stylebox("fill", "ProgressBar") as StyleBoxFlat
	if fill_style:
		if is_warning:
			var flash_time = Time.get_ticks_msec() / 500.0
			fill_style.bg_color = Color(1, 0, 0) if int(flash_time) % 2 == 0 else Color(1, 1, 0)
		else:
			fill_style.bg_color = Color(1, 1, 0)

func hide_timer():
	if timer_bar:
		timer_bar.visible = false
		timer_bar.value = 1 

func update_display(player_data, is_current_player: bool, show_cards: bool):
	name_label.text = player_data.name
	chip_count_label.text = Utilities.format_number(player_data.chips)
	
	# Update bet display if player has an active bet
	if player_data.has("bet") and player_data.bet > 0:
		display_bet(player_data.bet)
	else:
		clear_bet()
	
	# Only show timer if this is the current player
	if timer_bar:
		timer_bar.visible = is_current_player
	
	# Update avatar from player_data instead of PlayerData singleton
	if player_data.has("avatar_data") and not player_data.get("is_bot", false):
		var avatar_scene = avatar_viewport.get_node("AvatarScene")
		if avatar_scene:
			_update_avatar_scene(avatar_scene, player_data.avatar_data)
			avatar.texture = avatar_viewport.get_texture()
	else:
		# Hide avatar for bots or if no avatar data
		avatar.visible = false
	
	if player_data.folded:
		card1.texture = null
		card2.texture = null
	elif is_current_player or show_cards:
		if player_data.cards.size() >= 2:
			card1.texture = load("res://assets/cards/" + player_data.cards[0].rank + "_of_" + player_data.cards[0].suit + ".png")
			card2.texture = load("res://assets/cards/" + player_data.cards[1].rank + "_of_" + player_data.cards[1].suit + ".png")
	else:
		card1.texture = load("res://assets/cards/card_back.png")
		card2.texture = load("res://assets/cards/card_back.png")

	# Add visual indicator for bot players
	if player_data.get("is_bot", false):
		name_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))  # Light blue for bots
	else:
		name_label.remove_theme_color_override("font_color")

func display_bet(amount: int):
	if not chip_stack_display:
		return
		
	if amount <= 0:
		clear_bet()
		return
	
	# Make chip stack display visible
	chip_stack_display.visible = true
	
	# Start animation from panel center
	var start_pos = panel.size / 2
	
	# Set up new chips with animation without changing position
	chip_stack_display.set_amount(amount, true, start_pos)

func collect_bet_to_pot(pot_position: Vector2):
	if not chip_stack_display or not chip_stack_display.visible:
		return
		
	# Convert pot's global position to local coordinates
	var local_pot_pos = pot_position - panel.global_position
	
	# Only start new animation if not already animating
	if not chip_stack_display.is_animating:
		chip_stack_display.move_to_pot(local_pot_pos)

func clear_bet():
	if chip_stack_display:
		chip_stack_display.clear_chips()

func set_poker_active(is_active):
	if avatar:
		if is_active:
			avatar.modulate = Color.WHITE
		else:
			avatar.modulate = Color(0.7, 0.7, 0.7)

func _on_avatar_updated(_new_avatar_data):
	_update_avatar()

func _update_avatar():
	if not avatar_viewport:
		push_error("AvatarViewport node not found in PlayerUI")
		return

	var avatar_scene = avatar_viewport.get_node_or_null("AvatarScene")
	if avatar_scene:
		_update_avatar_scene(avatar_scene, PlayerData.get_avatar_data())
		avatar.texture = avatar_viewport.get_texture()
	else:
		push_error("AvatarScene not found in AvatarViewport")

func _update_avatar_scene(avatar_scene, avatar_data):
	if not avatar_data:
		print("Debug: No avatar data provided")
		return
		
	print("Debug: Starting avatar update with data:", avatar_data)
	
	for layer in avatar_layers:
		var layer_name = layer.replace("_", " ").capitalize()
		var sprite = avatar_scene.get_node_or_null(layer_name)
		
		if sprite:
			print("Debug: Processing layer:", layer)
			var part_id = avatar_data.get(layer)
			print("Debug: Part ID for", layer, ":", part_id)
			
			if part_id != null and part_id != "<null>":
				var texture_path = "res://assets/avatars/" + layer + "/" + str(part_id) + ".png"
				print("Debug: Attempting to load texture:", texture_path)
				var texture = load(texture_path)
				if texture:
					print("Debug: Successfully loaded texture for", layer)
					sprite.texture = texture
					sprite.visible = true
				else:
					push_error("Failed to load texture: " + texture_path)
					sprite.visible = false
			else:
				print("Debug: No texture for", layer, ", hiding sprite")
				sprite.visible = false
		else:
			push_warning("Node not found: " + layer_name)

func clear_cards():
	card1.texture = null
	card2.texture = null
	hide_timer()

func _exit_tree():
	# Ensure we clean up the chip display if it was reparented
	if chip_stack_display and is_instance_valid(chip_stack_display):
		chip_stack_display.queue_free()
