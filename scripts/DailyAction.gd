extends Control

@onready var tasks_container = $MarginContainer/VBoxContainer/TasksContainer
@onready var avatar_viewport = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/AvatarViewport
@onready var avatar_display = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/AvatarDisplay
@onready var avatar_scene = avatar_viewport.get_node("AvatarScene")
@onready var return_button = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/ReturnButton
@onready var task1 = $MarginContainer/VBoxContainer/TasksContainer/DailyActionTask1
@onready var task2 = $MarginContainer/VBoxContainer/TasksContainer/DailyActionTask2
@onready var task3 = $MarginContainer/VBoxContainer/TasksContainer/DailyActionTask3
@onready var task4 = $MarginContainer/VBoxContainer/TasksContainer/DailyActionTask4

var avatar_layers = ["face", "clothing", "hair", "hat", "ear_accessories", "mouth_accessories"]
var task_instances = []  # Store references to task instances
var tasks = []  # To hold references to all tasks

func _ready() -> void:
	print("Checking task references:")
	print("task1:", task1 != null)
	print("task2:", task2 != null)
	print("task3:", task3 != null)
	print("task4:", task4 != null)
	
	tasks = [task1, task2, task3, task4]
	
	DailyActionManager.connect("daily_tasks_updated", _on_daily_tasks_updated)
	DailyActionManager.connect("task_progress_updated", _on_task_progress_updated)
	
	setup_avatar()
	avatar_display.texture = avatar_viewport.get_texture()
	
	DailyActionManager.reset_daily_tasks()

func setup_avatar() -> void:
	var avatar_data = PlayerData.get_avatar_data()
	if not avatar_data or avatar_data.size() == 0:
		return

	for layer in avatar_layers:
		var layer_name = layer.capitalize()
		var sprite = avatar_scene.get_node(layer_name)
		if sprite and sprite is Sprite2D:
			if avatar_data.get(layer):
				var texture_path = "res://assets/avatars/" + layer + "/" + avatar_data[layer] + ".png"
				var texture = load(texture_path)
				if texture and texture is Texture2D:
					sprite.texture = texture
					sprite.visible = true
				else:
					sprite.visible = false
			else:
				sprite.visible = false

func _setup_tasks() -> void:
	print("Starting _setup_tasks")
	print("Number of tasks:", tasks.size())
	
	var task_data = DailyActionManager.current_tasks
	var i = 0
	for task_id in task_data:
		print("Setting up task", i)
		if i < tasks.size():
			if tasks[i] == null:
				push_error("Task " + str(i) + " is null")
			else:
				tasks[i].setup(task_id, task_data[task_id])
		i += 1

func _on_daily_tasks_updated() -> void:
	_setup_tasks()

func _on_task_progress_updated(task_id: String, progress: float) -> void:
	for task in tasks:
		if task.task_id == task_id:
			task.update_progress(progress)

func _on_return_button_pressed() -> void:
	SceneManager.goto_scene("res://scenes/MainHub.tscn")
