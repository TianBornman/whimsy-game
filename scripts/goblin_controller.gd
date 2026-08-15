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

## Movement bounds in this node's PARENT's local space (i.e. wherever
## this sprite sits in the scene). Set these per-instance, e.g. to the
## sprite's spawn area.
@export var min_bounds: Vector2 = Vector2(-100, -100)
@export var max_bounds: Vector2 = Vector2(100, 100)

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

## If true, min_bounds/max_bounds and movement use global_position instead
## of position. Turn this on if the sprite is nested under a parent that
## has its own offset/transform, so bounds line up with world space.
@export var use_global_position: bool = false

## --- Internal state ---

enum State { IDLE, WALK }

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _target_pos: Vector2
var _speed: float = 30.0


func _ready() -> void:
	# Per-instance random speed so the crowd doesn't move in lockstep.
	_speed = randf_range(speed_range.x, speed_range.y)

	# Start each sprite in idle with a random duration AND stagger it
	# further with a small random offset, so hundreds of sprites don't
	# all transition to WALK on the same frame.
	_state = State.IDLE
	_state_timer = randf_range(idle_duration_range.x, idle_duration_range.y)

	# In case the sprite was placed/spawned outside its own bounds,
	# snap it inside immediately rather than letting it wander from there.
	_set_clamped_position(global_position if use_global_position else position)


func _process(delta: float) -> void:
	_state_timer -= delta

	match _state:
		State.IDLE:
			if _state_timer <= 0.0:
				_start_walk()

		State.WALK:
			var current_pos: Vector2 = global_position if use_global_position else position
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


func _set_clamped_position(new_pos: Vector2) -> void:
	# Hard safety net: guarantees the sprite can never end up outside
	# bounds, regardless of speed, frame rate, or starting position.
	new_pos.x = clampf(new_pos.x, min_bounds.x, max_bounds.x)
	new_pos.y = clampf(new_pos.y, min_bounds.y, max_bounds.y)

	if use_global_position:
		global_position = new_pos
	else:
		position = new_pos


func _start_idle() -> void:
	_state = State.IDLE
	_state_timer = randf_range(idle_duration_range.x, idle_duration_range.y)
	# Hook: play an "idle" animation here if using AnimatedSprite2D.
	# e.g. if has_method("play"): play("idle")


func _start_walk() -> void:
	_state = State.WALK
	_state_timer = randf_range(walk_duration_range.x, walk_duration_range.y)
	_target_pos = Vector2(
		randf_range(min_bounds.x, max_bounds.x),
		randf_range(min_bounds.y, max_bounds.y)
	)
	# Hook: play a "walk" animation here if using AnimatedSprite2D.
	# e.g. if has_method("play"): play("walk")
