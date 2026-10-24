extends SceneTree
# One-shot: bake the fighter rig into a real scene-node hierarchy with an
# AnimationPlayer, so the moves can be keyframed visually in the editor.
# Run headlessly:
#   Godot --headless --path <project> --script res://tools/build_rig_scene.gd
#
# Hierarchy produced (saved to res://actors/fighter/Fighter.tscn):
#   Fighter (CharacterBody2D, fighter.gd)
#     CollisionShape2D
#     Rig (Node2D)           <- facing flip (scale.x) is applied here
#       Root (Node2D)        <- keyframe this for whole-body spins / position
#         pelvis ... torso/head/arms/legs (Node2D bones + Polygon2D visuals)
#     AnimationPlayer        <- author move animations here (idle/walk/roll/...)

const BODY := Color("#15171f")
const ACCENT := Color("#49c2ff")
const THIGH := 30.0
const SHIN := 30.0

const BONES := [
	{"name": "pelvis",          "parent": "",               "pos": Vector2.ZERO,      "rest": 0.0,   "len": 0.0,   "w": 0.0},
	{"name": "torso",           "parent": "pelvis",         "pos": Vector2.ZERO,      "rest": -90.0, "len": 44.0,  "w": 20.0},
	{"name": "upper_arm_back",  "parent": "torso",          "pos": Vector2(38, 0),    "rest": 185.0, "len": 22.0,  "w": 7.0},
	{"name": "lower_arm_back",  "parent": "upper_arm_back", "pos": Vector2(22, 0),    "rest": 8.0,   "len": 20.0,  "w": 6.0},
	{"name": "upper_arm_front", "parent": "torso",          "pos": Vector2(38, 0),    "rest": 175.0, "len": 22.0,  "w": 7.0},
	{"name": "lower_arm_front", "parent": "upper_arm_front","pos": Vector2(22, 0),    "rest": 8.0,   "len": 20.0,  "w": 6.0},
	{"name": "upper_leg_back",  "parent": "pelvis",         "pos": Vector2.ZERO,      "rest": 95.0,  "len": THIGH, "w": 9.0},
	{"name": "lower_leg_back",  "parent": "upper_leg_back", "pos": Vector2(THIGH, 0), "rest": 0.0,   "len": SHIN,  "w": 8.0},
	{"name": "upper_leg_front", "parent": "pelvis",         "pos": Vector2.ZERO,      "rest": 85.0,  "len": THIGH, "w": 9.0},
	{"name": "lower_leg_front", "parent": "upper_leg_front","pos": Vector2(THIGH, 0), "rest": 0.0,   "len": SHIN,  "w": 8.0},
]

const ANIMS := ["idle", "walk", "crouch", "prejump", "jump", "land", "lunge", "roll", "handspring", "airflip"]

var _root: Node

func _initialize() -> void:
	var fighter := CharacterBody2D.new()
	fighter.name = "Fighter"
	fighter.set_script(load("res://actors/fighter/fighter.gd"))
	_root = fighter

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 100.0
	col.shape = cap
	col.position = Vector2(0, -50)
	fighter.add_child(col)

	var rig := Node2D.new()
	rig.name = "Rig"
	fighter.add_child(rig)

	var root := Node2D.new()
	root.name = "Root"
	rig.add_child(root)

	var bones := {}
	for b in BONES:
		var node := Node2D.new()
		node.name = b["name"]
		var parent_node: Node2D = root if b["parent"] == "" else bones[b["parent"]]
		parent_node.add_child(node)
		node.position = b["pos"]
		node.rotation = deg_to_rad(b["rest"])
		bones[b["name"]] = node
		if b["len"] > 0.0:
			var poly := Polygon2D.new()
			poly.name = "vis"
			poly.polygon = _capsule(b["len"], b["w"])
			poly.color = BODY
			poly.z_as_relative = false
			poly.z_index = _z_for(b["name"])
			node.add_child(poly)

	# Hip fill
	_add_poly(bones["pelvis"], "hip", _circle(11.0, Vector2.ZERO), BODY, 4)
	# Head + accent eye
	var head := Node2D.new()
	head.name = "head"
	bones["torso"].add_child(head)
	head.position = Vector2(44, 0)
	bones["head"] = head
	_add_poly(head, "vis", _circle(11.0, Vector2(12, 0)), BODY, 13)
	_add_poly(head, "eye", _circle(2.6, Vector2(16, -3)), ACCENT, 22)
	# Chest accent gem
	_add_poly(bones["torso"], "gem", PackedVector2Array([
		Vector2(22, -4), Vector2(28, 0), Vector2(22, 4), Vector2(16, 0)
	]), ACCENT, 23)

	# AnimationPlayer with a library of (mostly empty) animations to author.
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	fighter.add_child(ap)
	var lib := AnimationLibrary.new()
	for a in ANIMS:
		lib.add_animation(a, _make_anim(a))
	ap.add_animation_library("", lib)

	_set_owner_recursive(fighter, fighter)

	var packed := PackedScene.new()
	packed.pack(fighter)
	var err := ResourceSaver.save(packed, "res://actors/fighter/Fighter.tscn")
	print("RIVEN rigged scene saved, err=", err)
	quit()

func _make_anim(anim_name: String) -> Animation:
	var a := Animation.new()
	a.length = 0.6
	if anim_name == "idle":
		# A tiny torso sway, as a live example of a track to copy.
		a.length = 1.4
		a.loop_mode = Animation.LOOP_LINEAR
		var ti := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(ti, "Rig/Root/pelvis/torso:rotation")
		a.track_insert_key(ti, 0.0, deg_to_rad(-90.0))
		a.track_insert_key(ti, 0.7, deg_to_rad(-87.0))
		a.track_insert_key(ti, 1.4, deg_to_rad(-90.0))
	else:
		# Stub: hold the rest pose; author real keyframes in the editor.
		var ti := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(ti, "Rig/Root:rotation")
		a.track_insert_key(ti, 0.0, 0.0)
	return a

# ---------------------------------------------------------------- helpers ---

func _add_poly(parent_node: Node2D, pname: String, points: PackedVector2Array, color: Color, z: int) -> void:
	var poly := Polygon2D.new()
	poly.name = pname
	poly.polygon = points
	poly.color = color
	poly.z_as_relative = false
	poly.z_index = z
	parent_node.add_child(poly)

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_set_owner_recursive(c, owner_node)

func _z_for(bone_name: String) -> int:
	if "back" in bone_name:
		return 0
	if "front" in bone_name:
		return 10
	return 5

func _capsule(length: float, width: float) -> PackedVector2Array:
	var r := width * 0.5
	var pts := PackedVector2Array()
	var segs := 6
	for i in range(segs + 1):
		var ang := PI * 0.5 + PI * float(i) / segs
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	for i in range(segs + 1):
		var ang := -PI * 0.5 + PI * float(i) / segs
		pts.append(Vector2(length, 0) + Vector2(cos(ang), sin(ang)) * r)
	return pts

func _circle(r: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var ang := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	return pts
