class_name DashStyle
extends Resource
## A data-driven dash definition, stored as a .tres asset in
## actors/fighter/dash_styles/. Each fighter points at one DashStyle, so
## different characters can have different dash behavior and animation without
## any code changes. A style may also carry a `back_override` used when dashing
## AWAY from the opponent (e.g. a quick step forward but a backflip backward).
##
## kind:  step  — short grounded burst (pure spacing)
##        slide — longer, faster grounded dash
##        roll  — grounded dash with a full body spin (evasive tumble)
##        flip  — airborne hop with a spin (launch via `up`)

@export var kind: String = "step"   # descriptive: lunge / handspring / airflip / roll
@export var speed: float = 480.0        # horizontal dash speed (px/s)
@export var time: float = 0.13          # grounded burst duration (s)
@export var recovery: float = 0.15      # locked recovery after the move (s)
@export var up: float = 0.0             # upward launch (px/s); > 0 = airborne
@export var spin: float = 0.0           # full body rotations during the move
@export var anim: String = "dash"       # rig anim to play (dash / roll / flip)
@export var back_override: DashStyle    # optional: used for backward dashes
