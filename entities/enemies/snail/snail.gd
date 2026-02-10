extends CharacterBody2D

# --- Movement Stats ---
@export var speed := 60.0
@export var damage_amount := 1
@export var knockback_force := 500.0
@export var max_health := 2 # Updated: Snail now survives one smash
var current_health : int

var direction := 1 # 1 = Right, -1 = Left
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var turn_cooldown := 0.0

# --- References ---
@onready var floor_ray: RayCast2D = $FloorRay
@onready var wall_ray: RayCast2D = $WallRay
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_box: Area2D = $HurtBox
@onready var health_bar = $EnemyHealthBar

func _ready() -> void:
	current_health = max_health # Initialize health
	
	if not hurt_box.body_entered.is_connected(_on_hurt_box_body_entered):
		hurt_box.body_entered.connect(_on_hurt_box_body_entered)
		
		# 1. GENERATE UNIQUE KEY
	# Uses the Level Name (BasicLevel) + the Node Name (SpikeTrap/PlantTrap)
	var level_path = get_tree().current_scene.scene_file_path
	var enemy_key = level_path + "_" + str(global_position) # Using position makes it very unique
	
	# 2. CHECK IF DEAD
	# If this specific enemy is in Global.destroyed_enemies, delete it immediately
	if Global.destroyed_enemies.has(enemy_key):
		queue_free()
		return 
	health_bar.setup(max_health)
	
	start_crawling_animation()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if turn_cooldown > 0:
		turn_cooldown -= delta

	if is_on_floor() and turn_cooldown <= 0:
		if not floor_ray.is_colliding() or wall_ray.is_colliding():
			direction *= -1
			sprite.flip_h = (direction == 1)
			floor_ray.position.x = 18 * direction 
			wall_ray.target_position.x = abs(wall_ray.target_position.x) * direction
			turn_cooldown = 0.2

	velocity.x = direction * speed
	move_and_slide()

func start_crawling_animation():
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.5)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.5)

# --- Damage & Smashing Logic ---
func _on_hurt_box_body_entered(body: Node2D) -> void:
	if body == null or not body.is_inside_tree(): 
		return

	if body.name == "Player":
		var is_smashing = body.get("is_rock_smashing") == true
		var is_rock_mask = body.get("current_set_id") == 4
		var is_falling_fast = body.velocity.y > 700.0
		var is_aura_active = body.get("is_rock_aura_active") == true

		# Updated: Deal 1 damage instead of instant death
		if is_smashing or is_aura_active or (is_rock_mask and is_falling_fast):
			take_damage(1)
			if body.has_method("bounce_off_enemy"):
				body.bounce_off_enemy()
			# Give Goma a bounce so he doesn't immediately get hit by the snail
			body.velocity.y = -400
			return 
			
		if body.get("is_invincible") == true:
			return

		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
			var push_dir = (body.global_position - global_position).normalized()
			body.velocity = push_dir * knockback_force

# Added take_damage to handle the 2-hit health pool
var hit_cooldown := 0.0
func take_damage(amount: int):
	if hit_cooldown > 0: return # Skip if recently hit
	
	current_health -= amount
	health_bar.update_health(current_health)
	hit_cooldown = 0.4 # Wait 0.4s before taking damage again
	
	GlobalAudioManager.play_enemy_hurt("snail")
	
	# Visual Hit Flash
	var flash = create_tween()
	flash.tween_property(sprite, "modulate", Color.RED, 0.05)
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	
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
	
	set_physics_process(false)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 0.1), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	
	await tween.finished
	queue_free()
