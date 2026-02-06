extends Node

# Load your audio files
var hover_sfx = preload("res://resources/sounds/SwitchSound.ogg")
var click_sfx = preload("res://resources/sounds/SelectSound.ogg")
var open_sfx = preload("res://resources/sounds/doorOpen_1.ogg")
var close_sfx = preload("res://resources/sounds/doorClose_4.ogg")
var game_over_sfx = preload("res://resources/sounds/DeathSound.ogg") 

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
	
	# NEW: Immediate trigger for GameOver when it is created
	if node.name == "GameOver":
		_mute_music_bus(true)
		_play_sfx(game_over_sfx)
	
	# Keep visibility listener for PauseMenu and Close sounds
	if node.name == "PauseMenu" or node.name == "GameOver":
		if not node.visibility_changed.is_connected(_on_menu_visibility_changed):
			node.visibility_changed.connect(_on_menu_visibility_changed.bind(node))

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

func _play_sfx(sfx: AudioStream):
	if sfx == null: return
	var asp = AudioStreamPlayer.new()
	asp.stream = sfx
	asp.bus = "SFX"
	asp.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)
