extends Control

const JavaScript = preload("res://addons/javascript.gd")

var javascript_enabled := false

@onready var username_input = $VBoxContainer/UsernameInput
@onready var password_input = $VBoxContainer/PasswordInput
@onready var login_button = $VBoxContainer/LoginButton
@onready var signup_button = $VBoxContainer/SignupButton
@onready var google_button = $VBoxContainer/GoogleSignInButton
@onready var error_label = $VBoxContainer/ErrorLabel

func _ready():
	# Check for JavaScript availability
	javascript_enabled = OS.has_feature("web") and Engine.has_singleton("JavaScript")
	
	# Existing connections
	login_button.pressed.connect(_on_login_pressed)
	signup_button.pressed.connect(_on_signup_pressed)
	google_button.pressed.connect(_on_google_signin_pressed)
	
	# Get references to your LineEdit nodes
	var username_input = $VBoxContainer/UsernameInput
	var password_input = $VBoxContainer/PasswordInput
	
	# Username input optimization
	username_input.selecting_enabled = true
	username_input.context_menu_enabled = false
	username_input.clear_button_enabled = true
	username_input.shortcut_keys_enabled = false
	username_input.middle_mouse_paste_enabled = false
	
	# Password input optimization
	password_input.secret = true  # Ensures dots appear instead of characters
	password_input.selecting_enabled = true
	password_input.context_menu_enabled = false
	password_input.clear_button_enabled = false
	password_input.shortcut_keys_enabled = false
	password_input.middle_mouse_paste_enabled = false
	
	# Check Google Sign-In availability
	if OS.has_feature("web"):
		if not javascript_enabled:
			google_button.disabled = true
			google_button.tooltip_text = "JavaScript not available"
		elif not _check_google_auth_status():
			google_button.disabled = true
			google_button.tooltip_text = "Google Sign-In not available"
	
	APIManager.connect("login_completed", _on_login_completed)

func _on_google_signin_pressed():
	if OS.has_feature("web"):
		if javascript_enabled:
			var js = JavaScript.get_interface("window")
			js.open("/api/auth/google", "Google Sign In", 
				"width=500,height=600,menubar=no,toolbar=no")
		else:
			error_label.text = "JavaScript not available"
	else:
		error_label.text = "Google Sign-In is only available in web version"

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if OS.has_feature("web") and javascript_enabled:
			var js = JavaScript.get_interface("window")
			var token = js.get("pendingAuthToken")
			if token and str(token) != "":
				js.set("pendingAuthToken", "")
				_handle_successful_google_login({"token": str(token)})

func _check_google_auth_status() -> bool:
	if javascript_enabled:
		var js = JavaScript.get_interface("window")
		if js.has("gapi"):
			print("Google API loaded")
			return true
	return false

func _start_auth_polling():
	# Create polling timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1.0  # Poll every second
	timer.timeout.connect(_check_auth_status)
	timer.start()

func _check_auth_status():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_auth_status_response)
	
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(
		ConfigManager.api_url + "/api/auth/check-status",
		headers,
		HTTPClient.METHOD_GET
	)
	
	if error != OK:
		print("Error checking auth status")

func _on_auth_status_response(result, response_code, headers, body):
	if response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		if response and response.has("authenticated"):
			if response.authenticated:
				_handle_successful_google_login(response)
				# Stop polling
				get_node("Timer").queue_free()

func _handle_successful_google_login(response):
	# Store the authentication token
	APIManager.user_token = response.token
	APIManager.refresh_token = response.refresh_token
	
	# Update user data
	if response.has("user"):
		User.handle_login_success(response)
	
	# Navigate to main hub
	SceneManager.goto_scene("res://scenes/MainHub.tscn")

# Existing methods remain unchanged
func _on_login_pressed():
	var username = username_input.text
	var password = password_input.text
	
	if username.is_empty() or password.is_empty():
		error_label.text = "Please enter both username and password."
		return
	
	error_label.text = "Logging in..."
	APIManager.login(username, password)

func _on_signup_pressed():
	error_label.text = "Signup functionality not implemented yet."

func _on_login_completed(success: bool, message: String):
	if success:
		error_label.text = "Login successful!"
		SceneManager.goto_scene("res://scenes/MainHub.tscn")
	else:
		error_label.text = "Login failed: " + message
