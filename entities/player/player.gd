extends CharacterBody2D

# --- Signals ---
signal health_changed(new_health)
signal masks_updated(unlocked_dict)

# --- Constants & Enums ---
enum Set { DEFAULT = 1, FEATHER = 2, GUM = 3, ROCK = 4 }
const DOUBLE_TAP_WINDOW := 0.25
const UI_FADE_SPEED := 0.5
const CHARGE_THRESHOLD := 0.15

# --- References ---
@onready var visuals: Node2D = $Visuals
@onready var mask: Sprite2D = $Visuals/Mask
@onready var cape: Sprite2D = $Visuals/Cape
@onready var smoke: GPUParticles2D = $Visuals/Smoke
@onready var feather_particles: GPUParticles2D = $Visuals/FeatherParticles
@onready var shockwave_particles: GPUParticles2D = $Visuals/ShockwaveParticles
@onready var ability_ui: CanvasItem = $AbilityUI
@onready var ability_container: HBoxContainer = $AbilityUI/HBoxContainer
@onready var blast_zone: Area2D = $RockBlastZone

# --- Exported Settings ---
@export_group("General")
@export var is_top_down := false
@export var speed := 460.0
@export var gravity := 1500.0
@export var ui_display_time := 2.5

@export_group("Platforming")
@export var jump_force_base := 450.0
@export var coyote_time_duration := 0.15
@export var wall_rejump_window := 0.20

@export_group("Abilities")
@export var charge_cooldown := 2.0
@export var glide_gravity_mult := 0.03
@export var glide_max_fall_speed := 80.0
@export var glide_horizontal_speed := 300.0
@export var rock_gravity_mult := 1.2
@export var rock_speed_mult := 0.85
@export var rock_smash_fall_speed := 1200.0
@export var invincibility_duration := 1.5

# --- Jump Height Multipliers ---
@export_subgroup("Jump Multipliers")
@export var jump_mult_default := 1.0
@export var jump_mult_feather := 1.1
@export var jump_mult_gum := 1.2
@export var jump_mult_rock := 0.85

@export_subgroup("Air Jump Multipliers")
@export var air_jump_feather := 1.3
@export var air_jump_gum := 1.2

# --- State Variables ---
var ability_charges := 3.0
var max_ability_charges := 3.0
var current_health: int
var max_health: int
var charge_recovery_timer := 0.0
var charge_time := 0.0
var coyote_timer := 0.0
var last_ability_press_time := 0.0
var last_wall_normal := Vector2.ZERO
var can_execute_launch := false
var wall_rejump_timer := 0.0
var wall_rejump_duration := 0.2 
var air_jump_stomp_timer := 0.0 #

var current_set_id: int = Set.DEFAULT
var is_facing_right := true
var is_charging := false
var is_gliding := false
var is_rock_smashing := false
var is_invincible := false
var is_dying := false
var input_enabled := false

var ability_icons = []
var unlocked_masks: Dictionary: get = _get_unlocked_masks

# --- Data Store ---
var set_data = {
	Set.DEFAULT: {
		"color": Color.WHITE,
		"mask": preload("res://entities/player/assets/mask_default.png"),
		"cape": preload("res://entities/player/assets/cape_default.png"),
		"mask_pos": Vector2(7, -17),
		"mask_scale": Vector2(0.114, 0.122)
	},
	Set.FEATHER: {
		"color": Color(0.0, 0.729, 0.388),
		"mask": preload("res://entities/player/assets/mask_feather.png"),
		"cape": preload("res://entities/player/assets/cape_feather.png"),
		"mask_pos": Vector2(6, -20),
		"mask_scale": Vector2(0.214, 0.239),
		"bar_p": preload("res://entities/player/assets/bar_feather.png"),
		"bar_u": preload("res://entities/player/assets/bar_feather_dim.png")
	},
	Set.GUM: {
		"color": Color(1.0, 0.5, 0.8),
		"mask": preload("res://entities/player/assets/mask_gum.png"),
		"cape": preload("res://entities/player/assets/cape_gum.png"),
		"mask_pos": Vector2(10.56, -12.632),
		"mask_scale": Vector2(0.14, 0.151),
		"bar_p": preload("res://entities/player/assets/bar_gum.png"),
		"bar_u": preload("res://entities/player/assets/bar_gum_dim.png")
	},
	Set.ROCK: {
		"color": Color(0.5, 0.5, 0.5),
		"mask": preload("res://entities/player/assets/mask_rock.png"),
		"cape": preload("res://entities/player/assets/cape_rock.png"),
		"mask_pos": Vector2(10, -16),
		"mask_scale": Vector2(0.16, 0.135),
		"bar_p": preload("res://entities/player/assets/bar_rock.png"),
		"bar_u": preload("res://entities/player/assets/bar_rock_dim.png")
	}
}

# --- Initialization ---
func _ready() -> void:
	self.modulate = Color.WHITE
	visuals.modulate = Color.WHITE
	visuals.rotation_degrees = 0
	visuals.scale = Vector2.ONE
	
	if not Global.isTitleShown:
		reset_visuals_after_travel()
		set_process_input(true)
		
		is_invincible = true
		var original_mask = collision_mask
		collision_mask = 1
		
		visuals.modulate = Color(3.0, 3.0, 3.0, 1.0)
		var flash_tween = create_tween()
		flash_tween.tween_property(visuals, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
		
		get_tree().create_timer(1.5).timeout.connect(func():
			is_invincible = false
			collision_mask = original_mask
		)
	else:
		hide()
		set_process_input(false)
	
	current_health = Global.current_health
	max_health = Global.max_health_limit
	health_changed.emit(current_health)
	
	_reset_states()
	_setup_idle_animation()

	await get_tree().process_frame
	masks_updated.emit(unlocked_masks)
	
	if ability_container:
		ability_icons = ability_container.get_children()

func _setup_idle_animation() -> void:
	var tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(visuals, "position:y", -5.0, 0.8).as_relative()
	tween.tween_property(visuals, "position:y", 5.0, 0.8).as_relative()

func reset_visuals_after_travel(portal_pos: Vector2 = Vector2.ZERO, target_pos: Vector2 = Vector2.ZERO, force_face_right: bool = false) -> void:
	var player_tweens = create_tween()
	player_tweens.kill()
	
	if force_face_right:
		is_facing_right = true
		visuals.scale.x = 1.0
	
	input_enabled = false
	
	if portal_pos != Vector2.ZERO:
		global_position = portal_pos
	
	self.scale = Vector2.ZERO
	self.modulate.a = 0.0
	show()
	set_physics_process(true)
	set_process_input(true)
	visuals.rotation = 0
	
	var appear_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if target_pos != Vector2.ZERO:
		appear_tween.tween_property(self, "global_position", target_pos, 0.4).set_delay(0.1)
	
	appear_tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_delay(0.1)
	appear_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_delay(0.1)
	
	if visuals.has_node("Goma"):
		var goma_sprite = visuals.get_node("Goma")
		goma_sprite.modulate.a = 1.0
		goma_sprite.scale = Vector2(0.166, 0.174)

	appear_tween.finished.connect(func():
		input_enabled = true
	)
	
# --- Physics Process ---

func _physics_process(delta: float) -> void:
	if get_tree().paused or is_dying: return

	if air_jump_stomp_timer > 0:
		air_jump_stomp_timer -= delta
		
	_handle_resource_regen(delta)

	if is_top_down:
		_process_top_down_movement(delta)
	else:
		_process_platformer_movement(delta)

	move_and_slide()
	_apply_physics_visuals(delta)

# --- Movement Logic ---

func _process_top_down_movement(delta: float) -> void:
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity = input_vector * speed
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_pos = get_global_mouse_position()
		if global_position.distance_to(mouse_pos) > 15:
			target_velocity = global_position.direction_to(mouse_pos) * speed
			
	if target_velocity.x != 0:
		is_facing_right = target_velocity.x > 0
		
	velocity = velocity.lerp(target_velocity, 15.0 * delta)
	visuals.rotation = 0

func _process_platformer_movement(delta: float) -> void:
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	var is_near_wall = (is_on_wall() or wall_rejump_timer > 0) and velocity.y >= -50
	
	if is_on_wall() and velocity.y >= -50:
		wall_rejump_timer = wall_rejump_duration
		last_wall_normal = get_wall_normal()
	else:
		wall_rejump_timer -= delta
		
	if not is_rock_smashing and input_vector.x != 0:
		is_facing_right = input_vector.x > 0

	_handle_ability_logic(delta, input_vector, is_on_floor(), is_near_wall)

	if not is_on_floor():
		coyote_timer -= delta
		var gravity_step = gravity
		
		if current_set_id == Set.ROCK:
			gravity_step *= rock_gravity_mult
		elif current_set_id == Set.FEATHER:
			gravity_step *= glide_gravity_mult if (is_gliding and ability_charges > 0) else 0.7
		
		if is_on_wall() and input_vector.x != 0 and velocity.y > 0:
			gravity_step *= 0.5
			
		velocity.y += gravity_step * delta
		
		if is_gliding and velocity.y > glide_max_fall_speed:
			velocity.y = glide_max_fall_speed
	else:
		coyote_timer = coyote_time_duration
		if velocity.y > 0: velocity.y = 0
		_handle_landing_logic()

	if not is_charging and not is_rock_smashing:
		var move_speed = speed
		if current_set_id == Set.ROCK:
			move_speed *= (1.4 if is_on_floor() and input_vector.x != 0 else rock_speed_mult)
		
		var target_x = input_vector.x * (glide_horizontal_speed if is_gliding and ability_charges > 0 else move_speed)
		var accel = 8.0 if is_gliding else 15.0
		velocity.x = lerp(velocity.x, target_x, accel * delta)

# ---  Ability Core Logic ---
func _handle_ability_logic(delta: float, input_vector: Vector2, can_jump: bool, is_near_wall: bool) -> void:
	if not input_enabled: return
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if Input.is_action_just_pressed("ability"):
		if current_time - last_ability_press_time < DOUBLE_TAP_WINDOW:
			if current_set_id == Set.ROCK and ability_charges >= 1.0:
				if not can_jump: trigger_rock_smash()
			last_ability_press_time = 0
		else:
			last_ability_press_time = current_time
			if current_set_id == Set.FEATHER and can_jump:
				perform_regular_jump()
			elif can_jump or is_near_wall:
				is_charging = true
				charge_time = 0.0

	if Input.is_action_pressed("ability"):
		if (can_jump or is_near_wall) and not is_rock_smashing and not is_gliding:
			_process_jump_charge(delta)
		elif not can_jump and not is_near_wall and current_set_id == Set.FEATHER and ability_charges > 0:
			if velocity.y > -150:
				_process_feather_glide(delta, input_vector)
				is_charging = false
				GlobalAudioManager.stop_charge_sound()
	else:
		is_gliding = false
		feather_particles.emitting = false

	if Input.is_action_just_released("ability"):
		if is_charging:
			if charge_time > CHARGE_THRESHOLD:
				execute_jump_launch(1.0 if is_facing_right else -1.0, input_vector)
			elif can_jump or is_near_wall:
				perform_regular_jump()
		else:
			if not can_jump and not is_near_wall:
				if current_set_id == Set.FEATHER and ability_charges >= 0.33:
					ability_charges -= 0.33
					perform_air_jump()
				elif current_set_id == Set.GUM and ability_charges >= 1.0:
					ability_charges -= 1.0
					perform_air_jump()
					
		_reset_temp_ability_states()

# --- Ability Actions & Feedback ---

func trigger_hit_stop(duration: float, time_scale: float):
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration * time_scale).timeout
	Engine.time_scale = 1.0

func bounce_off_enemy(force: float = -500.0, enemy_pos: Vector2 = Vector2.ZERO):
	# SNAP: If we have an enemy position, put Goma right on top before bouncing
	if enemy_pos != Vector2.ZERO:
		global_position.y = enemy_pos.y - 30 
		
	velocity.y = force
	coyote_timer = coyote_time_duration
	is_rock_smashing = false
	
	# Visual FeedBack: Air Whiff Effect
	play_air_whiff_effect()
	
	# STOMP ANIMATION: Squash and stretch
	var flip = 1.0 if is_facing_right else -1.0
	visuals.scale = Vector2(1.4 * flip, 0.6)
	create_tween().tween_property(visuals, "scale", Vector2(1.0 * flip, 1.0), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func play_air_whiff_effect():
	# Use the smoke particles to create a flat Ring of Air
	if smoke:
		smoke.modulate = Color(1, 1, 1, 0.4) # Faded white air
		smoke.restart()
		smoke.emitting = true
		
		# Animation: Air expands wide and flat
		var whiff = create_tween()
		smoke.scale = Vector2(0.2, 0.2)
		whiff.tween_property(smoke, "scale", Vector2(3.0, 0.1), 0.15).set_trans(Tween.TRANS_QUINT)
		whiff.tween_property(smoke, "modulate:a", 0.0, 0.1)

func perform_air_jump() -> void:
	var final_mult := 1.0
	if current_set_id == Set.FEATHER:
		final_mult = air_jump_feather
	elif current_set_id == Set.GUM:
		final_mult = air_jump_gum

	velocity.y = -jump_force_base * final_mult
	air_jump_stomp_timer = 0.2
	GlobalAudioManager._play_sfx(GlobalAudioManager.jump_sfx, -2.0, true)
	
	show_ability_ui()
	play_smoke_effect(set_data[current_set_id]["color"], Vector2(0, 50))
	
	if current_set_id == Set.FEATHER:
		feather_particles.emitting = true
		feather_particles.restart()
		
	apply_launch_stretch(1.0 if is_facing_right else -1.0)

func _process_feather_glide(delta: float, input_vec: Vector2) -> void:
	if not is_gliding:
		GlobalAudioManager.play_glide_sound() 
	is_gliding = true
	feather_particles.emitting = true
	feather_particles.position.y = 50.0

	var drain_rate = 0.5 if input_vec.x == 0 else 0.9
	ability_charges = max(0, ability_charges - delta * drain_rate)
	show_ability_ui()

	velocity.x = move_toward(velocity.x, input_vec.x * glide_horizontal_speed, 15.0)
	
	visuals.rotation = lerp_angle(visuals.rotation, input_vec.x * 0.3, 4.0 * delta)
	visuals.position.y += sin(Time.get_ticks_msec() * 0.01) * 0.2
	
	if velocity.y > glide_max_fall_speed:
		velocity.y = glide_max_fall_speed

func trigger_rock_smash() -> void:
	if is_rock_smashing: return 
	
	is_rock_smashing = true
	is_gliding = false
	velocity.x = 0
	
	ability_charges = max(0, ability_charges - 0.5) 
	show_ability_ui()
	
	var flip = 1.0 if is_facing_right else -1.0
	
	var tween = create_tween()
	tween.tween_property(visuals, "scale", Vector2(1.3 * flip, 0.7), 0.1)
	
	velocity.y = -200
	
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_rock_smashing: 
			velocity.y = rock_smash_fall_speed
			var slam_tween = create_tween()
			slam_tween.tween_property(visuals, "scale", Vector2(0.7 * flip, 1.4), 0.1)
	)

# --- Resource Management ---

func _handle_resource_regen(delta: float) -> void:			
	if ability_charges < max_ability_charges and not (is_gliding or is_charging or is_rock_smashing):
		charge_recovery_timer += delta
		if charge_recovery_timer >= charge_cooldown:
			ability_charges = min(ability_charges + 1, max_ability_charges)
			charge_recovery_timer = 0.0
			update_ability_visuals()

# --- Health System ---

func take_damage(amount: int) -> void:
	if Global.is_restarting or is_invincible or is_dying:
		return
		
	if current_set_id == Set.ROCK:
		amount = maxi(1, int(amount * 0.5))
	GlobalAudioManager._play_sfx(GlobalAudioManager.hurt_sfx)
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

func update_health(value):
	Global.current_health = clamp(value, 0, Global.max_health_limit)
	health_changed.emit(Global.current_health)
	if Global.current_health <= 0:
		trigger_game_over()
		
func heal(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)
	Global.current_health = current_health
	health_changed.emit(current_health)
	
# --- Combat & Feedback ---

func execute_shockwave() -> void:
	blast_zone.monitoring = true
	await get_tree().physics_frame
	
	for area in blast_zone.get_overlapping_areas():
		var target = area if area.has_method("take_damage") else area.get_parent()
		if target.has_method("take_damage") and not target.is_in_group("player"):
			target.take_damage(1)
			
	blast_zone.monitoring = false
	
	if shockwave_particles:
		shockwave_particles.emitting = true
		shockwave_particles.restart()

	var cam = get_node_or_null("Camera2D")
	if cam:
		var shake = create_tween()
		for i in 5:
			shake.tween_property(cam, "offset", Vector2(randf_range(-10,10), randf_range(-10,10)), 0.04)
		shake.tween_property(cam, "offset", Vector2.ZERO, 0.04)

# --- Set / Mask System ---

func change_set(id: int, silent: bool = false) -> void:
	if id == current_set_id or not set_data.has(id): return
	
	var mask_names = { Set.FEATHER: "feather", Set.GUM: "gum", Set.ROCK: "rock" }
	if id != Set.DEFAULT and not Global.is_mask_unlocked(mask_names[id]):
		return

	current_set_id = id
	Global.current_equipped_set = id
	var data = set_data[id]
	
	if not silent:
		GlobalAudioManager._play_sfx(GlobalAudioManager.mask_switch_sfx)
		play_smoke_effect(data["color"], Vector2.ZERO)
	
	mask.texture = data["mask"]
	mask.position = data["mask_pos"]
	mask.scale = data["mask_scale"]
	cape.texture = data["cape"]
	_reset_states()

# --- UI & Visuals ---

func update_ability_visuals() -> void:
	if current_set_id == Set.DEFAULT or !set_data[current_set_id].has("bar_p"):
		ability_ui.modulate.a = 0.0
		return
	
	var data = set_data[current_set_id]
	for i in ability_icons.size():
		var icon = ability_icons[i]
		icon.texture_progress = data["bar_p"]
		icon.texture_under = data["bar_u"]
		icon.value = clamp(ability_charges - i, 0.0, 1.0) * 100

func show_ability_ui() -> void:
	if current_set_id == Set.DEFAULT: return
	update_ability_visuals()
	ability_ui.modulate.a = 1.0
	get_tree().create_timer(ui_display_time).timeout.connect(func():
		create_tween().tween_property(ability_ui, "modulate:a", 0.0, 0.5)
	)

# --- Internal Helpers ---

func _get_unlocked_masks() -> Dictionary: return Global.unlocked_masks

func _reset_states() -> void:
	is_gliding = false
	is_rock_smashing = false
	is_charging = false
	charge_time = 0.0
	visuals.rotation = 0

func _reset_temp_ability_states() -> void:
	is_gliding = false
	is_charging = false
	charge_time = 0.0
	feather_particles.emitting = false
	GlobalAudioManager.stop_glide_sound()
	GlobalAudioManager.stop_charge_sound()
	
func _get_current_jump_mult() -> float:
	match current_set_id:
		Set.FEATHER: return jump_mult_feather
		Set.GUM: return jump_mult_gum
		Set.ROCK: return jump_mult_rock
		_: return jump_mult_default
		
func die() -> void:
	var existing_tweens = get_tree().get_processed_tweens()
	for t in existing_tweens:
		if t.is_valid():
			t.kill()
	if is_dying: return
	is_dying = true

	set_physics_process(false)
	set_process_input(false)
	get_tree().paused = true

	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(visuals, "rotation_degrees", 90, 0.15)
	tween.tween_property(visuals, "modulate", Color.DARK_SLATE_GRAY, 0.5)

	tween.finished.connect(func():
		visuals.modulate = Color.WHITE
		Global.trigger_game_over_ui()
	)

func trigger_game_over():
	get_tree().paused = true
	var go_scene = load("res://gameover/game_over.tscn").instantiate()
	get_tree().root.add_child(go_scene)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: change_set(Set.DEFAULT)
			KEY_2: change_set(Set.FEATHER)
			KEY_3: change_set(Set.GUM)
			KEY_4: change_set(Set.ROCK)

func _handle_landing_logic() -> void:
	if Global.isTitleShown:
		is_rock_smashing = false 
		return
		
	if is_rock_smashing:
		execute_shockwave()
		is_rock_smashing = false
		apply_landing_squash()
		GlobalAudioManager._play_sfx(GlobalAudioManager.rock_slam_sfx)
	elif velocity.y >= 0:
		if abs(visuals.rotation) > 0.01:
			var reset_tween = create_tween()
			reset_tween.tween_property(visuals, "rotation", 0.0, 0.1)
			GlobalAudioManager._play_sfx(GlobalAudioManager.land_sfx, -10.0)
	
func perform_regular_jump() -> void:
	velocity.y = -jump_force_base * _get_current_jump_mult()
	GlobalAudioManager._play_sfx(GlobalAudioManager.jump_sfx)
	apply_launch_stretch(1.0 if is_facing_right else -1.0)	

func _process_jump_charge(delta: float) -> void:
	if charge_time == 0:
		GlobalAudioManager.play_charge_sound() 
		
	is_charging = true
	can_execute_launch = true
	charge_time = min(charge_time + delta * (4.5 if current_set_id == Set.GUM else 2.5), 1.0)
	
	var side = 1.0 if is_facing_right else -1.0
	visuals.scale.y = lerp(visuals.scale.y, 0.6, 10 * delta)
	visuals.scale.x = lerp(visuals.scale.x, 1.4 * side, 10 * delta)
	velocity.x = lerp(velocity.x, 0.0, 10 * delta)

func execute_jump_launch(f_dir: float, input_vec: Vector2) -> void:
	var base_power = 1.2 + (charge_time * 1.0)
	var multiplier = _get_current_jump_mult()
				
	velocity.y = -jump_force_base * base_power * multiplier
	if input_vec.x != 0:
		velocity.x = input_vec.x * speed * base_power
	GlobalAudioManager._play_sfx(GlobalAudioManager.jump_sfx)
	apply_launch_stretch(f_dir)

func apply_launch_stretch(f_dir: float) -> void:
	var tween = create_tween()
	tween.tween_property(visuals, "scale", Vector2(0.8 * f_dir, 1.2), 0.1)
	tween.tween_property(visuals, "scale", Vector2(1.0 * f_dir, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC)

func apply_landing_squash() -> void:
	var flip = 1.0 if is_facing_right else -1.0
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	visuals.scale = Vector2(1.3 * flip, 0.7)
	tween.tween_property(visuals, "scale", Vector2(1.0 * flip, 1.0), 0.5)

func _apply_physics_visuals(delta: float) -> void:
	var side = 1.0 if is_facing_right else -1.0
	
	if is_top_down:
		visuals.scale = Vector2(side, 1.0)
		return
	
	if not is_charging:
		visuals.scale.x = side
	else:
		visuals.scale.x = abs(visuals.scale.x) * side
	
	if not is_charging and not is_rock_smashing:
		visuals.scale.y = move_toward(visuals.scale.y, 1.0, 10 * delta)
	
	if not is_gliding:
		visuals.rotation = move_toward(visuals.rotation, 0, 10 * delta)
		
	if not is_on_floor() and velocity.y > 0 and not is_gliding:
		# Visual Cue: Tilt forward 15 degrees while falling
		visuals.rotation = lerp_angle(visuals.rotation, side * 0.15, 5 * delta)
		
func start_invincibility_effect() -> void:
	var blink = create_tween().set_loops(int(invincibility_duration / 0.2))
	blink.tween_property(visuals, "modulate:a", 0.3, 0.1)
	blink.tween_property(visuals, "modulate:a", 1.0, 0.1)

func collect_mask(mask_name: String) -> void:
	Global.unlock_mask(mask_name)
	var name_to_id = { "feather": Set.FEATHER, "gum": Set.GUM, "rock": Set.ROCK }
	if name_to_id.has(mask_name):
		change_set(name_to_id[mask_name])
	masks_updated.emit(unlocked_masks)
	
func play_smoke_effect(color: Color, offset: Vector2) -> void:
	if smoke:
		smoke.modulate = color
		smoke.position = offset
		smoke.emitting = true
		smoke.restart()
