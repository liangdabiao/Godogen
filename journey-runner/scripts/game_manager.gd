extends Node
## res://scripts/game_manager.gd — Autoload singleton

signal game_over
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal distance_changed(new_distance: float)
signal power_up_activated(type: String)
signal power_up_expired

var score: int = 0
var distance: float = 0.0
var lives: int = 3
var peaches: int = 0
var current_power_up: String = ""
var game_running: bool = false
var difficulty_multiplier: float = 1.0

func _ready() -> void:
	pass

func start_game() -> void:
	score = 0
	distance = 0.0
	lives = 3
	peaches = 0
	current_power_up = ""
	game_running = true
	difficulty_multiplier = 1.0

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

func add_peach() -> void:
	peaches += 1
	add_score(10)

func update_distance(new_distance: float) -> void:
	distance = new_distance
	distance_changed.emit(distance)
	difficulty_multiplier = 1.0 + distance / 5000.0

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		game_running = false
		game_over.emit()

func activate_power_up(type: String) -> void:
	current_power_up = type
	power_up_activated.emit(type)

func deactivate_power_up() -> void:
	current_power_up = ""
	power_up_expired.emit()
