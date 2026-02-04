extends CharacterBody2D

enum State { PATROL, CHASE }

# --- Reusable Stats ---
@export_group("Stats")
@export var speed := 120.0
@export var chase_speed := 180.0
@export var damage_amount := 1
@export var max_health := 2
@export var knockback_force := 500.0

@export_group("Requirements")
# 0 = None, 1 = Feather, 2 = Gum, 4 = Rock (Matches your Set IDs)
@export var required_mask_id : int = 0 

@export_group("Visuals")
@export var texture: Texture2D # Drag your enemy image here in the Inspector

# --- State Variables ---
var current_state = State.PATROL
var player_ref: Node2D = null
var current_health: int
var direction := 1
var hit_cooldown := 0.0

# --- References ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var wall_ray: RayCast2D = $WallRay
@onready var los_ray: RayCast2D = $LOSRay
@onready var hurt_box: Area2D = $HurtBox
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
	# 1. MASK UNLOCK CHECK: If player doesn't have the mask, remove enemy immediately
	if required_mask_id != 0:
		if not _is_mask_unlocked(required_mask_id):
			queue_free()
			return

	# 2. PERSISTENCE CHECK: Check if this enemy was already killed
	var level_name = get_tree().current_scene.name
	var enemy_key = level_name + "_" + name
	if Global.destroyed_enemies.has(enemy_key):
		queue_free()
		return

	# Initialize Stats
	current_health = max_health
	if texture: 
		sprite.texture = texture

	# Connect signals
	hurt_box.body_entered.connect(_on_hurt_box_body_entered)
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	
	start_hover_animation()

# Helper function to check Global dictionary progress
func _is_mask_unlocked(mask_id: int) -> bool:
	match mask_id:
		1: return Global.unlocked_masks["feather"] == true
		2: return Global.unlocked_masks["gum"] == true
		4: return Global.unlocked_masks["rock"] == true
	return true

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

# --- AI & Movement Logic ---

func _process_patrol(_delta: float) -> void:
	if wall_ray.is_colliding():
		direction *= -1
		wall_ray.target_position.x = abs(wall_ray.target_position.x) * direction
		sprite.flip_h = (direction == -1)

	velocity.x = direction * speed
	velocity.y = sin(Time.get_ticks_msec() * 0.005) * 30 

func _process_chase(_delta: float) -> void:
	if player_ref:
		los_ray.target_position = to_local(player_ref.global_position)
		
		if los_ray.is_colliding() and los_ray.get_collider().name != "Player":
			current_state = State.PATROL
			return

		var dir_to_player = global_position.direction_to(player_ref.global_position)
		velocity = velocity.lerp(dir_to_player * chase_speed, 0.05)
		sprite.flip_h = (velocity.x < 0)

func _check_for_player() -> void:
	if player_ref:
		los_ray.target_position = to_local(player_ref.global_position)
		if not los_ray.is_colliding() or los_ray.get_collider().name == "Player":
			current_state = State.CHASE

# --- Combat & Damage Logic ---

func _on_hurt_box_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var is_smashing = body.get("is_rock_smashing") == true
		var is_aura_active = body.get("is_rock_aura_active") == true
		var is_rock_mask = body.get("current_set_id") == 4
		var is_falling_fast = body.velocity.y > 700.0

		if is_smashing or is_aura_active or (is_rock_mask and is_falling_fast):
			take_damage(1)
			if body.has_method("bounce_off_enemy"):
				body.bounce_off_enemy()
			body.velocity.y = -400 
			return
			
		if body.get("is_invincible") == true:
			return

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
	var level_name = get_tree().current_scene.name
	Global.destroyed_enemies[level_name + "_" + name] = true
	
	set_physics_process(false)
	hurt_box.set_deferred("monitoring", false)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", 1.5, 0.2)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	
	await tween.finished
	queue_free()

# --- Visual Animations ---

func start_hover_animation():
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.6).set_trans(Tween.TRANS_SINE)

# --- Signal Listeners ---

func _on_detection_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_ref = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_ref = null
		current_state = State.PATROL
