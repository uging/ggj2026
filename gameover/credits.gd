# credits.gd
extends CanvasLayer

# Reference the CharacterControl you copied from GameOver
@onready var character_anchor = $CharacterControl/CharacterAnchor

func _ready():
	# 1. SYNC VISUALS: Match the gameplay Goma's current look
	_sync_equipment_visuals()
	
	# 2. Reset look to 'Alive'
	character_anchor.rotation_degrees = 0
	character_anchor.modulate = Color.WHITE
	
	# 3. Start decorative loops
	_start_patrol()
	_start_jump()
	
	$ButtonContainer/MainMenuButton.pressed.connect(_on_main_menu_button_pressed)
	$ButtonContainer/ExitButton.pressed.connect(_on_exit_button_pressed)

	# Let the player use the D-pad/Arrow keys immediately
	$ButtonContainer/MainMenuButton.grab_focus()

func _sync_equipment_visuals():
	# Get the real gameplay player from Global
	var real_player = Global.player
	if not is_instance_valid(real_player): return
	
	# Get the current set data from the real player
	var current_id = real_player.current_set_id
	var data = real_player.set_data[current_id]
	
	# Update the decorative sprites in the Credits scene
	var credits_body = character_anchor.get_node("Goma")
	var credits_mask = character_anchor.get_node("Mask")
	var credits_cape = character_anchor.get_node("Cape")
	
	# Body Sync: Match Gameplay Goma's Transform
	credits_body.position = Vector2(1.0, 0.0) 
	credits_body.scale = Vector2(0.166, 0.174)
	credits_body.show()
	credits_body.modulate.a = 1.0
	
	# Cape Sync: Match Gameplay Cape's Transform
	credits_cape.texture = data["cape"]
	credits_cape.position = Vector2(-19.625, 6.125) 
	credits_cape.scale = Vector2(0.172, 0.195)
	
	# Mask Sync: Match Gameplay Mask's Transform
	credits_mask.texture = data["mask"]
	credits_mask.position = data["mask_pos"]
	credits_mask.scale = data["mask_scale"]
	
func _start_patrol():
	var walk_tween = create_tween().set_loops()
	
	# Walk Right
	walk_tween.tween_callback(func(): character_anchor.scale.x = 1)
	walk_tween.tween_property(character_anchor, "position:x", 150, 2.0).as_relative().set_trans(Tween.TRANS_SINE)
	
	# Walk Left
	walk_tween.tween_callback(func(): character_anchor.scale.x = -1)
	walk_tween.tween_property(character_anchor, "position:x", -150, 2.0).as_relative().set_trans(Tween.TRANS_SINE)

func _start_jump():
	var jump_tween = create_tween().set_loops()
	jump_tween.tween_interval(3.5)
	
	# Pop Up
	jump_tween.tween_property(character_anchor, "position:y", -100, 0.4).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fall Down
	jump_tween.tween_property(character_anchor, "position:y", 100, 0.4).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_main_menu_button_pressed():
	Global.reset_player_stats()
	get_tree().change_scene_to_file("res://main/main.tscn")

func _on_exit_button_pressed():
	get_tree().quit()
