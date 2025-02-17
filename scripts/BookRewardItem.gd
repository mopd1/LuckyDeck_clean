extends Control

@onready var points_required = $PointsRequired
@onready var chips_label = $RewardsContainer/ChipsContainer/ChipsLabel
@onready var gems_label = $RewardsContainer/GemsContainer/GemsLabel
@onready var status_icon = $StatusIcon
@onready var lock_overlay = $LockOverlay

func update(milestone_data: Dictionary, is_available: bool, is_claimed: bool, is_locked: bool) -> void:
	points_required.text = str(milestone_data.required_points) + " AP"
	
	chips_label.text = str(milestone_data.rewards.chips)
	gems_label.text = str(milestone_data.rewards.gems)
	
	status_icon.visible = is_claimed
	lock_overlay.visible = is_locked
	
	# Update visual state
	modulate = Color.WHITE if is_available else Color(0.7, 0.7, 0.7, 1.0)
