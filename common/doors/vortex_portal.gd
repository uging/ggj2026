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

func _ready() -> void:
	# Cleanly connect the signal
	trigger_area.body_entered.connect(_on_portal_entered)
	GlobalAudioManager.start_portal_hum()

func _process(delta: float) -> void:
	if is_instance_valid(Global.player):
		var dist = global_position.distance_to(Global.player.global_position)
		
		# 1. Calculate Growth Factor (0.0 to 1.0)
		var factor = 1.0 - clamp(dist / activation_distance, 0.0, 1.0)
		GlobalAudioManager.update_portal_hum_volume(factor)
		
		# 2. Dynamic Scaling
		var target_scale = lerp(min_scale, max_scale, factor)
		sprite.scale = Vector2(target_scale, target_scale)
		
		# 3. Wild Rotation: Spins faster as Goma gets closer
		var rotation_speed = lerp(1.5, 12.0, factor)
		sprite.rotation += rotation_speed * delta
		
		# 4. Visual Intensity: Gets clearer as Goma gets closer
		sprite.modulate.a = lerp(0.3, 1.0, factor)

func _on_portal_entered(body):
	if body == Global.player:
		GlobalAudioManager.stop_portal_hum()
		GlobalAudioManager.play_portal_travel()
		var main = get_tree().root.get_node_or_null("Main")
		if main:
			# If this is the end of the game, lock down gameplay elements
			if is_credits_portal:
				# 1. Hide HUD immediately
				if is_instance_valid(Global.hud):
					Global.hud.hide()
				
				# 2. Kill Player Physics and Visibility
				# This stops the "Gameplay Goma" from falling or moving in the background
				Global.player.hide()
				Global.player.set_physics_process(false)
				Global.player.set_process_input(false)
				Global.player.velocity = Vector2.ZERO # Stop all momentum
			
			# 3. Transition to the scene path set in Inspector (Credits scene)
			if main.has_method("change_scene"):
				main.change_scene(next_scene_path, spawn_pos)
