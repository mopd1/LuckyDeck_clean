extends Node

var current_scene = null

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

func goto_scene(path):
	call_deferred("_deferred_goto_scene", path)

func _deferred_goto_scene(path):
	current_scene.free()
	var new_scene = load(path).instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene = new_scene

func return_to_main_hub():
	goto_scene("res://scenes/MainHub.tscn")

func go_to_purchase_scene():
	goto_scene("res://scenes/PurchaseScene.tscn")

func go_to_main_scene():
	goto_scene("res://scenes/MainScene.tscn")

func go_to_challenge_scene():
	goto_scene("res://scenes/ChallengeScene.tscn")

func go_to_blackjack_scene():
	goto_scene("res://scenes/BlackjackScene.tscn")

func go_to_slot_machine():
	goto_scene("res://scenes/SlotMachineScene.tscn")

func go_to_player_personalisation_scene():
	goto_scene("res://scenes/PlayerPersonalisationScene.tscn")

func go_to_login_scene():
	goto_scene("res://scenes/LoginScene.tscn")

func go_to_user_profile_scene():
	goto_scene("res://scenes/UserProfileScene.tscn")

func go_to_friend_system():
	goto_scene("res://scenes/FriendSystemScene.tscn")
