extends Node2D

const DEPTH_Z_INDEX_MIN: int = -4096
const DEPTH_Z_INDEX_MAX: int = 4096

@export_category("Scene Assets")
@export var background_texture: Texture2D = preload("res://sprites/background_floor.png")
@export var background_tint_color: Color = Color.WHITE
@export var fake_goblin_texture: Texture2D = preload("res://sprites/outro/fake_goblin.png")
@export var fake_target_scene: PackedScene = preload("res://fake_goblin.tscn")
@export var final_face_texture: Texture2D = preload("res://sprites/outro/goblin_face.png")
@export var goblin_body_texture: Texture2D = preload("res://sprites/goblin_body_base.png")
@export var goblin_shadow_texture: Texture2D = preload("res://sprites/goblin_body_shadow.png")
@export var ui_scene: PackedScene = preload("res://scenes/ui.tscn")
@export var goblin_face_textures: Array[Texture2D] = [
	preload("res://sprites/faces/goblin_face_1.png"),
	preload("res://sprites/faces/goblin_face_2.png"),
	preload("res://sprites/faces/goblin_face_3.png"),
	preload("res://sprites/faces/goblin_face_4.png")
]
@export var goblin_hat_textures: Array[Texture2D] = [
	preload("res://sprites/hats/hat_1.png"),
	preload("res://sprites/hats/hat_2.png"),
	preload("res://sprites/hats/hat_3.png"),
	preload("res://sprites/hats/hat_4.png"),
	preload("res://sprites/hats/hat_5.png"),
	preload("res://sprites/hats/hat_6.png")
]
@export var goblin_clothing_textures: Array[Texture2D] = [
	preload("res://sprites/clothing/clothing_1.png"),
	preload("res://sprites/clothing/clothing_2.png"),
	preload("res://sprites/clothing/clothing_3.png"),
	preload("res://sprites/clothing/clothing_4.png"),
	preload("res://sprites/clothing/clothing_5.png")
]
@export var obstacle_scenes: Array[PackedScene] = [
	preload("res://scenes/obstacles/shrub_1.tscn"),
	preload("res://scenes/obstacles/shrub_2.tscn"),
	preload("res://scenes/obstacles/shrub_3.tscn")
]
@export var music_stream: AudioStream = preload("res://music/gamejame_song.mp3")

@export_category("Attack Feedback")
@export var attack_sound_streams: Array[AudioStream] = [
	preload("res://sounds/attack_sounds/attack_sound_1.mp3"),
	preload("res://sounds/attack_sounds/attack_sound_2.mp3"),
	preload("res://sounds/attack_sounds/attack_sound_3.mp3")
]
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var attack_sound_volume_db: float = 0.0
@export var attack_sound_bus: StringName = &"AttackClick"
@export var click_poof_texture: Texture2D = preload("res://sprites/particle_fx_texture.png")
@export_range(1, 64, 1) var click_poof_particle_count: int = 14
@export var click_poof_lifetime: float = 0.45
@export var click_poof_radius: float = 48.0
@export var click_poof_start_scale_range: Vector2 = Vector2(0.07, 0.13)
@export var click_poof_end_scale_multiplier: float = 1.35
@export var click_poof_color: Color = Color(1.0, 1.0, 1.0, 0.9)

@export_category("Fake Target")
@export var fake_target_scale: float = 0.55
@export var fake_target_hit_padding: Vector2 = Vector2(16.0, 16.0)
@export var fake_target_animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var fake_target_death_animation_name: StringName = &"Death"
@export var fake_target_hide_after_death_animation: bool = false
@export var shot_lock_cooldown_seconds: float = 9999.0

@export_category("Target Paper UI")
@export var target_paper_texture: Texture2D = preload("res://sprites/UI/paper.png")
@export_range(0.05, 2.0, 0.01) var target_paper_scale: float = 0.28
@export_range(0.0, 500.0, 1.0, "suffix:px") var target_paper_collapsed_visible_height: float = 42.0
@export var target_paper_screen_margin: Vector2 = Vector2(16.0, 12.0)
@export_range(0.01, 2.0, 0.01, "suffix:s") var target_paper_hover_seconds: float = 0.22
@export_range(0.05, 2.0, 0.01) var target_preview_scale_on_paper: float = 0.16
@export var target_preview_position_on_paper: Vector2 = Vector2(70.0, 72.0)

@export_category("Obstacles")
@export var obstacle_count_range: Vector2i = Vector2i(5, 8)
@export var obstacle_scale_range: Vector2 = Vector2(0.9, 1.1)
@export var obstacle_spawn_padding: float = 64.0
@export var min_obstacle_distance: float = 170.0
@export var obstacle_spawn_attempts: int = 32

@export_category("Goblin Walk-In")
@export var walk_in_goblin_count: int = 15
@export var walk_in_goblin_scale: float = 0.25
@export var walk_in_duration_range: Vector2 = Vector2(2.2, 4.0)
@export var walk_in_target_padding: float = 90.0
@export var walk_in_offscreen_padding: float = 420.0
@export var goblin_body_color_a: Color = Color(0.45, 0.95, 0.25, 1.0)
@export var goblin_body_color_b: Color = Color(0.14, 0.55, 0.24, 1.0)
@export var walk_squash_enabled: bool = true
@export var walk_squash_amount: float = 0.08
@export var walk_squash_frequency: float = 5.0
@export var walk_squash_reference_speed: float = 220.0
@export var walk_squash_max_speed_factor: float = 2.0
@export var walk_squash_lerp_speed: float = 18.0

@export_category("Final Face")
@export var final_face_delay_seconds: float = 10.0
@export var final_face_rise_seconds: float = 2.25
@export var final_face_scale: float = 6.0
@export var final_face_end_y_ratio: float = 0.62
@export_range(0.0, 10.0, 0.1, "suffix:s") var final_backdrop_fade_seconds: float = 3.0
@export var final_reveal_sound: AudioStream
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var final_reveal_sound_volume_db: float = 0.0
@export var final_reveal_sound_bus: StringName = &"Master"
@export var credits_scene: PackedScene = preload("res://credits_scene.tscn")

var _background: Sprite2D
var _sortable_parent: Node2D
var _fake_target: Node2D
var _ui: Node
var _music_player: AudioStreamPlayer
var _shot_taken: bool = false
var _pending_final_face: bool = false
var _final_face_timer: float = 0.0
var _running_goblins: Array[Node2D] = []
var _final_backdrop_overlay: ColorRect = null
var _final_face_layer: CanvasLayer = null
var _target_paper_layer: CanvasLayer = null
var _target_paper_drawer: Control = null
var _target_paper_expanded: bool = false
var _target_paper_tween: Tween = null


func _ready() -> void:
	randomize()
	_create_background()
	_create_sortable_parent()
	_spawn_obstacles()
	_create_fake_target()
	_create_target_paper_ui()
	_create_ui()
	_create_music_player()
	_update_all_depths()


func _process(delta: float) -> void:
	_update_running_goblin_walk_squash(delta)
	_update_target_paper_drawer_position(false)

	if _pending_final_face:
		_final_face_timer -= delta
		if _final_face_timer <= 0.0:
			_pending_final_face = false
			_raise_final_face()


func _unhandled_input(event: InputEvent) -> void:
	if _shot_taken:
		return

	if event.is_action_pressed("left_click"):
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		var click_position: Vector2 = get_global_mouse_position()
		if mouse_event != null:
			click_position = mouse_event.position

		if _is_fake_target_hit(click_position):
			get_viewport().set_input_as_handled()
			_shoot_fake_target(click_position)


func _create_background() -> void:
	_background = Sprite2D.new()
	_background.name = "BackgroundFloor"
	_background.texture = background_texture
	_background.self_modulate = background_tint_color
	_background.centered = true
	add_child(_background)
	_background.global_position = _get_viewport_center()
	_fit_background_to_viewport()


func _fit_background_to_viewport() -> void:
	if _background == null or _background.texture == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var texture_size: Vector2 = _background.texture.get_size()
	var fit_scale: float = maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	_background.scale = Vector2.ONE * fit_scale


func _create_sortable_parent() -> void:
	_sortable_parent = Node2D.new()
	_sortable_parent.name = "OutroObjects"
	_sortable_parent.y_sort_enabled = true
	add_child(_sortable_parent)


func _create_fake_target() -> void:
	if fake_target_scene != null:
		var target_instance: Node = fake_target_scene.instantiate()
		_fake_target = target_instance as Node2D
		if _fake_target == null:
			push_warning("Outro fake target scene root must be Node2D. Falling back to sprite target.")
			target_instance.queue_free()
			_create_fake_target_sprite_fallback()
			return

		_fake_target.name = "FakeGoblinTarget"
		_fake_target.scale *= fake_target_scale
		_sortable_parent.add_child(_fake_target)
		_fake_target.global_position = _get_viewport_center()
		_update_depth_z_index(_fake_target)
		return

	_create_fake_target_sprite_fallback()


func _create_fake_target_sprite_fallback() -> void:
	var fake_sprite: Sprite2D = Sprite2D.new()
	fake_sprite.name = "FakeGoblinTarget"
	fake_sprite.texture = fake_goblin_texture
	fake_sprite.centered = true
	fake_sprite.scale = Vector2.ONE * fake_target_scale
	_sortable_parent.add_child(fake_sprite)
	fake_sprite.global_position = _get_viewport_center()
	_fake_target = fake_sprite
	_update_depth_z_index(fake_sprite)


func _create_target_paper_ui() -> void:
	if target_paper_texture == null:
		return

	_target_paper_layer = CanvasLayer.new()
	_target_paper_layer.name = "OutroTargetPaperLayer"
	_target_paper_layer.layer = 5
	add_child(_target_paper_layer)

	_target_paper_drawer = Control.new()
	_target_paper_drawer.name = "OutroTargetPaperDrawer"
	_target_paper_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_paper_drawer.clip_contents = false
	_target_paper_drawer.custom_minimum_size = _get_target_paper_display_size()
	_target_paper_drawer.size = _get_target_paper_display_size()
	_target_paper_drawer.mouse_entered.connect(_on_target_paper_mouse_entered)
	_target_paper_drawer.mouse_exited.connect(_on_target_paper_mouse_exited)
	_target_paper_layer.add_child(_target_paper_drawer)

	var paper: TextureRect = TextureRect.new()
	paper.name = "TargetPaper"
	paper.texture = target_paper_texture
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.custom_minimum_size = target_paper_texture.get_size()
	paper.size = target_paper_texture.get_size()
	paper.scale = Vector2.ONE * target_paper_scale
	_target_paper_drawer.add_child(paper)

	var preview: Node2D = _create_fake_target_preview_for_paper()
	if preview != null:
		preview.name = "TargetPreview"
		preview.position = target_preview_position_on_paper
		preview.scale = Vector2.ONE * target_preview_scale_on_paper
		_target_paper_drawer.add_child(preview)

	_update_target_paper_drawer_position(false)


func _create_fake_target_preview_for_paper() -> Node2D:
	var preview: Node2D = null
	if fake_target_scene != null:
		preview = fake_target_scene.instantiate() as Node2D

	if preview == null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = fake_goblin_texture
		sprite.centered = true
		preview = sprite

	_remove_animation_players(preview)
	_reset_preview_sprite_animation_state(preview)
	return preview


func _remove_animation_players(node: Node) -> void:
	for child in node.get_children():
		_remove_animation_players(child)

	var animation_player: AnimationPlayer = node as AnimationPlayer
	if animation_player != null:
		animation_player.queue_free()


func _reset_preview_sprite_animation_state(node: Node) -> void:
	var node_2d: Node2D = node as Node2D
	if node_2d != null:
		node_2d.position = Vector2.ZERO
		node_2d.rotation = 0.0

	for child in node.get_children():
		_reset_preview_sprite_animation_state(child)


func _get_target_paper_display_size() -> Vector2:
	if target_paper_texture == null:
		return Vector2.ZERO
	return target_paper_texture.get_size() * target_paper_scale


func _update_target_paper_drawer_position(animated: bool) -> void:
	if !is_instance_valid(_target_paper_drawer):
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var paper_size: Vector2 = _get_target_paper_display_size()
	_target_paper_drawer.size = paper_size
	_target_paper_drawer.custom_minimum_size = paper_size
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


func _create_ui() -> void:
	if ui_scene == null:
		return
	_ui = ui_scene.instantiate()
	add_child(_ui)


func _create_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "OutroMusic"
	_music_player.stream = music_stream
	_music_player.autoplay = true
	_music_player.bus = &"Music"
	add_child(_music_player)
	_music_player.play()


func _shoot_fake_target(click_position: Vector2) -> void:
	_shot_taken = true
	_play_click_feedback(click_position)
	if is_instance_valid(_music_player):
		_music_player.stop()
	if is_instance_valid(_ui) and _ui.has_method("fire"):
		_ui.call("fire", shot_lock_cooldown_seconds)

	_play_fake_target_death_animation()

	_spawn_walk_in_goblins()
	_pending_final_face = true
	_final_face_timer = final_face_delay_seconds


func _is_fake_target_hit(global_point: Vector2) -> bool:
	if !is_instance_valid(_fake_target):
		return false

	var local_point: Vector2 = _fake_target.to_local(global_point)
	var local_bounds: Rect2 = _get_node_visual_local_bounds(_fake_target)
	if local_bounds.size.x <= 0.0 or local_bounds.size.y <= 0.0:
		return false

	local_bounds = local_bounds.grow_individual(
		fake_target_hit_padding.x,
		fake_target_hit_padding.y,
		fake_target_hit_padding.x,
		fake_target_hit_padding.y
	)
	return local_bounds.has_point(local_point)


func _play_fake_target_death_animation() -> void:
	if !is_instance_valid(_fake_target):
		return

	var animation_player: AnimationPlayer = _fake_target.get_node_or_null(fake_target_animation_player_path) as AnimationPlayer
	if animation_player == null:
		animation_player = _find_first_animation_player(_fake_target)

	if animation_player != null and animation_player.has_animation(fake_target_death_animation_name):
		animation_player.play(fake_target_death_animation_name)
		if fake_target_hide_after_death_animation:
			animation_player.animation_finished.connect(_on_fake_target_death_animation_finished, CONNECT_ONE_SHOT)
		return

	if fake_target_hide_after_death_animation:
		_fake_target.visible = false


func _on_fake_target_death_animation_finished(_animation_name: StringName) -> void:
	if is_instance_valid(_fake_target):
		_fake_target.visible = false


func _spawn_obstacles() -> void:
	if obstacle_scenes.is_empty():
		return

	var bounds: Rect2 = _get_spawn_bounds(obstacle_spawn_padding)
	var count: int = randi_range(maxi(0, mini(obstacle_count_range.x, obstacle_count_range.y)), maxi(obstacle_count_range.x, obstacle_count_range.y))
	var placed_positions: Array[Vector2] = []
	for i in range(count):
		var spawn_position: Variant = _find_spaced_position(bounds, placed_positions, min_obstacle_distance, obstacle_spawn_attempts)
		if spawn_position == null:
			break

		var scene: PackedScene = obstacle_scenes[randi_range(0, obstacle_scenes.size() - 1)]
		if scene == null:
			continue
		var obstacle: Node = scene.instantiate()
		var obstacle_2d: Node2D = obstacle as Node2D
		if obstacle_2d == null:
			obstacle.queue_free()
			continue

		_sortable_parent.add_child(obstacle_2d)
		obstacle_2d.global_position = spawn_position as Vector2
		obstacle_2d.scale *= randf_range(minf(obstacle_scale_range.x, obstacle_scale_range.y), maxf(obstacle_scale_range.x, obstacle_scale_range.y))
		_set_obstacle_flip(obstacle_2d, randf() < 0.5)
		_update_depth_z_index(obstacle_2d)
		placed_positions.append(obstacle_2d.global_position)


func _spawn_walk_in_goblins() -> void:
	var screen_bounds: Rect2 = get_viewport_rect()
	var target_bounds: Rect2 = _get_spawn_bounds(walk_in_target_padding)
	for i in range(walk_in_goblin_count):
		var goblin: Node2D = _create_visual_goblin()
		_sortable_parent.add_child(goblin)
		goblin.global_position = _get_random_offscreen_position(screen_bounds)
		var target_position: Vector2 = Vector2(
			randf_range(target_bounds.position.x, target_bounds.position.x + target_bounds.size.x),
			randf_range(target_bounds.position.y, target_bounds.position.y + target_bounds.size.y)
		)
		_update_depth_z_index(goblin)
		var walk_duration: float = randf_range(walk_in_duration_range.x, walk_in_duration_range.y)
		goblin.set_meta("walk_duration", walk_duration)
		_start_running_squiggle(goblin, target_position)

		var tween: Tween = goblin.create_tween()
		tween.tween_property(goblin, "global_position", target_position, walk_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.finished.connect(func() -> void: _finish_running_squiggle(goblin))


func _create_visual_goblin() -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = "OutroGoblin"
	root.scale = Vector2.ONE * walk_in_goblin_scale
	root.set_meta("base_scale", root.scale)
	root.set_meta("squash_phase", randf() * TAU)

	var shadow: Sprite2D = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = goblin_shadow_texture
	root.add_child(shadow)

	var body: Sprite2D = Sprite2D.new()
	body.name = "Body"
	body.texture = goblin_body_texture
	body.self_modulate = goblin_body_color_a.lerp(goblin_body_color_b, randf())
	root.add_child(body)

	var clothing: Sprite2D = Sprite2D.new()
	clothing.name = "Clothing"
	clothing.texture = _pick_texture(goblin_clothing_textures)
	body.add_child(clothing)

	var face: Sprite2D = Sprite2D.new()
	face.name = "Face"
	face.texture = _pick_texture(goblin_face_textures)
	body.add_child(face)

	var hat: Sprite2D = Sprite2D.new()
	hat.name = "Hat"
	hat.texture = _pick_texture(goblin_hat_textures)
	body.add_child(hat)

	return root


func _raise_final_face() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if is_instance_valid(_final_face_layer):
		_final_face_layer.queue_free()

	_final_face_layer = CanvasLayer.new()
	_final_face_layer.name = "FinalFaceLayer"
	# Face layer sits above the black fade layer so the face stays visible.
	_final_face_layer.layer = 20
	add_child(_final_face_layer)

	var face: Sprite2D = Sprite2D.new()
	face.name = "FinalGoblinFace"
	face.texture = final_face_texture
	face.centered = true
	face.scale = Vector2.ONE * final_face_scale
	_final_face_layer.add_child(face)

	var start_position: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y + _get_texture_height(face) * final_face_scale * 0.5)
	var end_position: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * final_face_end_y_ratio)
	face.position = start_position

	var tween: Tween = face.create_tween()
	tween.tween_property(face, "position", end_position, final_face_rise_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_final_face_revealed)


func _on_final_face_revealed() -> void:
	_fade_backdrop_to_black()
	_play_final_reveal_sound()


func _fade_backdrop_to_black() -> void:
	if is_instance_valid(_final_backdrop_overlay):
		_final_backdrop_overlay.queue_free()

	var overlay_layer: CanvasLayer = CanvasLayer.new()
	overlay_layer.name = "FinalBackdropFadeLayer"
	# Fade layer covers the whole scene, but remains under FinalFaceLayer.
	overlay_layer.layer = 10
	add_child(overlay_layer)

	_final_backdrop_overlay = ColorRect.new()
	_final_backdrop_overlay.name = "FinalBackdropFade"
	_final_backdrop_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_backdrop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_final_backdrop_overlay.size = get_viewport_rect().size
	_final_backdrop_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay_layer.add_child(_final_backdrop_overlay)

	var tween: Tween = _final_backdrop_overlay.create_tween()
	tween.tween_property(
		_final_backdrop_overlay,
		"color",
		Color(0.0, 0.0, 0.0, 1.0),
		maxf(0.0, final_backdrop_fade_seconds)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_final_reveal_sound() -> void:
	if final_reveal_sound == null:
		_go_to_credits()
		return

	var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_player.name = "FinalRevealSound"
	audio_player.stream = final_reveal_sound
	audio_player.volume_db = final_reveal_sound_volume_db
	audio_player.bus = final_reveal_sound_bus
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.finished.connect(_go_to_credits)
	add_child(audio_player)
	audio_player.play()


func _go_to_credits() -> void:
	if credits_scene == null:
		return

	get_tree().change_scene_to_packed(credits_scene)


func _play_click_feedback(click_position: Vector2) -> void:
	_spawn_click_poof(click_position)
	_play_random_attack_sound(click_position)


func _play_random_attack_sound(click_position: Vector2) -> void:
	if attack_sound_streams.is_empty():
		return

	var attack_sound: AudioStream = attack_sound_streams[randi_range(0, attack_sound_streams.size() - 1)]
	if attack_sound == null:
		return

	var audio_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	audio_player.name = "OutroAttackSound"
	audio_player.stream = attack_sound
	audio_player.volume_db = attack_sound_volume_db
	audio_player.bus = attack_sound_bus
	audio_player.finished.connect(audio_player.queue_free)
	add_child(audio_player)
	audio_player.global_position = click_position
	audio_player.play()


func _spawn_click_poof(click_position: Vector2) -> void:
	if click_poof_texture == null:
		return

	var poof_root: Node2D = Node2D.new()
	poof_root.name = "OutroClickPoof"
	poof_root.z_as_relative = false
	poof_root.z_index = DEPTH_Z_INDEX_MAX
	add_child(poof_root)
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

		var direction: Vector2 = Vector2.from_angle(randf() * TAU)
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


func _start_running_squiggle(goblin: Node2D, target_position: Vector2) -> void:
	var direction: Vector2 = target_position - goblin.global_position
	var facing_sign: float = -1.0 if direction.x > 0.0 else 1.0
	var base_scale: Vector2 = Vector2(walk_in_goblin_scale * facing_sign, walk_in_goblin_scale)
	goblin.set_meta("base_scale", base_scale)
	goblin.set_meta("squash_phase", randf() * TAU)
	goblin.set_meta("movement_speed", direction.length() / maxf(0.01, float(goblin.get_meta("walk_duration", 1.0))))
	goblin.scale = base_scale
	if !_running_goblins.has(goblin):
		_running_goblins.append(goblin)


func _finish_running_squiggle(goblin: Node2D) -> void:
	_update_depth_z_index(goblin)
	_running_goblins.erase(goblin)
	if is_instance_valid(goblin):
		goblin.scale = goblin.get_meta("base_scale", goblin.scale) as Vector2


func _update_running_goblin_walk_squash(delta: float) -> void:
	for i in range(_running_goblins.size() - 1, -1, -1):
		var goblin: Node2D = _running_goblins[i]
		if !is_instance_valid(goblin):
			_running_goblins.remove_at(i)
			continue

		var base_scale: Vector2 = goblin.get_meta("base_scale", Vector2.ONE * walk_in_goblin_scale) as Vector2
		if !walk_squash_enabled:
			goblin.scale = goblin.scale.lerp(base_scale, clampf(walk_squash_lerp_speed * delta, 0.0, 1.0))
			_update_depth_z_index(goblin)
			continue

		var movement_speed: float = float(goblin.get_meta("movement_speed", walk_squash_reference_speed))
		var reference_speed: float = maxf(1.0, walk_squash_reference_speed)
		var speed_factor: float = clampf(
			movement_speed / reference_speed,
			0.35,
			maxf(0.35, walk_squash_max_speed_factor)
		)
		var phase: float = fmod(
			float(goblin.get_meta("squash_phase", 0.0)) + delta * TAU * walk_squash_frequency * speed_factor,
			TAU
		)
		goblin.set_meta("squash_phase", phase)

		var squash_amount: float = maxf(0.0, walk_squash_amount) * speed_factor
		var pulse: float = sin(phase)
		var target_scale: Vector2 = Vector2(
			base_scale.x * (1.0 + pulse * squash_amount),
			base_scale.y * (1.0 - pulse * squash_amount)
		)
		var blend: float = clampf(walk_squash_lerp_speed * delta, 0.0, 1.0)
		goblin.scale = goblin.scale.lerp(target_scale, blend)
		_update_depth_z_index(goblin)


func _pick_texture(textures: Array[Texture2D]) -> Texture2D:
	if textures.is_empty():
		return null
	return textures[randi_range(0, textures.size() - 1)]


func _get_random_offscreen_position(screen_bounds: Rect2) -> Vector2:
	var side: int = randi_range(0, 3)
	var padding: float = maxf(walk_in_offscreen_padding, 320.0)
	match side:
		0:
			return Vector2(randf_range(screen_bounds.position.x - padding, screen_bounds.end.x + padding), screen_bounds.position.y - padding)
		1:
			return Vector2(screen_bounds.end.x + padding, randf_range(screen_bounds.position.y - padding, screen_bounds.end.y + padding))
		2:
			return Vector2(randf_range(screen_bounds.position.x - padding, screen_bounds.end.x + padding), screen_bounds.end.y + padding)
		_:
			return Vector2(screen_bounds.position.x - padding, randf_range(screen_bounds.position.y - padding, screen_bounds.end.y + padding))


func _get_spawn_bounds(padding: float) -> Rect2:
	var bounds: Rect2 = get_viewport_rect()
	var safe_padding: float = minf(maxf(0.0, padding), minf(bounds.size.x, bounds.size.y) * 0.45)
	return Rect2(bounds.position + Vector2.ONE * safe_padding, bounds.size - Vector2.ONE * safe_padding * 2.0)


func _find_spaced_position(bounds: Rect2, placed_positions: Array[Vector2], spacing: float, attempts: int) -> Variant:
	for i in range(maxi(1, attempts)):
		var candidate: Vector2 = Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
		var is_spaced: bool = true
		for placed_position in placed_positions:
			if candidate.distance_to(placed_position) < spacing:
				is_spaced = false
				break
		if is_spaced:
			return candidate
	return null


func _find_first_animation_player(node: Node) -> AnimationPlayer:
	var animation_player: AnimationPlayer = node as AnimationPlayer
	if animation_player != null:
		return animation_player

	for child in node.get_children():
		var found_player: AnimationPlayer = _find_first_animation_player(child)
		if found_player != null:
			return found_player

	return null


func _get_node_visual_local_bounds(node: Node2D) -> Rect2:
	var has_bounds: bool = false
	var bounds: Rect2 = Rect2()
	for sprite in _get_descendant_sprites(node):
		if !sprite.visible or sprite.texture == null:
			continue

		var sprite_bounds: Rect2 = _get_sprite_bounds_in_node_space(sprite, node)
		if !has_bounds:
			bounds = sprite_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(sprite_bounds)

	return bounds if has_bounds else Rect2()


func _get_descendant_sprites(node: Node) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	var sprite: Sprite2D = node as Sprite2D
	if sprite != null:
		sprites.append(sprite)

	for child in node.get_children():
		sprites.append_array(_get_descendant_sprites(child))

	return sprites


func _get_sprite_bounds_in_node_space(sprite: Sprite2D, root_node: Node2D) -> Rect2:
	var sprite_size: Vector2 = sprite.texture.get_size()
	if sprite.region_enabled:
		sprite_size = sprite.region_rect.size

	var local_origin: Vector2 = -sprite_size * 0.5 if sprite.centered else Vector2.ZERO
	local_origin += sprite.offset
	var corners: Array[Vector2] = [
		local_origin,
		local_origin + Vector2(sprite_size.x, 0.0),
		local_origin + Vector2(0.0, sprite_size.y),
		local_origin + sprite_size
	]
	var to_root: Transform2D = root_node.global_transform.affine_inverse() * sprite.global_transform
	var min_point: Vector2 = to_root * corners[0]
	var max_point: Vector2 = min_point
	for i in range(1, corners.size()):
		var point: Vector2 = to_root * corners[i]
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)

	return Rect2(min_point, max_point - min_point)


func _set_obstacle_flip(obstacle_node: Node, flip_h: bool) -> void:
	for child in obstacle_node.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite != null:
			sprite.flip_h = flip_h
		_set_obstacle_flip(child, flip_h)


func _update_all_depths() -> void:
	if !is_instance_valid(_sortable_parent):
		return
	for child in _sortable_parent.get_children():
		var child_2d: Node2D = child as Node2D
		if child_2d != null:
			_update_depth_z_index(child_2d)


func _update_depth_z_index(node: Node2D) -> void:
	node.z_as_relative = false
	node.z_index = clampi(int(round(node.global_position.y)), DEPTH_Z_INDEX_MIN, DEPTH_Z_INDEX_MAX)


func _get_viewport_center() -> Vector2:
	var viewport_rect: Rect2 = get_viewport_rect()
	return viewport_rect.position + viewport_rect.size * 0.5


func _get_texture_height(sprite: Sprite2D) -> float:
	if sprite.texture == null:
		return 0.0
	return sprite.texture.get_size().y
