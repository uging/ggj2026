extends Node

# --- Persistent Data ---
# These variables stay the same even when the scene reloads
var current_health : int = 3
var max_health_limit := 10
var current_equipped_set : int = 1 # is default
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
