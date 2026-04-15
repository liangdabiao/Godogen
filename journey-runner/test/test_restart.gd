extends SceneTree
## Test restart: play, force game over, restart, verify clean state
## Run: timeout 40 godot --path . --script test/test_restart.gd

var _frame := 0
var _ready := false
var _captured := 0
var _dir := "D:/game-test/test/journey-runner/screenshots/restart"

func _initialize() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	if not main:
		push_error("Cannot load main scene")
		quit(1)
		return
	root.add_child(main.instantiate())
	call_deferred("_mark_ready")

func _mark_ready() -> void:
	_ready = true
	print("Ready")

func _physics_process(_delta: float) -> bool:
	if not _ready:
		return false
	_frame += 1

	# Frame 5: start game
	if _frame == 5:
		Input.action_press("jump")
		call_deferred("_release_jump")
		print("Game started")

	# Frame 40: force game over (kill player below threshold)
	if _frame == 40:
		var player = root.get_node_or_null("Main/Player")
		if player:
			player.global_position = Vector2(0, 1100)

	# Frame 45: second death
	if _frame == 45:
		var player = root.get_node_or_null("Main/Player")
		if player:
			player.global_position = Vector2(0, 1100)

	# Frame 50: third death → game over
	if _frame == 50:
		var player = root.get_node_or_null("Main/Player")
		if player:
			player.global_position = Vector2(0, 1100)
		print("Forced 3 deaths")

	# Frame 70: press restart
	if _frame == 70:
		var hud = root.get_node_or_null("Main/UILayer/HUDControl")
		if hud and hud.has_method("_restart_game"):
			hud._restart_game()
			print("Restart triggered")
		_frame = 0

	# Frame 30 (after restart = frame 100): capture
	if _frame == 30 and _captured == 0:
		DirAccess.make_dir_recursive_absolute(_dir)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_dir + "/after_restart.png")
		print("Screenshot captured")
		# Print state
		var world = root.get_node_or_null("Main/World")
		var player = root.get_node_or_null("Main/Player")
		var cam = root.get_node_or_null("Main/Camera2D")
		if world:
			print("World children: %d" % world.get_child_count())
		if player:
			print("Player pos: %s" % str(player.global_position))
		if cam:
			print("Camera pos: %s" % str(cam.global_position))
		_captured += 1

	# Frame 90 (after restart = frame 160): second capture + quit
	if _frame == 90:
		DirAccess.make_dir_recursive_absolute(_dir)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_dir + "/playing_again.png")
		_captured += 1
		print("Done")
		quit()
		return false

	return false

func _release_jump() -> void:
	Input.action_release("jump")
