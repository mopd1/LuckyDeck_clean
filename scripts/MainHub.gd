# MainHub.gd
extends Control

signal game_joined(game_data)

@onready var profile_display = $ProfileDisplay
@onready var avatar_button = $ProfileDisplay/AvatarButton
@onready var player_name_label = $PlayerPanel/PlayerName
@onready var chip_balance_display = $PlayerPanel2/ChipBalanceDisplay
@onready var gem_balance_display = $PlayerPanel2/GemBalanceDisplay
@onready var game_type_selection = $GameSelectionArea/GameTypeSelection
@onready var stake_selection = $GameSelectionArea/StakeSelection
@onready var play_button = $GameSelectionArea/GamePanels/NLHoldemPanel/PlayButton
@onready var engagement_features_button = $EngagementFeaturesButton
@onready var purchase_chips_button = $PurchaseChipsButton
@onready var logout_button = $LogoutButton
@onready var avatar_display = $PlayerPanel/AvatarDisplay  # This should be an TextureRect
@onready var customize_avatar_button = $PlayerPanel/CustomizeAvatarButton
@onready var avatar_viewport = $AvatarViewport
@onready var avatar_scene = avatar_viewport.get_node("AvatarScene")
@onready var user_profile_button = $PlayerPanel/UserProfileButton
@onready var test_api_button = $TestAPIButton
@onready var friends_button = $FriendsButton
@onready var nl_holdem_panel = $GameSelectionArea/GamePanels/NLHoldemPanel
@onready var pl_omaha_panel = $GameSelectionArea/GamePanels/PLOmahaPanel
@onready var jackpot_sng_panel = $GameSelectionArea/GamePanels/JackpotSNGPanel
@onready var mtt_panel = $GameSelectionArea/GamePanels/MTTPanel
@onready var poker_panels = $GameSelectionArea/GamePanels
@onready var challenge_button = $ChallengeProgressButton
@onready var game_area_rect = $GameSelectionArea/ColorRect
@onready var shader_material: ShaderMaterial
@onready var game_selection_area = $GameSelectionArea
@onready var purchase_button = $PurchaseChipsButton
@onready var purchase_button_material: ShaderMaterial
@onready var table_games_panels = $GameSelectionArea/TableGamesPanels
@onready var table_games_button = $GameSelectionArea/GameTypeButtons/TableGamesButton
@onready var sports_betting_button = $GameSelectionArea/GameTypeButtons/SportsBettingButton
@onready var poker_test_button = $PokerTestButton

var tooltip_scene = preload("res://scenes/Tooltip.tscn")
var JackpotSNGManager = preload("res://scripts/JackpotSNGManager.gd").new()
var current_tooltip = null
var tooltip_timer: Timer

var avatar_layers = ["face", "clothing", "hair", "hat", "ear_accessories", "mouth_accessories"]
var player_data = {
	"name": "Player1",
	"total_balance": 10000,
	"leaderboard_points": 0
}

var original_main_scene = Node

func _ready():
	# Debug: Track initialization sequence
	print("Debug: MainHub _ready() started")
	
	# Check authentication
	if APIManager.user_token.is_empty():
		print("Debug: No user token found. Redirecting to login.")
		SceneManager.goto_scene("res://scenes/LoginScene.tscn")
		return
	
	# Connect to API manager signals first
	if not APIManager.is_connected("user_data_received", _on_user_data_received):
		APIManager.connect("user_data_received", _on_user_data_received)
		print("Debug: Connected to user_data_received signal")
	
	# Connect to PlayerData signals
	if not PlayerData.is_connected("balance_updated", _on_balance_updated):
		PlayerData.connect("balance_updated", _on_balance_updated)
		print("Debug: Connected to balance_updated signal")
	if not PlayerData.is_connected("balance_initialized", _on_balance_initialized):
		PlayerData.connect("balance_initialized", _on_balance_initialized)
		print("Debug: Connected to balance_initialized signal")
	
	# Hide balance displays until we have data
	if chip_balance_display:
		chip_balance_display.text = ""
	if gem_balance_display:
		gem_balance_display.text = ""
	
	# Update displays with current data before requesting new data
	print("Debug: Initial balance:", PlayerData.get_balance())
	update_chip_balance_display()
	update_gem_balance_display()
	
	# Request fresh data from server
	print("Debug: Requesting user data from server")
	APIManager.get_user_data()
	
	hide_all_game_sections()
	
	# Initialize UI and connect signals
	initialize_ui()
	connect_signals()
	setup_game_panels()
	
	print("Debug: MainHub setup complete")
	
	# Keep all existing connections
	PlayerData.connect("gem_balance_updated", _on_gem_balance_updated)
	PlayerData.connect("balance_updated", _on_balance_changed)
	update_challenge_button()
	PlayerData.connect("challenge_points_updated", _on_challenge_points_updated)
	GameJoiner.connect("game_joined", _on_game_joined)
	GameJoiner.connect("join_failed", _on_join_failed)
	
	setup_table_games_panels()
	
	# Connect button signals
	table_games_button.pressed.connect(_on_table_games_button_pressed)
	logout_button.pressed.connect(_on_logout_button_pressed)
	user_profile_button.pressed.connect(_on_user_profile_button_pressed)
	test_api_button.pressed.connect(_on_test_api_pressed)
	friends_button.pressed.connect(_on_friends_button_pressed)
	$GameSelectionArea/GameTypeButtons/PokerButton.pressed.connect(_on_poker_button_pressed)
	poker_test_button.pressed.connect(_on_poker_test_button_pressed)
	
	# Initialize challenge button
	if challenge_button:
		challenge_button.pressed.connect(_on_challenge_button_pressed)
		update_challenge_button()
	
	# Connect to JackpotSNGManager signals
	if not JackpotSNGManager.is_connected("game_ready", _on_jackpot_sng_game_ready):
		JackpotSNGManager.connect("game_ready", _on_jackpot_sng_game_ready)
	if not JackpotSNGManager.is_connected("multiplier_selected", _on_jackpot_sng_multiplier_selected):
		JackpotSNGManager.connect("multiplier_selected", _on_jackpot_sng_multiplier_selected)
	
	# Add verification for the customize button
	var customize_button = $PlayerPanel/CustomizeAvatarButton
	if customize_button:
		print("Debug: CustomizeAvatarButton found")
		if not customize_button.is_connected("pressed", _on_customize_avatar_button_pressed):
			customize_button.pressed.connect(_on_customize_avatar_button_pressed)
			print("Debug: CustomizeAvatarButton signal connected")
	else:
		push_error("CustomizeAvatarButton not found in scene")
	
	# Initialize stake selection and theme
	initialize_stake_selection()
	
	# Update avatar display
	_update_avatar_display()
	$PlayerPanel/AvatarDisplay.texture = $AvatarViewport.get_texture()
	
	# Pre-select NL Holdem Cash Game
	preselect_nl_holdem_cash_game()

func get_node_parent_chain(node: Node) -> String:
	var chain = ""
	var current = node
	while current:
		chain = current.get_class() + " -> " + chain
		current = current.get_parent()
	return chain

func _process(_delta):
	if shader_material:
		game_selection_area.queue_redraw()

func _on_user_data_received(data):
	print("Debug: User data received in MainHub:", data)
	
	if not data is Dictionary:
		push_error("Received invalid user data type")
		return
	
	# Check for both "balance" and "chips" fields for compatibility
	var balance = null
	if data.has("balance"):
		balance = data["balance"]
		print("Debug: Found balance field:", balance)
	elif data.has("chips"):
		balance = data["chips"]
		print("Debug: Found chips field:", balance)
		
	if balance != null:
		print("Debug: Updating chip balance to:", balance)
		PlayerData.player_data["total_balance"] = balance
		if chip_balance_display:
			chip_balance_display.text = Utilities.format_number(balance)
	
	if data.has("gems"):
		print("Debug: Updating gem balance to:", data.gems)
		PlayerData.player_data["gems"] = data.gems
		if gem_balance_display:
			gem_balance_display.text = Utilities.format_number(data.gems)

func hide_all_game_sections():
	poker_panels.hide()
	table_games_panels.hide()

func setup_table_games_panels():
	var blackjack_panel = table_games_panels.get_node("BlackjackPanel")
	var roulette_panel = table_games_panels.get_node("RoulettePanel")
	var craps_panel = table_games_panels.get_node("CrapsPanel")
	
	blackjack_panel.set_game_type("Blackjack", true)
	roulette_panel.set_game_type("Roulette")
	craps_panel.set_game_type("Craps")
	
	blackjack_panel.play_pressed.connect(_on_blackjack_play_pressed)

func _on_table_games_button_pressed():
	hide_all_game_sections()
	table_games_panels.show()

func _on_poker_button_pressed():
	hide_all_game_sections()
	poker_panels.show()

func _on_blackjack_play_pressed(_game_type):
	SceneManager.go_to_blackjack_scene()

func initialize_ui():
	update_profile_display()
	update_chip_balance_display()
	update_gem_balance_display()
	initialize_game_type_selection()
	initialize_stake_selection()
	play_button.disabled = true

func setup_game_panels():
	print("Debug: Setting up game panels...")
	
	# Get references to the panels
	var panels = {
		"nl_holdem": $GameSelectionArea/GamePanels/NLHoldemPanel,
		"pl_omaha": $GameSelectionArea/GamePanels/PLOmahaPanel,
		"jackpot_sng": $GameSelectionArea/GamePanels/JackpotSNGPanel,
		"mtt": $GameSelectionArea/GamePanels/MTTPanel
	}
	
	# Verify all panels exist
	for panel_name in panels:
		if not panels[panel_name]:
			push_error("Failed to find panel: " + panel_name)
			return
		print("Debug: Found panel: " + panel_name)
	
	# Setup each panel
	panels["nl_holdem"].set_game_type("NL Hold'em Cash Game", true)
	panels["nl_holdem"].play_pressed.connect(_on_game_panel_play_pressed)
	
	panels["pl_omaha"].set_game_type("PL Omaha Cash Game", false)
	
	panels["jackpot_sng"].set_game_type("Jackpot SNG", true)
	if panels["jackpot_sng"]:
		panels["jackpot_sng"].play_pressed.connect(_on_jackpot_sng_play_pressed)
		panels["jackpot_sng"].unregister_requested.connect(_on_jackpot_sng_unregister_requested)
		panels["jackpot_sng"].start_game_requested.connect(_on_jackpot_sng_start_game_requested)
	
	panels["mtt"].set_game_type("Multi-Table Tournament", false)

	# Make sure panels container is visible
	var panels_container = $GameSelectionArea/GamePanels
	if panels_container:
		panels_container.show()
		print("Debug: Game panels container shown")
	else:
		push_error("Failed to find game panels container")

	print("Debug: Game panels setup completed")

# Add new handler for game start request
func _on_jackpot_sng_start_game_requested(stake: int):
	print("Debug: Starting game with AI players")
	_trigger_test_game_start(stake)

func _on_game_panel_play_pressed(game_type: String, stake: int):
	print("Debug: Game panel play pressed")
	print("Debug: Game type:", game_type)
	print("Debug: Stake:", stake)
	print("Debug: Available stakes:", GameJoiner.AVAILABLE_STAKES)
	print("Debug: Available game types:", GameJoiner.available_game_types.keys())
	
	# Make sure we're using the exact game type string
	if game_type == "NL Hold'em Cash Game":
		print("Debug: Attempting to join game")
		print("Debug: Using game type:", game_type)  # Should be exact match
		print("Debug: Using stake:", stake)
		
		var player_data = {"name": "Player1"}
		# Create game_type variable for clarity
		var joiner_game_type = "NL Hold'em Cash Game"
		print("Debug: Calling join_game with type:", joiner_game_type)
		GameJoiner.join_game(player_data, joiner_game_type, stake)
	else:
		push_error("Unknown game type: " + game_type)

func _on_jackpot_sng_play_pressed(game_type: String, stake: int):
	print("Debug: Starting Jackpot SNG registration for stake:", stake)
	
	# Clear any existing game state
	JackpotSNGManager.cleanup_game()
	
	if JackpotSNGManager.register_player(User.current_user_id, stake):
		print("Registration successful")
		# The timer and game start is now handled by the panel itself
		# through its registration_timeout signal
	else:
		print("Registration failed")
		
func _trigger_test_game_start(stake: int):
	print("Debug: Triggering test game start")
	
	# Register two AI players with negative IDs to distinguish them
	if JackpotSNGManager.register_player(-1, stake) and \
	   JackpotSNGManager.register_player(-2, stake):
		print("AI players registered successfully")
		
		# Make sure the JackpotSNGManager emits the game_ready signal
		# This will trigger the scene transition
		var players = JackpotSNGManager.registered_players[stake]
		print("Debug: Registered players:", players)
		JackpotSNGManager.emit_signal("game_ready", players)
	else:
		print("Failed to register AI players")

func _on_jackpot_sng_unregister_requested(stake_level: int):
	print("Debug: Unregistering from Jackpot SNG stake:", stake_level)
	JackpotSNGManager.unregister_player(User.current_user_id, stake_level)

func _on_jackpot_sng_game_ready(players: Array):
	print("Debug: Jackpot SNG game ready, transitioning to multiplier reveal")
	print("Debug: Players:", players)
	
	# Get and store the current game state
	var state = JackpotSNGManager.get_current_game_state()
	print("Debug: Current game state before transition:", state)
	
	# Store in GameData singleton
	GameData.set_game_data(state)
	
	# Transition to multiplier reveal scene
	SceneManager.goto_scene("res://scenes/JackpotMultiplierScene.tscn")

func _on_jackpot_sng_multiplier_selected(multiplier: float, prize: int):
	print("Debug: Multiplier selected:", multiplier, "Prize:", prize)
	# Wait for animation then transition to game
	await get_tree().create_timer(5.0).timeout
	SceneManager.goto_scene("res://scenes/JackpotSNGScene.tscn")

func set_player_data(data):
	player_data["name"] = data["name"]
	player_data["total_balance"] = data["total_balance"]
	player_data["leaderboard_points"] = data.get("leaderboard_points", 0)
	call_deferred("update_profile_display")

func update_profile_display():
	if player_name_label:
		player_name_label.text = PlayerData.player_data["name"]
	if chip_balance_display:
		chip_balance_display.text = str(PlayerData.player_data["total_balance"])
	if gem_balance_display:  # New block
		gem_balance_display.text = str(PlayerData.player_data["gems"])

func _on_balance_updated(new_balance: int):
	update_chip_balance_display()
	update_stake_selection_on_balance_change()

func _on_balance_changed(_new_balance: int):
	update_stake_selection_on_balance_change()

func _on_balance_initialized():
	print("Debug: Balance initialized in MainHub")
	print("Debug: Current balance:", PlayerData.get_balance())
	update_chip_balance_display()
	initialize_stake_selection()

func update_chip_balance_display():
	if chip_balance_display:
		var balance = PlayerData.get_balance()
		print("Debug: Updating chip display to:", balance)
		chip_balance_display.text = Utilities.format_number(balance)
	else:
		push_error("chip_balance_display node not found")

func update_gem_balance_display():
	if gem_balance_display:
		gem_balance_display.text = Utilities.format_number(PlayerData.player_data["gems"])

func _on_gem_balance_updated(new_balance):
	update_gem_balance_display()

func initialize_challenge_button():
	update_challenge_button()
	challenge_button.pressed.connect(_on_challenge_button_pressed)

func update_challenge_button():
	if challenge_button:
		challenge_button.update_progress_display()

func _on_challenge_points_updated(_points):
	update_challenge_button()

func _on_challenge_button_pressed():
	SceneManager.goto_scene("res://scenes/ChallengeScene.tscn")

func initialize_game_type_selection():
	game_type_selection.clear()
	var game_types = GameJoiner.get_game_types()
	for game_type in game_types:
		game_type_selection.add_item(game_type)

func initialize_stake_selection():
	stake_selection.clear()
	var stakes = GameJoiner.get_stakes(game_type_selection.get_item_text(game_type_selection.selected))
	var player_balance = PlayerData.player_data["total_balance"]

	for i in range(stakes.size()):
		var stake = stakes[i]
		stake_selection.add_item(str(stake))
		if player_balance < stake * 100:
			stake_selection.set_item_disabled(i, true)
			stake_selection.set_item_metadata(i, "Chip balance too low to play this stake level")
		else:
			stake_selection.set_item_disabled(i, false)
			stake_selection.set_item_metadata(i, "")

	update_play_button_state()

func update_stake_selection_on_balance_change():
	if not game_type_selection or not stake_selection:
		return
		
	var current_balance = PlayerData.get_balance()
	var stakes = GameJoiner.get_stakes(game_type_selection.get_item_text(game_type_selection.selected))
	
	for i in range(stakes.size()):
		var stake = stakes[i]
		var required_stack = stake * 100  # 100 big blinds
		stake_selection.set_item_disabled(i, current_balance < required_stack)
		
		# Update tooltip for disabled stakes
		if current_balance < required_stack:
			stake_selection.set_item_metadata(i, "Requires " + Utilities.format_number(required_stack) + " chips")
		else:
			stake_selection.set_item_metadata(i, "")
	
	update_play_button_state()

func preselect_nl_holdem_cash_game():
	for i in range(game_type_selection.get_item_count()):
		if game_type_selection.get_item_text(i) == "NL Holdem Cash Game":
			game_type_selection.select(i)
			_on_game_type_selected(i)
			return
	print("NL Holdem Cash Game not found in game type selection")

func connect_signals():
	game_type_selection.item_selected.connect(_on_game_type_selected)
	stake_selection.item_selected.connect(_on_stake_selected)
	engagement_features_button.pressed.connect(_on_engagement_features_button_pressed)
	purchase_chips_button.pressed.connect(_on_purchase_chips_button_pressed)
	avatar_button.pressed.connect(_on_avatar_button_pressed)

func set_original_scene(scene):
	original_main_scene = scene

func set_player_balance(balance):
	PlayerData.player_data["total_balance"] = balance
	call_deferred("update_chip_balance_display")

func _on_game_type_selected(index):
	var selected_game_type = game_type_selection.get_item_text(index)
	initialize_stake_selection()

func update_stake_selection(game_type):
	stake_selection.clear()
	var stakes = GameJoiner.get_stakes(game_type)
	for stake in stakes:
		stake_selection.add_item(str(stake))
	stake_selection.disabled = false
	play_button.disabled = true
	
	# Select the first stake by default
	if stakes.size() > 0:
		stake_selection.select(0)
		_on_stake_selected(0)

func _on_stake_selected(index):
	print("Debug: Stake selected - Index:", index)
	print("Debug: Actual stake value:", stake_selection.get_item_text(index))
	update_play_button_state()

func update_play_button_state():
	var selected_index = stake_selection.selected
	play_button.disabled = selected_index == -1 or stake_selection.is_item_disabled(selected_index)

func _on_stake_selection_mouse_entered():
	var mouse_position = get_global_mouse_position()
	var item_index = stake_selection.get_selected_id()
	if item_index != -1 and stake_selection.is_item_disabled(item_index):
		show_tooltip(stake_selection.get_item_metadata(item_index), mouse_position)

func _on_stake_selection_mouse_exited():
	hide_tooltip()

func _on_stake_selection_about_to_popup():
	var popup = stake_selection.get_popup()
	for i in range(popup.item_count):
		if popup.is_item_disabled(i):
			var global_pos = stake_selection.global_position
			global_pos.y += stake_selection.size.y + (i * stake_selection.get_theme_constant("v_separation"))
			show_tooltip(popup.get_item_metadata(i), global_pos)
			return
	hide_tooltip()

func _on_stake_selection_popup_hide():
	hide_tooltip()

func _on_tooltip_timer_timeout():
	if current_tooltip and current_tooltip.visible:
		var mouse_pos = get_global_mouse_position()
		var popup = stake_selection.get_popup()
		var option_rect = Rect2(stake_selection.global_position, stake_selection.size)
		option_rect.size.y += popup.item_count * stake_selection.get_theme_constant("v_separation")
		if not option_rect.has_point(mouse_pos):
			hide_tooltip()

func show_tooltip(text, position):
	if current_tooltip == null:
		current_tooltip = tooltip_scene.instantiate()
		add_child(current_tooltip)
	current_tooltip.set_text(text)
	current_tooltip.global_position = position
	current_tooltip.show()

func hide_tooltip():
	if current_tooltip:
		current_tooltip.hide()

func _on_mouse_exited():
	hide_tooltip()

func _on_play_button_pressed():
	var selected_game_type = game_type_selection.get_item_text(game_type_selection.selected)
	var selected_stake = int(stake_selection.get_item_text(stake_selection.selected))
	
	print("Debug: Attempting to join game")
	print("Debug: Selected game type:", selected_game_type)
	print("Debug: Selected stake:", selected_stake)
	print("Debug: Current balance:", PlayerData.get_balance())
	
	# Double check balance before attempting to join
	var required_stack = selected_stake * 100
	if not PlayerData.has_sufficient_balance(required_stack):
		_on_join_failed("Insufficient balance for this stake level")
		return
	
	GameJoiner.join_game(PlayerData.player_data, selected_game_type, selected_stake)

func _on_game_joined(game_data):
	print("Successfully joined game: ", game_data)
	# Store the game data in our singleton
	GameData.set_game_data(game_data)
	# Switch to the MainScene
	SceneManager.goto_scene("res://scenes/MainScene.tscn")

func _on_join_failed(reason):
	print("Failed to join game: ", reason)
	# You might want to show an error message to the user here

func start_game(game_data):
	if original_main_scene:
		# Return to the original MainScene
		original_main_scene.show()
		original_main_scene.get_node("GameManager").initialize_game(game_data)
		get_tree().current_scene = original_main_scene
	else:
		# If for some reason we don't have the original scene, create a new one
		var main_scene = preload("res://scenes/MainScene.tscn").instantiate()
		main_scene.get_node("GameManager").initialize_game(game_data)
		get_tree().root.add_child(main_scene)
		get_tree().current_scene = main_scene
	
	# Hide and queue_free the MainHub scene
	self.hide()
	self.queue_free()

func _on_engagement_features_button_pressed():
	# Implement engagement features access
	pass

func _on_purchase_chips_button_pressed():
	SceneManager.goto_scene("res://scenes/PurchaseScene.tscn")

func _on_avatar_button_pressed():
	SceneManager.goto_scene("res://scenes/PlayerPersonalisationScene.tscn")

func _update_avatar():
	var avatar_data = PlayerData.get_avatar_data()
	print("Updating avatar with data: ", avatar_data)  # Debug print
	if avatar_data and avatar_data["face"]:
		_update_custom_avatar(avatar_data)
	else:
		var avatar_id = PlayerData.get_avatar()
		$AvatarButton.texture_normal = load("res://assets/avatars/avatar_" + str(avatar_id) + ".png")

func _update_custom_avatar(avatar_data):
	# This is a simplified version. You'll need to implement proper avatar composition
	if avatar_data["face"]:
		var face_texture = load("res://assets/avatars/face/" + avatar_data["face"] + ".png")
		if face_texture:
			$AvatarButton.texture_normal = face_texture
		else:
			push_error("Failed to load face texture: " + avatar_data["face"])
	else:
		push_error("No face texture found in avatar data")

func _on_avatar_updated(_new_avatar_data):
	_update_avatar_display()

func _get_node_path_string(node: Node, indent: int) -> String:
	var indent_string = "  ".repeat(indent)
	var result = indent_string + node.name + "\n"
	for child in node.get_children():
		result += _get_node_path_string(child, indent + 1)
	return result

func _on_customize_avatar_button_pressed():
	print("Debug: Current user token: ", APIManager.user_token)
	print("Debug: Current user ID: ", User.current_user_id)
	SceneManager.goto_scene("res://scenes/PlayerPersonalisationScene.tscn")

func _update_avatar_display():
	var avatar_data = PlayerData.get_avatar_data()
	if not avatar_data or avatar_data.size() == 0:
		print("No avatar data found. Using default avatar.")
		# Optionally, set a default avatar texture
		avatar_display.texture = preload("res://assets/avatars/default_avatar.png")
		return

	# Reference to the AvatarScene instance in the Viewport
	var avatar_scene = $AvatarViewport/AvatarScene

	for layer in avatar_layers:
		var layer_name = layer.capitalize()  # e.g., "face" -> "Face"
		var sprite = avatar_scene.get_node(layer_name)
		if sprite and sprite is Sprite2D:
			if avatar_data.get(layer):
				var texture_path = "res://assets/avatars/" + layer + "/" + avatar_data[layer] + ".png"
				var texture = load(texture_path)
				if texture and texture is Texture2D:
					sprite.texture = texture
					sprite.visible = true
				else:
					push_error("Failed to load texture for " + layer + ": " + texture_path)
					sprite.visible = false
			else:
				sprite.visible = false
		else:
			push_error("Sprite node not found for layer: " + layer_name)

func _on_logout_button_pressed():
	SceneManager.go_to_login_scene()

func _on_user_profile_button_pressed():
	SceneManager.goto_scene("res://scenes/UserProfileScene.tscn")

func _on_test_api_pressed():
	APIManager.test_endpoints()

func _on_friends_button_pressed():
	SceneManager.go_to_friend_system()

func _on_poker_test_button_pressed():
	SceneManager.goto_scene("res://scenes/PokerTestScene.tscn")
