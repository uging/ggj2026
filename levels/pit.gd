extends Area2D

@export var target_position: Vector2 = Vector2(100, 100)  # Set in inspector

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	# Optional: Check if it's the player
	if body.name == "Player" or body.is_in_group("player"):
		Global.player.global_position = Vector2(60, 480) 
