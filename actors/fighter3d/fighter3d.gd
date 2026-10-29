extends CharacterBody3D
## 2.5D fighter: a 3D body constrained to the 2D fighting plane (moves on X,
## jumps on Y, pinned to Z = 0), facing the opponent. The real character +
## animations (e.g. from Mixamo) get parented under the Model node, and the
## state machine / combat port over from the 2D version.

@export var speed := 4.0
@export var gravity := 18.0
@export var jump_velocity := 7.0
@export var opponent_path: NodePath

var facing := 1
var _opponent: Node3D

@onready var model: Node3D = $Model

func _ready() -> void:
	if opponent_path != NodePath(""):
		_opponent = get_node_or_null(opponent_path)

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
