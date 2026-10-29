extends CharacterBody3D
## 2.5D fighter: a 3D body constrained to the 2D fighting plane (moves on X,
## jumps on Y, pinned to Z = 0), facing the opponent. The real character +
## animations (e.g. from Mixamo) get parented under the Model node, and the
## state machine / combat port over from the 2D version.

@export var speed := 4.0
@export var gravity := 18.0
@export var jump_velocity := 7.0
@export var opponent_path: NodePath

const FOOT_OFFSET := 0.03  # lowest bone sits this far above the floor (sole thickness)

var facing := 1
var _opponent: Node3D
var _skeleton: Skeleton3D

@onready var model: Node3D = $Model

func _ready() -> void:
	if opponent_path != NodePath(""):
		_opponent = get_node_or_null(opponent_path)
	# Play the imported Mixamo idle (looped).
	var ap := $Model/Character.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap:
		var a := ap.get_animation("mixamo_com")
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
		ap.play("mixamo_com")
	_skeleton = $Model/Character.get_node_or_null("Skeleton3D")
	process_priority = 100  # run _ground_clamp after the animation poses the skeleton

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	velocity.z = 0.0
	move_and_slide()
	# Stay on the fighting plane.
	global_position.z = 0.0
	_update_facing()

func _update_facing() -> void:
	if _opponent and is_instance_valid(_opponent):
		facing = -1 if _opponent.global_position.x < global_position.x else 1
	# Turn the visual to face the opponent. The 90 deg base offset suits a
	# character that faces +Z by default (tune for the imported model).
	model.rotation.y = deg_to_rad(90.0) if facing == 1 else deg_to_rad(-90.0)

func _process(_delta: float) -> void:
	_ground_clamp()

func _ground_clamp() -> void:
	# Plant the character on the floor: when grounded, shift the model so the
	# skeleton's lowest bone sits just above the ground (no float, no sink).
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
	model.position.y = ground_y + FOOT_OFFSET - lowest
