# API Reference

## RemoteEvents

### PunchRequest

**Direction:** Client to server.
**Payload:** configured attack name.

The server validates type, rate limit, R6 requirements, combat state, attack order, special-combo eligibility, target range, facing, and damage. The client never sends a target or damage amount.

### RunRequest

**Direction:** Client to server.
**Payload:** boolean sprint state.

The server applies sprint speed only after character and state validation.

### BlockRequest

**Direction:** Client to server.
**Payload:** boolean block state.

The server stores the blocking Attribute after validation. Damage reduction also requires the attacker to be inside the defender's configured front arc.

### CombatFeedback

**Direction:** Server to client.

Actions include `SpecialReady`, `HitReaction`, `HitVfx`, `AimLock`, `LowHealthRecovery`, and `CancelAttack`. Feedback is visual only and never authorizes combat outcomes.

## Modules

- `CombatConfig`: centralized gameplay and animation values.
- `AnimationController.new(humanoid, config)`: cached local tracks and playback state.
- `DamageService.findHumanoidFromPart(part)`, `canDamage(...)`, `applyDamage(...)`.
- `HitboxService.createHitboxWindow(character, window, onHumanoidHit, isAttackActive)`: returns a handle with `destroy()`.
- `RigCombatService.engage(rig, player)`: begins rig pursuit when enabled.
