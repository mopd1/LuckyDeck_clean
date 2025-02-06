extends Node

# Enums
enum BetType { WIN, DRAW }
enum OddsFormat { AMERICAN, DECIMAL }
enum League { NFL, EPL }

# Constants
const MIN_BET_AMOUNT = 100000
const DEFAULT_TIMEZONE = "America/New_York"

# Signals
signal odds_updated(league: League)
signal bet_placed(bet_data: Dictionary)
signal bet_cancelled(bet_id: String)
signal bets_settled(settlement_data: Array)
signal fixture_round_updated(league: League)

# Data structures
var fixture_data = {
	League.NFL: {
		"current_round": 1,
		"lock_time": "",
		"settlement_time": "",
		"fixtures": []
	},
	League.EPL: {
		"current_round": 1,
		"lock_time": "",
		"settlement_time": "",
		"fixtures": []
	}
}

var active_bets = {}
var settled_bets = {}
var odds_format = OddsFormat.AMERICAN

func _ready():
	# Load initial fixture data
	_load_fixture_data()
	
	# Connect to API manager for bet settlement updates
	if not APIManager.is_connected("balance_update_completed", _on_balance_update_completed):
		APIManager.connect("balance_update_completed", _on_balance_update_completed)

func place_bet(league: League, fixture_id: String, bet_type: BetType, amount: int) -> Dictionary:
	if amount < MIN_BET_AMOUNT:
		return {"success": false, "error": "Minimum bet amount is " + str(MIN_BET_AMOUNT)}
	
	if not PlayerData.has_sufficient_balance(amount):
		return {"success": false, "error": "Insufficient balance"}
	
	# Check if bet already exists for this fixture
	if _has_existing_bet(fixture_id):
		return {"success": false, "error": "Already have a bet on this fixture"}
	
	var bet_id = _generate_bet_id()
	var bet_data = {
		"id": bet_id,
		"league": league,
		"fixture_id": fixture_id,
		"type": bet_type,
		"amount": amount,
		"odds": _get_odds(league, fixture_id, bet_type),
		"potential_winnings": _calculate_potential_winnings(amount, _get_odds(league, fixture_id, bet_type)),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	active_bets[bet_id] = bet_data
	PlayerData.update_total_balance(-amount)
	
	emit_signal("bet_placed", bet_data)
	return {"success": true, "bet_data": bet_data}

func cancel_bet(bet_id: String) -> Dictionary:
	if not active_bets.has(bet_id):
		return {"success": false, "error": "Bet not found"}
	
	var bet_data = active_bets[bet_id]
	var league = bet_data["league"]
	
	# Check if bet can still be cancelled
	if Time.get_unix_time_from_system() >= _get_lock_time(league):
		return {"success": false, "error": "Bets are locked"}
	
	# Return funds to player
	PlayerData.update_total_balance(bet_data["amount"])
	
	active_bets.erase(bet_id)
	emit_signal("bet_cancelled", bet_id)
	
	return {"success": true}

func toggle_odds_format():
	odds_format = OddsFormat.DECIMAL if odds_format == OddsFormat.AMERICAN else OddsFormat.AMERICAN
	emit_signal("odds_updated", League.NFL)
	emit_signal("odds_updated", League.EPL)

func get_formatted_odds(american_odds: float) -> String:
	if odds_format == OddsFormat.AMERICAN:
		return _format_american_odds(american_odds)
	return _format_decimal_odds(american_odds)

func _format_american_odds(odds: float) -> String:
	if odds >= 0:
		return "+" + str(odds)
	return str(odds)

func _format_decimal_odds(american_odds: float) -> String:
	var decimal = _convert_american_to_decimal(american_odds)
	return "%.2f" % decimal

func _convert_american_to_decimal(american_odds: float) -> float:
	if american_odds >= 0:
		return (american_odds / 100.0) + 1.0
	return (100.0 / abs(american_odds)) + 1.0

func _calculate_potential_winnings(bet_amount: int, american_odds: float) -> int:
	var decimal_odds = _convert_american_to_decimal(american_odds)
	return int(bet_amount * decimal_odds)

func _generate_bet_id() -> String:
	return str(randi()) + "_" + str(Time.get_unix_time_from_system())

func _has_existing_bet(fixture_id: String) -> bool:
	for bet in active_bets.values():
		if bet["fixture_id"] == fixture_id:
			return true
	return false

# Placeholder functions for backend integration
func _load_fixture_data():
	# This would eventually fetch from backend
	pass

func _get_odds(league: League, fixture_id: String, bet_type: BetType) -> float:
	# This would eventually fetch from backend
	return -110.0

func _get_lock_time(league: League) -> int:
	# This would eventually fetch from backend
	return 0

func _on_balance_update_completed(success: bool, message: String):
	if not success:
		push_error("Failed to update balance: " + message)
