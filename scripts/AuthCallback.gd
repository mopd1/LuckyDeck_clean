extends Control

func _ready():
	# Get token from URL
	var token = OS.get_cmdline_args()[0] if OS.get_cmdline_args().size() > 0 else ""
	if token:
		APIManager.user_token = token
		# Verify token and redirect to main hub
		_verify_token()
	else:
		get_node("VBoxContainer/StatusLabel").text = "Authentication failed"

func _verify_token():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_token_verified)
	
	var headers = ["Authorization: Bearer " + APIManager.user_token]
	var error = http_request.request(
		ConfigManager.api_url + "/api/auth/verify-token",
		headers,
		HTTPClient.METHOD_GET
	)

func _on_token_verified(result, response_code, headers, body):
	if response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		if response and response.authenticated:
			SceneManager.goto_scene("res://scenes/MainHub.tscn")
		else:
			get_node("VBoxContainer/StatusLabel").text = "Token verification failed"
	else:
		get_node("VBoxContainer/StatusLabel").text = "Authentication error"
