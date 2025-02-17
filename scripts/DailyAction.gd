extends Control

@onready var tasks_container = $MarginContainer/VBoxContainer/TasksContainer
@onready var avatar_viewport = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/AvatarViewport
@onready var avatar_display = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/AvatarDisplay
@onready var avatar_scene = avatar_viewport.get_node("AvatarScene")

var avatar_layers = ["face", "clothing", "hair", "hat", "ear_accessories", "mouth_accessories"]

func _ready() -> void:
	DailyActionManager.connect("daily_tasks_updated", _on_daily_tasks_updated)
	DailyActionManager.connect("task_progress_updated", _on_task_progress_updated)
	
	# Set up avatar first
	_update_avatar_display()
	avatar_display.texture = avatar_viewport.get_texture()
	
	_refresh_tasks()

func _update_avatar_display() -> void:
	var avatar_data = PlayerData.get_avatar_data()
	if not avatar_data or avatar_data.size() == 0:
		print("No avatar data found.")
		return

	for layer in avatar_layers:
		var layer_name = layer.capitalize()  # e.g., "face" -> "Face"
		var sprite = avatar_scene.get_node(layer_name)
		if sprite and sprite is Sprite2D:
			if avatar_data.get(layer):
				var texture_path = "res://assets/avatars/" + layer + "/" + avatar_data[layer] + ".png"
				var texture = load(texture_path)
				if texture and texture is Texture2D:
					sprite.texture = texture
					sprite.visible = true
				else:
					push_error("Failed to load texture for " + layer + ": " + texture_path)
					sprite.visible = false
			else:
				sprite.visible = false
		else:
			push_error("Sprite node not found for layer: " + layer_name)

func _refresh_tasks() -> void:
	# Clear existing tasks
	for child in tasks_container.get_children():
		child.queue_free()
	
	# Add current tasks
	for task_id in DailyActionManager.current_tasks:
		var task_data = DailyActionManager.current_tasks[task_id]
		var task_instance = preload("res://scenes/DailyActionTask.tscn").instantiate()
		task_instance.setup(task_id, task_data)
		tasks_container.add_child(task_instance)

func _on_daily_tasks_updated() -> void:
	_refresh_tasks()

func _on_task_progress_updated(task_id: String, progress: float) -> void:
	# Update specific task progress bar
	for task in tasks_container.get_children():
		if task.task_id == task_id:
			task.update_progress(progress)
