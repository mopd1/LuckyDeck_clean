# TableManagerTest.gd
extends Control

@onready var output_label = $OutputLabel

func _ready():
	# Clear the initial text
	output_label.text = ""
	run_tests()

func run_tests():
	log_output("Starting TableManager tests...")
	
	# Test 1: Table Creation
	log_output("\nTest 1: Table Creation")
	var table = TableManager.create_table(1000)  # 1000 chip big blind
	if table and table.id and table.stake_level == 1000:
		log_output("✓ Table created successfully")
		log_output("  Table ID: " + table.id)
		log_output("  Stake Level: " + str(table.stake_level))
	else:
		log_output("✗ Table creation failed")
	
	# Test 2: Player Seating
	log_output("\nTest 2: Player Seating")
	var player_data = {
		"user_id": "test_user_1",
		"name": "Test Player",
		"chips": 150000,  # 150 big blinds
		"bet": 0,
		"folded": false,
		"sitting_out": false,
		"cards": [],
		"auto_post_blinds": true,
		"last_action": "",
		"last_action_amount": 0,
		"time_bank": 30.0,
		"avatar_data": {}
	}
	
	var seat_index = TableManager.seat_player(table.id, player_data)
	if seat_index >= 0:
		log_output("✓ Player seated successfully at position " + str(seat_index))
	else:
		log_output("✗ Player seating failed")
	
	# Test 3: Optimal Table Selection
	log_output("\nTest 3: Optimal Table Selection")
	var optimal_table = TableManager.find_optimal_table(1000, player_data)
	if optimal_table:
		log_output("✓ Found optimal table")
		log_output("  Table ID: " + optimal_table.id)
		log_output("  Player Count: " + str(TableManager.get_player_count(optimal_table.id)))
	else:
		log_output("✗ Optimal table selection failed")
	
	# Test 4: Rake Calculation
	log_output("\nTest 4: Rake Calculation")
	var test_pot = 10000
	var rake = TableManager.calculate_rake(test_pot)
	log_output("  Test pot: " + str(test_pot))
	log_output("  Calculated rake: " + str(rake))
	if rake == 1000:  # Should be 10% of 10000
		log_output("✓ Rake calculation correct")
	else:
		log_output("✗ Rake calculation incorrect")
	
	# Test 5: Hand Progression
	log_output("\nTest 5: Hand Progression")
	TableManager.start_new_hand(table.id)
	log_output("  Started new hand")
	
	TableManager.enter_flop_betting_round(table.id)
	var table_data = TableManager.get_table_data(table.id)
	if table_data.rake_eligible:
		log_output("✓ Hand correctly marked as rake-eligible after flop")
	else:
		log_output("✗ Rake eligibility not set correctly")
	
	# Test 6: Player Removal
	log_output("\nTest 6: Player Removal")
	TableManager.remove_player(table.id, seat_index)
	var seat_still_occupied = TableManager.get_table_data(table.id).players[seat_index] != null
	if not seat_still_occupied:
		log_output("✓ Player removed successfully")
	else:
		log_output("✗ Player removal failed")
	
	log_output("\nTests completed!")

func log_output(text: String):
	print(text)  # Print to debug output
	if output_label:
		output_label.text += text + "\n"
