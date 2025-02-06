# JackpotSNGScene.gd
extends Control

# Tournament-specific UI elements
@onready var game_manager = $JackpotSNGGameManager
@onready var timer_value_label = $TournamentInfo/InfoVBox/TimerDisplay/TimerValue
@onready var blind_value_label = $TournamentInfo/InfoVBox/BlindDisplay/BlindValue
@onready var prize_value_label = $TournamentInfo/InfoVBox/PrizeDisplay/PrizeValue
@onready var action_ui = $ActionUI
@onready var players_node = $Players
@onready var community_cards_node = $CommunityCards
@onready var pot_label = $PotContainer/PotLabel
@onready var return_to_lobby_button = $ReturnToLobbyButton
@onready var dealer_button = $DealerButton
@onready var winner_popup = $WinnerPopup

func _ready():
	if not _verify_scene_nodes():
		push_error("Critical scene nodes missing or invalid")
		return
	
	# Get initial game state
	var game_state = GameData.get_game_data()
	if not game_state or not game_state.has("players") or game_state.players.is_empty():
		push_error("Invalid game state in JackpotSNGScene")
		SceneManager.return_to_main_hub()
		return
	
	_connect_signals()
	game_manager.initialize_game(game_state)
	_initialize_ui()
	_update_tournament_info()

func _verify_scene_nodes() -> bool:
	var all_valid = true
	var required_nodes = {
		"game_manager": game_manager,
		"action_ui": action_ui,
		"players_node": players_node,
		"community_cards_node": community_cards_node,
		"pot_label": pot_label,
		"dealer_button": dealer_button,
		"winner_popup": winner_popup
	}
	
	var tournament_nodes = {
		"timer_value_label": timer_value_label,
		"blind_value_label": blind_value_label,
		"prize_value_label": prize_value_label
	}

	for node_name in required_nodes:
		if not required_nodes[node_name]:
			push_error("Required node not found: " + node_name)
			all_valid = false

	for node_name in tournament_nodes:
		if not tournament_nodes[node_name]:
			push_error("Tournament node not found: " + node_name)
			all_valid = false

	return all_valid

func _connect_signals():
	if game_manager:
		game_manager.hand_updated.connect(_on_hand_updated)
		game_manager.game_state_changed.connect(_on_game_state_changed)
		game_manager.chips_updated.connect(_on_chips_updated)
		game_manager.betting_started.connect(_on_betting_started)
		game_manager.player_turn_started.connect(_on_player_turn_started)
		game_manager.player_eliminated.connect(_on_player_eliminated)
		game_manager.game_over.connect(_on_game_over)
		game_manager.blind_timer_updated.connect(_on_blind_timer_updated)
		game_manager.blinds_increased.connect(_on_blinds_increased)
		game_manager.dealer_position_changed.connect(_on_dealer_position_changed)
	
	if action_ui:
		action_ui.fold_pressed.connect(_on_fold_pressed)
		action_ui.check_call_pressed.connect(_on_check_call_pressed)
		action_ui.raise_pressed.connect(_on_raise_pressed)
	
	# Connect return to lobby button
	if return_to_lobby_button:
		# Disconnect any existing connections first to avoid duplicates
		if return_to_lobby_button.is_connected("pressed", _on_return_to_lobby_pressed):
			return_to_lobby_button.disconnect("pressed", _on_return_to_lobby_pressed)
		return_to_lobby_button.pressed.connect(_on_return_to_lobby_pressed)
	else:
		push_error("Return to lobby button not found")

func _initialize_ui():
	# Initialize tournament info
	var current_blinds = game_manager.get_current_blinds()
	blind_value_label.text = str(current_blinds.sb) + "/" + str(current_blinds.bb)
	timer_value_label.text = "03:00"  # Initial blind level time
	prize_value_label.text = Utilities.format_number(game_manager.get_tournament_prize())

	# Initialize player panels
	for i in range(players_node.get_child_count()):
		var player_panel = players_node.get_child(i)
		if player_panel.has_method("update_display"):
			var player_data = game_manager.players[i]
			player_panel.update_display(player_data, false, i == 0)

	# Hide all community cards initially
	for card_node in community_cards_node.get_children():
		card_node.visible = false

func _update_tournament_info():
	var current_blinds = game_manager.get_current_blinds()
	blind_value_label.text = str(current_blinds.sb) + "/" + str(current_blinds.bb)
	prize_value_label.text = Utilities.format_number(game_manager.get_tournament_prize())

# Tournament-specific signal handlers
func _on_blind_timer_updated(minutes: int, seconds: int):
	timer_value_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Flash warning when close to blind increase
	if minutes == 0 and seconds <= 30:
		var flash_cycle = Time.get_ticks_msec() / 500
		timer_value_label.modulate = Color.RED if int(flash_cycle) % 2 == 0 else Color.WHITE

func _on_blinds_increased(new_blinds: Dictionary):
	blind_value_label.text = str(new_blinds.sb) + "/" + str(new_blinds.bb)
	
	# Show blind increase notification
	var notification = Label.new()
	notification.text = "Blinds Increased!"
	notification.add_theme_color_override("font_color", Color.YELLOW)
	notification.position = Vector2(get_viewport_rect().size.x / 2, 100)
	add_child(notification)
	
	var tween = create_tween()
	tween.tween_property(notification, "modulate:a", 0.0, 2.0)
	tween.tween_callback(notification.queue_free)

func _on_player_eliminated(player_index: int):
	if players_node and player_index < players_node.get_child_count():
		var player_ui = players_node.get_child(player_index)
		if player_ui and player_ui.has_method("eliminate_player"):
			player_ui.eliminate_player()

func _on_game_over(winner_index: int, prize: int):
	# Show end game popup
	var popup = AcceptDialog.new()
	popup.dialog_text = "Tournament Complete!\n" + \
					   "Winner: " + game_manager.players[winner_index].name + "\n" + \
					   "Prize: " + Utilities.format_number(prize) + " chips"
	add_child(popup)
	popup.popup_centered()
	
	# Return to hub after delay
	await get_tree().create_timer(3.0).timeout
	SceneManager.return_to_main_hub()

# Standard game action handlers
func _on_fold_pressed():
	if game_manager.current_player_index == 0:
		game_manager.handle_fold(0)

func _on_check_call_pressed():
	if game_manager.current_player_index == 0:
		game_manager.handle_call(0)

func _on_raise_pressed():
	if game_manager.current_player_index == 0:
		var raise_amount = action_ui.get_node("BetControl/BetAmount").value
		game_manager.handle_raise(0, raise_amount)

# Standard game update handlers
func _on_hand_updated(hand_index: int):
	if hand_index == -1:
		# Update community cards
		for i in range(community_cards_node.get_child_count()):
			var card_node = community_cards_node.get_child(i)
			if i < game_manager.community_cards.size():
				var card = game_manager.community_cards[i]
				var texture_path = "res://assets/cards/%s_of_%s.png" % [card.rank.to_lower(), card.suit.to_lower()]
				card_node.texture = load(texture_path)
				card_node.visible = true
			else:
				card_node.visible = false
	else:
		# Update player hands
		var player_panel = players_node.get_child(hand_index)
		if player_panel and player_panel.has_method("update_display"):
			var player = game_manager.players[hand_index]
			player_panel.update_display(
				player, 
				hand_index == game_manager.current_player_index,
				hand_index == 0
			)

func _on_game_state_changed(state: String):
	match state:
		"hand_started":
			_update_tournament_info()
		"betting_started":
			for player_panel in players_node.get_children():
				player_panel.modulate = Color(1, 1, 1)
			if action_ui:
				action_ui.hide()
		"winner_determined":
			if winner_popup and game_manager.current_betting_round == "showdown":
				var active_players = game_manager.players.filter(func(p): return not p.folded and not p.eliminated)
				if active_players.size() == 1:
					var winner = active_players[0]
					winner_popup.show_winner(winner.name, "", game_manager.pot)
		"blinds_increased":
			_update_tournament_info()

func _on_chips_updated(player_index: int, new_amount: int):
	var player_panel = players_node.get_child(player_index)
	if player_panel:
		var chip_count_label = player_panel.get_node("Panel/ChipCount")
		if chip_count_label:
			chip_count_label.text = "Chips: " + Utilities.format_number(new_amount)

func _on_betting_started():
	# Hide action UI
	if action_ui:
		action_ui.hide()
	
	# Reset player highlights
	for player_panel in players_node.get_children():
		player_panel.modulate = Color(1, 1, 1)

func _on_player_turn_started(player_index: int):
	# Update UI for all players
	for i in range(players_node.get_child_count()):
		var player_panel = players_node.get_child(i)
		var is_current = i == player_index
		
		if player_panel.has_method("update_display"):
			var player_data = game_manager.players[i]
			player_panel.update_display(player_data, is_current, i == 0)
	
	# Update action UI for human player
	var is_human_turn = player_index == 0
	if is_human_turn and action_ui:
		action_ui.show()
		
		# Update call button text
		var call_amount = game_manager.current_bet - game_manager.players[0].bet
		var button_text = "Call " + str(call_amount) if call_amount > 0 else "Check"
		action_ui.update_call_button_text(button_text)
	else:
		if action_ui:
			action_ui.hide()

func _on_dealer_position_changed(new_position: int):
	if dealer_button:
		var target_position = game_manager.dealer_button_positions[new_position]
		
		# Create tween for smooth movement
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(dealer_button, "position", target_position, 0.5)

func _on_return_to_lobby_pressed():
	print("Debug: Return to lobby button pressed in JackpotSNGScene")
	if game_manager:
		game_manager._on_return_to_lobby_pressed()
	else:
		push_error("Game manager not found when trying to return to lobby")
		# Fallback direct return if game manager isn't available
		SceneManager.return_to_main_hub()
