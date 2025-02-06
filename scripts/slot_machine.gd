extends Node

signal spin_completed(result)
signal win_evaluated(result)

# Reel configuration
const REELS = 5
const ROWS = 3
const VIRTUAL_STOPS = 50

# Symbol configuration with weights
const SYMBOL_CONFIG = {
	"2": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"3": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"4": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"5": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"6": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"7": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"8": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"9": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"10": {"weight": 4, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"J": {"weight": 3, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"Q": {"weight": 3, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"K": {"weight": 3, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"A": {"weight": 2, "suits": ["hearts", "diamonds", "clubs", "spades"]},
	"JOKER": {"weight": 1, "suits": [""]}  # Jokers don't need suits
}

# Paylines configuration (for evaluating poker hands)
const PAYLINES = [
	# Horizontal lines
	[
		{"reel": 0, "row": 0}, {"reel": 1, "row": 0}, {"reel": 2, "row": 0},
		{"reel": 3, "row": 0}, {"reel": 4, "row": 0}
	],
	[
		{"reel": 0, "row": 1}, {"reel": 1, "row": 1}, {"reel": 2, "row": 1},
		{"reel": 3, "row": 1}, {"reel": 4, "row": 1}
	],
	[
		{"reel": 0, "row": 2}, {"reel": 1, "row": 2}, {"reel": 2, "row": 2},
		{"reel": 3, "row": 2}, {"reel": 4, "row": 2}
	],
	# V-shaped lines
	[
		{"reel": 0, "row": 0}, {"reel": 1, "row": 1}, {"reel": 2, "row": 2},
		{"reel": 3, "row": 1}, {"reel": 4, "row": 0}
	],
	[
		{"reel": 0, "row": 2}, {"reel": 1, "row": 1}, {"reel": 2, "row": 0},
		{"reel": 3, "row": 1}, {"reel": 4, "row": 2}
	]
]

# Payout configuration for poker hands (multipliers)
const PAYOUT_CONFIG = {
	"ROYAL_FLUSH": 20.0,
	"STRAIGHT_FLUSH": 15.0,
	"FOUR_OF_A_KIND": 10.0,
	"FULL_HOUSE": 4.0,
	"FLUSH": 3.0,
	"STRAIGHT": 2.0,
	"THREE_OF_A_KIND": 1.0,
	"TWO_PAIR": 0.0,
	"PAIR": 0.0,
	"HIGH_CARD": 0.0
}

var rng: CryptoRNG
var reels = []  # Array of arrays representing each reel's symbols
var current_symbols = []  # Currently visible symbols
var bet_amount = 0.0
var total_win = 0.0
var line_payout = 0.0
var ai_symbols = []
var ai_best_hand = null
var ai_winning_payline = null

func _ready():
	rng = CryptoRNG.new()
	_initialize_reels()

func _initialize_reels():
	reels.clear()

	# Create each reel
	for _i in range(REELS):
		var reel_symbols = []
		var symbol_pool = _generate_symbol_pool()

		# Fill reel with symbols according to virtual stops
		for _j in range(VIRTUAL_STOPS):
			var symbol = symbol_pool[rng.get_random_int(symbol_pool.size() - 1)]
			var suit = _get_random_suit(symbol)
			reel_symbols.append({"symbol": symbol, "suit": suit})

		reels.append(reel_symbols)

func _generate_symbol_pool() -> Array:
	var pool = []
	for symbol in SYMBOL_CONFIG:
		for _i in range(SYMBOL_CONFIG[symbol].weight):
			pool.append(symbol)
	return pool

func _get_random_suit(symbol: String) -> String:
	if symbol == "JOKER":
		return ""
	var suits = SYMBOL_CONFIG[symbol].suits
	return suits[rng.get_random_int(suits.size() - 1)]

func start_spin(bet_amount: float) -> void:
	self.bet_amount = bet_amount
	current_symbols = []
	ai_symbols = []

	# Generate symbols for each reel
	for _i in range(REELS):
		var reel = reels[_i]
		var start_index = rng.get_random_int(VIRTUAL_STOPS - 1)
		var visible = []
		var ai_visible = []

		for row in range(ROWS):
			var symbol_index = (start_index + row) % VIRTUAL_STOPS
			visible.append(reel[symbol_index])
			ai_visible.append(reel[(symbol_index + rng.get_random_int(VIRTUAL_STOPS - 1)) % VIRTUAL_STOPS])

		current_symbols.append(visible)
		ai_symbols.append(ai_visible)

	var result = _evaluate_spin()
	emit_signal("spin_completed", result)

func _evaluate_spin() -> Dictionary:
	var wins = []
	var total_win = 0.0
	var bet_per_line = bet_amount / PAYLINES.size()
	
	# Initialize player's best hand
	var player_best_hand = null

	# Evaluate player's hands
	for payline in PAYLINES:
		var hand = []
		for pos in payline:
			hand.append(current_symbols[pos["reel"]][pos["row"]])
		
		var hand_result = _evaluate_poker_hand(hand)
		if hand_result["payout"] > 0:
			# Calculate the win amount correctly using PAYOUT_CONFIG
			var payout_multiplier = PAYOUT_CONFIG[hand_result["hand_type"]]
			var line_payout = bet_amount * payout_multiplier  # Use full bet amount for each winning hand
			
			wins.append({
				"payline": payline,
				"hand_type": hand_result["hand_type"],
				"payout": line_payout,
				"winning_positions": payline,
				"hand_rank_value": hand_result["hand_rank_value"]
			})
			total_win += line_payout
			
			# Track player's best hand
			if !player_best_hand or hand_result["hand_rank_value"] > player_best_hand["hand_rank_value"]:
				player_best_hand = hand_result.duplicate()
				player_best_hand["winning_positions"] = payline.duplicate(true)

	# Evaluate AI's best hand
	var ai_best_hand = null
	var ai_winning_payline = null
	
	for payline in PAYLINES:
		var hand = []
		for pos in payline:
			hand.append(ai_symbols[pos["reel"]][pos["row"]])
		
		var hand_result = _evaluate_poker_hand(hand)
		if !ai_best_hand or hand_result["hand_rank_value"] > ai_best_hand["hand_rank_value"]:
			ai_best_hand = hand_result.duplicate()
			ai_best_hand["winning_positions"] = payline.duplicate(true)
			
			print("DEBUG: New best AI hand found:")
			print("- Type:", hand_result["hand_type"])
			print("- Value:", hand_result["hand_rank_value"])
			print("- Positions:", payline)

	# Define hand type rankings
	var hand_type_rankings = {
		"HIGH_CARD": 0,
		"PAIR": 1,
		"TWO_PAIR": 2,
		"THREE_OF_A_KIND": 3,
		"STRAIGHT": 4,
		"FLUSH": 5,
		"FULL_HOUSE": 6,
		"FOUR_OF_A_KIND": 7,
		"STRAIGHT_FLUSH": 8,
		"ROYAL_FLUSH": 9
	}

	# Compare hands to determine if player wins
	var player_beats_ai = false
	if player_best_hand and ai_best_hand:
		var player_hand_rank = hand_type_rankings[player_best_hand["hand_type"]]
		var ai_hand_rank = hand_type_rankings[ai_best_hand["hand_type"]]
		
		if player_hand_rank > ai_hand_rank:
			player_beats_ai = true
		elif player_hand_rank == ai_hand_rank:
			player_beats_ai = player_best_hand["hand_rank_value"] > ai_best_hand["hand_rank_value"]
	elif player_best_hand:
		player_beats_ai = true

	print("DEBUG: Hand comparison:")
	print("- Player hand type:", player_best_hand["hand_type"] if player_best_hand else "NONE")
	print("- AI hand type:", ai_best_hand["hand_type"] if ai_best_hand else "NONE")

	# Create the result dictionary
	var result = {
		"visible_symbols": current_symbols,
		"ai_symbols": ai_symbols,
		"wins": wins,
		"total_win": total_win,
		"ai_best_hand": ai_best_hand,
		"player_best_hand": player_best_hand,
		"player_beats_ai": player_beats_ai,
		"ai_hand_type": ai_best_hand["hand_type"] if ai_best_hand else "HIGH_CARD",
		"player_best_hand_type": player_best_hand["hand_type"] if player_best_hand else "HIGH_CARD"
	}

	print("DEBUG: Emitting win_evaluated signal")
	emit_signal("win_evaluated", result)
	return result

func compare_hands(player_hand: Dictionary, ai_hand: Dictionary) -> int:
	var hand_rankings = [
		"HIGH_CARD",
		"PAIR",
		"TWO_PAIR",
		"THREE_OF_A_KIND",
		"STRAIGHT",
		"FLUSH",
		"FULL_HOUSE",
		"FOUR_OF_A_KIND",
		"STRAIGHT_FLUSH",
		"ROYAL_FLUSH"
	]
	var player_rank = hand_rankings.find(player_hand["hand_type"])
	var ai_rank = hand_rankings.find(ai_hand["hand_type"])

	if player_rank != ai_rank:
		return player_rank - ai_rank  # Positive if player hand is better
	else:
		# Same hand type, compare hand_rank_value
		if player_hand["hand_rank_value"] > ai_hand["hand_rank_value"]:
			return 1
		elif player_hand["hand_rank_value"] < ai_hand["hand_rank_value"]:
			return -1
		else:
			return 0  # Tie

func get_player_best_hand_type(wins: Array) -> String:
	var best_hand_type = "HIGH_CARD"
	for win in wins:
		if PAYOUT_CONFIG[win["hand_type"]] > PAYOUT_CONFIG[best_hand_type]:
			best_hand_type = win["hand_type"]
	return best_hand_type

func get_player_best_win(wins: Array) -> Dictionary:
	if wins.size() == 0:
		return {}  # Return an empty Dictionary instead of null
	var best_win = wins[0]
	for win in wins:
		if compare_hands(win, best_win) > 0:
			best_win = win
	return best_win

func _compare_hands(win_a: Dictionary, win_b: Dictionary) -> int:
	var hand_rankings = [
		"HIGH_CARD",
		"PAIR",
		"TWO_PAIR",
		"THREE_OF_A_KIND",
		"STRAIGHT",
		"FLUSH",
		"FULL_HOUSE",
		"FOUR_OF_A_KIND",
		"STRAIGHT_FLUSH",
		"ROYAL_FLUSH"
	]
	var rank_a = hand_rankings.find(win_a["hand_type"])
	var rank_b = hand_rankings.find(win_b["hand_type"])
	if rank_a != rank_b:
		return rank_a - rank_b  # Higher index means better hand
	else:
		# Same hand type, compare hand_rank_value
		if win_a["hand_rank_value"] > win_b["hand_rank_value"]:
			return 1
		elif win_a["hand_rank_value"] < win_b["hand_rank_value"]:
			return -1
		else:
			return 0  # Tie


func _evaluate_poker_hand(hand: Array) -> Dictionary:
	# Convert the slot symbols into a format suitable for poker hand evaluation
	var poker_hand = []
	for symbol in hand:
		if symbol["symbol"] == "JOKER":
			poker_hand.append({"rank": "JOKER", "suit": ""})
		else:
			poker_hand.append({"rank": symbol["symbol"], "suit": symbol["suit"]})

	# Determine the best possible hand (including Joker substitutions)
	var best_hand = _find_best_hand(poker_hand)

	return {
		"hand_type": best_hand["type"],
		"payout": PAYOUT_CONFIG[best_hand["type"]],
		"winning_indices": best_hand.get("winning_indices", []),
		"hand_rank_value": best_hand.get("hand_rank_value", 0)
	}

func _find_best_hand(hand: Array) -> Dictionary:
	# If there are no Jokers, evaluate the hand as-is
	if not _contains_joker(hand):
		return _evaluate_basic_poker_hand(hand)

	# If there are Jokers, try all possible substitutions
	var best_hand = {"type": "HIGH_CARD", "payout": 0, "winning_indices": []}
	var possible_ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
	var possible_suits = ["hearts", "diamonds", "clubs", "spades"]

	# Generate all possible combinations for Jokers
	var joker_indices = []
	for i in range(hand.size()):
		if hand[i]["rank"] == "JOKER":
			joker_indices.append(i)

	var substitutions = _generate_joker_substitutions(joker_indices, possible_ranks, possible_suits)

	for substitution in substitutions:
		var test_hand = hand.duplicate(true)
		for idx in substitution:
			test_hand[idx] = substitution[idx]

		var result = _evaluate_basic_poker_hand(test_hand)
		if PAYOUT_CONFIG[result["type"]] > PAYOUT_CONFIG[best_hand["type"]]:
			best_hand = result

	return best_hand

func _contains_joker(hand: Array) -> bool:
	for card in hand:
		if card["rank"] == "JOKER":
			return true
	return false

func _evaluate_basic_poker_hand(hand: Array) -> Dictionary:
	var rank_counts = {}
	var suit_counts = {}
	var rank_to_indices = {}
	var suits = []

	# Build counts and index mappings
	for i in range(hand.size()):
		var card = hand[i]
		var card_rank = card["rank"]
		var card_suit = card["suit"]
		suits.append(card_suit)

		# Count ranks and store indices
		if card_rank in rank_counts:
			rank_counts[card_rank] += 1
			rank_to_indices[card_rank].append(i)
		else:
			rank_counts[card_rank] = 1
			rank_to_indices[card_rank] = [i]

		# Count suits
		if card_suit != "":
			if card_suit in suit_counts:
				suit_counts[card_suit] += 1
			else:
				suit_counts[card_suit] = 1

	# Check for flush
	var is_flush = false
	var flush_suit = ""
	for suit in suit_counts:
		if suit_counts[suit] >= 5:
			is_flush = true
			flush_suit = suit
			break

	# Check for straight
	var values = []
	for key_rank in rank_counts.keys():
			values.append(rank_to_value(key_rank))
	values.sort()
	values = values.reduce(func(acc, val): 
			if not val in acc:
				acc.append(val)
			return acc
	, [])  # Remove duplicates

	var is_straight = false
	var straight_values = []
	if values.size() >= 5:
		for i in range(values.size() - 4):
			if values[i + 4] - values[i] == 4:
				is_straight = true
				straight_values = values.slice(i, 5)
				break
		# Check for Ace-low straight (A,2,3,4,5)
		if not is_straight and values[-1] == 14 and values[0] == 2 and values[1] == 3 and values[2] == 4 and values[3] == 5:
			is_straight = true
			straight_values = [14, 2, 3, 4, 5]

	# Initialize variables for straight flush
	var is_straight_flush = false
	var straight_flush_values = []

	# Determine hand type, winning indices, and hand rank value
	var winning_indices = []
	var hand_rank_value = 0  # Used for tie-breakers

	if is_straight and is_flush:
		# Straight Flush or Royal Flush
		var flush_indices = []
		for i in range(hand.size()):
			if hand[i]["suit"] == flush_suit:
				flush_indices.append(i)
		var flush_values = []
		for idx in flush_indices:
			flush_values.append(rank_to_value(hand[idx]["rank"]))
		flush_values.sort()
		flush_values = flush_values.unify()
		if flush_values.size() >= 5:
			for i in range(flush_values.size() - 4):
				if flush_values[i + 4] - flush_values[i] == 4:
					is_straight_flush = true
					straight_flush_values = flush_values.slice(i, 5)
					# Get indices of the straight flush
					winning_indices = []
					for idx in flush_indices:
						if rank_to_value(hand[idx]["rank"]) in straight_flush_values:
							winning_indices.append(idx)
					hand_rank_value = flush_values[i + 4]  # Highest card in the straight flush
					if _is_royal(straight_flush_values):
						return {"type": "ROYAL_FLUSH", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}
					else:
						return {"type": "STRAIGHT_FLUSH", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}
			# Ace-low straight flush
			if not is_straight_flush and flush_values[-1] == 14 and flush_values[0] == 2:
				if flush_values[1] == 3 and flush_values[2] == 4 and flush_values[3] == 5:
					winning_indices = []
					for idx in flush_indices:
						if rank_to_value(hand[idx]["rank"]) in [14, 2, 3, 4, 5]:
							winning_indices.append(idx)
					hand_rank_value = 5  # Highest card in Ace-low straight
					return {"type": "STRAIGHT_FLUSH", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}

	# Four of a Kind
	for key_rank in rank_counts:
		if rank_counts[key_rank] == 4:
			winning_indices = rank_to_indices[key_rank]
			hand_rank_value = rank_to_value(key_rank)
			return {"type": "FOUR_OF_A_KIND", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}

	# Full House
	var three_of_kind_rank = ""
	var pair_rank = ""
	for key_rank in rank_counts:
		if rank_counts[key_rank] == 3:
			if three_of_kind_rank == "" or rank_to_value(key_rank) > rank_to_value(three_of_kind_rank):
				three_of_kind_rank = key_rank
		elif rank_counts[key_rank] == 2:
			if pair_rank == "" or rank_to_value(key_rank) > rank_to_value(pair_rank):
				pair_rank = key_rank
	if three_of_kind_rank != "" and pair_rank != "":
		winning_indices = rank_to_indices[three_of_kind_rank] + rank_to_indices[pair_rank]
		hand_rank_value = rank_to_value(three_of_kind_rank)
		return {"type": "FULL_HOUSE", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}

	# Flush
	if is_flush:
		winning_indices = []
		var flush_values = []
		for i in range(hand.size()):
			if hand[i]["suit"] == flush_suit:
				winning_indices.append(i)
				flush_values.append(rank_to_value(hand[i]["rank"]))
		hand_rank_value = flush_values.max()
		return {"type": "FLUSH", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}

	# Straight
	if is_straight:
		winning_indices = []
		for i in range(hand.size()):
			if rank_to_value(hand[i]["rank"]) in straight_values:
				winning_indices.append(i)
		hand_rank_value = straight_values.max()
		return {"type": "STRAIGHT", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}

	# Three of a Kind
	for key_rank in rank_counts:
		if rank_counts[key_rank] == 3:
			winning_indices = rank_to_indices[key_rank]
			hand_rank_value = rank_to_value(key_rank)
			return {"type": "THREE_OF_A_KIND", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}

	# Two Pair
	var pairs = []
	for key_rank in rank_counts:
		if rank_counts[key_rank] == 2:
			pairs.append(key_rank)
	if pairs.size() >= 2:
		# Get the two highest pairs
		pairs.sort_custom(func(a, b): return rank_to_value(b) - rank_to_value(a))
		winning_indices = rank_to_indices[pairs[0]] + rank_to_indices[pairs[1]]
		hand_rank_value = rank_to_value(pairs[0]) * 100 + rank_to_value(pairs[1])  # Combine values for tie-breaker
		return {"type": "TWO_PAIR", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}

	# One Pair
	var highest_pair_rank = ""
	for key_rank in rank_counts:
		if rank_counts[key_rank] == 2:
			if highest_pair_rank == "" or rank_to_value(key_rank) > rank_to_value(highest_pair_rank):
				highest_pair_rank = key_rank
	if highest_pair_rank != "":
		winning_indices = rank_to_indices[highest_pair_rank]
		hand_rank_value = rank_to_value(highest_pair_rank)
		return {"type": "PAIR", "winning_indices": winning_indices, "hand_rank_value": hand_rank_value}

	# High Card
	var rank_values = []
	for rank in rank_counts.keys():
			rank_values.append(rank_to_value(rank))
	var highest_card_value = rank_values.max()
	hand_rank_value = highest_card_value
	return {"type": "HIGH_CARD", "winning_indices": [], "hand_rank_value": hand_rank_value}

func rank_to_value(rank):
	match rank:
		"2": return 2
		"3": return 3
		"4": return 4
		"5": return 5
		"6": return 6
		"7": return 7
		"8": return 8
		"9": return 9
		"10": return 10
		"J": return 11
		"Q": return 12
		"K": return 13
		"A": return 14
		_: return 0  # For Jokers or invalid ranks

func _is_royal(values: Array) -> bool:
	return values == [10, 11, 12, 13, 14]

func _generate_joker_substitutions(joker_indices: Array, possible_ranks: Array, possible_suits: Array) -> Array:
	var substitutions = []
	if joker_indices.size() == 0:
		return substitutions

	# For simplicity, let's assume Jokers can be any rank and suit (wildcards)
	# Since generating all possible combinations is computationally intensive, we'll limit the substitutions
	# to the most impactful ones (e.g., ones that could form the highest possible hands)

	# For now, let's just try substituting Jokers with 'A' of any suit
	var substitution = {}
	for idx in joker_indices:
		substitution[idx] = {"rank": "A", "suit": "spades"}  # You can randomize or choose based on strategy

	substitutions.append(substitution)
	return substitutions
