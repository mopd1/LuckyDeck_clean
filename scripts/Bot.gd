extends Node

class_name Bot

const HandEvaluator = preload("res://scripts/HandEvaluator.gd")

const BOT_NAMES = [
	"CoolBot",
	"PokerMaster",
	"ChipWizard",
	"CardShark",
	"BluffMaster"
]

var seat_index: int
var table_id: String
var chips: int
var display_name: String
var avatar_data: Dictionary

func _init(seat: int, table: String, starting_chips: int):
	seat_index = seat
	table_id = table
	chips = starting_chips
	display_name = BOT_NAMES[randi() % BOT_NAMES.size()]
	
	# Generate random avatar data
	avatar_data = {
		"hair": randi() % 10,
		"face": randi() % 10,
		"clothes": randi() % 10,
		"accessories": randi() % 5
	}

func should_fold(hand_strength: int, pot_odds: float) -> bool:
	match hand_strength:
		HandEvaluator.HandRank.HIGH_CARD:
			return randf() < 0.8  # 80% chance to fold
		HandEvaluator.HandRank.PAIR:
			return randf() < 0.4  # 40% chance to fold
		_:
			return false  # Stronger hands don't fold

func calculate_bet_size(table_data: Dictionary, hand_strength: int) -> int:
	var pot_size = table_data.current_pot
	var min_raise = table_data.stake_level
	
	match hand_strength:
		HandEvaluator.HandRank.HIGH_CARD:
			return table_data.current_bet  # Just call
		HandEvaluator.HandRank.PAIR:
			return table_data.current_bet + min_raise  # Min raise
		_:
			# Stronger hands make bigger bets
			return table_data.current_bet + min_raise * 2

func make_decision(table_data: Dictionary) -> Dictionary:
	# Get hand info based on current round
	var hand_info
	if table_data.current_round == "preflop":
		hand_info = HandEvaluator.evaluate_preflop_hand(table_data.players[seat_index].cards)
	else:
		hand_info = HandEvaluator.evaluate_hand(table_data.players[seat_index].cards, table_data.community_cards)
	
	if hand_info == null:
		print("DEBUG: Bot ", seat_index, " couldn't evaluate hand, defaulting to fold")
		return {"action": "fold"}
		
	var pot_odds = float(table_data.current_bet) / float(table_data.current_pot) if table_data.current_pot > 0 else 0.0
	print("DEBUG: Bot ", seat_index, " evaluating decision:")
	print("- Hand rank: ", hand_info.rank)
	print("- Pot odds: ", pot_odds)
	
	if should_fold(hand_info.rank, pot_odds):
		print("DEBUG: Bot ", seat_index, " decided to fold")
		return {"action": "fold"}
	
	var bet_size = calculate_bet_size(table_data, hand_info.rank)
	if table_data.current_bet == 0:
		print("DEBUG: Bot ", seat_index, " decided to bet ", bet_size)
		return {"action": "raise", "amount": bet_size}
	elif bet_size > table_data.current_bet:
		print("DEBUG: Bot ", seat_index, " decided to raise to ", bet_size)
		return {"action": "raise", "amount": bet_size}
	else:
		print("DEBUG: Bot ", seat_index, " decided to call")
		return {"action": "call", "amount": table_data.current_bet}

func get_player_data() -> Dictionary:
	return {
		"user_id": "bot_" + str(seat_index),
		"name": display_name,
		"chips": chips,
		"bet": 0,
		"folded": false,
		"sitting_out": false,
		"cards": [],
		"auto_post_blinds": true,
		"last_action": "",
		"last_action_amount": 0,
		"time_bank": 30.0,
		"avatar_data": avatar_data,
		"is_bot": true
	}
