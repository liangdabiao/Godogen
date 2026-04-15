extends Area2D
## res://scripts/qigong_projectile.gd — Player's qigong energy blast

var _speed: float = 700.0
var _time: float = 0.0
var _max_lifetime: float = 4.0
var _hit: bool = false
var _hit_radius: float = 120.0
var _target: Node2D = null

func _ready() -> void:
	collision_layer = 32
	collision_mask = 8
	monitoring = true
	monitorable = false
	_create_visual()

func _create_visual() -> void:
	var outer := ColorRect.new()
	outer.name = "GlowOuter"
	outer.size = Vector2(60, 60)
	outer.color = Color(0.3, 0.9, 1.0, 0.35)
	outer.position = Vector2(-30, -30)
	outer.z_index = 5
	add_child(outer)

	var mid := ColorRect.new()
	mid.name = "GlowMid"
	mid.size = Vector2(38, 38)
	mid.color = Color(0.5, 1.0, 0.8, 0.6)
	mid.position = Vector2(-19, -19)
	mid.z_index = 6
	add_child(mid)

	var core := ColorRect.new()
	core.name = "GlowCore"
	core.size = Vector2(20, 20)
	core.color = Color(1.0, 1.0, 1.0, 0.95)
	core.position = Vector2(-10, -10)
	add_child(core)
	core.z_index = 7

func _physics_process(delta: float) -> void:
	if _hit:
		for child in get_children():
			if child is ColorRect and child.has_meta("max_life"):
				var life: float = child.get_meta("life") + delta
				var max_life: float = child.get_meta("max_life")
				var vx: float = child.get_meta("vx", 0.0)
				var vy: float = child.get_meta("vy", 0.0)
				child.set_meta("life", life)
				child.position.x += vx * delta
				child.position.y += vy * delta
				child.modulate.a = 1.0 - (life / max_life)
				child.scale = Vector2.ONE * (1.0 + life / max_life)
				if life >= max_life:
					child.queue_free()
		return

	_time += delta

	# Find nearest alive enemy to home in on
	var need_new_target := false
	if _target == null or not is_instance_valid(_target):
		need_new_target = true
	elif _target.has_method("take_damage"):
		# Check if target is already dying
		var enemies = get_tree().get_nodes_in_group("enemies")
		var found_alive := false
		for e in enemies:
			if e == _target:
				found_alive = true
				break
		if not found_alive:
			need_new_target = true

	if need_new_target:
		_target = null
		var best_dist: float = 1500.0
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			var d := global_position.distance_to(enemy.global_position)
			if d < best_dist:
				best_dist = d
				_target = enemy

	# Move towards target or straight right
	if _target and is_instance_valid(_target):
		var dir := (_target.global_position - global_position).normalized()
		position += dir * _speed * delta
	else:
		position.x += _speed * delta

	# Pulse
	var pulse := 1.0 + sin(_time * 20.0) * 0.15
	var outer = get_node_or_null("GlowOuter")
	if outer:
		outer.scale = Vector2(pulse, pulse)

	# Hit detection — large radius checks all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy.has_method("take_damage"):
			continue
		if global_position.distance_to(enemy.global_position) < _hit_radius:
			enemy.take_damage()
			_explode()
			return

	if _time > _max_lifetime or global_position.x > 3000:
		queue_free()

func _explode() -> void:
	_hit = true
	for i in range(8):
		var dot := ColorRect.new()
		var size := randf_range(8.0, 18.0)
		dot.size = Vector2(size, size)
		dot.position = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		var colors := [
			Color(0.3, 0.9, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 0.9),
			Color(1.0, 0.85, 0.2, 0.8),
		]
		dot.color = colors[i % colors.size()]
		dot.z_index = 10
		add_child(dot)
		dot.set_meta("vx", randf_range(-150.0, 150.0))
		dot.set_meta("vy", randf_range(-150.0, 150.0))
		dot.set_meta("life", 0.0)
		dot.set_meta("max_life", randf_range(0.2, 0.4))

	var outer = get_node_or_null("GlowOuter")
	if outer: outer.queue_free()
	var mid = get_node_or_null("GlowMid")
	if mid: mid.queue_free()
	var core = get_node_or_null("GlowCore")
	if core: core.queue_free()

	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)
