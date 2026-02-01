extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("The Pyramid!")
	#await get_tree().root.child_entered_tree  # Wait tree ready
	
	add_child(Global.player)
	Global.player.is_top_down = false
	Global.player.global_position = Vector2(60, 480) 
	
	add_child(Global.hud)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
