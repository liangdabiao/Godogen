extends SceneTree
## Extended combat test: more attacks, longer run
## Run: timeout 60 godot --path . --script test/test_combat.gd

var _frame := 0
var _ready := false
var _started := false
var _dir := "D:/game-test/test/journey-runner/screenshots/combat2"
var _captured := 0
var _attacks := 0

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

	# Attack every 25 frames — more frequent
	if _started and _frame > 15 and _frame % 25 == 0 and _attacks < 20:
		Input.action_press("attack")
		call_deferred("_release_attack")
		_attacks += 1

	# Capture screenshots
	if _started and _frame >= 15 and _captured < 80 and _frame % 5 == 0:
		DirAccess.make_dir_recursive_absolute(_dir)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_dir + "/frame_%04d.png" % _captured)
		_captured += 1

	if _frame >= 600:
		print("Done — %d attacks, %d screenshots" % [_attacks, _captured])
		quit()
		return false
	return false

func _release_jump() -> void:
	Input.action_release("jump")

func _release_attack() -> void:
	Input.action_release("attack")
