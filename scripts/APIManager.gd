extends Node

signal login_completed(success, message)
signal user_data_received(data)
signal token_refreshed(new_token)
signal profile_update_completed(success, message)
signal email_verification_completed(success, message)
signal package_purchase_completed(success, data)
signal balance_update_completed(success, message)
signal search_results_received(results)
signal friend_request_sent(success, data)
signal friend_request_received(request)
signal friend_request_accepted(response)
signal friend_request_rejected(response)
signal message_sent(message)
signal message_received(message)
signal messages_marked_read(friend_id)
signal chat_history_received(messages)

var api_url: String
var is_development: bool = true
var EC2_IP = "13.60.228.103"
var user_token = ""
var refresh_token = ""
var user_data = {}
var pending_balance_update = 0
var request_queue = []
var is_processing_queue = false
var last_request_time = 0.0
var min_request_interval = 1.0  # Minimum time between requests in seconds
var rate_limit_reset_time = 0.0
var rate_limit_remaining = 20
var rate_limit_window = 900.0
var last_login_attempt = 0.0

func get_correct_api_url(endpoint: String) -> String:
	var base = api_url.strip_edges().trim_suffix("/")
	if base.ends_with("/api"):
		base = base.trim_suffix("/api")
	
	# Make sure endpoint starts with a slash
	if not endpoint.begins_with("/"):
		endpoint = "/" + endpoint
	
	return base + "/api" + endpoint

func _ready():
	api_url = ConfigManager.api_url
	print("APIManager initialized with URL: ", api_url)

# Update your error handling to use the new logging system
# Example for a network request:
func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		ConfigManager.log(
			"API request failed. Code: %d, Body: %s" % [response_code, body.get_string_from_utf8()],
			"error"
		)
		return
		
	ConfigManager.log("API request successful", "debug")

func _update_rate_limits(headers: PackedStringArray) -> void:
	for header in headers:
		if header.begins_with("RateLimit-Reset:"):
			var reset_time = int(header.split(":")[1].strip_edges())
			rate_limit_reset_time = Time.get_unix_time_from_system() + reset_time
		elif header.begins_with("RateLimit-Remaining:"):
			rate_limit_remaining = int(header.split(":")[1].strip_edges())
		elif header.begins_with("RateLimit-Policy:"):
			var policy = header.split(":")[1].strip_edges()
			var window = policy.split(";")[1].split("=")[1]
			rate_limit_window = float(window)
	
	print("Rate limit updated - Remaining: %d, Reset in: %d seconds" % 
		  [rate_limit_remaining, rate_limit_reset_time - Time.get_unix_time_from_system()])

func can_attempt_login() -> Dictionary:
	var current_time = Time.get_unix_time_from_system()
	
	# If we're rate limited
	if current_time < rate_limit_reset_time:
		var wait_time = rate_limit_reset_time - current_time
		var minutes = floor(wait_time / 60)
		var seconds = int(wait_time) % 60
		return {
			"can_login": false,
			"message": "Please wait %d:%02d before trying again" % [minutes, seconds]
		}
	
	# If we have attempts remaining
	if rate_limit_remaining > 0:
		return {
			"can_login": true,
			"message": ""
		}
	
	return {
		"can_login": false,
		"message": "No login attempts remaining. Please try again later."
	}

func login(username: String, password: String) -> void:
	var request_id = Time.get_unix_time_from_system()
	print("Debug: Starting login request %d" % request_id)
	
	var full_url = get_correct_api_url("/auth/login")
	
	print("Debug - Base URL: ", api_url)
	print("Debug - Full URL: ", full_url)
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_login_request_completed"))
	
	# Disable SSL verification for development
	if is_development:
		http_request.set_tls_options(TLSOptions.client())
	
	var body = JSON.stringify({"username": username, "password": password})
	var headers = ["Content-Type: application/json"]
	print("Debug: Login request %d - sending to URL: %s" % [request_id, full_url])
	print("Debug: Login request %d - headers: %s" % [request_id, headers])
	print("Debug: Login request %d - body: %s" % [request_id, body])
	
	var error = http_request.request(full_url, headers, HTTPClient.METHOD_POST, body)
	
	match error:
		OK:
			print("Debug: Login request %d sent successfully" % request_id)
		ERR_CANT_CONNECT:
			print("Debug: Login request %d - Failed to connect to host: %s" % [request_id, full_url])
			emit_signal("login_completed", false, "Could not connect to server")
			http_request.queue_free()
		ERR_CANT_RESOLVE:
			print("Debug: Login request %d - Could not resolve hostname: %s" % [request_id, full_url])
			emit_signal("login_completed", false, "Could not resolve server address")
			http_request.queue_free()
		_:
			print("Debug: Login request %d failed with error code: %d" % [request_id, error])
			emit_signal("login_completed", false, "Connection error: " + str(error))
			http_request.queue_free()

func _on_login_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("Login request completed")
	print("Result code: ", result)
	print("HTTP Response code: ", response_code)
	print("Response headers: ", headers)
	print("Raw response: ", body.get_string_from_utf8())
	
	var result_message = ""
	match result:
		HTTPRequest.RESULT_SUCCESS: result_message = "Success"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: result_message = "Chunked body size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT: result_message = "Can't connect"
		HTTPRequest.RESULT_CANT_RESOLVE: result_message = "Can't resolve"
		HTTPRequest.RESULT_CONNECTION_ERROR: result_message = "Connection error"
		HTTPRequest.RESULT_NO_RESPONSE: result_message = "No response"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: result_message = "Body size limit exceeded"
		HTTPRequest.RESULT_REQUEST_FAILED: result_message = "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: result_message = "Download file can't open"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: result_message = "Download file write error"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: result_message = "Redirect limit reached"
		_: result_message = "Unknown result code: " + str(result)
	
	print("Result meaning: ", result_message)
	var response_text = body.get_string_from_utf8()
	print("Raw response: ", response_text)
	
	var http_request = get_node_or_null("HTTPRequest")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Request failed with result: ", result)
		emit_signal("login_completed", false, "Connection failed: " + result_message)
		if http_request:
			http_request.queue_free()
		return
	
	if response_code == 401:
		emit_signal("login_completed", false, "Invalid credentials")
	elif response_code == 200:
		var json = JSON.parse_string(response_text)
		if json == null:
			emit_signal("login_completed", false, "Invalid server response")
		else:
			user_token = json.get("token", "")
			refresh_token = json.get("refreshToken", "")
			User.handle_login_success(json)
			emit_signal("login_completed", true, "Login successful")
	else:
		# Try to get more detailed error message from response
		var error_msg = "Server error: " + str(response_code)
		var json = JSON.parse_string(response_text)
		if json != null and json.has("error"):
			error_msg = json["error"]
		emit_signal("login_completed", false, error_msg)

	if http_request:
		http_request.queue_free()

func handle_google_signin():
	if OS.get_name() == "iOS":
		var google_signin = Engine.get_singleton("GoogleSignIn")
		if google_signin:
			google_signin.signIn()
			# Connect signal for auth result
			google_signin.connect("auth_result", _on_google_auth_result)

func _on_google_auth_result(token: String, error: String):
	if error.is_empty():
		# Send token to your backend
		login_with_google_token(token)
	else:
		emit_signal("login_completed", false, error)

func login_with_google_token(token: String):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_google_token_login_completed)
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"token": token})
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)

func _on_google_token_login_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if response_code == 200 and json.has("token"):
		user_token = json.token
		User.handle_login_success(json)
		emit_signal("login_completed", true, "Success")
	else:
		emit_signal("login_completed", false, "Google authentication failed")

func get_user_data():
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_get_user_data_completed"))

	var headers = ["Content-Type: application/json", "Authorization: Bearer " + user_token]
	
	# Updated URL to include the /api prefix
	var url = api_url + "/api/auth/user"
	print("Debug: Getting user data from URL: " + url)
	
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_get_user_data_completed(result, response_code: int, headers, body: PackedByteArray):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
		if json is Dictionary:
			# Only update if we don't have a pending balance update
			if pending_balance_update == 0:
				user_data = json
				emit_signal("user_data_received", json)
			else:
				print("Debug: Ignoring user data update due to pending balance update")
		else:
			push_error("Received user data is not a dictionary")
			emit_signal("user_data_received", {})
	elif response_code == 401:
		refresh_auth_token()
	else:
		push_error("Failed to get user data: " + str(json))
		emit_signal("user_data_received", {})
	
	if http_request:
		http_request.queue_free()

func refresh_auth_token():
	if refresh_token.is_empty():
		push_error("No refresh token available. Please login again.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_refresh_token_completed"))

	var body = JSON.stringify({"refreshToken": refresh_token})
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_refresh_token_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())
	if response_code == 200:
		user_token = json.token
		emit_signal("token_refreshed", user_token)
	else:
		push_error("Failed to refresh token: " + str(json))

	if http_request:
		http_request.queue_free()

func logout():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_logout_completed"))

	var headers = ["Content-Type: application/json", "Authorization: Bearer " + user_token]
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_logout_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	user_token = ""
	refresh_token = ""
	user_data = {}
	print("Logged out successfully")

	if http_request:
		http_request.queue_free()

func update_user_profile(update_data: Dictionary):
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_update_profile_completed"))

	var headers = ["Content-Type: application/json", "Authorization: Bearer " + user_token]
	var body = JSON.stringify(update_data)
	
	# Updated URL to include the /api prefix
	var url = api_url + "/api/auth/update-profile"
	print("Debug: Sending profile update to URL: " + url)
	
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_update_profile_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var response_text = body.get_string_from_utf8()
	print("Profile update response: ", response_text)  # Debug print
	
	var json = JSON.parse_string(response_text)
	if json == null:
		print("Failed to parse JSON response")
		emit_signal("profile_update_completed", false, "Failed to parse server response")
	elif response_code == 200:
		emit_signal("profile_update_completed", true, "Profile updated successfully")
	else:
		var error_message = "Failed to update profile"
		if json is Dictionary and json.has("message"):
			error_message = json.message
		emit_signal("profile_update_completed", false, error_message)

	if http_request:
		http_request.queue_free()

func verify_email(verification_token: String):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_email_verification_completed"))

	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"token": verification_token})
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_email_verification_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())
	if response_code == 200:
		emit_signal("email_verification_completed", true, "Email verified successfully")
	else:
		emit_signal("email_verification_completed", false, json.message if json.has("message") else "Failed to verify email")

	if http_request:
		http_request.queue_free()

func purchase_package(package_data: Dictionary):
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		emit_signal("package_purchase_completed", false, {"message": "No user token available."})
		return
	
	# Debug: Print the package_data to ensure 'price' exists
	print("Attempting to purchase package with data:", package_data)
	
	# Validate required keys
	var required_keys = ["chips", "gems", "price"]
	for key in required_keys:
		if not package_data.has(key):
			push_error("Package data is missing required key: " + key)
			emit_signal("package_purchase_completed", false, {"message": "Missing key: " + key})
			return
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_package_purchase_completed"))
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + user_token]
	var body = JSON.stringify({
		"chips": package_data["chips"],
		"gems": package_data["gems"],
		"price": package_data["price"]
	})
	
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	   
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		emit_signal("package_purchase_completed", false, {"message": "HTTP request failed."})
		http_request.queue_free()

func _on_package_purchase_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var response_text = body.get_string_from_utf8()
	print("Purchase response code:", response_code)
	print("Purchase response body:", response_text)
	
	# Parse the JSON response directly
	var data = JSON.parse_string(response_text)
	if data == null:
		push_error("Failed to parse JSON response from server.")
		emit_signal("package_purchase_completed", false, {"message": "Invalid server response."})
	else:
		if response_code == 200:
			if data.has("new_balance") and data.has("new_gems"):
				PlayerData.player_data["total_balance"] = data["new_balance"]
				PlayerData.player_data["gems"] = data["new_gems"]
				emit_signal("package_purchase_completed", true, data)
				print("Package purchased successfully. New Balance:", data["new_balance"], "New Gems:", data["new_gems"])
			else:
				push_error("Server response missing 'new_balance' or 'new_gems'.")
				emit_signal("package_purchase_completed", false, {"message": "Incomplete server response."})
		else:
			var error_message = data.get("message", "Unknown error occurred.")
			push_error("Purchase failed: " + error_message)
			emit_signal("package_purchase_completed", false, {"message": error_message})
	
	if http_request:
		http_request.queue_free()

func update_server_balance(new_balance: int):
	print("Debug: APIManager updating server balance:")
	print("- New balance to set:", new_balance)
	
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		emit_signal("balance_update_completed", false, "No user token available")
		return
		
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_balance_update_completed"))
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + user_token]
	var body = JSON.stringify({
		"balance": new_balance
	})
	
	print("Debug: Sending balance update request")
	print("Debug: Request body:", body)
	print("Debug: Request URL:", api_url + "/api/balance/update-chips")  
	
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)

func _on_balance_update_completed(result, response_code: int, headers, body: PackedByteArray):
	print("Debug: Balance update response received")
	print("Debug: Response code:", response_code)
	print("Debug: Raw response:", body.get_string_from_utf8())
	
	var http_request = get_node_or_null("HTTPRequest")
	
	if response_code == 200:
		print("Debug: Balance update successful")
		pending_balance_update = 0
		emit_signal("balance_update_completed", true, "Balance updated successfully")
	else:
		var error_message = "Failed to update balance"
		var response_text = body.get_string_from_utf8()
		if not response_text.is_empty():
			var json = JSON.parse_string(response_text)
			if json and json.has("message"):
				error_message = json["message"]
		print("Debug: Balance update failed:", error_message)
		emit_signal("balance_update_completed", false, error_message)
	
	if http_request:
		http_request.queue_free()

# User Search
func search_users(query: String):
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_search_users_completed)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + user_token
	]
	
	# Remove the extra 'api/' from the path
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_search_users_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	
	# Debug: Print raw response
	print("Search response code:", response_code)
	print("Raw response:", body.get_string_from_utf8())
	
	# Only try to parse JSON if we got a successful response
	if response_code == 200:
		var response_text = body.get_string_from_utf8()
		var json = JSON.new()
		var error = json.parse(response_text)
		
		if error == OK:
			var data = json.get_data()
			emit_signal("search_results_received", data)
		else:
			push_error("Failed to parse search results JSON: " + json.get_error_message())
	else:
		push_error("Search request failed with code: " + str(response_code))

	if http_request:
		http_request.queue_free()

# Friend Requests
func send_friend_request(friend_id: int) -> void:
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_friend_request_sent_completed"))

	var body = JSON.stringify({"friendId": friend_id})
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + user_token
	]
	
	print("Sending friend request with body:", body)  # Debug print
	
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		emit_signal("friend_request_sent", false, {"message": "Failed to send request"})

func _on_friend_request_sent_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	
	# Debug prints
	print("Friend request response code:", response_code)
	print("Friend request response body:", body.get_string_from_utf8())
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 and json != null:
		print("Friend request successful:", json)  # Debug print
		emit_signal("friend_request_sent", true, json)
	else:
		var error_message = "Failed to send friend request"
		if json != null and json.has("message"):
			error_message = json.message
		push_error(error_message)
		emit_signal("friend_request_sent", false, {"message": error_message})
	
	if http_request:
		http_request.queue_free()

func get_user_friends():
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_get_user_friends_completed"))

	var headers = ["Content-Type: application/json", "Authorization: Bearer " + user_token]
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_get_user_friends_completed(result, response_code, headers, body: PackedByteArray):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())

	if response_code == 200:
		emit_signal("user_data_received", json)  # Emit signal so front-end can update
	else:
		push_error("Failed to get user friends data: " + str(json))

	if http_request:
		http_request.queue_free()

func get_pending_friend_requests():
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_get_pending_requests_completed"))

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + user_token
	]

	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)

	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_get_pending_requests_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	
	var response_text = body.get_string_from_utf8()
	print("Pending requests response code:", response_code)
	print("Pending requests response body:", response_text)
	
	if response_code == 200:
		var json = JSON.parse_string(response_text)
		if json != null:
			print("Parsed pending requests:", json)  # Debug print
			emit_signal("friend_request_received", json)
		else:
			push_error("Failed to parse pending requests response")
	else:
		push_error("Failed to get pending friend requests")
	
	if http_request:
		http_request.queue_free()

# Friend Request Response
func respond_to_friend_request(request_id: int, status: String):
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_friend_request_response_completed)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + user_token
	]
	var body = JSON.stringify({"status": status})
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_friend_request_response_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())
	print("Friend request response data:", json) # Debug print
	
	if response_code == 200 and json != null:
		# Even if request is deleted, we'll still get a response with the friendship ID
		if json.has("friendship"):
			print("Processing friendship status:", json.friendship.status)
			if json.friendship.status == "accepted":
				emit_signal("friend_request_accepted", json)
			elif json.friendship.status == "rejected":
				# We still emit the signal with the friendship ID so UI can be updated
				emit_signal("friend_request_rejected", json)
			else:
				push_error("Unknown friendship status: " + json.friendship.status)
		else:
			push_error("Response missing friendship data")
	else:
		push_error("Failed to respond to friend request")
	
	if http_request:
		http_request.queue_free()

# Messaging
func send_message(receiver_id: int, content: String):
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_message_sent_completed)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + user_token
	]
	var body = JSON.stringify({
		"receiverId": receiver_id,
		"content": content
	})
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_message_sent_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 and json != null:
		emit_signal("message_sent", json)
	else:
		push_error("Failed to send message")
	
	if http_request:
		http_request.queue_free()

# Chat History
func get_chat_history(friend_id: int, page: int = 1):
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_chat_history_completed)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + user_token
	]
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_chat_history_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 and json != null:
		emit_signal("chat_history_received", json)
	else:
		push_error("Failed to get chat history")
	
	if http_request:
		http_request.queue_free()

# Mark Messages as Read
func mark_messages_as_read(friend_id: int):
	if user_token.is_empty():
		push_error("No user token available. Please login first.")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_mark_messages_read_completed)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + user_token
	]
	var error = http_request.request(get_correct_api_url("/auth/user"), headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		http_request.queue_free()

func _on_mark_messages_read_completed(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
		emit_signal("messages_marked_read", json)
	else:
		push_error("Failed to mark messages as read")
	
	if http_request:
		http_request.queue_free()

func test_endpoints():
	print("Debug: Testing API endpoints")
	
	var test_endpoints = [
		"/user/update-chips",
		"/user/update-balance",
		"/auth/update-balance",
		"/user/balance"
	]
	
	for endpoint in test_endpoints:
		var http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.connect("request_completed", 
			func(result, response_code, headers, body): _on_test_endpoint_completed(endpoint, result, response_code, headers, body)
		)
		
		var headers = ["Content-Type: application/json", "Authorization: Bearer " + user_token]
		print("Debug: Testing endpoint:", get_correct_api_url(endpoint))
		
		# Try both GET and PUT methods
		for method in [HTTPClient.METHOD_GET, HTTPClient.METHOD_PUT]:
			var method_name = "GET" if method == HTTPClient.METHOD_GET else "PUT"
			print("Debug: Testing %s %s" % [method_name, endpoint])
			
			# Only include body for PUT requests
			var body = ""
			if method == HTTPClient.METHOD_PUT:
				body = JSON.stringify({
					"chips": 220000,
					"user_id": user_data.get("id", null)
				})
			
			var url = get_correct_api_url(endpoint)
			var error = http_request.request(url, headers, method, body if method == HTTPClient.METHOD_PUT else "")
			
			if error != OK:
				print("Debug: Error testing %s %s: %s" % [method_name, endpoint, error])

func _on_test_endpoint_completed(endpoint: String, result, response_code: int, headers, body: PackedByteArray):
	var response_text = body.get_string_from_utf8()
	print("Debug: Response for %s:" % endpoint)
	print("Debug: Response code:", response_code)
	print("Debug: Response headers:", headers)
	print("Debug: Response body:", response_text)
	print("-----------------")

func queue_request(request_data: Dictionary) -> void:
	# Just send the request immediately
	send_request(request_data)

func send_request(request_data: Dictionary) -> void:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(
		func(result, response_code, headers, body): 
			_on_queued_request_completed(result, response_code, headers, body, request_data)
	)
	
	var error = http_request.request(
		request_data.url,
		request_data.headers,
		request_data.method,
		request_data.body
	)
	
	if error != OK:
		push_error("Failed to send request: " + str(error))
		http_request.queue_free()

func process_request_queue() -> void:
	if request_queue.is_empty():
		is_processing_queue = false
		return
		
	var current_time = Time.get_unix_time_from_system()
	
	# Check if we're rate limited
	if rate_limit_reset_time > current_time:
		print("Rate limited. Waiting %d seconds..." % int(rate_limit_reset_time - current_time))
		await get_tree().create_timer(rate_limit_reset_time - current_time).timeout
		current_time = Time.get_unix_time_from_system()
	
	# Ensure minimum interval between requests
	if current_time - last_request_time < min_request_interval:
		await get_tree().create_timer(min_request_interval - (current_time - last_request_time)).timeout
	
	is_processing_queue = true
	var request = request_queue.pop_front()
	
	# Create and send the request
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(
		func(result, response_code, headers, body): 
			_on_queued_request_completed(result, response_code, headers, body, request)
	)
	
	var error = http_request.request(
		request.url,
		request.headers,
		request.method,
		request.body
	)
	
	if error != OK:
		push_error("Failed to send request: " + str(error))
		http_request.queue_free()
		process_request_queue()
	
	last_request_time = Time.get_unix_time_from_system()

func _on_queued_request_completed(result, response_code, headers, body, request):
	var http_request = get_node_or_null("HTTPRequest")
	
	# Always call the completion callback regardless of response code
	if request.has("completion_callback"):
		request.completion_callback.call(result, response_code, headers, body)
	
	if http_request:
		http_request.queue_free()
