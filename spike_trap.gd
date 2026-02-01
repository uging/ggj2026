extends Area2D

@export var damage_amount := 1
@export var knockback_force := 500.0
@export var trap_health := 1 # Plants/Spikes only need 1 hit to break

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# 1. Declare the check: is he smashing OR falling very fast (the smash speed)?
		var is_smashing = body.get("is_rock_smashing") == true
		var is_falling_fast = body.velocity.y > 700.0 # Smash fall speed is 1200, so 700 is a safe "landing" threshold

		# 2. If either is true, the trap should NOT hurt Goma
		if is_smashing or is_falling_fast:
			return 
			
		# 3. If he is already invincible (blinking), let him pass through.
		if body.get("is_invincible") == true:
			return

		# 4. Otherwise, do the normal damage logic
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
			var push_dir = (body.global_position - global_position).normalized()
			body.velocity = push_dir * knockback_force

func _physics_process(_delta: float) -> void:
	if not monitoring: return
	
	# Check for both Bodies (Player) and overlapping Areas
	for body in get_overlapping_bodies():
		if body.name == "Player":
			# If player is smashing OR falling fast enough to be a smash
			if body.get("is_rock_smashing") == true or body.velocity.y > 700.0:
				take_damage(1)
				return

func take_damage(amount: int):
	trap_health -= amount
	if trap_health <= 0:
		break_trap()

func break_trap():
	# Disable collisions immediately so he doesn't hit it twice
	monitoring = false 
	monitorable = false
	
	# Create a quick "shatter" scale effect
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1) # Quick swell
	tween.tween_property(self, "modulate:a", 0.0, 0.1)          # Fade out
	
	await tween.finished
	queue_free()
