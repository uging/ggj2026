extends Node2D

var player: Node2D = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("The Forrest!")
	
# 1. Safely handle moving the player and HUD to this scene
	if Global.player.get_parent():
		Global.player.get_parent().remove_child(Global.player)
	add_child(Global.player)
	
	if Global.hud.get_parent():
		Global.hud.get_parent().remove_child(Global.hud)
	add_child(Global.hud)
	
# 2. Set player state
	Global.player.is_top_down = false
	Global.player.gravity = 1600
	Global.player.global_position = Vector2(600, 400)
	
# 3. --- CLEANUP COLLECTED MASKS ---
# This finds EVERY node in the scene tagged with the "pickups" group
	for item in get_tree().get_nodes_in_group("pickups"):
		print(item.name)
		# Check if it's a rock mask and player has it
		if "rock" in item.name.to_lower() and Global.player.unlocked_masks["rock"]:
			item.queue_free()
		# Check if it's a gum mask and player has it
		elif "gum" in item.name.to_lower() and Global.player.unlocked_masks["gum"]:
			item.queue_free()
		# Check if it's a feather mask and player has it
		elif "feather" in item.name.to_lower() and Global.player.unlocked_masks["feather"]:
			item.queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
