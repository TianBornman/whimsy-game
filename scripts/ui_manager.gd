extends CanvasLayer


@onready var timer: Timer = $Timer

@onready var anim: AnimationPlayer = $anim

func fire(cooldown : float):
	if timer.time_left == 0:
		anim.play("attack")
		timer.start(cooldown - 1.0)
	


func _on_timer_timeout() -> void:
	anim.play_backwards("attack")
