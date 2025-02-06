extends PanelContainer

@onready var close_button = $VBoxContainer/CloseButton

func _ready():
	close_button.pressed.connect(hide)
	hide()

func show_popup():
	show()
	
func hide_popup():
	hide()
