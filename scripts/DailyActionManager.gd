extends Node

signal daily_tasks_updated
signal task_progress_updated(task_id: String, progress: float)

const RESET_HOUR_UTC := 0  # midnight UTC
const TOTAL_DAILY_TASKS := 4

var current_tasks := {}
var task_progress := {}

func _ready() -> void:
	# Load saved progress if exists
	load_progress()
	
	# Check if tasks need to be reset
	if should_reset_tasks():
		reset_daily_tasks()

func should_reset_tasks() -> bool:
	# Get the current UTC time
	var current_time = Time.get_unix_time_from_system()
	
	# Get the last reset time from player data
	var last_reset_time = User.get_current_user_data().get("last_daily_action_reset", 0)
	
	# Check if 24 hours have passed or if we've never reset
	if current_time - last_reset_time >= 86400 or last_reset_time == 0:
		# Save the current time as the last reset time
		var user_data = User.get_current_user_data()
		user_data["last_daily_action_reset"] = current_time
		User.save_user_data(user_data)
		return true
	
	return false

func reset_daily_tasks() -> void:
	# Clear progress
	task_progress.clear()
	
	# Generate new tasks for the day
	current_tasks = generate_daily_tasks()
	save_progress()
	
	emit_signal("daily_tasks_updated")

func generate_daily_tasks() -> Dictionary:
	# For now, return hardcoded example tasks
	# Later this will come from the server
	return {
		"task1": {
			"name": "Put in the work",
			"description": "Play 20 hands of table games",
			"required_progress": 20.0,
			"action_points": 100
		},
		"task2": {
			"name": "Do some pick-ups",
			"description": "Gain enough flash to open 4 packs",
			"required_progress": 4.0,
			"action_points": 50
		},
		"task3": {
			"name": "Make some walk-around money",
			"description": "Play 100 hands of table games",
			"required_progress": 100.0,
			"action_points": 200
		},
		"task4": {
			"name": "Get yourself a new look",
			"description": "Customize your character with an item from your packs",
			"required_progress": 1.0,
			"action_points": 150
		}
	}

func update_task_progress(task_id: String, progress: float) -> void:
	if task_id in current_tasks:
		task_progress[task_id] = min(progress, current_tasks[task_id].required_progress)
		save_progress()
		emit_signal("task_progress_updated", task_id, task_progress[task_id])

func get_task_progress(task_id: String) -> float:
	return task_progress.get(task_id, 0.0)

func save_progress() -> void:
	# Save to user preferences for now
	# Later this will sync with server
	pass

func load_progress() -> void:
	# Load from user preferences for now
	# Later this will sync with server
	pass
