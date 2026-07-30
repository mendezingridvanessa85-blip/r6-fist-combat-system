local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = ReplicatedStorage:WaitForChild("FistCombat"):WaitForChild("Assets")

local HitVfxService = {}

function HitVfxService.play(targetCharacter)
	local hitVfxTemplate = assets:FindFirstChild("HitVfxTemplate")
	local targetPart = targetCharacter and (targetCharacter:FindFirstChild("Torso") or targetCharacter:FindFirstChild("HumanoidRootPart"))
	if not hitVfxTemplate or not hitVfxTemplate:IsA("BasePart") or not targetPart or not targetPart:IsA("BasePart") then
		return
	end

	-- Attach the effect to the target so the impact stays in place while the character continues moving.
	local attachment = Instance.new("Attachment")
	attachment.Parent = targetPart

	for _, child in ipairs(hitVfxTemplate:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			local emitter = child:Clone()
			emitter.Rate = math.max(emitter.Rate, 70)
			emitter.Enabled = true
			emitter.Parent = attachment
		end
	end

	task.delay(0.35, function()
		for _, child in ipairs(attachment:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
	end)
	Debris:AddItem(attachment, 2)
end

return HitVfxService
