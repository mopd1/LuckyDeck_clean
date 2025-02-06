extends Panel

signal play_pressed(league_type: String)

@onready var title_label = $TitleLabel
@onready var game_image = $GameImage
@onready var active_bets_label = $ActiveBetsLabel
@onready var countdown_timer = $CountdownTimer
@onready var play_button = $PlayButton
@onready var timer_label = $TimerLabel

var league_type: String
var update_timer: Timer

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	update_timer = Timer.new()
	update_timer.wait_time = 1.0
	update_timer.timeout.connect(_update_countdown)
	add_child(update_timer)
	update_timer.start()
	
	SportsBettingManager.bet_placed.connect(_on_bet_placed)
	SportsBettingManager.bet_cancelled.connect(_on_bet_cancelled)

func set_league_type(type: String):
	league_type = type
	title_label.text = type
	
	var image_path = "res://assets/sports/" + type.to_lower().replace(" ", "_") + ".png"
	var texture = load(image_path)
	if texture:
		game_image.texture = texture
	
	_update_active_bets()
	_update_countdown()

func _update_active_bets():
	var active_count = 0
	for bet in SportsBettingManager.active_bets.values():
		if bet["league"] == _get_league_enum():
			active_count += 1
	
	active_bets_label.text = "Active Bets: " + str(active_count)

func _update_countdown():
	var lock_time = SportsBettingManager._get_lock_time(_get_league_enum())
	var current_time = Time.get_unix_time_from_system()
	var time_left = max(0, lock_time - current_time)
	
	if time_left > 0:
		var days = time_left / 86400
		var hours = (time_left % 86400) / 3600
		var minutes = (time_left % 3600) / 60
		var seconds = time_left % 60
		
		timer_label.text = "%02d:%02d:%02d:%02d" % [days, hours, minutes, seconds]
	else:
		timer_label.text = "Locked"

func _get_league_enum() -> int:
	return SportsBettingManager.League.NFL if league_type == "American NFL" else SportsBettingManager.League.EPL

func _on_play_pressed():
	emit_signal("play_pressed", league_type)

func _on_bet_placed(_bet_data: Dictionary):
	_update_active_bets()

func _on_bet_cancelled(_bet_id: String):
	_update_active_bets()
