extends EnemyBase

# --- CONFIGURATION ---
@export_group("Snail Movement")
@export var idle_time_snail := 2.0 

# --- STATE VARIABLES ---
enum State { PATROL, FLEE }
var current_state = State.PATROL
var direction := 1 
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var turn_cooldown := 0.0

# --- NODE REFERENCES ---
@onready var floor_ray: RayCast2D = $FloorRay
@onready var wall_ray: RayCast2D = $WallRay

# --- LIFECYCLE ---

func _ready() -> void:
	# 1. Custom Persistence Logic (Preserving your unique position-based key)
	var level_path = get_tree().current_scene.scene_file_path
	var enemy_key = level_path + "_" + str(global_position)
	
	if Global.destroyed_enemies.has(enemy_key):
		queue_free()
		return

	# 2. Run Base Setup (Signals, health_bar setup)
	super._ready()
	
	# 3. Snail Specifics
	sfx_key = "snail"
	start_crawling_animation()

func _physics_process(delta: float) -> void:
	# Run EnemyBase cooldown timer
	super._physics_process(delta)
	
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.FLEE:
			_process_flee(delta)

	move_and_slide()

# --- MOVEMENT LOGIC ---

func _process_patrol(delta: float) -> void:
	if turn_cooldown > 0:
		turn_cooldown -= delta

	if is_on_floor() and turn_cooldown <= 0:
		# Ledge and Wall detection
		if not floor_ray.is_colliding() or wall_ray.is_colliding():
			_flip_snail()

	velocity.x = direction * speed

func _process_flee(_delta: float) -> void:
	# Snail stops and idles when in FLEE state
	velocity.x = move_toward(velocity.x, 0, speed * 0.1)

# --- STATE TRANSITIONS ---

# Called by EnemyBase when Goma stomps or hits from the side
func _start_retreat(_player: Node2D = null) -> void:
	if current_state == State.FLEE: return
	
	current_state = State.FLEE
	
	# Squash visual for the "idle/hide" state
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.1)
	
	get_tree().create_timer(idle_time_snail).timeout.connect(_return_to_patrol)

func _return_to_patrol() -> void:
	current_state = State.PATROL
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)

# --- UTILITIES ---

func _flip_snail() -> void:
	direction *= -1
	sprite.flip_h = (direction == 1)
	# Preserved your exact raycast offsets
	floor_ray.position.x = 18 * direction 
	wall_ray.target_position.x = abs(wall_ray.target_position.x) * direction
	turn_cooldown = 0.2

func start_crawling_animation():
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.5)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.5)

# --- OVERRIDES ---

# Overriding the die function to keep your specific "crushed" animation
func die() -> void:
	if is_dead: return
	is_dead = true
	
	# Save death state using your unique position-based key
	var level_path = get_tree().current_scene.scene_file_path
	var enemy_key = level_path + "_" + str(global_position)
	Global.destroyed_enemies[enemy_key] = true
	
	set_physics_process(false)
	if hurt_box:
		hurt_box.set_deferred("monitoring", false)
		hurt_box.set_deferred("monitorable", false)
	
	# Your original flattened scale animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 0.1), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	
	await tween.finished
	queue_free()
