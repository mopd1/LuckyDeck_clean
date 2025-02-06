extends Node

signal error_occurred(error_info)

# Error severity levels
enum ErrorSeverity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

# Store the last few errors for debugging
var error_history = []
const MAX_ERROR_HISTORY = 50

func _ready():
	# Set up error handling for unhandled errors
	get_tree().set_debug_collisions_hint(true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect to tree for catching errors
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node):
	# Add error handling to all nodes
	if not node.tree_exiting.is_connected(_on_node_error):
		node.tree_exiting.connect(_on_node_error.bind(node))

func _on_node_error(node: Node):
	if node.is_inside_tree():
		var error_info = {
			"node": node.name,
			"scene": node.get_tree().current_scene.name if node.get_tree().current_scene else "Unknown",
			"stack": get_stack(),
			"timestamp": Time.get_unix_time_from_system()
		}
		handle_error(error_info, ErrorSeverity.ERROR)

func handle_error(error_info: Dictionary, severity: ErrorSeverity):
	# Add to error history
	error_history.push_front(error_info)
	if error_history.size() > MAX_ERROR_HISTORY:
		error_history.pop_back()
	
	# Log the error
	var error_message = "Error in %s (Scene: %s)" % [error_info.node, error_info.scene]
	ConfigManager.log(error_message, "error")
	
	# In production, we might want to send this to a server
	if ConfigManager.is_production():
		_send_error_to_server(error_info)
	
	emit_signal("error_occurred", error_info)
	
	# Handle critical errors
	if severity == ErrorSeverity.CRITICAL:
		_handle_critical_error(error_info)

func _handle_critical_error(error_info: Dictionary):
	# In production, show a user-friendly error screen
	if ConfigManager.is_production():
		# Save any necessary data
		_save_crash_report(error_info)
		
		# Show error screen
		SceneManager.goto_scene("res://scenes/ErrorScene.tscn")
	else:
		# In development, print detailed info
		print_debug("Critical Error: ", error_info)
		breakpoint

func _save_crash_report(error_info: Dictionary):
	var file = FileAccess.open("user://crash_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(error_info))

func _send_error_to_server(error_info: Dictionary):
	# Here you would implement sending the error to your server
	# This is where you'd want to set up proper error tracking
	pass

# Helper function to get current stack trace
func get_stack() -> Array:
	var stack = []
	for stack_info in get_stack():
		stack.append({
			"function": stack_info.function,
			"file": stack_info.file,
			"line": stack_info.line
		})
	return stack
