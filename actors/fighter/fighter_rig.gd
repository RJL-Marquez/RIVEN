class_name FighterRig
extends Node2D
## A segment-based bone rig for a RIVEN fighter.
##
## The skeleton is built procedurally from BONES: each entry is a Node2D "bone"
## whose limb is drawn as a dark capsule along the bone's local +X axis. Child
## bones attach at the parent's tip, so rotating a bone swings everything below
## it. This is the hard-segment equivalent of a Skeleton2D cutout rig and is
## ideal for silhouette limbs; detailed art can be skinned onto the same bones
## later, and weapons attach to a hand bone.
##
## GROUNDING: the rig origin sits on the ground plane (local y = 0). The legs
## are driven by 2-bone inverse kinematics so the FEET stay planted on that
## plane while the hip height changes (tall when idle, low when crouching).
## Nothing is ever drawn below y = 0, so the ground reads as a hard boundary,
## like a real 2D fighter. The upper body (torso, arms, head) uses simple
## forward-kinematics pose offsets.

@export var body_color: Color = Color("#15171f")
@export var accent_color: Color = Color("#49c2ff")

const THIGH := 30.0
const SHIN := 30.0

# Walk gait (distance-phased so feet track the ground instead of skating).
const WALK_STEP_LEN := 12.0   # body px advanced per radian of gait
const WALK_STRIDE := 8.0      # small shuffle reach (stance strafe)
const WALK_LIFT := 4.0        # low shuffle lift

# Spinning dashes (roll/flip) rotate about the feet then lift by this length *
# max(0, -cos(angle)) so the leading end rides the ground and nothing clips
# below it. FLIP_LEN = feet-to-overhead-hands; ROLL_LEN = tuck radius.
const FLIP_LEN := 132.0
const ROLL_R := 34.0          # tuck radius for center-pivot rolls

# name, parent (""=rig root), pos (offset from parent origin), rest angle (deg),
# limb length, limb width. Leg bone rotations are overridden each frame by IK.
const BONES := [
	{"name": "pelvis",          "parent": "",               "pos": Vector2.ZERO,   "rest": 0.0,   "len": 0.0,   "w": 0.0},
	{"name": "torso",           "parent": "pelvis",         "pos": Vector2.ZERO,   "rest": -90.0, "len": 44.0,  "w": 20.0},
	{"name": "upper_arm_back",  "parent": "torso",          "pos": Vector2(38, 0), "rest": 185.0, "len": 22.0,  "w": 7.0},
	{"name": "lower_arm_back",  "parent": "upper_arm_back", "pos": Vector2(22, 0), "rest": 8.0,   "len": 20.0,  "w": 6.0},
	{"name": "upper_arm_front", "parent": "torso",          "pos": Vector2(38, 0), "rest": 175.0, "len": 22.0,  "w": 7.0},
	{"name": "lower_arm_front", "parent": "upper_arm_front","pos": Vector2(22, 0), "rest": 8.0,   "len": 20.0,  "w": 6.0},
	{"name": "upper_leg_back",  "parent": "pelvis",         "pos": Vector2.ZERO,   "rest": 95.0,  "len": THIGH, "w": 9.0},
	{"name": "lower_leg_back",  "parent": "upper_leg_back", "pos": Vector2(THIGH, 0), "rest": 0.0, "len": SHIN,  "w": 8.0},
	{"name": "upper_leg_front", "parent": "pelvis",         "pos": Vector2.ZERO,   "rest": 85.0,  "len": THIGH, "w": 9.0},
	{"name": "lower_leg_front", "parent": "upper_leg_front","pos": Vector2(THIGH, 0), "rest": 0.0, "len": SHIN,  "w": 8.0},
]

const FK_BONES := ["torso", "upper_arm_back", "lower_arm_back", "upper_arm_front", "lower_arm_front", "head"]

var bones := {}       # name -> Node2D
var rest_rot := {}    # name -> float (radians)

var _anim := "idle"
var _phase := 0.0
var _offsets := {}                     # FK bone name -> current offset (deg)
var _hip_h := 54.0                     # current hip height above the ground
var _foot_front := Vector2(14, 0)      # current planted foot target (rig space)
var _foot_back := Vector2(-14, 0)
var _walk_phase := 0.0                  # distance-phased gait position
var _move_sign := 0.0                   # +1 advancing, -1 retreating
var _prev_gx := 0.0
var _gx_init := false
var _spin := 0.0                        # body rotation for roll / flip dashes

func _ready() -> void:
	_build()

func set_anim(anim_name: String) -> void:
	_anim = anim_name

func set_spin(radians: float) -> void:
	_spin = radians

func _process(delta: float) -> void:
	_phase += delta
	_update_gait()

	if _anim == "handspring":
		# Back handspring: rotate about the body mid-point (flips in place
		# instead of swinging off a pinned foot) and clamp the lowest end to the
		# ground, so it passes through a true hands-down handstand with no clip
		# and no teleport. Travel comes from the move's velocity.
		rotation = _spin
		var half := FLIP_LEN * 0.5
		position = Vector2(-half * sin(_spin), -FLIP_LEN * maxf(0.0, -cos(_spin)))
		bones["pelvis"].position.y = -54.0
		_handspring_legs()
	elif _anim == "roll":
		# Compact ball rotating about its center of gravity; travel from velocity.
		rotation = _spin
		var rc := Vector2(0.0, -ROLL_R)
		position = rc - rc.rotated(_spin)
		bones["pelvis"].position.y = -ROLL_R
		_tuck_legs()
	elif _anim == "airflip":
		# Airborne somersault: rotate the body about its own center (the body is
		# lofted off the ground by the jump, so no ground clamp is needed).
		rotation = _spin
		var c := Vector2(0.0, -50.0)
		position = c - c.rotated(_spin)
		bones["pelvis"].position.y = -50.0
		_tuck_legs()
	else:
		rotation = lerp_angle(rotation, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		position = position.lerp(Vector2.ZERO, clampf(delta * 18.0, 0.0, 1.0))
		_spin = 0.0
		# Legs: inverse kinematics, feet planted on the ground plane.
		var lt := _leg_targets(_anim, _phase)
		var ks := clampf(delta * 12.0, 0.0, 1.0)
		_hip_h = lerp(_hip_h, float(lt["hip"]), ks)
		_foot_front = _foot_front.lerp(lt["front"], ks)
		_foot_back = _foot_back.lerp(lt["back"], ks)
		bones["pelvis"].position.y = -_hip_h
		_apply_leg("front", _foot_front)
		_apply_leg("back", _foot_back)

	# --- Upper body: forward-kinematics pose offsets ---
	var targets := _targets_for(_anim, _phase)
	var kf := clampf(delta * 14.0, 0.0, 1.0)
	for bone_name in FK_BONES:
		if not rest_rot.has(bone_name):
			continue
		var cur: float = _offsets.get(bone_name, 0.0)
		cur = lerp(cur, float(targets.get(bone_name, 0.0)), kf)
		_offsets[bone_name] = cur
		bones[bone_name].rotation = rest_rot[bone_name] + deg_to_rad(cur)

# ------------------------------------------------------------- gait ---

func _update_gait() -> void:
	# Advance the gait by how far the body actually travels (in facing terms),
	# so planted feet track the ground instead of skating. Works for advancing
	# and backpedaling, in either facing.
	var gx := global_position.x
	if not _gx_init:
		_prev_gx = gx
		_gx_init = true
	var world_dx := gx - _prev_gx
	_prev_gx = gx
	var face := signf(scale.x) if absf(scale.x) > 0.01 else 1.0
	var fwd := world_dx * face
	if absf(fwd) > 0.02:
		_move_sign = signf(fwd)
	_walk_phase += fwd / WALK_STEP_LEN

func _step_foot(ph: float) -> Vector2:
	# Planted (y=0) while the foot drags backward (cos < 0); lifts in an arc
	# while it swings forward (cos > 0).
	return Vector2(WALK_STRIDE * sin(ph), -WALK_LIFT * maxf(0.0, cos(ph)))

# ------------------------------------------------------------- IK ---

func _apply_leg(prefix: String, foot_rig: Vector2) -> void:
	# Foot target is in rig space (y = 0 is the ground). Convert to the hip's
	# local frame (the hip sits at height _hip_h above the ground).
	var foot_local := Vector2(foot_rig.x, foot_rig.y + _hip_h)
	var sol := _ik2(foot_local, THIGH, SHIN, 1.0)
	bones["upper_leg_" + prefix].rotation = sol.x
	bones["lower_leg_" + prefix].rotation = sol.y

func _tuck_legs() -> void:
	for side in ["front", "back"]:
		bones["upper_leg_" + side].rotation = rest_rot["upper_leg_" + side] + deg_to_rad(-55.0)
		bones["lower_leg_" + side].rotation = rest_rot["lower_leg_" + side] + deg_to_rad(110.0)

func _handspring_legs() -> void:
	# Near-straight legs with a slight knee, for an arched handspring line.
	for side in ["front", "back"]:
		bones["upper_leg_" + side].rotation = deg_to_rad(90.0)
		bones["lower_leg_" + side].rotation = deg_to_rad(-14.0)

func _ik2(target: Vector2, l1: float, l2: float, knee_dir: float) -> Vector2:
	# Returns Vector2(thigh_angle, shin_angle_relative). Knee bends toward
	# knee_dir (+1 = forward for a right-facing fighter).
	var d := clampf(target.length(), 0.001, l1 + l2 - 0.01)
	var theta := atan2(target.y, target.x)
	var a1 := acos(clampf((d * d + l1 * l1 - l2 * l2) / (2.0 * d * l1), -1.0, 1.0))
	var a2 := acos(clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0))
	return Vector2(theta - knee_dir * a1, knee_dir * (PI - a2))

# ------------------------------------------------------------- targets ---

func _leg_targets(anim: String, t: float) -> Dictionary:
	# hip = hip height above ground; front/back = planted foot targets in rig
	# space. Foot y is always <= 0 so nothing dips below the ground.
	match anim:
		"walk":
			return {
				"hip": 52.0,
				"front": Vector2(20, 0) + _step_foot(_walk_phase),
				"back": Vector2(-20, 0) + _step_foot(_walk_phase + PI),
			}
		"prejump":
			return {"hip": 38.0, "front": Vector2(24, 0), "back": Vector2(-22, 0)}
		"crouch":
			return {"hip": 30.0, "front": Vector2(20, 0), "back": Vector2(-20, 0)}
		"jump":
			return {"hip": 54.0, "front": Vector2(10, -10), "back": Vector2(-8, -16)}
		"dash":
			return {"hip": 50.0, "front": Vector2(20, 0), "back": Vector2(-24, 0)}
		"land":
			return {"hip": 42.0, "front": Vector2(16, 0), "back": Vector2(-16, 0)}
		"lunge":
			return {"hip": 42.0, "front": Vector2(38, 0), "back": Vector2(-32, 0)}
		_:  # idle — bladed fighting stance: staggered feet, angled legs
			return {"hip": 52.0, "front": Vector2(27, 0), "back": Vector2(-25, 0)}

# (walk footwork is handled by _update_gait + _step_foot)

func _targets_for(anim: String, t: float) -> Dictionary:
	match anim:
		"walk":
			# Hold the guard with a subtle sway synced to the gait, and lean
			# into the direction of travel. (Weapons redefine arms later.)
			var sway := sin(_walk_phase) * 5.0
			return {
				"torso": 5.0 * _move_sign,
				"upper_arm_back": -50.0 - sway,
				"lower_arm_back": -80.0,
				"upper_arm_front": -56.0 + sway,
				"lower_arm_front": -72.0,
			}
		"prejump":
			return {
				"torso": 16.0,
				"upper_arm_back": -34.0,
				"lower_arm_back": -62.0,
				"upper_arm_front": -38.0,
				"lower_arm_front": -58.0,
			}
		"crouch":
			return {"torso": 24.0, "upper_arm_back": -4.0, "upper_arm_front": -4.0}
		"jump":
			return {"upper_arm_back": -34.0, "upper_arm_front": -40.0, "torso": -4.0}
		"dash":
			return {"torso": 20.0, "upper_arm_back": 22.0, "upper_arm_front": -18.0}
		"land":
			return {"torso": 10.0}
		"lunge":
			# Aggressive forward thrust: lean in, lead arm punched forward.
			return {
				"torso": 14.0,
				"upper_arm_front": -95.0,
				"lower_arm_front": -10.0,
				"upper_arm_back": 12.0,
				"lower_arm_back": 10.0,
			}
		"handspring":
			# Arched back, arms reach overhead so the hands lead to the floor.
			return {
				"torso": -16.0,
				"upper_arm_back": -178.0,
				"lower_arm_back": -4.0,
				"upper_arm_front": -178.0,
				"lower_arm_front": -4.0,
			}
		"airflip":
			# Tuck in the air.
			return {
				"torso": 22.0,
				"upper_arm_back": -72.0,
				"lower_arm_back": -112.0,
				"upper_arm_front": -72.0,
				"lower_arm_front": -112.0,
			}
		"roll":
			# Curl tightly into a ball (head tucked toward the knees).
			return {
				"torso": 130.0,
				"upper_arm_back": -60.0,
				"lower_arm_back": -120.0,
				"upper_arm_front": -60.0,
				"lower_arm_front": -120.0,
			}
		_:  # idle — hands-up fighting guard + subtle breathing
			var br := sin(t * 2.2) * 2.0
			return {
				"torso": 6.0 + br,
				"upper_arm_back": -52.0,
				"lower_arm_back": -82.0,
				"upper_arm_front": -58.0 - br,
				"lower_arm_front": -74.0,
			}

# ------------------------------------------------------------- building ---

func _build() -> void:
	for b in BONES:
		var node := Node2D.new()
		node.name = b["name"]
		var parent_node: Node2D = self if b["parent"] == "" else bones[b["parent"]]
		parent_node.add_child(node)
		node.position = b["pos"]
		node.rotation = deg_to_rad(b["rest"])
		bones[b["name"]] = node
		rest_rot[b["name"]] = node.rotation
		if b["len"] > 0.0:
			var poly := Polygon2D.new()
			poly.polygon = _capsule(b["len"], b["w"])
			poly.color = body_color
			poly.z_as_relative = false
			poly.z_index = _z_for(b["name"])
			node.add_child(poly)
	bones["pelvis"].position.y = -_hip_h
	_decorate()

func _decorate() -> void:
	_add_poly(bones["pelvis"], _circle(11.0, Vector2.ZERO), body_color, 4)
	var head := Node2D.new()
	head.name = "head"
	bones["torso"].add_child(head)
	head.position = Vector2(44, 0)
	bones["head"] = head
	rest_rot["head"] = 0.0
	_add_poly(head, _circle(11.0, Vector2(12, 0)), body_color, 13)
	_add_poly(head, _circle(2.6, Vector2(16, -3)), accent_color, 22)
	_add_poly(bones["torso"], PackedVector2Array([
		Vector2(22, -4), Vector2(28, 0), Vector2(22, 4), Vector2(16, 0)
	]), accent_color, 23)

func _add_poly(parent_node: Node2D, points: PackedVector2Array, color: Color, z: int) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.z_as_relative = false
	poly.z_index = z
	parent_node.add_child(poly)

func _z_for(bone_name: String) -> int:
	if "back" in bone_name:
		return 0
	if "front" in bone_name:
		return 10
	return 5  # torso / pelvis

# ------------------------------------------------------------- geometry ---

func _capsule(length: float, width: float) -> PackedVector2Array:
	var r := width * 0.5
	var pts := PackedVector2Array()
	var segs := 6
	for i in range(segs + 1):
		var a := PI * 0.5 + PI * float(i) / segs
		pts.append(Vector2(cos(a), sin(a)) * r)
	for i in range(segs + 1):
		var a := -PI * 0.5 + PI * float(i) / segs
		pts.append(Vector2(length, 0) + Vector2(cos(a), sin(a)) * r)
	return pts

func _circle(r: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
