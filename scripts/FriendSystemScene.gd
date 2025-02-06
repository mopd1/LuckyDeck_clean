# FriendSystemScene.gd
extends Control

signal friend_request_received(request)

# Scene preloads
var FriendItem = preload("res://scenes/FriendItem.tscn")
var RequestItem = preload("res://scenes/RequestItem.tscn")
var SearchResultItem = preload("res://scenes/SearchResultItem.tscn")
var MessageItem = preload("res://scenes/MessageItem.tscn")

# Onready variables
@onready var search_input = $MainContent/RightPanel/SearchSection/SearchContainer/SearchInput
@onready var search_button = $MainContent/RightPanel/SearchSection/SearchContainer/SearchButton
@onready var search_results = $MainContent/RightPanel/SearchSection/SearchResults
@onready var friend_list = $MainContent/LeftPanel/FriendList/FriendListContainer
@onready var friend_requests = $MainContent/LeftPanel/FriendRequests/RequestsContainer
@onready var chat_section = $MainContent/RightPanel/ChatSection
@onready var messages_container = $MainContent/RightPanel/ChatSection/MessagesContainer
@onready var message_input = $MainContent/RightPanel/ChatSection/MessageInputContainer/MessageInput
@onready var send_button = $MainContent/RightPanel/ChatSection/MessageInputContainer/SendButton
@onready var return_button = $Header/ReturnButton

# State variables
var current_chat_friend_id = null
var last_search_time = 0
var search_cooldown = 1.0  # 1 second cooldown between searches

func _ready():
	# Hide chat section initially
	chat_section.hide()
	
	# Connect signals
	connect_signals()
	
	# Load initial data
	load_friend_data()
	load_friend_requests()
	
	if not APIManager.is_connected("friend_request_sent", Callable(self, "_on_friend_request_sent")):
		APIManager.connect("friend_request_sent", Callable(self, "_on_friend_request_sent"))

	if not APIManager.is_connected("friend_request_received", Callable(self, "_on_friend_request_received")):
		APIManager.connect("friend_request_received", Callable(self, "_on_friend_request_received"))
	load_pending_requests()

func connect_signals():
	search_button.pressed.connect(_on_search_pressed)
	search_input.text_changed.connect(_on_search_input_changed)
	message_input.text_changed.connect(_on_message_input_changed)
	send_button.pressed.connect(_on_send_message_pressed)
	return_button.pressed.connect(_on_return_pressed)

	# Connect to APIManager signals
	APIManager.connect("search_results_received", _on_search_results_received)
	APIManager.connect("friend_request_sent", _on_friend_request_sent)
	APIManager.connect("friend_request_received", _on_friend_request_received)
	APIManager.connect("friend_request_accepted", _on_friend_request_accepted)
	APIManager.connect("friend_request_rejected", _on_friend_request_rejected)
	APIManager.connect("message_sent", _on_message_sent)
	APIManager.connect("message_received", _on_message_received)
	APIManager.connect("messages_marked_read", _on_messages_marked_read)

func load_friend_data():
	print("Reloading friends list...")
	# Get friends list from the API
	var token = APIManager.user_token
	var url = APIManager.API_URL + "/friends/list"
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.connect("request_completed", Callable(self, "_on_friends_data_received"))
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + token]
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_friends_data_received(result, response_code, headers, body):
	var http_request = get_node_or_null("HTTPRequest")
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	print("Received friends data:", json)
	
	if response_code == 200 and json is Array:
		# Clear existing friend list
		for child in friend_list.get_children():
			child.queue_free()
		
		# Add each friend to the list
		for friend_data in json:
			add_friend_to_list(friend_data)
			print("Added friend to list:", friend_data.username if friend_data.has("username") else "Unknown")
	else:
		push_error("Failed to load friends list")
	
	if http_request:
		http_request.queue_free()

func load_friend_requests():
	# Get pending friend requests from API
	var token = APIManager.user_token
	var url = APIManager.API_URL + "/friends/pending"
	# Make request to get pending requests

# Search functionality
func _on_search_input_changed(new_text: String):
	search_button.disabled = new_text.strip_edges().length() < 3

func _on_search_pressed():
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_search_time < search_cooldown:
		return
		
	last_search_time = current_time
	var search_term = search_input.text.strip_edges()
	if search_term.length() >= 3:
		APIManager.search_users(search_term)

func _on_search_results_received(results):
	# Clear previous results
	for child in search_results.get_children():
		child.queue_free()

	print("Processing search results:", results)  # Debug print

	# Add new results
	for result in results:
		var search_item = SearchResultItem.instantiate()
		if not search_item:
			push_error("Failed to instantiate SearchResultItem")
			continue

		# Add to scene tree before setup
		search_results.add_child(search_item)
		search_item.setup(result)
		search_item.connect("add_friend_pressed", _on_add_friend_pressed)

# Friend request handling
func _on_add_friend_pressed(friend_id: int):
	print("Sending friend request to user ID:", friend_id)  # Debug print
	APIManager.send_friend_request(friend_id)

func _on_friend_request_sent(success: bool, data: Dictionary):
	print("Friend request response:", success, data)  # Debug print
	
	if success and data.has("friendship"):
		var friendship = data.friendship
		
		# Update UI to show pending status
		for child in search_results.get_children():
			if child is Control and child.has_method("update_friendship_status"):
				if child.user_data.has("id") and child.user_data.id == friendship.friend_id:
					print("Updating status for user:", child.user_data.username)
					child.update_friendship_status("pending")
					break
	else:
		# Show error message to user
		if data.has("message"):
			push_error("Friend request failed: " + data.message)
		else:
			push_error("Friend request failed")

func load_pending_requests():
	APIManager.get_pending_friend_requests()

func _on_friend_request_received(requests):
	print("Received friend requests:", requests)  # Debug print
	
	# Clear existing request items
	for child in friend_requests.get_children():
		child.queue_free()
	
	# Handle the case where requests is an array
	if requests is Array:
		for request in requests:
			var request_item = RequestItem.instantiate()
			if request_item:
				friend_requests.add_child(request_item)
				request_item.setup(request)
				request_item.connect("request_accepted", _on_request_accepted)
				request_item.connect("request_rejected", _on_request_rejected)
	else:
		# Handle single request case (though this shouldn't happen with current API)
		push_error("Expected array of requests but got: " + str(typeof(requests)))

func _on_request_accepted(request_id):
	print("Request accepted signal received for ID:", request_id)
	APIManager.respond_to_friend_request(request_id, "accepted")

func _on_request_rejected(request_id):
	print("Request rejected signal received for ID:", request_id)
	APIManager.respond_to_friend_request(request_id, "rejected")

# Friend list handling
func add_friend_to_list(friend_data):
	var friend_item = FriendItem.instantiate()
	
	# Ensure the scene is added to the tree before calling setup
	if friend_item:
		friend_list.add_child(friend_item)
		friend_item.setup(friend_data)
	else:
		push_error("FriendItem failed to instantiate")


# Messaging functionality
func _on_friend_message_pressed(friend_id):
	current_chat_friend_id = friend_id
	chat_section.show()
	load_chat_history(friend_id)
	mark_messages_as_read(friend_id)

func _on_message_input_changed(new_text: String):
	send_button.disabled = new_text.strip_edges().is_empty()

func _on_send_message_pressed():
	if current_chat_friend_id == null:
		return
		
	var message = message_input.text.strip_edges()
	if not message.is_empty():
		APIManager.send_message(current_chat_friend_id, message)
		message_input.text = ""

func load_chat_history(friend_id):
	# Clear existing messages
	for child in messages_container.get_children():
		child.queue_free()
	
	# Load chat history from API
	APIManager.get_chat_history(friend_id)

func _on_message_sent(message_data):
	add_message_to_chat(message_data, true)

func _on_message_received(message_data):
	add_message_to_chat(message_data, false)
	if message_data.sender_id == current_chat_friend_id:
		mark_messages_as_read(current_chat_friend_id)

func add_message_to_chat(message_data: Dictionary, is_sender: bool):
	var message_item = MessageItem.instantiate()
	message_item.setup(message_data, is_sender)
	messages_container.add_child(message_item)
	
	# Scroll to bottom
	await get_tree().create_timer(0.1).timeout
	var scroll_container = messages_container.get_parent()
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func mark_messages_as_read(friend_id):
	APIManager.mark_messages_as_read(friend_id)

func _on_messages_marked_read(friend_id):
	# Update message status indicators
	for message in messages_container.get_children():
		if message.message_data.sender_id == friend_id:
			message.update_status("read")

func _on_friend_request_accepted(response_data):
	print("Processing friend request acceptance...")
	print("Response data:", response_data)
	
	if not response_data.has("friendship"):
		push_error("Response data missing friendship object")
		return
		
	print("Looking for request with ID:", response_data.friendship.id)
	
	# Remove the request from the requests list
	var request_found = false
	for child in friend_requests.get_children():
		if not is_instance_valid(child):
			continue
			
		if not (child is Control and "request_data" in child):
			continue
			
		if child.request_data.id == response_data.friendship.id:
			print("Found matching request, removing...")
			request_found = true
			child.queue_free()
			break
	
	if not request_found:
		print("No matching request found to remove")
	
	# Immediately reload the friends list
	load_friend_data()

func _on_friend_request_rejected(response_data):
	print("Processing friend request rejection...")
	print("Response data:", response_data)
	
	if not response_data.has("friendship"):
		push_error("Response data missing friendship object")
		return
		
	print("Looking for request with ID:", response_data.friendship.id)
	
	# Remove the request from the requests list
	var request_found = false
	for child in friend_requests.get_children():
		if not is_instance_valid(child):
			continue
			
		if not (child is Control and "request_data" in child):
			continue
			
		if child.request_data.id == response_data.friendship.id:
			print("Found matching request, removing...")
			request_found = true
			child.queue_free()
			break
	
	if not request_found:
		print("No matching request found to remove")
	
	# Update search results to allow new friend request
	if response_data.friendship.has("friend_id"):
		for child in search_results.get_children():
			if child is Control and "user_data" in child:
				if child.user_data.id == response_data.friendship.friend_id:
					# Reset the status to allow sending new request
					child.update_friendship_status("none")

	# Reload pending requests to ensure UI is in sync
	load_pending_requests()

func _on_return_pressed():
	SceneManager.return_to_main_hub()
