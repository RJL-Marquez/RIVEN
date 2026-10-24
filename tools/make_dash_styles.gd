extends SceneTree
# One-shot: generate the maneuver (.tres) assets. Run headlessly AFTER an editor
# scan has registered the DashStyle class:
#   Godot --headless --path <project> --script res://tools/make_dash_styles.gd

const DIR := "res://actors/fighter/moves"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	#     file         kind          speed  time  recov  up     spin  anim
	_save("lunge",      "lunge",      360.0, 0.18, 0.14,  0.0,   0.0,  "lunge")
	_save("handspring", "handspring", 300.0, 0.50, 0.12,  0.0,   1.0,  "handspring")
	_save("air_flip",   "airflip",    280.0, 0.0,  0.10,  560.0, 1.0,  "airflip")
	_save("roll_fwd",   "roll",       420.0, 0.30, 0.12,  0.0,   1.0,  "roll")
	_save("roll_back",  "roll",       450.0, 0.24, 0.10,  0.0,   1.0,  "roll")
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
