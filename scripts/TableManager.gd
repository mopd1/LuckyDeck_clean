# TableManager.gd
extends Node

signal table_created(table_id, stake_level)
signal table_closed(table_id)
signal player_seated(table_id, seat_index, player_data)
signal player_left(table_id, seat_index)
signal tables_updated
signal hand_completed(table_id, winner_info)

enum HandRank {
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH
}

const CARD_VALUES = {
	"2": 2,
	"3": 3,
	"4": 4,
	"5": 5,
	"6": 6,
	"7": 7,
	"8": 8,
	"9": 9,
	"10": 10,
	"J": 11,
	"Q": 12,
	"K": 13,
	"A": 14
}

const MAX_PLAYERS = 6
const MIN_TABLES_PER_STAKE = 1

# Main structure: {stake_level: {table_id: TableData}}
var tables = {}

# TableData structure
# {
#    "id": string,                  # Unique table identifier
#    "stake_level": int,           # Big blind amount
#    "players": Array[Dictionary],  # Array of player data or null for empty seats
#    "active_hand": bool,          # Whether a hand is currently in progress
#    "creation_time": int,         # Unix timestamp of table creation
#    "last_activity": int,         # Unix timestamp of last action
#    "dealer_position": int,       # Current dealer position (0-5)
#    "current_pot": int,           # Current pot size
#    "current_bet": int,           # Current bet to call
#    "min_buyin": int,            # Minimum buyin (100 big blinds)
#    "max_buyin": int,            # Maximum buyin (200 big blinds)
#    "community_cards": Array,     # Shared cards on the board
#    "current_round": String,      # Current betting round (preflop, flop, turn, river)
#    "action_on": int,            # Index of player whose turn it is
#    "side_pots": Array,          # Track side pots for all-in situations
#    "hand_number": int,          # Current hand number
#    "waiting_players": Array,     # Players waiting to join next hand
#    "rake_eligible": bool,        # Whether current hand has reached flop
#    "total_rake": int,           # Total rake collected at this table
#    "hand_rake": int,            # Rake collected in current hand
#    "main_pot_before_rake": int,  # Main pot before rake deduction
#    "side_pots_before_rake": Array # Side pots before rake deduction
# }

# Player data structure within players array
# {
#    "user_id": string,           # Unique user identifier
#    "name": string,              # Display name
#    "chips": int,                # Current stack size
#    "bet": int,                  # Current bet in this round
#    "folded": bool,              # Whether player has folded
#    "sitting_out": bool,         # Whether player is sitting out
#    "cards": Array,              # Hole cards (only sent to the specific player)
#    "auto_post_blinds": bool,    # Whether to automatically post blinds
#    "last_action": String,       # Last action taken (fold, call, raise)
#    "last_action_amount": int,   # Amount of last action
#    "time_bank": float,          # Remaining time bank
#    "avatar_data": Dictionary    # Player's avatar customization data
# }

func _ready():
	# Initialize minimal tables for each stake level
	print("Debug: TableManager initializing...")
	for stake in GameJoiner.AVAILABLE_STAKES:
		print("Debug: Ensuring minimum tables for stake", stake)
		ensure_minimum_tables(stake)
	print("Debug: TableManager initialization complete.")
	print("Debug: Tables initialized:", tables)

# Utility functions (defined first as they're used by other methods)
func generate_table_id(stake_level: int) -> String:
	var timestamp = Time.get_unix_time_from_system()
	return "table_%d_%d" % [stake_level, timestamp]

func find_stake_level_for_table(table_id: String) -> int:
	for stake_level in tables.keys():
		if tables[stake_level].has(table_id):
			return stake_level
	return -1

func get_table_data(table_id: String) -> Dictionary:
	var stake_level = find_stake_level_for_table(table_id)
	if stake_level != -1:
		return tables[stake_level][table_id]
	return {}

func has_active_players(table: Dictionary) -> bool:
	return count_active_players(table) > 0

func count_active_players(table: Dictionary) -> int:
	var count = 0
	for player in table.players:
		if player != null:
			count += 1
	return count

func calculate_rake(pot_amount: int) -> int:
	if pot_amount <= 0:
		return 0
	
	# Calculate 10% rake
	var rake = int(pot_amount * 0.1)
	return rake

# Core table management functions
func ensure_minimum_tables(stake_level: int) -> void:
	print("Debug: Ensuring minimum tables for stake level", stake_level)
	if not tables.has(stake_level):
		tables[stake_level] = {}
		print("Debug: Created tables dictionary for stake level", stake_level)
	
	var active_tables = get_active_tables(stake_level)
	print("Debug: Current active tables for stake", stake_level, ":", active_tables.size())
	while active_tables.size() < MIN_TABLES_PER_STAKE:
		create_table(stake_level)
		active_tables = get_active_tables(stake_level)
	print("Debug: Final active tables for stake", stake_level, ":", active_tables.size())

func create_table(stake_level: int) -> Dictionary:
	print("\nDebug: Creating new table for stake level", stake_level)
	var table_id = generate_table_id(stake_level)
	print("Debug: Generated table ID:", table_id)
	var table_data = {
		"id": table_id,
		"stake_level": stake_level,
		"players": [],
		"active_hand": false,
		"creation_time": Time.get_unix_time_from_system(),
		"last_activity": Time.get_unix_time_from_system(),
		"dealer_position": 0,
		"current_pot": 0,
		"current_bet": 0,
		"min_buyin": stake_level * 100,  # 100 big blinds minimum
		"max_buyin": stake_level * 200,  # 200 big blinds maximum
		"community_cards": [],
		"current_round": "preflop",
		"action_on": -1,
		"side_pots": [],
		"hand_number": 0,
		"waiting_players": [],
		"rake_eligible": false,
		"total_rake": 0,
		"hand_rake": 0,
		"main_pot_before_rake": 0,
		"side_pots_before_rake": []
	}
	
	# Initialize empty seats
	for i in range(MAX_PLAYERS):
		table_data.players.append(null)
	
	if not tables.has(stake_level):
		tables[stake_level] = {}
	
	tables[stake_level][table_id] = table_data
	emit_signal("table_created", table_id, stake_level)
	emit_signal("tables_updated")
	
	print("Debug: Created new table ", table_id, " at stake level ", stake_level)
	return table_data

func close_table(stake_level: int, table_id: String) -> void:
	if tables.has(stake_level) and tables[stake_level].has(table_id):
		var table = tables[stake_level][table_id]
		if not has_active_players(table):
			tables[stake_level].erase(table_id)
			emit_signal("table_closed", table_id)
			emit_signal("tables_updated")
			ensure_minimum_tables(stake_level)
			print("Debug: Closed table ", table_id, " at stake level ", stake_level)

func get_active_tables(stake_level: int) -> Array:
	print("Debug: Getting active tables for stake level", stake_level)
	if not tables.has(stake_level):
		print("Debug: No tables found for stake level", stake_level)
		return []
	var active = tables[stake_level].values()
	print("Debug: Found", active.size(), "active tables")
	return active

# Player management functions
func find_optimal_table(stake_level: int, player_data: Dictionary) -> Dictionary:
	print("\nDebug: Finding optimal table for stake level ", stake_level)
	print("Debug: Current tables for stake level:", tables.get(stake_level, {}).size())
	
	if not tables.has(stake_level):
		print("Debug: No tables found for stake level - creating new tables")
		ensure_minimum_tables(stake_level)
	
	var active_tables = get_active_tables(stake_level)
	if active_tables.is_empty():
		print("Debug: No active tables found - creating new table")
		return create_table(stake_level)
	
	# First, try to find a table with players but available seats
	var best_table = null
	var best_player_count = MAX_PLAYERS
	
	print("Debug: Searching through", active_tables.size(), "active tables")
	for table in active_tables:
		var player_count = count_active_players(table)
		print("Debug: Table", table.id, "has", player_count, "players")
		if player_count > 0 and player_count < MAX_PLAYERS and player_count < best_player_count:
			best_table = table
			best_player_count = player_count
			print("Debug: Found better table with", player_count, "players")
	
	# If no suitable table found, create a new one or use an empty table
	if not best_table:
		print("Debug: No suitable table found with players")
		if active_tables.size() >= MIN_TABLES_PER_STAKE:
			print("Debug: Creating new table as all existing tables are full")
			best_table = create_table(stake_level)
		else:
			print("Debug: Using first available table")
			best_table = active_tables[0]
	
	print("Debug: Selected table", best_table.id, "with", count_active_players(best_table), "players")
	return best_table

func seat_player(table_id: String, player_data: Dictionary) -> int:
	var stake_level = find_stake_level_for_table(table_id)
	if stake_level == -1:
		push_error("Table not found: " + table_id)
		return -1
	
	var table = tables[stake_level][table_id]
	
	# Add missing fields to player data
	var complete_player_data = player_data.duplicate()
	complete_player_data.merge({
		"bet": 0,
		"folded": false,
		"sitting_out": false,
		"cards": [],
		"auto_post_blinds": true,
		"last_action": "",
		"last_action_amount": 0,
		"time_bank": 30.0,
		"had_turn_this_round": false  # Add this field
	})
	
	# Find first available seat
	for i in range(table.players.size()):
		if table.players[i] == null:
			table.players[i] = complete_player_data
			table.last_activity = Time.get_unix_time_from_system()
			emit_signal("player_seated", table_id, i, complete_player_data)
			emit_signal("tables_updated")
			print("Debug: Seated player at table ", table_id, " seat ", i)
			return i
	
	push_error("No available seats at table " + table_id)
	return -1

func remove_player(table_id: String, seat_index: int) -> void:
	var stake_level = find_stake_level_for_table(table_id)
	if stake_level == -1:
		push_error("Table not found: " + table_id)
		return
	
	var table = tables[stake_level][table_id]
	if seat_index >= 0 and seat_index < table.players.size():
		table.players[seat_index] = null
		table.last_activity = Time.get_unix_time_from_system()
		emit_signal("player_left", table_id, seat_index)
		emit_signal("tables_updated")
		
		# Check if table should be closed
		if not has_active_players(table):
			close_table(stake_level, table_id)
		
		print("Debug: Removed player from table ", table_id, " seat ", seat_index)

# Game state management functions
func start_new_hand(table_id: String) -> void:
	print("DEBUG: Starting new hand for table ", table_id)
	var table = get_table_data(table_id)
	if table.is_empty():
		push_error("Table not found: " + table_id)
		return
	
	# Create new deck and deal cards
	var deck = []
	_initialize_deck(deck)
	_shuffle_deck(deck)
	print("DEBUG: Deck initialized and shuffled")
	
	# Reset hand state
	table.active_hand = true
	table.current_pot = 0
	table.current_bet = 0
	table.community_cards.clear()
	table.current_round = "preflop"
	table.hand_number += 1
	table.side_pots.clear()
	
	# Reset rake-related fields
	table.rake_eligible = false
	table.hand_rake = 0
	table.main_pot_before_rake = 0
	table.side_pots_before_rake.clear()
	
	# Move dealer button
	if table.hand_number == 1:
		# First hand, randomly assign dealer
		table.dealer_position = randi() % table.players.size()
	else:
		# Move button to next active player
		table.dealer_position = find_next_active_seat(table, table.dealer_position)
	print("DEBUG: Dealer position set to ", table.dealer_position)
	
	# Reset player states and deal cards
	for i in range(table.players.size()):
		var player = table.players[i]
		if player != null:
			player.bet = 0
			player.folded = false
			player.cards = []  # Clear previous cards
			player.last_action = ""
			player.last_action_amount = 0
			player.had_turn_this_round = false  # Reset turn tracking
			
			# Deal two cards to active player
			if player.chips > 0:
				print("DEBUG: Dealing cards to player ", i)
				player.cards = [_deal_card(deck), _deal_card(deck)]
	
	# Post blinds
	post_blinds(table)
	print("DEBUG: Blinds posted")
	
	# Set first action
	table.action_on = find_next_active_player(table, (table.dealer_position + 3) % table.players.size())
	print("DEBUG: First action set to ", table.action_on)
	
	table.action_on = find_first_actor(table)
	print("DEBUG: First action set to ", table.action_on)
	
	# If first actor is a bot, trigger their action
	if table.action_on != -1 and is_bot_turn(table):
		print("DEBUG: First actor is bot, triggering bot action")
		handle_bot_turn(table)
	
	table.last_activity = Time.get_unix_time_from_system()
	emit_signal("tables_updated")

func _initialize_deck(deck: Array) -> void:
	var suits = ["hearts", "diamonds", "clubs", "spades"]
	var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
	
	for suit in suits:
		for rank in ranks:
			deck.append({"rank": rank, "suit": suit})

func _shuffle_deck(deck: Array) -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = deck[i]
		deck[i] = deck[j]
		deck[j] = temp

func _deal_card(deck: Array) -> Dictionary:
	if deck.size() > 0:
		return deck.pop_back()
	push_error("Attempted to deal from empty deck")
	return {"rank": "2", "suit": "hearts"}  # Default card if deck is empty

func find_next_active_seat(table: Dictionary, current_position: int) -> int:
	var next_position = (current_position + 1) % table.players.size()
	var start_position = next_position
	
	while true:
		if table.players[next_position] != null and table.players[next_position].chips > 0:
			return next_position
		next_position = (next_position + 1) % table.players.size()
		if next_position == start_position:
			break
	
	return current_position  # Return current position if no other active seats found

func post_blinds(table: Dictionary) -> void:
	var small_blind_pos = find_next_active_seat(table, table.dealer_position)
	var big_blind_pos = find_next_active_seat(table, small_blind_pos)
	
	# Post small blind
	if table.players[small_blind_pos].chips > 0:
		var sb_amount = min(table.stake_level / 2, table.players[small_blind_pos].chips)
		table.players[small_blind_pos].chips -= sb_amount
		table.players[small_blind_pos].bet = sb_amount
	
	# Post big blind
	if table.players[big_blind_pos].chips > 0:
		var bb_amount = min(table.stake_level, table.players[big_blind_pos].chips)
		table.players[big_blind_pos].chips -= bb_amount
		table.players[big_blind_pos].bet = bb_amount
		table.current_bet = bb_amount
	
	print("DEBUG: Blinds posted - SB: ", small_blind_pos, ", BB: ", big_blind_pos)

func find_next_active_player(table: Dictionary, start_position: int) -> int:
	print("DEBUG: Finding next active player from position ", start_position)
	var num_players = table.players.size()
	var current_pos = start_position
	
	# First, check if we have enough active players to continue
	var active_count = 0
	var non_allin_count = 0
	for i in range(num_players):
		if table.players[i] != null and not table.players[i].folded:
			active_count += 1
			if table.players[i].chips > 0:
				non_allin_count += 1
	
	print("DEBUG: Active players: ", active_count, ", Non-all-in players: ", non_allin_count)
	
	# If only one player is not folded, or all active players are all-in
	if active_count <= 1 or non_allin_count == 0:
		print("DEBUG: No eligible players to act")
		return -1
	
	# Look for next active player
	for _i in range(num_players):
		current_pos = (current_pos + 1) % num_players
		var player = table.players[current_pos]
		if player != null and not player.folded and player.chips > 0:
			print("DEBUG: Found next active player at position ", current_pos)
			return current_pos
	
	print("DEBUG: No eligible player found, returning -1")
	return -1

func process_pot_with_rake(table_id: String) -> Dictionary:
	var table_data = get_table_data(table_id)
	if table_data.is_empty():
		return {}
		
	var result = {
		"main_pot": 0,
		"side_pots": [],
		"total_rake": 0
	}
	
	# Only apply rake if the hand reached the flop
	if not table_data.rake_eligible:
		result.main_pot = table_data.current_pot
		result.side_pots = table_data.side_pots.duplicate()
		return result
	
	# Calculate rake for main pot
	var main_pot_rake = calculate_rake(table_data.current_pot)
	result.main_pot = table_data.current_pot - main_pot_rake
	result.total_rake += main_pot_rake
	
	# Calculate rake for each side pot
	for side_pot in table_data.side_pots:
		var side_pot_rake = calculate_rake(side_pot.amount)
		var raked_side_pot = side_pot.duplicate()
		raked_side_pot.amount -= side_pot_rake
		result.side_pots.append(raked_side_pot)
		result.total_rake += side_pot_rake
	
	# Update table rake statistics
	table_data.hand_rake = result.total_rake
	table_data.total_rake += result.total_rake
	
	return result

func enter_flop_betting_round(table_id: String) -> void:
	var table_data = get_table_data(table_id)
	if table_data.is_empty():
		return
	
	# Mark hand as rake-eligible when reaching flop
	table_data.rake_eligible = true
	table_data.current_round = "flop"
	
	# Store pre-rake pot amounts
	table_data.main_pot_before_rake = table_data.current_pot
	table_data.side_pots_before_rake = table_data.side_pots.duplicate()
	
	emit_signal("tables_updated")

func get_rake_statistics(table_id: String) -> Dictionary:
	var table_data = get_table_data(table_id)
	if table_data.is_empty():
		return {}
	
	return {
		"total_rake": table_data.total_rake,
		"current_hand_rake": table_data.hand_rake,
		"rake_eligible": table_data.rake_eligible
	}

# Table state query functions
func is_seat_available(table_id: String, seat_index: int) -> bool:
	var table_data = get_table_data(table_id)
	if table_data.is_empty() or seat_index < 0 or seat_index >= MAX_PLAYERS:
		return false
	return table_data.players[seat_index] == null

func get_available_seats(table_id: String) -> Array:
	var available_seats = []
	var table_data = get_table_data(table_id)
	if not table_data.is_empty():
		for i in range(table_data.players.size()):
			if table_data.players[i] == null:
				available_seats.append(i)
	return available_seats

func get_player_count(table_id: String) -> int:
	var table_data = get_table_data(table_id)
	if table_data.is_empty():
		return 0
	return count_active_players(table_data)

func can_player_join(table_id: String, player_data: Dictionary) -> bool:
	var table_data = get_table_data(table_id)
	if table_data.is_empty():
		return false
		
	# Check if player has sufficient chips for minimum buyin
	if player_data.get("chips", 0) < table_data.min_buyin:
		return false
		
	# Check if there are any available seats
	return get_available_seats(table_id).size() > 0

func add_waiting_player(table_id: String, player_data: Dictionary) -> bool:
	var table_data = get_table_data(table_id)
	if table_data.is_empty():
		return false
		
	# Verify player has sufficient chips for minimum buyin
	if player_data.get("chips", 0) < table_data.min_buyin:
		return false
		
	table_data.waiting_players.append(player_data)
	return true

func set_hand_active(table_id: String, active: bool) -> void:
	var table_data = get_table_data(table_id)
	if not table_data.is_empty():
		table_data.active_hand = active
		table_data.last_activity = Time.get_unix_time_from_system()

func process_player_action(table_id: String, seat_index: int, action: String, amount: int = 0) -> bool:
	print("\nDEBUG: Processing player action")
	print("- Table ID: ", table_id)
	print("- Seat Index: ", seat_index)
	print("- Action: ", action)
	print("- Amount: ", amount)
	
	var table = get_table_data(table_id)
	if table.is_empty() or table.action_on != seat_index:
		return false
	
	var player = table.players[seat_index]
	if player == null or player.folded:
		return false
	
	# Process the action
	var success = false
	
	match action:
		"fold":
			print("DEBUG: Processing fold")
			player.folded = true
			player.last_action = "fold"
			success = true
			
		"call":
			print("DEBUG: Processing call/check")
			if table.current_bet == player.bet:
				print("DEBUG: This is a check")
				player.last_action = "check"
				success = true
			else:
				var call_amount = table.current_bet - player.bet
				if call_amount > player.chips:
					call_amount = player.chips
					handle_all_in(table, seat_index)
				player.chips -= call_amount
				player.bet += call_amount
				player.last_action = "call"
				player.last_action_amount = call_amount
				success = true
				
		"raise":
			print("DEBUG: Processing raise")
			if amount <= player.chips + player.bet:
				var raise_amount = amount - player.bet
				player.chips -= raise_amount
				player.bet = amount
				table.current_bet = amount
				player.last_action = "raise"
				player.last_action_amount = raise_amount
				success = true
	
	if success:
		handle_post_action(table)
		
		# Check if next player is a bot and trigger their action
		if is_bot_turn(table):
			print("DEBUG: Bot turn detected, triggering bot action")
			handle_bot_turn(table)
	
	return success

func validate_action(table: Dictionary, seat_index: int, action: String, amount: int) -> bool:
	if table.action_on != seat_index:
		return false
	
	var player = table.players[seat_index]
	if player == null or player.folded:
		return false
	
	match action:
		"fold":
			return true
		"call":
			var call_amount = table.current_bet - player.bet
			return call_amount <= player.chips
		"raise":
			var min_raise = table.stake_level  # 1 BB minimum raise
			var total_bet = player.bet + amount
			# Must be at least min_raise more than current bet
			return total_bet >= table.current_bet + min_raise and amount <= player.chips
	
	return false

func handle_all_in(table: Dictionary, seat_index: int) -> void:
	# Create potential side pot
	var all_in_amount = table.players[seat_index].chips + table.players[seat_index].bet
	var side_pot = {
		"amount": 0,
		"participants": []
	}
	
	# Calculate side pot contributions
	for i in range(table.players.size()):
		var other_player = table.players[i]
		if other_player != null and not other_player.folded and i != seat_index:
			if other_player.bet > all_in_amount:
				var excess = other_player.bet - all_in_amount
				other_player.bet = all_in_amount
				other_player.chips += excess  # Return excess chips
				side_pot.amount += excess
				side_pot.participants.append(i)
	
	if side_pot.amount > 0:
		table.side_pots.append(side_pot)

func handle_post_action(table: Dictionary) -> void:
	print("\nDEBUG: Handling post-action")
	print("- Current round: ", table.current_round)
	print("- Current pot: ", table.current_pot)
	print("- Current bet: ", table.current_bet)
	
	# Mark current player as having acted this round
	var current_player = table.players[table.action_on]
	current_player.had_turn_this_round = true
	
	# Find next player to act
	var next_player_index = find_next_actor(table)
	print("- Next player to act: ", next_player_index)
	
	# First, check if there's only one player left
	var active_players = []
	var total_players = 0
	for i in range(table.players.size()):
		var player = table.players[i]
		if player != null:
			total_players += 1
			if not player.folded:
				active_players.append(i)
	
	# If only one player left, they win all bets and the pot
	if active_players.size() == 1:
		print("DEBUG: Only one player remains - awarding pot")
		# Collect any outstanding bets first
		for player in table.players:
			if player != null and player.bet > 0:
				table.current_pot += player.bet
				player.bet = 0
		# Award pot to remaining player
		award_pot_to_player(table, active_players[0])
		prepare_next_hand(table)
		return
	
	# Normal round completion check
	var round_complete = (next_player_index == -1)
	if not round_complete:
		# Check if all non-folded players have acted and matched the bet
		var all_bets_matched = true
		for player in table.players:
			if player != null and not player.folded and player.chips > 0:
				if player.bet < table.current_bet or not player.had_turn_this_round:
					all_bets_matched = false
					break
		round_complete = all_bets_matched
	
	print("- Round complete: ", round_complete)
	
	if round_complete:
		# Move to next betting round
		print("DEBUG: Moving to next betting round")
		next_betting_round(table)
	else:
		# Continue current betting round
		table.action_on = next_player_index
		print("DEBUG: Continuing betting round, action on: ", table.action_on)
	
	emit_signal("tables_updated")

func find_next_actor(table: Dictionary) -> int:
	var start_pos = (table.action_on + 1) % table.players.size()
	var current_pos = start_pos
	
	# First, count active players
	var active_count = 0
	for player in table.players:
		if player != null and not player.folded and player.chips > 0:
			active_count += 1
	
	# If only one player remains active, no more actions needed
	if active_count <= 1:
		return -1
	
	# Find next eligible player
	while current_pos != table.action_on:
		var player = table.players[current_pos]
		if player != null and not player.folded and player.chips > 0:
			if player.bet < table.current_bet or not player.had_turn_this_round:
				return current_pos
		current_pos = (current_pos + 1) % table.players.size()
	
	# If we get here, betting round is complete
	return -1

func should_continue_hand(table: Dictionary) -> bool:
	var active_players = 0
	for player in table.players:
		if player != null and not player.folded:
			active_players += 1
	
	return active_players > 1 and table.current_round != "river"

func next_betting_round(table: Dictionary) -> void:
	print("\nDEBUG: Moving to next betting round")
	
	# Move all bets to the pot
	var total_bets = 0
	for player in table.players:
		if player != null:
			total_bets += player.bet
			player.bet = 0
			player.had_turn_this_round = false
	
	table.current_pot += total_bets
	table.current_bet = 0
	
	print("- Previous round: ", table.current_round)
	print("- Current pot: ", table.current_pot)

	# Check if we're in an all-in situation
	var is_allin_situation = is_all_in_situation(table)
	print("DEBUG: All-in situation: ", is_allin_situation)
	
	# Create a new deck if we don't have one
	var deck = []
	_initialize_deck(deck)
	_shuffle_deck(deck)
	
	# If it's an all-in situation, we'll deal all remaining streets
	if is_allin_situation:
		match table.current_round:
			"preflop":
				print("DEBUG: All-in - dealing all streets")
				# Deal flop
				table.current_round = "flop"
				for i in range(3):
					var card = _deal_card(deck)
					print("- Dealt flop: ", card.rank, " of ", card.suit)
					table.community_cards.append(card)
				emit_signal("tables_updated")
				await get_tree().create_timer(1.0).timeout # Delay for suspense
				
				# Deal turn
				table.current_round = "turn"
				var turn_card = _deal_card(deck)
				print("- Dealt turn: ", turn_card.rank, " of ", turn_card.suit)
				table.community_cards.append(turn_card)
				emit_signal("tables_updated")
				await get_tree().create_timer(1.0).timeout # Delay for suspense
				
				# Deal river
				table.current_round = "river"
				var river_card = _deal_card(deck)
				print("- Dealt river: ", river_card.rank, " of ", river_card.suit)
				table.community_cards.append(river_card)
				emit_signal("tables_updated")
				await get_tree().create_timer(1.0).timeout # Delay for suspense
				
				handle_showdown(table)
				return
				
			"flop":
				print("DEBUG: All-in - dealing turn and river")
				# Deal turn
				table.current_round = "turn"
				var turn_card = _deal_card(deck)
				print("- Dealt turn: ", turn_card.rank, " of ", turn_card.suit)
				table.community_cards.append(turn_card)
				emit_signal("tables_updated")
				await get_tree().create_timer(1.0).timeout # Delay for suspense
				
				# Deal river
				table.current_round = "river"
				var river_card = _deal_card(deck)
				print("- Dealt river: ", river_card.rank, " of ", river_card.suit)
				table.community_cards.append(river_card)
				emit_signal("tables_updated")
				await get_tree().create_timer(1.0).timeout # Delay for suspense
				
				handle_showdown(table)
				return
				
			"turn":
				print("DEBUG: All-in - dealing river")
				# Deal river
				table.current_round = "river"
				var river_card = _deal_card(deck)
				print("- Dealt river: ", river_card.rank, " of ", river_card.suit)
				table.community_cards.append(river_card)
				emit_signal("tables_updated")
				await get_tree().create_timer(1.0).timeout # Delay for suspense
				
				handle_showdown(table)
				return
	
	# Normal (non all-in) round progression
	match table.current_round:
		"preflop":
			print("DEBUG: Dealing flop")
			table.current_round = "flop"
			# Deal three flop cards
			for i in range(3):
				var card = _deal_card(deck)
				print("- Dealt: ", card.rank, " of ", card.suit)
				table.community_cards.append(card)
			enter_flop_betting_round(table.id)  # Mark hand as rake-eligible
			
		"flop":
			print("DEBUG: Dealing turn")
			table.current_round = "turn"
			# Deal turn card
			var card = _deal_card(deck)
			print("- Dealt: ", card.rank, " of ", card.suit)
			table.community_cards.append(card)
			
		"turn":
			print("DEBUG: Dealing river")
			table.current_round = "river"
			# Deal river card
			var card = _deal_card(deck)
			print("- Dealt: ", card.rank, " of ", card.suit)
			table.community_cards.append(card)
			
		"river":
			print("DEBUG: Moving to showdown")
			handle_showdown(table)
			return
	
	# Find first player to act (first active player after dealer)
	table.action_on = find_first_actor(table)
	print("- Next round: ", table.current_round)
	print("- First to act: ", table.action_on)
	print("- Community cards: ", table.community_cards.size())
	
	emit_signal("tables_updated")

# Helper function to check if we're in an all-in situation
func is_all_in_situation(table: Dictionary) -> bool:
	var active_non_allin_count = 0
	var total_active = 0
	
	for player in table.players:
		if player != null and not player.folded:
			total_active += 1
			if player.chips > 0:  # Player still has chips to bet
				active_non_allin_count += 1
	
	# It's an all-in situation if:
	# 1. We have at least 2 active players (not folded)
	# 2. No more than 1 of them has chips left to bet
	return total_active >= 2 and active_non_allin_count <= 1

func find_first_actor(table: Dictionary) -> int:
	# For preflop, first action is after BB (UTG position)
	if table.current_round == "preflop":
		# Find BB position (2 seats after dealer)
		var bb_pos = table.dealer_position
		for _i in range(2):
			bb_pos = find_next_active_seat(table, bb_pos)
		# First actor is after BB
		var first_actor = find_next_active_seat(table, bb_pos)
		print("DEBUG: Preflop first actor (UTG): ", first_actor)
		return first_actor
	
	# After preflop, first active player after dealer acts first
	var start_pos = table.dealer_position
	var current_pos = start_pos
	
	# Find first active player after dealer
	while true:
		current_pos = find_next_active_seat(table, current_pos)
		var player = table.players[current_pos]
		if player != null and not player.folded and player.chips > 0:
			return current_pos
		if current_pos == start_pos:
			break
	
	return -1  # Should never reach here if hand is still active

func deal_card(table: Dictionary) -> Dictionary:
	var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
	var suits = ["hearts", "diamonds", "clubs", "spades"]
	
	var attempts = 0
	var max_attempts = 100  # Prevent infinite loop
	
	while attempts < max_attempts:
		var card = {
			"rank": ranks[randi() % ranks.size()],
			"suit": suits[randi() % suits.size()]
		}
		
		# Check if card is already in use
		var card_in_use = false
		
		# Check community cards
		for community_card in table.community_cards:
			if community_card.rank == card.rank and community_card.suit == card.suit:
				card_in_use = true
				break
		
		# Check player hands
		if not card_in_use:
			for player in table.players:
				if player != null:
					for player_card in player.cards:
						if player_card.rank == card.rank and player_card.suit == card.suit:
							card_in_use = true
							break
					if card_in_use:
						break
		
		if not card_in_use:
			return card
			
		attempts += 1
	
	# If we couldn't find an unused card after max attempts, return a default card
	# This should never happen in practice but ensures we always return something
	push_error("Could not find unused card after " + str(max_attempts) + " attempts")
	return {
		"rank": "2",
		"suit": "hearts"
	}

func handle_showdown(table: Dictionary) -> void:
	print("\nDEBUG: Handling showdown")
	print("- Current pot: ", table.current_pot)
	print("- Active players: ", get_active_player_count(table))
	
	# If there's only one player left, they win automatically
	var active_players = []
	for i in range(table.players.size()):
		var player = table.players[i]
		if player != null and not player.folded:
			active_players.append(i)
	
	# Collect any remaining bets to pot
	for player in table.players:
		if player != null and player.bet > 0:
			table.current_pot += player.bet
			player.bet = 0
	
	# Calculate side pots for all-in players
	calculate_final_side_pots(table)
	print("- Side pots created: ", table.side_pots.size())
	
	# Apply rake
	var pot_results = process_pot_with_rake(table.id)
	print("- Rake applied. Main pot: ", pot_results.main_pot)
	
	if active_players.size() == 1:
		print("DEBUG: Single player remaining - auto-win")
		var winner_index = active_players[0]
		
		# Emit winner info first
		var winner_info = {
			"winner_index": winner_index,
			"hand_description": "All other players folded",
			"pot_amount": table.current_pot
		}
		print("DEBUG: Emitting winner info")
		emit_signal("hand_completed", table.id, winner_info)
		
		# Then award pot
		award_pot_to_player(table, winner_index)
		
		# Update server balance for human player
		var winner = table.players[winner_index]
		if winner != null and not winner.get("is_bot", false):
			APIManager.update_server_balance(winner.chips)
			
		prepare_next_hand(table)
		return
	
	# For main pot
	if active_players.size() > 0:
		var winners = find_winners(table, active_players)
		print("- Main pot winners: ", winners.size())
		var share = pot_results.main_pot / winners.size()
		
		for winner_index in winners:
			var winner_hand = evaluate_hand(table.players[winner_index].cards, table.community_cards)
			var winner_info = {
				"winner_index": winner_index,
				"hand_description": hand_to_string(winner_hand),
				"pot_amount": share
			}
			print("DEBUG: Emitting winner info")
			emit_signal("hand_completed", table.id, winner_info)
			award_pot_to_player(table, winner_index, share)
			
			# Update server balance for human winners
			var winner = table.players[winner_index]
			if winner != null and not winner.get("is_bot", false):
				APIManager.update_server_balance(winner.chips)
	
	prepare_next_hand(table)

func find_winners(table: Dictionary, eligible_players: Array) -> Array:
	print("\nDEBUG: Finding winners among ", eligible_players.size(), " players")
	var winners = []
	var best_hand = null
	var best_hand_value = null
	
	for player_index in eligible_players:
		var player = table.players[player_index]
		if player == null or player.folded:
			continue
		
		var hand = evaluate_hand(player.cards, table.community_cards)
		print("- Player ", player_index, " hand: ", hand_to_string(hand))
		
		if best_hand == null:
			best_hand = hand
			best_hand_value = hand.values
			winners = [player_index]
		else:
			var comparison = compare_hands(hand, best_hand)
			if comparison > 0:  # New best hand
				best_hand = hand
				best_hand_value = hand.values
				winners = [player_index]
			elif comparison == 0:  # Tie
				winners.append(player_index)
	
	print("- Winners found: ", winners)
	return winners

func hand_to_string(hand: Dictionary) -> String:
	var rank_names = {
		HandRank.HIGH_CARD: "High Card",
		HandRank.PAIR: "Pair",
		HandRank.TWO_PAIR: "Two Pair",
		HandRank.THREE_OF_A_KIND: "Three of a Kind",
		HandRank.STRAIGHT: "Straight",
		HandRank.FLUSH: "Flush",
		HandRank.FULL_HOUSE: "Full House",
		HandRank.FOUR_OF_A_KIND: "Four of a Kind",
		HandRank.STRAIGHT_FLUSH: "Straight Flush",
		HandRank.ROYAL_FLUSH: "Royal Flush"
	}
	
	return rank_names[hand.rank] + " (" + str(hand.values) + ")"

func get_active_player_count(table: Dictionary) -> int:
	var count = 0
	for player in table.players:
		if player != null and not player.folded:
			count += 1
	return count

func calculate_final_side_pots(table: Dictionary) -> void:
	# Sort players by their total chips committed (bet + already in pot)
	var committed_amounts = []
	for i in range(table.players.size()):
		var player = table.players[i]
		if player != null and not player.folded:
			committed_amounts.append({
				"index": i,
				"amount": player.bet
			})
	
	committed_amounts.sort_custom(func(a, b): return a.amount < b.amount)
	
	# Create side pots
	var previous_amount = 0
	for i in range(committed_amounts.size()):
		var current_amount = committed_amounts[i].amount
		if current_amount > previous_amount:
			var pot_amount = 0
			var pot_participants = []
			
			# Calculate contribution to this pot level
			for j in range(i, committed_amounts.size()):
				var contribution = current_amount - previous_amount
				pot_amount += contribution
				pot_participants.append(committed_amounts[j].index)
			
			if pot_amount > 0:
				if i == 0:
					table.current_pot += pot_amount
				else:
					table.side_pots.append({
						"amount": pot_amount,
						"participants": pot_participants.duplicate()
					})
			
			previous_amount = current_amount

func determine_winner(table: Dictionary, eligible_players: Array) -> int:
	var best_hand = null
	var winner_index = -1
	
	for player_index in eligible_players:
		var player = table.players[player_index]
		if player == null or player.folded:
			continue
		
		var hand_value = evaluate_hand(player.cards, table.community_cards)
		if best_hand == null or compare_hands(hand_value, best_hand) > 0:
			best_hand = hand_value
			winner_index = player_index
	
	return winner_index

func award_pot_to_player(table: Dictionary, winner_index: int, amount: int = -1) -> void:
	var winner = table.players[winner_index]
	if winner == null:
		return
	
	if amount == -1:
		amount = table.current_pot
		table.current_pot = 0
	
	winner.chips += amount
	table.last_activity = Time.get_unix_time_from_system()
	emit_signal("tables_updated")

func prepare_next_hand(table: Dictionary) -> void:
	# Reset hand state
	table.current_pot = 0
	table.current_bet = 0
	table.community_cards.clear()
	table.side_pots.clear()
	table.current_round = "preflop"
	table.action_on = -1
	table.rake_eligible = false
	table.hand_rake = 0
	
	# Check for players who need to leave (no chips)
	for i in range(table.players.size()):
		var player = table.players[i]
		if player != null and player.chips <= 0:
			remove_player(table.id, i)
	
	# If enough players remain, start new hand
	if count_active_players(table) >= 2:
		start_new_hand(table.id)
	else:
		table.active_hand = false

func evaluate_hand(hole_cards: Array, community_cards: Array) -> Dictionary:
	# Combine hole cards and community cards
	var all_cards = hole_cards + community_cards
	
	# Check for each hand type from highest to lowest
	var result = check_royal_flush(all_cards)
	if result: return result
	
	result = check_straight_flush(all_cards)
	if result: return result
	
	result = check_four_of_a_kind(all_cards)
	if result: return result
	
	result = check_full_house(all_cards)
	if result: return result
	
	result = check_flush(all_cards)
	if result: return result
	
	result = check_straight(all_cards)
	if result: return result
	
	result = check_three_of_a_kind(all_cards)
	if result: return result
	
	result = check_two_pair(all_cards)
	if result: return result
	
	result = check_pair(all_cards)
	if result: return result
	
	# If nothing else, return high card
	return check_high_card(all_cards)

func compare_hands(hand1: Dictionary, hand2: Dictionary) -> int:
	# Returns 1 if hand1 wins, -1 if hand2 wins, 0 if tie
	if hand1.rank > hand2.rank:
		return 1
	elif hand1.rank < hand2.rank:
		return -1
	
	# If same rank, compare values
	for i in range(hand1.values.size()):
		if hand1.values[i] > hand2.values[i]:
			return 1
		elif hand1.values[i] < hand2.values[i]:
			return -1
	
	return 0

# Helper functions for evaluate_hand
func check_royal_flush(cards: Array) -> Dictionary:
	var result = check_straight_flush(cards)
	if result and result.values[0] == 14:  # Ace-high straight flush
		return {"rank": HandRank.ROYAL_FLUSH, "values": result.values}
	return {}

func check_straight_flush(cards: Array) -> Dictionary:
	# Group cards by suit
	var suits = {}
	for card in cards:
		if not suits.has(card.suit):
			suits[card.suit] = []
		suits[card.suit].append(CARD_VALUES[card.rank])
	
	# Check each suit for a straight
	for suit_cards in suits.values():
		if suit_cards.size() >= 5:
			suit_cards.sort()
			var result = check_straight_in_values(suit_cards)
			if not result.is_empty():
				return {"rank": HandRank.STRAIGHT_FLUSH, "values": result.values}
	return {}

func check_four_of_a_kind(cards: Array) -> Dictionary:
	var ranks = {}
	for card in cards:
		var value = CARD_VALUES[card.rank]
		if not ranks.has(value):
			ranks[value] = 0
		ranks[value] += 1
		if ranks[value] == 4:
			# Find highest remaining card for kicker
			var kicker = 0
			for other_card in cards:
				var other_value = CARD_VALUES[other_card.rank]
				if other_value != value and other_value > kicker:
					kicker = other_value
			return {"rank": HandRank.FOUR_OF_A_KIND, "values": [value, kicker]}
	return {}

func check_full_house(cards: Array) -> Dictionary:
	var three_kind = null
	var pair = null
	var ranks = {}
	
	# Count occurrences of each rank
	for card in cards:
		var value = CARD_VALUES[card.rank]
		if not ranks.has(value):
			ranks[value] = 0
		ranks[value] += 1
	
	# Find highest three of a kind and highest pair
	for value in ranks:
		if ranks[value] == 3:
			if three_kind == null or value > three_kind:
				three_kind = value
		elif ranks[value] >= 2:
			if pair == null or value > pair:
				pair = value
	
	if three_kind != null and pair != null:
		return {"rank": HandRank.FULL_HOUSE, "values": [three_kind, pair]}
	return {}

func check_flush(cards: Array) -> Dictionary:
	var suits = {}
	for card in cards:
		if not suits.has(card.suit):
			suits[card.suit] = []
		suits[card.suit].append(CARD_VALUES[card.rank])
	
	for suit_cards in suits.values():
		if suit_cards.size() >= 5:
			suit_cards.sort()
			suit_cards.reverse()
			return {"rank": HandRank.FLUSH, "values": suit_cards.slice(0, 5)}
	return {}

func check_straight(cards: Array) -> Dictionary:
	var values = []
	for card in cards:
		values.append(CARD_VALUES[card.rank])
	values.sort()
	return check_straight_in_values(values)

func check_straight_in_values(values: Array) -> Dictionary:
	# Handle Ace-low straight (A,2,3,4,5)
	if values.has(14):  # If we have an Ace
		values.append(1)  # Add it as a 1 as well
	
	var current_run = 1
	var previous_value = values[0]
	var straight_high = values[0]
	
	for i in range(1, values.size()):
		if values[i] == previous_value:
			continue
		elif values[i] == previous_value + 1:
			current_run += 1
			if current_run >= 5:
				straight_high = values[i]
		else:
			current_run = 1
		previous_value = values[i]
	
	if current_run >= 5:
		return {"rank": HandRank.STRAIGHT, "values": [straight_high]}
	return {}

func check_three_of_a_kind(cards: Array) -> Dictionary:
	var ranks = {}
	for card in cards:
		var value = CARD_VALUES[card.rank]
		if not ranks.has(value):
			ranks[value] = 0
		ranks[value] += 1
		if ranks[value] == 3:
			# Find two highest remaining cards for kickers
			var kickers = []
			for other_card in cards:
				var other_value = CARD_VALUES[other_card.rank]
				if other_value != value:
					kickers.append(other_value)
			kickers.sort()
			kickers.reverse()
			return {"rank": HandRank.THREE_OF_A_KIND, "values": [value] + kickers.slice(0, 2)}
	return {}

func check_two_pair(cards: Array) -> Dictionary:
	var pairs = []
	var ranks = {}
	
	for card in cards:
		var value = CARD_VALUES[card.rank]
		if not ranks.has(value):
			ranks[value] = 0
		ranks[value] += 1
		if ranks[value] == 2:
			pairs.append(value)
	
	if pairs.size() >= 2:
		pairs.sort()
		pairs.reverse()
		# Find highest remaining card for kicker
		var kicker = 0
		for card in cards:
			var value = CARD_VALUES[card.rank]
			if value != pairs[0] and value != pairs[1] and value > kicker:
				kicker = value
		return {"rank": HandRank.TWO_PAIR, "values": [pairs[0], pairs[1], kicker]}
	return {}

func check_pair(cards: Array) -> Dictionary:
	var ranks = {}
	for card in cards:
		var value = CARD_VALUES[card.rank]
		if not ranks.has(value):
			ranks[value] = 0
		ranks[value] += 1
		if ranks[value] == 2:
			# Find three highest remaining cards for kickers
			var kickers = []
			for other_card in cards:
				var other_value = CARD_VALUES[other_card.rank]
				if other_value != value:
					kickers.append(other_value)
			kickers.sort()
			kickers.reverse()
			return {"rank": HandRank.PAIR, "values": [value] + kickers.slice(0, 3)}
	return {}

func check_high_card(cards: Array) -> Dictionary:
	var values = []
	for card in cards:
		values.append(CARD_VALUES[card.rank])
	values.sort()
	values.reverse()
	return {"rank": HandRank.HIGH_CARD, "values": values.slice(0, 5)}

func create_bot_player(table_id: String, seat_index: int) -> void:
	print("DEBUG: Creating bot for table ", table_id, " seat ", seat_index)
	var table = get_table_data(table_id)
	if table.is_empty():
		push_error("Table not found when creating bot")
		return
		
	var starting_chips = table.min_buyin
	var bot = Bot.new(seat_index, table_id, starting_chips)
	var bot_data = bot.get_player_data()
	
	print("DEBUG: Created bot with data: ", bot_data)
	table.players[seat_index] = bot_data
	table.last_activity = Time.get_unix_time_from_system()
	emit_signal("player_seated", table_id, seat_index, bot_data)
	emit_signal("tables_updated")
	
func fill_empty_seats_with_bots(table_id: String) -> void:
	print("DEBUG: Filling empty seats with bots for table ", table_id)
	var table = get_table_data(table_id)
	if table.is_empty():
		push_error("Table not found when filling bots")
		return
		
	# Fill all but one seat with bots (leave space for players)
	var bot_count = 0
	var max_bots = 4  # Leave 2 seats for human players
	
	for i in range(table.players.size()):
		if table.players[i] == null and bot_count < max_bots:
			print("DEBUG: Creating bot for empty seat ", i)
			create_bot_player(table_id, i)
			bot_count += 1
			await get_tree().create_timer(0.2).timeout
	
	print("DEBUG: Added ", bot_count, " bots to table")
	
	# If we added bots and there's a human player, start the hand
	if bot_count > 0 and has_human_player(table):
		print("DEBUG: Starting new hand after adding bots")
		start_new_hand(table_id)

func has_human_player(table: Dictionary) -> bool:
	for player in table.players:
		if player != null and not player.get("is_bot", false):
			return true
	return false

func is_bot_turn(table: Dictionary) -> bool:
	if table.action_on < 0 or table.action_on >= table.players.size():
		return false
	
	var current_player = table.players[table.action_on]
	return current_player != null and current_player.get("is_bot", false)

func handle_bot_turn(table: Dictionary) -> void:
	if not is_bot_turn(table):
		return
		
	print("DEBUG: Handling bot turn for seat ", table.action_on)
	var bot_seat = table.action_on
	var bot = Bot.new(bot_seat, table.id, table.players[bot_seat].chips)
	var decision = bot.make_decision(table)
	
	print("DEBUG: Bot decision: ", decision)
	
	# Add slight delay before bot acts
	await get_tree().create_timer(1.5).timeout
	
	# Only process action if it's still the bot's turn
	if table.action_on == bot_seat:
		process_player_action(table.id, bot_seat, decision.action, decision.get("amount", 0))
