class_name Fighter
extends CharacterBody2D
## Phase 1 fighter: grounded, deliberate movement with a tactical step-dash.
##
## An input-buffered state machine drives movement and tells the rig which pose
## to play. Combat states (attack / block / hit / KO) slot into the same enum
## and match block in later phases without restructuring this.
##
## Facing is OPPONENT-relative: the fighter always faces `opponent_path` (so it
## backpedals when moving away and only turns when the opponent crosses to its
## other side), never the direction of movement.

@export_group("Movement feel")
@export var walk_speed := 190.0        # deliberate, has mass
@export var gravity := 1250.0
@export var jump_velocity := -430.0    # low, heavy hop
@export var air_control := 0.6         # fraction of walk_speed usable midair

@export_group("Step-dash")
@export var dash_speed := 520.0
@export var dash_time := 0.14          # burst duration
@export var dash_recovery := 0.18      # locked recovery after the burst (commitment)
@export var double_tap_window := 0.22  # max gap between taps to trigger a dash

@export_group("Timing")
@export var land_time := 0.08          # brief landing recovery for weight
@export var prejump_time := 0.09       # wind-up dip before launch, for momentum

@export_group("Opponent")
@export var opponent_path: NodePath    # the fighter always faces this node

enum State { IDLE, WALK, CROUCH, PREJUMP, JUMP, DASH, LAND }

var facing := 1          # 1 = right, -1 = left
var state: State = State.IDLE

var _state_time := 0.0
var _dash_dir := 1
var _time := 0.0
var _last_tap := {-1: -999.0, 1: -999.0}
var _opponent: Node2D

@onready var rig: FighterRig = $Rig

func _ready() -> void:
	if opponent_path != NodePath(""):
		_opponent = get_node_or_null(opponent_path)

func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta

	if not is_on_floor():
		velocity.y += gravity * delta

	var move := Input.get_axis("move_left", "move_right")
	_detect_dash()

	match state:
		State.IDLE: _state_idle(move)
		State.WALK: _state_walk(move)
		State.CROUCH: _state_crouch(move)
		State.PREJUMP: _state_prejump()
		State.JUMP: _state_jump(move)
		State.DASH: _state_dash()
		State.LAND: _state_land()

	move_and_slide()
	_update_facing()
	_update_anim()

func state_name() -> String:
	return State.keys()[state]

# -------------------------------------------------------------- states ---

func _state_idle(move: float) -> void:
	velocity.x = 0.0
	if not is_on_floor():
		_set_state(State.JUMP); return
	if Input.is_action_just_pressed("jump"):
		_set_state(State.PREJUMP); return
	if Input.is_action_pressed("crouch"):
		_set_state(State.CROUCH); return
	if absf(move) > 0.1:
		_set_state(State.WALK)

func _state_walk(move: float) -> void:
	if not is_on_floor():
		_set_state(State.JUMP); return
	if Input.is_action_just_pressed("jump"):
		_set_state(State.PREJUMP); return
	if Input.is_action_pressed("crouch"):
		_set_state(State.CROUCH); return
	if absf(move) < 0.1:
		_set_state(State.IDLE); return
	velocity.x = move * walk_speed

func _state_crouch(move: float) -> void:
	velocity.x = 0.0
	if not Input.is_action_pressed("crouch"):
		_set_state(State.WALK if absf(move) > 0.1 else State.IDLE)

func _state_prejump() -> void:
	# Wind-up: plant and dip briefly, then launch. Gives the jump weight.
	velocity.x = 0.0
	if _state_time >= prejump_time:
		velocity.y = jump_velocity
		_set_state(State.JUMP)

func _state_jump(move: float) -> void:
	velocity.x = move * walk_speed * air_control
	if is_on_floor() and velocity.y >= 0.0:
		_set_state(State.LAND)

func _state_dash() -> void:
	# Commit: a quick burst, then a locked recovery you cannot act out of.
	if _state_time <= dash_time:
		velocity.x = _dash_dir * dash_speed
	elif _state_time <= dash_time + dash_recovery:
		velocity.x = 0.0
	else:
		_set_state(State.IDLE)

func _state_land() -> void:
	velocity.x = 0.0
	if _state_time >= land_time:
		_set_state(State.IDLE)

# -------------------------------------------------------------- helpers ---

func _set_state(s: State) -> void:
	state = s
	_state_time = 0.0

func _detect_dash() -> void:
	# Double-tap a direction (while grounded) to step-dash. Direction is pure
	# input (not facing), so a back-dash keeps you facing the opponent.
	if state == State.DASH or state == State.LAND or state == State.PREJUMP or not is_on_floor():
		return
	for dir in [-1, 1]:
		var action := "move_left" if dir == -1 else "move_right"
		if Input.is_action_just_pressed(action):
			if _time - _last_tap[dir] <= double_tap_window:
				_start_dash(dir)
			_last_tap[dir] = _time

func _start_dash(dir: int) -> void:
	_dash_dir = dir
	velocity.x = dir * dash_speed
	_set_state(State.DASH)

func _update_facing() -> void:
	# Always face the opponent; never turn just because we moved backward.
	if _opponent and is_instance_valid(_opponent):
		facing = -1 if _opponent.global_position.x < global_position.x else 1
	rig.scale.x = facing

func _update_anim() -> void:
	match state:
		State.WALK: rig.set_anim("walk")
		State.CROUCH: rig.set_anim("crouch")
		State.PREJUMP: rig.set_anim("prejump")
		State.JUMP: rig.set_anim("jump")
		State.DASH: rig.set_anim("dash")
		State.LAND: rig.set_anim("land")
		_: rig.set_anim("idle")
