# Animating RIVEN's fighter (AnimationPlayer workflow)

The fighter's poses are now authored **visually** with keyframes — you pose the
character on a timeline and Godot fills in the motion. This is far better than
tuning angles by hand for acrobatic moves.

## The rig

Open `actors/fighter/Fighter.tscn` in Godot. The hierarchy:

```
Fighter (CharacterBody2D)
  CollisionShape2D
  Rig (Node2D)        <- facing flip; don't keyframe this
    Root (Node2D)     <- keyframe this for WHOLE-BODY spins & position (flips, rolls, handspring)
      pelvis
        torso -> head, upper_arm_front/back -> lower_arm_front/back
        upper_leg_front/back -> lower_leg_front/back
  AnimationPlayer     <- author animations here
```

- **Individual bones** (torso, arms, legs): rotate them to pose limbs. Rotating
  a bone swings everything below it.
- **`Root`**: rotate/move it to spin or lift the *whole body* — this is how you
  do flips, rolls, and the handspring (the whole body rotating), and how you
  keep feet on the ground.

## How to animate a move

1. Select the **AnimationPlayer** node. The **Animation** panel opens at the
   bottom.
2. Pick an animation from the dropdown (they already exist, see names below).
3. Set its **length** (right side of the panel), e.g. `0.5`.
4. Move the **playhead** to a time, rotate/move bones in the viewport (or type
   values in the Inspector), and click the **key icon** next to each changed
   property to drop a keyframe. Repeat at a few times across the length.
5. Scrub the playhead to preview. Press **Play** in the panel to loop it.

For a **roll**: keyframe `Root:rotation` from `0` to `360°` across the length,
and keep `Root:position` so the lowest point stays on the floor; tuck the legs
and curl the torso with their own tracks in the middle. For the **handspring**:
keyframe `Root:rotation` and `Root:position` so the hands plant and the body
rotates over them. For **flips**: rotate `Root` a full turn and tuck the legs in
toward the middle.

## Animation names (must match exactly)

The game plays these automatically based on what the fighter is doing — you do
NOT need to touch any code:

`idle`, `walk`, `crouch`, `prejump`, `jump`, `land`, `lunge`, `handspring`,
`airflip`, `roll`

(`idle` already has a small sway as a working example. The rest are stubs — fill
them in.) The same `roll` animation is used for front and back rolls (the
direction/travel is handled by the game), same for the flips with `airflip`.

## Testing

Press **F5** to run the arena. Controls: A/D move, W jump, S crouch; combos:
double-tap forward/back = lunge / handspring, jump+dir = flip, crouch+dir = roll.

## What the game still controls (not the animation)

The animation is only the **pose/rotation**. How far and fast a move travels is
data you can tweak in `actors/fighter/moves/*.tres` (Inspector): `speed`, `time`,
`recovery`, `up` (launch height), `spin`. Match your animation's length to the
move's `time` (or airtime) so they line up.

> The old procedural rig (`actors/fighter/fighter_rig.gd`) is no longer used and
> can be deleted; it's left for reference.
