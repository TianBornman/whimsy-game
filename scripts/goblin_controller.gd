extends Sprite2D
## Wander-in-bounds behavior for crowd sprites.
## Attach directly to the sprite node (or change "extends Sprite2D" to
## "extends Node2D" / "extends AnimatedSprite2D" as needed).
##
## PERFORMANCE NOTES (for spawning hundreds of these):
## - No Timer nodes are used (each Timer adds a node + signal overhead).
##   State timing is tracked with a plain float decremented in _process,
##   which is far cheaper at scale.
## - No physics body / move_and_slide is used. Position is set directly,
##   which skips the physics server entirely. Fine for a visual crowd
##   that doesn't need collision with the player or each other.
## - Only _process is used (no _physics_process), so movement is tied to
##   the render step, not a second fixed-step loop.
## - Random start values below desync instances so they don't all
##   flip state on the same frame (avoids CPU spikes every N seconds).

## --- Configuration (tune per-instance or leave as defaults) ---

const CLICK_COOLDOWN_SECONDS: float = 5.0
const SCATTER_DURATION_SECONDS: float = 10.0
const SCATTER_SPEED_MULTIPLIER: float = 2.5

## Movement bounds are shared by every goblin and come from the visible
## screen. The script keeps the whole sprite inside, not just its center
## point.

## Random range for walk speed (px/sec), picked once per sprite so
## not everyone moves at identical speed.
@export var speed_range: Vector2 = Vector2(20.0, 45.0)

## How long a single "walk toward target" phase can last at most,
## before giving up and pausing anyway (prevents getting stuck).
@export var walk_duration_range: Vector2 = Vector2(1.5, 4.0)

## How long the idle/break phase lasts between wander phases.
@export var idle_duration_range: Vector2 = Vector2(1.0, 3.0)

## How close to the target counts as "arrived".
@export var arrival_threshold: float = 4.0

## If true, flips the sprite horizontally based on movement direction.
@export var flip_with_direction: bool = true

## Make this goblin the level target. Targets are green and win the level
## when clicked.
@export var is_target: bool = false
@export var target_color: Color = Color(0.1, 1.0, 0.1, 1.0)
@export var win_message: String = "YOU WIN!"

## --- Internal state ---

enum State { IDLE, WALK, SCATTER }

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _target_pos: Vector2
var _scatter_origin: Vector2
var _speed: float = 30.0
var _has_won_level: bool = false

static var _active_goblins: Array = []
static var _click_cooldown_until_msec: int = 0
static var _last_click_handled_frame: int = -1
static var _screen_bounds_cache_frame: int = -1
static var _screen_bounds_cache: Rect2 = Rect2()


func _ready() -> void:
	if _active_goblins.is_empty():
		_click_cooldown_until_msec = 0
		_last_click_handled_frame = -1
		_screen_bounds_cache_frame = -1

	if !_active_goblins.has(self):
		_active_goblins.append(self)

	if is_target:
		modulate = target_color

	# Per-instance random speed so the crowd doesn't move in lockstep.
	_speed = randf_range(speed_range.x, speed_range.y)

	# Start each sprite in idle with a random duration AND stagger it
	# further with a small random offset, so hundreds of sprites don't
	# all transition to WALK on the same frame.
	_state = State.IDLE
	_state_timer = randf_range(idle_duration_range.x, idle_duration_range.y)

	# In case the sprite was placed/spawned outside its own bounds,
	# snap it inside immediately rather than letting it wander from there.
	_set_clamped_position(global_position)


func _exit_tree() -> void:
	_active_goblins.erase(self)


func _process(delta: float) -> void:
	_state_timer -= delta

	match _state:
		State.IDLE:
			if _state_timer <= 0.0:
				_start_walk()

		State.WALK:
			var current_pos: Vector2 = global_position
			var to_target: Vector2 = _target_pos - current_pos
			var dist: float = to_target.length()

			if dist <= arrival_threshold or _state_timer <= 0.0:
				_start_idle()
			else:
				var dir: Vector2 = to_target / dist  # cheaper than normalize() (avoids re-sqrt)
				# Never step further than the remaining distance, so we can't
				# overshoot the target (and therefore can't overshoot the bounds).
				var step: float = minf(_speed * delta, dist)
				current_pos += dir * step

				if flip_with_direction and absf(dir.x) > 0.01:
					flip_h = dir.x < 0.0

				_set_clamped_position(current_pos)

		State.SCATTER:
			if _state_timer <= 0.0:
				_start_idle()
			else:
				_scatter_step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if self != _get_input_dispatcher() or _has_won_level:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT or !mouse_event.pressed:
		return

	var current_frame: int = Engine.get_process_frames()
	if _last_click_handled_frame == current_frame:
		get_viewport().set_input_as_handled()
		return

	_last_click_handled_frame = current_frame

	var click_position: Vector2 = get_global_mouse_position()
	if _is_click_cooldown_active():
		get_viewport().set_input_as_handled()
		return

	var clicked_goblin: Sprite2D = _get_goblin_at_global_point(click_position)
	if clicked_goblin != null and clicked_goblin.is_target:
		clicked_goblin._win_level()
	else:
		_apply_miss_penalty(click_position)

	get_viewport().set_input_as_handled()


func _get_input_dispatcher() -> Sprite2D:
	for goblin in _active_goblins:
		if is_instance_valid(goblin) and goblin.is_inside_tree():
			return goblin

	return null


func _get_goblin_at_global_point(global_point: Vector2) -> Sprite2D:
	for i in range(_active_goblins.size() - 1, -1, -1):
		var goblin: Sprite2D = _active_goblins[i]
		if !is_instance_valid(goblin):
			_active_goblins.remove_at(i)
			continue

		if !goblin.is_visible_in_tree():
			continue

		if goblin._is_global_point_inside_sprite(global_point):
			return goblin

	return null


func _is_global_point_inside_sprite(global_point: Vector2) -> bool:
	return get_rect().has_point(to_local(global_point))


func _is_click_cooldown_active() -> bool:
	return Time.get_ticks_msec() < _click_cooldown_until_msec


func _apply_miss_penalty(miss_position: Vector2) -> void:
	_click_cooldown_until_msec = Time.get_ticks_msec() + int(CLICK_COOLDOWN_SECONDS * 1000.0)

	for goblin in _active_goblins:
		if !is_instance_valid(goblin) or goblin.is_target:
			continue

		goblin._start_scatter(miss_position)


func _win_level() -> void:
	_has_won_level = true
	_state = State.IDLE
	_show_win_message()
	get_tree().paused = true


func _show_win_message() -> void:
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.name = "WinLayer"
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root
	parent_node.add_child(canvas_layer)

	var label: Label = Label.new()
	label.name = "WinLabel"
	label.text = win_message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 72)
	canvas_layer.add_child(label)


func _set_clamped_position(new_pos: Vector2) -> void:
	# Hard safety net: keeps the sprite's visual rect inside bounds whenever
	# it fits, regardless of speed, frame rate, or starting position.
	var effective_bounds: Rect2 = _get_effective_bounds()
	var effective_max: Vector2 = effective_bounds.position + effective_bounds.size
	new_pos.x = clampf(new_pos.x, effective_bounds.position.x, effective_max.x)
	new_pos.y = clampf(new_pos.y, effective_bounds.position.y, effective_max.y)

	global_position = new_pos


func _get_effective_bounds() -> Rect2:
	var screen_bounds: Rect2 = _get_screen_bounds()
	var ordered_min: Vector2 = screen_bounds.position
	var ordered_max: Vector2 = screen_bounds.position + screen_bounds.size
	var min_margin: Vector2 = _get_visual_min_margin()
	var max_margin: Vector2 = _get_visual_max_margin()
	var effective_min: Vector2 = ordered_min + min_margin
	var effective_max: Vector2 = ordered_max - max_margin

	# If a bound is smaller than the sprite, the whole sprite cannot fit on
	# that axis. Pin the center to the middle instead of letting clampf() get
	# an inverted range and push it out unpredictably.
	if effective_min.x > effective_max.x:
		var center_x: float = (ordered_min.x + ordered_max.x) * 0.5
		effective_min.x = center_x
		effective_max.x = center_x
	if effective_min.y > effective_max.y:
		var center_y: float = (ordered_min.y + ordered_max.y) * 0.5
		effective_min.y = center_y
		effective_max.y = center_y

	return Rect2(effective_min, effective_max - effective_min)


func _get_screen_bounds() -> Rect2:
	var current_frame: int = Engine.get_process_frames()
	if _screen_bounds_cache_frame == current_frame:
		return _screen_bounds_cache

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

	_screen_bounds_cache = Rect2(world_min, world_max - world_min)
	_screen_bounds_cache_frame = current_frame
	return _screen_bounds_cache


func _get_visual_min_margin() -> Vector2:
	var sprite_rect: Rect2 = get_rect()
	return Vector2(
		maxf(0.0, -sprite_rect.position.x) * absf(global_scale.x),
		maxf(0.0, -sprite_rect.position.y) * absf(global_scale.y)
	)


func _get_visual_max_margin() -> Vector2:
	var sprite_rect: Rect2 = get_rect()
	return Vector2(
		maxf(0.0, sprite_rect.position.x + sprite_rect.size.x) * absf(global_scale.x),
		maxf(0.0, sprite_rect.position.y + sprite_rect.size.y) * absf(global_scale.y)
	)


func _start_idle() -> void:
	_state = State.IDLE
	_state_timer = randf_range(idle_duration_range.x, idle_duration_range.y)
	# Hook: play an "idle" animation here if using AnimatedSprite2D.
	# e.g. if has_method("play"): play("idle")


func _start_scatter(scatter_origin: Vector2) -> void:
	_state = State.SCATTER
	_state_timer = SCATTER_DURATION_SECONDS
	_scatter_origin = scatter_origin
	_target_pos = _get_scatter_target()


func _scatter_step(delta: float) -> void:
	var current_pos: Vector2 = global_position
	var to_target: Vector2 = _target_pos - current_pos
	var dist: float = to_target.length()

	if dist <= arrival_threshold:
		_target_pos = _get_scatter_target()
		return

	var dir: Vector2 = to_target / dist
	var step: float = minf(_speed * SCATTER_SPEED_MULTIPLIER * delta, dist)
	current_pos += dir * step

	if flip_with_direction and absf(dir.x) > 0.01:
		flip_h = dir.x < 0.0

	_set_clamped_position(current_pos)


func _get_scatter_target() -> Vector2:
	var effective_bounds: Rect2 = _get_effective_bounds()
	var effective_max: Vector2 = effective_bounds.position + effective_bounds.size
	var best_target: Vector2 = global_position
	var best_distance_squared: float = -1.0

	for i in range(8):
		var candidate: Vector2 = Vector2(
			randf_range(effective_bounds.position.x, effective_max.x),
			randf_range(effective_bounds.position.y, effective_max.y)
		)
		var distance_squared: float = (candidate - _scatter_origin).length_squared()
		if distance_squared > best_distance_squared:
			best_distance_squared = distance_squared
			best_target = candidate

	return best_target


func _start_walk() -> void:
	_state = State.WALK
	_state_timer = randf_range(walk_duration_range.x, walk_duration_range.y)
	var effective_bounds: Rect2 = _get_effective_bounds()
	var effective_max: Vector2 = effective_bounds.position + effective_bounds.size
	_target_pos = Vector2(
		randf_range(effective_bounds.position.x, effective_max.x),
		randf_range(effective_bounds.position.y, effective_max.y)
	)
	# Hook: play a "walk" animation here if using AnimatedSprite2D.
	# e.g. if has_method("play"): play("walk")
