extends Node2D

## Spawns a configurable crowd for the level. Put this on the level root,
## assign goblin_scene, then tune goblin_count in the Inspector.

@export var goblin_scene: PackedScene
@export var goblin_count: int = 10

## -1 means pick a random target. Set this to 0, 1, 2, etc. if you want a
## specific spawned goblin to be the target for testing.
@export var target_index: int = -1

## Keeps spawns away from the exact screen edge. The goblin controller still
## clamps movement to the screen after spawning.
@export var spawn_padding: float = 48.0

@export var goblin_name_prefix: String = "Goblin"


func _ready() -> void:
	if goblin_scene == null:
		push_error("Level goblin spawner needs a Goblin Scene assigned.")
		return

	_spawn_goblins()


func _spawn_goblins() -> void:
	var count: int = maxi(1, goblin_count)
	var chosen_target_index: int = _get_target_index(count)

	for i in range(count):
		var goblin: Node = goblin_scene.instantiate()
		goblin.name = "%s%d" % [goblin_name_prefix, i + 1]
		goblin.set("is_target", i == chosen_target_index)

		add_child(goblin)

		var goblin_2d: Node2D = goblin as Node2D
		if goblin_2d != null:
			goblin_2d.global_position = _get_random_spawn_position()


func _get_target_index(count: int) -> int:
	if target_index >= 0 and target_index < count:
		return target_index

	return randi_range(0, count - 1)


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
