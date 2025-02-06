# PlayerUIBase.gd
class_name PlayerUIBase
extends Control

# Common onready vars
@onready var name_label = $Panel/NameLabel
@onready var chip_count_label = $Panel/ChipCount
@onready var card1 = $Cards/Card1
@onready var card2 = $Cards/Card2
@onready var avatar_display = $Panel/AvatarDisplay
@onready var timer_bar = $Panel/TimerBar
@onready var panel = $Panel

func _ready():
	if timer_bar:
		initialize_timer_bar()

func initialize_timer_bar():
	timer_bar.min_value = 0
	timer_bar.max_value = 1
	timer_bar.value = 1
	timer_bar.show_percentage = false
	timer_bar.visible = false
	
	# Add theme stylebox for the timer
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(1, 1, 0)  # Yellow default color
	timer_bar.add_theme_stylebox_override("fill", style_box)

# Base display update that can be extended
func update_display(player_data: Dictionary, is_current_player: bool, show_cards: bool) -> void:
	if not player_data:
		push_error("Invalid player data provided to PlayerUIBase")
		return
		
	# Update name and chip count
	name_label.text = player_data.get("name", "Unknown")
	chip_count_label.text = "Chips: " + Utilities.format_number(player_data.get("chips", 0))
	
	# Handle cards
	if player_data.get("folded", false):
		clear_cards()
	elif show_cards or is_current_player:
		_show_player_cards(player_data.get("cards", []))
	else:
		_show_card_backs()
		
	# Update timer visibility
	if timer_bar:
		timer_bar.visible = is_current_player
		
	# Update active state
	set_poker_active(is_current_player)

func _show_player_cards(cards: Array) -> void:
	if cards.size() >= 2:
		var card1_path = "res://assets/cards/" + cards[0].rank.to_lower() + "_of_" + cards[0].suit.to_lower() + ".png"
		var card2_path = "res://assets/cards/" + cards[1].rank.to_lower() + "_of_" + cards[1].suit.to_lower() + ".png"
		
		card1.texture = load(card1_path)
		card2.texture = load(card2_path)
		card1.visible = true
		card2.visible = true
	else:
		clear_cards()

func _show_card_backs() -> void:
	var back_texture = load("res://assets/cards/card_back.png")
	card1.texture = back_texture
	card2.texture = back_texture
	card1.visible = true
	card2.visible = true

func update_timer_display(progress: float, is_warning: bool) -> void:
	if timer_bar:
		timer_bar.visible = true
		timer_bar.value = progress
		
		var fill_style = timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if is_warning:
				var flash_time = Time.get_ticks_msec() / 500.0
				fill_style.bg_color = Color.RED if int(flash_time) % 2 == 0 else Color.YELLOW
			else:
				fill_style.bg_color = Color.GREEN

func hide_timer() -> void:
	if timer_bar:
		timer_bar.visible = false

func clear_cards() -> void:
	card1.texture = null
	card2.texture = null

func set_poker_active(is_active: bool) -> void:
	if is_active:
		panel.modulate = Color.WHITE
	else:
		panel.modulate = Color(0.7, 0.7, 0.7)
