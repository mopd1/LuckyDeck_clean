extends TextureRect

# Called when the node enters the scene tree for the first time.
func _ready():
	material.set_shader_parameter('Color', Vector4(1.0,0.0,0.0,1.0))
	var tween = create_tween()
	tween.tween_property(self, 'material:shader_parameter/Alpha', 1.0, 2)
