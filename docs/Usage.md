# Usage

## Setup

1. Configure the experience for R6 avatars.
2. Create the hierarchy in [Architecture](Architecture.md).
3. Place the files in `src/` at their matching Studio locations.
4. Create the four RemoteEvents documented in [API](API.md).
5. Place `HitVfxTemplate` and its ParticleEmitters under `ReplicatedStorage.FistCombat.Assets`.
6. Verify animation ownership and IDs in `CombatConfig`.

## Controls

| Action | Keyboard / Mouse | Controller | Touch |
| --- | --- | --- | --- |
| Attack | MouseButton1 | ButtonR2 | Screen tap |
| Sprint | LeftControl | ButtonL3 | Project-specific adapter |
| Block | F | ButtonL2 | Project-specific adapter |

Back roll activates by moving backward with mouse lock active.

## Tuning

Edit `CombatConfig` rather than runtime modules.

- `Hitbox`: fixed size, offset, and sweep sampling.
- `Attacks` and `SpecialCombo`: hit timing and damage windows.
- `PvP`: rate limits, range, and angle validation.
- `Run`, `Block`, `LowHealth`, and `RigCombat`: behavior tuning.

Keep `DebugHitboxes` set to `false` in production.
