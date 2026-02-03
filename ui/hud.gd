extends CanvasLayer

@onready var heart_container = $HeartContainer
@onready var mask_container = $MaskContainer

# Preload the heart image you just created
var heart_texture = preload("res://assets/items/heart.png") 
var mask_textures = {
	"feather": preload("res://entities/player/assets/mask_feather.png"),
	"gum": preload("res://entities/player/assets/mask_gum.png"),
	"rock": preload("res://entities/player/assets/mask_rock.png")
}

func _ready():
	# We leave this empty! Main.gd will call setup_health() 
	# as soon as the player is instantiated.
	pass
	
# This is called by Main.gd to safely link the player and HUD
func setup_health(player_node):
	if player_node == null: return
	
	# Connect Health
	if player_node.has_signal("health_changed"):
		if player_node.health_changed.is_connected(update_hearts):
			player_node.health_changed.disconnect(update_hearts)
		player_node.health_changed.connect(update_hearts)
	
	# Connect Masks
	if player_node.has_signal("masks_updated"):
		if player_node.masks_updated.is_connected(update_masks):
			player_node.masks_updated.disconnect(update_masks)
		player_node.masks_updated.connect(update_masks)
	
	# Initial Draw
	update_hearts(player_node.current_health)
	update_masks(player_node.unlocked_masks)
	
func update_hearts(health: int):
	# SAFETY: If the HUD is currently being deleted or hidden, stop here.
	# This prevents the "null instance" error during scene transitions.
	if not is_inside_tree() or heart_container == null: 
		return

	# 1. Clear existing hearts
	for child in heart_container.get_children():
		child.queue_free()
	
	# 2. Add new hearts based on current health
	for i in range(health):
		var rect = TextureRect.new()
		rect.texture = heart_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.custom_minimum_size = Vector2(40, 40)
		
		# Using call_deferred ensures the heart is added safely 
		# even if the physics engine is busy.
		heart_container.call_deferred("add_child", rect)
		
func update_masks(unlocked_dict: Dictionary):
	# SAFETY: Prevent updating if the HUD is being removed or scene is reloading
	if not is_inside_tree() or mask_container == null: 
		return

	# 1. Clear old icons
	for child in mask_container.get_children():
		child.queue_free()
	
	# Mapping mask names to their assigned number keys
	var mask_keys = { "default": "1", "feather": "2", "gum": "3", "rock": "4" }
	
	# 2. Always show the Default Mask (Key 1)
	_add_mask_slot(preload("res://entities/player/assets/mask_default.png"), "1")
	
	# 3. Loop through collected masks
	for mask_name in unlocked_dict:
		# Check if the mask is unlocked AND we have a texture for it
		if unlocked_dict[mask_name] == true and mask_textures.has(mask_name):
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
