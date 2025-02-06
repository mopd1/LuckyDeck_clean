extends Node

signal bet_placed(area: String, amount: int, position: Vector2)
signal bet_removed(area: String, amount: int)
signal bet_won(area: String, amount: int, payout: int)
signal bet_lost(area: String, amount: int)

# Bet types and their corresponding payouts
const PAYOUTS = {
	"pass_line": 1,         # 1:1
	"dont_pass": 1,         # 1:1
	"come": 1,              # 1:1
	"dont_come": 1,         # 1:1
	"field": {
		"2": 2,            # 2:1
		"3": 1,            # 1:1
		"4": 1,
		"9": 1,
		"10": 1,
		"11": 1,
		"12": 3            # 3:1
	},
	"hardways": {
		"4": 7,            # 7:1
		"6": 9,            # 9:1
		"8": 9,            # 9:1
		"10": 7            # 7:1
	},
	"one_roll": {
		"7": 4,            # 4:1
		"craps": 7,        # 7:1
		"11": 15,          # 15:1
		"any_craps": 7     # 7:1
	}
}

# Track all active bets
var active_bets: Dictionary = {}
var come_point_bets: Dictionary = {}
var dont_come_point_bets: Dictionary = {}

func _init():
	reset_bets()

func reset_bets() -> void:
	active_bets.clear()
	come_point_bets.clear()
	dont_come_point_bets.clear()

func can_place_bet(bet_type: String, amount: int, game_phase: String, point: int) -> bool:
	# Check if bet type is valid for current game phase
	match game_phase:
		"come_out":
			if bet_type in ["come", "dont_come"]:
				return false
		"point":
			if bet_type in ["pass_line", "dont_pass"]:
				return false
	
	return true

func place_bet(bet_type: String, amount: int, position: Vector2) -> bool:
	if not active_bets.has(bet_type):
		active_bets[bet_type] = []
	
	active_bets[bet_type].append({
		"amount": amount,
		"position": position
	})
	
	emit_signal("bet_placed", bet_type, amount, position)
	return true

func process_come_out_roll(total: int) -> void:
	# Process Pass Line bets
	if total in [7, 11]:
		pay_bets("pass_line", 1)
		collect_bets("dont_pass")
	elif total in [2, 3]:
		collect_bets("pass_line")
		pay_bets("dont_pass", 1)
	elif total == 12:
		collect_bets("pass_line")
		push_bets("dont_pass")  # Return don't pass bets on 12
	
	# Process Field bets
	process_field_bets(total)
	
	# Process One Roll bets
	process_one_roll_bets(total)

func process_one_roll_bets(total: int) -> void:
	if not active_bets.has("one_roll"):
		return
	
	# Process Seven bets (7)
	if total == 7:
		pay_bets("one_roll_seven", PAYOUTS.one_roll["7"])
	else:
		collect_bets("one_roll_seven")
	
	# Process Any Craps bets (2, 3, or 12)
	if total in [2, 3, 12]:
		pay_bets("one_roll_craps", PAYOUTS.one_roll["craps"])
	else:
		collect_bets("one_roll_craps")
	
	# Process Eleven bets (11)
	if total == 11:
		pay_bets("one_roll_eleven", PAYOUTS.one_roll["11"])
	else:
		collect_bets("one_roll_eleven")
	
	# Process Any Craps (2, 3, or 12)
	if total in [2, 3, 12]:
		pay_bets("one_roll_any_craps", PAYOUTS.one_roll["any_craps"])
	else:
		collect_bets("one_roll_any_craps")

func process_point_roll(total: int, point: int) -> void:
	if total == point:
		pay_bets("pass_line", 1)
		collect_bets("dont_pass")
		process_come_point_bets(total)
	elif total == 7:
		collect_bets("pass_line")
		pay_bets("dont_pass", 1)
		collect_come_point_bets()
	
	# Process Come/Don't Come bets
	process_come_bets(total)
	
	# Process Field bets
	process_field_bets(total)
	
	# Process Hardways
	if is_hard_way(total):
		process_hardway_bets(total)
	elif total == 7:
		collect_hardway_bets()

func process_field_bets(total: int) -> void:
	if not active_bets.has("field"):
		return
	
	if total in PAYOUTS.field:
		var multiplier = PAYOUTS.field[str(total)]
		pay_bets("field", multiplier)
	else:
		collect_bets("field")

func process_hardway_bets(total: int) -> void:
	var bet_key = "hardways_" + str(total)
	if active_bets.has(bet_key) and is_hard_way(total):
		pay_bets(bet_key, PAYOUTS.hardways[str(total)])

func process_come_bets(total: int) -> void:
	if active_bets.has("come"):
		if total in [7, 11]:
			pay_bets("come", 1)
		elif total in [2, 3, 12]:
			collect_bets("come")
		else:
			move_come_bets_to_point(total)
	
	if active_bets.has("dont_come"):
		if total in [7, 11]:
			collect_bets("dont_come")
		elif total in [2, 3]:
			pay_bets("dont_come", 1)
		elif total == 12:
			push_bets("dont_come")
		else:
			move_dont_come_bets_to_point(total)

func pay_bets(bet_type: String, multiplier: int) -> void:
	if not active_bets.has(bet_type):
		return
	
	for bet in active_bets[bet_type]:
		var payout = bet.amount * multiplier
		emit_signal("bet_won", bet_type, bet.amount, payout)
	
	active_bets.erase(bet_type)

func collect_bets(bet_type: String) -> void:
	if not active_bets.has(bet_type):
		return
	
	for bet in active_bets[bet_type]:
		emit_signal("bet_lost", bet_type, bet.amount)
	
	active_bets.erase(bet_type)

func push_bets(bet_type: String) -> void:
	if not active_bets.has(bet_type):
		return
	
	for bet in active_bets[bet_type]:
		emit_signal("bet_removed", bet_type, bet.amount)
	
	active_bets.erase(bet_type)

func is_hard_way(total: int) -> bool:
	# A hard way is when both dice show the same number
	return total % 2 == 0 and total >= 4 and total <= 10

func move_come_bets_to_point(point: int) -> void:
	if not active_bets.has("come"):
		return
	
	come_point_bets[point] = active_bets["come"]
	active_bets.erase("come")

func move_dont_come_bets_to_point(point: int) -> void:
	if not active_bets.has("dont_come"):
		return
	
	dont_come_point_bets[point] = active_bets["dont_come"]
	active_bets.erase("dont_come")

func process_come_point_bets(total: int) -> void:
	if come_point_bets.has(total):
		for bet in come_point_bets[total]:
			emit_signal("bet_won", "come_point", bet.amount, bet.amount * 1)
		come_point_bets.erase(total)

func collect_come_point_bets() -> void:
	for point in come_point_bets:
		for bet in come_point_bets[point]:
			emit_signal("bet_lost", "come_point", bet.amount)
	come_point_bets.clear()

func collect_hardway_bets() -> void:
	for i in [4, 6, 8, 10]:
		var bet_key = "hardways_" + str(i)
		if active_bets.has(bet_key):
			collect_bets(bet_key)

func get_total_active_bets() -> int:
	var total = 0
	for bet_type in active_bets:
		for bet in active_bets[bet_type]:
			total += bet.amount
	return total
