# Tooltip.gd
extends Control

@onready var label = $Label

func set_text(text):
	label.text = text

func _ready():
	# Set up the appearance of the tooltip
	var style_box = StyleBoxFlat.new()
	style_box.set_bg_color(Color(0.1, 0.1, 0.1, 0.8))
	style_box.set_corner_radius_all(5)
	style_box.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style_box)

# You'll need to create a scene file (Tooltip.tscn) with this script attached
# The scene should have a Control node as root with a Label as child
# The Control node should use a PanelContainer to allow for styling
