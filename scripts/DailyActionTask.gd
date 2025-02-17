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
	# Add null checks
	if task_name == null or task_description == null or action_points == null or progress_bar == null:
		push_error("Some UI nodes not found in DailyActionTask")
		return
		
	task_id = id
	task_name.text = data.name
	task_description.text = data.description
	action_points.text = str(data.action_points) + " AP"
	
	progress_bar.max_value = data.required_progress
	progress_bar.value = DailyActionManager.get_task_progress(task_id)

func update_progress(progress: float) -> void:
	if progress_bar:
		progress_bar.value = progress
