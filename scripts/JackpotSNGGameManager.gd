# JackpotSNGGameManager.gd
extends "res://scripts/GameManager.gd"  # Explicitly extend from GameManager

# Signals specific to JackpotSNG mode
signal player_eliminated(player_index)
signal game_over(winner_index, prize)
signal blinds_increased(new_blinds)
signal blind_timer_updated(minutes, seconds)

# JackpotSNG-specific constants
const BLIND_INTERVAL = 180.0  # 3 minutes
const STARTING_TOURNAMENT_CHIPS = 1000  # Fixed starting stack for all players
const BLIND_STRUCTURE = [
	{"sb": 15, "bb": 30},
	{"sb": 25, "bb": 50},
	{"sb": 50, "bb": 100},
	{"sb": 100, "bb": 200},
	{"sb": 200, "bb": 400},
	{"sb": 300, "bb": 600},
	{"sb": 400, "bb": 800},
	{"sb": 500, "bb": 1000},
	{"sb": 1000, "bb": 2000}
]

# Tournament-specific variables
var blind_level: int = 0
var blind_timer: Timer
var prize_multiplier: float = 1.0
var current_game_state: Dictionary
var jackpot_dealer_positions = {
	0: Vector2(960, 675),  # Bottom (You)
	1: Vector2(480, 300),  # Top left
	2: Vector2(1340, 300)  # Top right
}

func _ready():
	rng = CryptoRNG.new()
	super._ready()  # Call parent _ready
	setup_blind_timer()

func setup_blind_timer():
	if not blind_timer:
		blind_timer = Timer.new()
		blind_timer.wait_time = BLIND_INTERVAL
		blind_timer.one_shot = false
		add_child(blind_timer)
		blind_timer.timeout.connect(_on_blind_timer_timeout)
		blind_timer.start()

func get_player_count() -> int:
	return 3  # Always return 3 for Jackpot SNG games

func _is_valid_game_state() -> bool:
	return current_game_state.has("players") and \
		   current_game_state.players is Array and \
		   current_game_state.players.size() >= get_player_count()

func initialize_players(default_stack: int):
	players.clear()
	
	# Initialize all players with tournament chips
	for i in range(get_player_count()):
		var player_data = null
		if _is_valid_game_state():
			player_data = current_game_state.players[i]
		
		var is_ai = player_data.id < 0 if player_data else (i > 0)
		
		players.append({
			"id": player_data.id if player_data else i,
			"name": "Player " + str(i + 1) + ("" if not is_ai else " (AI)"),
			"chips": STARTING_TOURNAMENT_CHIPS,  # Everyone starts with same tournament chips
			"cards": [],
			"bet": 0,
			"folded": false,
			"had_turn_this_round": false,
			"eliminated": false,
			"is_ai": is_ai,
			"action_timer": ACTION_TIME_LIMIT,
			"is_timing_out": false
		})

func initialize_game(game_state = null):
	_player_count = 3  # Set for Jackpot SNG games
	
	if not rng:
		rng = CryptoRNG.new()

	if game_state:
		current_game_state = game_state
		print("Debug: Received game state:", game_state)
		
		if _is_valid_game_state():
			prize_multiplier = game_state.multiplier
			blind_level = 0
			var initial_blinds = BLIND_STRUCTURE[blind_level]
			big_blind = initial_blinds.bb
			small_blind = initial_blinds.sb
		else:
			print("Debug: Invalid game state provided, using defaults")
			current_game_state = {"players": []}
			big_blind = BLIND_STRUCTURE[0].bb
			small_blind = BLIND_STRUCTURE[0].sb
	else:
		print("Debug: No game state provided, using defaults")
		current_game_state = {"players": []}
		big_blind = BLIND_STRUCTURE[0].bb
		small_blind = BLIND_STRUCTURE[0].sb

	# Call parent's initialize_game with modified data
	var modified_game_data = {
		"big_blind": big_blind,
		"small_blind": small_blind
	}
	super.initialize_game(modified_game_data)

	# Start the blind timer
	setup_blind_timer()

# Override process to handle blind timer
func _process(delta):
	super._process(delta)
	
	if blind_timer and blind_timer.time_left > 0:
		var time_left = blind_timer.time_left
		var minutes = int(time_left) / 60
		var seconds = int(time_left) % 60
		blind_timer_updated.emit(minutes, seconds)

func move_dealer_button():
	if not dealer_button:
		push_error("Dealer button not initialized!")
		return
	
	# Convert the 6-position dealer_position to 3-position index
	var jackpot_position = dealer_position % 3
	var target_position = jackpot_dealer_positions[jackpot_position]
	
	# Create a Tween for smooth animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(dealer_button, "position", target_position, 0.5)
	
	# Emit signal for scene to handle
	dealer_position_changed.emit(jackpot_position)

# Override the complete start_new_hand function
func start_new_hand():
	# If this isn't the first hand, wait before clearing
	if not community_cards.is_empty():
		await get_tree().create_timer(2.0).timeout
	
	# Reset deck and clear community cards
	deck.reset()
	community_cards.clear()
	
	# Hide all community cards
	for i in range(5):
		var card_node = get_node("../CommunityCards/Card" + str(i + 1))
		if card_node:
			card_node.visible = false
			card_node.texture = null
	
	# Reset game state
	pot = 0
	current_bet = 0
	current_betting_round = "preflop"
	last_bet_amount = big_blind
	
	# Reset pot-related variables
	main_pot = 0
	side_pots.clear()
	active_bets.clear()
	all_in_players.clear()
	
	# Rotate dealer position for 3 players
	dealer_position = (dealer_position + 1) % 3
	
	# Only deal cards to players with chips
	for i in range(get_player_count()):
		players[i].bet = 0
		players[i].folded = players[i].chips <= 0  # Auto-fold players with no chips
		players[i].had_turn_this_round = false
		if players[i].chips > 0:
			players[i].cards = deck.deal_hand(2)
		else:
			players[i].cards = []
	
	# Handle blinds for 3-player game
	var small_blind_position = (dealer_position + 1) % 3
	var big_blind_position = (dealer_position + 2) % 3
	
	# Find players who can post blinds
	while players[small_blind_position].chips < small_blind:
		small_blind_position = (small_blind_position + 1) % 3
		if small_blind_position == dealer_position:
			# No one can post small blind, end hand
			return
	
	while players[big_blind_position].chips < big_blind or big_blind_position == small_blind_position:
		big_blind_position = (big_blind_position + 1) % 3
		if big_blind_position == dealer_position:
			# No one can post big blind, end hand
			return
	
	# Set blinds
	players[small_blind_position].chips -= small_blind
	players[small_blind_position].bet = small_blind
	players[big_blind_position].chips -= big_blind
	players[big_blind_position].bet = big_blind
	
	# Set current bet to big blind
	current_bet = big_blind
	last_bet_amount = big_blind
	
	# Reset all player timers
	for player in players:
		player.action_timer = 0.0
		player.is_timing_out = false
	
	# Update balances and UI
	update_human_player_balance()
	
	# Set current player (UTG - under the gun, first to act preflop)
	# In 3-player game, UTG is the dealer position
	current_player_index = dealer_position
	
	# Move dealer button to new position
	move_dealer_button()
	update_ui()
	update_player_displays()
	start_action_timer()
	
	# Update blind level display if needed
	var current_blinds = get_current_blinds()
	blinds_increased.emit(current_blinds)

func _on_blind_timer_timeout():
	blind_level = min(blind_level + 1, BLIND_STRUCTURE.size() - 1)
	var new_blinds = get_current_blinds()
	blinds_increased.emit(new_blinds)
	
	if blind_level < BLIND_STRUCTURE.size() - 1:
		blind_timer.start()

# Override player elimination handling
func handle_player_elimination(player_index: int):
	if player_index < 0 or player_index >= players.size():
		return
		
	players[player_index].eliminated = true
	players[player_index].chips = 0
	players[player_index].folded = true
	
	if player_index in all_in_players:
		all_in_players.erase(player_index)
	
	# If human player is eliminated
	if player_index == 0:
		# No chips returned - entry fee was already paid
		pass
	
	player_eliminated.emit(player_index)
	check_tournament_end()

func check_tournament_end() -> bool:
	var active_count = 0
	var last_active_index = -1
	
	for i in range(players.size()):
		if not players[i].eliminated:
			active_count += 1
			last_active_index = i
	
	if active_count == 1:
		# Winner found - award prize
		if last_active_index == 0:  # If human player won
			var prize = current_game_state.prize
			# Update real balance with tournament prize
			PlayerData.update_total_balance(prize)
			APIManager.update_server_balance(PlayerData.get_balance())
		
		game_over.emit(last_active_index, current_game_state.prize)
		return true
	
	return false

func get_current_blinds() -> Dictionary:
	return BLIND_STRUCTURE[blind_level]

func get_tournament_prize() -> int:
	return current_game_state.prize

# Override update_human_player_balance to prevent updating real balance during tournament
func update_human_player_balance():
	# Do nothing - tournament chips don't affect real balance
	pass

# Override update_server_balance to prevent updating during tournament
func update_server_balance(new_balance: int):
	# Do nothing - tournament chips don't affect server balance
	pass

# Override handle_showdown to check for eliminations
func determine_winner():  # This should match the function name in GameManager.gd
	super.determine_winner()
	
	# Check for eliminations after chips are awarded
	for i in range(players.size()):
		if not players[i].eliminated and players[i].chips <= 0:
			handle_player_elimination(i)

# Replace cleanup_game with correct function name
func reset_game_state():  # This should match the function name in GameManager.gd
	super.reset_game_state()
	if is_instance_valid(blind_timer):
		blind_timer.stop()
	blind_level = 0

func _on_return_to_lobby_pressed():
	print("Debug: Returning to lobby from JackpotSNG")
	
	# If the tournament isn't over, the player is forfeiting
	if not check_tournament_end():
		print("Debug: Player forfeiting tournament")
		# Handle elimination if player isn't already eliminated
		if not players[0].eliminated:
			handle_player_elimination(0)
	
	# No balance calculations needed - tournament chips don't affect real balance
	SceneManager.return_to_main_hub()
