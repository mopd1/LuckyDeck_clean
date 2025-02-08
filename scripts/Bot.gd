extends Node

class_name Bot

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
var display_name: String  # Changed from 'name' to 'display_name'
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

func make_decision(table_data: Dictionary) -> Dictionary:
	# Simple random decision-making
	var action_weights = {
		"fold": 0.33,
		"call": 0.33,
		"raise": 0.34
	}
	
	var rand_value = randf()
	var cumulative_weight = 0.0
	
	for action in action_weights:
		cumulative_weight += action_weights[action]
		if rand_value <= cumulative_weight:
			match action:
				"fold":
					return {"action": "fold"}
				"call":
					var call_amount = table_data.current_bet
					return {"action": "call", "amount": call_amount}
				"raise":
					var min_raise = table_data.stake_level
					var raise_amount = table_data.current_bet + min_raise
					return {"action": "raise", "amount": raise_amount}
	
	# Default to folding if something goes wrong
	return {"action": "fold"}

func get_player_data() -> Dictionary:
	return {
		"user_id": "bot_" + str(seat_index),
		"name": display_name,  # Use display_name here
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
