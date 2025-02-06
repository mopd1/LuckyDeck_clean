# RequestItem.gd
extends Control

signal request_accepted(request_id)
signal request_rejected(request_id)

@onready var username_label = $UserInfo/Username
@onready var avatar_display = $AvatarDisplay
@onready var accept_button = $Buttons/AcceptButton
@onready var reject_button = $Buttons/RejectButton
@onready var timestamp_label = $UserInfo/TimestampLabel

var request_data = {}

func _ready():
	# Connect button signals
	accept_button.pressed.connect(_on_accept_button_pressed)
	reject_button.pressed.connect(_on_reject_button_pressed)

func setup(data: Dictionary):
	print("Setting up request item with data:", data)  # Debug print
	request_data = data
	
	# Handle user data
	if data.has("User") and data.User != null:
		username_label.text = data.User.username
	else:
		push_error("Request data missing User information")
		username_label.text = "Unknown User"
		
	# Set timestamp if available
	if data.has("createdAt"):
		var datetime = Time.get_datetime_dict_from_datetime_string(
			data.createdAt,
			true  # Use UTC
		)
		timestamp_label.text = "%d/%d/%d" % [datetime.day, datetime.month, datetime.year]
	else:
		timestamp_label.text = "Unknown Date"
	
	# Disable buttons if request is already handled
	if data.has("status") and data.status != "pending":
		accept_button.disabled = true
		reject_button.disabled = true

func _on_accept_button_pressed():
	accept_button.disabled = true
	reject_button.disabled = true
	emit_signal("request_accepted", request_data.id)

func _on_reject_button_pressed():
	accept_button.disabled = true
	reject_button.disabled = true
	emit_signal("request_rejected", request_data.id)

func update_avatar(avatar_data: Dictionary):
	# Implementation will depend on your avatar system
	pass

func update_status(new_status: String):
	request_data.status = new_status
	if new_status != "pending":
		accept_button.disabled = true
		reject_button.disabled = true
