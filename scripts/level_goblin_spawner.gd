extends Node2D

## Spawns a configurable crowd for the level. Put this on the level root,
## assign goblin_scene, then tune goblin_count in the Inspector.

const DEPTH_Z_INDEX_MIN: int = -4096
const DEPTH_Z_INDEX_MAX: int = 4096
const OBSTACLE_CLICK_BLOCKER_GROUP: String = "obstacle_click_blocker"
const OBSTACLE_CLICK_BLOCKER_AREA_GROUP: String = "obstacle_click_blocker_area"

@export_category("Goblins")
@export var goblin_scene: PackedScene
@export var goblin_count: int = 10
@export_range(1, 128, 1) var target_count: int = 1

## -1 means pick random targets. Set this to 0, 1, 2, etc. if you want a
## specific spawned goblin included as a target for testing.
@export var target_index: int = -1

## Keeps spawns away from the exact screen edge. The goblin controller still
## clamps movement to the screen after spawning.
@export var spawn_padding: float = 48.0

@export var goblin_name_prefix: String = "Goblin"

@export_category("Level Timing")
@export_range(0.0, 30.0, 0.1, "suffix:s") var shot_cooldown_seconds: float = 5.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var panic_duration_seconds: float = 10.0
@export_range(0.1, 20.0, 0.1, "suffix:s") var win_runoff_seconds: float = 3.0
@export_range(0.0, 20.0, 0.1, "suffix:s") var wrong_kill_runoff_penalty_seconds: float = 2.0

## Shared body palette for all spawned goblins. Each goblin randomly picks one
## stepped blend between these two colors, so several goblins can share the
## target's body color.
@export var randomize_goblin_body_colors: bool = true
@export var goblin_body_color_a: Color = Color(0.45, 0.95, 0.25, 1.0)
@export var goblin_body_color_b: Color = Color(0.14, 0.55, 0.24, 1.0)
@export_range(2, 12, 1) var goblin_body_color_steps: int = 3

@export_category("Background")
@export var background_texture: Texture2D
@export var background_sprite_path: NodePath = NodePath("BackgroundFloor")

@export_category("Background Obstacles")
@export var spawn_background_obstacles: bool = true
@export var depth_sort_goblins_with_obstacles: bool = true
@export var bg_object_parent_path: NodePath = NodePath("bg_object_parent")
@export var obstacle_scenes: Array[PackedScene] = []
@export_dir var obstacle_scene_directory: String = "res://scenes/obstacles"

## Keep this range low so the obstacles feel sprinkled in rather than crowded.
@export var obstacle_count_range: Vector2i = Vector2i(5, 8)
@export var obstacle_scale_range: Vector2 = Vector2(0.9, 1.1)
@export var min_obstacle_distance: float = 170.0
@export var obstacle_spawn_padding: float = 64.0
@export var obstacle_spawn_attempts_per_obstacle: int = 32
@export var randomize_obstacle_flip: bool = true


func _ready() -> void:
	_apply_background_texture()
	_configure_depth_sorting()

	if spawn_background_obstacles:
		_spawn_background_obstacles()

	if goblin_scene == null:
		push_error("Level goblin spawner needs a Goblin Scene assigned.")
		return

	_spawn_goblins()


func _apply_background_texture() -> void:
	if background_texture == null:
		return

	var background_sprite: Sprite2D = get_node_or_null(background_sprite_path) as Sprite2D
	if background_sprite == null:
		push_warning("Background texture was assigned, but no BackgroundFloor Sprite2D was found.")
		return

	background_sprite.texture = background_texture


func _configure_depth_sorting() -> void:
	var sortable_parent: Node2D = _get_background_object_parent()
	if sortable_parent != null:
		sortable_parent.y_sort_enabled = depth_sort_goblins_with_obstacles


func _get_background_object_parent() -> Node2D:
	if String(bg_object_parent_path).is_empty():
		return null

	return get_node_or_null(bg_object_parent_path) as Node2D


func _get_goblin_parent() -> Node:
	if depth_sort_goblins_with_obstacles:
		var sortable_parent: Node2D = _get_background_object_parent()
		if sortable_parent != null:
			sortable_parent.y_sort_enabled = true
			return sortable_parent

	return self


func _spawn_background_obstacles() -> void:
	var bg_object_parent: Node2D = _get_background_object_parent()
	if bg_object_parent == null:
		push_warning("Background obstacle spawning skipped: no bg_object_parent Node2D was found.")
		return

	var available_obstacle_scenes: Array[PackedScene] = _get_available_obstacle_scenes()
	if available_obstacle_scenes.is_empty():
		push_warning("Background obstacle spawning skipped: no obstacle scenes were assigned or found.")
		return

	var count: int = _get_obstacle_count()
	if count <= 0:
		return

	var spawn_bounds: Rect2 = _get_obstacle_spawn_bounds()
	if spawn_bounds.size.x <= 0.0 or spawn_bounds.size.y <= 0.0:
		push_warning("Background obstacle spawning skipped: obstacle spawn bounds are empty.")
		return

	var placed_positions: Array[Vector2] = []
	for i in range(count):
		var obstacle_position: Variant = _find_obstacle_spawn_position(spawn_bounds, placed_positions)
		if obstacle_position == null:
			break

		var obstacle_scene: PackedScene = available_obstacle_scenes[
			randi_range(0, available_obstacle_scenes.size() - 1)
		]
		var obstacle_instance: Node = obstacle_scene.instantiate()
		var obstacle_2d: Node2D = obstacle_instance as Node2D
		if obstacle_2d == null:
			push_warning("Background obstacle scene skipped: root node must be a Node2D.")
			obstacle_instance.queue_free()
			continue

		var obstacle_scale: float = _get_random_obstacle_scale()

		obstacle_2d.name = "Obstacle%d" % [i + 1]
		obstacle_2d.scale *= obstacle_scale
		_configure_obstacle_click_blockers(obstacle_2d)
		_set_obstacle_flip(obstacle_2d, randomize_obstacle_flip and randf() < 0.5)

		bg_object_parent.add_child(obstacle_2d)
		obstacle_2d.global_position = obstacle_position as Vector2
		_update_obstacle_depth_z_index(obstacle_2d)

		placed_positions.append(obstacle_2d.global_position)


func _configure_obstacle_click_blockers(obstacle_node: Node) -> void:
	obstacle_node.add_to_group(OBSTACLE_CLICK_BLOCKER_GROUP)
	_configure_obstacle_click_blockers_recursive(obstacle_node)


func _configure_obstacle_click_blockers_recursive(node: Node) -> void:
	var area: Area2D = node as Area2D
	if area != null:
		area.add_to_group(OBSTACLE_CLICK_BLOCKER_AREA_GROUP)

	for child in node.get_children():
		_configure_obstacle_click_blockers_recursive(child)


func _set_obstacle_flip(obstacle_node: Node, flip_h: bool) -> void:
	for child in obstacle_node.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite != null:
			sprite.flip_h = flip_h

		_set_obstacle_flip(child, flip_h)


func _update_obstacle_depth_z_index(obstacle_node: Node2D) -> void:
	obstacle_node.z_as_relative = false
	obstacle_node.z_index = _get_depth_z_index(_get_visual_bottom_global_y(obstacle_node))


func _get_visual_bottom_global_y(node: Node) -> float:
	var visual_bottom_y: float = -INF
	var sprite: Sprite2D = node as Sprite2D
	if sprite != null and sprite.texture != null:
		visual_bottom_y = _get_sprite_global_bounds(sprite).end.y

	for child in node.get_children():
		visual_bottom_y = maxf(visual_bottom_y, _get_visual_bottom_global_y(child))

	if visual_bottom_y == -INF:
		var node_2d: Node2D = node as Node2D
		if node_2d != null:
			return node_2d.global_position.y
		return 0.0

	return visual_bottom_y


func _get_depth_z_index(sort_y: float) -> int:
	return clampi(int(round(sort_y)), DEPTH_Z_INDEX_MIN, DEPTH_Z_INDEX_MAX)


func _get_available_obstacle_scenes() -> Array[PackedScene]:
	var available_scenes: Array[PackedScene] = []
	for obstacle_scene in obstacle_scenes:
		if obstacle_scene != null:
			available_scenes.append(obstacle_scene)

	if !available_scenes.is_empty():
		return available_scenes

	return _load_obstacle_scenes_from_directory()


func _load_obstacle_scenes_from_directory() -> Array[PackedScene]:
	var available_scenes: Array[PackedScene] = []
	if obstacle_scene_directory.is_empty():
		return available_scenes

	for file_name in DirAccess.get_files_at(obstacle_scene_directory):
		if file_name.get_extension().to_lower() != "tscn":
			continue

		var resource_path: String = obstacle_scene_directory.path_join(file_name)
		var obstacle_scene: PackedScene = load(resource_path) as PackedScene
		if obstacle_scene != null:
			available_scenes.append(obstacle_scene)

	return available_scenes


func _get_obstacle_count() -> int:
	var min_count: int = maxi(0, mini(obstacle_count_range.x, obstacle_count_range.y))
	var max_count: int = maxi(min_count, maxi(obstacle_count_range.x, obstacle_count_range.y))
	return randi_range(min_count, max_count)


func _get_random_obstacle_scale() -> float:
	var min_scale: float = maxf(0.01, minf(obstacle_scale_range.x, obstacle_scale_range.y))
	var max_scale: float = maxf(min_scale, maxf(obstacle_scale_range.x, obstacle_scale_range.y))
	return randf_range(min_scale, max_scale)


func _get_obstacle_spawn_bounds() -> Rect2:
	var bounds: Rect2 = _get_background_sprite_bounds()
	var safe_padding: float = minf(
		maxf(0.0, obstacle_spawn_padding),
		minf(bounds.size.x, bounds.size.y) * 0.45
	)
	var padding_vector: Vector2 = Vector2(safe_padding, safe_padding)
	return Rect2(
		bounds.position + padding_vector,
		bounds.size - padding_vector * 2.0
	)


func _get_background_sprite_bounds() -> Rect2:
	var background_sprite: Sprite2D = get_node_or_null(background_sprite_path) as Sprite2D
	if background_sprite == null or background_sprite.texture == null:
		return _get_spawn_bounds()

	return _get_sprite_global_bounds(background_sprite)


func _get_sprite_global_bounds(sprite: Sprite2D) -> Rect2:
	var sprite_size: Vector2 = sprite.texture.get_size()
	if sprite.region_enabled:
		sprite_size = sprite.region_rect.size

	var local_origin: Vector2 = -sprite_size * 0.5 if sprite.centered else Vector2.ZERO
	local_origin += sprite.offset

	var sprite_corners: Array[Vector2] = [
		local_origin,
		local_origin + Vector2(sprite_size.x, 0.0),
		local_origin + Vector2(0.0, sprite_size.y),
		local_origin + sprite_size
	]
	var world_min: Vector2 = sprite.global_transform * sprite_corners[0]
	var world_max: Vector2 = world_min

	for i in range(1, sprite_corners.size()):
		var world_corner: Vector2 = sprite.global_transform * sprite_corners[i]
		world_min.x = minf(world_min.x, world_corner.x)
		world_min.y = minf(world_min.y, world_corner.y)
		world_max.x = maxf(world_max.x, world_corner.x)
		world_max.y = maxf(world_max.y, world_corner.y)

	return Rect2(world_min, world_max - world_min)


func _find_obstacle_spawn_position(spawn_bounds: Rect2, placed_positions: Array[Vector2]) -> Variant:
	var attempts: int = maxi(1, obstacle_spawn_attempts_per_obstacle)
	var spawn_max: Vector2 = spawn_bounds.position + spawn_bounds.size

	for i in range(attempts):
		var candidate: Vector2 = Vector2(
			randf_range(spawn_bounds.position.x, spawn_max.x),
			randf_range(spawn_bounds.position.y, spawn_max.y)
		)
		if _is_obstacle_position_spaced(candidate, placed_positions):
			return candidate

	return null


func _is_obstacle_position_spaced(candidate: Vector2, placed_positions: Array[Vector2]) -> bool:
	var required_distance: float = maxf(0.0, min_obstacle_distance)
	for placed_position in placed_positions:
		if candidate.distance_to(placed_position) < required_distance:
			return false

	return true


func _spawn_goblins() -> void:
	var count: int = maxi(1, goblin_count)
	var chosen_target_indices: Array[int] = _get_target_indices(count)
	var goblin_parent: Node = _get_goblin_parent()

	for i in range(count):
		var goblin: Node = goblin_scene.instantiate()
		goblin.name = "%s%d" % [goblin_name_prefix, i + 1]
		goblin.set("is_target", chosen_target_indices.has(i))
		_configure_goblin_level_timing(goblin)
		_configure_goblin_body_palette(goblin)

		goblin_parent.add_child(goblin)

		var goblin_2d: Node2D = goblin as Node2D
		if goblin_2d != null:
			goblin_2d.global_position = _get_random_spawn_position()
			if goblin.has_method("_update_depth_z_index"):
				goblin.call("_update_depth_z_index")


func _configure_goblin_level_timing(goblin: Node) -> void:
	goblin.set("shot_cooldown_seconds", shot_cooldown_seconds)
	goblin.set("panic_duration_seconds", panic_duration_seconds)
	goblin.set("win_runoff_seconds", win_runoff_seconds)
	goblin.set("wrong_kill_runoff_penalty_seconds", wrong_kill_runoff_penalty_seconds)


func _configure_goblin_body_palette(goblin: Node) -> void:
	goblin.set("randomize_body_color_on_ready", randomize_goblin_body_colors)
	goblin.set("body_color_a", goblin_body_color_a)
	goblin.set("body_color_b", goblin_body_color_b)
	goblin.set("body_color_steps", goblin_body_color_steps)


func _get_target_indices(count: int) -> Array[int]:
	var chosen_indices: Array[int] = []
	var desired_count: int = clampi(target_count, 1, count)

	if target_index >= 0 and target_index < count:
		chosen_indices.append(target_index)

	var available_indices: Array[int] = []
	for i in range(count):
		if !chosen_indices.has(i):
			available_indices.append(i)

	while chosen_indices.size() < desired_count and !available_indices.is_empty():
		var pick_index: int = randi_range(0, available_indices.size() - 1)
		chosen_indices.append(available_indices[pick_index])
		available_indices.remove_at(pick_index)

	return chosen_indices


func _get_random_spawn_position() -> Vector2:
	var spawn_bounds: Rect2 = _get_spawn_bounds()
	var spawn_max: Vector2 = spawn_bounds.position + spawn_bounds.size
	return Vector2(
		randf_range(spawn_bounds.position.x, spawn_max.x),
		randf_range(spawn_bounds.position.y, spawn_max.y)
	)


func _get_spawn_bounds() -> Rect2:
	var screen_bounds: Rect2 = _get_screen_bounds()
	var safe_padding: float = minf(
		spawn_padding,
		minf(screen_bounds.size.x, screen_bounds.size.y) * 0.45
	)
	var padding_vector: Vector2 = Vector2(safe_padding, safe_padding)
	return Rect2(
		screen_bounds.position + padding_vector,
		screen_bounds.size - padding_vector * 2.0
	)


func _get_screen_bounds() -> Rect2:
	var viewport_rect: Rect2 = get_viewport_rect()
	var canvas_to_world: Transform2D = get_canvas_transform().affine_inverse()
	var screen_corners: Array[Vector2] = [
		viewport_rect.position,
		viewport_rect.position + Vector2(viewport_rect.size.x, 0.0),
		viewport_rect.position + Vector2(0.0, viewport_rect.size.y),
		viewport_rect.position + viewport_rect.size
	]
	var world_min: Vector2 = canvas_to_world * screen_corners[0]
	var world_max: Vector2 = world_min

	for i in range(1, screen_corners.size()):
		var world_corner: Vector2 = canvas_to_world * screen_corners[i]
		world_min.x = minf(world_min.x, world_corner.x)
		world_min.y = minf(world_min.y, world_corner.y)
		world_max.x = maxf(world_max.x, world_corner.x)
		world_max.y = maxf(world_max.y, world_corner.y)

	return Rect2(world_min, world_max - world_min)
