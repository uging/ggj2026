extends CanvasLayer

@onready var heart_container = $HBoxContainer
# Preload the heart image you just created
var heart_texture = preload("res://assets/character/heart.png") 

func _ready():
	# Find the player in the scene and connect to their signal
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(update_hearts)
		update_hearts(player.current_health)

func update_hearts(health: int):
	# Clear existing hearts
	for child in heart_container.get_children():
		child.queue_free()
	
	# Add new hearts based on current health
	for i in range(health):
		var rect = TextureRect.new()
		rect.texture = heart_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.custom_minimum_size = Vector2(40, 40)
		heart_container.add_child(rect)
