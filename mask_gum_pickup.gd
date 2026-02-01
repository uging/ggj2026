extends Area2D

# This creates a dropdown in the Inspector so you can reuse this scene 
# for the Feather, Gum, and Rock masks!
@export_enum("feather", "gum", "rock") var mask_type: String = "feather"

func _ready() -> void:
	# Connect the signal for when Goma touches the item
	body_entered.connect(_on_body_entered)
	
	# Optional: Make the mask icon "float" so it's easy to see
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", -5.0, 0.8).as_relative()
	tween.tween_property(self, "position:y", 5.0, 0.8).as_relative()

func _on_body_entered(body: Node2D) -> void:
	# Check if the body is Goma and has our collection function
	if body.has_method("collect_mask"):
		body.collect_mask(mask_type)
		play_collect_effect()

func play_collect_effect() -> void:
	# Simple 'pop' animation before deleting
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.finished.connect(queue_free)
