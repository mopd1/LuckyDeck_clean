extends Node2D

signal animation_completed

const CHIP_TEXTURES = {
	500: preload("res://assets/table/500chip.png"),
	1000: preload("res://assets/table/1000chip.png"),
	10000: preload("res://assets/table/10000chip.png"),
	50000: preload("res://assets/table/50000chip.png"),
	100000: preload("res://assets/table/100000chip.png"),
	1000000: preload("res://assets/table/1000000chip.png"),
	10000000: preload("res://assets/table/10000000chip.png"),
	100000000: preload("res://assets/table/100000000chip.png")
}

const STACK_HEIGHT_OFFSET = -20  # Vertical overlap of chips in stack
const MAX_CHIPS_PER_STACK = 5   # Maximum chips before new stack
const STACK_SPACING = 180        # Horizontal space between stacks

var current_chips = []  # Array of {value: int, sprite: Sprite2D}
var is_animating = false

func _ready():
	visible = false
	modulate.a = 1.0

func _exit_tree():
	clear_chips()

func set_amount(amount: int, animate: bool = true, from_position: Vector2 = Vector2.ZERO):
	# Cancel any ongoing animations first
	cancel_animations()
	
	# Calculate chip combinations
	var chip_counts = calculate_chip_combination(amount)
	if chip_counts.is_empty():
		clear_chips()
		return
	
	# Clear existing chips
	clear_chips()
	
	# Make visible before starting animations
	visible = true
	modulate.a = 1.0
	
	# Create new chips
	setup_chips(chip_counts, animate, from_position)
	
	if animate:
		is_animating = true
		var request = AnimationManager.AnimationRequest.new(
			AnimationManager.AnimationType.CHIP_BET,
			self,
			null,
			from_position,
			position,
			AnimationManager.DEFAULT_DURATION,
			{"amount": amount},
			func():
				is_animating = false
				animation_completed.emit()
		)
		AnimationManager.queue_animation(request)

func move_to_pot(pot_position: Vector2):
	if current_chips.is_empty():
		animation_completed.emit()
		return
	
	is_animating = true
	var request = AnimationManager.AnimationRequest.new(
		AnimationManager.AnimationType.CHIP_COLLECT,
		self,
		null,
		global_position,
		pot_position,
		AnimationManager.DEFAULT_DURATION,
		{},
		func():
			# Ensure cleanup happens before emitting completion signal
			is_animating = false
			clear_chips()
			# Small delay before emitting to ensure cleanup is complete
			await get_tree().create_timer(0.1).timeout
			animation_completed.emit()
	)
	AnimationManager.queue_animation(request)

func clear_chips():
	# Cancel any active animations first
	cancel_animations()
	
	# Keep track of chips we're clearing
	var chips_to_clear = current_chips.duplicate()
	current_chips.clear()
	
	# Clear chips safely
	for chip_data in chips_to_clear:
		if is_instance_valid(chip_data.sprite):
			if chip_data.sprite.is_inside_tree() and chip_data.sprite.get_parent() == self:
				remove_child(chip_data.sprite)
				chip_data.sprite.queue_free()
	
	visible = false
	modulate.a = 1.0
	is_animating = false

func setup_chips(chip_counts: Dictionary, animate: bool, start_position: Vector2):
	var stack_index = 0
	var stack_count = 0
	
	for value in chip_counts.keys():
		for i in range(chip_counts[value]):
			var chip = Sprite2D.new()
			chip.texture = CHIP_TEXTURES[value]
			
			# Position chip
			if animate:
				chip.position = start_position
			else:
				chip.position = Vector2(
					stack_index * STACK_SPACING,
					stack_count * STACK_HEIGHT_OFFSET
				)
			
			add_child(chip)
			current_chips.append({
				"value": value,
				"sprite": chip,
				"target_position": Vector2(
					stack_index * STACK_SPACING,
					stack_count * STACK_HEIGHT_OFFSET
				)
			})
			
			stack_count += 1
			if stack_count >= MAX_CHIPS_PER_STACK:
				stack_count = 0
				stack_index += 1

func calculate_chip_combination(amount: int) -> Dictionary:
	var result = {}
	var remaining = amount
	var denominations = CHIP_TEXTURES.keys()
	denominations.sort_custom(func(a, b): return a > b)
	
	for denom in denominations:
		if remaining >= denom:
			var count = remaining / denom
			result[denom] = count
			remaining = remaining % denom
		
		if remaining == 0:
			break
	
	return result

func cancel_animations():
	if not AnimationManager:
		return
		
	if is_animating:
		# Cancel any active animations in the manager
		AnimationManager.cancel_animations(AnimationManager.AnimationType.CHIP_BET)
		AnimationManager.cancel_animations(AnimationManager.AnimationType.CHIP_COLLECT)
		
		# Reset animation state
		is_animating = false
		
		# Clear potential queued animations
		for chip_data in current_chips:
			if is_instance_valid(chip_data.sprite):
				chip_data.sprite.position = chip_data.target_position
