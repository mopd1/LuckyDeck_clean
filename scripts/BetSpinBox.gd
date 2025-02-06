# BetSpinBox.gd
extends SpinBox

signal bet_entered(value: String)  # Changed from bet_submitted to avoid confusion
var pending_value: String = ""

func _ready():
	update_on_text_changed = false
	select_all_on_focus = true
	
func _gui_input(event):
	if event is InputEventKey:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if pending_value.length() > 0:
				value = pending_value.to_int()
				emit_signal("bet_entered", str(value))
				pending_value = ""
			release_focus()
			get_viewport().set_input_as_handled()

func _on_text_changed(new_text: String):
	pending_value = new_text
