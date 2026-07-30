local DamageService = {}

function DamageService.findHumanoidFromPart(part)
	local current = part
	while current and current ~= workspace do
		local humanoid = current:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid, current
		end
		current = current.Parent
	end
	return nil, nil
end

function DamageService.canDamage(attackerCharacter, targetHumanoid)
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end

	local targetCharacter = targetHumanoid.Parent
	return targetCharacter and targetCharacter ~= attackerCharacter
end

local CombatConfig = require(game:GetService("ReplicatedStorage").FistCombat.Modules.CombatConfig)

-- Blocking only reduces damage from the defender's forward arc, preventing a block from covering attacks behind them.
local function isDirectionalBlock(attackerCharacter, targetCharacter)
	if not attackerCharacter or not targetCharacter or not targetCharacter:GetAttribute("Blocking") then
		return false
	end

	local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not targetRoot then
		return false
	end

	local offset = attackerRoot.Position - targetRoot.Position
	if offset.Magnitude == 0 then
		return false
	end

	local minimumDot = math.cos(math.rad(CombatConfig.Block.MaxBlockAngle * 0.5))
	return targetRoot.CFrame.LookVector:Dot(offset.Unit) >= minimumDot
end

function DamageService.applyDamage(attackerCharacter, targetHumanoid, amount)
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end

	local targetCharacter = targetHumanoid.Parent
	if isDirectionalBlock(attackerCharacter, targetCharacter) then
		amount *= CombatConfig.Block.DamageMultiplier
	end
	targetHumanoid:TakeDamage(amount)
	return true
end

return DamageService
