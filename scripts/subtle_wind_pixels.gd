extends Node2D

## Tiny low-cost wind streaks drawn directly by this node. No collision,
## no input, just subtle atmosphere drifting across the visible screen.

@export var wind_enabled: bool = true
@export_range(0, 128, 1) var wind_pixel_count: int = 34
@export var wind_color: Color = Color(0.86, 0.96, 1.0, 1.0)
@export var alpha_range: Vector2 = Vector2(0.82, 0.96)
@export var length_range: Vector2 = Vector2(5.0, 16.0)
@export var speed_range: Vector2 = Vector2(26.0, 82.0)
@export var pixel_width: float = 1.0
@export var spawn_margin: float = 96.0
@export var vertical_drift_range: Vector2 = Vector2(-8.0, 14.0)
@export var pulse_strength: float = 0.18
@export var pulse_speed_range: Vector2 = Vector2(0.6, 1.4)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _streaks: Array[Dictionary] = []


func _ready() -> void:
	z_as_relative = false
	z_index = 4095
	_rng.randomize()
	_sync_streak_count(_get_screen_bounds())


func _process(delta: float) -> void:
	if !wind_enabled:
		return

	var screen_bounds: Rect2 = _get_screen_bounds()
	_sync_streak_count(screen_bounds)

	for i in range(_streaks.size()):
		var streak: Dictionary = _streaks[i]
		var streak_position: Vector2 = streak["position"]
		var streak_velocity: Vector2 = streak["velocity"]
		streak_position += streak_velocity * delta
		streak["position"] = streak_position
		streak["age"] = float(streak["age"]) + delta

		if _is_streak_outside_bounds(streak_position, screen_bounds):
			streak = _make_streak(screen_bounds, true)

		_streaks[i] = streak

	queue_redraw()


func _draw() -> void:
	if !wind_enabled:
		return

	for streak in _streaks:
		var streak_position: Vector2 = streak["position"]
		var streak_velocity: Vector2 = streak["velocity"]
		var direction: Vector2 = streak_velocity.normalized()
		var local_position: Vector2 = to_local(streak_position)
		var local_start: Vector2 = local_position - direction * float(streak["length"])

		var streak_color: Color = wind_color
		var pulse: float = 1.0 + sin(float(streak["age"]) * TAU * float(streak["pulse_speed"])) * pulse_strength
		streak_color.a = clampf(float(streak["alpha"]) * pulse, 0.0, 1.0)

		draw_line(local_start, local_position, streak_color, pixel_width)


func _sync_streak_count(screen_bounds: Rect2) -> void:
	var target_count: int = maxi(0, wind_pixel_count)
	while _streaks.size() < target_count:
		_streaks.append(_make_streak(screen_bounds, false))

	while _streaks.size() > target_count:
		_streaks.pop_back()


func _make_streak(screen_bounds: Rect2, start_offscreen: bool) -> Dictionary:
	var spawn_x: float = _rng.randf_range(screen_bounds.position.x, screen_bounds.end.x)
	if start_offscreen:
		spawn_x = screen_bounds.position.x - _rng.randf_range(pixel_width, spawn_margin)

	var speed: float = _rng.randf_range(speed_range.x, speed_range.y)
	var vertical_drift: float = _rng.randf_range(vertical_drift_range.x, vertical_drift_range.y)

	return {
		"position": Vector2(
			spawn_x,
			_rng.randf_range(screen_bounds.position.y - spawn_margin, screen_bounds.end.y + spawn_margin)
		),
		"velocity": Vector2(speed, vertical_drift),
		"length": _rng.randf_range(length_range.x, length_range.y),
		"alpha": _rng.randf_range(alpha_range.x, alpha_range.y),
		"age": _rng.randf_range(0.0, 2.0),
		"pulse_speed": _rng.randf_range(pulse_speed_range.x, pulse_speed_range.y)
	}


func _is_streak_outside_bounds(streak_position: Vector2, screen_bounds: Rect2) -> bool:
	return (
		streak_position.x > screen_bounds.end.x + spawn_margin
		or streak_position.y < screen_bounds.position.y - spawn_margin
		or streak_position.y > screen_bounds.end.y + spawn_margin
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

