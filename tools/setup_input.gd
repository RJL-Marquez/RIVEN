extends SceneTree
# One-shot setup script: registers RIVEN's abstract input actions into
# ProjectSettings, then saves project.godot. Run headlessly with:
#   Godot --headless --path <project> --script res://tools/setup_input.gd
# Keyboard bindings here are the PC iteration layer; the same action names
# will be driven by on-screen touch controls on mobile.

func _initialize() -> void:
	var actions := {
		"move_left":  [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump":       [KEY_W, KEY_UP, KEY_SPACE],
		"crouch":     [KEY_S, KEY_DOWN],
		"attack":     [KEY_J],
		"kick":       [KEY_K],
		"block":      [KEY_L],
		"magic":      [KEY_I],
	}
	for action in actions.keys():
		var events := []
		for kc in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = kc
			events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.5, "events": events})
	var err := ProjectSettings.save()
	print("RIVEN input setup saved, err=", err)
	quit()
