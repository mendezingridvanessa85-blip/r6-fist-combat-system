# R6 Fist Combat System

A server-authoritative R6 melee combat system for Roblox Studio. Client input stays responsive while the server validates damage, targets, range, attack order, cooldowns, and combat states.

## Features

- Alternating left punch, right punch, right kick, and left kick attacks.
- One buffered follow-up input for responsive chaining.
- Server validation for R6 characters, state, sequence, rate limits, distance, and facing.
- Fixed overlap hitboxes updated through `RunService.Heartbeat`.
- Directional blocking, confirmed-hit special combo, low-health recovery, sprint, back roll, hit reaction, VFX, and short aim-lock feedback.
- R6 rig AI that pursues and attacks the player that engages it.
- Mouse, touch, and controller attack bindings.

## Architecture

`CombatController` owns local input and presentation. It sends lightweight RemoteEvent requests to `FistCombatServer`, which creates validated hit windows through `HitboxService` and applies damage through `DamageService`.

```text
CombatController (client)
  -> PunchRequest / RunRequest / BlockRequest
  -> FistCombatServer (server validation)
  -> HitboxService + DamageService
  -> CombatFeedback (client presentation)
```

See [Architecture](docs/Architecture.md), [API](docs/API.md), [Usage](docs/Usage.md), and [Programming Decisions](docs/Programming-Decisions.md).

## Repository Layout

```text
src/
  ReplicatedStorage/FistCombat/
    Assets/
    Modules/
    Remotes/
  ServerScriptService/
  StarterPlayer/StarterPlayerScripts/
docs/
README.md
LICENSE
.gitignore
```

The `src/` directory mirrors the live Studio hierarchy for code review. It is not an automatic Studio importer.

## Requirements

- Roblox experience configured for R6 characters.
- The `FistCombat` hierarchy placed as documented in [Architecture](docs/Architecture.md).
- Animation assets in `CombatConfig` available to the experience owner.

## Testing

1. Start a two-player Roblox Studio test.
2. Attack with MouseButton1, touch, or ButtonR2.
3. Sprint with LeftControl or ButtonL3 while moving.
4. Block with F or ButtonL2.
5. Land confirmed hits to charge the special combo, then attack again while ready.
6. Set `CombatConfig.DebugHitboxes` to `true` only when calibrating.

## License

Released under the [MIT License](LICENSE).
