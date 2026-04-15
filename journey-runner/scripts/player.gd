extends CharacterBody2D
## res://scripts/player.gd — Fox warrior player controller (animated sprite)

signal died
signal hit_obstacle

@export var run_speed: float = 380.0
@export var jump_velocity: float = -550.0
@export var double_jump_velocity: float = -420.0
@export var slide_speed_multiplier: float = 0.75
@export var max_fall_speed: float = 900.0
@export var invincible_duration: float = 1.5
@export var pickup_range: float = 50.0

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _jumps_remaining: int = 2
var _is_sliding: bool = false
var _is_invincible: bool = false
var _alive: bool = true
var _base_scale: Vector2 = Vector2.ONE
var _attack_cooldown: float = 0.0
var _projectile_scene: PackedScene = null

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_load_sprite_sheet()
	# Listen for attack animation finish to switch back to run
	_sprite.animation_finished.connect(_on_animation_finished)

func _load_sprite_sheet() -> void:
	var sf := SpriteFrames.new()

	# Load run animation
	var run_image := Image.load_from_file("res://assets/img/test_fox_run.png")
	if run_image:
		var run_tex := ImageTexture.create_from_image(run_image)
		var grid := 4
		var fw: float = float(run_tex.get_width()) / float(grid)
		var fh: float = float(run_tex.get_height()) / float(grid)
		sf.add_animation("run")
		sf.set_animation_speed("run", 10.0)
		sf.set_animation_loop("run", true)
		for i in range(grid * grid):
			var at := AtlasTexture.new()
			at.atlas = run_tex
			at.region = Rect2(float(i % grid) * fw, float(i / grid) * fh, fw, fh)
			sf.add_frame("run", at)

	# Load attack animation
	var atk_image := Image.load_from_file("res://assets/img/test_fox_attack.png")
	if atk_image:
		var atk_tex := ImageTexture.create_from_image(atk_image)
		var grid := 4
		var fw: float = float(atk_tex.get_width()) / float(grid)
		var fh: float = float(atk_tex.get_height()) / float(grid)
		sf.add_animation("attack")
		sf.set_animation_speed("attack", 12.0)
		sf.set_animation_loop("attack", false)
		for i in range(grid * grid):
			var at := AtlasTexture.new()
			at.atlas = atk_tex
			at.region = Rect2(float(i % grid) * fw, float(i / grid) * fh, fw, fh)
			sf.add_frame("attack", at)

	_sprite.sprite_frames = sf
	# Use run sprite for base scale (always loaded)
	var display_h := 80.0
	var run_grid := 4
	var run_fh: float = float(run_image.get_height()) / float(run_grid) if run_image else 80.0
	var scale_factor: float = display_h / run_fh
	_base_scale = Vector2(scale_factor, scale_factor)
	_sprite.scale = _base_scale
	_sprite.play("run")

func _physics_process(delta: float) -> void:
	if not _alive:
		velocity = Vector2.ZERO
		return
	if not GameManager.game_running:
		return

	# Attack cooldown
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	GameManager.update_distance(global_position.x / 10.0)
	_apply_gravity(delta)
	_handle_input()
	_apply_movement()
	_update_visuals()
	_check_pickups()
	_check_fall()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	if is_on_floor() and _jumps_remaining < 2:
		_jumps_remaining = 2

func _handle_input() -> void:
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			_jumps_remaining = 1
		elif _jumps_remaining > 0:
			velocity.y = double_jump_velocity
			_jumps_remaining -= 1
		_emit_jump_fx()

	if Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0:
		_attack()
		_attack_cooldown = 0.4

	var want_slide: bool = Input.is_action_pressed("slide") and is_on_floor()
	if want_slide and not _is_sliding:
		_is_sliding = true
		_collision.position.y = 10
	elif not want_slide and _is_sliding:
		_is_sliding = false
		_collision.position.y = 0

func _attack() -> void:
	# Play attack animation
	_sprite.play("attack")
	# Spawn qigong projectile
	_spawn_qigong()
	# Emit attack sparkles
	_emit_attack_fx()

func _spawn_qigong() -> void:
	if not _projectile_scene:
		_projectile_scene = load("res://scenes/projectile.tscn")
	if not _projectile_scene:
		return
	var proj = _projectile_scene.instantiate()
	var world = get_parent()
	if world and world.name == "Main":
		world = world.get_node_or_null("World")
	if not world:
		world = get_tree().root
	world.add_child(proj)
	proj.global_position = global_position + Vector2(30, -10)

func _on_animation_finished() -> void:
	if _alive and _sprite.animation == "attack":
		_sprite.play("run")

func _emit_attack_fx() -> void:
	var colors := [
		Color(1.0, 0.85, 0.2, 1.0),
		Color(0.3, 0.9, 1.0, 0.9),
		Color(1.0, 1.0, 1.0, 0.8),
	]
	for i in range(5):
		var dot := ColorRect.new()
		var size := randf_range(5.0, 12.0)
		dot.size = Vector2(size, size)
		dot.position = Vector2(
			randf_range(20, 50),
			randf_range(-20, 10)
		)
		dot.color = colors[i % colors.size()]
		dot.z_index = 10
		add_child(dot)
		dot.set_meta("vy", randf_range(-80.0, 40.0))
		dot.set_meta("vx", randf_range(100.0, 200.0))
		dot.set_meta("life", 0.0)
		dot.set_meta("max_life", randf_range(0.15, 0.35))

func _emit_jump_fx() -> void:
	var colors := [
		Color(1.0, 0.95, 0.4, 1.0),
		Color(1.0, 0.7, 0.1, 0.9),
		Color(1.0, 0.4, 0.0, 0.8),
		Color(1.0, 0.2, 0.0, 0.6),
	]
	for i in range(8):
		var dot := ColorRect.new()
		var size := randf_range(8.0, 20.0)
		dot.size = Vector2(size, size)
		dot.position = Vector2(
			randf_range(-18, 18),
			randf_range(15, 45)
		)
		dot.color = colors[i % colors.size()]
		dot.z_index = 10
		add_child(dot)
		dot.set_meta("vy", randf_range(60.0, 150.0))
		dot.set_meta("life", 0.0)
		dot.set_meta("max_life", randf_range(0.25, 0.5))

func _process(delta: float) -> void:
	for child in get_children():
		if child is ColorRect and child.has_meta("max_life"):
			var life: float = child.get_meta("life") + delta
			var max_life: float = child.get_meta("max_life")
			var vy: float = child.get_meta("vy", 0.0)
			var vx: float = child.get_meta("vx", 0.0)
			child.set_meta("life", life)
			child.position.y += vy * delta
			child.position.x += vx * delta
			var t := life / max_life
			child.modulate.a = 1.0 - t
			child.scale = Vector2.ONE * (1.0 + t * 2.0)
			if life >= max_life:
				child.queue_free()

func _take_damage() -> void:
	if _is_invincible:
		return
	hit_obstacle.emit()
	GameManager.lose_life()
	if GameManager.lives > 0:
		_become_invincible()
	else:
		_die()

func _apply_movement() -> void:
	var speed: float = run_speed * slide_speed_multiplier if _is_sliding else run_speed
	speed *= (1.0 + GameManager.difficulty_multiplier * 0.05)
	velocity.x = speed
	move_and_slide()
	# Check slide collisions for enemy/obstacle damage
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var body = col.get_collider()
		if body and body.collision_layer & 8 != 0:
			_take_damage()

func _check_pickups() -> void:
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	for c in collectibles:
		if c.global_position.distance_to(global_position) < pickup_range:
			if c.has_method("collect"):
				c.collect()

func _update_visuals() -> void:
	if _is_sliding:
		_sprite.scale.y = _base_scale.y * 0.5
	elif abs(_sprite.scale.y - _base_scale.y) > 0.001 and _sprite.animation == "run":
		_sprite.scale.y = lerp(_sprite.scale.y, _base_scale.y, 0.2)
		_sprite.scale.x = _base_scale.x

	if not is_on_floor():
		_sprite.rotation = deg_to_rad(-8) if velocity.y < 0 else deg_to_rad(5)
	else:
		_sprite.rotation = lerp(_sprite.rotation, 0.0, 0.3)

	if _is_invincible:
		_sprite.visible = floori(Time.get_ticks_msec() / 80) % 2 == 0
	else:
		_sprite.visible = true

func _check_fall() -> void:
	if global_position.y > 1000:
		_die()

func _die() -> void:
	if not _alive:
		return
	_alive = false
	GameManager.lose_life()
	if GameManager.lives > 0:
		_respawn()
	else:
		died.emit()

func _respawn() -> void:
	_alive = true
	_is_sliding = false
	_jumps_remaining = 2
	velocity = Vector2.ZERO
	_collision.position.y = 0
	_sprite.scale = _base_scale
	_sprite.rotation = 0.0
	_sprite.play("run")
	var platforms = get_tree().get_nodes_in_group("platforms")
	var best_x: float = 200.0
	var best_y: float = 400.0
	for p in platforms:
		var px: float = p.global_position.x
		if px < global_position.x + 100 and px > best_x - 300:
			best_x = px
			best_y = p.global_position.y
	global_position = Vector2(best_x, best_y - 80)
	_become_invincible()

func _become_invincible() -> void:
	_is_invincible = true
	var timer = get_tree().create_timer(invincible_duration)
	timer.timeout.connect(func():
		_is_invincible = false
		_sprite.visible = true
	)
