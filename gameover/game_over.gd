extends CanvasLayer

# Get references to the nodes we need to animate
@onready var character_anchor = $ColorRect/CenterContainer/VBoxContainer/CharacterControl/CharacterAnchor
@onready var restart_btn = $ColorRect/CenterContainer/VBoxContainer/RestartButton
@onready var menu_btn = $ColorRect/CenterContainer/VBoxContainer/MenuButton

func _ready():
	# 1. IMPORTANT: Allow this node to run while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 2. Start with the "Dead" look (tilted, dim)
	character_anchor.rotation_degrees = 90
	character_anchor.modulate = Color(0.5, 0.5, 0.5)
	
	# 3. GRAB FOCUS: This enables arrow key navigation immediately
	# We wait one frame to ensure the UI is fully painted before grabbing focus.
	await get_tree().process_frame
	restart_btn.grab_focus()

func _on_restart_pressed():
	set_buttons_disabled(true)
	
	# 1. FORCE THE RESET IMMEDIATELY
	Global.reset_player_stats() 
	
	# 2. Animate Goma coming back to life
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(character_anchor, "rotation_degrees", 0, 0.5)
	tween.parallel().tween_property(character_anchor, "modulate", Color.WHITE, 0.3)
	
	await tween.finished
	
	# 3. Load the level WHILE still paused
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("load_level"):
		if Global.last_level_path != "":
			main.load_level(Global.last_level_path, Global.last_spawn_pos)
	
	# 4. FINALLY unpause and clear the overlay
	get_tree().paused = false
	queue_free()
	
func _on_menu_pressed():
	set_buttons_disabled(true)
	
	# Animate Goma falling away
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(character_anchor, "position:y", -100, 0.3).as_relative()
	tween.tween_property(character_anchor, "position:y", 500, 0.4).as_relative()
	
	await tween.finished
	
	# 1. Reset Global data for a fresh start
	Global.reset_player_stats() 
	Global.isTitleShown = true 
	
	# 2. Hide the HUD
	if is_instance_valid(Global.hud):
		Global.hud.hide()
	
	# 3. Unpause and go to the Main shell
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main/main.tscn")
	
	queue_free()

func set_buttons_disabled(state: bool):
	restart_btn.disabled = state
	menu_btn.disabled = state
