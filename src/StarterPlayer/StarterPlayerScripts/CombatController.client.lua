local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local combatRoot = ReplicatedStorage:WaitForChild("FistCombat")
local modules = combatRoot:WaitForChild("Modules")
local remotes = combatRoot:WaitForChild("Remotes")

local CombatConfig = require(modules:WaitForChild("CombatConfig"))
local AnimationController = require(modules:WaitForChild("AnimationController"))
local HitVfxService = require(modules:WaitForChild("HitVfxService"))
local punchRemote = remotes:WaitForChild("PunchRequest")
local runRemote = remotes:WaitForChild("RunRequest")
local blockRemote = remotes:WaitForChild("BlockRequest")
local feedbackRemote = remotes:WaitForChild("CombatFeedback")

local nextAttackIndex = 1
local bufferedAttack = false
local specialReady = false
local animationController
local runInputHeld = false
local isRunning = false
local movementConnection
local defaultFov = 70
local activeFovTween
local wasMovingBackward = false
local nextBackRollAt = 0
local aimLockUntil = 0

local function clearAimLock()
	RunService:UnbindFromRenderStep("FistCombatAimLock")
	aimLockUntil = 0
end

-- Aim lock is local presentation only; the server has already confirmed the hit before this feedback is received.
local function startAimLock(targetCharacter)
	clearAimLock()
	if not targetCharacter or not targetCharacter:IsA("Model") then
		return
	end

	aimLockUntil = os.clock() + CombatConfig.AimLock.Duration
	RunService:BindToRenderStep("FistCombatAimLock", Enum.RenderPriority.Camera.Value + 1, function()
		local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		local targetPart = targetCharacter:FindFirstChild("HumanoidRootPart") or targetCharacter:FindFirstChild("Torso")
		local camera = Workspace.CurrentCamera
		if not targetHumanoid or targetHumanoid.Health <= 0 or not targetPart or not camera or os.clock() >= aimLockUntil then
			clearAimLock()
			return
		end

		local targetPosition = targetPart.Position + Vector3.new(0, CombatConfig.AimLock.TargetHeight, 0)
		if (targetPosition - camera.CFrame.Position).Magnitude > CombatConfig.AimLock.MaxDistance then
			clearAimLock()
			return
		end

		camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPosition)
	end)
end

local function setRunning(enabled)
	if not animationController or animationController.isPunching or animationController.isRecovering or animationController.isRolling then
		enabled = false
	end
	if isRunning == enabled then
		return
	end
	isRunning = enabled
	if enabled then
		animationController:playRun()
	else
		animationController:stopRun()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		if activeFovTween then activeFovTween:Cancel() end
		activeFovTween = TweenService:Create(camera, TweenInfo.new(CombatConfig.Run.FovTransition), { FieldOfView = enabled and CombatConfig.Run.Fov or defaultFov })
		activeFovTween:Play()
	end
	runRemote:FireServer(enabled)
end

local function updateBackRoll()
	local humanoid = animationController and animationController.humanoid
	local character = humanoid and humanoid.Parent
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		wasMovingBackward = false
		return false
	end

	local direction = humanoid.MoveDirection
	local isMovingBackward = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		and direction.Magnitude > CombatConfig.Run.MoveThreshold
		and direction:Dot(rootPart.CFrame.LookVector) <= CombatConfig.BackRoll.BackwardDotThreshold

	if isMovingBackward and not wasMovingBackward and os.clock() >= nextBackRollAt then
		setRunning(false)
		if animationController:playBackRoll() then
			nextBackRollAt = os.clock() + CombatConfig.BackRoll.Cooldown
		end
	end

	wasMovingBackward = isMovingBackward
	return animationController.isRolling
end

local function updateRunning()
	if updateBackRoll() then
		setRunning(false)
		return
	end

	local humanoid = animationController and animationController.humanoid
	setRunning(runInputHeld and humanoid and humanoid.MoveDirection.Magnitude > CombatConfig.Run.MoveThreshold)
end

local function setBlocking(enabled)
	if not animationController then return end
	if enabled then
		if animationController:playBlock() then
			blockRemote:FireServer(true)
		end
	else
		animationController:stopBlock()
		blockRemote:FireServer(false)
	end
end

local function getNextAttackName()
	if specialReady then
		return "SpecialCombo"
	end
	return CombatConfig.AttackOrder[nextAttackIndex]
end

local function startAttack()
	setRunning(false)
	if not animationController or animationController.isPunching or animationController.isRecovering or animationController.isRolling then
		return
	end

	local attackName = getNextAttackName()
	local attackData = CombatConfig.Attacks[attackName] or CombatConfig.SpecialCombo
	if not attackData then
		return
	end

	local didPlay = animationController:playAttack(attackData.AnimationName, function()
		if not bufferedAttack then
			return
		end

		bufferedAttack = false
		task.defer(startAttack)
	end)
	if not didPlay then
		return
	end

	punchRemote:FireServer(attackName)

	if attackName == "SpecialCombo" then
		specialReady = false
		nextAttackIndex = 1
	else
		nextAttackIndex = (nextAttackIndex % #CombatConfig.AttackOrder) + 1
	end
end

local function handleAttackInput()
	if not animationController or animationController.isRecovering or animationController.isRolling then
		return
	end

	if animationController.isPunching then
		if not bufferedAttack and animationController:isWithinInputBufferWindow() then
			bufferedAttack = true
		end
		return
	end

	startAttack()
end

local function onBlockAction(_, inputState)
	setBlocking(inputState == Enum.UserInputState.Begin)
	return Enum.ContextActionResult.Sink
end

local function onRunAction(_, inputState)
	runInputHeld = inputState == Enum.UserInputState.Begin
	updateRunning()
	return Enum.ContextActionResult.Pass
end

local function onAttackAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		handleAttackInput()
	end
	return Enum.ContextActionResult.Pass
end

-- Respawns replace every local reference and connection so input state cannot leak from the previous character.
local function setupCharacter(character)
	clearAimLock()
	if movementConnection then movementConnection:Disconnect() end
	if animationController then
		animationController:destroy()
	end

	nextAttackIndex = 1
	bufferedAttack = false
	specialReady = false
	runInputHeld = false
	isRunning = false
	wasMovingBackward = false
	nextBackRollAt = 0
	local camera = Workspace.CurrentCamera
	if camera then defaultFov = camera.FieldOfView end

	local humanoid = character:WaitForChild("Humanoid")
	animationController = AnimationController.new(humanoid, CombatConfig)
	movementConnection = humanoid.Running:Connect(updateRunning)
	animationController:playIdle()
end

feedbackRemote.OnClientEvent:Connect(function(action, targetCharacter)
	if not animationController then
		return
	end

	if action == "SpecialReady" then
		specialReady = true
	elseif action == "HitReaction" then
		animationController:playHitReaction()
	elseif action == "HitVfx" then
		HitVfxService.play(targetCharacter)
	elseif action == "AimLock" then
		startAimLock(targetCharacter)
	elseif action == "LowHealthRecovery" then
		bufferedAttack = false
		animationController:playLowHealthRecovery()
	elseif action == "CancelAttack" then
		bufferedAttack = false
	end
end)

ContextActionService:BindAction(
	"FistCombatBlock",
	onBlockAction,
	true,
	Enum.KeyCode.F,
	Enum.KeyCode.ButtonL2
)

ContextActionService:BindAction(
	"FistCombatRun",
	onRunAction,
	false,
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.ButtonL3
)

ContextActionService:BindAction(
	"FistCombatAttack",
	onAttackAction,
	false,
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.Touch,
	Enum.KeyCode.ButtonR2
)

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)
