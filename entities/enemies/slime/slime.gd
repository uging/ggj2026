extends CharacterBody2D

enum SlimeType { YELLOW, BLUE, PURPLE }
@export var type: SlimeType = SlimeType.YELLOW

# Movement Variables
var speed := 60.0
var jump_force := -700.0 # High enough to clear stairs
var gravity := 1600.0
var direction := 1

# Health & Combat
var max_health := 1
var current_health : int
var hit_cooldown := 0.0

@onready var sprite = $Sprite2D
@onready var health_bar = $EnemyHealthBar
@onready var floor_ray = $FloorRay
@onready var wall_ray = $WallRay
@onready var jump_timer = Timer.new()

func _ready():
	# 1. Setup Stats
	setup_slime_stats()
	current_health = max_health
	
	# 2. Health Bar Setup (using the 'Pinned' fix)
	health_bar.setup(max_health)
	health_bar.set_as_top_level(true)
	
	# 3. Setup Random Jump Timer
	add_child(jump_timer)
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	start_random_jump_timer()

func setup_slime_stats():
	match type:
		SlimeType.YELLOW:
			modulate = Color.YELLOW
			speed = 60.0
			jump_force = -700.0
			max_health = 1
		SlimeType.BLUE:
			modulate = Color.CYAN
			speed = 100.0
			jump_force = -850.0 # Jumps very high
			max_health = 2
		SlimeType.PURPLE:
			modulate = Color.PURPLE
			speed = 40.0
			jump_force = -500.0 # Heavy jump
			max_health = 4

func _physics_process(delta):
	# 1. Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# 2. Patrol Logic & Visual Flipping
	if is_on_floor():
		# Check for wall or ledge
		if is_on_wall() or not floor_ray.is_colliding():
			direction *= -1
			
			# Visual Flip: direction 1 is Right, -1 is Left
			# (Assuming your texture faces Right by default)
			sprite.flip_h = (direction == -1) 
			
			# --- CRITICAL: Flip the Rays ---
			# Use abs() to ensure we only flip the sign, not double the distance
			wall_ray.target_position.x = abs(wall_ray.target_position.x) * direction
			floor_ray.position.x = abs(floor_ray.position.x) * direction
			
		velocity.x = direction * speed
	else:
		# Small air resistance - keeps them from flying away too far
		velocity.x = lerp(velocity.x, float(direction * speed), 0.05)

	# 3. Apply Movement
	move_and_slide()
	
	# 4. Update Pinned Health Bar
	# Using the 'Pinned' global position logic to avoid wiggle drift
	if is_instance_valid(health_bar) and health_bar.visible:
		var bar_offset = Vector2(-20, -50) 
		health_bar.global_position = global_position + bar_offset

func start_random_jump_timer():
	# Wait between 2 and 5 seconds for the next jump
	jump_timer.start(randf_range(2.0, 5.0))

func _on_jump_timer_timeout():
	if is_on_floor():
		velocity.y = jump_force
		# Visual feedback for the jump
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
	
	start_random_jump_timer()

func take_damage(amount: int):
	if hit_cooldown > 0: return
	current_health -= amount
	health_bar.update_health(current_health)
	hit_cooldown = 0.4
	
	if current_health <= 0:
		queue_free() # Add your death effects here!
