extends SceneTree
# One-shot: bake the fighter rig into a real scene-node hierarchy with an
# AnimationPlayer whose animations are authored as editable KEYFRAMES.
# Run headlessly:
#   Godot --headless --path <project> --script res://tools/build_rig_scene.gd
#
# Re-running regenerates res://actors/fighter/Fighter.tscn (reload it in the
# editor afterward). Tune the animations visually in the Animation panel.

const BODY := Color("#15171f")
const ACCENT := Color("#49c2ff")
const THIGH := 30.0
const SHIN := 30.0
const PELVIS_Y := -58.0   # rest hip height so the feet sit on the ground

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

const REST := {
	"torso": -90.0, "head": 0.0,
	"upper_arm_back": 185.0, "lower_arm_back": 8.0,
	"upper_arm_front": 175.0, "lower_arm_front": 8.0,
	"upper_leg_back": 95.0, "lower_leg_back": 0.0,
	"upper_leg_front": 85.0, "lower_leg_front": 0.0,
}
const PATHS := {
	"torso": "Rig/Root/pelvis/torso",
	"head": "Rig/Root/pelvis/torso/head",
	"upper_arm_back": "Rig/Root/pelvis/torso/upper_arm_back",
	"lower_arm_back": "Rig/Root/pelvis/torso/upper_arm_back/lower_arm_back",
	"upper_arm_front": "Rig/Root/pelvis/torso/upper_arm_front",
	"lower_arm_front": "Rig/Root/pelvis/torso/upper_arm_front/lower_arm_front",
	"upper_leg_back": "Rig/Root/pelvis/upper_leg_back",
	"lower_leg_back": "Rig/Root/pelvis/upper_leg_back/lower_leg_back",
	"upper_leg_front": "Rig/Root/pelvis/upper_leg_front",
	"lower_leg_front": "Rig/Root/pelvis/upper_leg_front/lower_leg_front",
}
const GUARD := {"upper_arm_back": -52.0, "lower_arm_back": -82.0, "upper_arm_front": -58.0, "lower_arm_front": -74.0}
const STANCE := {"upper_leg_back": 8.0, "lower_leg_back": 8.0, "upper_leg_front": -8.0, "lower_leg_front": 8.0}

const ANIMS := ["idle", "walk", "crouch", "prejump", "jump", "land", "lunge", "handspring", "airflip", "roll"]

func _initialize() -> void:
	var fighter := CharacterBody2D.new()
	fighter.name = "Fighter"
	fighter.set_script(load("res://actors/fighter/fighter.gd"))

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
	bones["pelvis"].position.y = PELVIS_Y

	_add_poly(bones["pelvis"], "hip", _circle(11.0, Vector2.ZERO), BODY, 4)
	var head := Node2D.new()
	head.name = "head"
	bones["torso"].add_child(head)
	head.position = Vector2(44, 0)
	bones["head"] = head
	_add_poly(head, "vis", _circle(11.0, Vector2(12, 0)), BODY, 13)
	_add_poly(head, "eye", _circle(2.6, Vector2(16, -3)), ACCENT, 22)
	_add_poly(bones["torso"], "gem", PackedVector2Array([
		Vector2(22, -4), Vector2(28, 0), Vector2(22, 4), Vector2(16, 0)
	]), ACCENT, 23)

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

# ------------------------------------------------------- animation build ---

func _make_anim(anim_name: String) -> Animation:
	var data := _anim_data(anim_name)
	var a := Animation.new()
	a.length = data["length"]
	if data.get("loop", false):
		a.loop_mode = Animation.LOOP_LINEAR
	var keys: Array = data["keys"]

	var bones_used := {}
	var use_root := false
	for k in keys:
		if float(k.get("root_rot", 0.0)) != 0.0 or k.get("root_pos", Vector2.ZERO) != Vector2.ZERO:
			use_root = true
		for b in k.get("off", {}).keys():
			bones_used[b] = true

	var tp := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tp, "Rig/Root/pelvis:position")
	for k in keys:
		a.track_insert_key(tp, k["t"], Vector2(0, float(k.get("pelvis", PELVIS_Y))))

	if use_root:
		var tr := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tr, "Rig/Root:rotation")
		for k in keys:
			a.track_insert_key(tr, k["t"], deg_to_rad(float(k.get("root_rot", 0.0))))
		var tpos := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tpos, "Rig/Root:position")
		for k in keys:
			a.track_insert_key(tpos, k["t"], k.get("root_pos", Vector2.ZERO))

	for b in bones_used.keys():
		var tb := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tb, PATHS[b] + ":rotation")
		for k in keys:
			var off: float = float(k.get("off", {}).get(b, 0.0))
			a.track_insert_key(tb, k["t"], deg_to_rad(float(REST[b]) + off))
	return a

func _anim_data(anim_name: String) -> Dictionary:
	match anim_name:
		"idle":
			return {"length": 1.4, "loop": true, "keys": [
				{"t": 0.0, "pelvis": -56.0, "off": _m([GUARD, STANCE, {"torso": 6.0}])},
				{"t": 0.7, "pelvis": -56.0, "off": _m([GUARD, STANCE, {"torso": 9.0}])},
				{"t": 1.4, "pelvis": -56.0, "off": _m([GUARD, STANCE, {"torso": 6.0}])},
			]}
		"walk":
			return {"length": 0.6, "loop": true, "keys": [
				{"t": 0.0, "pelvis": -56.0, "off": _m([GUARD, {"upper_leg_front": -14.0, "upper_leg_back": 14.0, "lower_leg_front": 8.0, "lower_leg_back": 8.0, "torso": 4.0}])},
				{"t": 0.3, "pelvis": -56.0, "off": _m([GUARD, {"upper_leg_front": 8.0, "upper_leg_back": -8.0, "lower_leg_front": 8.0, "lower_leg_back": 8.0, "torso": 4.0}])},
				{"t": 0.6, "pelvis": -56.0, "off": _m([GUARD, {"upper_leg_front": -14.0, "upper_leg_back": 14.0, "lower_leg_front": 8.0, "lower_leg_back": 8.0, "torso": 4.0}])},
			]}
		"crouch":
			return {"length": 0.15, "loop": false, "keys": [
				{"t": 0.0, "pelvis": -56.0, "off": _m([GUARD, STANCE])},
				{"t": 0.15, "pelvis": -34.0, "off": _m([{"torso": 18.0, "upper_leg_back": 45.0, "lower_leg_back": 55.0, "upper_leg_front": -45.0, "lower_leg_front": 55.0, "upper_arm_back": -12.0, "upper_arm_front": -12.0}])},
			]}
		"prejump":
			return {"length": 0.09, "loop": false, "keys": [
				{"t": 0.0, "pelvis": -56.0, "off": _m([GUARD, STANCE])},
				{"t": 0.09, "pelvis": -44.0, "off": _m([{"torso": 12.0, "upper_leg_back": 25.0, "lower_leg_back": 30.0, "upper_leg_front": -25.0, "lower_leg_front": 30.0}])},
			]}
		"jump":
			return {"length": 0.4, "loop": false, "keys": [
				{"t": 0.0, "pelvis": -58.0, "off": _m([{"torso": -4.0, "upper_leg_back": -15.0, "lower_leg_back": 25.0, "upper_leg_front": -15.0, "lower_leg_front": 25.0, "upper_arm_back": -30.0, "upper_arm_front": -30.0}])},
			]}
		"land":
			return {"length": 0.1, "loop": false, "keys": [
				{"t": 0.0, "pelvis": -46.0, "off": _m([{"torso": 10.0, "upper_leg_back": 20.0, "lower_leg_back": 28.0, "upper_leg_front": -20.0, "lower_leg_front": 28.0}])},
			]}
		"lunge":
			var ext := _m([{"torso": 14.0, "upper_arm_front": -95.0, "lower_arm_front": -10.0, "upper_arm_back": 12.0, "lower_arm_back": 10.0, "upper_leg_front": -35.0, "lower_leg_front": 20.0, "upper_leg_back": 30.0, "lower_leg_back": 10.0}])
			return {"length": 0.22, "loop": false, "keys": [
				{"t": 0.0, "pelvis": -56.0, "off": _m([GUARD, STANCE])},
				{"t": 0.12, "pelvis": -46.0, "off": ext},
				{"t": 0.22, "pelvis": -46.0, "off": ext},
			]}
		"airflip":
			return _spin_data(0.6, Vector2(0, -50), -50.0, true)
		"roll":
			return _roll_data()
		"handspring":
			return _handspring_data()
	return {"length": 0.6, "loop": false, "keys": [{"t": 0.0}]}

func _spin_data(length: float, center: Vector2, pelvis_y: float, tuck: bool) -> Dictionary:
	# Airborne somersault: rotate the body about its center, tuck eased to mid.
	var keys := []
	var n := 6
	for i in range(n + 1):
		var p := float(i) / n
		var th := -TAU * p
		var tf := sin(p * PI)
		var off := {}
		if tuck:
			off = {
				"upper_leg_back": -70.0 * tf, "lower_leg_back": 135.0 * tf,
				"upper_leg_front": -70.0 * tf, "lower_leg_front": 135.0 * tf,
				"upper_arm_back": -72.0 * tf, "lower_arm_back": -112.0 * tf,
				"upper_arm_front": -72.0 * tf, "lower_arm_front": -112.0 * tf,
				"torso": 22.0 * tf,
			}
		keys.append({"t": p * length, "pelvis": pelvis_y, "root_rot": rad_to_deg(th),
			"root_pos": center - center.rotated(th), "off": off})
	return {"length": length, "loop": false, "keys": keys}

func _roll_data() -> Dictionary:
	var length := 0.52
	var roll_len := 56.0
	var half := roll_len * 0.5
	var keys := []
	var n := 8
	for i in range(n + 1):
		var p := float(i) / n
		var th := -TAU * p
		var tf := sin(p * PI)
		keys.append({"t": p * length, "pelvis": -40.0, "root_rot": rad_to_deg(th),
			"root_pos": Vector2(-half * sin(th), -roll_len * maxf(0.0, -cos(th))),
			"off": {
				"upper_leg_back": -70.0 * tf * 0.55, "lower_leg_back": 135.0 * tf * 0.55,
				"upper_leg_front": -70.0 * tf * 0.55, "lower_leg_front": 135.0 * tf * 0.55,
				"torso": 80.0 * tf, "upper_arm_back": -35.0 * tf, "lower_arm_back": -70.0 * tf,
				"upper_arm_front": -35.0 * tf, "lower_arm_front": -70.0 * tf,
			}})
	return {"length": length, "loop": false, "keys": keys}

func _handspring_data() -> Dictionary:
	var length := 0.5
	var bl := 132.0
	var half := bl * 0.5
	var keys := []
	var n := 10
	for i in range(n + 1):
		var p := float(i) / n
		var th := -TAU * p
		keys.append({"t": p * length, "pelvis": -54.0, "root_rot": rad_to_deg(th),
			"root_pos": Vector2(-half * sin(th), -bl * maxf(0.0, -cos(th))),
			"off": {
				"upper_leg_back": -5.0, "lower_leg_back": -14.0,
				"upper_leg_front": 5.0, "lower_leg_front": -14.0,
				"upper_arm_back": -178.0, "lower_arm_back": -4.0,
				"upper_arm_front": -178.0, "lower_arm_front": -4.0,
				"torso": 0.0,
			}})
	return {"length": length, "loop": false, "keys": keys}

# ---------------------------------------------------------------- helpers ---

func _m(parts: Array) -> Dictionary:
	var r := {}
	for p in parts:
		r.merge(p, true)
	return r

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
