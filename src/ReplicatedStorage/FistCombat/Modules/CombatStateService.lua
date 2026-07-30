local CombatStateService = {}

CombatStateService.Names = {
	Idle = "Idle",
	Attacking = "Attacking",
	Kicking = "Kicking",
	SpecialCombo = "SpecialCombo",
	HitStunned = "HitStunned",
	LowHealthRecovery = "LowHealthRecovery",
	Dead = "Dead",
}

function CombatStateService.canStartAttack(stateName)
	return stateName == CombatStateService.Names.Idle
end

function CombatStateService.isCharacterBlocked(character)
	return not character
		or character:GetAttribute("Stunned") == true
		or character:GetAttribute("CombatDisabled") == true
		or character:GetAttribute("Blocking") == true
end

return CombatStateService
