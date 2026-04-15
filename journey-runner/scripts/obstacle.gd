extends StaticBody2D
## res://scripts/obstacle.gd — Stone pillar obstacle

func _ready() -> void:
	_load_texture()

func _load_texture() -> void:
	var sprite: Sprite2D = $Sprite2D
	var tex: Texture2D = load("res://assets/img/obstacles_kit_nobg.png")
	if not tex:
		return
	sprite.texture = tex
	sprite.region_enabled = true
	var half_w = tex.get_width() / 2.0
	sprite.region_rect = Rect2(0, 0, half_w, tex.get_height())
	# Scale to ~48x80 display
	var display_h = 80.0
	var scale_factor = display_h / tex.get_height()
	sprite.scale = Vector2(scale_factor, scale_factor)

func _process(_delta: float) -> void:
	if global_position.x < -300:
		queue_free()
