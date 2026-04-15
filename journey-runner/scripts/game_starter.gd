extends Node2D
## res://scripts/game_starter.gd — Manages game state and camera

@onready var _player: CharacterBody2D = $Player
@onready var _world: Node2D = $World
@onready var _camera: Camera2D = $Camera2D

var _game_started: bool = false
var _start_label: Label

func _ready() -> void:
	_setup_backgrounds()
	_setup_start_screen()

func _setup_backgrounds() -> void:
	var bg = $Background
	if not bg:
		return
	var sky = bg.get_node_or_null("SkyLayer/SkySprite")
	if sky:
		var tex = load("res://assets/img/bg_sky.png")
		if tex:
			sky.texture = tex
			sky.scale = Vector2(1.5, 1.5)
	var mtn = bg.get_node_or_null("MountainLayer/MountainSprite")
	if mtn:
		var tex = load("res://assets/img/bg_mountains.png")
		if tex:
			mtn.texture = tex
			mtn.scale = Vector2(1.5, 1.5)
	var clouds = bg.get_node_or_null("CloudIslandLayer/CloudIslandSprite")
	if clouds:
		var tex = load("res://assets/img/bg_clouds.png")
		if tex:
			clouds.texture = tex
			clouds.scale = Vector2(1.5, 1.5)
	var fg = bg.get_node_or_null("ForegroundLayer/ForegroundSprite")
	if fg:
		var tex = load("res://assets/img/bg_foreground.png")
		if tex:
			fg.texture = tex
			fg.scale = Vector2(1.5, 1.5)

func _setup_start_screen() -> void:
	# Create start screen label
	var ui_layer = $UILayer
	if not ui_layer:
		return
	_start_label = Label.new()
	_start_label.name = "StartLabel"
	_start_label.text = "西游记跑酷\n\n按 空格键 开始游戏\n↑/W 跳跃  ↓/S 滑行  D 气功攻击\n双击跳跃可在空中再跳一次"
	_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_start_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_start_label.add_theme_font_size_override("font_size", 32)
	_start_label.add_theme_color_override("font_color", Color.GOLD)
	_start_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_start_label.add_theme_constant_override("shadow_offset_x", 2)
	_start_label.add_theme_constant_override("shadow_offset_y", 2)
	ui_layer.add_child(_start_label)

func _process(delta: float) -> void:
	if not _game_started:
		if Input.is_action_just_pressed("jump"):
			_start_game()
		return

	# Camera follows player smoothly
	if _player and _camera:
		var target_x: float = _player.global_position.x + 300
		var target_y: float = _player.global_position.y - 50
		_camera.global_position.x = lerp(_camera.global_position.x, target_x, 5.0 * delta)
		_camera.global_position.y = lerp(_camera.global_position.y, target_y, 5.0 * delta)

func _start_game() -> void:
	_game_started = true
	GameManager.start_game()
	# Remove start label
	if _start_label:
		_start_label.queue_free()
		_start_label = null
	if _world and _world.has_method("start"):
		_world.start()
	if _player:
		_player.global_position = Vector2(200, 300)
		_player.velocity = Vector2.ZERO
	if _camera:
		_camera.global_position = Vector2(500, 250)
