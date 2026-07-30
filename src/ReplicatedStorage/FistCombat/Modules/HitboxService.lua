local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.FistCombat.Modules.CombatConfig)
local HitboxService = {}

local function createDebugHitbox()
	local hitbox = Instance.new("Part")
	hitbox.Name = "FistDebugHitbox"
	hitbox.Size = CombatConfig.Hitbox.Size
	hitbox.Color = Color3.fromRGB(255, 0, 0)
	hitbox.Material = Enum.Material.Neon
	hitbox.Transparency = 0.5
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = true
	hitbox.CanQuery = false
	hitbox.Massless = true
	hitbox.CastShadow = false
	return hitbox
end

function HitboxService.createHitboxWindow(character, window, onHumanoidHit, isAttackActive)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	local alreadyHit = {}
	local hitbox
	local heartbeatConnection
	local isFinished = false
	local previousCFrame

	local function finish()
		if isFinished then
			return
		end

		isFinished = true
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
		if hitbox then
			hitbox:Destroy()
			hitbox = nil
		end
	end

	-- The hit list belongs to this window, allowing multi-hit attacks while preventing repeat damage within one impact.
	local function queryAt(hitboxCFrame)
		for _, part in ipairs(workspace:GetPartBoundsInBox(hitboxCFrame, CombatConfig.Hitbox.Size, overlapParams)) do
			onHumanoidHit(part, alreadyHit)
		end
	end

	task.delay(window.Start, function()
		if isFinished or not character.Parent or not root.Parent or (isAttackActive and not isAttackActive()) then
			finish()
			return
		end

		if CombatConfig.DebugHitboxes then
			hitbox = createDebugHitbox()
			hitbox.Parent = workspace
		end

		-- Query immediately before Heartbeat begins so short windows do not lose their first simulation frame.
		local activeUntil = os.clock() + window.Duration
		local initialCFrame = root.CFrame * CFrame.new(0, 0, -CombatConfig.Hitbox.ForwardOffset)
		if hitbox then
			hitbox.CFrame = initialCFrame
		end
		queryAt(initialCFrame)
		previousCFrame = initialCFrame

		heartbeatConnection = RunService.Heartbeat:Connect(function()
			if os.clock() >= activeUntil or not character.Parent or not root.Parent or (isAttackActive and not isAttackActive()) then
				finish()
				return
			end

			local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -CombatConfig.Hitbox.ForwardOffset)
			if hitbox then
				hitbox.CFrame = hitboxCFrame
			end

			local distance = (hitboxCFrame.Position - previousCFrame.Position).Magnitude
			local sampleCount = math.clamp(
				math.ceil(distance / CombatConfig.Hitbox.SweepStepDistance),
				1,
				CombatConfig.Hitbox.MaxSweepSamples
			)
			for sample = 1, sampleCount do
				queryAt(previousCFrame:Lerp(hitboxCFrame, sample / sampleCount))
			end

			previousCFrame = hitboxCFrame
		end)
	end)

	return {
		destroy = finish,
	}
end


return HitboxService
