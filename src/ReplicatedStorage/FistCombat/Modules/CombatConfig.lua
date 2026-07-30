local CombatConfig = {}

CombatConfig.Damage = 10
CombatConfig.AnimationFadeTime = 0.08
CombatConfig.IdleFadeTime = 0.12
CombatConfig.InputBufferWindow = 0.14
CombatConfig.AttackWalkSpeedMultiplier = 0.72
CombatConfig.AttackPlaybackSpeed = 1.15
CombatConfig.DebugHitboxes = false

CombatConfig.Hitbox = {
	Size = Vector3.new(4.565, 6.397, 5.823),
	ForwardOffset = 0,
	MinimumWindowDuration = 0.12,
	SweepStepDistance = 1,
	MaxSweepSamples = 6,
}

CombatConfig.Animations = {
	Idle = "rbxassetid://115526238010169",
	Run = "rbxassetid://121133347206838",
	Block = "rbxassetid://112314956707971",
	BackRoll = "rbxassetid://121930303855436",
	LeftPunch = "rbxassetid://91891591251709",
	RightPunch = "rbxassetid://127289126900178",
	RightKick = "rbxassetid://86126107894170",
	LeftKick = "rbxassetid://101595350138214",
	HitReaction = "rbxassetid://72135504313045",
	LowHealthRecovery = "rbxassetid://124024635186036",
	SpecialCombo = "rbxassetid://76591298073814",
}

CombatConfig.AttackOrder = { "LeftPunch", "RightPunch", "RightKick", "LeftKick" }

CombatConfig.Block = {
	DamageMultiplier = 0.3,
	MaxBlockAngle = 120,
}

CombatConfig.Run = {
	Speed = 22,
	BotSpeed = 20,
	Fov = 82,
	FovTransition = 0.22,
	MoveThreshold = 0.05,
}

CombatConfig.BackRoll = {
	Cooldown = 0.8,
	BackwardDotThreshold = -0.7,
}

CombatConfig.AimLock = {
	Duration = 0.65,
	MaxDistance = 24,
	TargetHeight = 1.5,
}

CombatConfig.HitVfx = {
	AudienceDistance = 50,
}

CombatConfig.Attacks = {
	LeftPunch = {
		AnimationName = "LeftPunch",
		State = "Attacking",
		Duration = 0.46,
		Recovery = 0.04,
		CountsTowardsSpecial = true,
		HitWindows = {
			{ Start = 0.07, Duration = 0.14 },
		},
	},
	RightPunch = {
		AnimationName = "RightPunch",
		State = "Attacking",
		Duration = 0.46,
		Recovery = 0.04,
		CountsTowardsSpecial = true,
		HitWindows = {
			{ Start = 0.07, Duration = 0.14 },
		},
	},
	RightKick = {
		AnimationName = "RightKick",
		State = "Kicking",
		Duration = 0.32,
		Recovery = 0,
		CountsTowardsSpecial = true,
		HitWindows = {
			{ Start = 0.18, Duration = 0.14 },
		},
	},
	LeftKick = {
		AnimationName = "LeftKick",
		State = "Kicking",
		Duration = 0.34,
		Recovery = 0,
		CountsTowardsSpecial = true,
		HitWindows = {
			{ Start = 0.18, Duration = 0.14 },
		},
	},
}

CombatConfig.SpecialCombo = {
	AnimationName = "SpecialCombo",
	RequiredConfirmedHits = 4,
	HitChainTimeout = 2,
	Cooldown = 6,
	Duration = 2.70,
	Recovery = 0,
	HitWindows = {
		{ Start = 0.383, Duration = 0.08, Damage = 2 },
		{ Start = 0.667, Duration = 0.08, Damage = 2 },
		{ Start = 0.883, Duration = 0.08, Damage = 2 },
		{ Start = 1.117, Duration = 0.08, Damage = 2 },
		{ Start = 1.267, Duration = 0.08, Damage = 2 },
		{ Start = 1.383, Duration = 0.08, Damage = 2 },
		{ Start = 1.500, Duration = 0.08, Damage = 2 },
		{ Start = 1.650, Duration = 0.08, Damage = 2 },
		{ Start = 1.767, Duration = 0.08, Damage = 2 },
		{ Start = 1.883, Duration = 0.08, Damage = 2 },
		{ Start = 1.983, Duration = 0.08, Damage = 2 },
		{ Start = 2.083, Duration = 0.08, Damage = 2 },
		{ Start = 2.450, Duration = 0.12, Damage = 4 },
	},
}

CombatConfig.RigCombat = {
	Enabled = true,
	DetectionRange = 30,
	StopDistance = 4,
	AttackRange = 6,
	AttackCooldown = 0.45,
	Damage = 4,
}

CombatConfig.PvP = {
	RequestInterval = 0.08,
	RunRequestInterval = 0.10,
	BlockRequestInterval = 0.10,
	MaxTargetDistance = 9,
	MaxAttackAngle = 130,
	SpecialComboAngle = 110,
}

CombatConfig.HitReaction = {
	Cooldown = 0.35,
}

CombatConfig.LowHealth = {
	TriggerPercent = 0.30,
	ResetPercent = 0.35,
	Duration = 1.6,
	MovementLockDuration = 0.75,
}

return CombatConfig
