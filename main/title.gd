extends Label

func _ready():
	# Start slightly smaller and transparent
	scale = Vector2(0.9, 0.9)
	modulate.a = 0.0

	var t := create_tween()

	# Intro: fade + scale in
	t.tween_property(self, "modulate:a", 1.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Then loop a very subtle breathing motion
	t.set_loops()
	t.tween_property(self, "scale", Vector2(1.03, 1.03), 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
