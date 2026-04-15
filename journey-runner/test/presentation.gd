extends SceneTree
## Presentation video — ~30s cinematic gameplay showcase

var _player: Node2D
var _game_manager: Node
var _game_starter: Node
var _frame: int = 0
var _camera: Camera2D

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game_root = scene.instantiate()
	root.add_child(game_root)

	for child in root.get_children():
		if child.name == "GameManager":
			_game_manager = child
			break

	_game_starter = game_root

	if _game_manager and _game_manager.has_method("start_game"):
		_game_manager.start_game()

	var world = game_root.get_node_or_null("World")
	if world and world.has_method("start"):
		world.start()

	_player = game_root.get_node_or_null("Player")
	if _player:
		_player.global_position = Vector2(200, 300)

	var start_label = game_root.get_node_or_null("UILayer/StartLabel")
	if start_label:
		start_label.free()

	if _game_starter:
		_game_starter.set("_game_started", true)

	_camera = game_root.get_node_or_null("Camera2D")
	if _camera:
		_camera.make_current()

func _process(_delta: float) -> bool:
	_frame += 1

	# Autonomous gameplay — periodic jumps and slides
	if _frame % 25 == 0:
		Input.action_press("jump")
	elif _frame % 25 == 1:
		Input.action_release("jump")
	if _frame % 40 == 5:
		Input.action_press("jump")
	elif _frame % 40 == 6:
		Input.action_release("jump")

	if _frame > 200 and _frame % 60 < 15:
		Input.action_press("slide")
	else:
		Input.action_release("slide")

	# Camera: follow player with smooth lerp
	if _player and _camera:
		var target_x: float = _player.global_position.x + 350
		var target_y: float = _player.global_position.y - 30
		_camera.global_position.x = lerp(_camera.global_position.x, target_x, 8.0 * _delta)
		_camera.global_position.y = lerp(_camera.global_position.y, target_y, 8.0 * _delta)

	# Periodic status
	if _frame % 90 == 0 and _player and _game_manager:
		print("Frame %d: pos=(%.0f,%.0f) score=%d dist=%.0f lives=%d" % [
			_frame, _player.global_position.x, _player.global_position.y,
			_game_manager.score, _game_manager.distance, _game_manager.lives])

	return false
