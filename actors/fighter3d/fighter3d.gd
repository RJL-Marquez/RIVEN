extends CharacterBody3D
## 2.5D fighter: a 3D body constrained to the 2D fighting plane (moves on X,
## jumps on Y, pinned to Z = 0), facing the opponent. The Mixamo character +
## its clips live under the Model node.
##
## Walk = the reference Mixamo walk's FEET with the upper body held in the idle
## fighting stance: the upper body holds the idle posture (hunged torso + guard
## arms) and the pelvis tilts forward toward the idle (thighs compensated so the
## feet keep the walk motion, knees untouched so they stay natural). A deeper
## crouch is deferred until the real character mesh replaces this placeholder —
## forcing it here just kinks the Beta mesh's knees.

@export var speed := 1.0       # forward m/s — matches the Walking clip's stride
@export var back_speed := 1.1  # retreat m/s — matches the Walking Backwards clip
@export var gravity := 18.0
@export var jump_velocity := 7.0
@export var opponent_path: NodePath

## Height tweak: raise if feet clip INTO the floor, lower (even negative) if they
## FLOAT above it. Editable in the Inspector.
@export var foot_offset := -0.02

## How much the torso hunches into the idle fighting stance while walking
## (1 = full idle hunch, 0 = the walk's own upright torso).
@export_range(0.0, 1.0) var stance_blend := 1.0

const IDLE := "mixamo_com"       # Fight Idle clip baked into the character FBX
const INPUT_DEADZONE := 0.2
const BLEND := 0.32          # clip cross-fade time (idle <-> walk) — soft, not snappy
const OVERLAY_FADE := 3.2    # stance overlay blend rate (~0.3s to full)

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
var _overlay := 0.0          # 0 = pure walk anim, 1 = full idle stance

# Bone groups.
var _upper_bones: Array[int] = []   # torso/head/arms -> hold idle posture
var _thigh_bones: Array[int] = []   # UpLeg -> compensate for the pelvis tilt
var _hips_bone := -1

# Idle base pose (local rotation per bone index), the stance we hold.
var _idle_rot := {}

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
	_classify_bones()
	if _ap and _skeleton:
		var ia := _ap.get_animation(IDLE)
		if ia:
			_sample_rot(ia, 0.0, _idle_rot)
		_ap.play(IDLE)
	process_priority = 100  # stance overlay / ground clamp run after the anim

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

## Sample an animation's local rotation for every skeleton bone at time t.
func _sample_rot(anim: Animation, t: float, out_rot: Dictionary) -> void:
	out_rot.clear()
	var name_to_i := {}
	for i in _skeleton.get_bone_count():
		name_to_i[_skeleton.get_bone_name(i)] = i
	for ti in anim.get_track_count():
		if anim.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
			continue
		var path := String(anim.track_get_path(ti))
		if not ":" in path:
			continue
		var bn := path.get_slice(":", 1)
		if name_to_i.has(bn):
			out_rot[name_to_i[bn]] = anim.rotation_track_interpolate(ti, t)

func _classify_bones() -> void:
	_upper_bones.clear()
	_thigh_bones.clear()
	_hips_bone = -1
	if _skeleton == null:
		return
	for i in _skeleton.get_bone_count():
		var bn := _skeleton.get_bone_name(i)
		if "Hips" in bn:
			_hips_bone = i
			continue
		if "UpLeg" in bn:
			_thigh_bones.append(i)
			continue
		if ("Leg" in bn) or ("Foot" in bn) or ("Toe" in bn):
			continue  # knees / feet stay exactly as the walk clip poses them
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
	# Fade the stance overlay in while walking, out while idle — synced with the
	# clip cross-fade so there's no pop when you stop or start.
	var target := 1.0 if _state != S_IDLE else 0.0
	_overlay = move_toward(_overlay, target, OVERLAY_FADE * delta)
	if _overlay > 0.001 and not _idle_rot.is_empty():
		_apply_stance(_overlay)
	_ground_clamp()

## Hunch the torso into the idle stance without touching the walking legs:
##  - upper body -> hold the idle posture (hunged torso + guard arms)
##  - hips       -> tilt the pelvis toward the idle, pinned horizontally (in place)
##  - thighs     -> compensated for the pelvis tilt so the feet keep the walk motion
func _apply_stance(w: float) -> void:
	# Upper body holds the idle posture.
	for i in _upper_bones:
		if not _idle_rot.has(i):
			continue
		var cur: Quaternion = _skeleton.get_bone_pose_rotation(i)
		_skeleton.set_bone_pose_rotation(i, cur.slerp(_idle_rot[i], w))

	# Pelvis tilt toward the idle; capture the change K to undo it on the thighs.
	var k := Quaternion.IDENTITY
	if _hips_bone >= 0 and _idle_rot.has(_hips_bone):
		var h_old: Quaternion = _skeleton.get_bone_pose_rotation(_hips_bone)
		var h_new: Quaternion = h_old.slerp(_idle_rot[_hips_bone], w * stance_blend)
		_skeleton.set_bone_pose_rotation(_hips_bone, h_new)
		k = h_new.inverse() * h_old
		var cp: Vector3 = _skeleton.get_bone_pose_position(_hips_bone)
		var rest := _skeleton.get_bone_rest(_hips_bone).origin
		_skeleton.set_bone_pose_position(_hips_bone, cp.lerp(Vector3(rest.x, cp.y, rest.z), w))

	# Thighs keep the reference walk's world orientation despite the pelvis tilt,
	# so the feet (and knees) keep the natural walk motion.
	for i in _thigh_bones:
		var cur: Quaternion = _skeleton.get_bone_pose_rotation(i)
		_skeleton.set_bone_pose_rotation(i, k * cur)

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
