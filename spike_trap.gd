extends Area2D

@export var damage_amount := 1
@export var knockback_force := 500.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_amount)
		
		# Optional: Push Goma away from the spike
		var push_dir = (body.global_position - global_position).normalized()
		body.velocity = push_dir * knockback_force
