extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_player.gd

func _initialize() -> void:
	print("Generating: Player")

	var root := CharacterBody2D.new()
	root.name = "Player"
	root.collision_layer = 1
	root.collision_mask = 2 + 4 + 8 + 16  # platforms + collectibles + hazards + bounds

	# Script
	var script = load("res://scripts/player.gd")
	root.set_script(script)

	# AnimatedSprite2D — sprite sheet animation (texture loaded at runtime)
	var anim_sprite := AnimatedSprite2D.new()
	anim_sprite.name = "AnimatedSprite2D"
	root.add_child(anim_sprite)

	# CollisionShape2D — capsule
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var capsule := CapsuleShape2D.new()
	capsule.radius = 20.0
	capsule.height = 50.0
	collision.shape = capsule
	root.add_child(collision)

	# AnimationPlayer
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)

	# PickupArea (Area2D for collectible detection)
	var pickup_area := Area2D.new()
	pickup_area.name = "PickupArea"
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 4  # collectibles layer
	var pickup_collision := CollisionShape2D.new()
	pickup_collision.name = "CollisionShape2D"
	var pickup_circle := CircleShape2D.new()
	pickup_circle.radius = 35.0
	pickup_collision.shape = pickup_circle
	pickup_area.add_child(pickup_collision)
	root.add_child(pickup_area)

	# Save
	set_owner_on_new_nodes(root, root)
	var count := _count_nodes(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Pack failed: " + str(err))
		quit(1)
		return
	if not validate_packed_scene(packed, count, "res://scenes/player.tscn"):
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://scenes/player.tscn")
	if err != OK:
		push_error("Save failed: " + str(err))
		quit(1)
		return
	print("BUILT: %d nodes" % count)
	print("Saved: res://scenes/player.tscn")
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
