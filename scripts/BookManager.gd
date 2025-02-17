extends Node

signal milestone_claimed(milestone_data)

const POINTS_PER_MILESTONE = [100, 250, 500, 1000, 2000]
const MILESTONES_PER_TRACK = 5
const STORY_ACTS = 5

var claimed_milestones = []  # Track which milestones have been claimed
var has_inside_track = false # Track if user has purchased premium track

func get_unlocked_acts() -> Array:
	var unlocked = []
	var points = PlayerData.get_action_points()
	
	# Each act unlocks at a specific milestone point threshold
	for i in range(POINTS_PER_MILESTONE.size()):
		if points >= POINTS_PER_MILESTONE[i]:
			unlocked.append(i + 1)  # Act numbers are 1-based
			
	return unlocked

func get_next_milestone(current_points: int) -> int:
	for milestone in POINTS_PER_MILESTONE:
		if current_points < milestone:
			return milestone
	return 0  # Return 0 if all milestones are completed

func get_claimed_milestones() -> Array:
	return claimed_milestones.duplicate()

func get_milestone_data(index: int, is_inside_track: bool) -> Dictionary:
	if index < 0 or index >= POINTS_PER_MILESTONE.size():
		return {}
		
	var required_points = POINTS_PER_MILESTONE[index]
	var multiplier = 2.0 if is_inside_track else 1.0
	
	return {
		"required_points": required_points,
		"rewards": {
			"chips": int(1000 * (index + 1) * multiplier),
			"gems": int(10 * (index + 1) * multiplier)
		}
	}

func claim_milestone(milestone_index: int, is_inside_track: bool) -> bool:
	# Check if milestone is already claimed
	if milestone_index in claimed_milestones:
		return false
		
	# Check if user has enough points
	var points = PlayerData.get_action_points()
	var milestone_data = get_milestone_data(milestone_index, is_inside_track)
	
	if points < milestone_data.required_points:
		return false
		
	# Check if trying to claim inside track without access
	if is_inside_track and not has_inside_track:
		return false
		
	# Claim the milestone
	claimed_milestones.append(milestone_index)
	
	# Award the rewards
	var rewards = milestone_data.rewards
	PlayerData.update_total_balance(rewards.chips)
	PlayerData.update_gems(rewards.gems)
	
	emit_signal("milestone_claimed", milestone_data)
	return true

func has_inside_track_access() -> bool:
	return has_inside_track

func purchase_inside_track() -> bool:
	# TODO: Implement purchase logic
	# This should connect to your in-app purchase system
	has_inside_track = true
	return true

func reset_season():
	claimed_milestones.clear()
	has_inside_track = false
	PlayerData.set_action_points(0)
