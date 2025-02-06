extends Node

# Constants for environment types
const ENV_DEVELOPMENT = "development"
const ENV_STAGING = "staging"
const ENV_PRODUCTION = "production"

# Configuration values
var current_environment: String
var api_url: String
var websocket_url: String
var enable_debug_logging: bool

# Environment-specific configurations
const ENV_CONFIGS = {
	ENV_DEVELOPMENT: {
		"api_url": "http://localhost:3000/api",
		"websocket_url": "ws://localhost:3000",
		"debug_logging": true
	},
	ENV_STAGING: {
		"api_url": "https://dev-api.luckydeckgaming.com/api",  # Your SSL-enabled dev endpoint
		"websocket_url": "wss://dev-api.luckydeckgaming.com",
		"debug_logging": true
	},
	ENV_PRODUCTION: {
		"api_url": "https://luckydeckgaming.com/api",
		"websocket_url": "wss://luckydeckgaming.com",
		"debug_logging": false
	}
}

func _ready():
	# Remove environment detection logic
	current_environment = ENV_DEVELOPMENT
	api_url = "http://13.60.228.103:3000/api"
	websocket_url = "ws://13.60.228.103:3000"
	enable_debug_logging = true

func set_environment_config(env: String):
	if env not in ENV_CONFIGS:
		push_error("Invalid environment: " + env)
		return
		
	current_environment = env
	api_url = ENV_CONFIGS[env]["api_url"]
	websocket_url = ENV_CONFIGS[env]["websocket_url"]
	enable_debug_logging = ENV_CONFIGS[env]["debug_logging"]

func set_development_config():
	set_environment_config(ENV_DEVELOPMENT)

func set_staging_config():
	set_environment_config(ENV_STAGING)

func set_production_config():
	set_environment_config(ENV_PRODUCTION)

func is_development() -> bool:
	return current_environment == ENV_DEVELOPMENT

func is_staging() -> bool:
	return current_environment == ENV_STAGING

func is_production() -> bool:
	return current_environment == ENV_PRODUCTION

# Helper function for logging
func log(message: String, level: String = "info"):
	if not enable_debug_logging and level == "debug":
		return
		
	var timestamp = Time.get_datetime_string_from_system()
	var log_message = "[%s] [%s] %s" % [timestamp, level.to_upper(), message]
	
	print(log_message)
	
	if is_production():
		# In production, we could send logs to a server or write to a file
		# This is where you'd implement production logging
		pass

# Helper function to get the current base URL for the environment
func get_base_url() -> String:
	var url = api_url.split("/api")[0]
	return url

func get_api_url() -> String:
	if OS.has_feature("web"):
		# Use relative URL for web builds
		return "/api"
	else:
		# Use full URL for other platforms
		return "https://luckydeckgaming.com/api"

# Helper function to check if current environment requires HTTPS
func requires_https() -> bool:
	return is_staging() or is_production()
