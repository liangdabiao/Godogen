## AnimationNodeBlendSpace1D <- AnimationRootNode

A resource used by AnimationNodeBlendTree. AnimationNodeBlendSpace1D represents a virtual axis on which any type of AnimationRootNodes can be added using `add_blend_point`. Outputs the linear blend of the two AnimationRootNodes adjacent to the current value. You can set the extents of the axis with `min_space` and `max_space`.

**Props:**
- blend_mode: int (AnimationNodeBlendSpace1D.BlendMode) = 0
- cyclic_length: float = 0.0
- max_space: float = 1.0
- min_space: float = -1.0
- snap: float = 0.1
- sync: bool
- sync_mode: int (AnimationNodeBlendSpace1D.SyncMode) = 0
- value_label: String = "value"

- **blend_mode**: Controls the interpolation between animations.
- **cyclic_length**: The cycle length in seconds used by `SYNC_MODE_CYCLIC_CONSTANT`. All animations are time-scaled so they complete one full cycle in this duration. Must be greater than `0` for cyclic sync to take effect.
- **max_space**: The blend space's axis's upper limit for the points' position. See `add_blend_point`.
- **min_space**: The blend space's axis's lower limit for the points' position. See `add_blend_point`.
- **snap**: Position increment to snap to when moving a point on the axis.
- **sync**: If `true`, sync mode is enabled (equivalent to `SYNC_MODE_INDEPENDENT`). This property is kept for backward compatibility.
- **sync_mode**: Controls how animations are synced when blended. See `SyncMode` for available options.
- **value_label**: Label of the virtual axis of the blend space.

**Methods:**
- add_blend_point(node: AnimationRootNode, pos: float, at_index: int = -1, name: StringName = &"") - Adds a new point with `name` that represents a `node` on the virtual axis at a given position set by `pos`. You can insert it at a specific index using the `at_index` argument. If you use the default value for `at_index`, the point is inserted at the end of the blend points array. **Note:** If no name is provided, safe index is used as reference. In the future, empty names will be deprecated, so explicitly passing a name is recommended.
- find_blend_point_by_name(name: StringName) -> int - Returns the index of the blend point with the given `name`. Returns `-1` if no blend point with that name is found.
- get_blend_point_count() -> int - Returns the number of points on the blend axis.
- get_blend_point_name(point: int) -> StringName - Returns the name of the blend point at index `point`.
- get_blend_point_node(point: int) -> AnimationRootNode - Returns the AnimationNode referenced by the point at index `point`.
- get_blend_point_position(point: int) -> float - Returns the position of the point at index `point`.
- remove_blend_point(point: int) - Removes the point at index `point` from the blend axis.
- reorder_blend_point(from_index: int, to_index: int) - Swaps the blend points at indices `from_index` and `to_index`, exchanging their positions and properties.
- set_blend_point_name(point: int, name: StringName) - Sets the name of the blend point at index `point`. If the name conflicts with an existing point, a unique name will be generated automatically.
- set_blend_point_node(point: int, node: AnimationRootNode) - Changes the AnimationNode referenced by the point at index `point`.
- set_blend_point_position(point: int, pos: float) - Updates the position of the point at index `point` on the blend axis.

**Enums:**
**BlendMode:** BLEND_MODE_INTERPOLATED=0, BLEND_MODE_DISCRETE=1, BLEND_MODE_DISCRETE_CARRY=2
  - BLEND_MODE_INTERPOLATED: The interpolation between animations is linear.
  - BLEND_MODE_DISCRETE: The blend space plays the animation of the animation node which blending position is closest to. Useful for frame-by-frame 2D animations.
  - BLEND_MODE_DISCRETE_CARRY: Similar to `BLEND_MODE_DISCRETE`, but starts the new animation at the last animation's playback position.
**SyncMode:** SYNC_MODE_NONE=0, SYNC_MODE_INDEPENDENT=1, SYNC_MODE_CYCLIC_MUTABLE=2, SYNC_MODE_CYCLIC_CONSTANT=3
  - SYNC_MODE_NONE: Inactive animations are frozen and do not advance.
  - SYNC_MODE_INDEPENDENT: Inactive animations advance with a weight of `0`. This is equivalent to the previous `sync = true` behavior.
  - SYNC_MODE_CYCLIC_MUTABLE: All animations are time-scaled so they stay in sync, with the cycle length dynamically computed from active blend weights. This is self-normalizing: a solo animation plays at normal speed. **Note:** If you apply AnimationNodeTimeSeek to the result when handling animations of different lengths, synchronization will be broken. In such cases, it is recommended to use `AnimationNodeAnimation.use_custom_timeline` to align the animation lengths.
  - SYNC_MODE_CYCLIC_CONSTANT: All animations are time-scaled so they complete one cycle in `cyclic_length` seconds, keeping them in sync regardless of their individual lengths. **Note:** If you apply AnimationNodeTimeSeek to the result when handling animations of different lengths, synchronization will be broken. In such cases, it is recommended to use `AnimationNodeAnimation.use_custom_timeline` to align the animation lengths.

