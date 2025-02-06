extends Node

func _ready():
	print("\n=== Configuration Test Starting ===")
	test_config_manager()
	test_api_manager()
	test_error_manager()
	print("=== Configuration Test Complete ===\n")

func test_config_manager():
	print("\nTesting ConfigManager:")
	print("Environment: ", ConfigManager.current_environment)
	print("API URL: ", ConfigManager.api_url)
	print("WebSocket URL: ", ConfigManager.websocket_url)
	print("Debug Logging Enabled: ", ConfigManager.enable_debug_logging)

func test_api_manager():
	print("\nTesting APIManager:")
	print("API URL Configuration: ", APIManager.API_URL)
	print("API URL matches Config: ", APIManager.API_URL == ConfigManager.api_url)

func test_error_manager():
	print("\nTesting ErrorManager:")
	# Test error logging
	ErrorManager.handle_error({
		"node": "ConfigurationTest",
		"scene": "TestScene",
		"message": "Test error message",
		"timestamp": Time.get_unix_time_from_system()
	}, ErrorManager.ErrorSeverity.INFO)
