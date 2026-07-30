local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatRoot = ReplicatedStorage:WaitForChild("FistCombat")
local modules = combatRoot:WaitForChild("Modules")

local CombatConfig = require(modules:WaitForChild("CombatConfig"))
local DamageService = require(modules:WaitForChild("DamageService"))
local HitboxService = require(modules:WaitForChild("HitboxService"))

local RigCombatService = {}
local states = {}

-- Rig state owns its tracks and connections, so cleanup happens from one place on death or removal.
local function destroyState(state)
	if states[state.rig] ~= state then
		return
	end

	states[state.rig] = nil
	state.isAttacking = false
	state.targetPlayer = nil
	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end
	for _, track in pairs(state.tracks) do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(state.connections)
	table.clear(state.tracks)
end

local function getState(rig)
	local state = states[rig]
	if state then
		return state
	end

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	state = {
		rig = rig,
		humanoid = humanoid,
		root = root,
		animator = animator,
		tracks = {},
		runTrack = nil,
		normalWalkSpeed = humanoid.WalkSpeed,
		targetPlayer = nil,
		attackIndex = 1,
		isAttacking = false,
		attackToken = 0,
		nextAttackAt = 0,
		isRunning = false,
		connections = {},
	}
	states[rig] = state
	table.insert(state.connections, humanoid.Died:Connect(function()
		destroyState(state)
	end))
	table.insert(state.connections, rig.AncestryChanged:Connect(function(_, parent)
		if not parent then
			destroyState(state)
		end
	end))
	return state
end

-- Cache each rig track after its first load to keep repeated attacks from allocating animation objects.
local function getTrack(state, animationName)
	local track = state.tracks[animationName]
	if track then
		return track
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = CombatConfig.Animations[animationName]
	track = state.animator:LoadAnimation(animation)
	track.Looped = animationName == "Run"
	track.Priority = animationName == "Run" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Action
	state.tracks[animationName] = track
	return track
end

local function setRunning(state, enabled)
	local track = state.runTrack or getTrack(state, "Run")
	state.runTrack = track
	if enabled and not track.IsPlaying then
		track:Play(CombatConfig.AnimationFadeTime)
	elseif not enabled and track.IsPlaying then
		track:Stop(CombatConfig.AnimationFadeTime)
	end
end

local function isValidTarget(state)
	local player = state.targetPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function performAttack(state)
	local character, targetHumanoid, targetRoot = isValidTarget(state)
	if not character or not targetHumanoid or targetHumanoid.Health <= 0 or not targetRoot then
		return
	end

	local attackName = CombatConfig.AttackOrder[state.attackIndex]
	local attackData = CombatConfig.Attacks[attackName]
	if not attackData then
		return
	end

	setRunning(state, false)
	state.humanoid.WalkSpeed = state.normalWalkSpeed
	state.isAttacking = true
	state.attackToken += 1
	local token = state.attackToken
	state.nextAttackAt = os.clock() + attackData.Duration + CombatConfig.RigCombat.AttackCooldown
	state.attackIndex = (state.attackIndex % #CombatConfig.AttackOrder) + 1

	local track = getTrack(state, attackData.AnimationName)
	track:Play(CombatConfig.AnimationFadeTime)

	for _, window in ipairs(attackData.HitWindows) do
		HitboxService.createHitboxWindow(state.rig, window, function(part, alreadyHit)
			local humanoid, model = DamageService.findHumanoidFromPart(part)
			if humanoid ~= targetHumanoid or model ~= character or alreadyHit[humanoid] then
				return
			end

			alreadyHit[humanoid] = true
			DamageService.applyDamage(state.rig, humanoid, CombatConfig.RigCombat.Damage)
		end, function()
			return state.isAttacking
				and state.attackToken == token
				and state.rig.Parent
				and state.humanoid.Health > 0
		end)
	end

	task.delay(attackData.Duration, function()
		if states[state.rig] == state and state.attackToken == token then
			state.isAttacking = false
		end
	end)
end

local function run(state)
	if state.isRunning then
		return
	end

	state.isRunning = true
	task.spawn(function()
		while states[state.rig] == state and state.rig.Parent and state.humanoid.Health > 0 do
			local character, targetHumanoid, targetRoot = isValidTarget(state)
			if not character or not targetHumanoid or targetHumanoid.Health <= 0 or not targetRoot then
				state.targetPlayer = nil
				break
			end

			local offset = targetRoot.Position - state.root.Position
			local distance = offset.Magnitude
			if distance > CombatConfig.RigCombat.DetectionRange then
				state.targetPlayer = nil
				break
			end

			if not state.isAttacking then
				if distance > CombatConfig.RigCombat.StopDistance then
					state.humanoid.WalkSpeed = CombatConfig.Run.BotSpeed
					setRunning(state, true)
					state.humanoid:MoveTo(targetRoot.Position)
				else
					setRunning(state, false)
					state.humanoid.WalkSpeed = state.normalWalkSpeed
					state.humanoid:MoveTo(state.root.Position)
					if distance > 0 then
						state.root.CFrame = CFrame.lookAt(state.root.Position, Vector3.new(targetRoot.Position.X, state.root.Position.Y, targetRoot.Position.Z))
					end
				end

				if distance <= CombatConfig.RigCombat.AttackRange and os.clock() >= state.nextAttackAt then
					performAttack(state)
				end
			end

			task.wait(0.1)
		end

		if states[state.rig] == state then
			state.isRunning = false
		end
	end)
end

function RigCombatService.engage(rig, player)
	if not CombatConfig.RigCombat.Enabled or not rig or not player or Players:GetPlayerFromCharacter(rig) then
		return
	end

	local state = getState(rig)
	if not state then
		return
	end

	state.targetPlayer = player
	run(state)
end

return RigCombatService
