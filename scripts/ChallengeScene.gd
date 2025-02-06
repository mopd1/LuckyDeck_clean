extends Control

@onready var points_label = $PointsLabel
@onready var rewards_container = $ScrollContainer/RewardsContainer
@onready var claim_all_button = $ClaimAllButton
@onready var return_button = $ReturnButton
@onready var scroll_container = $ScrollContainer

var RewardItem = preload("res://scenes/RewardItem.tscn")

func _ready():
	print("ChallengeScene ready")
	if not is_instance_valid(ChallengesManager):
		push_error("ChallengesManager is not valid")
		return
		
	if not rewards_container:
		push_error("RewardsContainer not found in ChallengeScene")
		return
		
	if not RewardItem:
		push_error("Failed to load RewardItem scene")
		return
		
	# Enable touch scrolling by setting mouse filter
	if scroll_container:
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
		
	update_display()
	
	if claim_all_button:
		claim_all_button.pressed.connect(_on_claim_all_pressed)
	else:
		push_error("ClaimAllButton node not found in ChallengeScene")
		
	if return_button:
		return_button.pressed.connect(_on_return_pressed)
	else:
		push_error("ReturnButton node not found in ChallengeScene")

func update_display():
	print("Updating ChallengeScene display")
	if not is_instance_valid(points_label) or not is_instance_valid(rewards_container):
		push_error("Required nodes not found in ChallengeScene")
		return
		
	var points = PlayerData.player_data["challenge_points"]
	points_label.text = "Challenge Points: %s" % Utilities.format_number(points)
	print("Current challenge points: ", points)
	
	for child in rewards_container.get_children():
		child.queue_free()
		
	var unclaimed_milestones = ChallengesManager.check_milestones(points)
	var claimed_milestones = ChallengesManager.get_claimed_milestones()
	
	print("Populating rewards container")
	for milestone in ChallengesManager.MILESTONES.keys():
		var reward = ChallengesManager.MILESTONES[milestone]
		var reward_item = RewardItem.instantiate()
		if not reward_item:
			push_error("Failed to instantiate RewardItem")
			continue
			
		rewards_container.add_child(reward_item)
		
		if reward_item.has_method("setup"):
			var is_claimable = milestone in unclaimed_milestones
			var is_claimed = milestone in claimed_milestones
			print("Setting up reward item for milestone ", milestone, ": claimable = ", is_claimable, ", claimed = ", is_claimed)
			
			# Pass raw integers to RewardItem.setup()
			reward_item.setup(milestone, reward["chips"], reward["gems"], is_claimable, is_claimed)
			reward_item.connect("reward_claimed", Callable(self, "_on_reward_claimed"))
		else:
			push_error("RewardItem scene does not have a 'setup' method")
			
	claim_all_button.disabled = unclaimed_milestones.is_empty()
	print("ChallengeScene display update complete")

func _on_claim_all_pressed():
	var claimed = ChallengesManager.claim_all_rewards(PlayerData.player_data["challenge_points"])
	if not claimed.is_empty():
		update_display()

func _on_return_pressed():
	SceneManager.goto_scene("res://scenes/MainHub.tscn")

func _on_reward_claimed(_milestone):
	update_display()

func _input(event):
	if event is InputEventScreenDrag:
		if scroll_container and scroll_container.get_global_rect().has_point(event.position):
			scroll_container.scroll_vertical -= event.relative.y * 1.5
			get_viewport().set_input_as_handled()
