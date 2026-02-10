extends CharacterBody2D
class_name EnemyBase

# --- CONFIGURATION ---
@export_group("Base Stats")
@export var speed := 120.0
@export var damage_amount := 1
@export var knockback_force := 500.0
@export var max_health := 1
@export var sfx_key: String = "slime"
@export var recovery_speed := 150.0 # Speed at which it flies back up

@export_group("Persistence")
@export var persistence_enabled := true

# --- STATE VARIABLES ---
var current_health: int
var hit_cooldown := 0.0
var is_dead := false
var home_y: float # Original height
var is_recovering := false # Whether we are currently flying back up

# --- NODE REFERENCES ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar = $EnemyHealthBar
@onready var hurt_box: Area2D = $HurtBox

# --- LIFECYCLE ---

func _ready() -> void:
	# Store the starting height for recovery
	home_y = global_position.y 
	
	if persistence_enabled and _check_already_destroyed():
		queue_free()
		return

	current_health = max_health
	if is_instance_valid(health_bar):
		health_bar.setup(max_health)
	
	_connect_base_signals()

func _physics_process(delta: float) -> void:
	if hit_cooldown > 0:
		hit_cooldown -= delta
	
	# RECOVERY LOGIC: Move back to original height if knocked down
	if is_recovering and not is_dead:
		if global_position.y > home_y:
			# Move upward toward home_y
			velocity.y = -recovery_speed
		else:
			# Snap to home and stop recovery
			velocity.y = 0
			global_position.y = home_y
			is_recovering = false

# --- SETUP HELPERS ---

func _connect_base_signals() -> void:
	if hurt_box:
		if not hurt_box.body_entered.is_connected(_on_hurt_box_body_entered):
			hurt_box.body_entered.connect(_on_hurt_box_body_entered)

func _check_already_destroyed() -> bool:
	var enemy_key = _get_unique_key()
	return Global.destroyed_enemies.has(enemy_key)

func _get_unique_key() -> String:
	var level_name = get_tree().current_scene.name
	return level_name + "_" + name

# --- UNIVERSAL COMBAT LOGIC ---

func _on_hurt_box_body_entered(body: Node2D) -> void:
	if is_dead or not body.is_in_group("player"): return

	var is_falling = body.velocity.y > 0 
	var is_above = body.global_position.y < (global_position.y + 25)
	var is_smashing = body.get("is_rock_smashing") == true
	var is_air_jump_stomp = body.get("air_jump_stomp_timer") > 0

	if (is_falling and is_above) or is_smashing or (is_air_jump_stomp and is_above):
		# --- SUCCESSFUL STOMP ---
		if is_air_jump_stomp:
			body.set("air_jump_stomp_timer", 0.0)
		
		# 1. Trigger Hit Stop
		if body.has_method("trigger_hit_stop"):
			body.trigger_hit_stop(0.1, 0.1)
		
		# 2. Damage & Jolt Downward
		take_damage(1)
		velocity.y = 400.0 # The "Pushed away" jolt
		is_recovering = true 
		
		# 3. Bounce Player
		if body.has_method("bounce_off_enemy"):
			var force = -700.0 if body.get("current_set_id") == 4 else -500.0
			body.bounce_off_enemy(force, global_position)
	else:
		# --- FAILED STOMP ---
		if not body.get("is_invincible") and body.has_method("take_damage"):
			body.take_damage(damage_amount)
			var push_dir = (body.global_position - global_position).normalized()
			body.velocity = push_dir * 500.0
			if has_method("_start_retreat"):
				call("_start_retreat", body)

# --- DAMAGE & DEATH ---

func take_damage(amount: int) -> void:
	if hit_cooldown > 0 or is_dead: 
		return
	
	current_health -= amount
	hit_cooldown = 0.4
	
	if health_bar: health_bar.update_health(current_health)
	GlobalAudioManager.play_enemy_hurt(sfx_key)
	
	var flash = create_tween()
	flash.tween_property(sprite, "modulate", Color.RED, 0.05)
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	
	if current_health <= 0:
		die()

func die() -> void:
	if is_dead: return
	is_dead = true
	
	if persistence_enabled:
		Global.destroyed_enemies[_get_unique_key()] = true
	
	set_physics_process(false)
	if hurt_box: hurt_box.set_deferred("monitoring", false)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()
