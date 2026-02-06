extends Node

# Load your audio files
var hover_sfx = preload("res://resources/sounds/SwitchSound.ogg")
var click_sfx = preload("res://resources/sounds/SelectSound.ogg")
var open_sfx = preload("res://resources/sounds/doorOpen_1.ogg")
var close_sfx = preload("res://resources/sounds/doorClose_4.ogg")
var game_over_sfx = preload("res://resources/sounds/DeathSound.ogg") 
var portal_travel_sfx = preload("res://resources/sounds/laserLarge_004.ogg")

# Character SFX
var jump_sfx = preload("res://resources/sounds/Jump2.wav")
var land_sfx = preload("res://resources/sounds/Jump10.wav")
var dash_sfx = preload("res://resources/sounds/Jump1.wav")
var hurt_sfx = preload("res://resources/sounds/Hit_Hurt9.wav")
var rock_slam_sfx = preload("res://resources/sounds/Explosion7.wav")

var heart_sfx = preload("res://resources/sounds/Pickup_Coin3.wav")  # Healing sound
var mask_pickup_sfx = preload("res://resources/sounds/Powerup2.wav") # New mask found
var mask_switch_sfx = preload("res://resources/sounds/Powerup3.wav") # Power up / Switch

var charge_sfx = preload("res://resources/sounds/Laser_Shoot.wav") # Change to your charge file
var active_charge_player: AudioStreamPlayer = null
var glide_sfx = preload("res://resources/sounds/lowFrequency_explosion_000.ogg") # Replace with a wind/glide file
var active_glide_player: AudioStreamPlayer = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_recursive_scan(get_tree().root)

func _on_node_added(node: Node):
	_connect_logic(node)

func _recursive_scan(node: Node):
	for child in node.get_children():
		_connect_logic(child)
		_recursive_scan(child)

func _connect_logic(node: Node):
	if node is BaseButton:
		if not node.mouse_entered.is_connected(_play_sfx):
			node.mouse_entered.connect(_play_sfx.bind(hover_sfx))
		if not node.focus_entered.is_connected(_play_sfx):
			node.focus_entered.connect(_play_sfx.bind(hover_sfx))
		if not node.pressed.is_connected(_play_sfx):
			node.pressed.connect(_play_sfx.bind(click_sfx))
	
	# Immediate trigger for GameOver when it is created
	if node.name == "GameOver":
		_mute_music_bus(true)
		_play_sfx(game_over_sfx)
	
	# Keep visibility listener for PauseMenu and Close sounds
	if node.name == "PauseMenu" or node.name == "GameOver":
		if not node.visibility_changed.is_connected(_on_menu_visibility_changed):
			node.visibility_changed.connect(_on_menu_visibility_changed.bind(node))
	
	# 1. Heart Pickups (Healing)
	if node.name.contains("HeartPickup"):
		if node.has_signal("collected"):
			node.collected.connect(_play_sfx.bind(heart_sfx))
	# 2. Mask Item Pickups (Finding a new mask in the world)
	if node.name.contains("MaskPickup"):
		if node.has_signal("collected"):
			node.collected.connect(_play_sfx.bind(mask_pickup_sfx))

func _on_menu_visibility_changed(menu_node: Node):
	if menu_node.visible:
		# Only handle PauseMenu here; GameOver is handled immediately in _connect_logic
		if menu_node.name == "PauseMenu":
			_play_sfx(open_sfx)
	else:
		# Unmute music when the Game Over screen is hidden/freed
		if menu_node.name == "GameOver":
			_mute_music_bus(false)
		_play_sfx(close_sfx)

func _mute_music_bus(should_mute: bool):
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, should_mute)
	
	# NEW: If we are muting, physically stop any music nodes from playing
	if should_mute:
		_find_and_stop_music(get_tree().root)
		
func _find_and_stop_music(node: Node):
	for child in node.get_children():
		# This checks if the node is a music player on the Music bus
		if child is AudioStreamPlayer and child.bus == "Music":
			child.stop() 
		_find_and_stop_music(child) # Keep looking through the whole tree

func _play_sfx(sfx: AudioStream, volume: float = 0.0, randomize_pitch: bool = true):
	if sfx == null: return
	
	var asp = AudioStreamPlayer.new()
	asp.stream = sfx
	asp.volume_db = volume
	asp.bus = "SFX"
	
	if randomize_pitch:
		# Subtle pitch shift makes it feel less repetitive
		asp.pitch_scale = randf_range(0.9, 1.1) 
		
	asp.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)
	
func _on_portal_triggered(body: Node):
	if body == Global.player:
		_play_sfx(portal_travel_sfx)

# NEW: Helper functions to manage the charging loop
# Inside GlobalAudioManager.gd

func play_charge_sound():
	if active_charge_player == null:
		active_charge_player = AudioStreamPlayer.new()
		active_charge_player.stream = charge_sfx
		active_charge_player.bus = "SFX"
		active_charge_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(active_charge_player)
		active_charge_player.play()
	elif not active_charge_player.playing:
		active_charge_player.play()

func stop_charge_sound():
	# Stop and delete the player node when the charge is finished or cancelled
	if active_charge_player:
		active_charge_player.stop()
		active_charge_player.queue_free()
		active_charge_player = null


func play_glide_sound():
	if active_glide_player == null:
		active_glide_player = AudioStreamPlayer.new()
		active_glide_player.stream = glide_sfx
		active_glide_player.bus = "SFX"
		active_glide_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(active_glide_player)
		active_glide_player.play()
	elif not active_glide_player.playing:
		active_glide_player.play()

func stop_glide_sound():
	if active_glide_player:
		active_glide_player.stop()
		active_glide_player.queue_free()
		active_glide_player = null

func _on_heart_collected():
	_play_sfx(heart_sfx, -5.0) # Slightly quieter for hearts

func _on_mask_item_collected():
	_play_sfx(mask_pickup_sfx, 0.0) # Full volume for big discoveries
