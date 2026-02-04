extends CharacterBody2D

# --- Signals ---
signal health_changed(new_health)
signal masks_updated(unlocked_dict)

# --- Constants & Enums ---
enum Set { DEFAULT = 1, FEATHER = 2, GUM = 3, ROCK = 4 }

# --- References ---
@onready var visuals = $Visuals
@onready var goma = $Visuals/Goma
@onready var mask = $Visuals/Mask
@onready var cape = $Visuals/Cape
@onready var smoke = $Visuals/Smoke
@onready var feather_particles = $Visuals/FeatherParticles
@onready var shockwave_particles = $Visuals/ShockwaveParticles
@onready var rock_aura_visual: Sprite2D = $Visuals/RockAuraVisual
@onready var ability_ui = $AbilityUI
@onready var ability_container = $AbilityUI/HBoxContainer

# --- Exported Settings ---
@export_group("General")
@export var is_top_down := false
@export var speed := 460.0
@export var gravity := 1600.0
@export var ui_display_time := 2.5

@export_group("Platforming")
@export var jump_force_base := 320.0
@export var max_jump_multiplier := 1.5
@export var ground_friction_factor := 5.0
@export var slide_speed := 600.0
@export var slope_limit_deg := 30.0
@export var coyote_time_duration := 0.15
@export var wall_rejump_window := 0.20

@export_group("Abilities")
@export var charge_cooldown := 2.0
@export var glide_gravity_mult := 0.03
@export var glide_max_fall_speed := 80.0
@export var glide_horizontal_speed := 300.0
@export var rock_gravity_mult := 1.8
@export var rock_speed_mult := 0.85
@export var rock_smash_fall_speed := 1200.0
@export var invincibility_duration := 1.5

# --- State Variables ---
var current_health: int
var max_health: int
var ability_charges := 3.0
var max_ability_charges := 3.0
var charge_recovery_timer := 0.0
var charge_time := 0.0
var ui_fade_timer := 0.0
var coyote_timer := 0.0
var wall_rejump_timer := 0.0
var last_ability_press_time := 0.0

var input_enabled := false
var current_set_id: int = Set.DEFAULT
var is_facing_right := true
var is_charging := false
var is_gliding := false
var is_rock_aura_active := false
var is_rock_smashing := false
var is_super_charging := false
var is_invincible := false
var is_dying := false
var can_execute_launch := false
var last_wall_normal := Vector2.ZERO
var ability_icons = []
var unlocked_masks = Global.unlocked_masks

# --- Data Dictionaries ---
var ability_textures = {
	Set.FEATHER: { 
		"p": preload("res://entities/player/assets/bar_feather.png"), 
		"u": preload("res://entities/player/assets/bar_feather_dim.png") 
	},
	Set.GUM: { 
		"p": preload("res://entities/player/assets/bar_gum.png"),     
		"u": preload("res://entities/player/assets/bar_gum_dim.png") 
	},
	Set.ROCK: { 
		"p": preload("res://entities/player/assets/bar_rock.png"),    
		"u": preload("res://entities/player/assets/bar_rock_dim.png") 
	}
}

var equipment_sets = {
	Set.DEFAULT: { 
		"mask": preload("res://entities/player/assets/mask_default.png"), 
		"cape": preload("res://entities/player/assets/cape_default.png"), 
		"mask_pos": Vector2(7, -17), 
		"mask_scale": Vector2(0.114, 0.122) 
	},
	Set.FEATHER: { 
		"mask": preload("res://entities/player/assets/mask_feather.png"), 
		"cape": preload("res://entities/player/assets/cape_feather.png"), 
		"mask_pos": Vector2(6, -20), 
		"mask_scale": Vector2(0.214, 0.239) 
	},
	Set.GUM: { 
		"mask": preload("res://entities/player/assets/mask_gum.png"),     
		"cape": preload("res://entities/player/assets/cape_gum.png"),     
		"mask_pos": Vector2(10.56, -12.632), 
		"mask_scale": Vector2(0.14, 0.151) 
	},
	Set.ROCK: { 
		"mask": preload("res://entities/player/assets/mask_rock.png"),    
		"cape": preload("res://entities/player/assets/cape_rock.png"),    
		"mask_pos": Vector2(10, -16), 
		"mask_scale": Vector2(0.16, 0.135) 
	}
}

# --- Initialization ---
func _ready() -> void:
	current_health = Global.current_health 
	max_health = Global.max_health_limit
	
	# Pass 'true' as the second argument to skip the smoke effect on load
	if Global.current_equipped_set != Set.DEFAULT:
		change_set(Global.current_equipped_set, true)
		
	# Reset status
	is_dying = false
	can_execute_launch = false
	_reset_states()
	
	process_mode = PROCESS_MODE_INHERIT 
	show()
	
	# Idle Bobbing Logic
	var tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(visuals, "position:y", -5.0, 0.8).as_relative()
	tween.tween_property(visuals, "position:y", 5.0, 0.8).as_relative()
	
	health_changed.emit(current_health)
	masks_updated.emit(unlocked_masks)
	
	if ability_container:
		ability_icons = ability_container.get_children()
		
	if has_node("Camera2D"):
		$Camera2D.make_current()
		
	get_tree().create_timer(0.1).timeout.connect(func(): input_enabled = true)

# --- Main Physics Loop ---

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	_handle_resource_regen(delta)
	
	if is_rock_aura_active:
		_handle_aura_damage()

	if is_top_down:
		_process_top_down_movement(delta)
	else:
		_process_platformer_movement(delta)

	move_and_slide()
	_apply_physics_visuals(delta)

# --- Movement Branches ---

func _process_top_down_movement(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity = Vector2.ZERO
	is_charging = false
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if global_position.distance_to(mouse_pos) > 15:
			target_velocity = global_position.direction_to(mouse_pos) * speed
			is_facing_right = target_velocity.x > 0
	else:
		target_velocity = input_vector * speed
		if input_vector.x != 0:
			is_facing_right = input_vector.x > 0
		
	velocity = velocity.lerp(target_velocity, 15.0 * delta)
	visuals.rotation = 0

func _process_platformer_movement(delta: float) -> void:
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_near_wall = is_on_wall() or wall_rejump_timer > 0
	var can_jump = (coyote_timer > 0) or is_near_wall
	var is_hunkered = Input.is_action_pressed("move_down") and is_on_floor()
	
	# 1. Facing Logic
	if not is_rock_smashing:
		if is_hunkered and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_facing_right = (get_global_mouse_position().x > global_position.x)
		elif input_vector.x != 0:
			is_facing_right = input_vector.x > 0

	# 2. Ability Logic (Delegated to Module 3)
	_handle_ability_logic(delta, input_vector, can_jump, is_near_wall)

	# 3. Gravity Logic
	if not is_on_floor():
		coyote_timer -= delta
		var gravity_step = gravity
		
		if current_set_id == Set.ROCK:
			gravity_step *= rock_gravity_mult
		elif current_set_id == Set.FEATHER:
			gravity_step *= glide_gravity_mult if (is_gliding and ability_charges > 0) else 0.7
			
		velocity.y += gravity_step * delta
		if is_gliding and velocity.y > glide_max_fall_speed:
			velocity.y = glide_max_fall_speed
	else:
		coyote_timer = coyote_time_duration
		if velocity.y > 0: velocity.y = 0
		_handle_landing_logic()

	# 4. Horizontal Movement
	if not is_charging and not is_rock_smashing:
		if is_hunkered:
			velocity.x = move_toward(velocity.x, 0, speed * 0.2)
		else:
			var move_speed = speed
			if current_set_id == Set.ROCK:
				move_speed *= (1.4 if is_on_floor() and input_vector.x != 0 else rock_speed_mult)
			
			var target_x = input_vector.x * (glide_horizontal_speed if is_gliding and ability_charges > 0 else move_speed)
			var accel = 8.0 if is_gliding else 15.0
			velocity.x = lerp(velocity.x, target_x, accel * delta)

# --- Resource Regen ---

func _handle_resource_regen(delta: float) -> void:
	var is_using_ability = is_gliding or is_charging or is_rock_smashing or is_rock_aura_active
	
	# Handle Rock Aura Drain
	if is_rock_aura_active:
		ability_charges -= delta * 0.8 # Adjust speed of drain here
		show_ability_ui()
		if ability_charges <= 0:
			_deactivate_rock_aura()
			
	if ability_charges < max_ability_charges and not is_using_ability:
		charge_recovery_timer += delta
		if charge_recovery_timer >= charge_cooldown:
			ability_charges = min(ability_charges + 1, max_ability_charges)
			charge_recovery_timer = 0.0
			update_ability_visuals()
			
# --- Ability Input Coordinator ---

func _handle_ability_logic(delta: float, input_vector: Vector2, can_jump: bool, is_near_wall: bool) -> void:
	if not input_enabled: return
	
	# 1. Tap / Double-Tap Logic
	if Input.is_action_just_pressed("ability"):
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Rock Smash (Double tap / Quick air press)
		if current_set_id == Set.ROCK and not is_on_floor() and current_time - last_ability_press_time < 0.3:
			if ability_charges >= 1.0: trigger_rock_smash()
		
		# Air Jumps (Gum / Feather)
		elif current_set_id in [Set.GUM, Set.FEATHER] and not is_on_floor() and not is_near_wall:
			if ability_charges >= 1.0:
				ability_charges -= 1.0
				var jump_power = 2.5 if current_set_id == Set.GUM else 1.5
				perform_air_jump(jump_power)
				
		last_ability_press_time = current_time

	# 2. Held Logic (Charging or Gliding)
	if Input.is_action_pressed("ability"):
		if can_jump and not is_rock_smashing:
			_process_jump_charge(delta)
		elif not is_on_floor() and current_set_id == Set.FEATHER and ability_charges > 0:
			if velocity.y > -150: 
				_process_feather_glide(delta, input_vector)
			else:
				is_gliding = false
				feather_particles.emitting = false
	else:
		is_gliding = false
		feather_particles.emitting = false

	# 3. Release Logic
	if Input.is_action_just_released("ability"):
		if is_charging and can_execute_launch: 
			execute_jump_launch(1.0 if is_facing_right else -1.0, input_vector)
		
		is_gliding = false
		is_charging = false
		can_execute_launch = false
		feather_particles.emitting = false

# --- Jump & Launch Mechanics ---

func _process_jump_charge(delta: float) -> void:
	is_charging = true
	can_execute_launch = true
	var charge_speed = 4.5 if current_set_id == Set.GUM else 2.5
	charge_time = min(charge_time + delta * charge_speed, 1.0)
	coyote_timer = 0
	
	# Visual feedback for charging
	visuals.scale.y = lerp(visuals.scale.y, 0.6, 10 * delta)
	velocity.x = lerp(velocity.x, 0.0, 10 * delta)
	
	if charge_time > 0.7: 
		is_super_charging = (current_set_id == Set.GUM)
		visuals.position.x = randf_range(-1, 1)

func execute_jump_launch(f_dir: float, input_vec: Vector2) -> void:	
	# 1. Safety exit for micro-taps
	if charge_time < 0.05:
		charge_time = 0.0
		is_charging = false
		return

	# 2. Standard Jump/Launch Power Calculation
	var base_power = 1.2 + (charge_time * 1.0)
	var mask_mult = 1.0
	match current_set_id:
		Set.GUM: mask_mult = 1.3
		Set.ROCK: mask_mult = 1.1
	
	var launch_y = -1.8 * base_power * mask_mult
	var jump_dir = Vector2(input_vec.x * 0.4, launch_y).normalized()

	# 3. Wall Jump Logic
	if (is_on_wall() or wall_rejump_timer > 0) and not is_on_floor():
		var wall_norm = get_wall_normal() if is_on_wall() else last_wall_normal
		jump_dir = (wall_norm * 1.6 + Vector2(0, launch_y)).normalized()

	velocity = jump_dir * (jump_force_base * base_power * mask_mult)
	
	# 4. Cleanup
	is_charging = false
	charge_time = 0.0
	apply_launch_stretch(f_dir)

func perform_air_jump(power_mult: float) -> void:
	velocity.y = -jump_force_base * power_mult 
	show_ability_ui()
	
	var jump_color = Color.WHITE 
	match current_set_id:
		Set.FEATHER: jump_color = Color(0.0, 0.681, 0.252, 1.0)
		Set.GUM:     jump_color = Color(1.0, 0.5, 0.8)
		Set.ROCK:    jump_color = Color(0.5, 0.5, 0.5)

	play_smoke_effect(jump_color, Vector2(0, 50))
	
	if current_set_id == Set.FEATHER:
		feather_particles.emitting = true
		feather_particles.restart()
	
	# Air Jump "Juice"
	var tween = create_tween()
	var flip = 1.0 if is_facing_right else -1.0
	tween.tween_property(visuals, "scale", Vector2(0.7 * flip, 1.4), 0.1)
	tween.tween_property(visuals, "scale", Vector2(1.0 * flip, 1.0), 0.3).set_trans(Tween.TRANS_ELASTIC)

# --- Specific Ability Processors ---

func _process_feather_glide(delta: float, input_vec: Vector2) -> void:
	is_gliding = true
	feather_particles.emitting = true
	feather_particles.position.y = 50.0
	
	var drain_rate = 0.5 if input_vec.x == 0 else 0.9
	ability_charges -= delta * drain_rate
	show_ability_ui()

	velocity.x = move_toward(velocity.x, input_vec.x * glide_horizontal_speed, 15.0)
	visuals.rotation = lerp_angle(visuals.rotation, input_vec.x * 0.3, 4.0 * delta)
	visuals.position.y += sin(Time.get_ticks_msec() * 0.01) * 0.2

func trigger_rock_smash() -> void:
	is_rock_smashing = true
	velocity.x = 0
	ability_charges -= 1.0
	show_ability_ui()
	
	velocity.y = -jump_force_base * 0.8 
	visuals.modulate = Color(0.5, 0.5, 0.5)

	await get_tree().create_timer(0.15).timeout
	if is_rock_smashing:
		velocity.y = rock_smash_fall_speed
		
# --- Health & Damage Logic ---

func heal(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)
	Global.current_health = current_health
	health_changed.emit(current_health)

func take_damage(amount: int) -> void:
	if is_invincible or is_dying or is_rock_aura_active: return
	
	# Rock Resistance: Half damage
	if current_set_id == Set.ROCK:
		amount = maxi(1, int(amount * 0.5))
		
	current_health = clampi(current_health - amount, 0, max_health)
	Global.current_health = current_health
	health_changed.emit(current_health)
	
	if current_health <= 0:
		die()
	else:
		is_invincible = true
		start_invincibility_effect()
		await get_tree().create_timer(invincibility_duration).timeout
		is_invincible = false

func bounce_off_enemy() -> void:
	velocity.y = -500
	is_rock_smashing = false 
	visuals.modulate = Color.WHITE

# --- Equipment & Set Systems ---
func change_set(id: int, silent: bool = false) -> void:
	# If we are already wearing this set, do nothing
	if id == current_set_id or not equipment_sets.has(id): return
	
	# Verify Unlock status from Global
	var mask_names = { Set.FEATHER: "feather", Set.GUM: "gum", Set.ROCK: "rock" }
	if id != Set.DEFAULT and not unlocked_masks.get(mask_names[id], false):
		return 

	_reset_states()
	current_set_id = id
	Global.current_equipped_set = id
	
	var new_data = equipment_sets[id]
	var swap_color = {
		Set.DEFAULT: Color.WHITE,
		Set.FEATHER: Color(0.0, 0.729, 0.388),
		Set.GUM:     Color(1.0, 0.5, 0.8),
		Set.ROCK:    Color(0.5, 0.5, 0.5)
	}.get(id, Color.WHITE)
	
	# LOGIC FIX: Only trigger the smoke/juice if we aren't in 'silent' mode
	if not silent:
		play_smoke_effect(swap_color, Vector2.ZERO)
	
	# Brief delay to ensure textures swap cleanly
	await get_tree().create_timer(0.05).timeout
	mask.texture = new_data["mask"]
	mask.position = new_data["mask_pos"]
	mask.scale = new_data["mask_scale"]
	cape.texture = new_data["cape"]

func collect_mask(mask_name: String) -> void:
	if unlocked_masks.has(mask_name):
		unlocked_masks[mask_name] = true
		masks_updated.emit(unlocked_masks)
		
		var name_to_id = { "feather": Set.FEATHER, "gum": Set.GUM, "rock": Set.ROCK }
		if name_to_id.has(mask_name):
			change_set(name_to_id[mask_name])

# --- Visual & UI Effects ---

func _apply_physics_visuals(delta: float) -> void:
	if is_top_down:
		visuals.scale.x = 1.0 if is_facing_right else -1.0
		visuals.scale.y = 1.0
		return

	var side = 1.0 if is_facing_right else -1.0
	if is_rock_smashing:
		visuals.scale.x = side * 0.8
		visuals.scale.y = lerp(visuals.scale.y, 1.4, 15 * delta)
	elif is_charging:
		visuals.scale.y = lerp(visuals.scale.y, 0.6, 10 * delta)
		visuals.scale.x = side 
	else:
		var stretch = abs(velocity.x) * 0.0001
		visuals.scale.y = lerp(visuals.scale.y, 1.0 - (stretch * 0.5), 10 * delta)
		visuals.scale.x = side * (1.0 + stretch)
		visuals.rotation = lerp(visuals.rotation, velocity.x * 0.0004, 5 * delta)

func execute_shockwave() -> void:
	$RockBlastZone.monitoring = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	for area in $RockBlastZone.get_overlapping_areas():
		if area.has_method("take_damage"): area.take_damage(1)
		elif area.get_parent().has_method("take_damage"): area.get_parent().take_damage(1)
				
	$RockBlastZone.monitoring = false
	
	if shockwave_particles:
		var mat = shockwave_particles.process_material
		if mat is ParticleProcessMaterial:
			# 1. Color: Dirt Brown
			mat.color = Color(0.4, 0.25, 0.1) 

			# 2. Scale: Restore the "Chunky" look
			mat.scale_min = 4.0
			mat.scale_max = 7.0

			# 3. Velocity: Make them explode outward
			mat.initial_velocity_min = 250.0
			mat.initial_velocity_max = 500.0
		shockwave_particles.emitting = true
		shockwave_particles.restart() 

	if has_node("Camera2D"):
		var shake_tween = create_tween()
		for i in 5:
			shake_tween.tween_property($Camera2D, "offset", Vector2(randf_range(-14, 14), randf_range(-14, 14)), 0.04)
		shake_tween.tween_property($Camera2D, "offset", Vector2.ZERO, 0.04)

func _activate_rock_aura() -> void:
	is_rock_aura_active = true
	is_invincible = true
	
	# 1. Get the radius of your collision shape (100)
	var col_shape = $RockBlastZone/CollisionShape2D.shape
	if col_shape is CircleShape2D:
		var target_radius = col_shape.radius
		
		# 2. Match the sprite scale to the radius
		# Diameter (200) divided by Image Width (681)
		var texture_width = rock_aura_visual.texture.get_size().x
		var final_scale = (target_radius * 2.0) / texture_width
		rock_aura_visual.scale = Vector2(final_scale, final_scale)
	
	rock_aura_visual.show()
	
	# 3. Pulsing animation (starts from our calculated base scale)
	var base_scale = rock_aura_visual.scale
	var pulse = create_tween().set_loops()
	pulse.tween_property(rock_aura_visual, "scale", base_scale * 1.1, 0.6)
	pulse.tween_property(rock_aura_visual, "scale", base_scale, 0.6)

func _deactivate_rock_aura() -> void:
	is_rock_aura_active = false
	is_invincible = false
	if is_instance_valid(rock_aura_visual):
		rock_aura_visual.hide()
	visuals.modulate = Color.WHITE
	
func _handle_aura_damage() -> void:
	if not is_rock_aura_active: return
	
	# Reuse your RockBlastZone for the aura contact damage
	$RockBlastZone.monitoring = true
	for area in $RockBlastZone.get_overlapping_areas():
		if area.has_method("take_damage"):
			area.take_damage(1)
		elif area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(1)
			
func update_ability_visuals() -> void:
	if !ability_textures.has(current_set_id): 
		ability_ui.modulate.a = 0.0
		return
	
	ability_ui.show()
	var data = ability_textures[current_set_id]
	for i in ability_icons.size():
		var icon = ability_icons[i]
		icon.texture_progress = data["p"]
		icon.texture_under = data["u"]
		icon.value = clamp(ability_charges - i, 0.0, 1.0) * 100

func show_ability_ui() -> void:
	if current_set_id == Set.DEFAULT: return
	
	# 1. Update the icons/bars
	update_ability_visuals()
	
	# 2. Make it appear instantly (No tween needed here)
	ability_ui.show()
	ability_ui.modulate.a = 1.0
	
	# 3. Start the "countdown" timer
	# When the time runs out, it calls the OTHER function which HAS the tween
	get_tree().create_timer(ui_display_time).timeout.connect(fade_out_ui)

func fade_out_ui() -> void:
	# Check if the UI is already hidden to avoid unnecessary tweens
	if ability_ui.modulate.a == 0: return
	
	var tween = create_tween()
	tween.tween_property(ability_ui, "modulate:a", 0.0, 0.5)

# --- Internal Helpers ---

func _input(event: InputEvent) -> void:
	# Only trigger on the initial press, not while holding
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: 
				change_set(Set.DEFAULT)
				fade_out_ui() # Hide UI when removing masks
			KEY_2: 
				change_set(Set.FEATHER)
			KEY_3: 
				change_set(Set.GUM)
			KEY_4: 
				change_set(Set.ROCK)

func _reset_states() -> void:
	is_gliding = false
	is_rock_smashing = false
	is_charging = false
	charge_time = 0.0
	visuals.modulate = Color.WHITE
	visuals.rotation = 0

func start_invincibility_effect() -> void:
	var flash = create_tween()
	visuals.modulate = Color.RED 
	flash.tween_property(visuals, "modulate", Color.WHITE, 0.4)
	
	var blink = create_tween().set_loops(int(invincibility_duration / 0.2))
	blink.tween_property(visuals, "modulate:a", 0.3, 0.1)
	blink.tween_property(visuals, "modulate:a", 1.0, 0.1)

func play_smoke_effect(color: Color = Color.WHITE, offset: Vector2 = Vector2.ZERO) -> void:
	if smoke:
		smoke.position = offset
		smoke.self_modulate = color
		smoke.emitting = true
		smoke.restart()

func die() -> void:
	if is_dying: return
	is_dying = true
	process_mode = PROCESS_MODE_DISABLED 
	collision_layer = 0
	collision_mask = 0
	Global.player = null
	hide() 
	
	get_tree().create_timer(0.1).timeout.connect(func():
		queue_free()
		get_tree().reload_current_scene()
	)

func _handle_landing_logic() -> void:
	if is_rock_smashing:
		execute_shockwave()
		is_rock_smashing = false
		visuals.modulate = Color.WHITE
		if ability_charges > 0:
			_activate_rock_aura()
		else:
			visuals.modulate = Color.WHITE
		apply_landing_squash()

func apply_landing_squash() -> void:
	var tween = create_tween()
	var flip = 1.0 if is_facing_right else -1.0
	tween.tween_property(visuals, "scale", Vector2(1.2 * flip, 0.8), 0.1)
	tween.tween_property(visuals, "scale", Vector2(1.0 * flip, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC)

func apply_launch_stretch(f_dir: float) -> void:
	var tween = create_tween()
	tween.tween_property(visuals, "scale", Vector2(0.85 * f_dir, 1.15), 0.1)
	tween.tween_property(visuals, "scale", Vector2(1.0 * f_dir, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC)
