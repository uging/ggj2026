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
	2: { "p": preload("res://assets/character/bar_feather.png"), "u": preload("res://assets/character/bar_feather_dim.png") },
	3: { "p": preload("res://assets/character/bar_gum.png"),     "u": preload("res://assets/character/bar_gum_dim.png") },
	4: { "p": preload("res://assets/character/bar_rock.png"),    "u": preload("res://assets/character/bar_rock_dim.png") }
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
@export var glide_gravity_mult := 0.08  # Lower = Lighter (was 0.15)
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
var is_facing_right := false
var current_set_id : int = 1 
var has_mask := false

# --- Active Ability Resources (Generic) ---
var ability_charges := 3.0 
var max_ability_charges := 3
var charge_recovery_timer := 0.0

var unlocked_masks = Global.unlocked_masks

# --- Equipment Sets ---
var equipment_sets = {
	1: { "mask": preload("res://assets/character/mask_default.png"), "cape": preload("res://assets/character/cape_default.png"), "mask_pos": Vector2(-6, -17), "mask_scale": Vector2(0.114, 0.122), "smoke_tex": preload("res://assets/character/smoke_default.png") },
	2: { "mask": preload("res://assets/character/mask_feather.png"), "cape": preload("res://assets/character/cape_feather.png"), "mask_pos": Vector2(-2, -22), "mask_scale": Vector2(0.216, 0.208), "smoke_tex": preload("res://assets/character/smoke_feather.png") },
	3: { "mask": preload("res://assets/character/mask_gum.png"), "cape": preload("res://assets/character/cape_gum.png"), "mask_pos": Vector2(-7, -13), "mask_scale": Vector2(0.134, 0.165), "smoke_tex": preload("res://assets/character/smoke_gum.png") },
	4: { "mask": preload("res://assets/character/mask_rock.png"), "cape": preload("res://assets/character/cape_rock.png"), "mask_pos": Vector2(-7, -14), "mask_scale": Vector2(0.151, 0.132), "smoke_tex": preload("res://assets/character/smoke_rock.png") }
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
# --- 1. INPUT DETECTION ---
	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	var flip_dir = -1.0 if is_facing_right else 1.0

# --- 2. RESOURCE MANAGEMENT ---
	# Only recharge if we AREN'T currently using an ability
	var is_using_ability = is_gliding or (is_charging and current_set_id == 3) or is_rock_smashing
	
	if ability_charges < max_ability_charges and not is_using_ability:
		charge_recovery_timer += delta
		update_ability_visuals()
		
		ui_fade_timer = ui_display_time
		ability_ui.modulate.a = 1.0 
		
		if charge_recovery_timer >= charge_cooldown:
			ability_charges = min(ability_charges + 1, max_ability_charges)
			charge_recovery_timer = 0.0
			update_ability_visuals()
			
	# Handle the fade-out timer
	if ui_fade_timer > 0 and not is_using_ability:
		ui_fade_timer -= delta
		if ui_fade_timer <= 0:
			fade_out_ui()

# --- 3. GRAVITY & STATE HANDLING ---
	if not is_on_floor():
		coyote_timer -= delta  # The timer counts down when in the air
		var current_gravity = 0.0
		
		if not is_top_down:
			current_gravity = gravity
			if current_set_id == 4:
				current_gravity *= rock_gravity_mult

		# FEATHER GLIDE (ID 2)
		if current_set_id == 2 and Input.is_action_pressed("ui_accept") and ability_charges > 0:
			is_gliding = true 
			feather_particles.emitting = true

			if Input.is_action_just_pressed("ui_accept"): 
				velocity.y = -250.0
				var flap_tween = create_tween()
				flap_tween.tween_property(visuals, "scale", Vector2(1.3 * flip_dir, 0.8), 0.1)
				flap_tween.tween_property(visuals, "scale", Vector2(1.0 * flip_dir, 1.0), 0.3)
			
			current_gravity *= glide_gravity_mult
			velocity.y = min(velocity.y, glide_max_fall_speed)
			var glide_input = Input.get_axis("move_left", "move_right")
			velocity.x = lerp(velocity.x, glide_input * glide_horizontal_speed, 8.0 * delta)
			visuals.rotation = lerp_angle(visuals.rotation, glide_input * 0.2, 5.0 * delta)
			
			# ADJUST THIS LINE TO CHANGE CONSUMPTION RATE:
			# With this "Smart Drain":
			var drain_rate = 0.7 if glide_input == 0 else 1.3
			ability_charges -= delta * drain_rate
			show_ability_ui()
		else:
			is_gliding = false 
			feather_particles.emitting = false
			visuals.rotation = lerp_angle(visuals.rotation, 0, 5.0 * delta)
			
			if wall_kick_boost_timer > 0:
				current_gravity *= 0.3
				wall_kick_boost_timer -= delta
			
		velocity.y += current_gravity * delta
		if wall_rejump_timer > 0: wall_rejump_timer -= delta

		# GUM AERIAL JUMP (ID 3)
		if Input.is_action_just_pressed("ui_accept") and current_set_id == 3:
			if ability_charges >= 1.0:
				perform_super_jump_logic()
				# 1. Reset downward velocity so falling doesn't "eat" your jump height
				if velocity.y > 0:
					velocity.y = 0

				# 2. Apply the boost (Adjust 2.0 to your liking)
				velocity.y = -jump_force_base * 2.0 

				# 3. Optional: Add a little "kick" to the scale for visual feedback
				visuals.scale = Vector2(1.4 * flip_dir, 0.7)
				
		# ROCK SMASH (ID 4)
		if current_set_id == 4 and Input.is_action_just_pressed("ui_accept") and not is_on_floor():
			if ability_charges >= 1.0:
				is_rock_smashing = true
				ability_charges -= 1.0
				show_ability_ui()

				velocity.y = -jump_force_base * 1.3
				visuals.modulate = Color(0.5, 0.5, 0.5) # Turn Grey

				await get_tree().create_timer(0.2).timeout
				
				# Ensure we are still smashing (didn't land during the timer)
				if is_rock_smashing:
					velocity.y = rock_smash_fall_speed
					velocity.x = 0
	else:
		coyote_timer = coyote_time_duration # Reset timer while touching the floor

# --- 4. SNAPPY FLIP TRACKER ---
	if input_vector.x > 0: is_facing_right = true
	elif input_vector.x < 0: is_facing_right = false
	
# ---5. SLOPE SLIDING CALCULATION ---
	var is_on_steep_slope = false
	floor_snap_length = 12.0     # Keep Goma glued to the floor
	floor_constant_speed = true  # Ignore jagged speed changes
	floor_max_angle = deg_to_rad(45.0) # Ensure he can walk up 45-degree angles/stairs

	if is_on_floor():
		var floor_normal = get_floor_normal() #
		var floor_angle = rad_to_deg(acos(floor_normal.dot(Vector2.UP))) #
		
		if floor_angle > slope_limit_deg:
			var gum_can_resist = (current_set_id == 3 and ability_charges >= 1.0)
			if not gum_can_resist:
				is_on_steep_slope = true
				
				# Set velocity based on slope direction for a smoother ride
				# We use the X component of the normal to determine direction
				velocity.x = lerp(velocity.x, floor_normal.x * slide_speed, 5 * delta)
				
				# Visual: Match the slope angle smoothly
				visuals.rotation = lerp_angle(visuals.rotation, floor_normal.angle() + PI/2, 10 * delta)

# --- 6. JUMP CHARGING (Floor, Wall, or Sticky) ---
	var is_near_wall = is_on_wall() or wall_rejump_timer > 0
	var can_jump = (coyote_timer > 0) or is_near_wall

	if Input.is_key_pressed(KEY_SPACE) and can_jump and not is_rock_smashing and current_set_id != 4:
		is_charging = true
		var charge_speed = 4.0 if current_set_id == 3 else 2.0
		charge_time = min(charge_time + delta * charge_speed, 1.0) 
		
		# IMPORTANT: Once we start charging a jump, 
		# kill the coyote timer so they can't double-jump
		coyote_timer = 0
		
		if current_set_id == 3 and charge_time >= 1.0 and ability_charges >= 1.0:
			is_super_charging = true
			# Optional: Visual indicator that Super Jump is ready (e.g., vibrating)
			visuals.position.x = randf_range(-2, 2) 
		
		# Visual Squish
		visuals.scale.y = lerp(visuals.scale.y, 0.6, 10 * delta) # Deeper squish for long press
		visuals.scale.x = 1.35 * flip_dir 
		velocity.x = lerp(velocity.x, 0.0, 10 * delta)
	
	elif is_charging:
	# --- 7. PERFORM LAUNCH ---
		# BASE HEIGHT SETTINGS (Adjust these numbers to tune height)
		var regular_jump_height = -1.4     # Default (No Mask)
		var gum_regular_height = -2.2      # Gum Mask (Single Tap)
		var gum_super_height = -2.7        # Gum Mask (Long Press / Charged)
		var feather_jump_height = -1.8    # Feather Mask
		
		# Determine which height to use
		var launch_y = regular_jump_height
		
		var rock_jump_height = -2.0 # Lower than regular -1.4
		if current_set_id == 4:
			launch_y = rock_jump_height
		
		if current_set_id == 3: # GUM MASK
			if is_super_charging:
				perform_super_jump_logic() 
				launch_y = gum_super_height
				is_super_charging = false
			else:
				launch_y = gum_regular_height
		elif current_set_id == 2: # FEATHER MASK
			launch_y = feather_jump_height
			
		var jump_direction = Vector2(input_vector.x, launch_y).normalized()
		
		# --- WALL KICK LOGIC ---
		if is_near_wall and not is_on_floor():
			var wall_normal = get_wall_normal() if is_on_wall() else last_wall_normal
			wall_kick_boost_timer = wall_kick_boost_duration
			
			if input_vector.x == 0 or sign(input_vector.x) == sign(-wall_normal.x):
				jump_direction = (wall_normal * 1.2 + Vector2(0, launch_y * 1.8)).normalized()
			else:
				jump_direction = (wall_normal * 3.5 + Vector2(0, launch_y * 1.2)).normalized()
			wall_rejump_timer = 0 

		# Calculate final force
		var power_boost = 1.0 # We handle the boost via launch_y now
		var final_force = (jump_force_base * (1.0 + charge_time * max_jump_multiplier)) * power_boost
		
		# Cap the speed
		var max_cap = 1000.0 if current_set_id == 3 else 750.0
		velocity = jump_direction * min(final_force, max_cap)
		
		apply_launch_stretch(flip_dir)
		charge_time = 0.0
		is_charging = false

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and current_set_id == 4:
		velocity.y = -jump_force_base * 2.0 # A small, heavy jump
		# Small Forward Kick: If moving, give a little extra push to help clear the ledge
		if input_vector.x != 0:
			velocity.x = input_vector.x * (speed * 1.1)
		apply_launch_stretch(flip_dir)
		# Optional: Add a small screen shake or sound effect here!
	
# # --- 8. NORMAL MOVEMENT ---
	if not is_charging:
		# 1. Start with base speed
		var final_speed = speed
		
		# 2. APPLY ROCK HEAVINESS (ID 4)
		if current_set_id == 4:
			final_speed *= rock_speed_mult # Goma walks slower with the heavy mask
		
		# 3. Calculate target velocity using our modified speed
		var target_vel = input_vector * final_speed
		
		if is_top_down:
			# TOP-DOWN MOVEMENT: Snappy movement for the map
			velocity = velocity.lerp(target_vel, 15.0 * delta)
			visuals.rotation = lerp_angle(visuals.rotation, 0.0, 10.0 * delta)
		else:
			if is_on_steep_slope:
				# Slide control on slopes
				velocity.x = lerp(velocity.x, velocity.x + (target_vel.x * 0.1), 2 * delta)
			else:
				if is_on_floor():
					# Grounded movement
					velocity.x = lerp(velocity.x, target_vel.x, 20.0 * delta)
				elif is_gliding:
					# Skip this part! Section 3 is handling velocity.x for the Feather Mask
					pass 
				else:
					# Normal air control (Jump/Fall)
					velocity.x = lerp(velocity.x, target_vel.x, 3.0 * delta)
				
				# Apply the "speed lean" ONLY if not gliding
				if not is_gliding:
					visuals.rotation = lerp(visuals.rotation, velocity.x * 0.0004, 5 * delta)
		
		# --- SCALE LOGIC ---
		# We check 'is_gliding' here so our "flap" squash-and-stretch in Section 3 
		# doesn't get instantly overwritten by the running stretch.
		if not is_gliding:
			var stretch_factor = abs(velocity.x) * 0.0001
			visuals.scale.x = (1.0 + stretch_factor) * flip_dir
			visuals.scale.y = lerp(visuals.scale.y, 1.0 - (stretch_factor * 0.5), 10 * delta)

# --- 9. EXECUTE MOVEMENT & LANDING ---
	var was_in_air = not is_on_floor()
	move_and_slide()
	
	if not is_top_down:
		if was_in_air and is_on_floor():
			if is_rock_smashing:
				# Call the new function we just made
				execute_shockwave()
				
				# Reset states AFTER the shockwave check
				is_rock_smashing = false
				visuals.modulate = Color.WHITE
				velocity.y = 0 
				
				show_ability_ui()
			
			apply_landing_squash()
						
# --- Helper Functions ---

func change_set(id: int):
	if id == current_set_id: return
	# Reset all active states
	is_gliding = false
	is_rock_smashing = false
	is_super_charging = false
	visuals.modulate = Color.WHITE # Reset rock color
	
	# Mapping IDs to the dictionary keys
	var mask_names = { 2: "feather", 3: "gum", 4: "rock" }
	
	# Check if the mask is allowed
	var can_change = false
	if id == 1: 
		can_change = true # Always allow default
	elif mask_names.has(id):
		var mask_key = mask_names[id]
		if unlocked_masks[mask_key] == true:
			can_change = true
		else:
			print("You haven't collected the ", mask_key, " mask yet!")
			return # Exit the function if not unlocked
	
	# If we pass the check, perform the visual change
	if can_change and equipment_sets.has(id):
		current_set_id = id
		var new_data = equipment_sets[id]
		
		smoke.texture = new_data["smoke_tex"]
		smoke.emitting = true
		smoke.restart()
		
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

# --- Health Logic ---

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
	
	# 1. Enable and Sync the zone
	$RockBlastZone.monitoring = true
	$RockBlastZone.force_update_transform() # Ensures physics knows our current position
	
	# 2. Wait for physics frames
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# 3. Check for the traps
	var targets = $RockBlastZone.get_overlapping_areas()
	
	for t in targets:
		if t.has_method("take_damage"):
			t.take_damage(1)
	
	# 4. Cleanup & Visuals
	$RockBlastZone.monitoring = false
	
	# Trigger your NEW shockwave particles
	shockwave_particles.emitting = true
	shockwave_particles.restart() 
	
	# (Optional) Keep the old smoke too if you want both!
	# smoke.emitting = true
	# smoke.restart()
	
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
