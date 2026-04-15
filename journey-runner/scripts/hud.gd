extends Control
## res://scripts/hud.gd — Game HUD

var _game_over_visible: bool = false

@onready var _score_label: Label = $TopBar/ScoreLabel
@onready var _distance_label: Label = $TopBar/DistanceLabel
@onready var _lives_container: HBoxContainer = $TopBar/LivesContainer
@onready var _peach_label: Label = $TopBar/PeachLabel
@onready var _power_up_icon: TextureRect = $BottomBar/PowerUpIcon
@onready var _game_over_panel: PanelContainer = $GameOverPanel
@onready var _final_score: Label = $GameOverPanel/VBox/FinalScore
@onready var _final_distance: Label = $GameOverPanel/VBox/FinalDistance
@onready var _restart_hint: Label = $GameOverPanel/VBox/RestartHint
@onready var _title_label: Label = $GameOverPanel/VBox/Title

func _ready() -> void:
	_game_over_panel.visible = false
	_create_life_hearts()
	_connect_signals()

func _connect_signals() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.distance_changed.connect(_on_distance_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.power_up_activated.connect(_on_power_up_activated)
	GameManager.power_up_expired.connect(_on_power_up_expired)

func _create_life_hearts() -> void:
	for i in range(3):
		var heart = TextureRect.new()
		heart.name = "Heart%d" % i
		heart.custom_minimum_size = Vector2(24, 24)
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.modulate = Color.RED
		_lives_container.add_child(heart)

func _process(_delta: float) -> void:
	# Update peach count display
	if _peach_label:
		_peach_label.text = "蟠桃: %d" % GameManager.peaches

	# Handle restart
	if _game_over_visible and Input.is_action_just_pressed("jump"):
		_restart_game()

func _on_score_changed(new_score: int) -> void:
	if _score_label:
		_score_label.text = "分数: %d" % new_score

func _on_distance_changed(new_distance: float) -> void:
	if _distance_label:
		_distance_label.text = "距离: %.0f米" % new_distance

func _on_lives_changed(new_lives: int) -> void:
	# Update heart display
	for i in range(_lives_container.get_child_count()):
		var heart = _lives_container.get_child(i)
		if heart is TextureRect:
			heart.visible = i < new_lives
			if i < new_lives:
				heart.modulate = Color.RED
			else:
				heart.modulate = Color.DARK_RED

func _on_game_over() -> void:
	_game_over_visible = true
	if _game_over_panel:
		_game_over_panel.visible = true
	if _final_score:
		_final_score.text = "最终分数: %d" % GameManager.score
	if _final_distance:
		_final_distance.text = "距离: %.0f米" % GameManager.distance
	if _title_label:
		_title_label.text = "游戏结束"

func _on_power_up_activated(type: String) -> void:
	if _power_up_icon:
		_power_up_icon.visible = true
		match type:
			"somersault_cloud":
				_power_up_icon.modulate = Color.GOLD

func _on_power_up_expired() -> void:
	if _power_up_icon:
		_power_up_icon.visible = false

func _restart_game() -> void:
	_game_over_visible = false
	if _game_over_panel:
		_game_over_panel.visible = false

	# Reset game state
	GameManager.start_game()

	# Clear all old world objects (platforms, enemies, obstacles, collectibles)
	var world = get_tree().get_root().get_node_or_null("Main/World")
	if world:
		for child in world.get_children():
			child.queue_free()
		# Re-spawn initial level
		if world.has_method("start"):
			world.start()

	# Reset player
	var player = get_tree().get_root().get_node_or_null("Main/Player")
	if player:
		player.global_position = Vector2(200, 300)
		player.velocity = Vector2.ZERO
		if player.has_method("_respawn"):
			player._respawn()

	# Reset camera
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		var camera = main.get_node_or_null("Camera2D")
		if camera:
			camera.global_position = Vector2(500, 250)

	# Reset HUD labels
	if _score_label:
		_score_label.text = "分数: 0"
	if _distance_label:
		_distance_label.text = "距离: 0米"

	# Reset life hearts
	for i in range(_lives_container.get_child_count()):
		var heart = _lives_container.get_child(i)
		if heart is TextureRect:
			heart.visible = true
			heart.modulate = Color.RED
