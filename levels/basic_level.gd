extends Node2D

var player: Node2D = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("The Forrest!")
	#await get_tree().root.child_entered_tree  # Wait tree ready
	
	add_child(Global.player)
	Global.player.is_top_down = false
	Global.player.gravity = 1600
	Global.player.global_position = Vector2(600, 400) 
	
	add_child(Global.hud)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
