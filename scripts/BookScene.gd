extends Control

@onready var story_acts_box = $StoryContainer/StoryActsBox
@onready var standard_track_box = $RewardsContainer/StandardTrackBox
@onready var inside_track_box = $RewardsContainer/InsideTrackBox
@onready var return_button = $HeaderContainer/ReturnButton
@onready var purchase_inside_track_button = $HeaderContainer/PurchaseInsideTrackButton
@onready var action_points_label = $HeaderContainer/ActionPointsLabel

func _ready():
	setup_story_acts()
	setup_reward_tracks()
	update_display()
	
	# Connect signals
	if return_button:
		return_button.pressed.connect(_on_return_pressed)
	if purchase_inside_track_button:
		purchase_inside_track_button.pressed.connect(_on_purchase_inside_track)
		
	# Connect to PlayerData signals
	PlayerData.action_points_updated.connect(_on_action_points_updated)
	
func setup_story_acts():
	# Create story act buttons
	for i in range(BookManager.STORY_ACTS):  # Use constant instead of hardcoded 5
		var act_button = TextureButton.new()
		story_acts_box.add_child(act_button)
		act_button.connect("pressed", _on_story_act_pressed.bind(i + 1))
		
		# Set default texture (locked state)
		act_button.modulate = Color(0.5, 0.5, 0.5, 1.0)

func setup_reward_tracks():
	var BookRewardItem = preload("res://scenes/BookRewardItem.tscn")
	
	for i in range(BookManager.MILESTONES_PER_TRACK):  # Use constant instead of hardcoded 5
		# Standard track milestone
		var standard_milestone = BookRewardItem.instantiate()
		standard_track_box.add_child(standard_milestone)
		
		# Inside track milestone
		var inside_milestone = BookRewardItem.instantiate()
		inside_track_box.add_child(inside_milestone)
		
		# Configure milestones
		update_milestone(standard_milestone, i, false)
		update_milestone(inside_milestone, i, true)

func update_display():
	# Update action points display
	var points = PlayerData.get_action_points()
	action_points_label.text = "Action Points: %s" % points
	
	# Update milestone displays
	for i in range(standard_track_box.get_child_count()):
		update_milestone(standard_track_box.get_child(i), i, false)
		update_milestone(inside_track_box.get_child(i), i, true)
	
	# Update story acts
	update_story_acts()
	
	# Update Inside Track button
	purchase_inside_track_button.visible = not BookManager.has_inside_track_access()

func update_milestone(milestone_item, index: int, is_inside_track: bool):
	var milestone_data = BookManager.get_milestone_data(index, is_inside_track)
	var points = PlayerData.get_action_points()
	var claimed_milestones = BookManager.get_claimed_milestones()
	
	milestone_item.update(
		milestone_data,
		points >= milestone_data.required_points,
		index in claimed_milestones,
		is_inside_track and not BookManager.has_inside_track_access()
	)

func update_story_acts():
	var unlocked_acts = BookManager.get_unlocked_acts()
	for i in range(story_acts_box.get_child_count()):
		var act_button = story_acts_box.get_child(i)
		act_button.modulate = Color.WHITE if i + 1 in unlocked_acts else Color(0.5, 0.5, 0.5, 1.0)

func _on_story_act_pressed(act_number: int):
	var story_data = await BookManager.get_story_act_data(act_number)
	if story_data:
		show_story_popup(story_data)

func show_story_popup(story_data: Dictionary):
	var popup = AcceptDialog.new()
	add_child(popup)
	
	popup.title = "Story Act %s" % story_data.get("act_number", "")
	popup.dialog_text = story_data.get("content", "")
	popup.custom_minimum_size = Vector2(800, 600)
	
	popup.popup_centered()
	
	popup.confirmed.connect(func(): popup.queue_free())
	popup.canceled.connect(func(): popup.queue_free())

func _on_return_pressed():
	SceneManager.return_to_main_hub()

func _on_purchase_inside_track():
	if BookManager.purchase_inside_track():
		update_display()

func _on_action_points_updated(_points):
	update_display()
