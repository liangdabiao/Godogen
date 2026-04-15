extends SceneTree
## Scene builder — run: timeout 60 godot --headless --script scenes/build_main.gd

func _initialize() -> void:
	print("Generating: Main")

	var root := Node2D.new()
	root.name = "Main"

	# Script
	var starter_script = load("res://scripts/game_starter.gd")
	root.set_script(starter_script)

	# === ParallaxBackground ===
	var parallax := ParallaxBackground.new()
	parallax.name = "Background"
	parallax.scroll_base_offset = Vector2(0, 0)
	parallax.scroll_ignore_camera_zoom = false
	root.add_child(parallax)

	# Layer 1: Sky (slowest)
	var sky_layer := ParallaxLayer.new()
	sky_layer.name = "SkyLayer"
	sky_layer.motion_mirroring = Vector2(1920, 0)
	sky_layer.motion_scale = Vector2(0.1, 0.1)
	parallax.add_child(sky_layer)
	var sky_sprite := Sprite2D.new()
	sky_sprite.name = "SkySprite"
	sky_sprite.centered = false
	sky_sprite.offset = Vector2(0, -100)
	sky_sprite.scale = Vector2(2.0, 2.0)
	sky_layer.add_child(sky_sprite)

	# Layer 2: Mountains
	var mtn_layer := ParallaxLayer.new()
	mtn_layer.name = "MountainLayer"
	mtn_layer.motion_mirroring = Vector2(1920, 0)
	mtn_layer.motion_scale = Vector2(0.3, 0.15)
	mtn_layer.motion_offset = Vector2(0, 200)
	parallax.add_child(mtn_layer)
	var mtn_sprite := Sprite2D.new()
	mtn_sprite.name = "MountainSprite"
	mtn_sprite.centered = false
	mtn_sprite.offset = Vector2(0, -150)
	mtn_sprite.scale = Vector2(2.0, 2.0)
	mtn_layer.add_child(mtn_sprite)

	# Layer 3: Cloud Islands
	var cloud_layer := ParallaxLayer.new()
	cloud_layer.name = "CloudIslandLayer"
	cloud_layer.motion_mirroring = Vector2(1920, 0)
	cloud_layer.motion_scale = Vector2(0.5, 0.2)
	cloud_layer.motion_offset = Vector2(0, 100)
	parallax.add_child(cloud_layer)
	var cloud_sprite := Sprite2D.new()
	cloud_sprite.name = "CloudIslandSprite"
	cloud_sprite.centered = false
	cloud_sprite.offset = Vector2(0, -200)
	cloud_sprite.scale = Vector2(2.0, 2.0)
	cloud_layer.add_child(cloud_sprite)

	# Layer 4: Foreground wisps (fastest)
	var fg_layer := ParallaxLayer.new()
	fg_layer.name = "ForegroundLayer"
	fg_layer.motion_mirroring = Vector2(1920, 0)
	fg_layer.motion_scale = Vector2(0.8, 0.1)
	fg_layer.motion_offset = Vector2(0, 400)
	parallax.add_child(fg_layer)
	var fg_sprite := Sprite2D.new()
	fg_sprite.name = "ForegroundSprite"
	fg_sprite.centered = false
	fg_sprite.offset = Vector2(0, -300)
	fg_sprite.scale = Vector2(2.0, 2.0)
	fg_layer.add_child(fg_sprite)

	# === World (spawn container) ===
	var world := Node2D.new()
	world.name = "World"
	var spawner_script = load("res://scripts/platform_spawner.gd")
	world.set_script(spawner_script)
	root.add_child(world)

	# === Player (instance from player.tscn) ===
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player"
	player.position = Vector2(200, 300)
	root.add_child(player)

	# === Camera2D ===
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(0, -50)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	root.add_child(camera)

	# === UI Layer ===
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 100
	root.add_child(ui_layer)

	var hud_root := Control.new()
	hud_root.name = "HUDControl"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(hud_root)

	# Attach HUD script
	var hud_script = load("res://scripts/hud.gd")
	hud_root.set_script(hud_script)

	# Top bar
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.add_theme_constant_override("separation", 20)
	top_bar.offset_left = 20.0
	top_bar.offset_right = -20.0
	top_bar.offset_top = 10.0
	hud_root.add_child(top_bar)

	# Distance label
	var dist_label := Label.new()
	dist_label.name = "DistanceLabel"
	dist_label.text = "距离: 0米"
	dist_label.add_theme_font_size_override("font_size", 24)
	dist_label.add_theme_color_override("font_color", Color.WHITE)
	top_bar.add_child(dist_label)

	# Score label (center)
	var score_label := Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "分数: 0"
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Color.GOLD)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(score_label)

	# Lives container
	var lives_hbox := HBoxContainer.new()
	lives_hbox.name = "LivesContainer"
	lives_hbox.add_theme_constant_override("separation", 5)
	top_bar.add_child(lives_hbox)

	# Peach label
	var peach_label := Label.new()
	peach_label.name = "PeachLabel"
	peach_label.text = "蟠桃: 0"
	peach_label.add_theme_font_size_override("font_size", 24)
	peach_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	top_bar.add_child(peach_label)

	# Restart button (right side)
	var restart_btn := Button.new()
	restart_btn.name = "RestartButton"
	restart_btn.text = "重新开始"
	restart_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.custom_minimum_size = Vector2(120, 40)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.add_theme_color_override("font_color", Color.WHITE)
	restart_btn.add_theme_color_override("font_hover_color", Color.GOLD)
	restart_btn.pressed.connect(func():
		hud_root._restart_game()
	)
	top_bar.add_child(restart_btn)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_left = 20.0
	bottom_bar.offset_right = -20.0
	bottom_bar.offset_bottom = -10.0
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_root.add_child(bottom_bar)

	# Power-up icon
	var power_icon := TextureRect.new()
	power_icon.name = "PowerUpIcon"
	power_icon.visible = false
	power_icon.custom_minimum_size = Vector2(48, 48)
	power_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bottom_bar.add_child(power_icon)

	# Game Over panel
	var go_panel := PanelContainer.new()
	go_panel.name = "GameOverPanel"
	go_panel.visible = false
	go_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	go_panel.offset_left = -200.0
	go_panel.offset_top = -150.0
	go_panel.offset_right = 200.0
	go_panel.offset_bottom = 150.0
	hud_root.add_child(go_panel)

	var go_vbox := VBoxContainer.new()
	go_vbox.name = "VBox"
	go_vbox.add_theme_constant_override("separation", 15)
	go_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	go_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	go_panel.add_child(go_vbox)

	var go_title := Label.new()
	go_title.name = "Title"
	go_title.text = "游戏结束"
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_title.add_theme_font_size_override("font_size", 40)
	go_title.add_theme_color_override("font_color", Color.RED)
	go_vbox.add_child(go_title)

	var go_score := Label.new()
	go_score.name = "FinalScore"
	go_score.text = "最终分数: 0"
	go_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_score.add_theme_font_size_override("font_size", 28)
	go_vbox.add_child(go_score)

	var go_dist := Label.new()
	go_dist.name = "FinalDistance"
	go_dist.text = "距离: 0米"
	go_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_dist.add_theme_font_size_override("font_size", 24)
	go_vbox.add_child(go_dist)

	var go_restart := Label.new()
	go_restart.name = "RestartHint"
	go_restart.text = "按 空格键 重新开始"
	go_restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_restart.add_theme_font_size_override("font_size", 20)
	go_vbox.add_child(go_restart)

	# === World boundary (invisible floor to catch falls) ===
	# We'll skip a world bounds floor — player dies on fall via Y check

	# === Save ===
	set_owner_on_new_nodes(root, root)
	var count := _count_nodes(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Pack failed: " + str(err))
		quit(1)
		return
	if not validate_packed_scene(packed, count, "res://scenes/main.tscn"):
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://scenes/main.tscn")
	if err != OK:
		push_error("Save failed: " + str(err))
		quit(1)
		return
	print("BUILT: %d nodes" % count)
	print("Saved: res://scenes/main.tscn")
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
