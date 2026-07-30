# Programming Decisions

## Server authority

Local animation is immediate for responsiveness, but the server validates state, order, timing, range, facing, targets, special progress, and damage. Remote payloads stay deliberately small because clients are not trusted to report hits.

## Overlap hitboxes

`GetPartBoundsInBox` with `OverlapParams` replaces `.Touched` as the source of combat hits. Queries run only during configured active windows and maintain a per-window hit list. Movement is sampled across Heartbeat frames to reduce misses.

## Fixed geometry

Melee attacks share the fixed hitbox from `CombatConfig`. The box follows the HumanoidRootPart, keeping calibration predictable across punches, kicks, and special-combo windows.

## Timing and cleanup

The server transforms configured windows to match `AttackPlaybackSpeed`. Attack tokens invalidate delayed callbacks after state changes. Player and rig states own their temporary connections and tracks so cancellation, death, and removal clean up correctly.

## Scope

This repository intentionally focuses on R6 melee combat. It does not add weapons, stamina, parries, ragdolls, audio, or UI frameworks.
