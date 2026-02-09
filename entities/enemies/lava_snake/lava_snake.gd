extends Area2D

@export var damage_amount := 1
@export var knockback_force := 500.0
@export var max_health := 2 # Updated: Snakes now have 2 health
var current_health : int

@onready var sprite = $Sprite2D
@onready var health_bar = $EnemyHealthBar

func _ready() -> void:
	# Initialize health
	current_health = max_health
	
	# 1. Connect the signal
	body_entered.connect(_on_body_entered)
	
	# 2. GENERATE UNIQUE KEY
	# Uses the Level Name (BasicLevel) + the Node Name (SpikeTrap/PlantTrap)
	var level_name = get_tree().current_scene.name
	var enemy_key = level_name + "_" + name
	
	# 3. CHECK IF DEAD
	# If this specific enemy is in Global.destroyed_enemies, delete it immediately
	if Global.destroyed_enemies.has(enemy_key):
		queue_free()
		return 
		
	health_bar.setup(max_health)
	
	# 4. Start the "Living" animations
	start_wiggle()
	start_glow()

func start_wiggle():
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.8).set_trans(Tween.TRANS_SINE)

func start_glow():
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.2, 1.2), 1.2) 
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 1.2)

func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_inside_tree(): 
		return

	if body.name == "Player":
		var is_smashing = body.get("is_rock_smashing") == true
		var is_rock_mask = body.get("current_set_id") == 4 
		var is_aura_active = body.get("is_rock_aura_active") == true

		# Updated Logic: Use take_damage(1) instead of die()
		if is_smashing or is_aura_active or (is_rock_mask and body.velocity.y > 700.0):
			take_damage(1) 
			# Bounce Goma up so he doesn't stay inside the lava
			body.velocity.y = -400
			return
			
		if body.get("is_invincible") == true:
			return

		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
			var push_dir = (body.global_position - global_position).normalized()
			body.velocity = push_dir * knockback_force

# Function to handle health subtraction and visual hits
var hit_cooldown := 0.0
func take_damage(amount: int):
	if hit_cooldown > 0: return # Skip if recently hit
	current_health -= amount
	health_bar.update_health(current_health)
	hit_cooldown = 0.4 # wait 0.4s before taking damage again
	
	# Visual Feedback: Quick red flash
	var flash = create_tween()
	flash.tween_property(sprite, "self_modulate", Color.RED, 0.05)
	flash.tween_property(sprite, "self_modulate", Color.WHITE, 0.05)
	
	if current_health <= 0:
		die()
		
func _process(delta: float):
	if hit_cooldown > 0:
		hit_cooldown -= delta
		
func die():
	# save to global list
	var level_name = get_tree().current_scene.name
	var enemy_key = level_name + "_" + name
	Global.destroyed_enemies[enemy_key] = true
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 0.1), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	
	await tween.finished
	queue_free()
