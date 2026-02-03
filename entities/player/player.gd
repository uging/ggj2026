extends CharacterBody2D

@export var is_top_down := false # Enable this in the Inspector for your Main Scene

# --- References ---
@onready var visuals = $Visuals
@onready var goma = $Visuals/Goma
@onready var mask = $Visuals/Mask
@onready var cape = $Visuals/Cape
@onready var smoke = $Visuals/Smoke

# --- Ability UI References ---
@onready var ability_ui = $AbilityUI
@onready var ability_container = $AbilityUI/HBoxContainer
var ability_icons = [] # This will hold your 3 progress bars
@onready var feather_particles = $Visuals/FeatherParticles
@onready var shockwave_particles = $Visuals/ShockwaveParticles

var ability_textures = {
	2: { "p": preload("res://entities/player/assets/bar_feather.png"), "u": preload("res://entities/player/assets/bar_feather_dim.png") },
	3: { "p": preload("res://entities/player/assets/bar_gum.png"),     "u": preload("res://entities/player/assets/bar_gum_dim.png") },
	4: { "p": preload("res://entities/player/assets/bar_rock.png"),    "u": preload("res://entities/player/assets/bar_rock_dim.png") }
}

# --- Ability UI vars ---
var ui_fade_timer := 0.0
@export var ui_display_time := 2.5 # How long it stays visible after use/refill

# --- Movement & Gummy Stats ---
@export var speed := 460.0
@export var jump_force_base := 320.0
@export var max_jump_multiplier := 1.5
@export var ground_friction_factor := 5.0
@export var gravity := 1600.0
@export var slide_speed := 600.0
@export var slope_limit_deg := 30.0
@export var coyote_time_duration := 0.15 # 0.1 to 0.2 is the "sweet spot"
var coyote_timer := 0.0 # so jumps feel a bit more forgiving when Goma runs off a ledge

# --- Wall Scaling Logic ---
@export var wall_rejump_window := 0.20  # Time allowed to re-kick same wall
var wall_rejump_timer := 0.0
var last_wall_normal := Vector2.ZERO

# --- Gum Ability Stats ---
@export var super_jump_mult := 2.0      # How much higher the super jump goes
var is_super_charging := false
@export var charge_cooldown := 2.0      # Seconds to refill ONE charge
var wall_kick_boost_timer := 0.0
@export var wall_kick_boost_duration := 0.25 

# --- Feather Ability Stats ---
var feather_charges := 3
var max_feather_charges := 3
@export var glide_gravity_mult := 0.03  # Lower = Lighter (was 0.15)
@export var glide_max_fall_speed := 80.0 # Lower = Slower descent (was 150.0)
@export var glide_horizontal_speed := 300.0 # Higher = More zip while gliding
var is_gliding := false

# --- Rock Ability Stats ---
@export var rock_gravity_mult := 1.8     # Makes him fall faster/heavier
@export var rock_speed_mult := 0.85       # Makes him walk slower
@export var rock_smash_fall_speed := 1200.0 # High-speed descent
var is_rock_smashing := false

signal health_changed(new_health)
@export var max_health := 10
var current_health := 3  # Starts at 3
var is_invincible := false
@export var invincibility_duration := 1.5 # Seconds of safety

var charge_time := 0.0
var is_charging := false
var is_facing_right := true
var current_set_id : int = 1 
var has_mask := false
var last_ability_press_time := 0.0

# --- Active Ability Resources (Generic) ---
var ability_charges := 3.0
var max_ability_charges := 3.0
var charge_recovery_timer := 0.0

var unlocked_masks = Global.unlocked_masks

# --- Equipment Sets ---
var equipment_sets = {
	1: { 
		"mask": preload("res://entities/player/assets/mask_default.png"), 
		"cape": preload("res://entities/player/assets/cape_default.png"), 
		"mask_pos": Vector2(7, -17),
		"mask_scale": Vector2(0.114, 0.122)
	},
	2: { 
		"mask": preload("res://entities/player/assets/mask_feather.png"), 
		"cape": preload("res://entities/player/assets/cape_feather.png"), 
		"mask_pos": Vector2(6, -20),
		"mask_scale": Vector2(0.214, 0.239)
	},
	3: { 
		"mask": preload("res://entities/player/assets/mask_gum.png"), 
		"cape": preload("res://entities/player/assets/cape_gum.png"), 
		"mask_pos": Vector2(10.56, -12.632),
		"mask_scale": Vector2(0.14, 0.151)
	},
	4: { 
		"mask": preload("res://entities/player/assets/mask_rock.png"), 
		"cape": preload("res://entities/player/assets/cape_rock.png"), 
		"mask_pos": Vector2(10, -16),
		"mask_scale": Vector2(0.16, 0.135)
	}
}

func _ready() -> void:
	# Reset status in case the engine reused memory
	is_dying = false
	process_mode = PROCESS_MODE_INHERIT 
	show()
	
	# Idle Bobbing Logic
	var tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(visuals, "position:y", -5.0, 0.8).as_relative()
	tween.tween_property(visuals, "position:y", 5.0, 0.8).as_relative()
	
	# Update the HUD right away when Goma is born
	health_changed.emit(current_health)
	masks_updated.emit(unlocked_masks)
	
	if ability_container:
		# This grabs TextureProgressBar, TextureProgressBar2, and TextureProgressBar3
		ability_icons = ability_container.get_children()
		
	# Force the camera to be the active one as soon as Goma hits the stage
	if has_node("Camera2D"):
		$Camera2D.make_current()

func _physics_process(delta: float) -> void:
# --- 1. BASIC INPUT & DIRECTION ---
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

# Only update facing direction if we ARE NOT rock smashing
	if not is_rock_smashing:
		if input_vector.x > 0: 
			is_facing_right = true  
		elif input_vector.x < 0: 
			is_facing_right = false 

	# Character naturally faces RIGHT. 
	# side = 1.0 (Normal/Right), side = -1.0 (Flipped/Left)
	var side = 1.0 if is_facing_right else -1.0

# --- 2. RESOURCE REGEN ---
	var is_using_ability = is_gliding or is_charging or is_rock_smashing
	if ability_charges < max_ability_charges and not is_using_ability:
		charge_recovery_timer += delta
		if charge_recovery_timer >= charge_cooldown:
			ability_charges = min(ability_charges + 1, max_ability_charges)
			charge_recovery_timer = 0.0
			update_ability_visuals()

# --- 3. MOVEMENT LOGIC ---
	if is_top_down:
		velocity = velocity.lerp(input_vector * speed, 15.0 * delta)
		visuals.rotation = lerp_angle(visuals.rotation, 0.0, 10.0 * delta)
	else:
		var is_near_wall = is_on_wall() or wall_rejump_timer > 0
		var can_jump = (coyote_timer > 0) or is_near_wall

		# Ability Press (Single Hits)
		if Input.is_action_just_pressed("ability"):
			var current_time = Time.get_ticks_msec() / 1000.0
			
			# Rock Smash (Double Tap/Fast Press)
			if current_set_id == 4 and not is_on_floor() and current_time - last_ability_press_time < 0.3:
				if ability_charges >= 1.0: trigger_rock_smash()
			
			# --- Shared Air Jump Logic ---
			elif (current_set_id == 3 or current_set_id == 2) and not is_on_floor() and not is_near_wall:
				if ability_charges >= 1.0:
					ability_charges -= 1.0
					# Pass a multiplier: Gum (3) is 2.5, Feather (2) is 1.5
					var jump_power = 2.5 if current_set_id == 3 else 1.5
					perform_air_jump(jump_power)
					
			last_ability_press_time = current_time

		# Ability Held (Charging or Gliding)
		if Input.is_action_pressed("ability"):
			if can_jump and not is_rock_smashing:
				# --- CHARGING LOGIC ---
				is_charging = true
				var charge_speed = 4.5 if current_set_id == 3 else 2.5
				charge_time = min(charge_time + delta * charge_speed, 1.0)
				coyote_timer = 0
				visuals.scale.y = lerp(visuals.scale.y, 0.6, 10 * delta)
				velocity.x = lerp(velocity.x, 0.0, 10 * delta)
				if charge_time > 0.7: 
					is_super_charging = (current_set_id == 3)
					visuals.position.x = randf_range(-1, 1)
			
			# --- GLIDING LOGIC ---
			elif not is_on_floor() and current_set_id == 2 and ability_charges > 0:
				# 1. The "Peak" check: Only allow glide if falling or at the top of a jump
				if velocity.y > -150: 
					# 2. The Zelda "Catch"
					if not is_gliding:
						velocity.y = min(velocity.y, 10.0)
					
					process_feather_glide(delta, input_vector)
				else:
					# We are still moving UP too fast from a jump, don't glide yet
					is_gliding = false
					feather_particles.emitting = false
		else:
			is_gliding = false
			feather_particles.emitting = false

		# Ability Release
		if Input.is_action_just_released("ability"):
			if is_charging: execute_jump_launch(side, input_vector)
			is_gliding = false
			feather_particles.emitting = false

		# --- GRAVITY CALCULATIONS ---
		if not is_on_floor():
			coyote_timer -= delta
			var gravity_step = gravity
			
			if current_set_id == 4: # Rock logic
				gravity_step *= rock_gravity_mult
			elif current_set_id == 2: # Feather logic
				# The player only gets the gravity buff if they have charges AND are gliding
				if is_gliding and ability_charges > 0:
					gravity_step *= glide_gravity_mult
				else:
					gravity_step *= 0.7 # Normal feather weightlessness (no glide)

			velocity.y += gravity_step * delta
			
			if is_gliding and velocity.y > glide_max_fall_speed:
				velocity.y = glide_max_fall_speed
		else:
			coyote_timer = coyote_time_duration
			if velocity.y > 0:
				velocity.y = 0

		# --- HORIZONTAL MOVEMENT ---
		if not is_charging and not is_rock_smashing:
			var move_speed = speed
			if current_set_id == 4: 
				move_speed *= rock_speed_mult
				if is_on_floor() and input_vector.x != 0: move_speed *= 1.4 
			
			if is_gliding and ability_charges > 0: # Only zip if we have fuel
				velocity.x = lerp(velocity.x, input_vector.x * glide_horizontal_speed, 8.0 * delta)
			else:
				velocity.x = lerp(velocity.x, input_vector.x * move_speed, 15.0 * delta)

# --- 4. EXECUTION & VISUALS ---
	if is_rock_smashing:
		velocity.x = 0

	move_and_slide()

	if not is_top_down:
		handle_landing_logic()
		
# VISUAL OVERRIDE
		if is_rock_smashing:
			visuals.scale.x = side * 0.8
			visuals.scale.y = lerp(visuals.scale.y, 1.4, 15 * delta)
			visuals.rotation = 0 
		elif is_gliding:
			visuals.scale.x = side
			visuals.scale.y = 1.0
		elif is_charging:
			visuals.scale.y = lerp(visuals.scale.y, 0.6, 10 * delta)
			visuals.scale.x = side 
		else:
			# Normal movement juice
			var stretch_factor = abs(velocity.x) * 0.0001
			visuals.scale.y = lerp(visuals.scale.y, 1.0 - (stretch_factor * 0.5), 10 * delta)
			visuals.scale.x = side * (1.0 + stretch_factor)
			# Rotation: Now naturally tilts forward based on velocity without extra side-inversion
			visuals.rotation = lerp(visuals.rotation, velocity.x * 0.0004, 5 * delta)
	else:
		visuals.scale.x = side
		visuals.scale.y = 1.0
	
# --- HELPER FUNCTIONS ---
func execute_jump_launch(f_dir: float, input_vec: Vector2):
	# 1. Calculate Jump Height & Power
	var base_power = 1.2 + (charge_time * 1.0) 
	
	var mask_mult = 1.0
	if current_set_id == 3: mask_mult = 1.3 # Gum
	if current_set_id == 4: mask_mult = 1.1 # Rock
	
	var launch_y = -1.8 * base_power * mask_mult
	var jump_dir = Vector2(input_vec.x * 0.4, launch_y).normalized()

	# 2. Wall Jump Adjustment
	if (is_on_wall() or wall_rejump_timer > 0) and not is_on_floor():
		var wall_norm = get_wall_normal() if is_on_wall() else last_wall_normal
		jump_dir = (wall_norm * 1.6 + Vector2(0, launch_y)).normalized()

	velocity = jump_dir * (jump_force_base * base_power * mask_mult)

	# 3. --- SMOKE LOGIC ---
	# Increased threshold to 0.25 to catch quick taps
	if charge_time > 0.25: 
		play_smoke_effect(Color.WHITE)
	else:
		# Explicitly kill smoke on tap jumps
		smoke.emitting = false

	# 4. Cleanup States
	is_charging = false
	charge_time = 0.0
	apply_launch_stretch(f_dir)

func perform_air_jump(power_mult: float):
	if is_charging: return # Prevent double-triggering if charging on a platform
	
	velocity.y = 0 
	velocity.y = -jump_force_base * power_mult 
	
	show_ability_ui()
	
	
	# Match Color to Mask
	var jump_color = Color.WHITE 
	match current_set_id:
		2: jump_color = Color(0.0, 0.681, 0.252, 1.0) # Light Blue Feather
		3: jump_color = Color(1.0, 0.5, 0.8)  # Pink Gum
		4: jump_color = Color(0.5, 0.5, 0.5)  # Grey Rock

	play_smoke_effect(jump_color)
	
	if current_set_id == 2:
		feather_particles.emitting = true
		feather_particles.restart()
	
	# Juice
	var tween = create_tween()
	var flip_mult = 1.0 if is_facing_right else -1.0
	tween.tween_property(visuals, "scale", Vector2(0.7 * flip_mult, 1.4), 0.1)
	tween.tween_property(visuals, "scale", Vector2(1.0 * flip_mult, 1.0), 0.3).set_trans(Tween.TRANS_ELASTIC)
	
func process_feather_glide(delta, input_vec):
	is_gliding = true
	
	# Particles: Force them on
	if not feather_particles.emitting:
		feather_particles.emitting = true
		
	# Position the particles below Goma
	feather_particles.position.y = 50.0
	
	# Resource Drain
	var drain_rate = 0.5 if input_vec.x == 0 else 0.9
	ability_charges -= delta * drain_rate
	show_ability_ui()

	# Wind resistance & Momentum
	if input_vec.x != 0:
		# Gliding speed - using move_toward for a more "physical" feel than lerp
		velocity.x = move_toward(velocity.x, input_vec.x * glide_horizontal_speed, 15.0)
	else:
		# Drifting to a stop horizontally
		velocity.x = move_toward(velocity.x, 0, 5.0)

	# Aerodynamic Tilt
	visuals.rotation = lerp_angle(visuals.rotation, input_vec.x * 0.3, 4.0 * delta)
	
	# Subtle "Lift" bobbing while gliding
	visuals.position.y += sin(Time.get_ticks_msec() * 0.01) * 0.2

func trigger_rock_smash():
	is_rock_smashing = true
	velocity.x = 0
	ability_charges -= 1.0
	show_ability_ui()
	
	# 1. The "Forceful Jump" - Give him a little lift first
	velocity.y = -jump_force_base * 0.8 
	visuals.modulate = Color(0.5, 0.5, 0.5)

	# Wait briefly while he's in the "upward" part of the jump
	await get_tree().create_timer(0.15).timeout

	if is_rock_smashing:
		velocity.y = rock_smash_fall_speed

func handle_landing_logic():
	if is_on_floor() and is_rock_smashing:
		execute_shockwave()
		is_rock_smashing = false
		visuals.modulate = Color.WHITE
		apply_landing_squash()

func change_set(id: int):
	if id == current_set_id: return
	
	is_gliding = false
	is_rock_smashing = false
	is_charging = false # Reset charging state on swap
	charge_time = 0.0
	visuals.modulate = Color.WHITE 
	
	var mask_names = { 2: "feather", 3: "gum", 4: "rock" }
	var can_change = false
	
	if id == 1: 
		can_change = true 
	elif mask_names.has(id):
		if unlocked_masks.get(mask_names[id], false):
			can_change = true
		else:
			return 
	
	if can_change and equipment_sets.has(id):
		current_set_id = id
		var new_data = equipment_sets[id]
		
		# --- SWAP POOF ---
			# 2. Match Color to Mask
		var swap_color = Color.WHITE 
		match current_set_id:
			2: swap_color = Color(0.0, 0.729, 0.388, 0.906) # Light Blue Feather
			3: swap_color = Color(1.0, 0.5, 0.8)  # Pink Gum
			4: swap_color = Color(0.5, 0.5, 0.5)  # Grey Rock
		play_smoke_effect(swap_color)
		
		await get_tree().create_timer(0.05).timeout
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
	var flip_mult = 1.0 if is_facing_right else -1.0
	
	# 1. Squash down
	tween.tween_property(visuals, "scale", Vector2(1.2 * flip_mult, 0.8), 0.1)
	
	# 2. Bounce back
	tween.tween_property(visuals, "scale", Vector2(1.0 * flip_mult, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: 
				change_set(1)
				fade_out_ui() # Hide UI when taking off masks
			KEY_2: change_set(2)
			KEY_3: change_set(3)
			KEY_4: change_set(4)

func perform_super_jump_logic():
	ability_charges -= 1.0
	charge_recovery_timer = 0.0
	show_ability_ui()
	smoke.emitting = true
	smoke.restart()
	
signal masks_updated(unlocked_dict)

# Function to call when Goma picks up a mask item
func collect_mask(mask_name: String):
	if unlocked_masks.has(mask_name):
		unlocked_masks[mask_name] = true
		print("Global updated: ", mask_name, " is now true")
		masks_updated.emit(unlocked_masks)
		
		# --- AUTO-EQUIP LOGIC ---
		# Create a quick mapping to find the ID based on the name
		var name_to_id = { "feather": 2, "gum": 3, "rock": 4 }
		
		if name_to_id.has(mask_name):
			var new_id = name_to_id[mask_name]
			change_set(new_id) # This triggers the smoke and visual swap automatically
			
func play_smoke_effect(color: Color = Color.WHITE):
	if smoke:
		smoke.self_modulate = color
		smoke.emitting = true
		smoke.restart()

func take_damage(amount: int):
	# ROCK RESISTANCE: Reduce damage or ignore it
	if current_set_id == 4:
		amount = int(amount * 0.5) # Take half damage
		if amount < 1: return     # Or ignore small hits entirely
		
	if is_invincible:
		return
		
	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health) # Notify the UI to remove a heart
	
	if current_health <= 0:
		die()
		return # Exit early if dead
		
	# Start Invincibility
	is_invincible = true
	start_invincibility_effect() # Start visual feedback
	
	# Wait for the duration, then turn invincibility off
	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false

func execute_shockwave():
	# 1. Damage Logic
	$RockBlastZone.monitoring = true
	$RockBlastZone.force_update_transform()
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var targets = $RockBlastZone.get_overlapping_areas()
	for t in targets:
		if t.has_method("take_damage"):
			t.take_damage(1)
	
	$RockBlastZone.monitoring = false
	
	# 2. THE CHUNKY BROWN BURST
	if shockwave_particles:
		var mat = shockwave_particles.process_material
		if mat:
			# CHANGE COLOR: Set to a "Dirt Brown"
			# Color(0.4, 0.25, 0.1) is a solid brown hex-style color
			mat.color = Color(0.4, 0.25, 0.1) 
			
			# CHANGE SIZE: Make individual chunks much bigger
			mat.scale_min = 4.0
			mat.scale_max = 7.0
			
			# INCREASE SCATTER: Make them fly faster and further
			mat.initial_velocity_min = 250.0
			mat.initial_velocity_max = 500.0
		
		# Ensure the smoke stays OFF
		# smoke.emitting = false  <-- We just won't call restart() on it
		
		shockwave_particles.emitting = true
		shockwave_particles.restart() 

	# 3. THE GROUND QUAKE (Camera Shake)
	if has_node("Camera2D"):
		var cam = $Camera2D
		var shake_tween = create_tween()
		for i in range(5):
			var intensity = 14.0 # Slightly stronger shake for more impact
			shake_tween.tween_property(cam, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.04)
		shake_tween.tween_property(cam, "offset", Vector2.ZERO, 0.04)
	
func start_invincibility_effect():
	# 1. THE RED FLASH (One time, very fast)
	var flash_tween = create_tween()
	# Change color to red immediately, then fade back to white
	visuals.modulate = Color.RED 
	flash_tween.tween_property(visuals, "modulate", Color.WHITE, 0.4)
	
	# 2. THE BLINKING (Repeats for the whole duration)
	# We use a loop that runs until invincibility is over
	var blink_tween = create_tween().set_loops(int(invincibility_duration / 0.2))
	
	# Transition transparency (Alpha) from 1.0 (Solid) to 0.3 (Ghostly)
	blink_tween.tween_property(visuals, "modulate:a", 0.3, 0.1)
	blink_tween.tween_property(visuals, "modulate:a", 1.0, 0.1)
	
	# 3. CLEANUP
	await get_tree().create_timer(invincibility_duration).timeout
	# Ensure Goma isn't stuck red or transparent
	visuals.modulate = Color.WHITE
	visuals.modulate.a = 1.0
	
func show_ability_ui():
# Only show if the current set has an ability (ID 2, 3, or 4)
	if current_set_id == 1:
		ability_ui.modulate.a = 0.0
		return
		
	ui_fade_timer = ui_display_time
	var tween = create_tween()
	tween.tween_property(ability_ui, "modulate:a", 1.0, 0.2)
	update_ability_visuals()

func fade_out_ui():
	var tween = create_tween()
	tween.tween_property(ability_ui, "modulate:a", 0.0, 0.5)

func update_ability_visuals():
	if !ability_textures.has(current_set_id): 
		ability_ui.hide()
		return
	
	ability_ui.show()
	var data = ability_textures[current_set_id]

	for i in range(ability_icons.size()):
		var icon = ability_icons[i]
		icon.texture_progress = data["p"]
		icon.texture_under = data["u"]
		icon.show() 

		# Calculate fill: e.g., if charges is 1.5, bar 0 is 100%, bar 1 is 50%, bar 2 is 0%
		var fill = clamp(ability_charges - i, 0.0, 1.0)
		icon.value = fill * 100

# --- Health Logic ---
func heal(amount: int):
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health) # Notify the UI to add a heart

var is_dying = false 

func die():
	if is_dying: return
	is_dying = true
	
	# 1. Total Physics/Signal Shutdown
	# This stops all scripts and collisions instantly
	process_mode = PROCESS_MODE_DISABLED 
	collision_layer = 0
	collision_mask = 0
	
	# 2. Clear Global immediately
	Global.player = null
	
	hide() 
	
	# 3. Use the SceneTree Timer directly to reload
	# We use CONNECT_ONE_SHOT to ensure this can't trigger twice
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(_on_death_timer_timeout, CONNECT_ONE_SHOT)

# This separate function is safer than an anonymous 'func():'
func _on_death_timer_timeout():
	# Final check: only reload if the tree still exists
	var tree = get_tree()
	if tree:
		# wipe this specific player instance from memory
		self.queue_free()
		tree.call_deferred("reload_current_scene")
	
func _reset_game():
	get_tree().reload_current_scene()
