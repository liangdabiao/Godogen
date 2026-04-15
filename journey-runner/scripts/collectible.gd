extends Area2D
## res://scripts/collectible.gd — Peach, pill, cloud power-up

var _type: String = "peach"
var _bob_time: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	_base_y = global_position.y
	add_to_group("collectibles")
	_load_texture()

func _load_texture() -> void:
	var sprite: Sprite2D = $Sprite2D
	var tex: Texture2D = load("res://assets/img/collectibles_kit_nobg.png")
	if not tex:
		tex = load("res://assets/img/collectibles_kit.png")
	if not tex:
		return
	sprite.texture = tex
	sprite.region_enabled = true
	var w: float = tex.get_width()
	var h: float = tex.get_height()
	var third: float = w / 3.0

	match _type:
		"peach":
			sprite.region_rect = Rect2(0, 0, third, h)
		"pill":
			sprite.region_rect = Rect2(third, 0, third, h)
		"cloud":
			sprite.region_rect = Rect2(third * 2.0, 0, third, h)

	# Scale to 32x32 display
	var display_size = 32.0
	var region_size = sprite.region_rect.size
	var scale_factor = display_size / max(region_size.x, region_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)

func set_type(type: String) -> void:
	_type = type
	_load_texture()

func _process(delta: float) -> void:
	_bob_time += delta * 3.0
	global_position.y = _base_y + sin(_bob_time) * 8.0
	if global_position.x < -200:
		queue_free()

func collect() -> void:
	match _type:
		"peach":
			GameManager.add_peach()
		"pill":
			GameManager.add_score(50)
		"cloud":
			GameManager.activate_power_up("somersault_cloud")
	queue_free()
