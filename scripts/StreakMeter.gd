extends Control

var progress_bar: ProgressBar
var current_streak = 0
const MAX_STREAK = 4

func _ready():
	# Make sure node is visible
	visible = true
	modulate.a = 1.0
	
	# Wait one frame to ensure node is ready
	await get_tree().process_frame
	
	progress_bar = get_node_or_null("ProgressBar")
	if not progress_bar:
		push_error("ProgressBar node not found in StreakMeter")
		return
	
	setup_progress_bar()
	reset_streak()

func setup_progress_bar():
	if not progress_bar:
		push_error("Cannot setup ProgressBar: node is null")
		return
	
	# Create default style
	var default_style = StyleBoxFlat.new()
	default_style.bg_color = Color(0.3, 0.7, 1.0, 0.8)  # Default blue color
	default_style.set_corner_radius_all(5)
	
	# Background style
	var background_style = StyleBoxFlat.new()
	background_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	background_style.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("background", background_style)
	
	# Set initial style
	progress_bar.add_theme_stylebox_override("fill", default_style)
	
	# Configure progress bar
	progress_bar.min_value = 0
	progress_bar.max_value = MAX_STREAK
	progress_bar.step = 1
	progress_bar.value = 0

func update_streak(new_streak: int):
	print("\nDebug - Streak Meter Update:")
	print("- Current streak: %d" % current_streak)
	print("- New streak: %d" % new_streak)
	
	if progress_bar:
		current_streak = new_streak
		progress_bar.value = min(current_streak, MAX_STREAK)
		print("- Updated progress bar value to: %d" % progress_bar.value)
	else:
		push_error("Progress bar not found when updating streak")

func reset_streak():
	if progress_bar:
		current_streak = 0
		progress_bar.value = 0
