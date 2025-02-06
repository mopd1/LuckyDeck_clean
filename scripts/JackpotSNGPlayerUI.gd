# JackpotSNGPlayerUI.gd
extends PlayerUIBase

func update_display(player_data: Dictionary, is_current_player: bool, show_cards: bool) -> void:
	# Handle elimination before normal display update
	if player_data.get("eliminated", false):
		eliminate_player()
		return
		
	# Call parent implementation for normal display
	super.update_display(player_data, is_current_player, show_cards)

func eliminate_player() -> void:
	# Create elimination effect
	var elimination_effect = CPUParticles2D.new()
	elimination_effect.emitting = true
	elimination_effect.one_shot = true
	elimination_effect.explosiveness = 0.8
	elimination_effect.lifetime = 0.5
	add_child(elimination_effect)
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(queue_free)
