extends CharacterBody2D

# --- Movement Stats ---
@export var speed := 60.0
@export var damage_amount := 1
@export var knockback_force := 500.0

var direction := 1 # 1 = Right, -1 = Left
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var turn_cooldown := 0.0

# --- References ---
# Ensure these names match your Scene Tree exactly!
@onready var floor_ray: RayCast2D = $FloorRay
@onready var wall_ray: RayCast2D = $WallRay
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_box: Area2D = $HurtBox

func _ready() -> void:
	# Connect the HurtBox signal automatically
	if not hurt_box.body_entered.is_connected(_on_hurt_box_body_entered):
		hurt_box.body_entered.connect(_on_hurt_box_body_entered)
	
	# Start a little "crawling" wiggle
	start_crawling_animation()

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. Turn Cooldown Timer
	if turn_cooldown > 0:
		turn_cooldown -= delta

	# 3. Edge and Wall Detection
	if is_on_floor() and turn_cooldown <= 0:
		# Check if we are about to fall or hit a wall
		if not floor_ray.is_colliding() or wall_ray.is_colliding():
			direction *= -1
			
			# Flip visuals
			sprite.flip_h = (direction == 1) # Adjust based on your default face
			
			# Move the FloorRay to the NEW front of the snail
			floor_ray.position.x = 18 * direction 
			
			# Add a tiny cooldown (0.2 seconds) so it doesn't flip back instantly
			turn_cooldown = 0.2 

	# 4. Apply Movement
	velocity.x = direction * speed
	move_and_slide()

func start_crawling_animation():
	# Makes the snail squash and stretch slightly as it moves
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.5)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.5)

# --- Damage & Smashing Logic ---
func _on_hurt_box_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# Check Goma's state
		var is_smashing = body.get("is_rock_smashing") == true
		var is_rock_mask = body.get("current_set_id") == 4
		var is_falling_fast = body.velocity.y > 700.0

		# If Goma smashes the snail, it dies
		if is_smashing or (is_rock_mask and is_falling_fast):
			die()
			return 
			
		# If Goma is invincible, don't hurt him
		if body.get("is_invincible") == true:
			return

		# Otherwise, hurt Goma
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
			var push_dir = (body.global_position - global_position).normalized()
			body.velocity = push_dir * knockback_force

func die():
	# 1. Disable all physics and collisions immediately
	set_physics_process(false)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)
	
	# 2. Death Animation (Squish into the floor)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 0.1), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	
	# 3. Remove the snail
	await tween.finished
	queue_free()
