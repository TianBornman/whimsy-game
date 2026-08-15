extends CanvasLayer
@onready var anim_player: AnimationPlayer = $anim_player
@onready var colour_box: ColorRect = $colour_box




func _ready() -> void:
	anim_player.play("intro_anim")


func _on_anim_player_animation_finished(_anim_name: StringName) -> void:
	if _anim_name == "intro_anim":
		var tween = get_tree().create_tween()
		tween.tween_property(colour_box, "self_modulate", Color.BLACK, 1.0)
		await get_tree().create_timer(1).timeout
		switch_scene()
	

func _on_button_pressed() -> void:
	switch_scene()
	print("wtf")


func switch_scene():
	get_tree().change_scene_to_file("res://level_1.tscn")
