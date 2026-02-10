extends Area2D

# --- CONFIGURATION ---
@export_group("Trap Stats")
@export var damage_amount := 1
@export var knockback_force := 500.0
@export var trap_health := 1 
@export var sfx_key: String = "spike" # Set to "plant" in the Inspector for Plant Traps

# --- STATE VARIABLES ---
var current_health: int
var hit_cooldown := 0.0

# --- NODE REFERENCES ---
@onready var health_bar = $EnemyHealthBar

# --- LIFECYCLE ---

func _ready() -> void:
	# 1. PERSISTENCE CHECK: Check if this specific trap was already broken
	var level_name = get_tree().current_scene.name
	var enemy_key = level_name + "_" + name
	if Global.destroyed_enemies.has(enemy_key):
		queue_free()
		return 
		
	# 2. SETUP
	current_health = trap_health
	if health_bar: 
		health_bar.setup(trap_health)

	# 3. SIGNAL CONNECTION
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Handle internal hit cooldown
	if hit_cooldown > 0:
		hit_cooldown -= delta
		
	# CONTINUOUS CHECK: Allows Goma to break the trap by smashing into it 
	# even if he was already overlapping with it.
	if not monitoring: return

	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			var is_smashing = body.get("is_rock_smashing") == true
			var is_falling_fast = body.velocity.y > 700.0
			
			if is_smashing or is_falling_fast:
				take_damage(1)

# --- COMBAT LOGIC ---

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or current_health <= 0: return
	
	var is_smashing = body.get("is_rock_smashing") == true
	var is_falling_fast = body.velocity.y > 700.0

	# SUCCESS: Goma breaks the trap
	if is_smashing or is_falling_fast:
		take_damage(1)
		if body.has_method("bounce_off_enemy"):
			body.bounce_off_enemy(-600.0)
	
	# FAILURE: Trap hurts Goma
	else:
		if not body.get("is_invincible") and body.has_method("take_damage"):
			body.take_damage(damage_amount)
			# Knock Goma back away from the spike center
			var push_dir = (body.global_position - global_position).normalized()
			body.velocity = push_dir * knockback_force

func take_damage(amount: int) -> void:
	if hit_cooldown > 0: return
	
	current_health -= amount
	hit_cooldown = 0.4
	
	if health_bar: 
		health_bar.update_health(current_health)
	
	GlobalAudioManager.play_enemy_hurt(sfx_key)
	
	if current_health <= 0:
		break_trap()

func break_trap() -> void:
	# RECORD DEATH: Save to persistence so it stays gone
	var level_name = get_tree().current_scene.name
	Global.destroyed_enemies[level_name + "_" + name] = true
	
	monitoring = false 
	monitorable = false
	
	# Visual "shatter" animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	
	await tween.finished
	queue_free()
