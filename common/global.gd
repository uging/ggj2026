extends Node

# --- Persistent Data ---
var current_health : int = 3
var max_health_limit := 10
var current_equipped_set : int = 1
var isTitleShown := true
var is_restarting := false

# --- Level Bookmarking ---
# These store where the player is so Restart/Map buttons work
var last_level_path : String = ""
var last_spawn_pos : Vector2 = Vector2.ZERO

# traps and enemies storage
var destroyed_enemies = {}

# Powers unlock states
var unlocked_masks = {
	"feather": true,
	"gum": true,
	"rock": true
}

# --- HUD & Player References ---
var player = null
var hud = null

func _ready() -> void:
	print("Global data initialized.")
	
func trigger_game_over_ui():
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var go_scene = load("res://gameover/game_over.tscn").instantiate()
		main.get_node("UILayer").add_child(go_scene)
	else:
		var go_scene = load("res://gameover/game_over.tscn").instantiate()
		get_tree().root.add_child(go_scene)
	
	get_tree().paused = true

func set_volume(percentage: float):
	var bus_index = AudioServer.get_bus_index("Master")
	var db_volume = linear_to_db(percentage)
	AudioServer.set_bus_volume_db(bus_index, db_volume)
	
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

func reset_player_stats():
	current_health = 3
	is_restarting = true
	destroyed_enemies.clear()
	
	# Ensure the player instance (if it exists) is reset too
	if is_instance_valid(player):
		player.current_health = 3
		player.is_dying = false
		player.health_changed.emit(3) # Force HUD to show 3 hearts next time it's shown
	
	print("Global: Player stats reset.")
	# Unlock damage after a short delay (1 second after restart)
	get_tree().create_timer(1.0).timeout.connect(func(): is_restarting = false)
	print("Global: Player stats reset and damage locked.")
