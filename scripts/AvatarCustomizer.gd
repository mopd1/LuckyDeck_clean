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

@onready var categories_container = $UIRoot/ScrollContainer/CategoriesContainer
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
	face_sprite.visible = false
	clothing_sprite.visible = false
	hair_sprite.visible = false
	hat_sprite.visible = false
	ear_accessories_sprite.visible = false
	mouth_accessories_sprite.visible = false

func setup_ui():
	var confirm_button = $UIRoot/ConfirmButton
	var clear_button = $UIRoot/ClearButton
	var randomize_button = $UIRoot/RandomizeButton

	# Load all items first
	var all_items = []
	for category in avatar_config.keys():
		var items = load_items_for_category(category)
		all_items.append_array(items)
	
	# Populate "All" category
	var all_list = categories_container.get_node("AllCategory/ItemScroll/ItemList")
	populate_item_list(all_list, all_items)

	# Populate individual categories
	for category in avatar_config.keys():
		var category_name = category.replace("_", "").capitalize() + "Category"
		var category_node = categories_container.get_node_or_null(category_name)
		if category_node:
			var item_list = category_node.get_node("ItemScroll/ItemList")
			var items = load_items_for_category(category)
			populate_item_list(item_list, items)

	if confirm_button:
		confirm_button.connect("pressed", Callable(self, "_on_confirm_pressed"))
	if clear_button:
		clear_button.connect("pressed", Callable(self, "_on_clear_pressed"))
	if randomize_button:
		randomize_button.connect("pressed", Callable(self, "_on_randomize_pressed"))

func populate_item_list(item_list: HBoxContainer, items: Array):
	for item in items:
		var button = TextureButton.new()
		var texture = load(item.texture_path)
		button.texture_normal = texture
		
		# Set a fixed size for the button
		var button_size = Vector2(100, 100)
		button.custom_minimum_size = button_size
		
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		# Extract category from texture path
		var category = ""
		for cat in category_mapping.keys():
			if item.texture_path.contains(category_mapping[cat].folder):
				category = cat
				break
		
		button.connect("pressed", Callable(self, "_on_item_selected").bind(category, item.id))
		item_list.add_child(button)

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
	print("Applying item: ", category, " - ", item_id)
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
