extends EnemyBase

# --- CONFIGURATION ---
enum SlimeType { YELLOW, BLUE, PURPLE }
@export_group("Slime Settings")
@export var type: SlimeType = SlimeType.YELLOW
@export var jump_force_base := -700.0 # Renamed to avoid conflict during setup
@export var gravity := 1600.0

@export_group("Retreat Behavior")
@export var retreat_speed_slime := 150.0
@export var retreat_time_slime := 1.0 

# --- STATE VARIABLES ---
enum State { PATROL, FLEE }
var current_state = State.PATROL
var direction := 1
var player_ref: Node2D = null

# --- NODE REFERENCES ---
@onready var floor_ray = $FloorRay
@onready var wall_ray = $WallRay
@onready var jump_timer = Timer.new()

# --- LIFECYCLE ---

func _ready() -> void:
	# 1. Run Base Setup (Handles health_bar initialization and signals)
	super._ready()
	
	# 2. Slime Specific Setup
	_setup_slime_stats()
	_setup_jump_logic()

func _physics_process(delta: float) -> void:
	# Run hit_cooldown timer logic from EnemyBase
	super._physics_process(delta)
	
	_apply_gravity(delta)
	
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.FLEE:
			_process_flee(delta)

	move_and_slide()
	
	# Visuals & UI
	_update_visual_orientation()
	_update_ui_position()

# --- SETUP HELPERS ---

func _setup_slime_stats() -> void:
	# SFX key for the audio manager
	sfx_key = "slime"
	
	match type:
		SlimeType.YELLOW:
			modulate = Color.YELLOW
			speed = 60.0
			jump_force_base = -700.0
			max_health = 1
		SlimeType.BLUE:
			modulate = Color.CYAN
			speed = 100.0
			jump_force_base = -850.0 
			max_health = 2
		SlimeType.PURPLE:
			modulate = Color.PURPLE
			speed = 40.0
			jump_force_base = -500.0 
			max_health = 4
	
	# Sync Base variables with these type-specific stats
	current_health = max_health
	if health_bar:
		health_bar.setup(max_health)
		health_bar.set_as_top_level(true) # Kept from original

func _setup_jump_logic() -> void:
	if not jump_timer.get_parent():
		add_child(jump_timer)
	if not jump_timer.timeout.is_connected(_on_jump_timer_timeout):
		jump_timer.timeout.connect(_on_jump_timer_timeout)
	_start_random_jump_timer()

# --- MOVEMENT LOGIC ---

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _process_patrol(delta: float) -> void:
	if is_on_floor():
		# Ledge and Wall detection
		if is_on_wall() or not floor_ray.is_colliding():
			_flip_direction()
			
		var target_velocity = direction * speed
		# Smooth acceleration from your original script
		velocity.x = move_toward(velocity.x, target_velocity, speed * delta * 15.0)
	else:
		# Air control from your original script
		velocity.x = lerp(velocity.x, float(direction * speed), 0.05)

func _process_flee(delta: float) -> void:
	if player_ref and is_instance_valid(player_ref):
		# Calculate flee direction based on player position
		var dir_away = 1 if (global_position.x - player_ref.global_position.x) > 0 else -1
		velocity.x = move_toward(velocity.x, dir_away * retreat_speed_slime, speed * delta * 20.0)
	else:
		_return_to_patrol()

# --- UTILITIES ---

func _flip_direction() -> void:
	direction *= -1
	velocity.x = 0 
	_update_visual_orientation()
	# Update rays to match new direction
	wall_ray.target_position.x = abs(wall_ray.target_position.x) * direction
	floor_ray.position.x = abs(floor_ray.position.x) * direction

# Called by EnemyBase automatically
func _start_retreat(target_player: Node2D) -> void:
	player_ref = target_player
	current_state = State.FLEE
	# Retreat timer from original
	get_tree().create_timer(retreat_time_slime).timeout.connect(_return_to_patrol)

func _return_to_patrol() -> void:
	current_state = State.PATROL
	# Sync direction to current facing to avoid instant snapping back
	direction = -1 if sprite.flip_h else 1

func _on_jump_timer_timeout() -> void:
	if is_on_floor() and current_state == State.PATROL:
		velocity.y = jump_force_base
		# Squash and stretch visuals from original
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
	_start_random_jump_timer()

func _start_random_jump_timer() -> void:
	jump_timer.start(randf_range(2.0, 5.0))

func _update_visual_orientation() -> void:
	if velocity.x != 0:
		sprite.flip_h = (velocity.x < 0)

func _update_ui_position() -> void:
	if is_instance_valid(health_bar) and health_bar.visible:
		var bar_offset = Vector2(-20, -50) 
		health_bar.global_position = global_position + bar_offset
