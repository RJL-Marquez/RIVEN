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
## Poses are driven by set_anim(): each animation returns per-bone angle offsets
## (degrees) from the rest pose, which are smoothed toward every frame.

@export var body_color: Color = Color("#15171f")
@export var accent_color: Color = Color("#49c2ff")

# name, parent (""=rig root), pos (offset from parent origin), rest angle (deg),
# limb length, limb width. Angles: 0 = local +X; +90 points down (+Y).
const BONES := [
	{"name": "pelvis",          "parent": "",               "pos": Vector2.ZERO,   "rest": 0.0,   "len": 0.0,  "w": 0.0},
	{"name": "torso",           "parent": "pelvis",         "pos": Vector2.ZERO,   "rest": -90.0, "len": 44.0, "w": 20.0},
	{"name": "upper_arm_back",  "parent": "torso",          "pos": Vector2(38, 0), "rest": 185.0, "len": 22.0, "w": 7.0},
	{"name": "lower_arm_back",  "parent": "upper_arm_back", "pos": Vector2(22, 0), "rest": 8.0,   "len": 20.0, "w": 6.0},
	{"name": "upper_arm_front", "parent": "torso",          "pos": Vector2(38, 0), "rest": 175.0, "len": 22.0, "w": 7.0},
	{"name": "lower_arm_front", "parent": "upper_arm_front","pos": Vector2(22, 0), "rest": 8.0,   "len": 20.0, "w": 6.0},
	{"name": "upper_leg_back",  "parent": "pelvis",         "pos": Vector2.ZERO,   "rest": 95.0,  "len": 30.0, "w": 9.0},
	{"name": "lower_leg_back",  "parent": "upper_leg_back", "pos": Vector2(30, 0), "rest": 0.0,   "len": 30.0, "w": 8.0},
	{"name": "upper_leg_front", "parent": "pelvis",         "pos": Vector2.ZERO,   "rest": 85.0,  "len": 30.0, "w": 9.0},
	{"name": "lower_leg_front", "parent": "upper_leg_front","pos": Vector2(30, 0), "rest": 0.0,   "len": 30.0, "w": 8.0},
]

var bones := {}       # name -> Node2D
var rest_rot := {}    # name -> float (radians)

var _anim := "idle"
var _phase := 0.0
var _offsets := {}    # name -> current applied offset (deg)
var _vert := 0.0
var _base_y := 0.0

func _ready() -> void:
	_base_y = position.y
	_build()

func set_anim(anim_name: String) -> void:
	_anim = anim_name

func _process(delta: float) -> void:
	_phase += delta
	var targets := _targets_for(_anim, _phase)
	var k := clampf(delta * 14.0, 0.0, 1.0)
	for name in bones.keys():
		if not rest_rot.has(name):
			continue
		var cur: float = _offsets.get(name, 0.0)
		var tgt: float = targets.get(name, 0.0)
		cur = lerp(cur, tgt, k)
		_offsets[name] = cur
		bones[name].rotation = rest_rot[name] + deg_to_rad(cur)
	_vert = lerp(_vert, _vert_for(_anim), clampf(delta * 12.0, 0.0, 1.0))
	position.y = _base_y + _vert

# ---------------------------------------------------------------- building ---

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
	_decorate()

func _decorate() -> void:
	# Hip fill so the pelvis joint doesn't look hollow.
	_add_poly(bones["pelvis"], _circle(11.0, Vector2.ZERO), body_color, 4)
	# Head on the torso tip, with an accent eye.
	var head := Node2D.new()
	head.name = "head"
	bones["torso"].add_child(head)
	head.position = Vector2(44, 0)
	bones["head"] = head
	rest_rot["head"] = 0.0
	_add_poly(head, _circle(11.0, Vector2(12, 0)), body_color, 13)
	_add_poly(head, _circle(2.6, Vector2(16, -3)), accent_color, 22)
	# Accent "core" gem on the chest — the per-fighter identity color.
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

func _z_for(name: String) -> int:
	if "back" in name:
		return 0
	if "front" in name:
		return 10
	return 5  # torso / pelvis

# --------------------------------------------------------------- geometry ---

func _capsule(length: float, width: float) -> PackedVector2Array:
	var r := width * 0.5
	var pts := PackedVector2Array()
	var segs := 6
	for i in range(segs + 1):  # start cap
		var a := PI * 0.5 + PI * float(i) / segs
		pts.append(Vector2(cos(a), sin(a)) * r)
	for i in range(segs + 1):  # end cap
		var a := -PI * 0.5 + PI * float(i) / segs
		pts.append(Vector2(length, 0) + Vector2(cos(a), sin(a)) * r)
	return pts

func _circle(r: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

# -------------------------------------------------------------- poses ---

func _targets_for(anim: String, t: float) -> Dictionary:
	match anim:
		"walk":
			var sw := sin(t * 9.0)
			return {
				"upper_leg_back": sw * 24.0,
				"upper_leg_front": -sw * 24.0,
				"lower_leg_back": clampf(-sw, 0.0, 1.0) * 26.0 + 6.0,
				"lower_leg_front": clampf(sw, 0.0, 1.0) * 26.0 + 6.0,
				"upper_arm_back": -sw * 16.0,
				"upper_arm_front": sw * 16.0,
				"lower_arm_back": 6.0,
				"lower_arm_front": 6.0,
				"torso": 3.0,
			}
		"crouch":
			return {
				"torso": 24.0,
				"upper_leg_back": 50.0,
				"upper_leg_front": -50.0,
				"lower_leg_back": 70.0,
				"lower_leg_front": 70.0,
				"upper_arm_back": -4.0,
				"upper_arm_front": -4.0,
			}
		"jump":
			return {
				"upper_leg_back": -22.0,
				"upper_leg_front": -30.0,
				"lower_leg_back": 34.0,
				"lower_leg_front": 40.0,
				"upper_arm_back": -34.0,
				"upper_arm_front": -40.0,
				"torso": -4.0,
			}
		"dash":
			return {
				"torso": 20.0,
				"upper_leg_back": 30.0,
				"upper_leg_front": -26.0,
				"lower_leg_back": 10.0,
				"lower_leg_front": 18.0,
				"upper_arm_back": 22.0,
				"upper_arm_front": -18.0,
			}
		"land":
			return {
				"torso": 10.0,
				"upper_leg_back": 14.0,
				"upper_leg_front": -14.0,
				"lower_leg_back": 16.0,
				"lower_leg_front": 16.0,
			}
		_:  # idle — subtle breathing + light guard
			var br := sin(t * 2.2) * 2.0
			return {
				"torso": br,
				"upper_arm_back": 4.0 + br,
				"upper_arm_front": 4.0 - br,
				"lower_arm_back": 8.0,
				"lower_arm_front": 8.0,
			}

func _vert_for(anim: String) -> float:
	match anim:
		"crouch": return 40.0
		"land": return 10.0
		"jump": return -2.0
		_: return 0.0
