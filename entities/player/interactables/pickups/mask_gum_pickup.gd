extends Area2D

@export_enum("feather", "gum", "rock") var mask_type: String = "feather"

func _ready() -> void:
	# Connect the signal for when Goma touches the item
	# 1. Check if this specific mask is already unlocked in Global
	# If it is, delete it before the player even sees it
	if Global.unlocked_masks.get(mask_type, false):
		queue_free()
		return 

	# 2. Otherwise, proceed with normal setup
	body_entered.connect(_on_body_entered)
	
	# Make the mask icon "float" so it's easy to see
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", -5.0, 0.8).as_relative()
	tween.tween_property(self, "position:y", 5.0, 0.8).as_relative()

func _on_body_entered(body: Node2D) -> void:
	# 1. Verify it's the player
	if body.is_in_group("player"):
		# 2. Update Global data and trigger signals automatically
		Global.unlock_mask(mask_type)
		
		# 3. Tell the player to physically swap to the new mask
		if body.has_method("collect_mask"):
			body.collect_mask(mask_type)
		
		# 4. Visual/Sound feedback
		play_collect_effect()
		queue_free()

func play_collect_effect() -> void:
	# Simple 'pop' animation before deleting
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.finished.connect(queue_free)
