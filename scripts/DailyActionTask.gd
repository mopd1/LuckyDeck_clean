extends PanelContainer

var task_id: String

@onready var task_name = $HBoxContainer/TaskName
@onready var task_description = $HBoxContainer/TaskDescription
@onready var action_points = $HBoxContainer/ActionPoints
@onready var progress_bar = $HBoxContainer/ProgressBar

func _ready() -> void:
	# Debug prints to check which nodes are found
	print("task_name node found: ", task_name != null)
	print("task_description node found: ", task_description != null)
	print("action_points node found: ", action_points != null)
	print("progress_bar node found: ", progress_bar != null)

func setup(id: String, data: Dictionary) -> void:
	print("Setting up task:", id)
	print("Task data:", data)
	
	# Add null checks
	if task_name == null or task_description == null or action_points == null or progress_bar == null:
		push_error("Some UI nodes not found in DailyActionTask")
		return
		
	task_id = id
	
	# Debug visibility
	print("TaskName visibility:", task_name.visible)
	print("TaskName modulate:", task_name.modulate)
	print("TaskName position:", task_name.position)
	print("TaskName size:", task_name.size)
	
	# Set the text values
	task_name.text = data["name"]
	print("TaskName text immediately after setting:", task_name.text)
	
	task_description.text = data["description"]
	print("TaskDescription text immediately after setting:", task_description.text)
	
	action_points.text = str(data["action_points"]) + " AP"
	print("ActionPoints text immediately after setting:", action_points.text)
	
	# Set progress bar values
	progress_bar.max_value = data["required_progress"]
	var current_progress = DailyActionManager.get_task_progress(task_id)
	progress_bar.value = current_progress

func update_progress(progress: float) -> void:
	if progress_bar:
		progress_bar.value = progress
