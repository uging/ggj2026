extends Area2D

@export var heal_amount := 1
signal collected

func _ready() -> void:
	# Wait for the level script to finish setting up Global.player
	await get_tree().process_frame
	
	# We need to check Global.player because it holds the health stats
	# between level transitions.
	if Global.player != null:
		if Global.player.current_health >= 10:
			queue_free()
			return

	# Standard setup if player needs health
	body_entered.connect(_on_body_entered)

	# Visual: Gentle Bobbing
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", -10.0, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", 10.0, 1.2).as_relative().set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	print("Heart touched by: ", body.name)
	# Check if the body has our 'heal' function
	if body.has_method("heal"):
		# Only pick up if health is less than the max (10)
		if body.current_health < body.max_health:
			body.heal(heal_amount)
			collected.emit()
			# Disable collisions immediately so it can't be picked up twice
			set_deferred("monitoring", false)
			play_collect_animation()

func play_collect_animation():
	# Pop and fade effect before deleting the node
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.finished.connect(queue_free)
