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

func _process(delta: float) -> void:
	if is_instance_valid(Global.player):
		var dist = global_position.distance_to(Global.player.global_position)
		
		# 1. Calculate Growth Factor (0.0 to 1.0)
		var factor = 1.0 - clamp(dist / activation_distance, 0.0, 1.0)
		
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
		var main = get_tree().root.get_node_or_null("Main")
		if main and main.has_method("change_scene"):
			# If this is the end of the game, hide the HUD and Player
			if is_credits_portal:
				Global.player.hide()
				Global.hud.hide()
			
			# Use the deferred manager helper to avoid physics crashes
			main.change_scene(next_scene_path, spawn_pos)
