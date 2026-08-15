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
const SCATTER_SPEED_MULTIPLIER: float = 3.5
const WRONG_KILL_RUNOFF_PENALTY_SECONDS: float = 2.0
const SCATTER_TARGET_ATTEMPTS: int = 20
const SCATTER_MIN_TRAVEL_FRACTION: float = 0.18
const SCATTER_RETARGET_INTERVAL_RANGE: Vector2 = Vector2(0.9, 1.8)
const FLEE_OFFSCREEN_SPEED_MULTIPLIER: float = 4.0
const FLEE_OFFSCREEN_PADDING: float = 250.0

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

## Make this goblin the level target. The target keeps its randomized body
## hue/face, and a matching portrait is shown under the timers.
@export var is_target: bool = false
@export var win_message: String = "YOU WIN!"

## Optional face randomization. Assign the Face child here, then fill
## face_textures with every face image this goblin can use.
@export var randomize_face_on_ready: bool = true
@export var face_sprite_path: NodePath = NodePath("Face")
@export var face_textures: Array[Texture2D] = []
## Optional face shown after this goblin is shot/killed.
@export var dead_face_texture: Texture2D

## Body-only hue randomization. This uses self_modulate so child face sprites
## keep their own colors.
@export var randomize_body_hue_on_ready: bool = true
@export var body_hue_saturation: float = 0.65
@export var body_hue_value: float = 1.0

## --- Internal state ---

enum State { IDLE, WALK, SCATTER, FLEE_OFFSCREEN, DEAD }

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _target_pos: Vector2
var _scatter_retarget_timer: float = 0.0
var _speed: float = 30.0
var _is_dead: bool = false

static var _active_goblins: Array = []
static var _click_cooldown_until_msec: int = 0
static var _panic_ends_at_msec: int = 0
static var _level_resolved: bool = false
static var _last_click_handled_frame: int = -1
static var _screen_bounds_cache_frame: int = -1
static var _screen_bounds_cache: Rect2 = Rect2()
static var _timer_layer: CanvasLayer = null
static var _shooter_timer_label: Label = null
static var _runoff_timer_label: Label = null
static var _target_preview_label: Label = null
static var _target_preview_root: Node2D = null
static var _target_preview_body: Sprite2D = null
static var _target_preview_face: Sprite2D = null
static var _result_layer: CanvasLayer = null


func _ready() -> void:
	if _active_goblins.is_empty():
		_click_cooldown_until_msec = 0
		_panic_ends_at_msec = 0
		_level_resolved = false
		_last_click_handled_frame = -1
		_screen_bounds_cache_frame = -1
		_timer_layer = null
		_shooter_timer_label = null
		_runoff_timer_label = null
		_target_preview_label = null
		_target_preview_root = null
		_target_preview_body = null
		_target_preview_face = null
		_result_layer = null

	if !_active_goblins.has(self):
		_active_goblins.append(self)

	if randomize_face_on_ready:
		randomize_face()

	if randomize_body_hue_on_ready:
		randomize_body_hue()

	if is_target:
		_set_target_preview()

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


func randomize_face() -> void:
	if face_textures.is_empty():
		return

	var face_sprite: Sprite2D = _get_face_sprite()
	if face_sprite == null:
		push_warning("Goblin face randomization skipped: no Face Sprite2D was found.")
		return

	face_sprite.texture = face_textures[randi_range(0, face_textures.size() - 1)]


func randomize_body_hue() -> void:
	self_modulate = Color.from_hsv(
		randf(),
		clampf(body_hue_saturation, 0.0, 1.0),
		maxf(0.0, body_hue_value),
		1.0
	)


func _set_target_preview() -> void:
	_ensure_timer_ui()

	if !is_instance_valid(_target_preview_body) or !is_instance_valid(_target_preview_face):
		return

	_target_preview_body.texture = texture
	_target_preview_body.scale = scale
	_target_preview_body.centered = centered
	_target_preview_body.offset = offset
	_target_preview_body.flip_h = false
	_target_preview_body.self_modulate = self_modulate
	_target_preview_body.modulate = Color.WHITE

	var source_face: Sprite2D = _get_face_sprite()
	if source_face == null or source_face.texture == null:
		_target_preview_face.visible = false
		return

	_target_preview_face.visible = true
	_target_preview_face.texture = source_face.texture
	_target_preview_face.position = source_face.position
	_target_preview_face.rotation = source_face.rotation
	_target_preview_face.scale = source_face.scale
	_target_preview_face.centered = source_face.centered
	_target_preview_face.offset = source_face.offset
	_target_preview_face.flip_h = false
	_target_preview_face.self_modulate = source_face.self_modulate
	_target_preview_face.modulate = source_face.modulate


func _get_face_sprite() -> Sprite2D:
	if String(face_sprite_path) != "":
		var path_sprite: Sprite2D = get_node_or_null(face_sprite_path) as Sprite2D
		if path_sprite != null:
			return path_sprite

	var named_face: Sprite2D = _find_descendant_sprite_named(self, "face")
	if named_face != null:
		return named_face

	return _find_first_descendant_sprite(self)


func _find_descendant_sprite_named(parent_node: Node, name_part: String) -> Sprite2D:
	for child in parent_node.get_children():
		var child_sprite: Sprite2D = child as Sprite2D
		if child_sprite != null and String(child.name).to_lower().contains(name_part):
			return child_sprite

		var nested_sprite: Sprite2D = _find_descendant_sprite_named(child, name_part)
		if nested_sprite != null:
			return nested_sprite

	return null


func _find_first_descendant_sprite(parent_node: Node) -> Sprite2D:
	for child in parent_node.get_children():
		var child_sprite: Sprite2D = child as Sprite2D
		if child_sprite != null:
			return child_sprite

		var nested_sprite: Sprite2D = _find_first_descendant_sprite(child)
		if nested_sprite != null:
			return nested_sprite

	return null


func _process(delta: float) -> void:
	if self == _get_input_dispatcher():
		_update_level_timers()

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

		State.FLEE_OFFSCREEN:
			_flee_offscreen_step(delta)

		State.DEAD:
			pass


func _unhandled_input(event: InputEvent) -> void:
	if self != _get_input_dispatcher() or _level_resolved:
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
	elif clicked_goblin != null:
		clicked_goblin._kill_goblin()
		_apply_miss_penalty(click_position, true)
	else:
		_apply_miss_penalty(click_position, false)

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

		if goblin._is_dead or !goblin.is_visible_in_tree():
			continue

		if goblin._is_global_point_inside_sprite(global_point):
			return goblin

	return null


func _is_global_point_inside_sprite(global_point: Vector2) -> bool:
	return get_rect().has_point(to_local(global_point))


func _is_click_cooldown_active() -> bool:
	return Time.get_ticks_msec() < _click_cooldown_until_msec


func _apply_miss_penalty(miss_position: Vector2, killed_wrong_goblin: bool) -> void:
	var now_msec: int = Time.get_ticks_msec()
	_click_cooldown_until_msec = now_msec + int(CLICK_COOLDOWN_SECONDS * 1000.0)

	if _panic_ends_at_msec > 0 and now_msec >= _panic_ends_at_msec:
		_fail_level()
		return

	if _panic_ends_at_msec <= 0:
		_panic_ends_at_msec = now_msec + int(SCATTER_DURATION_SECONDS * 1000.0)

	if killed_wrong_goblin:
		_panic_ends_at_msec -= int(WRONG_KILL_RUNOFF_PENALTY_SECONDS * 1000.0)
		if _panic_ends_at_msec <= now_msec:
			_fail_level()
			return

	var scatter_seconds_remaining: float = maxf(0.1, float(_panic_ends_at_msec - now_msec) / 1000.0)
	_update_timer_ui()

	for goblin in _active_goblins:
		if !is_instance_valid(goblin) or goblin._is_dead:
			continue

		goblin._start_scatter(miss_position, scatter_seconds_remaining)


func _win_level() -> void:
	if _level_resolved:
		return

	_level_resolved = true
	_click_cooldown_until_msec = 0
	_kill_goblin()
	_ensure_scatter_runoff(global_position)
	_update_timer_ui()
	_show_result_message(win_message)


func _fail_level() -> void:
	if _level_resolved:
		return

	_level_resolved = true
	_click_cooldown_until_msec = 0
	_update_timer_ui()
	_show_result_message("YOU FAILED")
	_send_living_goblins_offscreen()


func _send_living_goblins_offscreen() -> void:
	_panic_ends_at_msec = 0
	_click_cooldown_until_msec = 0
	_update_timer_ui()
	for goblin in _active_goblins:
		if !is_instance_valid(goblin) or goblin._is_dead:
			continue

		goblin._start_flee_offscreen()


func _ensure_scatter_runoff(scatter_origin: Vector2) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if _panic_ends_at_msec <= now_msec:
		_panic_ends_at_msec = now_msec + int(SCATTER_DURATION_SECONDS * 1000.0)

	var scatter_seconds_remaining: float = maxf(0.1, float(_panic_ends_at_msec - now_msec) / 1000.0)
	for goblin in _active_goblins:
		if !is_instance_valid(goblin) or goblin._is_dead:
			continue

		goblin._start_scatter(scatter_origin, scatter_seconds_remaining)


func _kill_goblin() -> void:
	_is_dead = true
	_state = State.DEAD
	_state_timer = 0.0
	_scatter_retarget_timer = 0.0
	_apply_dead_face()
	modulate = Color.WHITE


func _apply_dead_face() -> void:
	if dead_face_texture == null:
		return

	var face_sprite: Sprite2D = _get_face_sprite()
	if face_sprite == null:
		push_warning("Goblin dead face skipped: no Face Sprite2D was found.")
		return

	face_sprite.texture = dead_face_texture


func _show_result_message(message: String) -> void:
	if is_instance_valid(_result_layer):
		_result_layer.queue_free()

	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.name = "ResultLayer"
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_result_layer = canvas_layer

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root
	parent_node.add_child(canvas_layer)

	var label: Label = Label.new()
	label.name = "ResultLabel"
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 72)
	canvas_layer.add_child(label)


func _update_level_timers() -> void:
	if _panic_ends_at_msec > 0 and Time.get_ticks_msec() >= _panic_ends_at_msec:
		if _level_resolved:
			_send_living_goblins_offscreen()
		else:
			_fail_level()
		return

	_update_timer_ui()


func _update_timer_ui() -> void:
	_ensure_timer_ui()

	if !is_instance_valid(_shooter_timer_label) or !is_instance_valid(_runoff_timer_label):
		return

	var now_msec: int = Time.get_ticks_msec()
	var shoot_remaining: float = maxf(0.0, float(_click_cooldown_until_msec - now_msec) / 1000.0)
	if _level_resolved:
		_shooter_timer_label.text = "Shot: --"
	elif shoot_remaining > 0.0:
		_shooter_timer_label.text = "Shot: %.1fs" % shoot_remaining
	else:
		_shooter_timer_label.text = "Shot: READY"

	var runoff_remaining: float = maxf(0.0, float(_panic_ends_at_msec - now_msec) / 1000.0)
	if _panic_ends_at_msec > 0:
		_runoff_timer_label.text = "Run off: %.1fs" % runoff_remaining
	elif _level_resolved:
		_runoff_timer_label.text = "Run off: NOW"
	else:
		_runoff_timer_label.text = "Run off: --"


func _ensure_timer_ui() -> void:
	if is_instance_valid(_timer_layer):
		return

	_timer_layer = CanvasLayer.new()
	_timer_layer.name = "TimerLayer"
	_timer_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root
	parent_node.add_child(_timer_layer)

	_shooter_timer_label = _create_timer_label("ShooterTimerLabel", Vector2(16.0, 16.0))
	_runoff_timer_label = _create_timer_label("RunoffTimerLabel", Vector2(16.0, 48.0))
	_timer_layer.add_child(_shooter_timer_label)
	_timer_layer.add_child(_runoff_timer_label)

	_target_preview_label = _create_timer_label("TargetPreviewLabel", Vector2(16.0, 84.0))
	_target_preview_label.text = "Target:"
	_timer_layer.add_child(_target_preview_label)

	_target_preview_root = Node2D.new()
	_target_preview_root.name = "TargetPreview"
	_target_preview_root.position = Vector2(70.0, 155.0)
	_timer_layer.add_child(_target_preview_root)

	_target_preview_body = Sprite2D.new()
	_target_preview_body.name = "Body"
	_target_preview_body.scale = scale
	_target_preview_root.add_child(_target_preview_body)

	_target_preview_face = Sprite2D.new()
	_target_preview_face.name = "Face"
	_target_preview_body.add_child(_target_preview_face)


func _create_timer_label(label_name: String, label_position: Vector2) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.position = label_position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	return label


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
	if _is_dead:
		return

	_state = State.IDLE
	_state_timer = randf_range(idle_duration_range.x, idle_duration_range.y)
	# Hook: play an "idle" animation here if using AnimatedSprite2D.
	# e.g. if has_method("play"): play("idle")


func _start_scatter(_scatter_origin: Vector2, scatter_duration: float) -> void:
	if _is_dead:
		return

	_state = State.SCATTER
	_state_timer = scatter_duration
	_target_pos = _get_scatter_target()
	_reset_scatter_retarget_timer()


func _scatter_step(delta: float) -> void:
	_scatter_retarget_timer -= delta
	if _scatter_retarget_timer <= 0.0:
		_target_pos = _get_scatter_target()
		_reset_scatter_retarget_timer()

	var current_pos: Vector2 = global_position
	var to_target: Vector2 = _target_pos - current_pos
	var dist: float = to_target.length()

	if dist <= arrival_threshold:
		_target_pos = _get_scatter_target()
		_reset_scatter_retarget_timer()
		return

	var dir: Vector2 = to_target / dist
	var step: float = minf(_speed * SCATTER_SPEED_MULTIPLIER * delta, dist)
	current_pos += dir * step

	if flip_with_direction and absf(dir.x) > 0.01:
		flip_h = dir.x < 0.0

	_set_clamped_position(current_pos)


func _reset_scatter_retarget_timer() -> void:
	_scatter_retarget_timer = randf_range(
		SCATTER_RETARGET_INTERVAL_RANGE.x,
		SCATTER_RETARGET_INTERVAL_RANGE.y
	)


func _start_flee_offscreen() -> void:
	if _is_dead:
		return

	_state = State.FLEE_OFFSCREEN
	_state_timer = 0.0
	_target_pos = _get_offscreen_flee_target()


func _flee_offscreen_step(delta: float) -> void:
	var current_pos: Vector2 = global_position
	var to_target: Vector2 = _target_pos - current_pos
	var dist: float = to_target.length()

	if dist <= arrival_threshold:
		visible = false
		set_process(false)
		return

	var dir: Vector2 = to_target / dist
	var step: float = minf(_speed * FLEE_OFFSCREEN_SPEED_MULTIPLIER * delta, dist)
	global_position = current_pos + dir * step

	if flip_with_direction and absf(dir.x) > 0.01:
		flip_h = dir.x < 0.0


func _get_offscreen_flee_target() -> Vector2:
	var screen_bounds: Rect2 = _get_screen_bounds()
	var screen_center: Vector2 = screen_bounds.position + screen_bounds.size * 0.5
	var flee_direction: Vector2 = global_position - screen_center
	if flee_direction.length_squared() <= 0.0001:
		flee_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	else:
		flee_direction = flee_direction.normalized()

	var flee_distance: float = maxf(screen_bounds.size.x, screen_bounds.size.y) + FLEE_OFFSCREEN_PADDING
	return global_position + flee_direction * flee_distance


func _get_scatter_target() -> Vector2:
	var effective_bounds: Rect2 = _get_effective_bounds()
	var effective_max: Vector2 = effective_bounds.position + effective_bounds.size
	var best_target: Vector2 = global_position
	var best_score: float = -INF
	var min_travel_distance: float = minf(effective_bounds.size.x, effective_bounds.size.y) * SCATTER_MIN_TRAVEL_FRACTION

	for i in range(SCATTER_TARGET_ATTEMPTS):
		var candidate: Vector2 = Vector2(
			randf_range(effective_bounds.position.x, effective_max.x),
			randf_range(effective_bounds.position.y, effective_max.y)
		)
		var travel_distance: float = (candidate - global_position).length()
		var horizontal_edge_margin: float = minf(
			candidate.x - effective_bounds.position.x,
			effective_max.x - candidate.x
		)
		var vertical_edge_margin: float = minf(
			candidate.y - effective_bounds.position.y,
			effective_max.y - candidate.y
		)
		var edge_margin: float = minf(horizontal_edge_margin, vertical_edge_margin)
		var score: float = travel_distance + edge_margin * 0.08 + randf() * min_travel_distance
		if travel_distance < min_travel_distance:
			score -= min_travel_distance

		if score > best_score:
			best_score = score
			best_target = candidate

	return best_target


func _start_walk() -> void:
	if _is_dead:
		return

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
