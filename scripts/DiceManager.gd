class_name DiceManager
extends Node2D

signal roll_completed(die1: int, die2: int)
signal animation_completed

@onready var die1_sprite = $Die1
@onready var die2_sprite = $Die2

var rng = CryptoRNG.new()
var is_rolling := false
var dice_textures: Array[Texture2D] = []
var roll_result := Vector2i.ZERO

# Animation parameters
const ROLL_DURATION := 1.0
const SPIN_FRAMES := 10
const FINAL_BOUNCE_HEIGHT := 50
const BOUNCE_DURATION := 0.3

func _ready():
	# Load dice textures
	for i in range(1, 7):
		dice_textures.append(load("res://assets/dice/die_%d.png" % i))
	
	# Initialize dice positions
	reset_dice_positions()

func reset_dice_positions():
	if die1_sprite and die2_sprite:
		die1_sprite.position = Vector2(0, 0)
		die2_sprite.position = Vector2(100, 0)
		die1_sprite.rotation = 0
		die2_sprite.rotation = 0

func roll() -> void:
	if is_rolling:
		return
		
	is_rolling = true
	
	# Generate roll results immediately but don't show them yet
	roll_result.x = rng.get_random_int(5) + 1  # 1-6
	roll_result.y = rng.get_random_int(5) + 1  # 1-6
	
	# Start animation sequence
	animate_roll()

func animate_roll() -> void:
	var spin_tween = create_tween().set_parallel(true)
	
	# Animate each die
	for die in [die1_sprite, die2_sprite]:
		# Initial upward motion
		spin_tween.tween_property(die, "position:y", -100, ROLL_DURATION * 0.5)\
			.set_ease(Tween.EASE_OUT)
		
		# Rotation animation
		spin_tween.tween_property(die, "rotation", PI * 4, ROLL_DURATION)\
			.set_ease(Tween.EASE_IN_OUT)
	
	# Spin animation showing random faces
	var spin_timer = get_tree().create_timer(ROLL_DURATION * 0.8)
	spin_timer.timeout.connect(_on_spin_timer_timeout)
	
	await spin_tween.finished
	await animate_final_bounce()
	
	# Show final result
	die1_sprite.texture = dice_textures[roll_result.x - 1]
	die2_sprite.texture = dice_textures[roll_result.y - 1]
	
	is_rolling = false
	emit_signal("roll_completed", roll_result.x, roll_result.y)

func animate_final_bounce() -> void:
	var bounce_tween = create_tween().set_parallel(true)
	
	for die in [die1_sprite, die2_sprite]:
		# Reset rotation
		die.rotation = 0
		
		# Bounce animation
		bounce_tween.tween_property(die, "position:y", FINAL_BOUNCE_HEIGHT, BOUNCE_DURATION)\
			.set_ease(Tween.EASE_OUT)
		bounce_tween.tween_property(die, "position:y", 0, BOUNCE_DURATION)\
			.set_ease(Tween.EASE_IN)
	
	await bounce_tween.finished
	emit_signal("animation_completed")

func _on_spin_timer_timeout() -> void:
	# Show random faces during spin animation
	for i in range(SPIN_FRAMES):
		var timer = get_tree().create_timer(0.05)
		await timer.timeout
		
		if is_rolling:
			die1_sprite.texture = dice_textures[randi() % 6]
			die2_sprite.texture = dice_textures[randi() % 6]

func get_roll_total() -> int:
	return roll_result.x + roll_result.y

func is_hard_way() -> bool:
	return roll_result.x == roll_result.y

func is_craps() -> bool:
	var total = get_roll_total()
	return total == 2 or total == 3 or total == 12

func is_natural() -> bool:
	var total = get_roll_total()
	return total == 7 or total == 11
