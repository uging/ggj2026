extends CharacterBody2D

# --- References ---
@onready var visuals = $Visuals
@onready var goma = $Visuals/Goma
@onready var mask = $Visuals/Mask
@onready var cape = $Visuals/Cape
@onready var smoke = $Visuals/Smoke

# --- Movement & Gummy Stats ---
@export var speed := 460.0
@export var jump_force_base := 400.0
@export var max_jump_multiplier := 1.8
@export var ground_friction_factor := 5.0
@export var gravity := 1500.0
@export var slide_speed := 600.0
@export var wall_slide_speed := 50.0
@export var slope_limit_deg := 30.0


signal health_changed(new_health)
@export var max_health := 10
var current_health := 3  # Starts at 3

var charge_time := 0.0
var is_charging := false
var is_facing_right := false
var current_set_id : int = 1 
var has_mask := true 

# --- Gum Ability Stats ---
var gum_charges := 3
var max_gum_charges := 3
var is_sticking := false
var stick_timer := 0.0
var charge_recovery_timer := 0.0

@export var wall_stick_duration := 0.6  # How long he stays stuck (seconds)
@export var charge_cooldown := 2.0      # Seconds to refill ONE charge

# --- Equipment Sets ---
var equipment_sets = {
	1: { "mask": preload("res://assets/character/mask_default.png"), "cape": preload("res://assets/character/cape_default.png"), "mask_pos": Vector2(-6, -17), "mask_scale": Vector2(0.114, 0.122), "smoke_tex": preload("res://assets/character/smoke_default.png") },
	2: { "mask": preload("res://assets/character/mask_feather.png"), "cape": preload("res://assets/character/cape_feather.png"), "mask_pos": Vector2(-2, -22), "mask_scale": Vector2(0.216, 0.208), "smoke_tex": preload("res://assets/character/smoke_feather.png") },
	3: { "mask": preload("res://assets/character/mask_gum.png"), "cape": preload("res://assets/character/cape_gum.png"), "mask_pos": Vector2(-7, -13), "mask_scale": Vector2(0.134, 0.165), "smoke_tex": preload("res://assets/character/smoke_gum.png") },
	4: { "mask": preload("res://assets/character/mask_rock.png"), "cape": preload("res://assets/character/cape_rock.png"), "mask_pos": Vector2(-7, -14), "mask_scale": Vector2(0.151, 0.132), "smoke_tex": preload("res://assets/character/smoke_rock.png") }
}

func _ready() -> void:
	# Idle Bobbing Logic
	var tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(visuals, "position:y", -5.0, 0.8).as_relative()
	tween.tween_property(visuals, "position:y", 5.0, 0.8).as_relative()

func _physics_process(delta: float) -> void:
	# --- 1. INPUT DETECTION ---
	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	# --- 2. GUM RESOURCE MANAGEMENT (Gum Mask ID 3) ---
	if gum_charges < max_gum_charges:
		charge_recovery_timer += delta
		if charge_recovery_timer >= charge_cooldown:
			gum_charges += 1
			charge_recovery_timer = 0.0
			# print("Gum Charge Refilled! Current: ", gum_charges)

	# --- 3. WALL STICK LOGIC (Gum Mask ID 3 only) ---
	# We check if Goma is touching a wall, in the air, and pushing toward the wall
	if current_set_id == 3 and is_on_wall() and not is_on_floor():
		# Only stick if moving toward the wall or holding a direction
		if abs(input_vector.x) > 0.1:
			if gum_charges > 0 and not is_sticking:
				start_wall_stick()

# --- 4. GRAVITY & STATE HANDLING ---
	if is_sticking:
		# If timer is still active, Goma is stuck perfectly still
		if stick_timer > 0:
			velocity = Vector2.ZERO
			stick_timer -= delta
		else:
			# SLIME MODE: The timer ran out, so slide down slowly
			velocity.y = wall_slide_speed
			# Optional: Slow down horizontal drift if he's sliding off a corner
			velocity.x = 0 
		
		# Visual: Flatten Goma against the wall vertically
		var flip_mult = -1.0 if is_facing_right else 1.0
		visuals.scale.x = 0.7 * flip_mult
		visuals.scale.y = 1.3
		
		# Release if he hits the floor or is no longer touching a wall
		if is_on_floor() or not is_on_wall():
			stop_wall_stick()
	else:
		# Apply normal gravity if not sticking
		if not is_on_floor():
			velocity.y += gravity * delta

	# --- 5. SNAPPY FLIP TRACKER ---
	if input_vector.x > 0: is_facing_right = true
	elif input_vector.x < 0: is_facing_right = false
	var flip_dir = -1.0 if is_facing_right else 1.0
	
	# --- 6. SLOPE SLIDING CALCULATION ---
	var is_on_steep_slope = false
	floor_snap_length = 32.0     # Keep Goma glued to the floor
	floor_constant_speed = true  # Ignore jagged speed changes

	if is_on_floor():
		var floor_normal = get_floor_normal() #
		var floor_angle = rad_to_deg(acos(floor_normal.dot(Vector2.UP))) #
		
		if floor_angle > slope_limit_deg:
					var gum_can_resist = (current_set_id == 3 and gum_charges > 0)
					if not gum_can_resist:
						is_on_steep_slope = true
						
						# Set velocity based on slope direction for a smoother ride
						# We use the X component of the normal to determine direction
						velocity.x = lerp(velocity.x, floor_normal.x * slide_speed, 5 * delta)
						
						# Visual: Match the slope angle smoothly
						visuals.rotation = lerp_angle(visuals.rotation, floor_normal.angle() + PI/2, 10 * delta)

# --- 7. JUMP CHARGING (Floor, Wall, or Sticky) ---
	# We allow charging if on floor, sticking, OR near a wall for non-mask jumping
	var can_jump = is_on_floor() or is_sticking or is_on_wall()
	
	if Input.is_key_pressed(KEY_SPACE) and can_jump:
		is_charging = true
		# Gummy Mask (ID 3) charges much faster
		var charge_speed = 4.0 if current_set_id == 3 else 2.0
		charge_time = min(charge_time + delta * charge_speed, 1.0) 
		
		# Stop sticking so we can aim the jump
		if is_sticking: 
			is_sticking = false 
		
		# Visual Squish
		visuals.scale.y = lerp(visuals.scale.y, 0.75, 10 * delta)
		visuals.scale.x = 1.25 * flip_dir 
		velocity.x = lerp(velocity.x, 0.0, 10 * delta)
	
	elif is_charging:
			# --- 8. PERFORM LAUNCH ---
			var jump_direction = Vector2(input_vector.x, -1.5).normalized()
			
			# WALL KICK: If Goma is touching a wall but not the floor, push him away
			if is_on_wall() and not is_on_floor():
				var wall_normal = get_wall_normal()
				# If the player isn't holding a direction, jump away from the wall automatically
				if input_vector.x == 0:
					jump_direction = (wall_normal + Vector2(0, -1.2)).normalized()
				else:
					# Mix player input with the wall bounce
					jump_direction = (Vector2(input_vector.x, -1.5) + wall_normal * 0.5).normalized()

			var power_boost = 1.8 if current_set_id == 3 else 1.0
			var max_speed_cap = 1300.0 if current_set_id == 3 else 800.0
			
			var final_force = (jump_force_base * (1.0 + charge_time * max_jump_multiplier)) * power_boost
			velocity = jump_direction * min(final_force, max_speed_cap)
			
			apply_launch_stretch(flip_dir)
			charge_time = 0.0
			is_charging = false
	
# --- 9. NORMAL MOVEMENT ---
	if not is_charging and not is_sticking:
		var target_speed = input_vector.x * speed
		
		if is_on_steep_slope:
			# SLIDE CONTROL: Give only 10% influence to player input to stop the "rough" jitter
			# This lets gravity handle the heavy lifting while sliding
			velocity.x = lerp(velocity.x, velocity.x + (target_speed * 0.1), 2 * delta)
		else:
			# NORMAL GROUND/AIR CONTROL:
			# Use 10.0 for snappy floor movement, 3.0 for air drift
			var lerp_weight = 20.0 if is_on_floor() else 3.0
			velocity.x = lerp(velocity.x, target_speed, lerp_weight * delta)
			
			# Only apply the "speed lean" when NOT on a steep slope 
			# (Because on slopes, Section 6 handles the rotation)
			visuals.rotation = lerp(visuals.rotation, velocity.x * 0.0004, 5 * delta)
		
		# Gummy scale effects based on the final velocity
		var stretch_factor = abs(velocity.x) * 0.0001
		visuals.scale.x = (1.0 + stretch_factor) * flip_dir
		visuals.scale.y = lerp(visuals.scale.y, 1.0 - stretch_factor, 10 * delta)

	# --- 10. EXECUTE MOVEMENT & LANDING ---
	var was_in_air = not is_on_floor()
	move_and_slide() #
	
	if was_in_air and is_on_floor():
		apply_landing_squash() #

# --- Helper Functions ---

func change_set(id: int):
	if id == current_set_id: return
	if has_mask and equipment_sets.has(id):
		current_set_id = id
		var new_data = equipment_sets[id] # Fixed Shadowing
		
		smoke.texture = new_data["smoke_tex"]
		smoke.emitting = true
		smoke.restart() #
		
		await get_tree().create_timer(0.1).timeout
		mask.texture = new_data["mask"]
		mask.position = new_data["mask_pos"]
		mask.scale = new_data["mask_scale"]
		cape.texture = new_data["cape"]

func apply_launch_stretch(f_dir: float):
	var tween = create_tween()
	# Stretch tall and thin on takeoff
	tween.tween_property(visuals, "scale", Vector2(0.85 * f_dir, 1.15), 0.1)
	tween.tween_property(visuals, "scale", Vector2(1.0 * f_dir, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC)
	
func apply_landing_squash():
	var tween = create_tween()
	var flip_mult = -1.0 if is_facing_right else 1.0
	
	# 1. Squash down (wider and shorter)
	tween.tween_property(visuals, "scale", Vector2(1.2 * flip_mult, 0.8), 0.1)
	
	# 2. Bounce back to normal size with an elastic "boing"
	tween.tween_property(visuals, "scale", Vector2(1.0 * flip_mult, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: change_set(1)
			KEY_2: change_set(2)
			KEY_3: change_set(3)
			KEY_4: change_set(4)

func start_wall_stick():
	is_sticking = true
	stick_timer = wall_stick_duration
	gum_charges -= 1
	charge_recovery_timer = 0.0 # Reset recovery whenever a charge is used
	print("Stuck! Charges left: ", gum_charges)

func stop_wall_stick():
	is_sticking = false
	# Return to normal scale gummy-style
	apply_landing_squash()


# --- Health Logic ---

func take_damage(amount: int):
	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health) # Notify the UI to remove a heart
	
	# Visual feedback: Flash red
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", Color.RED, 0.1)
	tween.tween_property(visuals, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health) # Notify the UI to add a heart

func die():
	# For now, just reload the scene when health hits 0
	get_tree().reload_current_scene()
