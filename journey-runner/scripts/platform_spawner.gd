extends Node2D
## res://scripts/platform_spawner.gd — Procedural level generation

var _platform_scene: PackedScene
var _collectible_scene: PackedScene
var _obstacle_scene: PackedScene
var _enemy_scene: PackedScene
var _scenes_loaded: bool = false

var _last_platform_x: float = 0.0
var _last_platform_y: float = 400.0
var _player: Node2D
var _started: bool = false

func _ready() -> void:
	_player = get_parent().get_node_or_null("Player")
	_connect_signals()

func _ensure_scenes_loaded() -> void:
	if _scenes_loaded:
		return
	_scenes_loaded = true
	_platform_scene = load("res://scenes/platform.tscn")
	_collectible_scene = load("res://scenes/collectible.tscn")
	_obstacle_scene = load("res://scenes/obstacle.tscn")
	_enemy_scene = load("res://scenes/enemy.tscn")

func _connect_signals() -> void:
	if GameManager:
		GameManager.game_over.connect(_on_game_over)

func _on_game_over() -> void:
	_started = false

func start() -> void:
	_last_platform_x = 0.0
	_last_platform_y = 400.0
	_started = true
	_ensure_scenes_loaded()
	_spawn_initial_platforms()

func _spawn_initial_platforms() -> void:
	_spawn_platform(200, 450, 600)
	_spawn_platform(850, 420, 400)
	_spawn_platform(1350, 400, 350)
	_spawn_platform(1800, 430, 500)
	_spawn_platform(2400, 380, 350)
	_spawn_platform(2850, 410, 400)

	_spawn_collectible(400, 390, "peach")
	_spawn_collectible(700, 380, "peach")
	_spawn_collectible(1000, 370, "pill")

	# Spawn initial enemies for early combat
	_spawn_enemy(500, 360)
	_spawn_enemy(800, 320)
	_spawn_enemy(1100, 340)
	_spawn_enemy(1400, 300)
	_spawn_enemy(1700, 350)
	_spawn_enemy(2000, 310)
	_spawn_enemy(2300, 330)
	_spawn_enemy(2600, 290)

func _process(_delta: float) -> void:
	if not _started or not GameManager.game_running:
		return
	if not _player:
		return
	var spawn_threshold: float = _player.global_position.x + 1500
	if _last_platform_x < spawn_threshold:
		_spawn_segment()

func _spawn_segment() -> void:
	var difficulty: float = min(GameManager.difficulty_multiplier, 3.0)

	var max_gap: float = 120.0 + difficulty * 25.0
	var gap: float = randf_range(60.0, max_gap)

	var max_width: float = 450.0 - difficulty * 30.0
	var min_width: float = 150.0
	var width: float = randf_range(min_width, max_width)

	var x: float = _last_platform_x + gap + width / 2.0

	var max_height_delta: float = 100.0 + difficulty * 15.0
	var height_delta: float = randf_range(-max_height_delta, max_height_delta)
	var y: float = clampf(_last_platform_y + height_delta, 200.0, 550.0)

	_spawn_platform(x, y, width)

	if randf() < 0.65:
		var cx = x + randf_range(-width * 0.3, width * 0.3)
		_spawn_collectible(cx, y - 50.0, "peach")

	if randf() < 0.12:
		var cx = x + randf_range(-width * 0.2, width * 0.2)
		_spawn_collectible(cx, y - 90.0, "pill")

	if randf() < 0.25 * difficulty:
		var ox = x + randf_range(-width * 0.2, width * 0.2)
		_spawn_obstacle(ox, y)

	if randf() < 0.18 * difficulty:
		var ex = x + randf_range(0, width * 0.5)
		var ey = y - randf_range(80.0, 180.0)
		_spawn_enemy(ex, ey)

	if randf() < 0.04:
		_spawn_collectible(x, y - 160.0, "cloud")

	_last_platform_x = x + width / 2.0
	_last_platform_y = y

func _spawn_platform(x: float, y: float, width: float) -> void:
	if not _platform_scene:
		return
	var platform = _platform_scene.instantiate()
	platform.global_position = Vector2(x, y)
	add_child(platform)
	if platform.has_method("set_width"):
		platform.set_width(width)

func _spawn_collectible(x: float, y: float, type: String) -> void:
	if not _collectible_scene:
		return
	var item = _collectible_scene.instantiate()
	item.global_position = Vector2(x, y)
	if item.has_method("set_type"):
		item.set_type(type)
	add_child(item)

func _spawn_obstacle(x: float, y: float) -> void:
	if not _obstacle_scene:
		return
	var obs = _obstacle_scene.instantiate()
	obs.global_position = Vector2(x, y - 40.0)
	add_child(obs)

func _spawn_enemy(x: float, y: float) -> void:
	if not _enemy_scene:
		return
	var enm = _enemy_scene.instantiate()
	enm.global_position = Vector2(x, y)
	add_child(enm)
