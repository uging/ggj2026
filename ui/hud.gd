extends CanvasLayer

@onready var heart_container = $HeartContainer
@onready var mask_container = $MaskContainer

var heart_texture = preload("res://assets/items/heart.png") 
var mask_textures = {
	"feather": preload("res://entities/player/assets/mask_feather.png"),
	"gum": preload("res://entities/player/assets/mask_gum.png"),
	"rock": preload("res://entities/player/assets/mask_rock.png")
}

func _ready() -> void:
	# Sync with Global data immediately on spawn
	update_hearts(Global.current_health)
	update_masks(Global.unlocked_masks)

# --- Signal Handlers (Connected by Main.gd) ---

func _on_health_changed(new_health: int):
	update_hearts(new_health)

func _on_masks_updated(unlocked_dict: Dictionary):
	update_masks(unlocked_dict)

# --- Setup logic for Main.gd ---

func setup_health(player_node):
	if player_node == null: return
	
	# Initial Draw from the specific player instance
	update_hearts(player_node.current_health)
	update_masks(Global.unlocked_masks)

# --- Visual Update Logic ---

func update_hearts(health: int):
	if not is_inside_tree() or heart_container == null: return

	# Clear existing
	for child in heart_container.get_children():
		child.free() # Using .free() here is safer for immediate redraws than queue_free()
	
	for i in range(health):
		var rect = TextureRect.new()
		rect.texture = heart_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.custom_minimum_size = Vector2(40, 40)
		heart_container.add_child(rect)
		
func update_masks(unlocked_dict: Dictionary):
	if not is_inside_tree() or mask_container == null: return

	# 1. Clear old icons immediately
	for child in mask_container.get_children():
		child.free() 
	
	var mask_keys = { "feather": "2", "gum": "3", "rock": "4" }
	
	# 2. Always show Default Mask
	_add_mask_slot(preload("res://entities/player/assets/mask_default.png"), "1")
	
	# 3. Add unlocked masks in a consistent order
	var order = ["feather", "gum", "rock"]
	for m_name in order:
		if unlocked_dict.get(m_name, false) and mask_textures.has(m_name):
			_add_mask_slot(mask_textures[m_name], mask_keys[m_name])

func _add_mask_slot(tex: Texture2D, key_text: String):
	var slot = VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", -2) 

	var rect = TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(40, 40)
	
	var label = Label.new()
	label.text = key_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	slot.add_child(rect)
	slot.add_child(label)
	mask_container.add_child(slot)
