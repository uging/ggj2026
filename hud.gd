extends CanvasLayer

@onready var heart_container = $HeartContainer
@onready var mask_container = $MaskContainer

# Preload the heart image you just created
var heart_texture = preload("res://assets/character/heart.png") 
var mask_textures = {
	"feather": preload("res://assets/character/mask_feather.png"),
	"gum": preload("res://assets/character/mask_gum.png"),
	"rock": preload("res://assets/character/mask_rock.png")
}

func _ready():
	# Find the player in the scene and connect to their signal
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(update_hearts)
		# Connect to our new mask signal
		player.masks_updated.connect(update_masks)
		update_hearts(player.current_health)
		update_masks(player.unlocked_masks)

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
		
func update_masks(unlocked_dict: Dictionary):
	if mask_container == null: return

	# Clear old icons
	for child in mask_container.get_children():
		child.queue_free()
	
	# Mapping mask names to their assigned number keys
	var mask_keys = { "default": "1", "feather": "2", "gum": "3", "rock": "4" }
	
	# 1. Always show the Default Mask (Key 1)
	_add_mask_slot(preload("res://assets/character/mask_default.png"), "1")
	
	# 2. Loop through collected masks
	for mask_name in unlocked_dict:
		if unlocked_dict[mask_name] == true:
			_add_mask_slot(mask_textures[mask_name], mask_keys[mask_name])


func _add_mask_slot(tex: Texture2D, key_text: String):
	var slot = VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# REDUCE SPACE: This moves the number closer to the mask icon
	slot.add_theme_constant_override("separation", -2) 

	# Create the Icon
	var rect = TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(40, 40)
	
	# Create the Number Label
	var label = Label.new()
	label.text = key_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16) # Slightly larger for readability
	
	# OUTLINE/SHADOW: This makes white text visible on light backgrounds
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_color", Color.WHITE)
	
	slot.add_child(rect)
	slot.add_child(label)
	mask_container.add_child(slot)
