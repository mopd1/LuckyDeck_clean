# MessageItem.gd
extends Control

@onready var message_content = $MessageContent
@onready var timestamp_label = $TimestampLabel
@onready var status_indicator = $StatusIndicator
@onready var avatar_display = $AvatarDisplay

var message_data = {}
var is_sender = false

func setup(data: Dictionary, is_current_user_sender: bool):
	message_data = data
	is_sender = is_current_user_sender
	
	# Set message content
	message_content.text = data.content
	
	# Format and set timestamp
	var datetime = Time.get_datetime_dict_from_datetime_string(
		data.createdAt,
		true  # Use UTC
	)
	timestamp_label.text = "%02d:%02d" % [datetime.hour, datetime.minute]
	
	# Align message based on sender/receiver
	if is_sender:
		# Align right for sender's messages
		set_sender_style()
	else:
		# Align left for received messages
		set_receiver_style()
	
	# Set message status
	update_status(data.status)
	
	# Load avatar if available (for received messages)
	if not is_sender and data.has("sender_avatar_data"):
		update_avatar(data.sender_avatar_data)

func set_sender_style():
	# Right align the message
	$Layout.alignment = BoxContainer.ALIGNMENT_END
	$Layout/MessageBubble.add_theme_stylebox_override("panel", get_sender_style())
	avatar_display.hide()
	status_indicator.show()

func set_receiver_style():
	# Left align the message
	$Layout.alignment = BoxContainer.ALIGNMENT_BEGIN
	$Layout/MessageBubble.add_theme_stylebox_override("panel", get_receiver_style())
	avatar_display.show()
	status_indicator.hide()

func get_sender_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.8, 1.0)  # Blue for sender
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func get_receiver_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.25, 1.0)  # Gray for receiver
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_right = 15
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func update_status(status: String):
	match status:
		"sent":
			status_indicator.texture = preload("res://assets/icons/sent.png")
			status_indicator.modulate = Color(0.7, 0.7, 0.7, 1.0)
		"delivered":
			status_indicator.texture = preload("res://assets/icons/delivered.png")
			status_indicator.modulate = Color(0.7, 0.7, 0.7, 1.0)
		"read":
			status_indicator.texture = preload("res://assets/icons/read.png")
			status_indicator.modulate = Color(0.2, 0.8, 0.2, 1.0)
	
	# Only show status for sender's messages
	status_indicator.visible = is_sender

func update_avatar(avatar_data: Dictionary):
	# Implementation will depend on your avatar system
	pass
