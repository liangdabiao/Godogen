extends SceneTree
## Quick test: start game, capture HUD with restart button
## Run: timeout 15 godot --path . --script test/test_restart_btn.gd

var _frame := 0
var _ready := false
var _started := false

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

func _physics_process(_delta: float) -> bool:
	if not _ready:
		return false
	_frame += 1

	# Start game on frame 5
	if _frame == 5 and not _started:
		Input.action_press("jump")
		call_deferred("_release_jump")
		_started = true

	# Capture frame 25 (game running, HUD visible)
	if _frame == 25:
		var dir := "D:/game-test/test/journey-runner/screenshots/restart_btn"
		DirAccess.make_dir_recursive_absolute(dir)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(dir + "/hud.png")
		print("Screenshot saved")
		quit()
		return false
	return false

func _release_jump() -> void:
	Input.action_release("jump")
