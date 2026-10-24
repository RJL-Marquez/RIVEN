class_name Fighter
extends CharacterBody2D
## Phase 1 fighter. Movement, state machine, and the input-combo special moves
## live here; the POSES are authored visually in the AnimationPlayer (one
## animation per state: idle / walk / crouch / prejump / jump / land / lunge /
## handspring / airflip / roll). This script just plays the animation that
## matches the current state and moves the body.
##
## Input combos (relative to facing, which is opponent-relative):
##   double-tap forward / back -> lunge / back handspring
##   jump + forward / back     -> front / back flip
##   crouch + forward / back   -> front / back roll

@export_group("Movement feel")
@export var walk_speed := 190.0
@export var gravity := 1250.0
@export var jump_velocity := -430.0
@export var air_control := 0.6

@export_group("Timing")
@export var land_time := 0.08
@export var prejump_time := 0.09
@export var double_tap_window := 0.22

@export_group("Opponent")
@export var opponent_path: NodePath

@export_group("Maneuvers")
@export var move_lunge: DashStyle
@export var move_handspring: DashStyle
@export var move_air_flip: DashStyle
@export var move_roll_fwd: DashStyle
@export var move_roll_back: DashStyle

enum State { IDLE, WALK, CROUCH, PREJUMP, JUMP, MOVE, LAND }

const MOVES := "res://actors/fighter/moves/"

var facing := 1
var state: State = State.IDLE

var _state_time := 0.0
var _dash_dir := 1
var _active: DashStyle
var _launched := false
var _time := 0.0
var _last_tap := {-1: -999.0, 1: -999.0}
var _opponent: Node2D

@onready var rig: Node2D = $Rig
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if opponent_path != NodePath(""):
		_opponent = get_node_or_null(opponent_path)
	if move_lunge == null: move_lunge = load(MOVES + "lunge.tres")
	if move_handspring == null: move_handspring = load(MOVES + "handspring.tres")
	if move_air_flip == null: move_air_flip = load(MOVES + "air_flip.tres")
	if move_roll_fwd == null: move_roll_fwd = load(MOVES + "roll_fwd.tres")
	if move_roll_back == null: move_roll_back = load(MOVES + "roll_back.tres")

func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta
	if not is_on_floor():
		velocity.y += gravity * delta

	var move := Input.get_axis("move_left", "move_right")

	if (state == State.IDLE or state == State.WALK) and is_on_floor():
		_try_specials(move)

	match state:
		State.IDLE: _state_idle(move)
		State.WALK: _state_walk(move)
		State.CROUCH: _state_crouch(move)
		State.PREJUMP: _state_prejump()
		State.JUMP: _state_jump(move)
		State.MOVE: _state_move()
		State.LAND: _state_land()

	move_and_slide()
	_update_facing()
	_update_anim()

func state_name() -> String:
	return State.keys()[state]

# -------------------------------------------------------- special inputs ---

func _try_specials(move: float) -> bool:
	var d := -1 if move < 0.0 else 1
	var has_dir := absf(move) > 0.3

	for dir in [-1, 1]:
		var action := "move_left" if dir == -1 else "move_right"
		if Input.is_action_just_pressed(action):
			if _time - _last_tap[dir] <= double_tap_window:
				_start_move(move_lunge if dir == facing else move_handspring, dir)
				return true
			_last_tap[dir] = _time

	if has_dir and Input.is_action_just_pressed("jump"):
		_start_move(move_air_flip, d)
		return true

	if has_dir and Input.is_action_just_pressed("crouch"):
		_start_move(move_roll_fwd if d == facing else move_roll_back, d)
		return true

	return false

func _start_move(m: DashStyle, dir: int) -> void:
	_active = m
	_dash_dir = dir
	# Airborne moves (flips) wind up with a short crouch before launching.
	_launched = m.up <= 0.0
	velocity.x = (dir * m.speed) if m.up <= 0.0 else 0.0
	_set_state(State.MOVE)

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
	velocity.x = 0.0
	if _state_time >= prejump_time:
		velocity.y = jump_velocity
		_set_state(State.JUMP)

func _state_jump(move: float) -> void:
	velocity.x = move * walk_speed * air_control
	if is_on_floor() and velocity.y >= 0.0:
		_set_state(State.LAND)

func _state_move() -> void:
	var s := _active
	var airborne := s.up > 0.0

	if airborne and not _launched:
		velocity.x = 0.0
		if _state_time >= prejump_time:
			velocity.y = -s.up
			velocity.x = _dash_dir * s.speed
			_launched = true
		return

	if airborne:
		velocity.x = _dash_dir * s.speed
		if (_state_time - prejump_time) > 0.1 and is_on_floor() and velocity.y >= 0.0:
			_set_state(State.LAND)
	else:
		if _state_time <= s.time:
			velocity.x = _dash_dir * s.speed
		elif _state_time <= s.time + s.recovery:
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

func _update_facing() -> void:
	if _opponent and is_instance_valid(_opponent):
		facing = -1 if _opponent.global_position.x < global_position.x else 1
	rig.scale.x = facing

func _update_anim() -> void:
	var name := "idle"
	match state:
		State.WALK: name = "walk"
		State.CROUCH: name = "crouch"
		State.PREJUMP: name = "prejump"
		State.JUMP: name = "jump"
		State.LAND: name = "land"
		State.MOVE: name = (_active.anim if _active else "idle")
		_: name = "idle"
	_play(name)

func _play(anim_name: String) -> void:
	if anim.has_animation(anim_name) and anim.current_animation != anim_name:
		anim.play(anim_name)
