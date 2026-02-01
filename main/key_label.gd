extends Label

func _ready():
	modulate.a = 1.0  # start visible

	var t := create_tween()
	t.set_loops()  # repeat forever

	# Fade out
	t.tween_property(self, "modulate:a", 0.2, 0.5) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	# Fade back in
	t.tween_property(self, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
