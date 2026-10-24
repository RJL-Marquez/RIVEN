# RIVEN — Design & Roadmap

_Living document. Every core decision lives here so the project never drifts._

## Vision

RIVEN is a **weighty, tactical 1v1 duel fighter** in the tradition of *Shadow Fight 2*.
Fights are about spacing, timing, and commitment — attacks commit you, reading the
opponent matters, and one clean hit does real damage.

## Pillars

| Pillar | Decision |
|---|---|
| **Genre** | Weighty, tactical 1v1 duel fighter |
| **Visual style** | Dark silhouettes with glowing **per-fighter accent colors** (color = identity / faction) |
| **Setting** | Medieval / martial — swords, spears, axes, shields; light magic accents |
| **Combat depth** | Full directional — **head / body / legs** hit zones; block the correct height or get hit |
| **Controls** | Virtual joystick + action buttons on mobile; keyboard/gamepad on PC |
| **Primary ship target** | Web (HTML5) playable in iPhone Safari; native iOS possible later (needs a Mac) |

## Technical approach

- **Engine:** Godot 4.7.2, **Compatibility (OpenGL/WebGL) renderer** — required for reliable
  web export and low-end mobile performance. (Forward+ does not work on web.)
- **Animation:** Skeleton2D cutout rigs (bones + body-part sprites), not frame-by-frame
  sprites. Gives the weighty SF2 limb motion and lets weapons attach to a hand bone.
  Development proceeds on placeholder/silhouette art; final art is skinned onto the same rig.
- **Input:** abstracted action names (see below) so PC keyboard and mobile touch share one
  code path.
- **Combat tech:** `Area2D` hitboxes/hurtboxes, an input-buffered state machine per fighter.

### Input actions

`move_left`, `move_right`, `jump`, `crouch`, `attack`, `kick`, `block`, `magic`

## Roadmap

- [x] **Phase 0 — Scaffold.** Godot project, renderer/display config, input map, folder
      structure, docs, git. _(this commit)_
- [ ] **Phase 1 — Movement + one fighter.** Rigged silhouette fighter; walk/dash/jump/crouch
      via an input-buffered state machine.
- [ ] **Phase 2 — Combat core.** Hitbox/hurtbox, one attack, hit reactions, health bar,
      block, KO. _(make-or-break "does it feel good" milestone)_
- [ ] **Phase 3 — Second fighter + AI.** AI opponent, full round/match loop. First playable duel.
- [ ] **Phase 4 — Weapons & depth.** Multiple attacks, weapon reach/damage data, combos, magic.
- [ ] **Phase 5 — RPG layer.** Equipment, stats, shop, XP/leveling, save system.
- [ ] **Phase 6 — Content & polish.** Enemies, arenas, menus, SFX/music, hitstop/screenshake juice.
- [ ] **Phase 7 — Ship.** Web export to itch.io / iPhone Safari; native builds as stretch goals.

## Deployment notes

- **Web (HTML5):** primary path. Exports to WebAssembly; host on itch.io or any static host;
  open in iPhone Safari and "Add to Home Screen". No Mac or Apple account required.
- **Desktop:** trivial Godot export for Windows/Mac/Linux.
- **Native iOS:** requires macOS + Xcode to build/sign; Apple Developer Program ($99/yr) for
  the App Store or device installs beyond a 7-day sideload. Deferred.
- **Android:** doable later (export template + keystore; $25 one-time Play Store fee).

## Folder structure

```
actors/   fighters, their rigs, state machines
scenes/   gameplay scenes, arenas, Main.tscn
scripts/  shared/global scripts, autoloads
ui/       HUD, menus, touch controls
art/      sprites, rigs, silhouettes, effects
audio/    music and SFX
tools/    one-off editor/setup scripts
```
