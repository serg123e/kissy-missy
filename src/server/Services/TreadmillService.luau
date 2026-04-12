-- Detects players on treadmills and increases their speed over time
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local TreadmillService = {}

local PlayerService
local RoundService
local cachedTreadmills: { BasePart } = {}

function TreadmillService:Init(playerService, roundService)
	PlayerService = playerService
	RoundService = roundService
	print("[TreadmillService] Initialized")
end

function TreadmillService:Start()
	-- Cache treadmill parts once — they are static map objects
	local folder = workspace:FindFirstChild("Treadmills")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(cachedTreadmills, child)
			end
		end
	end

	if #cachedTreadmills == 0 then
		warn("[TreadmillService] No treadmill parts found — training disabled")
		return
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.TREADMILL_TICK_SECONDS)
			self:_tick()
		end
	end)
	print("[TreadmillService] Training loop started (" .. #cachedTreadmills .. " treadmills)")
end

function TreadmillService:_tick()
	local state = RoundService:GetState()
	if state ~= "SafeZone" and state ~= "Hunt" then
		return
	end

	for _, player in PlayerService:GetAlivePlayers() do
		if self:_isOnTreadmill(player) then
			local data = PlayerService:GetData(player)
			if data and data.speed < GameConfig.MAX_PLAYER_SPEED then
				PlayerService:SetSpeed(player, data.speed + GameConfig.SPEED_PER_TREADMILL_TICK)
			end
		end
	end
end

function TreadmillService:_isOnTreadmill(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	local pos = hrp.Position
	for _, treadmill in cachedTreadmills do
		-- Horizontal distance (XZ plane)
		local dx = pos.X - treadmill.Position.X
		local dz = pos.Z - treadmill.Position.Z
		local horizontalDist = math.sqrt(dx * dx + dz * dz)
		local radius = math.max(treadmill.Size.X, treadmill.Size.Z) / 2 + 1

		-- Vertical: -1 allows slight floor overlap; 6 covers a standing character
		-- (~5 studs tall in Roblox) above the treadmill surface
		local treadmillTop = treadmill.Position.Y + treadmill.Size.Y / 2
		local dy = pos.Y - treadmillTop
		local onTop = dy >= -1 and dy <= 6

		if horizontalDist <= radius and onTop then
			return true
		end
	end

	return false
end

return TreadmillService
