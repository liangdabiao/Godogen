extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_obstacle.gd

func _initialize() -> void:
	print("Generating: Obstacle")

	var root := StaticBody2D.new()
	root.name = "Obstacle"
	root.collision_layer = 4  # hazards
	root.collision_mask = 0

	# Script
	var script = load("res://scripts/obstacle.gd")
	root.set_script(script)

	# Sprite2D
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	root.add_child(sprite)

	# CollisionShape2D
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 80)
	collision.shape = rect
	root.add_child(collision)

	# Save
	set_owner_on_new_nodes(root, root)
	var count := _count_nodes(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Pack failed: " + str(err))
		quit(1)
		return
	if not validate_packed_scene(packed, count, "res://scenes/obstacle.tscn"):
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://scenes/obstacle.tscn")
	if err != OK:
		push_error("Save failed: " + str(err))
		quit(1)
		return
	print("BUILT: %d nodes" % count)
	print("Saved: res://scenes/obstacle.tscn")
	quit(0)

func set_owner_on_new_nodes(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		if child.scene_file_path.is_empty():
			set_owner_on_new_nodes(child, scene_owner)

func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

func validate_packed_scene(packed: PackedScene, expected_count: int, scene_path: String) -> bool:
	var test_instance = packed.instantiate()
	var actual := _count_nodes(test_instance)
	test_instance.free()
	if actual < expected_count:
		push_error("Pack validation failed for %s: expected %d nodes, got %d" % [scene_path, expected_count, actual])
		return false
	return true
