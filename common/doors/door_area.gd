extends Area2D

# This door leads back to the map
@export var next_scene_path: String = "res://levels/world_map.tscn"
@export var spawn_position: Vector2 = Vector2(656, 318)

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body == Global.player:
		var main = get_tree().root.get_node_or_null("Main")
		if main and main.has_method("change_scene"):
			# Standard transition back to map
			main.change_scene(next_scene_path, spawn_position)
