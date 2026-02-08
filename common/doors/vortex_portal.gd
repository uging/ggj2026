extends Node2D

@export_group("Settings")
@export var next_scene_path: String = "res://levels/world_map.tscn"
@export var spawn_pos: Vector2 = Vector2(656, 318)
@export var is_credits_portal: bool = false

@export_group("Animation")
@export var activation_distance := 400.0
@export var max_scale := 2.0
@export var min_scale := 0.5

@onready var sprite = $Sprite2D
@onready var trigger_area = $TriggerArea

var active_suck_tween: Tween = null

func _ready() -> void:
	trigger_area.body_entered.connect(_on_portal_entered)

func _process(delta: float) -> void:
	if is_instance_valid(Global.player):
		# 1. EMERGING SAFETY: If Goma is popping out, keep portal silent and dormant
		if not Global.player.input_enabled:
			GlobalAudioManager.update_portal_hum_volume(0.0)
			return 

		# 2. Distance Calculations
		var dist = global_position.distance_to(Global.player.global_position)
		var factor = 1.0 - clamp(dist / activation_distance, 0.0, 1.0)
		
		# 3. Audio Logic
		if factor > 0.05:
			GlobalAudioManager.start_portal_hum()
			GlobalAudioManager.update_portal_hum_volume(factor)
		else:
			GlobalAudioManager.update_portal_hum_volume(0.0)
		
		# 4. Visual Feedback (Scale, Rotation, Opacity)
		apply_portal_shake(factor * 5.0)
		
		var target_scale = lerp(min_scale, max_scale, factor)
		sprite.scale = sprite.scale.lerp(Vector2(target_scale, target_scale), 5.0 * delta)
		
		var rotation_speed = lerp(0.0, 12.0, factor)
		sprite.rotation += rotation_speed * delta
		sprite.modulate.a = lerp(0.4, 1.0, factor)

func apply_portal_shake(intensity: float):
	if intensity <= 0.1: return # Don't process if too low
	
	if is_instance_valid(Global.player) and Global.player.has_node("Camera2D"):
		var camera = Global.player.get_node("Camera2D")
		# Direct offset shake
		camera.offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			
func _on_portal_entered(body):
	if body is CharacterBody2D and (body.name == "Player" or body == Global.player):
		if not body.input_enabled: 
			return
		GlobalAudioManager.fade_music(-80.0, 0.8)
		# 1. Start audio and freeze player
		GlobalAudioManager.update_portal_hum_volume(0.0)
		GlobalAudioManager.stop_portal_hum()
		GlobalAudioManager.play_portal_travel()
		
		_freeze_player_for_travel() 
		
		# 2. THE NEW STEP: Dissolve the portal sprite itself
		_dissolve_portal()
		
		if is_credits_portal:
			_handle_credits_transition()
		
		# 3. Wait for both player AND portal animations to finish
		await get_tree().create_timer(0.8).timeout
		
		if active_suck_tween and active_suck_tween.is_valid():
			active_suck_tween.kill()
		
		if is_instance_valid(Global.player) and Global.player.has_method("reset_visuals_after_travel"):
			Global.player.reset_visuals_after_travel()
		
		var main = get_tree().root.get_node_or_null("Main")
		if main and main.has_method("change_scene"):
			main.change_scene(next_scene_path, spawn_pos)

func _dissolve_portal():
	# Stop the _process loop from fighting the scale/rotation
	set_process(false)
	
	var dissolve = create_tween().set_parallel(true)
	# Shrink it to zero and spin it rapidly
	dissolve.tween_property(sprite, "scale", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	dissolve.tween_property(sprite, "modulate:a", 0.0, 0.5)
	dissolve.tween_property(sprite, "rotation", sprite.rotation + 15.0, 0.6)
	
func _freeze_player_for_travel():
	if is_instance_valid(Global.player):
		Global.player.set_physics_process(false)
		Global.player.set_process_input(false)
		Global.player.velocity = Vector2.ZERO
		
		# Visual Suck-in animation
		active_suck_tween = create_tween()
		active_suck_tween.tween_property(Global.player, "scale", Vector2.ZERO, 0.5)
		active_suck_tween.tween_property(Global.player, "modulate:a", 0.0, 0.5)
		
func _handle_credits_transition():
	if is_instance_valid(Global.hud): Global.hud.hide()
	Global.player.hide()
	Global.player.set_physics_process(false)
	Global.player.set_process_input(false)
	Global.player.velocity = Vector2.ZERO
