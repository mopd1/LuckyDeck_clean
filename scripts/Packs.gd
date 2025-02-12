extends Resource
class_name Packs

const PACK_TYPES = {
	"envelope": {
		"name": "Envelope Pack",
		"cost": 100,
		"probabilities": {
			"common": 0.80,
			"uncommon": 0.18,
			"rare": 0.02
		}
	},
	"holdall": {
		"name": "Holdall Pack",
		"cost": 200,
		"probabilities": {
			"common": 0.60,
			"uncommon": 0.30,
			"rare": 0.10
		}
	},
	"briefcase": {
		"name": "Briefcase Pack",
		"cost": 300,
		"probabilities": {
			"common": 0.30,
			"uncommon": 0.50,
			"rare": 0.20
		}
	}
}

static func get_rarity_for_pack(pack_type: String) -> String:
	var pack_data = PACK_TYPES[pack_type]
	var rand = randf()
	var cumulative = 0.0
	
	for rarity in pack_data.probabilities:
		cumulative += pack_data.probabilities[rarity]
		if rand <= cumulative:
			return rarity
	
	return "common" # Fallback
