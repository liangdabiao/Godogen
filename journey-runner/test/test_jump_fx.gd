extends SceneTree
## Auto-jump test: loads main scene, simulates jumps, captures screenshots.
## Run: timeout 20 godot --path . --script test/test_jump_fx.gd

var _frame := 0
var _jump_frames := [5, 35, 65, 95, 125]  # when to press jump — first one early
var _jump_idx := 0
var _dir := "screenshots/jump_fx"
var _captured := 0
var _ready := false
var _release_next := false

func _initialize() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	if not main:
		push_error("Cannot load main scene")
		quit(1)
		return
	root.add_child(main.instantiate())
	# Give the scene tree one frame to call _ready on all nodes
	call_deferred("_mark_ready")

func _mark_ready() -> void:
	_ready = true
	print("Test ready — capturing jump FX over 150 frames")

func _physics_process(_delta: float) -> bool:
	if not _ready:
		return false
	_frame += 1

	# Handle jump release
	if _release_next:
		Input.action_release("jump")
		_release_next = false

	# Press jump at scheduled frames
	if _jump_idx < _jump_frames.size() and _frame == _jump_frames[_jump_idx]:
		Input.action_press("jump")
		_release_next = true
		_jump_idx += 1
		print("JUMP at frame %d" % _frame)

	# Capture every frame for first 80, then every 2
	if _captured < 80 and (_frame <= 80 or _frame % 2 == 0):
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/frame_%03d.png" % [_dir, _captured]
		img.save_png(path)
		_captured += 1

	# End after 150 frames
	if _frame >= 150:
		print("Done — %d screenshots in %s/" % [_captured, _dir])
		quit()
		return false
	return false
