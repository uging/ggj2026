extends CharacterBody2D

enum State { PATROL, CHASE }

# --- CONFIGURATION ---
@export_group("Stats")
@export var speed := 120.0
@export var chase_speed := 180.0
@export var damage_amount := 1
@export var max_health := 2
@export var knockback_force := 500.0
@export var detection_radius := 200.0
@export var leash_distance := 400.0 

@export_group("Movement Behavior")
@export var wave_frequency := 0.005 # How fast they bob
@export var wave_amplitude := 30.0  # How far they bob

@export_group("Requirements & Persistence")
@export var persistence_enabled := false
## 0=None, 1=Ninja, 2=Feather, 3=Gum, 4=Rock
@export var required_mask_id : int = 3 

@export_group("Visuals")
@export var texture: Texture2D

# --- STATE VARIABLES ---
var current_state = State.PATROL
var current_health: int
var direction := 1
var hit_cooldown := 0.0
var home_position : Vector2
var player_ref: Node2D = null

# --- NODE REFERENCES ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var wall_ray: RayCast2D = $WallRay
@onready var los_ray: RayCast2D = $LOSRay
@onready var hurt_box: Area2D = $HurtBox
@onready var detection_area: Area2D = $DetectionArea

# --- LIFECYCLE ---

func _ready() -> void:
	_setup_nodes()
	_setup_detection_radius()
	
	# Wait for Global/Scene to settle
	await get_tree().process_frame
	
	if not _check_spawn_requirements():
		return

	# Init stats
	current_health = max_health
	if texture: sprite.texture = texture
	
	_connect_signals()
	start_hover_animation()

func _physics_process(delta: float) -> void:
	if hit_cooldown > 0: 
		hit_cooldown -= delta

	match current_state:
		State.PATROL:
			_process_patrol(delta)
			_check_for_player()
		State.CHASE:
			_process_chase(delta)

	move_and_slide()

# --- SETUP HELPERS ---

func _setup_nodes() -> void:
	los_ray.add_exception(self)
	home_position = global_position

func _setup_detection_radius() -> void:
	var shape_node = $DetectionArea/CollisionShape2D
	if shape_node.shape:
		shape_node.shape = shape_node.shape.duplicate()
		if shape_node.shape is CircleShape2D:
			shape_node.shape.radius = detection_radius

func _connect_signals() -> void:
	hurt_box.body_entered.connect(_on_hurt_box_body_entered)
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)

func _check_spawn_requirements() -> bool:
	# 1. Mask Check
	if required_mask_id != 0 and not _is_mask_unlocked(required_mask_id):
		queue_free()
		return false
	
	# 2. Persistence Check
	if persistence_enabled:
		var enemy_key = get_tree().current_scene.name + "_" + name
		if Global.destroyed_enemies.has(enemy_key):
			queue_free()
			return false
			
	return true

func _is_mask_unlocked(mask_id: int) -> bool:
	match mask_id:
		2: return Global.unlocked_masks.get("feather", false)
		3: return Global.unlocked_masks.get("gum", false)
		4: return Global.unlocked_masks.get("rock", false)
	return true

# --- AI LOGIC ---

func _process_patrol(_delta: float) -> void:
	if wall_ray.is_colliding():
		direction *= -1
		wall_ray.target_position.x = abs(wall_ray.target_position.x) * direction
		sprite.flip_h = (direction == -1)

	velocity.x = direction * speed
	velocity.y = sin(Time.get_ticks_msec() * wave_frequency) * wave_amplitude

func _process_chase(_delta: float) -> void:
	if not player_ref or global_position.distance_to(home_position) > leash_distance:
		_return_to_patrol()
		return

	# Update LOS
	los_ray.target_position = to_local(player_ref.global_position)
	los_ray.force_raycast_update()

	if los_ray.is_colliding() and los_ray.get_collider().name != "Player":
		_return_to_patrol()
		return

	var dir_to_player = global_position.direction_to(player_ref.global_position)
	velocity = velocity.lerp(dir_to_player * chase_speed, 0.05)
	sprite.flip_h = (velocity.x < 0)

func _check_for_player() -> void:
	if player_ref:
		los_ray.target_position = to_local(player_ref.global_position)
		los_ray.force_raycast_update()

		if not los_ray.is_colliding() or los_ray.get_collider().name == "Player":
			current_state = State.CHASE

func _return_to_patrol() -> void:
	player_ref = null
	current_state = State.PATROL

# --- COMBAT & DAMAGE ---

func _on_hurt_box_body_entered(body: Node2D) -> void:
	if body.name != "Player": return
	
	# Check for Player "Attack" States
	var is_smashing = body.get("is_rock_smashing") == true
	var is_aura_active = body.get("is_rock_aura_active") == true
	var is_rock_mask = body.get("current_set_id") == 4
	var is_falling_fast = body.velocity.y > 700.0

	if is_smashing or is_aura_active or (is_rock_mask and is_falling_fast):
		take_damage(1)
		if body.has_method("bounce_off_enemy"): body.bounce_off_enemy()
		body.velocity.y = -400 
		return
			
	if body.get("is_invincible"): return

	if body.has_method("take_damage"):
		body.take_damage(damage_amount)
		var push_dir = (body.global_position - global_position).normalized()
		body.velocity = push_dir * knockback_force

func take_damage(amount: int):
	if hit_cooldown > 0: return
	
	current_health -= amount
	hit_cooldown = 0.4
	
	var flash = create_tween()
	flash.tween_property(sprite, "modulate", Color.RED, 0.05)
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	
	if current_health <= 0:
		die()

func die():
	if persistence_enabled:
		var enemy_key = get_tree().current_scene.name + "_" + name
		Global.destroyed_enemies[enemy_key] = true
	
	set_physics_process(false)
	hurt_box.set_deferred("monitoring", false)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", 1.5, 0.2)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()

# --- VISUALS ---

func start_hover_animation():
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.6).set_trans(Tween.TRANS_SINE)

# --- SIGNALS ---

func _on_detection_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_ref = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_return_to_patrol()
