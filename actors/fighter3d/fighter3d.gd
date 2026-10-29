extends CharacterBody3D
## 2.5D fighter: a 3D body constrained to the 2D fighting plane (moves on X,
## jumps on Y, pinned to Z = 0), facing the opponent. The Mixamo character +
## its clips live under the Model node. Locomotion is a simple idle <-> walk
## (forward / backward), with the idle's fighting guard (arms + fists) blended
## onto the walking legs, fading in/out so there's no pop at idle <-> walk.

@export var speed := 1.0       # forward m/s — matches the Walking clip's stride
@export var back_speed := 1.1  # retreat m/s — matches the Walking Backwards clip
@export var gravity := 18.0
@export var jump_velocity := 7.0
@export var opponent_path: NodePath

## Height tweak: raise if the feet clip INTO the floor, lower (even negative)
## if they FLOAT above it. Editable in the Inspector.
@export var foot_offset := -0.02

const IDLE := "mixamo_com"       # Fight Idle clip baked into the character FBX
const INPUT_DEADZONE := 0.2
const BLEND := 0.15          # clip cross-fade time (idle <-> walk)
const GUARD_FADE := 6.5      # upper-body guard blend rate (~0.15s to full)

## The two sustained walk loops (exported from Mixamo, dropped in this folder).
const CLIPS := {
	"fwd_loop": "res://actors/fighter3d/Walking.fbx",
	"back_loop": "res://actors/fighter3d/Walking Backwards.fbx",
}
const UPPER_TOKENS := ["Spine", "Neck", "Head", "Shoulder", "Arm", "Hand"]

enum { S_IDLE, S_F_LOOP, S_B_LOOP }

var facing := 1
var _opponent: Node3D
var _skeleton: Skeleton3D
var _ap: AnimationPlayer
var _state := S_IDLE
var _clips_ok := {}

# Upper-body guard pose captured from the idle, re-applied over the walk.
var _upper_bones: Array[int] = []
var _hips_bone := -1
var _guard_pos := {}
var _guard_rot := {}
var _guard_captured := false
var _guard_weight := 0.0  # 0 = pure anim (idle), 1 = full guard (walking)

@onready var model: Node3D = $Model

func _ready() -> void:
	if opponent_path != NodePath(""):
		_opponent = get_node_or_null(opponent_path)
	var character := $Model/Character
	_ap = character.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_skeleton = character.get_node_or_null("Skeleton3D") as Skeleton3D
	if _ap:
		var idle := _ap.get_animation(IDLE)
		if idle:
			idle.loop_mode = Animation.LOOP_LINEAR
		for n in CLIPS:
			_register_clip(CLIPS[n], n)
		_ap.play(IDLE)
	_classify_bones()
	process_priority = 100  # pose overrides / ground clamp run after the anim

## Pull the single clip out of a Mixamo FBX and add it (looped) to THIS
## character's AnimationPlayer. Both share the mixamorig skeleton, so the bone
## tracks retarget automatically. Missing file = that walk just stays off.
func _register_clip(path: String, anim_name: String) -> void:
	if _ap == null or not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var inst := scene.instantiate()
	var src := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null:
		inst.queue_free()
		return
	var names := src.get_animation_list()
	var sn := ""
	for n in names:
		if n == "mixamo_com":
			sn = n
			break
	if sn == "" and names.size() > 0:
		sn = names[0]
	if sn == "":
		inst.queue_free()
		return
	var a := (src.get_animation(sn) as Animation).duplicate() as Animation
	a.loop_mode = Animation.LOOP_LINEAR
	var lib := _ap.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		_ap.add_animation_library("", lib)
	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)
	lib.add_animation(anim_name, a)
	inst.queue_free()
	_clips_ok[anim_name] = true

func _classify_bones() -> void:
	_upper_bones.clear()
	_hips_bone = -1
	if _skeleton == null:
		return
	for i in _skeleton.get_bone_count():
		var bn := _skeleton.get_bone_name(i)
		if "Hips" in bn:
			_hips_bone = i
			continue
		for t in UPPER_TOKENS:
			if t in bn:
				_upper_bones.append(i)
				break

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var dir := Input.get_axis("move_left", "move_right")
	# Retreating (moving away from the opponent) uses the backward stride speed.
	var spd := speed
	if dir != 0.0 and int(signf(dir)) != facing:
		spd = back_speed
	velocity.x = dir * spd
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0  # stay on the fighting plane
	_update_facing()
	_update_anim(dir)

func _update_facing() -> void:
	if _opponent and is_instance_valid(_opponent):
		facing = -1 if _opponent.global_position.x < global_position.x else 1
	model.rotation.y = deg_to_rad(90.0) if facing == 1 else deg_to_rad(-90.0)

## Idle <-> walk. Advancing toward the opponent plays the forward loop,
## retreating plays the backward loop.
func _update_anim(dir: float) -> void:
	if _ap == null:
		return
	var want := S_IDLE
	if absf(dir) > INPUT_DEADZONE:
		want = S_F_LOOP if int(signf(dir)) == facing else S_B_LOOP
	if want == _state:
		return
	_state = want
	match _state:
		S_IDLE: _ap.play(IDLE, BLEND)
		S_F_LOOP: _play("fwd_loop")
		S_B_LOOP: _play("back_loop")

func _play(anim_name: String) -> void:
	if _clips_ok.has(anim_name):
		_ap.play(anim_name, BLEND)
	else:
		_ap.play(IDLE, BLEND)  # clip missing -> fall back to idle

func _process(delta: float) -> void:
	if _skeleton == null:
		return
	if not _guard_captured and _state == S_IDLE:
		_capture_guard()
	# Fade the guard in while walking, out while idle — synced with the clip
	# cross-fade so there's no pop when you stop or start.
	var target := 1.0 if _state != S_IDLE else 0.0
	_guard_weight = move_toward(_guard_weight, target, GUARD_FADE * delta)
	if _guard_captured and _guard_weight > 0.001:
		_apply_guard(_guard_weight)
	_ground_clamp()

func _capture_guard() -> void:
	for i in _upper_bones:
		_guard_pos[i] = _skeleton.get_bone_pose_position(i)
		_guard_rot[i] = _skeleton.get_bone_pose_rotation(i)
	_guard_captured = true

## Overlay the captured guard on the upper body, and pin the hips horizontally
## so the walk plays in place (our velocity does the travelling).
func _apply_guard(w: float) -> void:
	for i in _upper_bones:
		var p := _skeleton.get_bone_pose_position(i)
		var q := _skeleton.get_bone_pose_rotation(i)
		_skeleton.set_bone_pose_position(i, p.lerp(_guard_pos[i], w))
		_skeleton.set_bone_pose_rotation(i, q.slerp(_guard_rot[i], w))
	if _hips_bone >= 0:
		var hp := _skeleton.get_bone_pose_position(_hips_bone)
		var r := _skeleton.get_bone_rest(_hips_bone).origin
		_skeleton.set_bone_pose_position(_hips_bone, hp.lerp(Vector3(r.x, hp.y, r.z), w))

func _ground_clamp() -> void:
	# Plant the character: shift the model so the skeleton's lowest point sits
	# on the floor (no float, no clipping).
	model.position.y = 0.0
	if not is_on_floor() or _skeleton == null:
		return
	var ground_y := global_position.y
	var lowest := 1.0e20
	var st := _skeleton.global_transform
	for i in _skeleton.get_bone_count():
		var wy: float = (st * _skeleton.get_bone_global_pose(i).origin).y
		if wy < lowest:
			lowest = wy
	model.position.y = ground_y + foot_offset - lowest
