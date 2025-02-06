# ChallengeProgressButton.gd
extends Control

signal pressed

@onready var progress_bar = $HBoxContainer/ProgressBar
@onready var points_label = $PointsLabel
@onready var tier_icon = $TierIcon

var current_points: int = 0
var next_milestone: int = 0
var _is_setup_complete := false

func _ready():
	custom_minimum_size = Vector2(790, 90)
	if not is_inside_tree():
		await tree_entered
	
	if not _is_setup_complete:
		call_deferred("_setup_component")

func _setup_component():
	if _is_setup_complete:
		return

	# Add these lines
	size = Vector2(790, 90)
	custom_minimum_size = Vector2(790, 90)
	
	if is_instance_valid(progress_bar):
		progress_bar.custom_minimum_size = Vector2(700, 60)

	var nodes_valid = await _verify_required_nodes()
	if not nodes_valid:
		push_error("ChallengeProgressButton: Required nodes verification failed")
		return

	# Make progress bar clickable
	progress_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	progress_bar.gui_input.connect(_on_progress_bar_gui_input)
	
	# Set up the progress bar styling
	_setup_progress_bar()
	
	# Update initial display
	update_progress_display()
	
	_is_setup_complete = true

func _verify_required_nodes() -> bool:
	await get_tree().process_frame
	
	var has_all_nodes = true
	
	if not is_instance_valid(progress_bar):
		push_error("ProgressBar node not found")
		progress_bar = get_node_or_null("ProgressBar")
		has_all_nodes = false
	
	if not is_instance_valid(points_label):
		push_error("PointsLabel node not found")
		points_label = get_node_or_null("PointsLabel")
		has_all_nodes = false
		
	if not is_instance_valid(tier_icon):
		push_error("TierIcon node not found")
		tier_icon = get_node_or_null("TierIcon")
		has_all_nodes = false
	
	return has_all_nodes

func _setup_progress_bar():
	if not is_instance_valid(progress_bar):
		push_error("Cannot setup ProgressBar: node is null")
		return

	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(100, 40)

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.8, 0.8, 0.8, 0.5)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5

	progress_bar.add_theme_stylebox_override("background", style_box)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.7, 1.0, 0.8)
	fill_style.corner_radius_top_left = 5
	fill_style.corner_radius_top_right = 5
	fill_style.corner_radius_bottom_left = 5
	fill_style.corner_radius_bottom_right = 5

	progress_bar.add_theme_stylebox_override("fill", fill_style)

func update_challenge_data():
	if not _is_setup_complete:
		await _setup_component()
	
	if not is_instance_valid(progress_bar):
		push_error("Cannot update challenge data: ProgressBar node is null")
		return
	
	current_points = PlayerData.player_data["challenge_points"]
	
	# Get next milestone and update progress bar
	next_milestone = ChallengesManager.get_next_milestone(current_points)
	if next_milestone != null:
		progress_bar.min_value = 0
		progress_bar.max_value = next_milestone
		progress_bar.value = current_points
	else:
		# Handle case where all milestones are complete
		progress_bar.value = progress_bar.max_value
	
	# Update points display
	points_label.text = str(current_points)
	
	# Update tier icon (placeholder until tier system is implemented)
	_update_tier_icon(current_points)

func _update_tier_icon(points: int):
	# Placeholder tier calculation - update this when implementing tier system
	var tier = 1  # Default to tier 1
	var texture_path = "res://assets/icons/tier_%d.png" % tier
	
	var texture = load(texture_path)
	if texture:
		tier_icon.texture = texture
	else:
		push_error("Failed to load tier icon: " + texture_path)

func _on_progress_bar_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("pressed")

func update_progress_display():
	if not _is_setup_complete:
		await _setup_component()
	update_challenge_data()
	queue_redraw()
