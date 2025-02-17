extends Control

signal pressed

@onready var progress_bar = $HBoxContainer/ProgressBar
@onready var action_points_label = $ActionPointsLabel
@onready var book_icon = $BookIcon

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

	size = Vector2(790, 90)
	custom_minimum_size = Vector2(790, 90)
	
	if is_instance_valid(progress_bar):
		progress_bar.custom_minimum_size = Vector2(700, 60)

	var nodes_valid = await _verify_required_nodes()
	if not nodes_valid:
		push_error("BookButton: Required nodes verification failed")
		return

	# Make progress bar clickable
	progress_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Check if signal is already connected before connecting
	if not progress_bar.gui_input.is_connected(_on_progress_bar_gui_input):
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
		has_all_nodes = false
	
	if not is_instance_valid(action_points_label):
		push_error("ActionPointsLabel node not found")
		has_all_nodes = false
		
	if not is_instance_valid(book_icon):
		push_error("BookIcon node not found")
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

func update_book_data():
	if not _is_setup_complete:
		await _setup_component()
	
	if not is_instance_valid(progress_bar):
		push_error("Cannot update book data: ProgressBar node is null")
		return
	
	current_points = PlayerData.player_data["action_points"]
	
	# Get next milestone and update progress bar
	next_milestone = BookManager.get_next_milestone(current_points)
	if next_milestone != null:
		progress_bar.min_value = 0
		progress_bar.max_value = next_milestone
		progress_bar.value = current_points
	else:
		# Handle case where all milestones are complete
		progress_bar.value = progress_bar.max_value
	
	# Update points display
	action_points_label.text = str(current_points)

func _on_progress_bar_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Book button clicked!")
		emit_signal("pressed")

func update_progress_display():
	if not _is_setup_complete:
		await _setup_component()
	update_book_data()
	queue_redraw()


func _on_pressed() -> void:
	SceneManager.go_to_book_scene()
