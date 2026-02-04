extends Node

# --- Persistent Data ---
# These variables stay the same even when the scene reloads
var current_health : int = 3
var max_health_limit := 10
var current_equipped_set : int = 1 # is default
var isTitleShown := true

# traps and enemies storage so they don't reappear
var destroyed_enemies = {}

# Store the unlock states here so Goma keeps his powers after dying
var unlocked_masks = {
	"feather": true,
	"gum": true,
	"rock": true
}

# --- HUD & Player References ---
# We no longer instantiate them here. 
# We just keep variables to track the 'active' ones if needed.
var player = null
var hud = null

func _ready() -> void:
	# We leave this empty or just for initialization of basic data.
	# The Main script will now handle creating the Player and HUD nodes.
	print("Global data initialized.")
	
func set_volume(percentage: float):
	var bus_index = AudioServer.get_bus_index("Master")
	var db_volume = linear_to_db(percentage)
	
	AudioServer.set_bus_volume_db(bus_index, db_volume)
	
	# If volume is moved above 0, unmute. If at 0, mute.
	if percentage > 0:
		AudioServer.set_bus_mute(bus_index, false)
	else:
		AudioServer.set_bus_mute(bus_index, true)

func toggle_mute(is_muted: bool):
	var bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_index, is_muted)

func is_mask_unlocked(mask_name: String) -> bool:
	return unlocked_masks.get(mask_name, false)

func unlock_mask(mask_name: String):
	if unlocked_masks.has(mask_name):
		unlocked_masks[mask_name] = true
		if player and player.has_signal("masks_updated"):
			player.masks_updated.emit(unlocked_masks)
