extends Node

const MILESTONES = {
	5: {"chips": 2000, "gems": 0},
	10: {"chips": 0, "gems": 30},
	20: {"chips": 8000, "gems": 0},
	30: {"chips": 0, "gems": 50},
	50: {"chips": 20000, "gems": 0},
	75: {"chips": 0, "gems": 100},
	100: {"chips": 40000, "gems": 0},
	200: {"chips": 80000, "gems": 0},
	300: {"chips": 120000, "gems": 0},
	500: {"chips": 200000, "gems": 0},
	1000: {"chips": 400000, "gems": 0},
	2000: {"chips": 800000, "gems": 0},
	3000: {"chips": 1200000, "gems": 0},
	5000: {"chips": 2000000, "gems": 0},
	10000: {"chips": 4000000, "gems": 0},
	20000: {"chips": 8000000, "gems": 0},
	30000: {"chips": 12000000, "gems": 0},
	50000: {"chips": 20000000, "gems": 0},
	100000: {"chips": 40000000, "gems": 0},
	200000: {"chips": 80000000, "gems": 0},
	300000: {"chips": 120000000, "gems": 0},
	500000: {"chips": 200000000, "gems": 0},
	1000000: {"chips": 500000000, "gems": 1000}
}

var claimed_milestones = []

func _ready():
	print("ChallengesManager initialized")
	print("Available milestones: ", MILESTONES.keys())

func check_milestones(current_points):
	if not is_instance_valid(self):
		push_error("ChallengesManager is not valid")
		return []
	
	print("Checking milestones for ", current_points, " points")
	var unclaimed_rewards = []
	for milestone in MILESTONES.keys():
		if current_points >= milestone and milestone not in claimed_milestones:
			unclaimed_rewards.append(milestone)
	print("Unclaimed rewards: ", unclaimed_rewards)
	return unclaimed_rewards

func claim_reward(milestone):
	if not is_instance_valid(self):
		push_error("ChallengesManager is not valid")
		return false
	
	print("Attempting to claim reward for milestone ", milestone)
	if milestone in MILESTONES and milestone not in claimed_milestones:
		var reward = MILESTONES[milestone]
		PlayerData.update_total_balance(reward["chips"])
		PlayerData.update_gems(reward["gems"])
		claimed_milestones.append(milestone)
		print("Reward claimed for milestone ", milestone)
		return true
	print("Failed to claim reward for milestone ", milestone)
	return false

func claim_all_rewards(current_points):
	var claimed = []
	for milestone in check_milestones(current_points):
		if claim_reward(milestone):
			claimed.append(milestone)
	return claimed

func get_next_milestone(current_points):
	var next_milestone = null
	for milestone in MILESTONES.keys():
		if milestone > current_points:
			if next_milestone == null or milestone < next_milestone:
				next_milestone = milestone
	return next_milestone

func calculate_total_unclaimed_rewards(current_points):
	var total_chips = 0
	var total_gems = 0
	for milestone in check_milestones(current_points):
		total_chips += MILESTONES[milestone]["chips"]
		total_gems += MILESTONES[milestone]["gems"]
	return {"chips": total_chips, "gems": total_gems}

func get_claimed_milestones():
	if not is_instance_valid(self):
		push_error("ChallengesManager is not valid")
		return []
	
	print("Claimed milestones: ", claimed_milestones)
	return claimed_milestones
