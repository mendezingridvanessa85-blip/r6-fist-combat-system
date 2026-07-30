local AnimationController = {}
AnimationController.__index = AnimationController

local priorities = {
	Idle = Enum.AnimationPriority.Idle,
	Run = Enum.AnimationPriority.Movement,
	Block = Enum.AnimationPriority.Action2,
	HitReaction = Enum.AnimationPriority.Action2,
	LowHealthRecovery = Enum.AnimationPriority.Action3,
	SpecialCombo = Enum.AnimationPriority.Action3,
}

function AnimationController.new(humanoid, config)
	local self = setmetatable({}, AnimationController)
	self.humanoid = humanoid
	self.config = config
	self.tracks = {}
	self.isPunching = false
	self.isRecovering = false
	self.isRunning = false
	self.isBlocking = false
	self.isRolling = false
	self.activeTrack = nil
	self.activeStoppedConnection = nil
	self.backRollStoppedConnection = nil
	self.movementRestoreToken = 0
	self.originalWalkSpeed = nil
	self:_loadAnimations()
	return self
end

-- Tracks are loaded once per character to avoid creating new Animation instances during combat.
function AnimationController:_loadAnimations()
	local animator = self.humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = self.humanoid
	end

	for name, id in pairs(self.config.Animations) do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = id

		local track = animator:LoadAnimation(animation)
		track.Looped = name == "Idle" or name == "Run" or name == "Block"
		track.Priority = priorities[name] or Enum.AnimationPriority.Action
		self.tracks[name] = track
	end
end

function AnimationController:playIdle()
	local idle = self.tracks.Idle
	if idle and not idle.IsPlaying and not self.isRecovering then
		idle:Play(self.config.IdleFadeTime)
	end
end

function AnimationController:_restoreMovement()
	if self.originalWalkSpeed then
		self.humanoid.WalkSpeed = self.originalWalkSpeed
		self.originalWalkSpeed = nil
	end
end

function AnimationController:_disconnectActiveTrack()
	if self.activeStoppedConnection then
		self.activeStoppedConnection:Disconnect()
		self.activeStoppedConnection = nil
	end
end

function AnimationController:_disconnectBackRollTrack()
	if self.backRollStoppedConnection then
		self.backRollStoppedConnection:Disconnect()
		self.backRollStoppedConnection = nil
	end
end

function AnimationController:isWithinInputBufferWindow()
	local track = self.activeTrack
	if not track or not track.IsPlaying then
		return false
	end

	local duration = track.Length > 0 and track.Length or self.config.Attacks.LeftPunch.Duration
	return (duration - track.TimePosition) / self.config.AttackPlaybackSpeed <= self.config.InputBufferWindow
end

function AnimationController:playBlock()
	if self.isBlocking or self.isPunching or self.isRecovering or self.isRolling then
		return false
	end
	local track = self.tracks.Block
	if not track then
		return false
	end
	self:stopRun()
	self.isBlocking = true
	track:Play(self.config.AnimationFadeTime)
	return true
end

function AnimationController:stopBlock()
	local track = self.tracks.Block
	if track and track.IsPlaying then
		track:Stop(self.config.AnimationFadeTime)
	end
	self.isBlocking = false
end

function AnimationController:playRun()
	if self.isRunning or self.isBlocking or self.isPunching or self.isRecovering or self.isRolling then
		return false
	end
	local track = self.tracks.Run
	if not track then
		return false
	end
	self.isRunning = true
	track:Play(self.config.AnimationFadeTime)
	return true
end

function AnimationController:stopRun()
	local track = self.tracks.Run
	if track and track.IsPlaying then
		track:Stop(self.config.AnimationFadeTime)
	end
	self.isRunning = false
end

function AnimationController:stopBackRoll()
	self:_disconnectBackRollTrack()
	local track = self.tracks.BackRoll
	if track and track.IsPlaying then
		track:Stop(self.config.AnimationFadeTime)
	end
	self.isRolling = false
end

function AnimationController:playBackRoll()
	if self.isRolling or self.isBlocking or self.isPunching or self.isRecovering then
		return false
	end

	local track = self.tracks.BackRoll
	if not track then
		return false
	end

	self:stopRun()
	self.isRolling = true
	self:_disconnectBackRollTrack()
	self.backRollStoppedConnection = track.Stopped:Connect(function()
		self:_disconnectBackRollTrack()
		self.isRolling = false
		self:playIdle()
	end)
	track:Play(self.config.AnimationFadeTime)
	return true
end

function AnimationController:playAttack(animationName, onFinished)
	if self.isBlocking or self.isPunching or self.isRecovering or self.isRolling then
		return false
	end

	local track = self.tracks[animationName]
	if not track then
		return false
	end

	self:stopRun()
	self.isPunching = true
	self.activeTrack = track
	self.originalWalkSpeed = self.humanoid.WalkSpeed

	local idle = self.tracks.Idle
	if idle and idle.IsPlaying then
		idle:Stop(self.config.AnimationFadeTime)
	end

	self.humanoid.WalkSpeed = self.originalWalkSpeed * self.config.AttackWalkSpeedMultiplier
	self:_disconnectActiveTrack()
	self.activeStoppedConnection = track.Stopped:Connect(function()
		if self.activeTrack ~= track then
			return
		end

		self:_disconnectActiveTrack()
		self.activeTrack = nil
		self.isPunching = false
		self:_restoreMovement()
		self:playIdle()

		if onFinished then
			onFinished()
		end
	end)

	track:Play(self.config.AnimationFadeTime, 1, self.config.AttackPlaybackSpeed)
	return true
end

function AnimationController:playPunch(animationName, onFinished)
	return self:playAttack(animationName, onFinished)
end

function AnimationController:playHitReaction()
	if self.isRecovering then
		return false
	end

	local track = self.tracks.HitReaction
	if not track then
		return false
	end

	track:Play(self.config.AnimationFadeTime)
	return true
end

function AnimationController:playLowHealthRecovery(onFinished)
	if self.isRecovering then
		return false
	end

	local track = self.tracks.LowHealthRecovery
	if not track then
		return false
	end

	self.isRecovering = true
	self:stopRun()
	self:stopBackRoll()
	if self.activeTrack and self.activeTrack.IsPlaying then
		self.activeTrack:Stop(self.config.AnimationFadeTime)
	end
	local hitReaction = self.tracks.HitReaction
	if hitReaction and hitReaction.IsPlaying then
		hitReaction:Stop(self.config.AnimationFadeTime)
	end

	self.originalWalkSpeed = self.originalWalkSpeed or self.humanoid.WalkSpeed
	self.humanoid.WalkSpeed = 0
	-- The token invalidates an older delayed restore when another recovery state replaces it.
	self.movementRestoreToken += 1
	local restoreToken = self.movementRestoreToken
	task.delay(self.config.LowHealth.MovementLockDuration, function()
		if self.isRecovering and self.movementRestoreToken == restoreToken then
			self:_restoreMovement()
		end
	end)

	local connection
	connection = track.Stopped:Connect(function()
		connection:Disconnect()
		if not self.isRecovering then
			return
		end
		self.isRecovering = false
		self:_restoreMovement()
		self:playIdle()
		if onFinished then
			onFinished()
		end
	end)

	track:Play(self.config.AnimationFadeTime)
	return true
end

function AnimationController:destroy()
	self:_disconnectActiveTrack()
	self:stopBackRoll()
	self.movementRestoreToken += 1
	self:_restoreMovement()

	for _, track in pairs(self.tracks) do
		track:Stop(0)
		track:Destroy()
	end

	table.clear(self.tracks)
	self.activeTrack = nil
	self.isPunching = false
	self.isRecovering = false
	self.isRolling = false
end

return AnimationController
