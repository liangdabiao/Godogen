# 西游记跑酷 (Journey Runner)

## Dimension: 2D

## Input Actions

| Action | Keys |
|--------|------|
| jump | Space, Up Arrow, W |
| slide | Down Arrow, S |
| restart | Space (game over screen) |

## Scenes

### Main
- **File:** res://scenes/main.tscn
- **Root type:** Node2D
- **Children:**
  - Background (ParallaxBackground) — 4 layers: sky, mountains, cloud islands, foreground
  - World (Node2D) — container for spawned platforms, obstacles, collectibles, enemies
  - Player (CharacterBody2D) — instanced from player.tscn
  - Camera2D — follows player with smooth lerp
  - UILayer (CanvasLayer, layer=100)
    - HUDControl (Control, full rect) — score, distance, lives, peach count, power-up slot

### Player
- **File:** res://scenes/player.tscn
- **Root type:** CharacterBody2D
- **Children:**
  - Sprite2D — player visual (Sun Wukong)
  - CollisionShape2D — capsule shape
  - AnimationPlayer — run, jump, fall, slide, hurt animations
  - Area2D (PickupArea) — larger radius for collectible detection
    - CollisionShape2D — circle

### Platform
- **File:** res://scenes/platform.tscn
- **Root type:** StaticBody2D
- **Children:**
  - Sprite2D — cloud platform visual
  - CollisionShape2D — rectangle

### Collectible
- **File:** res://scenes/collectible.tscn
- **Root type:** Area2D
- **Children:**
  - Sprite2D — peach or pill visual
  - CollisionShape2D — circle
  - AnimationPlayer — bob/rotate animation

### Obstacle
- **File:** res://scenes/obstacle.tscn
- **Root type:** StaticBody2D
- **Children:**
  - Sprite2D — stone pillar / rock visual
  - CollisionShape2D — rectangle

### Enemy
- **File:** res://scenes/enemy.tscn
- **Root type:** CharacterBody2D
- **Children:**
  - Sprite2D — flying demon visual
  - CollisionShape2D — circle
  - AnimationPlayer — wing flap

## Scripts

### GameManager
- **File:** res://scripts/game_manager.gd
- **Extends:** Node
- **Type:** Autoload singleton
- **Signals emitted:** game_over, score_changed, lives_changed, distance_changed, power_up_activated, power_up_expired
- **State:** score, distance, lives, peaches, current_power_up, game_running, difficulty_multiplier

### PlayerController
- **File:** res://scripts/player.gd
- **Extends:** CharacterBody2D
- **Attaches to:** Player:Player (scenes/player.tscn)
- **Signals emitted:** died, hit_obstacle, collected_item, landed
- **Behavior:** Auto-run rightward at constant speed. Jump (single + double). Slide (reduce hitbox). Power-up states (fly mode, invincibility). Collision response.

### Platform
- **File:** res://scripts/platform.gd
- **Extends:** StaticBody2D
- **Attaches to:** Platform:Platform (scenes/platform.tscn)
- **Behavior:** Mark for recycling when off-screen left.

### PlatformSpawner
- **File:** res://scripts/platform_spawner.gd
- **Extends:** Node2D
- **Attaches to:** World (main.tscn)
- **Behavior:** Spawn platforms ahead of player with procedural gaps/heights. Spawn obstacles, enemies, collectibles on platforms. Remove off-screen entities. Difficulty scales with distance.

### Collectible
- **File:** res://scripts/collectible.gd
- **Extends:** Area2D
- **Attaches to:** Collectible (scenes/collectible.tscn)
- **Signals emitted:** collected(type, value)
- **Behavior:** Bob animation. On contact with player: add score/peaches, play feedback, queue_free.

### Obstacle
- **File:** res://scripts/obstacle.gd
- **Extends:** StaticBody2D
- **Attaches to:** Obstacle (scenes/obstacle.tscn)
- **Behavior:** On body contact with player: deal damage, knockback. Mark for recycling when off-screen.

### Enemy
- **File:** res://scripts/enemy.gd
- **Extends:** CharacterBody2D
- **Attaches to:** Enemy (scenes/enemy.tscn)
- **Behavior:** Fly in sine wave pattern. On contact with player: deal damage. Mark for recycling when off-screen.

### HUD
- **File:** res://scripts/hud.gd
- **Extends:** Control
- **Attaches to:** HUDControl (main.tscn)
- **Signals received:** game_over, score_changed, lives_changed, distance_changed, power_up_activated, power_up_expired

## Signal Map

- Player:PickupArea.area_entered -> Collectible._on_pickup_area_entered
- Collectible.collected -> Player._on_item_collected
- Player.hit_obstacle -> GameManager._on_player_hit
- Player.died -> GameManager._on_player_died
- GameManager.score_changed -> HUD._on_score_changed
- GameManager.lives_changed -> HUD._on_lives_changed
- GameManager.distance_changed -> HUD._on_distance_changed
- GameManager.game_over -> HUD._on_game_over
- GameManager.power_up_activated -> HUD._on_power_up_activated
- GameManager.power_up_expired -> HUD._on_power_up_expired

## Collision Layers

| Layer | Name | bitmask |
|-------|------|---------|
| 1 | player | 1 |
| 2 | platforms | 2 |
| 3 | collectibles | 4 |
| 4 | hazards | 8 |
| 5 | world_bounds | 16 |

- Player: collision_layer=1, collision_mask=2+4+8+16 (platforms, collectibles, hazards, bounds)
- Platform: collision_layer=2, collision_mask=0
- Collectible: collision_layer=3, collision_mask=1 (detect player)
- Obstacle: collision_layer=4, collision_mask=0
- Enemy: collision_layer=4, collision_mask=1 (detect player)

## Asset Hints

- Player sprite — Sun Wukong golden armor, staff (64x64, animation frames for run/jump/fall/slide)
- Cloud platform — golden-glowing cloud (various widths: 128-512px, 48px tall)
- Red peach — 蟠桃 (32x32, with glow)
- Golden pill — 金丹 (24x24, glowing aura)
- Stone pillar — vertical rock pillar (64x128)
- Rock obstacle — jagged rock (96x96)
- Flying demon — red demon with wings (48x48, wing animation frames)
- Background sky — deep blue-purple gradient with stars (seamless, 1920px wide)
- Distant mountains — silhouette layer (seamless, 1920px wide)
- Cloud islands — mid-layer floating clouds (seamless, 1920px wide)
- Foreground wisps — translucent cloud wisps (seamless, 1920px wide)
- HUD icons — peach, pill, heart, cloud, monkey face (each 32x32)
- Power-up cloud — 筋斗云 golden cloud mount (64x64)
- Power-up aura — invincibility glow ring (64x64)

## Build Order

1. scenes/build_player.gd → scenes/player.tscn
2. scenes/build_platform.gd → scenes/platform.tscn
3. scenes/build_collectible.gd → scenes/collectible.tscn
4. scenes/build_obstacle.gd → scenes/obstacle.tscn
5. scenes/build_enemy.gd → scenes/enemy.tscn
6. scenes/build_main.gd → scenes/main.tscn (depends: all above)
