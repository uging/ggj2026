extends Area2D

@export var damage_amount := 1
@export var knockback_force := 500.0
@export var trap_health := 1 

func _ready() -> void:
	# 1. GENERATE UNIQUE KEY
	# Uses the Level Name (BasicLevel) + the Node Name (SpikeTrap/PlantTrap)
	var level_name = get_tree().current_scene.name
	var enemy_key = level_name + "_" + name
	
	# 2. CHECK IF DEAD
	# If this specific enemy is in Global.destroyed_enemies, delete it immediately
	if Global.destroyed_enemies.has(enemy_key):
		queue_free()
		return 

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var is_smashing = body.get("is_rock_smashing") == true
		var is_falling_fast = body.velocity.y > 700.0 

		if is_smashing or is_falling_fast:
			return 
			
		if body.get("is_invincible") == true:
			return

		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
			var push_dir = (body.global_position - global_position).normalized()
			body.velocity = push_dir * knockback_force

func _physics_process(_delta: float) -> void:
	if not monitoring: return

	for body in get_overlapping_bodies():
		if body == null or not is_instance_valid(body):
			continue

		if body.name == "Player":
			var player_vel = body.get("velocity") if body.get("velocity") != null else Vector2.ZERO
			if body.get("is_rock_smashing") == true or player_vel.y > 700.0:
				take_damage(1)
				return

func take_damage(amount: int):
	trap_health -= amount
	if trap_health <= 0:
		break_trap()

func break_trap():
	# 3. RECORD THE DEATH
	# This ensures the trap 'Self-Destructs' next time the level loads
	var level_name = get_tree().current_scene.name
	Global.destroyed_enemies[level_name + "_" + name] = true
	
	monitoring = false 
	monitorable = false
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	
	await tween.finished
	queue_free()
