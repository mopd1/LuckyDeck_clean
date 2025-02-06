# FriendItem.gd
extends Control

signal message_pressed(friend_id)

@onready var username_label = $UserInfo/Username
@onready var status_indicator = $UserInfo/StatusIndicator
@onready var message_button = $MessageButton
@onready var avatar_display = $AvatarDisplay

var friend_data = {}

func setup(data: Dictionary):
	friend_data = data
	# Check if the node exists before accessing its properties
	if username_label != null:
		username_label.text = data.username
	else:
		push_error("username_label is null. Ensure the node path is correct.")
	
	# Set online status
	if data.get("Status") and data.Status != null:
		status_indicator.modulate = Color.GREEN if data.Status.status == "online" else Color.RED
	else:
		status_indicator.modulate = Color.GRAY
		
	# Load avatar if available
	if data.get("avatar_data"):
		update_avatar(data.avatar_data)

func _on_message_button_pressed():
	emit_signal("message_pressed", friend_data.id)

func update_avatar(avatar_data: Dictionary):
	# Implementation will depend on your avatar system
	pass
