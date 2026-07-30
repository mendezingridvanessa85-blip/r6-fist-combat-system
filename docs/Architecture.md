# Architecture

## Runtime Flow

```text
CombatController (client input and presentation)
  -> RemoteEvents
  -> FistCombatServer (authoritative validation)
  -> HitboxService (overlap windows)
  -> DamageService (damage and directional block)
  -> CombatFeedback (client presentation)
```

The client requests actions and plays local presentation immediately. It never chooses damage, targets, range, attack order, or special-combo progress.

## Studio Hierarchy

```text
ReplicatedStorage
  FistCombat
    Assets
      HitVfxTemplate
    Modules
      CombatConfig
      CombatStateService
      AnimationController
      DamageService
      HitboxService
      HitVfxService
    Remotes
      PunchRequest
      RunRequest
      BlockRequest
      CombatFeedback
ServerScriptService
  FistCombatServer
  RigCombatService
StarterPlayer
  StarterPlayerScripts
    CombatController
```

## Responsibilities

| Component | Side | Responsibility |
| --- | --- | --- |
| CombatConfig | Shared | IDs, timing, hitbox geometry, validation limits, movement, and AI tuning. |
| CombatStateService | Shared | Combat state names and blocked-state checks. |
| CombatController | Client | Input, animation, sprint FOV, back roll, aim lock, and feedback. |
| AnimationController | Client | Cached AnimationTracks and local movement restoration. |
| HitVfxService | Client | Confirmed-hit particle presentation. |
| FistCombatServer | Server | Player state, RemoteEvent validation, hit chains, recovery, and hitbox creation. |
| HitboxService | Server | Fixed overlap-box windows and debug geometry cleanup. |
| DamageService | Server | Humanoid validation, damage, and directional block reduction. |
| RigCombatService | Server | R6 rig pursuit and attacks after engagement. |

Each player uses one server state record. Attack tokens invalidate delayed work from earlier actions. Character death, stun, removal, and player removal clean hitboxes and connections.
