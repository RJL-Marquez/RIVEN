extends Node2D
## Phase 1 test arena: hosts one fighter and shows a live debug readout so we
## can tune the movement feel.

@onready var fighter: Fighter = $Fighter
@onready var debug: Label = $HUD/Debug

func _process(_delta: float) -> void:
	if not is_instance_valid(fighter):
		return
	debug.text = "RIVEN - Phase 1\nState: %s\nVel: (%+.0f, %+.0f)\nFacing: %s\nOn floor: %s\nFPS: %d" % [
		fighter.state_name(),
		fighter.velocity.x, fighter.velocity.y,
		("right" if fighter.facing >= 0 else "left"),
		str(fighter.is_on_floor()),
		Engine.get_frames_per_second(),
	]
