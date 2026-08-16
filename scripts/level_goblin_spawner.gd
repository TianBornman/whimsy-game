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

@export_category("Level Messages")
@export var win_message: String = "YOU WIN!"
@export var fail_message: String = "YOU FAILED"
@export var next_level_scene: PackedScene
@export var result_font: FontFile = preload("res://FontdinerSwanky-Regular.ttf")
@export_range(12, 160, 1) var result_font_size: int = 72
@export var win_dialogue_stream: AudioStream
@export var fail_dialogue_stream: AudioStream
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var result_dialogue_volume_db: float = 0.0
@export var result_dialogue_bus: StringName = &"Master"

@export_category("Click Feedback")
@export var ui_path: NodePath = NodePath("UI")
@export var attack_sound_streams: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var attack_sound_volume_db: float = 0.0
@export var attack_sound_bus: StringName = &"AttackClick"
@export var click_poof_texture: Texture2D
@export_range(1, 32, 1) var click_poof_particle_count: int = 12
@export var click_poof_lifetime: float = 0.45
@export var click_poof_radius: float = 48.0
@export var click_poof_start_scale_range: Vector2 = Vector2(0.07, 0.13)
@export var click_poof_end_scale_multiplier: float = 1.35
@export var click_poof_color: Color = Color(1.0, 1.0, 1.0, 0.9)

@export_category("Target Paper UI")
@export var target_paper_texture: Texture2D = preload("res://sprites/UI/paper.png")
@export_range(0.05, 2.0, 0.01) var target_paper_scale: float = 0.28
@export_range(0.0, 500.0, 1.0, "suffix:px") var target_paper_collapsed_visible_height: float = 42.0
@export var target_paper_screen_margin: Vector2 = Vector2(16.0, 12.0)
@export_range(0.01, 2.0, 0.01, "suffix:s") var target_paper_hover_seconds: float = 0.22
@export var target_paper_stack_offset: Vector2 = Vector2(-5.0, -6.0)
@export var target_paper_expanded_spacing: Vector2 = Vector2(150.0, 0.0)
@export_range(0.05, 2.0, 0.01) var target_oki_scale_on_paper: float = 0.28
@export var target_oki_position_on_paper: Vector2 = Vector2(62.0, 70.0)

## Shared body palette for all spawned goblins. Each goblin randomly picks one
## stepped blend between these two colors, so several goblins can share the
## target's body color.
@export var randomize_goblin_body_colors: bool = true
@export var goblin_body_color_a: Color = Color(0.45, 0.95, 0.25, 1.0)
@export var goblin_body_color_b: Color = Color(0.14, 0.55, 0.24, 1.0)
@export_range(2, 12, 1) var goblin_body_color_steps: int = 3

@export_category("Background")
@export var background_texture: Texture2D
@export var background_tint_color: Color = Color.WHITE
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


var _result_layer: CanvasLayer = null
var _result_dialogue_player: AudioStreamPlayer = null
var _result_dialogue_finished: bool = true
var _target_paper_layer: CanvasLayer = null
var _target_paper_drawer: Control = null
var _target_preview_slots: Array = []
var _target_paper_controls: Array[Control] = []
var _target_paper_expanded: bool = false
var _target_paper_tween: Tween = null




func _ready() -> void:
	_apply_background_settings()
	_configure_depth_sorting()

	if spawn_background_obstacles:
		_spawn_background_obstacles()

	if goblin_scene == null:
		push_error("Level goblin spawner needs a Goblin Scene assigned.")
		return

	_spawn_goblins()


func _process(_delta: float) -> void:
	_update_target_paper_drawer_position(false)


func _apply_background_settings() -> void:
	var background_sprite: Sprite2D = get_node_or_null(background_sprite_path) as Sprite2D
	if background_sprite == null:
		if background_texture != null or background_tint_color != Color.WHITE:
			push_warning("Background settings were assigned, but no BackgroundFloor Sprite2D was found.")
		return

	if background_texture != null:
		background_sprite.texture = background_texture

	background_sprite.self_modulate = background_tint_color


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


func add_target_preview(
	source_body: Sprite2D,
	source_clothing: Sprite2D,
	source_face: Sprite2D,
	source_hat: Sprite2D,
	source_root_scale: Vector2
) -> void:
	_ensure_target_paper_ui()
	if !is_instance_valid(_target_paper_drawer):
		return

	var preview_slot: Dictionary = _create_target_preview_slot(_target_preview_slots.size())
	_target_preview_slots.append(preview_slot)
	_update_target_paper_stack(_target_preview_slots.size())

	var preview_body: Sprite2D = preview_slot.get("body") as Sprite2D
	_copy_preview_layer(source_body, preview_body)
	if source_body != null and preview_body != null and preview_body.visible:
		preview_body.scale = _multiply_scale(source_body.scale, source_root_scale)

	_copy_preview_layer(source_clothing, preview_slot.get("clothing") as Sprite2D)
	_copy_preview_layer(source_face, preview_slot.get("face") as Sprite2D)
	_copy_preview_layer(source_hat, preview_slot.get("hat") as Sprite2D)


func _ensure_target_paper_ui() -> void:
	if is_instance_valid(_target_paper_layer) and is_instance_valid(_target_paper_drawer):
		return

	_target_paper_layer = CanvasLayer.new()
	_target_paper_layer.name = "TargetPaperLayer"
	_target_paper_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root
	parent_node.add_child(_target_paper_layer)

	_target_paper_drawer = Control.new()
	_target_paper_drawer.name = "TargetPaperDrawer"
	_target_paper_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_paper_drawer.clip_contents = false
	_target_paper_drawer.custom_minimum_size = _get_target_paper_display_size()
	_target_paper_drawer.size = _get_target_paper_display_size()
	_target_paper_drawer.mouse_entered.connect(_on_target_paper_mouse_entered)
	_target_paper_drawer.mouse_exited.connect(_on_target_paper_mouse_exited)
	_target_paper_layer.add_child(_target_paper_drawer)

	_update_target_paper_drawer_position(false)


func _create_target_preview_slot(slot_index: int) -> Dictionary:
	var paper_control: Control = _create_target_paper_control(slot_index)
	_target_paper_controls.append(paper_control)

	var slot_root: Node2D = Node2D.new()
	slot_root.name = "TargetPreview%d" % [slot_index + 1]
	slot_root.position = target_oki_position_on_paper
	slot_root.scale = Vector2.ONE * target_oki_scale_on_paper
	paper_control.add_child(slot_root)

	var body: Sprite2D = Sprite2D.new()
	body.name = "Body"
	slot_root.add_child(body)

	var clothing: Sprite2D = Sprite2D.new()
	clothing.name = "Clothing"
	body.add_child(clothing)

	var face: Sprite2D = Sprite2D.new()
	face.name = "Face"
	body.add_child(face)

	var hat: Sprite2D = Sprite2D.new()
	hat.name = "Hat"
	body.add_child(hat)

	_update_target_paper_layout(false)

	return {
		"paper": paper_control,
		"root": slot_root,
		"body": body,
		"clothing": clothing,
		"face": face,
		"hat": hat
	}


func _create_target_paper_control(slot_index: int) -> Control:
	var paper_control: Control = Control.new()
	paper_control.name = "TargetPaperSlot%d" % [slot_index + 1]
	paper_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper_control.custom_minimum_size = _get_target_paper_display_size()
	paper_control.size = _get_target_paper_display_size()
	paper_control.z_index = slot_index
	_target_paper_drawer.add_child(paper_control)

	var paper: TextureRect = TextureRect.new()
	paper.name = "TargetPaper"
	paper.texture = target_paper_texture
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	if target_paper_texture != null:
		paper.custom_minimum_size = target_paper_texture.get_size()
		paper.size = target_paper_texture.get_size()
	paper.scale = Vector2.ONE * target_paper_scale
	paper.z_index = -1
	paper_control.add_child(paper)

	return paper_control


func _copy_preview_layer(source_sprite: Sprite2D, target_sprite: Sprite2D) -> void:
	if !is_instance_valid(target_sprite):
		return

	if source_sprite == null or !source_sprite.visible or source_sprite.texture == null:
		target_sprite.visible = false
		return

	target_sprite.visible = true
	target_sprite.texture = source_sprite.texture
	target_sprite.position = source_sprite.position
	target_sprite.rotation = source_sprite.rotation
	target_sprite.scale = source_sprite.scale
	target_sprite.centered = source_sprite.centered
	target_sprite.offset = source_sprite.offset
	target_sprite.flip_h = false
	target_sprite.self_modulate = source_sprite.self_modulate
	target_sprite.modulate = source_sprite.modulate


func _multiply_scale(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(a.x * b.x, a.y * b.y)


func _update_target_paper_stack(paper_count: int = -1) -> void:
	if !is_instance_valid(_target_paper_drawer):
		return

	var desired_count: int = maxi(1, _target_preview_slots.size()) if paper_count < 0 else maxi(1, paper_count)
	while _target_paper_controls.size() < desired_count:
		_target_paper_controls.append(_create_target_paper_control(_target_paper_controls.size()))

	_update_target_paper_layout(false)


func _update_target_paper_layout(animated: bool) -> void:
	if !is_instance_valid(_target_paper_drawer):
		return

	var paper_size: Vector2 = _get_target_paper_display_size()
	# Keep the drawer rect locked to the front/rightmost paper. Extra papers
	# expand left from this anchor so the visible tab never drifts sideways.
	_target_paper_drawer.size = paper_size
	_target_paper_drawer.custom_minimum_size = paper_size

	for i in range(_target_paper_controls.size()):
		var paper_control: Control = _target_paper_controls[i]
		if !is_instance_valid(paper_control):
			continue

		paper_control.size = paper_size
		paper_control.custom_minimum_size = paper_size
		paper_control.visible = i == 0 or _target_paper_expanded
		var target_position: Vector2 = _get_target_paper_slot_position(i)
		if animated:
			var tween: Tween = paper_control.create_tween()
			tween.tween_property(paper_control, "position", target_position, target_paper_hover_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			paper_control.position = target_position


func _get_target_paper_slot_position(slot_index: int) -> Vector2:
	if _target_paper_expanded:
		return Vector2(
			-target_paper_expanded_spacing.x * float(slot_index),
			target_paper_expanded_spacing.y * float(slot_index)
		)

	return target_paper_stack_offset * float(slot_index)


func _get_target_paper_display_size() -> Vector2:
	if target_paper_texture == null:
		return Vector2.ZERO
	return target_paper_texture.get_size() * target_paper_scale


func _update_target_paper_drawer_position(animated: bool) -> void:
	if !is_instance_valid(_target_paper_drawer):
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	_update_target_paper_layout(animated)
	var paper_size: Vector2 = _get_target_paper_display_size()
	var anchored_x: float = viewport_size.x - paper_size.x - target_paper_screen_margin.x
	var expanded_position: Vector2 = Vector2(
		anchored_x,
		viewport_size.y - paper_size.y - target_paper_screen_margin.y
	)
	var collapsed_position: Vector2 = Vector2(
		anchored_x,
		viewport_size.y - target_paper_collapsed_visible_height
	)
	var target_position: Vector2 = expanded_position if _target_paper_expanded else collapsed_position

	if animated:
		if is_instance_valid(_target_paper_tween):
			_target_paper_tween.kill()
		_target_paper_tween = _target_paper_drawer.create_tween()
		_target_paper_tween.tween_property(_target_paper_drawer, "position", target_position, target_paper_hover_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_target_paper_drawer.position = target_position


func _on_target_paper_mouse_entered() -> void:
	_target_paper_expanded = true
	_update_target_paper_drawer_position(true)


func _on_target_paper_mouse_exited() -> void:
	_target_paper_expanded = false
	_update_target_paper_drawer_position(true)


func play_click_feedback(click_position: Vector2) -> void:
	_play_ui_attack_animation()
	_spawn_click_poof(click_position)
	_play_random_attack_sound(click_position)


func _play_ui_attack_animation() -> void:
	var ui: Node = get_node_or_null(ui_path)
	if ui != null and ui.has_method("fire"):
		ui.call("fire", shot_cooldown_seconds)


func show_result_message(message: String, level_was_won: bool = false) -> void:
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
	if result_font != null:
		label.add_theme_font_override("font", result_font)
	label.add_theme_font_size_override("font_size", result_font_size)
	canvas_layer.add_child(label)

	_play_result_dialogue(level_was_won)


func is_result_dialogue_finished() -> bool:
	return _result_dialogue_finished


func handle_positive_resolution_choice(level_was_won: bool) -> void:
	if level_was_won and next_level_scene != null:
		get_tree().change_scene_to_packed(next_level_scene)
		return

	get_tree().reload_current_scene()


func _play_result_dialogue(level_was_won: bool) -> void:
	if is_instance_valid(_result_dialogue_player):
		_result_dialogue_player.queue_free()
	_result_dialogue_player = null

	var dialogue_stream: AudioStream = win_dialogue_stream if level_was_won else fail_dialogue_stream
	if dialogue_stream == null:
		_result_dialogue_finished = true
		return

	_result_dialogue_finished = false
	var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_player.name = "ResultDialogue"
	audio_player.stream = dialogue_stream
	audio_player.volume_db = result_dialogue_volume_db
	audio_player.bus = result_dialogue_bus
	audio_player.finished.connect(_on_result_dialogue_finished)
	add_child(audio_player)
	_result_dialogue_player = audio_player
	audio_player.play()


func _on_result_dialogue_finished() -> void:
	_result_dialogue_finished = true
	if is_instance_valid(_result_dialogue_player):
		_result_dialogue_player.queue_free()
	_result_dialogue_player = null


func _play_random_attack_sound(click_position: Vector2) -> void:
	if attack_sound_streams.is_empty():
		return

	var attack_sound: AudioStream = attack_sound_streams[randi_range(0, attack_sound_streams.size() - 1)]
	if attack_sound == null:
		return

	var audio_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	audio_player.name = "AttackClickSound"
	audio_player.stream = attack_sound
	audio_player.volume_db = attack_sound_volume_db
	audio_player.bus = attack_sound_bus
	audio_player.finished.connect(audio_player.queue_free)

	var parent_node: Node = _get_click_feedback_parent()
	if parent_node == null:
		audio_player.queue_free()
		return

	parent_node.add_child(audio_player)
	audio_player.global_position = click_position
	audio_player.play()


func _spawn_click_poof(click_position: Vector2) -> void:
	if click_poof_texture == null:
		return

	var parent_node: Node = _get_click_feedback_parent()
	if parent_node == null:
		return

	var poof_root: Node2D = Node2D.new()
	poof_root.name = "ClickPoof"
	poof_root.z_as_relative = false
	poof_root.z_index = DEPTH_Z_INDEX_MAX
	parent_node.add_child(poof_root)
	poof_root.global_position = click_position

	var lifetime: float = maxf(0.05, click_poof_lifetime)
	var particle_count: int = maxi(1, click_poof_particle_count)
	var min_start_scale: float = maxf(0.01, minf(click_poof_start_scale_range.x, click_poof_start_scale_range.y))
	var max_start_scale: float = maxf(min_start_scale, maxf(click_poof_start_scale_range.x, click_poof_start_scale_range.y))
	var poof_radius: float = maxf(0.0, click_poof_radius)

	var tween: Tween = poof_root.create_tween()
	tween.set_parallel(true)
	for i in range(particle_count):
		var particle: Sprite2D = Sprite2D.new()
		particle.name = "PoofParticle%d" % [i + 1]
		particle.texture = click_poof_texture
		particle.centered = true
		particle.modulate = click_poof_color
		particle.rotation = randf_range(-PI, PI)

		var angle: float = randf() * TAU
		var direction: Vector2 = Vector2.from_angle(angle)
		var start_scale: float = randf_range(min_start_scale, max_start_scale)
		var end_scale: float = start_scale * maxf(0.01, click_poof_end_scale_multiplier)
		var end_position: Vector2 = direction * randf_range(poof_radius * 0.35, poof_radius)

		particle.scale = Vector2.ONE * start_scale
		poof_root.add_child(particle)

		var fade_color: Color = click_poof_color
		fade_color.a = 0.0
		tween.tween_property(particle, "position", end_position, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector2.ONE * end_scale, lifetime).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate", fade_color, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.finished.connect(poof_root.queue_free)


func _get_click_feedback_parent() -> Node:
	var tree: SceneTree = get_tree()
	var parent_node: Node = tree.current_scene if tree != null else null
	if parent_node == null:
		parent_node = get_parent()
	if parent_node == null:
		parent_node = tree.root if tree != null else null

	return parent_node


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
		_configure_goblin_body_palette(goblin)

		goblin_parent.add_child(goblin)

		var goblin_2d: Node2D = goblin as Node2D
		if goblin_2d != null:
			goblin_2d.global_position = _get_random_spawn_position()
			if goblin.has_method("_update_depth_z_index"):
				goblin.call("_update_depth_z_index")



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
