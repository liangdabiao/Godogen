extends SceneTree
## Test harness — capture gameplay screenshots

var _player: Node2D
var _game_manager: Node
var _game_starter: Node
var _frame: int = 0

func _initialize() -> void:
	# Load main scene
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game_root = scene.instantiate()
	root.add_child(game_root)

	# Find GameManager autoload
	for child in root.get_children():
		if child.name == "GameManager":
			_game_manager = child
			break

	# Find and configure game_starter to skip its own start logic
	_game_starter = game_root

	# Start game directly
	if _game_manager and _game_manager.has_method("start_game"):
		_game_manager.start_game()

	var world = game_root.get_node_or_null("World")
	if world and world.has_method("start"):
		world.start()

	_player = game_root.get_node_or_null("Player")
	if _player:
		_player.global_position = Vector2(200, 300)

	# Remove start label
	var start_label = game_root.get_node_or_null("UILayer/StartLabel")
	if start_label:
		start_label.free()

	# Set game_starter flag so it doesn't restart on space press
	if _game_starter:
		_game_starter.set("_game_started", true)

func _process(_delta: float) -> bool:
	_frame += 1

	# Input sequence - realistic gameplay
	if _frame == 15:
		Input.action_press("jump")
	elif _frame == 16:
		Input.action_release("jump")
	elif _frame == 28:
		Input.action_press("jump")  # double jump
	elif _frame == 29:
		Input.action_release("jump")
	elif _frame == 45:
		Input.action_press("slide")
	elif _frame == 55:
		Input.action_release("slide")
	elif _frame == 65:
		Input.action_press("jump")
	elif _frame == 66:
		Input.action_release("jump")
	elif _frame == 78:
		Input.action_press("jump")
	elif _frame == 79:
		Input.action_release("jump")
	elif _frame == 100:
		Input.action_press("slide")
	elif _frame == 108:
		Input.action_release("slide")
	elif _frame == 120:
		Input.action_press("jump")
	elif _frame == 121:
		Input.action_release("jump")
	elif _frame == 130:
		Input.action_press("jump")
	elif _frame == 131:
		Input.action_release("jump")

	if _frame % 30 == 0 and _player and _game_manager:
		var px = _player.global_position.x
		var py = _player.global_position.y
		var sc = _game_manager.score
		var ds = _game_manager.distance
		var lv = _game_manager.lives
		print("Frame %d: pos=(%.0f,%.0f) score=%d dist=%.0f lives=%d" % [_frame, px, py, sc, ds, lv])

	return false
