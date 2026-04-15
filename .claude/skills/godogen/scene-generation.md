# Scene Generation

Scene builders are GDScript files that run headless in Godot to produce `.tscn` files programmatically. They are NOT runtime scripts — they run once at build-time and exit.

## Scene Output Requirements

Generate a single GDScript file that:
1. `extends SceneTree` (required for headless execution)
2. Implements `_initialize()` as entry point
3. Builds complete node hierarchy with all properties set
4. Sets `owner` on ALL descendants for serialization
5. Attaches scripts from STRUCTURE.md via `set_script()`
6. Saves scene using `PackedScene.pack()` + `ResourceSaver.save()`
7. Calls `quit()` when done

## Owner Chain (CRITICAL)

**MUST call `set_owner_on_new_nodes(root, root)` ONCE at the end**, after all nodes are added.

```gdscript
# At end of _initialize(), AFTER all add_child() calls:
set_owner_on_new_nodes(root, root)

func set_owner_on_new_nodes(node: Node, scene_owner: Node) -> void:
    for child in node.get_children():
        child.owner = scene_owner
        if child.scene_file_path.is_empty():
            # Node created with .new() — recurse into children
            set_owner_on_new_nodes(child, scene_owner)
        # else: instantiated scene (GLB/TSCN) — don't recurse, keeps as reference
```

### Post-Pack Validation

Call after `packed.pack(root)` to verify no nodes were silently dropped:

```gdscript
func validate_packed_scene(packed: PackedScene, expected_count: int, scene_path: String) -> bool:
    var test_instance = packed.instantiate()
    var actual := _count_nodes(test_instance)
    test_instance.free()
    if actual < expected_count:
        push_error("Pack validation failed for %s: expected %d nodes, got %d — nodes were dropped during serialization" % [scene_path, expected_count, actual])
        return false
    return true
```

Use in the scene template between `packed.pack(root)` and `ResourceSaver.save()`. **Gate the save on the validation result:**
```gdscript
    var count := _count_nodes(root)
    var err := packed.pack(root)
    if err != OK:
        push_error("Pack failed: " + str(err))
        quit(1)
        return
    if not validate_packed_scene(packed, count, "res://{output_path}.tscn"):
        quit(1)
        return
```

**WRONG patterns** (cause missing nodes in saved .tscn):
```gdscript
# WRONG: Setting owner only on direct children, forgetting grandchildren
terrain.owner = root  # Terrain's children (Mesh, Collision) have NO owner!

# WRONG: Calling helper on containers instead of root
set_owner_on_new_nodes(track_container, root)  # track_container itself has NO owner!
```

**GLB OWNERSHIP BUG** — Never use unconditional recursion. If you recurse into instantiated GLB models, ALL internal mesh/material nodes get serialized inline as text, causing 100MB+ .tscn files.

## Common Node Compositions

**3D Physics Object:**
```gdscript
var body := RigidBody3D.new()
var collision := CollisionShape3D.new()
var mesh := MeshInstance3D.new()
var shape := BoxShape3D.new()
shape.size = Vector3(1, 1, 1)
collision.shape = shape
body.add_child(collision)
body.add_child(mesh)
```

**Camera Rig:**
```gdscript
var pivot := Node3D.new()
var camera := Camera3D.new()
camera.position.z = 5
pivot.add_child(camera)
```

## Script Attachment (in Scenes)

```gdscript
# Attach scripts listed in STRUCTURE.md "Attaches to" fields
var script := load("res://scripts/player_controller.gd")
player_node.set_script(script)
```

## Asset Loading

**3D models (GLB):**
```gdscript
# MUST type as PackedScene, use = (not :=) for instantiate()
var model_scene: PackedScene = load("res://assets/glb/car.glb")
var model = model_scene.instantiate()
model.name = "CarModel"

# Measure for scaling — find MeshInstance3D (GLB structure varies, may be nested)
var mesh_inst: MeshInstance3D = find_mesh_instance(model)
var aabb: AABB = mesh_inst.get_aabb() if mesh_inst else AABB(Vector3.ZERO, Vector3.ONE)

# Scale to target size (e.g., car should be ~2 units long)
var target_length := 2.0
var scale_factor: float = target_length / aabb.size.x
model.scale = Vector3.ONE * scale_factor
model.position.y = -aabb.position.y * scale_factor  # Fix vertical alignment

parent_node.add_child(model)

func find_mesh_instance(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D:
        return node
    for child in node.get_children():
        var found = find_mesh_instance(child)  # Recursive — use = not :=
        if found:
            return found
    return null
```

**GLB orientation:** Imported models often face the wrong axis. After instantiating, check the AABB: the longest dimension tells you which local axis the model faces. If a car's AABB is longest on Z but your game expects forward=negative Z, no rotation needed; if longest on X, rotate 90°. For animals/characters, the forward-facing axis must align with the direction of movement — an animal moving sideways is a clear bug. Verify this in screenshots: if the bounding box or silhouette doesn't match the movement direction, fix the rotation.

**Collision shapes for 3D models:** Always use simple primitives (BoxShape3D, SphereShape3D, CapsuleShape3D). Never use `create_convex_shape()` or `create_trimesh_shape()` on imported GLB meshes — causes <1 FPS on high-poly models (100k+ triangles).

```gdscript
# Box from AABB — use this for all imported models
var box := BoxShape3D.new()
box.size = aabb.size * model.scale
collision_shape.shape = box
```

**Textures (PNG):**
```gdscript
var mat := StandardMaterial3D.new()
mat.albedo_texture = load("res://assets/img/grass.png")
mesh_instance.set_surface_override_material(0, mat)
```

**Texture UV tiling:** For large surfaces, scale UVs to avoid stretched textures:
```gdscript
mat.uv1_scale = Vector3(10, 10, 1)  # Tile every 2m on a 20m floor
```

## Child Scene Instancing

```gdscript
# MUST type as PackedScene, use = for instantiate()
var car_scene: PackedScene = load("res://scenes/car.tscn")
var car = car_scene.instantiate()
car.name = "PlayerCar"
car.position = Vector3(0, 0, 5)
root.add_child(car)
car.owner = root  # Child internals already have owner — just set on instance root
```

## Scene Template

```gdscript
extends SceneTree

func _initialize() -> void:
    print("Generating: {scene_name}")

    var root := {RootNodeType}.new()
    root.name = "{SceneName}"

    # ... build node hierarchy, add_child(), set properties ...

    # Set ownership chain (skips instantiated scene internals)
    set_owner_on_new_nodes(root, root)

    # Count nodes before packing for verification
    var count := _count_nodes(root)

    # Pack and validate
    var packed := PackedScene.new()
    var err := packed.pack(root)
    if err != OK:
        push_error("Pack failed: " + str(err))
        quit(1)
        return
    if not validate_packed_scene(packed, count, "res://{output_path}.tscn"):
        quit(1)
        return

    # Save (only if validation passed)
    err = ResourceSaver.save(packed, "res://{output_path}.tscn")
    if err != OK:
        push_error("Save failed: " + str(err))
        quit(1)
        return

    print("BUILT: %d nodes" % count)
    print("Saved: res://{output_path}.tscn")
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
```

## Scene Constraints

## Animated Sprites (Sprite Sheets)

When using sprite sheets generated by `sprite_gen.py`, choose the right approach based on complexity:

### Sprite2D with hframes/vframes (single animation, simple)

For characters that only need one animation state:

```gdscript
var sprite := Sprite2D.new()
sprite.texture = load("res://assets/img/char_run.png")
sprite.hframes = 4  # columns in the grid
sprite.vframes = 4  # rows in the grid
sprite.frame = 0    # set in _process() to animate
parent.add_child(sprite)
```

Animate by incrementing `sprite.frame` in a `_process()` method. Wraps automatically.

**NOTE:** `load()` requires `.import` files. For sprite sheets generated at runtime (by sprite_gen.py), use `Image.load_from_file()` instead (see Runtime Loading below).

### AnimatedSprite2D with SpriteFrames (multiple animations, recommended)

For characters with multiple animation states (run, idle, attack, etc.).

**In scene builders (build-time):** Only create the node, NOT the SpriteFrames. Texture loading and SpriteFrames setup must happen at runtime because sprite_gen.py generates images after the scene is built.

```gdscript
# Scene builder — only create the empty node
var anim_sprite := AnimatedSprite2D.new()
anim_sprite.name = "AnimatedSprite2D"
root.add_child(anim_sprite)
```

**In runtime scripts (_ready):** Load texture and build SpriteFrames:

```gdscript
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    _load_sprite_sheet()

func _load_sprite_sheet() -> void:
    var path := "res://assets/img/char_run.png"
    # Image.load_from_file bypasses Godot's import system
    # Works without .import files in both headless and normal mode
    var image := Image.load_from_file(path)
    if not image:
        push_warning("Failed to load: " + path)
        return

    var tex := ImageTexture.create_from_image(image)
    var grid := 4
    var fw: float = float(tex.get_width()) / float(grid)
    var fh: float = float(tex.get_height()) / float(grid)

    var sf := SpriteFrames.new()
    sf.add_animation("run")
    sf.set_animation_speed("run", 12.0)
    sf.set_animation_loop("run", true)  # NOT set_loop() — that doesn't exist
    for i in range(grid * grid):
        var at := AtlasTexture.new()
        at.atlas = tex
        var col := i % grid
        var row := i / grid
        at.region = Rect2(float(col) * fw, float(row) * fh, fw, fh)
        sf.add_frame("run", at)

    _sprite.sprite_frames = sf
    _sprite.play("run")
```

**Critical:** Always use `float()` casts for region calculations. Integer division truncates in GDScript, causing wrong frame crops.

**Scaling:** Calculate scale based on desired display size vs frame dimensions:
```gdscript
var display_h := 80.0  # desired pixel height in game
var scale_factor: float = display_h / fh
_sprite.scale = Vector2(scale_factor, scale_factor)
```

**Multiple animations on one character:** add each animation to the same `SpriteFrames`:

```gdscript
# After adding "run" above, add "idle" from a different sprite sheet
sf.add_animation("idle")
sf.set_animation_speed("idle", 8.0)
sf.set_animation_loop("idle", true)
var idle_tex = _load_image("res://assets/img/char_idle.png")
var idle_fw: float = float(idle_tex.get_width()) / 4.0
var idle_fh: float = float(idle_tex.get_height()) / 4.0
for i in range(16):
    var at := AtlasTexture.new()
    at.atlas = idle_tex
    var col := i % 4
    var row := i / 4
    at.region = Rect2(float(col) * idle_fw, float(row) * idle_fh, idle_fw, idle_fh)
    sf.add_frame("idle", at)
```

**Runtime animation switching:** `anim.play("attack")`, `anim.play("idle")`, etc. Listen to `animation_finished` signal for one-shot animations (attack, death, jump).

### Runtime Texture Loading

Sprite sheets from `sprite_gen.py` are generated after the project exists, so they have no `.import` files. Godot's `load()` returns null without `.import` files in normal game mode.

**Two loading methods:**

| Method | Works without .import? | Headless? | Use case |
|--------|----------------------|-----------|----------|
| `load("res://path.png")` | No | Yes (sometimes) | Assets imported by Godot editor |
| `Image.load_from_file("res://path.png")` + `ImageTexture.create_from_image()` | **Yes** | **Yes** | Generated sprite sheets |

```gdscript
# Helper to reuse across animations
func _load_image(path: String) -> ImageTexture:
    var image := Image.load_from_file(path)
    if not image:
        push_warning("Failed to load: " + path)
        return null
    return ImageTexture.create_from_image(image)
```

**Important:** Use `float()` casts for all region calculations in scene builders to avoid integer truncation in GDScript.

## Scene Constraints

- Do NOT use `@onready` or scene-time annotations (this runs at build-time)
- Do NOT use `preload()` — use `load()` (preload fails in headless)
- Do NOT connect signals at build-time — scripts aren't instantiated yet. Signal connections belong in runtime scripts' `_ready()` method
- **No spatial methods in `_initialize()`** — `look_at()`, `to_global()`, etc. fail because nodes aren't in the tree yet. Use `rotation_degrees` or compute transforms manually. In runtime scripts (`_ready()`, `_process()`), **always use `look_at()` to orient cameras and objects toward targets** — it's the correct tool there. Manual rotation math is error-prone and unnecessary.
- **2D/3D consistency** — never mix dimensions in the same scene hierarchy.

## Visual Effects (Flash, Burst, Trail)

**Prefer Tween + simple nodes over particle systems.** Particle nodes (CPUParticles2D, GPUParticles2D) do NOT render in `--headless` or `--write-movie` capture modes, making them invisible in automated screenshots. Use Tween-animated ColorRect/Sprite2D nodes instead — they render reliably everywhere and give full control.

### Jump/impact flash (runtime GDScript)

```gdscript
func _emit_jump_fx() -> void:
    var colors := [
        Color(1.0, 0.95, 0.4, 1.0),   # bright yellow
        Color(1.0, 0.7, 0.1, 0.9),    # orange-yellow
        Color(1.0, 0.4, 0.0, 0.8),    # orange
    ]
    for i in range(8):
        var dot := ColorRect.new()
        var size := randf_range(4.0, 12.0)
        dot.size = Vector2(size, size)
        dot.position = Vector2(
            global_position.x + randf_range(-15, 15),
            global_position.y + randf_range(20, 40)
        )
        dot.color = colors[i % colors.size()]
        dot.z_index = 5
        get_tree().current_scene.add_child(dot)
        # Parallel tweens: move down + fade out
        var dur := randf_range(0.2, 0.5)
        var tw_move := create_tween()
        tw_move.tween_property(dot, "position:y", dot.position.y + randf_range(20, 50), dur)
        var tw_fx := create_tween()
        tw_fx.set_parallel(true)
        tw_fx.tween_property(dot, "modulate:a", 0.0, dur)
        tw_fx.tween_property(dot, "scale", Vector2(2.0, 2.0), dur)
        tw_fx.tween_callback(dot.queue_free)
```

### When to use particle systems vs Tween nodes

| Effect type | Recommended approach | Why |
|-------------|---------------------|-----|
| Jump/land flash | Tween + ColorRect | Simple, testable |
| Collect item sparkle | Tween + Sprite2D | Need custom shapes |
| Trail behind character | GPUParticles2D | Continuous emission, performance-critical |
| Explosion/impact burst | Tween + Sprite2D | Testable, controllable |
| Ambient particles (dust, rain) | CPUParticles2D | Continuous, not screenshot-critical |

**Rule of thumb:** If the effect needs to be visible in automated screenshots (QA, capture), use Tween nodes. If it's ambient/continuous and only seen by human players, particle systems are fine.

### Particle system reference (if needed)

**GPUParticles2D** — GPU-driven, all physics on `ParticleProcessMaterial`:
```gdscript
var pmat := ParticleProcessMaterial.new()
pmat.direction = Vector3(0, 1, 0)
pmat.spread = 45.0
pmat.gravity = Vector3(0, 400, 0)
pmat.initial_velocity_min = 80.0
pmat.initial_velocity_max = 160.0
pmat.scale_min = 0.5
pmat.scale_max = 1.5
particles.process_material = pmat
```

**CPUParticles2D** — CPU-driven, all properties on the node:
```gdscript
particles.direction = Vector2(0, 1)
particles.spread = 45.0
particles.gravity = Vector2(0, 400)
particles.scale_amount_min = 0.5
particles.scale_amount_max = 1.5
particles.color_ramp = Gradient.new()  # NOT GradientTexture1D
```

See `quirks.md` for the full list of particle system gotchas.

## Environment & Lighting (3D Scenes)

When building 3D scenes, set up environment and lighting programmatically:

```gdscript
# WorldEnvironment
var world_env := WorldEnvironment.new()
var env := Environment.new()
env.background_mode = Environment.BG_SKY
env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
env.ambient_light_color = Color.WHITE
env.ambient_light_sky_contribution = 0.5
var sky := Sky.new()
sky.sky_material = ProceduralSkyMaterial.new()
env.sky = sky
world_env.environment = env
root.add_child(world_env)

# Sun (DirectionalLight3D)
var sun := DirectionalLight3D.new()
sun.shadow_enabled = true
sun.shadow_bias = 0.05
sun.shadow_blur = 2.0
sun.directional_shadow_max_distance = 30.0
sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
sun.rotation_degrees = Vector3(-45, -30, 0)
root.add_child(sun)
```

## CSG for Rapid Prototyping

CSG nodes generate collision automatically — no separate CollisionShape needed:

```gdscript
var floor := CSGBox3D.new()
floor.size = Vector3(20, 0.5, 20)
floor.use_collision = true
floor.material = ground_mat
root.add_child(floor)

# Subtraction (carve holes): child CSG on parent CSG
var hole := CSGCylinder3D.new()
hole.operation = CSGShape3D.OPERATION_SUBTRACTION
hole.radius = 1.0
hole.height = 1.0
floor.add_child(hole)
```

## Noise/Procedural Textures

```gdscript
var noise := FastNoiseLite.new()
noise.noise_type = FastNoiseLite.TYPE_CELLULAR
noise.frequency = 0.02
noise.fractal_type = FastNoiseLite.FRACTAL_FBM
noise.fractal_octaves = 5

var tex := NoiseTexture2D.new()
tex.noise = noise
tex.width = 1024
tex.height = 1024
tex.seamless = true       # tileable
tex.as_normal_map = true  # for normal maps
tex.bump_strength = 2.0
```

## StandardMaterial3D Extended Properties

Beyond basic albedo, useful properties for richer materials:
- `normal_enabled = true` + `normal_texture` + `normal_scale = 2.0`
- `rim_enabled = true` + `rim_tint = 1.0` — silhouette glow
- `emission_enabled = true` + `emission_texture` — self-illumination
- `texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC`
