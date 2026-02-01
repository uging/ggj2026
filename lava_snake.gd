extends Area2D

@export var damage_amount := 1
@export var knockback_force := 500.0
@export var health := 1

@onready var sprite = $Sprite2D

func _ready() -> void:
	# 1. Connect the signal
	body_entered.connect(_on_body_entered)
	
	# 2. Start the "Living" animations
	start_wiggle()
	start_glow()

func start_wiggle():
	# This makes the snake "breathe" or wiggle slightly
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.8).set_trans(Tween.TRANS_SINE)

func start_glow():
	# This makes the lava color pulse
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.2, 1.2), 1.2) # Brighten (Over-brightening works in Godot)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 1.2)       # Normal

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# --- YOUR SPIKE TRAP LOGIC ---
		var is_smashing = body.get("is_rock_smashing") == true
		var is_rock_mask = body.get("current_set_id") == 4 # Only ID 4 is Rock

		# If Goma smashes the lava snake, it dies
		if is_smashing or (is_rock_mask and body.velocity.y > 700.0):
			die()
			return
			
		if body.get("is_invincible") == true:
			return

		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
			var push_dir = (body.global_position - global_position).normalized()
			body.velocity = push_dir * knockback_force

func die():
	# Use set_deferred to avoid the "Function blocked" error
	# This tells Godot to wait until the current physics frame is over
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Squash and fade out
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 0.1), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	
	await tween.finished
	queue_free()
