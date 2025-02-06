extends RefCounted

const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS = ["hearts", "diamonds", "clubs", "spades"]

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

class HandInfo:
	var rank: HandRank
	var values: Array
	
	func _init(r: HandRank, v: Array):
		rank = r
		values = v

static func evaluate_hand(hole_cards, community_cards):
	var all_cards = hole_cards + community_cards
	return identify_best_hand(all_cards)

static func identify_best_hand(cards):
	var best_hand = null
	var combinations = get_all_combinations(cards, 5)
	
	for hand in combinations:
		var current_hand = identify_hand(hand)
		if best_hand == null or compare_hands(current_hand, best_hand) > 0:
			best_hand = current_hand
	
	return best_hand

static func identify_hand(cards):
	var ranks = cards.map(func(card): return card.rank)
	var suits = cards.map(func(card): return card.suit)
	
	var is_flush = is_flush(cards)
	var is_straight = is_straight(ranks)
	
	if is_straight and is_flush:
		if "A" in ranks and "K" in ranks:
			return HandInfo.new(HandRank.ROYAL_FLUSH, [])
		return HandInfo.new(HandRank.STRAIGHT_FLUSH, [max_rank_value(ranks)])
	
	var rank_counts = {}
	for rank in ranks:
		if rank not in rank_counts:
			rank_counts[rank] = 1
		else:
			rank_counts[rank] += 1
	
	var counts = rank_counts.values()
	var sorted_ranks = rank_counts.keys().map(func(r): return rank_to_value(r))
	sorted_ranks.sort()
	sorted_ranks.reverse()
	
	if 4 in counts:
		var quad = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 4)[0]
		var kicker = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 1)[0]
		return HandInfo.new(HandRank.FOUR_OF_A_KIND, [quad, kicker])
	
	if 3 in counts and 2 in counts:
		var triple = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 3)[0]
		var pair = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 2)[0]
		return HandInfo.new(HandRank.FULL_HOUSE, [triple, pair])
	
	if is_flush:
		return HandInfo.new(HandRank.FLUSH, sorted_ranks)
	
	if is_straight:
		var values = ranks.map(func(rank): return rank_to_value(rank))
		var high_card = get_straight_high_card(values)
		return HandInfo.new(HandRank.STRAIGHT, [high_card] + values)
	
	if 3 in counts:
		var triple = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 3)[0]
		var kickers = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 1)
		return HandInfo.new(HandRank.THREE_OF_A_KIND, [triple] + kickers)
	
	if counts.count(2) == 2:
		var pairs = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 2)
		var kicker = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 1)[0]
		return HandInfo.new(HandRank.TWO_PAIR, pairs + [kicker])
	
	if 2 in counts:
		var pair = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 2)[0]
		var kickers = sorted_ranks.filter(func(r): return rank_counts[RANKS[r]] == 1)
		return HandInfo.new(HandRank.PAIR, [pair] + kickers)
	
	return HandInfo.new(HandRank.HIGH_CARD, sorted_ranks)

static func compare_hands(hand1: HandInfo, hand2: HandInfo):
	if hand1.rank > hand2.rank:
		return 1
	elif hand1.rank < hand2.rank:
		return -1
	
	# If ranks are equal, compare the values
	for i in range(min(hand1.values.size(), hand2.values.size())):
		if hand1.values[i] > hand2.values[i]:
			return 1
		elif hand1.values[i] < hand2.values[i]:
			return -1
	
	return 0

static func get_all_combinations(cards, r):
	var n = cards.size()
	var combinations = []
	
	if r > n:
		return combinations  # Return empty list if r is greater than n
	
	var indices = []
	for i in range(r):
		indices.append(i)
	
	while true:
		var combination = []
		for i in range(r):
			combination.append(cards[indices[i]])
		combinations.append(combination)
		
		# Find the rightmost index that can be incremented
		var i = r - 1
		while i >= 0 and indices[i] == i + n - r:
			i -= 1
		
		if i < 0:
			break
		
		indices[i] += 1
		for j in range(i + 1, r):
			indices[j] = indices[i] + j - i
	
	return combinations

static func evaluate_preflop_hand(hole_cards):
	if not hole_cards or hole_cards.size() < 2 or not hole_cards[0] or not hole_cards[1]:
		push_error("Invalid hole cards provided to evaluate_preflop_hand")
		return HandInfo.new(HandRank.HIGH_CARD, [])
   
	var ranks = hole_cards.map(func(card): return card.rank)
	var suits = hole_cards.map(func(card): return card.suit)
   
	if ranks[0] == ranks[1]:
		return HandInfo.new(HandRank.PAIR, [rank_to_value(ranks[0])])
	elif suits[0] == suits[1]:
		var values = [rank_to_value(ranks[0]), rank_to_value(ranks[1])]
		values.sort()
		values.reverse()
		return HandInfo.new(HandRank.HIGH_CARD, values)  # Suited cards, but not a flush
	else:
		var values = [rank_to_value(ranks[0]), rank_to_value(ranks[1])]
		values.sort()
		values.reverse()
		return HandInfo.new(HandRank.HIGH_CARD, values)

static func max_rank_value(ranks):
	return ranks.map(func(r): return rank_to_value(r)).max()

static func hand_rank_to_string(hand_info):
	if hand_info == null:
		return "Invalid Hand"
	
	var base_str = match_hand_rank_to_string(hand_info.rank)
	match hand_info.rank:
		HandRank.PAIR, HandRank.THREE_OF_A_KIND, HandRank.FOUR_OF_A_KIND:
			return base_str + " of " + RANKS[hand_info.values[0]] + "s"
		HandRank.TWO_PAIR:
			return base_str + " " + RANKS[hand_info.values[0]] + "s and " + RANKS[hand_info.values[1]] + "s"
		HandRank.FULL_HOUSE:
			return base_str + " " + RANKS[hand_info.values[0]] + "s full of " + RANKS[hand_info.values[1]] + "s"
		HandRank.FLUSH:
			return base_str + " to the " + RANKS[hand_info.values[0]]
		HandRank.STRAIGHT, HandRank.STRAIGHT_FLUSH:
			var high_card = hand_info.values[0]
			if high_card == 5 and hand_info.values.has(14):  # Special case for wheel
				return base_str + ", Five-high"
			return base_str + ", " + RANKS[high_card] + "-high"
		_:
			return base_str

static func match_hand_rank_to_string(hand_rank):
	match hand_rank:
		HandRank.HIGH_CARD: return "High Card"
		HandRank.PAIR: return "Pair"
		HandRank.TWO_PAIR: return "Two Pair"
		HandRank.THREE_OF_A_KIND: return "Three of a Kind"
		HandRank.STRAIGHT: return "Straight"
		HandRank.FLUSH: return "Flush"
		HandRank.FULL_HOUSE: return "Full House"
		HandRank.FOUR_OF_A_KIND: return "Four of a Kind"
		HandRank.STRAIGHT_FLUSH: return "Straight Flush"
		HandRank.ROYAL_FLUSH: return "Royal Flush"
	return "Unknown Hand"

static func rank_to_value(rank):
	return RANKS.find(rank)

static func is_flush(cards):
	var suit = cards[0].suit
	return cards.all(func(card): return card.suit == suit)

static func is_straight(ranks):
	var values = ranks.map(func(rank): return rank_to_value(rank))
	values.sort()
	values = values.reduce(func(acc, val): 
		if acc.is_empty() or val != acc[-1]:
			acc.append(val)
		return acc
	, [])  # Remove duplicates
	
	if values.size() < 5:
		return false
	
	for i in range(values.size() - 4):
		if values[i+4] - values[i] == 4:
			return true
	
	# Fix the Ace-low straight check
	# We need to check for Ace (14) and 2,3,4,5
	if values.has(14):  # If we have an Ace
		var low_straight = [2, 3, 4, 5]
		var has_low_straight = low_straight.all(func(val): return values.has(val))
		if has_low_straight:
			return true
	
	return false

static func get_straight_high_card(values: Array) -> int:
	# Sort values in ascending order
	values.sort()
	values = values.reduce(func(acc, val):
		if not val in acc:
			acc.append(val)
		return acc
	, []) # Remove duplicates
	
	# Check for regular straight
	for i in range(values.size() - 4):
		if values[i + 4] - values[i] == 4:
			return values[i + 4]
	
	# Check specifically for 5-high straight (A,2,3,4,5)
	if values.has(14) and values.has(2) and values.has(3) and values.has(4) and values.has(5):
		return 5
		
	return 0

static func debug_print_hand(cards):
	var hand_str = ""
	for card in cards:
		hand_str += card.rank + card.suit[0] + " "
	print("Debug - Hand: ", hand_str)
