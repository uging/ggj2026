extends Area2D

@export var heal_amount := 1

func _ready() -> void:
	# Connect the signal for when Goma enters the heart
	body_entered.connect(_on_body_entered)
	
	# Visual: Make it bob gently
	var tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", -10.0, 1.2).as_relative()
	tween.tween_property(self, "position:y", 10.0, 1.2).as_relative()

func _on_body_entered(body: Node2D) -> void:
	# Check if the body has our 'heal' function
	if body.has_method("heal"):
		# Only pick up if health is less than the max (10)
		if body.current_health < body.max_health:
			body.heal(heal_amount)
			play_collect_animation()

func play_collect_animation():
	# Pop and fade effect before deleting the node
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.finished.connect(queue_free)
