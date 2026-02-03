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
	

func set_volume(percentage: float):
	# Percentage should be 0.0 to 1.0
	# We convert linear volume (0-1) to Decibels, which Godot uses
	var db_volume = linear_to_db(percentage)
	var bus_index = AudioServer.get_bus_index("Master")
	
	AudioServer.set_bus_volume_db(bus_index, db_volume)
	
	# Mute automatically if volume is 0
	AudioServer.set_bus_mute(bus_index, percentage <= 0)

func toggle_mute(is_muted: bool):
	var bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_index, is_muted)
