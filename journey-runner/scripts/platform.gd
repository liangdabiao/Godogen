extends StaticBody2D
## res://scripts/platform.gd — Cloud platform

var _platform_width: float = 200.0

func _ready() -> void:
	add_to_group("platforms")
	_load_texture()

func _load_texture() -> void:
	var tex = load("res://assets/img/platform_nobg.png")
	if tex:
		$Sprite2D.texture = tex
	_update_visual()

func set_width(width: float) -> void:
	_platform_width = width
	var rect: RectangleShape2D = $CollisionShape2D.shape
	if rect:
		rect.size = Vector2(width, 40)
	_update_visual()

func _update_visual() -> void:
	var sprite: Sprite2D = $Sprite2D
	if sprite and sprite.texture:
		var tex_width: float = sprite.texture.get_width()
		if tex_width > 0:
			# Scale to match platform width, 48px tall
			var scale_x: float = _platform_width / tex_width
			var scale_y: float = 48.0 / sprite.texture.get_height()
			sprite.scale = Vector2(scale_x, scale_y)

func _process(_delta: float) -> void:
	if global_position.x < -800:
		queue_free()
