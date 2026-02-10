extends EnemyBase

# --- CONFIGURATION ---
@export_group("Stats")
# 'speed' is inherited from EnemyBase (120.0)
@export var chase_speed := 180.0
@export var detection_radius := 200.0
@export var leash_distance := 400.0 

@export_group("Movement Behavior")
@export var wave_frequency := 0.005 
@export var wave_amplitude := 30.0  

@export_group("Requirements & Persistence")
## 0=None, 1=Ninja, 2=Feather, 3=Gum, 4=Rock
@export var required_mask_id : int = 3 

@export_group("Visuals")
@export var texture: Texture2D

@export_group("Retreat Behavior")
@export var retreat_speed := 220.0
@export var retreat_time := 1.5 

# --- STATE VARIABLES ---
var current_state = State.PATROL
var direction := 1
var home_position : Vector2
var player_ref: Node2D = null

enum State { PATROL, CHASE, FLEE }

# --- NODE REFERENCES ---
@onready var wall_ray: RayCast2D = $WallRay
@onready var los_ray: RayCast2D = $LOSRay
@onready var detection_area: Area2D = $DetectionArea

# --- LIFECYCLE ---

func _ready() -> void:
	# 1. Run Base Setup (Signals & Health)
	super._ready()
	
	# 2. Bee Specific Setup
	_setup_nodes()
	_setup_detection_radius()
	
	await get_tree().process_frame
	
	if not _check_spawn_requirements():
		return

	if texture: sprite.texture = texture
	
	_connect_bee_signals()
	start_hover_animation()

func _physics_process(delta: float) -> void:
	# Run hit_cooldown timer from EnemyBase
	super._physics_process(delta)

	match current_state:
		State.PATROL:
			_process_patrol(delta)
			_check_for_player()
		State.CHASE:
			_process_chase(delta)
		State.FLEE:
			_process_flee()

	move_and_slide()
	_update_visual_orientation()

# --- VISUAL HELPERS ---

func _update_visual_orientation() -> void:
	if current_state == State.PATROL:
		sprite.flip_h = (direction == -1)
	else:
		if player_ref and is_instance_valid(player_ref):
			sprite.flip_h = (player_ref.global_position.x < global_position.x)

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

func _connect_bee_signals() -> void:
	# HurtBox is already connected by super._ready()
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)

func _check_spawn_requirements() -> bool:
	# Original check logic
	if required_mask_id != 0 and not _is_mask_unlocked_internal(required_mask_id):
		queue_free()
		return false
	
	if persistence_enabled:
		var enemy_key = get_tree().current_scene.name + "_" + name
		if Global.destroyed_enemies.has(enemy_key):
			queue_free()
			return false
	return true

func _is_mask_unlocked_internal(mask_id: int) -> bool:
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

	velocity.x = direction * speed
	velocity.y = sin(Time.get_ticks_msec() * wave_frequency) * wave_amplitude
	home_position = global_position

func _process_chase(_delta: float) -> void:
	if not player_ref or global_position.distance_to(home_position) > leash_distance:
		_return_to_patrol()
		return

	los_ray.target_position = to_local(player_ref.global_position)
	los_ray.force_raycast_update()

	if los_ray.is_colliding():
		var collider = los_ray.get_collider()
		if collider != player_ref and not collider.is_in_group("player"):
			_return_to_patrol()
			return

	var dir_to_player = global_position.direction_to(player_ref.global_position)
	velocity = velocity.lerp(dir_to_player * chase_speed, 0.1)

func _check_for_player() -> void:
	if player_ref and is_instance_valid(player_ref):
		los_ray.target_position = to_local(player_ref.global_position)
		los_ray.force_raycast_update()

		if not los_ray.is_colliding() or los_ray.get_collider() == player_ref or los_ray.get_collider().is_in_group("player"):
			current_state = State.CHASE

func _return_to_patrol() -> void:
	direction = -1 if sprite.flip_h else 1
	player_ref = null
	current_state = State.PATROL

func _process_flee() -> void:
	if player_ref:
		var dir_away = (global_position - player_ref.global_position).normalized()
		velocity = velocity.lerp(dir_away * retreat_speed, 0.1)
	else:
		_return_to_patrol()

# Called by EnemyBase automatically
func _start_retreat(target_player: Node2D = null) -> void:
	if target_player: player_ref = target_player
	current_state = State.FLEE
	get_tree().create_timer(retreat_time).timeout.connect(_return_to_patrol)

# --- OVERRIDES ---

func die():
	if is_dead: return
	is_dead = true
	
	if persistence_enabled:
		var enemy_key = get_tree().current_scene.name + "_" + name
		Global.destroyed_enemies[enemy_key] = true
	
	set_physics_process(false)
	if hurt_box: hurt_box.set_deferred("monitoring", false)
	
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
	if body.is_in_group("player"):
		player_ref = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player_ref:
		if global_position.distance_to(player_ref.global_position) > detection_radius:
			_return_to_patrol()
