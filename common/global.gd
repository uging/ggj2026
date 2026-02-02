extends Node

# --- Persistent Data ---
# These variables stay the same even when the scene reloads
var isTitleShown := true

# Store the unlock states here so Goma keeps his powers after dying
var unlocked_masks = {
	"feather": false,
	"gum": false,
	"rock": false
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
