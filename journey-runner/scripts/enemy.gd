extends CharacterBody2D
## res://scripts/enemy.gd — Flying demon

var _base_y: float = 0.0
var _time: float = 0.0
var _amplitude: float = 60.0
var _speed: float = 3.0
var _dying: bool = false

func _ready() -> void:
	_base_y = global_position.y
	collision_layer = 8   # hazards
	collision_mask = 1 + 32  # detect player + projectiles
	add_to_group("enemies")
	_load_texture()
	_time = randf() * TAU

func _load_texture() -> void:
	var sprite: Sprite2D = $Sprite2D
	var tex = load("res://assets/img/enemy_nobg.png")
	if tex:
		sprite.texture = tex
		var display_size = 48.0
		var scale_factor = display_size / max(tex.get_width(), tex.get_height())
		sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		sprite.modulate = Color.RED

func take_damage() -> void:
	if _dying:
		return
	_dying = true
	GameManager.add_score(25)

func _physics_process(delta: float) -> void:
	if _dying:
		var sprite: Sprite2D = $Sprite2D
		if sprite:
			sprite.scale *= 1.0 + delta * 10.0
			sprite.modulate.a -= delta * 4.0
		if sprite and sprite.modulate.a <= 0.0:
			queue_free()
		return
	_time += delta * 2.5
	global_position.x -= _speed
	global_position.y = _base_y + sin(_time) * _amplitude
	if global_position.x < -300:
		queue_free()
