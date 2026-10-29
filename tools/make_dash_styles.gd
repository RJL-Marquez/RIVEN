extends SceneTree
# One-shot: generate the maneuver (.tres) assets. Run headlessly AFTER an editor
# scan has registered the DashStyle class:
#   Godot --headless --path <project> --script res://tools/make_dash_styles.gd

const DIR := "res://actors/fighter/moves"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	#     file         kind          speed  time  recov  up     spin  anim
	_save("lunge",      "lunge",      480.0, 0.22, 0.16,  0.0,   0.0,  "dash/lunge")
	_save("handspring", "handspring", 480.0, 0.50, 0.12,  0.0,   1.0,  "dash/handspring")
	_save("air_flip",   "airflip",    320.0, 0.0,  0.10,  420.0, 1.0,  "jumpmove/airflip")
	_save("roll_fwd",   "roll",       340.0, 0.52, 0.14,  0.0,   1.0,  "crouchmove/roll")
	_save("roll_back",  "roll",       360.0, 0.46, 0.12,  0.0,   1.0,  "crouchmove/roll")
	print("RIVEN moves saved")
	quit()

func _save(fname: String, kind: String, speed: float, time: float, recovery: float, up: float, spin: float, anim: String) -> void:
	var m := DashStyle.new()
	m.kind = kind
	m.speed = speed
	m.time = time
	m.recovery = recovery
	m.up = up
	m.spin = spin
	m.anim = anim
	ResourceSaver.save(m, DIR + "/" + fname + ".tres")
