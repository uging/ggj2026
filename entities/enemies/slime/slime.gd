extends CharacterBody2D

# --- CONFIGURATION ---
enum SlimeType { YELLOW, BLUE, PURPLE }
@export_group("Stats")
@export var type: SlimeType = SlimeType.YELLOW
@export var speed := 60.0
@export var jump_force := -700.0
@export var gravity := 1600.0
@export var damage_amount := 1
@export var knockback_force := 400.0

@export_group("Retreat Behavior")
@export var retreat_speed := 150.0
@export var retreat_time := 1.0 # How long they run away after hitting player

# --- STATE VARIABLES ---
enum State { PATROL, FLEE }
var current_state = State.PATROL
var current_health: int
var max_health := 1
var direction := 1
var hit_cooldown := 0.0
var player_ref: Node2D = null

# --- NODE REFERENCES ---
@onready var sprite = $Sprite2D
@onready var health_bar = $EnemyHealthBar
@onready var floor_ray = $FloorRay
@onready var wall_ray = $WallRay
@onready var jump_timer = Timer.new()
@onready var hurt_box = $HurtBox # Ensure you have an Area2D named HurtBox

# --- LIFECYCLE ---

func _ready() -> void:
	_setup_stats()
	_setup_nodes()
	_connect_signals()

func _physics_process(delta: float) -> void:
	if hit_cooldown > 0:
		hit_cooldown -= delta
		
	_apply_gravity(delta)
	
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.FLEE:
			_process_flee(delta)

	move_and_slide()
	_update_visual_orientation()
	_update_ui_position()

# --- SETUP HELPERS ---

func _setup_stats() -> void:
	match type:
		SlimeType.YELLOW:
			modulate = Color.YELLOW
			speed = 60.0
			max_health = 1
		SlimeType.BLUE:
			modulate = Color.CYAN
			speed = 100.0
			max_health = 2
		SlimeType.PURPLE:
			modulate = Color.PURPLE
			speed = 40.0
			max_health = 4
	
	current_health = max_health
	health_bar.setup(max_health)
	health_bar.set_as_top_level(true)

func _setup_nodes() -> void:
	add_child(jump_timer)
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	_start_random_jump_timer()

func _connect_signals() -> void:
	# Patterned after bee's combat detection
	if hurt_box:
		hurt_box.body_entered.connect(_on_hurt_box_body_entered)

# --- AI & MOVEMENT LOGIC ---

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _process_patrol(delta: float) -> void:
	if is_on_floor():
		# Ledge and Wall detection
		if is_on_wall() or not floor_ray.is_colliding():
			_flip_direction()
			
		var target_velocity = direction * speed
		velocity.x = move_toward(velocity.x, target_velocity, speed * delta * 15.0)
	else:
		velocity.x = lerp(velocity.x, float(direction * speed), 0.05)

func _process_flee(delta: float) -> void:
	# Move away from where the player was
	if player_ref and is_instance_valid(player_ref):
		var dir_away = (global_position.x - player_ref.global_position.x)
		var flee_dir = 1 if dir_away > 0 else -1
		velocity.x = move_toward(velocity.x, flee_dir * retreat_speed, speed * delta * 20.0)
	else:
		_return_to_patrol()

func _flip_direction() -> void:
	direction *= -1
	velocity.x = 0 
	_update_visual_orientation()
	# Update rays
	wall_ray.target_position.x = abs(wall_ray.target_position.x) * direction
	floor_ray.position.x = abs(floor_ray.position.x) * direction

func _return_to_patrol() -> void:
	current_state = State.PATROL
	# Sync direction to current facing to avoid instant snapping back
	direction = -1 if sprite.flip_h else 1

func _start_retreat(target_player: Node2D) -> void:
	player_ref = target_player
	current_state = State.FLEE
	# Retreat for a set time then go back to patrol
	get_tree().create_timer(retreat_time).timeout.connect(_return_to_patrol)

# --- COMBAT & DAMAGE ---

func _on_hurt_box_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	
	# Check for Rock Smash or Aura safety
	var is_aura_active = body.get("is_rock_aura_active") == true
	var is_invincible = body.get("is_invincible") == true
	
	if is_invincible or is_aura_active:
		_start_retreat(body)
		return

	if body.has_method("take_damage"):
		body.take_damage(damage_amount)
		# Push Goma away
		var push_dir = (body.global_position - global_position).normalized()
		body.velocity = push_dir * knockback_force
		# Start Retreat to prevent sticking
		_start_retreat(body)

func take_damage(amount: int) -> void:
	if hit_cooldown > 0: return
	current_health -= amount
	health_bar.update_health(current_health)
	hit_cooldown = 0.2
	
	# Visual flash
	var flash = create_tween()
	flash.tween_property(sprite, "modulate", Color.RED, 0.05)
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	
	if current_health <= 0:
		queue_free()

# --- JUMP LOGIC ---

func _start_random_jump_timer() -> void:
	jump_timer.start(randf_range(2.0, 5.0))

func _on_jump_timer_timeout() -> void:
	if is_on_floor() and current_state == State.PATROL:
		velocity.y = jump_force
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
	_start_random_jump_timer()

# --- VISUALS & UI ---

func _update_visual_orientation() -> void:
	if velocity.x != 0:
		sprite.flip_h = (velocity.x < 0)

func _update_ui_position() -> void:
	if is_instance_valid(health_bar) and health_bar.visible:
		var bar_offset = Vector2(-20, -50) 
		health_bar.global_position = global_position + bar_offset
