-- Discord: dogi0704_22601 | Roblox: Kj52058
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatRoot = ReplicatedStorage:WaitForChild("FistCombat")
local modules = combatRoot:WaitForChild("Modules")
local remotes = combatRoot:WaitForChild("Remotes")

local CombatConfig = require(modules:WaitForChild("CombatConfig"))
local CombatStateService = require(modules:WaitForChild("CombatStateService"))
local DamageService = require(modules:WaitForChild("DamageService"))
local HitboxService = require(modules:WaitForChild("HitboxService"))
local punchRemote = remotes:WaitForChild("PunchRequest")
local runRemote = remotes:WaitForChild("RunRequest")
local blockRemote = remotes:WaitForChild("BlockRequest")
local feedbackRemote = remotes:WaitForChild("CombatFeedback")
local RigCombatService = require(script.Parent:WaitForChild("RigCombatService"))

-- Keeps server-owned combat data per player so every remote request is checked against the character's real state.
local combatStates = {}

local function isR6Character(character, humanoid)
	return humanoid
		and humanoid.RigType == Enum.HumanoidRigType.R6
		and character:FindFirstChild("Torso")
		and character:FindFirstChild("Left Arm")
		and character:FindFirstChild("Right Arm")
		and character:FindFirstChild("Left Leg")
		and character:FindFirstChild("Right Leg")
		and character:FindFirstChild("HumanoidRootPart")
end

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function destroyHitboxes(state)
	for _, hitbox in ipairs(state.hitboxes) do
		hitbox.destroy()
	end
	table.clear(state.hitboxes)
end

local function resetHitChain(state)
	state.confirmedHits = 0
	state.lastConfirmedHitAt = 0
	state.specialReady = false
end

local function restoreAutoRotate(state, humanoid)
	if state.originalAutoRotate ~= nil and humanoid then
		humanoid.AutoRotate = state.originalAutoRotate
		state.originalAutoRotate = nil
	end
end

local function restoreMovement(state, humanoid)
	if state.normalWalkSpeed and humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = state.normalWalkSpeed
	end
	state.isSprinting = false
end

local function cancelActiveAttack(state, humanoid)
	state.attackToken += 1
	state.activeUntil = 0
	destroyHitboxes(state)
	restoreAutoRotate(state, humanoid)
	restoreMovement(state, humanoid)
end

local function getState(player, character)
	local state = combatStates[player]
	if state and state.character == character then
		return state
	end

	if state then
		disconnectAll(state.connections)
		destroyHitboxes(state)
	end

	state = {
		character = character,
		state = CombatStateService.Names.Idle,
		expectedAttackIndex = 1,
		activeUntil = 0,
		attackToken = 0,
		lastRequestAt = 0,
		lastRunRequestAt = 0,
		lastBlockRequestAt = 0,
		normalWalkSpeed = nil,
		isSprinting = false,
		confirmedHits = 0,
		lastConfirmedHitAt = 0,
		specialReady = false,
		specialCooldownUntil = 0,
		lastHitReactionAt = 0,
		lowHealthArmed = true,
		hitboxes = {},
		connections = {},
	}
	combatStates[player] = state
	return state
end

local function isTargetInRange(attackerCharacter, targetCharacter, angle, referenceLookVector)
	local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not targetRoot then
		return false
	end

	local offset = targetRoot.Position - attackerRoot.Position
	if offset.Magnitude == 0 or offset.Magnitude > CombatConfig.PvP.MaxTargetDistance then
		return false
	end

	local direction = offset.Unit
	local minimumDot = math.cos(math.rad(angle * 0.5))
	local lookVector = referenceLookVector or attackerRoot.CFrame.LookVector
	return lookVector:Dot(direction) >= minimumDot
end

-- Converts client playback timings into server timings so hit windows remain aligned when animation speed changes.
local function getServerAttackData(attackData)
	local playbackSpeed = CombatConfig.AttackPlaybackSpeed
	local hitWindows = table.create(#attackData.HitWindows)

	for index, window in ipairs(attackData.HitWindows) do
		hitWindows[index] = {
			Start = window.Start / playbackSpeed,
			Duration = math.max(window.Duration / playbackSpeed, CombatConfig.Hitbox.MinimumWindowDuration),
			Damage = window.Damage,
		}
	end

	return {
		State = attackData.State,
		Duration = attackData.Duration / playbackSpeed,
		Recovery = attackData.Recovery / playbackSpeed,
		CountsTowardsSpecial = attackData.CountsTowardsSpecial,
		HitWindows = hitWindows,
	}
end

local function hasValidTargetInRange(character)
	local attackerRoot = character:FindFirstChild("HumanoidRootPart")
	if not attackerRoot then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	for _, part in ipairs(workspace:GetPartBoundsInRadius(attackerRoot.Position, CombatConfig.PvP.MaxTargetDistance, overlapParams)) do
		local targetHumanoid, targetCharacter = DamageService.findHumanoidFromPart(part)
		if DamageService.canDamage(character, targetHumanoid)
			and targetCharacter
			and isTargetInRange(character, targetCharacter, CombatConfig.PvP.SpecialComboAngle) then
			return true
		end
	end

	return false
end

local function sendHitVfx(attackerPlayer, targetCharacter)
	local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return
	end

	for _, viewer in ipairs(Players:GetPlayers()) do
		local viewerCharacter = viewer.Character
		local viewerRoot = viewerCharacter and viewerCharacter:FindFirstChild("HumanoidRootPart")
		if viewer == attackerPlayer or viewerCharacter == targetCharacter or (viewerRoot and (viewerRoot.Position - targetRoot.Position).Magnitude <= CombatConfig.HitVfx.AudienceDistance) then
			feedbackRemote:FireClient(viewer, "HitVfx", targetCharacter)
		end
	end
end

local function triggerHitReaction(targetPlayer, targetHumanoid, state)
	local now = os.clock()
	if not targetPlayer or targetHumanoid.Health <= 0 or now < state.lastHitReactionAt + CombatConfig.HitReaction.Cooldown then
		return
	end

	state.lastHitReactionAt = now
	feedbackRemote:FireClient(targetPlayer, "HitReaction")
end

local function registerConfirmedHit(player, state)
	local now = os.clock()
	if now - state.lastConfirmedHitAt > CombatConfig.SpecialCombo.HitChainTimeout then
		state.confirmedHits = 0
	end

	state.confirmedHits += 1
	state.lastConfirmedHitAt = now

	if state.confirmedHits >= CombatConfig.SpecialCombo.RequiredConfirmedHits then
		state.confirmedHits = 0
		state.lastConfirmedHitAt = 0
		state.specialReady = true
		feedbackRemote:FireClient(player, "SpecialReady")
	end
end

local function finishAttack(player, state, humanoid, token, duration, recovery)
	task.delay(duration + recovery, function()
		if combatStates[player] ~= state or state.attackToken ~= token or state.state == CombatStateService.Names.Dead then
			return
		end

		state.activeUntil = 0
		state.state = CombatStateService.Names.Idle
		state.specialLookVector = nil
		destroyHitboxes(state)
		restoreAutoRotate(state, humanoid)
		restoreMovement(state, humanoid)
	end)
end

local function beginLowHealthRecovery(player, state, humanoid)
	if state.state == CombatStateService.Names.Dead or state.state == CombatStateService.Names.LowHealthRecovery then
		return
	end

	cancelActiveAttack(state, humanoid)
	resetHitChain(state)
	state.state = CombatStateService.Names.LowHealthRecovery
	state.lowHealthArmed = false
	local token = state.attackToken
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	feedbackRemote:FireClient(player, "LowHealthRecovery")

	task.delay(CombatConfig.LowHealth.MovementLockDuration, function()
		if combatStates[player] == state and state.attackToken == token and state.state == CombatStateService.Names.LowHealthRecovery and humanoid.Health > 0 then
			humanoid.WalkSpeed = originalWalkSpeed
		end
	end)

	task.delay(CombatConfig.LowHealth.Duration, function()
		if combatStates[player] ~= state or state.attackToken ~= token or humanoid.Health <= 0 then
			return
		end

		state.state = CombatStateService.Names.Idle
		humanoid.WalkSpeed = originalWalkSpeed
	end)
end

local function bindCharacter(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	local state = getState(player, character)

	table.insert(state.connections, humanoid.HealthChanged:Connect(function(health)
		if humanoid.MaxHealth <= 0 then
			return
		end

		local percentage = health / humanoid.MaxHealth
		if percentage >= CombatConfig.LowHealth.ResetPercent then
			state.lowHealthArmed = true
		elseif health > 0 and percentage <= CombatConfig.LowHealth.TriggerPercent and state.lowHealthArmed then
			beginLowHealthRecovery(player, state, humanoid)
		end
	end))

	table.insert(state.connections, humanoid.Died:Connect(function()
		state.state = CombatStateService.Names.Dead
		cancelActiveAttack(state, humanoid)
		resetHitChain(state)
	end))

	table.insert(state.connections, character:GetAttributeChangedSignal("Stunned"):Connect(function()
		if character:GetAttribute("Stunned") then
			cancelActiveAttack(state, humanoid)
			resetHitChain(state)
			if humanoid.Health > 0 then
				state.state = CombatStateService.Names.HitStunned
			end
		elseif state.state == CombatStateService.Names.HitStunned and humanoid.Health > 0 then
			state.state = CombatStateService.Names.Idle
		end
	end))

	table.insert(state.connections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			resetHitChain(state)
		end
	end))

	table.insert(state.connections, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			resetHitChain(state)
		end
	end))
end

local function canDamageTarget(attackerCharacter, targetHumanoid, attackAngle, referenceLookVector)
	if not DamageService.canDamage(attackerCharacter, targetHumanoid) then
		return false
	end

	local targetCharacter = targetHumanoid.Parent
	if not targetCharacter or not targetCharacter:IsA("Model") then
		return false
	end

	return isTargetInRange(attackerCharacter, targetCharacter, attackAngle or CombatConfig.PvP.MaxAttackAngle, referenceLookVector)
end

-- Damage is resolved here after overlap and state checks; clients only request an attack and never choose a target.
local function createHitboxes(player, state, character, attackData, token, damage, angle, referenceLookVector)
	for _, window in ipairs(attackData.HitWindows) do
		local hitbox = HitboxService.createHitboxWindow(character, window, function(part, alreadyHit)
			local targetHumanoid = DamageService.findHumanoidFromPart(part)
			if alreadyHit[targetHumanoid] or not canDamageTarget(character, targetHumanoid, angle, referenceLookVector) then
				return
			end

			alreadyHit[targetHumanoid] = true
			if not DamageService.applyDamage(character, targetHumanoid, window.Damage or damage) then
				return
			end
			sendHitVfx(player, targetHumanoid.Parent)
			feedbackRemote:FireClient(player, "AimLock", targetHumanoid.Parent)

			local targetPlayer = Players:GetPlayerFromCharacter(targetHumanoid.Parent)
			local targetState = targetPlayer and getState(targetPlayer, targetHumanoid.Parent)
			if targetState then
				triggerHitReaction(targetPlayer, targetHumanoid, targetState)
			else
				RigCombatService.engage(targetHumanoid.Parent, player)
			end

			if attackData.CountsTowardsSpecial then
				registerConfirmedHit(player, state)
			end
		end, function()
			return combatStates[player] == state and state.attackToken == token and state.state == attackData.State
		end)

		if hitbox then
			table.insert(state.hitboxes, hitbox)
		end
	end
end

local function onBlockRequest(player, enabled)
	if type(enabled) ~= "boolean" then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or not isR6Character(character, humanoid) then return end
	local state = getState(player, character)
	local now = os.clock()
	if now - state.lastBlockRequestAt < CombatConfig.PvP.BlockRequestInterval then return end
	state.lastBlockRequestAt = now
	if enabled and (CombatStateService.isCharacterBlocked(character) or not CombatStateService.canStartAttack(state.state)) then return end
	character:SetAttribute("Blocking", enabled)
end

local function onRunRequest(player, enabled)
	if type(enabled) ~= "boolean" then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or not isR6Character(character, humanoid) then return end
	local state = getState(player, character)
	local now = os.clock()
	if now - state.lastRunRequestAt < CombatConfig.PvP.RunRequestInterval then return end
	state.lastRunRequestAt = now
	if enabled and (CombatStateService.isCharacterBlocked(character) or not CombatStateService.canStartAttack(state.state)) then return end
	state.normalWalkSpeed = state.normalWalkSpeed or humanoid.WalkSpeed
	state.isSprinting = enabled
	humanoid.WalkSpeed = enabled and CombatConfig.Run.Speed or state.normalWalkSpeed
end

local function onPunchRequest(player, attackName)
	if type(attackName) ~= "string" then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or not isR6Character(character, humanoid) then
		return
	end
	local state = getState(player, character)
	local now = os.clock()
	if now - state.lastRequestAt < CombatConfig.PvP.RequestInterval then
		return
	end
	state.lastRequestAt = now

	if CombatStateService.isCharacterBlocked(character) or not CombatStateService.canStartAttack(state.state) then
		return
	end

	if attackName == "SpecialCombo" then
		if not state.specialReady or now < state.specialCooldownUntil or not hasValidTargetInRange(character) then
			return
		end

		state.normalWalkSpeed = state.normalWalkSpeed or humanoid.WalkSpeed
		state.isSprinting = false
		humanoid.WalkSpeed = state.normalWalkSpeed * CombatConfig.AttackWalkSpeedMultiplier
		state.specialReady = false
		state.specialCooldownUntil = now + CombatConfig.SpecialCombo.Cooldown
		state.expectedAttackIndex = 1
		state.state = CombatStateService.Names.SpecialCombo
		state.attackToken += 1
		local token = state.attackToken
		local specialData = getServerAttackData({
			State = CombatStateService.Names.SpecialCombo,
			Duration = CombatConfig.SpecialCombo.Duration,
			Recovery = CombatConfig.SpecialCombo.Recovery,
			HitWindows = CombatConfig.SpecialCombo.HitWindows,
		})
		state.activeUntil = now + specialData.Duration + specialData.Recovery
		state.originalAutoRotate = humanoid.AutoRotate
		state.specialLookVector = character.HumanoidRootPart.CFrame.LookVector
		humanoid.AutoRotate = false
		createHitboxes(player, state, character, specialData, token, 0, CombatConfig.PvP.SpecialComboAngle, state.specialLookVector)
		finishAttack(player, state, humanoid, token, specialData.Duration, specialData.Recovery)
		return
	end

	local attackData = CombatConfig.Attacks[attackName]
	local expectedAttack = CombatConfig.AttackOrder[state.expectedAttackIndex]
	if not attackData or attackName ~= expectedAttack then
		return
	end

	local serverAttackData = getServerAttackData(attackData)
	state.normalWalkSpeed = state.normalWalkSpeed or humanoid.WalkSpeed
	state.isSprinting = false
	humanoid.WalkSpeed = state.normalWalkSpeed * CombatConfig.AttackWalkSpeedMultiplier
	state.state = serverAttackData.State
	state.attackToken += 1
	local token = state.attackToken
	state.activeUntil = now + serverAttackData.Duration + serverAttackData.Recovery
	state.expectedAttackIndex = (state.expectedAttackIndex % #CombatConfig.AttackOrder) + 1
	createHitboxes(player, state, character, serverAttackData, token, CombatConfig.Damage, CombatConfig.PvP.MaxAttackAngle)
	finishAttack(player, state, humanoid, token, serverAttackData.Duration, serverAttackData.Recovery)
end

punchRemote.OnServerEvent:Connect(onPunchRequest)
runRemote.OnServerEvent:Connect(onRunRequest)
blockRemote.OnServerEvent:Connect(onBlockRequest)

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)
	if player.Character then
		bindCharacter(player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local state = combatStates[player]
	if state then
		disconnectAll(state.connections)
		destroyHitboxes(state)
	end
	combatStates[player] = nil
end)
