# SearchResultItem.gd
extends Control

signal add_friend_pressed(user_id)

@onready var username_label = $UserInfo/Username
@onready var level_label = $UserInfo/LevelLabel
@onready var avatar_display = $AvatarDisplay
@onready var add_friend_button = $AddFriendButton
@onready var status_label = $StatusLabel

var user_data = {}
var friendship_status = "none"  # none, pending, accepted, rejected

func setup(data: Dictionary, current_friendship_status: String = "none"):
	# Debug print
	print("Setting up SearchResultItem with data:", data)
	
	if not data.has("id"):
		push_error("SearchResultItem data missing required 'id' field")
		return
	if not data.has("username"):
		push_error("SearchResultItem data missing required 'username' field")
		return
	
	user_data = data
	friendship_status = current_friendship_status
	
	# Ensure all nodes exist before accessing
	if not username_label or not level_label or not avatar_display or not add_friend_button or not status_label:
		push_error("Required nodes not found in SearchResultItem")
		return
		
	username_label.text = data.username
	
	# Only show level if it exists
	if data.has("level"):
		level_label.text = "Level " + str(data.level)
		level_label.show()
	else:
		level_label.hide()
	
	# Update button/status based on friendship status
	update_friendship_status(friendship_status)
	
	# Show online status if available
	var status_indicator = get_node_or_null("UserInfo/StatusIndicator")
	if status_indicator:
		if data.has("Status") and data.Status != null:
			var status_color = Color.GRAY
			match data.Status.status:
				"online":
					status_color = Color.GREEN
				"away":
					status_color = Color.YELLOW
			status_indicator.modulate = status_color
			status_indicator.show()
		else:
			status_indicator.hide()

func update_friendship_status(status: String):
	friendship_status = status
	match status:
		"none":
			add_friend_button.show()
			add_friend_button.disabled = false
			status_label.hide()
		"pending":
			add_friend_button.hide()
			status_label.text = "Request Pending"
			status_label.modulate = Color(1, 0.8, 0, 1) # Yellow
			status_label.show()
		"accepted":
			add_friend_button.hide()
			status_label.text = "Already Friends"
			status_label.modulate = Color(0, 0.8, 0, 1) # Green
			status_label.show()
		"rejected":
			# This state should be temporary as we're deleting rejected requests
			add_friend_button.show()
			add_friend_button.disabled = false
			status_label.hide()

func _on_add_friend_button_pressed():
	print("Add Friend button pressed for user_id:", user_data.id)
	if friendship_status == "none":
		add_friend_button.disabled = true
		emit_signal("add_friend_pressed", user_data.id)
		print("Emitted add_friend_pressed signal for user_id:", user_data.id)

func update_avatar(avatar_data: Dictionary):
	# Implementation will depend on your avatar system
	pass
