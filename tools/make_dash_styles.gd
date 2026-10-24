extends SceneTree
# One-shot: generate the DashStyle .tres assets. Run headlessly AFTER an editor
# scan has registered the DashStyle class:
#   Godot --headless --path <project> --script res://tools/make_dash_styles.gd

const DIR := "res://actors/fighter/dash_styles"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	var step := DashStyle.new()
	step.kind = "step"; step.speed = 480.0; step.time = 0.13; step.recovery = 0.15
	step.anim = "dash"
	ResourceSaver.save(step, DIR + "/step.tres")

	var slide := DashStyle.new()
	slide.kind = "slide"; slide.speed = 650.0; slide.time = 0.20; slide.recovery = 0.22
	slide.anim = "dash"
	ResourceSaver.save(slide, DIR + "/slide.tres")

	var roll := DashStyle.new()
	roll.kind = "roll"; roll.speed = 540.0; roll.time = 0.34; roll.recovery = 0.16
	roll.spin = 1.0; roll.anim = "roll"
	ResourceSaver.save(roll, DIR + "/roll.tres")

	var flip := DashStyle.new()
	# Grounded back handspring (hands plant, feet over) — not an airborne launch.
	flip.kind = "flip"; flip.speed = 300.0; flip.time = 0.42; flip.recovery = 0.12
	flip.up = 0.0; flip.spin = 1.0; flip.anim = "flip"
	ResourceSaver.save(flip, DIR + "/flip.tres")

	# Default showcase: step forward, backflip out.
	var combo := DashStyle.new()
	combo.kind = "step"; combo.speed = 480.0; combo.time = 0.13; combo.recovery = 0.15
	combo.anim = "dash"
	combo.back_override = load(DIR + "/flip.tres")
	ResourceSaver.save(combo, DIR + "/step_flipout.tres")

	print("RIVEN dash styles saved")
	quit()
