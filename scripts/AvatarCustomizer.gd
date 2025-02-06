extends Control

signal customization_complete(avatar_data)

var category_mapping = {
	"face": {"node": "Face", "folder": "face"},
	"clothing": {"node": "Clothing", "folder": "clothing"},
	"hair": {"node": "Hair", "folder": "hair"},
	"hat": {"node": "Hat", "folder": "hat"},
	"ear_accessories": {"node": "EarAccessories", "folder": "ear_accessories"},
	"mouth_accessories": {"node": "MouthAccessories", "folder": "mouth_accessories"}
}

var avatar_config = {
	"face": null,
	"clothing": null,
	"hair": null,
	"hat": null,
	"ear_accessories": null,
	"mouth_accessories": null
}

@onready var head_base = $AvatarRoot/HeadBase
@onready var torso_base = $AvatarRoot/TorsoBase

# Onready variables for each customizable element
@onready var face_sprite = $AvatarRoot/HeadBase/Face
@onready var clothing_sprite = $AvatarRoot/TorsoBase/Clothing
@onready var hair_sprite = $AvatarRoot/HeadBase/Hair
@onready var hat_sprite = $AvatarRoot/HeadBase/Hat
@onready var ear_accessories_sprite = $AvatarRoot/HeadBase/EarAccessories
@onready var mouth_accessories_sprite = $AvatarRoot/HeadBase/MouthAccessories

func _ready():
	initialize_avatar()
	setup_ui()
	test_customization()

func initialize_avatar():
	# Load default textures or previously saved configuration
	# For now, let's just ensure all sprites are invisible
	face_sprite.visible = false
	clothing_sprite.visible = false
	hair_sprite.visible = false
	hat_sprite.visible = false
	ear_accessories_sprite.visible = false
	mouth_accessories_sprite.visible = false

func setup_ui():
	var tab_container = $UIRoot/TabContainer
	var confirm_button = $UIRoot/ConfirmButton
	var clear_button = $UIRoot/ClearButton
	var randomize_button = $UIRoot/RandomizeButton

	if not tab_container:
		push_error("TabContainer not found")
		return

	for category in avatar_config.keys():
		var node_name = category_mapping[category]["node"]
		# Convert underscore to space for UI elements
		var ui_name = category.replace("_", " ").capitalize()
		
		var tab = tab_container.get_node(ui_name + "Tab")
		if not tab:
			push_error("Tab not found for category: " + category + " (looking for: " + ui_name + "Tab)")
			continue
		
		var grid = tab.get_node(ui_name + "Grid")
		if not grid:
			push_error("Grid not found for category: " + category + " (looking for: " + ui_name + "Grid)")
			continue

		# Set up the grid
		grid.columns = 4  # Adjust the number of columns as needed
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)

		var items = load_items_for_category(category)
		for item in items:
			var button = TextureButton.new()
			var texture = load(item.texture_path)
			button.texture_normal = texture
			
			# Set a fixed size for the button
			var button_size = Vector2(100, 100)  # Adjust this size as needed
			button.custom_minimum_size = button_size
			
			# Use the correct properties for TextureButton
			button.ignore_texture_size = true
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			
			button.connect("pressed", Callable(self, "_on_item_selected").bind(category, item.id))
			grid.add_child(button)

	if confirm_button:
		confirm_button.connect("pressed", Callable(self, "_on_confirm_pressed"))
	else:
		push_error("ConfirmButton not found")

	if clear_button:
		clear_button.connect("pressed", Callable(self, "_on_clear_pressed"))
	else:
		push_error("ClearButton not found")

	if randomize_button:
		randomize_button.connect("pressed", Callable(self, "_on_randomize_pressed"))
	else:
		push_error("RandomizeButton not found")

	# Make sure the UIRoot is visible
	$UIRoot.visible = true

func load_items_for_category(category: String) -> Array:
	var items = []
	var folder_name = category_mapping[category]["folder"]
	var dir = DirAccess.open("res://assets/avatars/" + folder_name)
	var owned_parts = PlayerData.get_owned_avatar_parts()
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				var item_id = file_name.get_basename()
				if item_id in owned_parts:
					items.append({
						"id": item_id,
						"texture_path": "res://assets/avatars/" + folder_name + "/" + file_name
					})
			file_name = dir.get_next()
	return items

func _on_item_selected(category: String, item_id: String):
	apply_item(category, item_id)


func preview_item(category: String, texture: Texture2D):
	print("Previewing " + category + " with texture: " + texture.resource_path)
	var node_name = category_mapping[category]["node"]
	var sprite = get_node("AvatarRoot/HeadBase/" + node_name) if category != "clothing" else get_node("AvatarRoot/TorsoBase/Clothing")
	if sprite:
		sprite.texture = texture
		sprite.visible = true
	else:
		push_error("Could not find sprite node for category: " + category)

func apply_item(category: String, item_id: String):
	print("Applying item: ", category, " - ", item_id)  # Debug print
	avatar_config[category] = item_id
	var node_name = category_mapping[category]["node"]
	var sprite = get_node("AvatarRoot/HeadBase/" + node_name) if category != "clothing" else get_node("AvatarRoot/TorsoBase/Clothing")
	
	if sprite:
		var texture_path = "res://assets/avatars/" + category_mapping[category]["folder"] + "/" + item_id + ".png"
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			sprite.visible = true
		else:
			push_error("Failed to load texture: " + texture_path)
			sprite.visible = false
	else:
		push_error("Sprite not found for category: " + category + " (looking for: " + node_name + ")")

	print("Applied " + category + " item: " + item_id)

func clear_item(category: String):
	avatar_config[category] = null
	var node_name = category_mapping[category]["node"]
	var sprite = get_node("AvatarRoot/HeadBase/" + node_name) if category != "clothing" else get_node("AvatarRoot/TorsoBase/Clothing")
	if sprite:
		sprite.visible = false
	else:
		push_error("Could not find sprite node for category: " + category + " (looking for: " + node_name + ")")

func _on_confirm_pressed():
	print("Confirm pressed. Avatar config: ", avatar_config)
	emit_signal("customization_complete", avatar_config)

# Add this method to load a saved configuration
func load_configuration(config: Dictionary):
	avatar_config = config
	for category in avatar_config.keys():
		if avatar_config[category]:
			apply_item(category, avatar_config[category])
		else:
			clear_item(category)

func test_customization():
	print("Starting customization test")
	for category in avatar_config.keys():
		var items = load_items_for_category(category)
		if items.size() > 0:
			var random_item = items[randi() % items.size()]
			print("Selecting random item for " + category + ": " + random_item.id)
			apply_item(category, random_item.id)
	print("Customization test complete")
	print("Final configuration: ", avatar_config)

func _on_clear_pressed():
	for category in avatar_config.keys():
		clear_item(category)

func _on_randomize_pressed():
	for category in avatar_config.keys():
		var items = load_items_for_category(category)
		if items.size() > 0:
			var random_item = items[randi() % items.size()]
			apply_item(category, random_item.id)
		else:
			print("No items found for category: " + category)

func load_avatar_data(data):
	if data:
		for category in data.keys():
			if data[category]:
				apply_item(category, data[category])
