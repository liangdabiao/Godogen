# Memory

## Build Discoveries

- **Asset generator outputs JPEG as .png** — The `asset_gen.py` tool saves images with .png extension but the actual format is JPEG. Must convert with `magick` before Godot can import them.
- **rembg fails on CPU with 1024px images** — "bad allocation" error. Only smaller images work on CPU without CUDA. For larger sprites, use originals or install GPU deps.
- **preload() fails in SceneTree scripts** — Even though preload is evaluated at parse time, it fails when used in _ready() of scripts attached to scenes loaded via --script mode. Use load() with lazy initialization instead.
- **Autoloads unavailable in --script mode** — Cannot reference autoload singletons by name. Find via `root.get_children()` and match by `.name`.
- **get_tree() unavailable in SceneTree scripts** — Must use `root` directly or traverse from root.
- **await not reliable in --write-movie** — Use frame counter in _process() instead of await chains.
- **Camera2D property names changed in Godot 4.6** — Use `position_smoothing_enabled` and `position_smoothing_speed` instead of `smoothing_enabled` and `smoothing_speed`.
- **_ready() deferred after add_child()** — When using --script mode, _ready() fires after _initialize() returns. If you need nodes to be ready in _initialize(), call init methods manually.
- **Godot headless --import needed after adding new assets** — Must run before scenes can load them. Clean .godot directory if assets change format.

## Architecture Notes

- **Player uses distance-based pickup** — Area2D signals unreliable for fast-moving characters. Distance check in _physics_process() with get_tree().get_nodes_in_group() works reliably.
- **Platform spawner lazy-loads scenes** — _ensure_scenes_loaded() called from start() and _process(), avoiding preload issues.
- **Collectibles use groups** — "collectibles" group for player distance-check pickup, "platforms" group for respawn targeting.
