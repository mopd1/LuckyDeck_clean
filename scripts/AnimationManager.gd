extends Node

# Animation speeds (can be modified in settings)
const DEFAULT_DURATION = 0.5
const FAST_DURATION = 0.25
const SLOW_DURATION = 0.75

# Animation types
enum AnimationType {
	CHIP_BET,
	CHIP_COLLECT,
	CHIP_WIN,
	CARD_DEAL,
	DEALER_BUTTON,
	PLAYER_TURN,
	WINNER_HIGHLIGHT
}

# Signals
signal animation_started(type: AnimationType)
signal animation_completed(type: AnimationType)
signal all_animations_completed

# Animation queue and tracking
var active_animations: Dictionary = {}  # type: Array[Tween]
var animation_queue: Array = []
var is_processing_queue := false
var animation_speed_multiplier := 1.0

class AnimationRequest:
	var type: AnimationType
	var source: Node
	var target: Node
	var start_pos: Vector2
	var end_pos: Vector2
	var duration: float
	var data: Dictionary
	var completed: Callable
	
	func _init(p_type: AnimationType, p_source: Node, p_target: Node = null, 
			   p_start_pos: Vector2 = Vector2.ZERO, p_end_pos: Vector2 = Vector2.ZERO,
			   p_duration: float = 1.0, p_data: Dictionary = {}, p_completed: Callable = func(): pass):
		type = p_type
		source = p_source
		target = p_target
		start_pos = p_start_pos
		end_pos = p_end_pos
		duration = p_duration
		data = p_data
		completed = p_completed

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure animations continue during pause

func queue_animation(request: AnimationRequest) -> void:
	animation_queue.append(request)
	if not is_processing_queue:
		process_queue()

func process_queue() -> void:
	if animation_queue.is_empty():
		is_processing_queue = false
		emit_signal("all_animations_completed")
		return
	
	is_processing_queue = true
	var request = animation_queue.pop_front()
	
	# Ensure source node still exists
	if not is_instance_valid(request.source):
		process_queue()
		return
	
	match request.type:
		AnimationType.CHIP_BET:
			animate_chip_bet(request)
		AnimationType.CHIP_COLLECT:
			animate_chip_collect(request)
		AnimationType.CHIP_WIN:
			animate_chip_win(request)
		AnimationType.CARD_DEAL:
			animate_card_deal(request)
		AnimationType.DEALER_BUTTON:
			animate_dealer_button(request)
		AnimationType.PLAYER_TURN:
			animate_player_turn(request)
		AnimationType.WINNER_HIGHLIGHT:
			animate_winner_highlight(request)

func animate_chip_bet(request: AnimationRequest) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Store tween reference
	if not active_animations.has(AnimationType.CHIP_BET):
		active_animations[AnimationType.CHIP_BET] = []
	active_animations[AnimationType.CHIP_BET].append(tween)
	
	emit_signal("animation_started", AnimationType.CHIP_BET)
	
	# Move chip to target position
	tween.tween_property(
		request.source,
		"position",
		request.end_pos,
		request.duration * animation_speed_multiplier
	)
	
	# Setup completion
	tween.finished.connect(
		func():
			active_animations[AnimationType.CHIP_BET].erase(tween)
			request.completed.call()
			emit_signal("animation_completed", AnimationType.CHIP_BET)
			process_queue()
	)

func animate_chip_collect(request: AnimationRequest) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	if not active_animations.has(AnimationType.CHIP_COLLECT):
		active_animations[AnimationType.CHIP_COLLECT] = []
	active_animations[AnimationType.CHIP_COLLECT].append(tween)
	
	emit_signal("animation_started", AnimationType.CHIP_COLLECT)
	
	# Move to pot position
	tween.tween_property(
		request.source,
		"position",
		request.end_pos,
		request.duration * animation_speed_multiplier
	)
	
	# Fade out as it reaches the pot
	tween.parallel().tween_property(
		request.source,
		"modulate:a",
		0.0,
		(request.duration * 0.5) * animation_speed_multiplier
	)
	
	tween.finished.connect(
		func():
			active_animations[AnimationType.CHIP_COLLECT].erase(tween)
			request.completed.call()
			emit_signal("animation_completed", AnimationType.CHIP_COLLECT)
			process_queue()
	)

func animate_chip_win(request: AnimationRequest) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	if not active_animations.has(AnimationType.CHIP_WIN):
		active_animations[AnimationType.CHIP_WIN] = []
	active_animations[AnimationType.CHIP_WIN].append(tween)
	
	emit_signal("animation_started", AnimationType.CHIP_WIN)
	
	# Move chips to winner position
	tween.tween_property(
		request.source,
		"position",
		request.end_pos,
		request.duration * animation_speed_multiplier
	)
	
	tween.finished.connect(
		func():
			active_animations[AnimationType.CHIP_WIN].erase(tween)
			request.completed.call()
			emit_signal("animation_completed", AnimationType.CHIP_WIN)
			process_queue()
	)

func animate_card_deal(request: AnimationRequest) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	if not active_animations.has(AnimationType.CARD_DEAL):
		active_animations[AnimationType.CARD_DEAL] = []
	active_animations[AnimationType.CARD_DEAL].append(tween)
	
	emit_signal("animation_started", AnimationType.CARD_DEAL)
	
	# Move card from deck to position
	tween.tween_property(
		request.source,
		"position",
		request.end_pos,
		request.duration * animation_speed_multiplier
	)
	
	tween.finished.connect(
		func():
			active_animations[AnimationType.CARD_DEAL].erase(tween)
			request.completed.call()
			emit_signal("animation_completed", AnimationType.CARD_DEAL)
			process_queue()
	)

func animate_dealer_button(request: AnimationRequest) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	if not active_animations.has(AnimationType.DEALER_BUTTON):
		active_animations[AnimationType.DEALER_BUTTON] = []
	active_animations[AnimationType.DEALER_BUTTON].append(tween)
	
	emit_signal("animation_started", AnimationType.DEALER_BUTTON)
	
	# Move dealer button
	tween.tween_property(
		request.source,
		"position",
		request.end_pos,
		request.duration * animation_speed_multiplier
	)
	
	tween.finished.connect(
		func():
			active_animations[AnimationType.DEALER_BUTTON].erase(tween)
			request.completed.call()
			emit_signal("animation_completed", AnimationType.DEALER_BUTTON)
			process_queue()
	)

func animate_player_turn(request: AnimationRequest) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	if not active_animations.has(AnimationType.PLAYER_TURN):
		active_animations[AnimationType.PLAYER_TURN] = []
	active_animations[AnimationType.PLAYER_TURN].append(tween)
	
	emit_signal("animation_started", AnimationType.PLAYER_TURN)
	
	# Highlight current player
	tween.tween_property(
		request.source,
		"modulate",
		Color(1.2, 1.2, 1.2),  # Slight highlight
		request.duration * animation_speed_multiplier
	)
	
	tween.finished.connect(
		func():
			active_animations[AnimationType.PLAYER_TURN].erase(tween)
			request.completed.call()
			emit_signal("animation_completed", AnimationType.PLAYER_TURN)
			process_queue()
	)

func animate_winner_highlight(request: AnimationRequest) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	if not active_animations.has(AnimationType.WINNER_HIGHLIGHT):
		active_animations[AnimationType.WINNER_HIGHLIGHT] = []
	active_animations[AnimationType.WINNER_HIGHLIGHT].append(tween)
	
	emit_signal("animation_started", AnimationType.WINNER_HIGHLIGHT)
	
	# Flash winner
	tween.tween_property(
		request.source,
		"modulate",
		Color(1.5, 1.5, 0.5),  # Golden highlight
		request.duration * 0.5 * animation_speed_multiplier
	)
	tween.tween_property(
		request.source,
		"modulate",
		Color(1, 1, 1),
		request.duration * 0.5 * animation_speed_multiplier
	)
	
	tween.finished.connect(
		func():
			active_animations[AnimationType.WINNER_HIGHLIGHT].erase(tween)
			request.completed.call()
			emit_signal("animation_completed", AnimationType.WINNER_HIGHLIGHT)
			process_queue()
	)

func cancel_animations(type: AnimationType = -1) -> void:
	if type == -1:
		# Cancel all animations
		for anim_type in active_animations.keys():
			for tween in active_animations[anim_type]:
				if is_instance_valid(tween):
					tween.kill()
			active_animations[anim_type].clear()
		animation_queue.clear()
		is_processing_queue = false
	else:
		# Cancel specific animation type
		if active_animations.has(type):
			for tween in active_animations[type]:
				if is_instance_valid(tween):
					tween.kill()
			active_animations[type].clear()
		# Remove queued animations of this type
		animation_queue = animation_queue.filter(
			func(req): return req.type != type
		)

func set_animation_speed(multiplier: float) -> void:
	animation_speed_multiplier = clamp(multiplier, 0.1, 3.0)

# Helper method to wait for specific animation type to complete
func wait_for_animation(type: AnimationType) -> void:
	if not active_animations.has(type) or active_animations[type].is_empty():
		return
		
	for tween in active_animations[type]:
		if is_instance_valid(tween) and not tween.is_valid():
			await tween.finished

# Helper method to wait for all animations to complete
func wait_for_all_animations() -> void:
	if not is_processing_queue and animation_queue.is_empty():
		return
	await all_animations_completed
