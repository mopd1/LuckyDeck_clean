extends Control

signal reward_claimed(milestone)

@onready var milestone_label = $PanelContainer/Control/Control/MilestoneLabel
@onready var status_label = $PanelContainer/Control/Control/StatusLabel
@onready var chip_reward_label = $PanelContainer/Control/Control2/ChipRewardLabel
@onready var gem_reward_label = $PanelContainer/Control/Control2/GemRewardLabel
@onready var claim_button = $PanelContainer/Control/ClaimButton

var milestone: int = 0
var chips_amount: int = 0  # Store raw values for claiming
var gems_amount: int = 0   # Store raw values for claiming

func _ready():
	print("RewardItem ready")
	_check_nodes()
	
	if claim_button:
		claim_button.pressed.connect(_on_claim_button_pressed)

func _check_nodes():
	print("Checking RewardItem nodes:")
	print("- MilestoneLabel: ", "Found" if milestone_label else "Not found")
	print("- StatusLabel: ", "Found" if status_label else "Not found")
	print("- ChipRewardLabel: ", "Found" if chip_reward_label else "Not found")
	print("- GemRewardLabel: ", "Found" if gem_reward_label else "Not found")
	print("- ClaimButton: ", "Found" if claim_button else "Not found")

func setup(milestone_value: int, chips: int, gems: int, is_claimable: bool, is_claimed: bool):
	print("Setting up RewardItem for milestone ", milestone_value)
	milestone = milestone_value
	chips_amount = chips
	gems_amount = gems
	
	if milestone_label:
		milestone_label.text = "%s" % Utilities.format_number(milestone)
	else:
		push_error("MilestoneLabel not found in RewardItem")
	
	if chip_reward_label:
		chip_reward_label.text = Utilities.format_number(chips) if chips > 0 else ""
	else:
		push_error("ChipRewardLabel not found in RewardItem")
	
	if gem_reward_label:
		gem_reward_label.text = Utilities.format_number(gems) if gems > 0 else ""
	else:
		push_error("GemRewardLabel not found in RewardItem")
	
	update_claim_state(is_claimable, is_claimed)

func update_claim_state(is_claimable: bool, is_claimed: bool):
	print("Updating claim state for milestone ", milestone, ": claimable = ", is_claimable, ", claimed = ", is_claimed)
	if status_label and claim_button:
		if is_claimed:
			status_label.text = "Claimed"
			status_label.modulate = Color.GRAY
			claim_button.text = "Claimed"
			claim_button.disabled = true
		elif is_claimable:
			status_label.text = "Available"
			status_label.modulate = Color.GREEN
			claim_button.text = "Claim"
			claim_button.disabled = false
		else:
			status_label.text = "Locked"
			status_label.modulate = Color.RED
			claim_button.text = "Claim"
			claim_button.disabled = true
	else:
		push_error("StatusLabel or ClaimButton not found in RewardItem")

func _on_claim_button_pressed():
	print("Claim button pressed for milestone ", milestone)
	if ChallengesManager.claim_reward(milestone):
		update_claim_state(false, true)
		emit_signal("reward_claimed", milestone)
