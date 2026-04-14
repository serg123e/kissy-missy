local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local KissySmoothingController = {}

local SNAP_THRESHOLD = 20

type KissyState = {
	model: Model,
	hrp: BasePart,
	target: CFrame,
	cframeConn: RBXScriptConnection,
}

local currentKissy: KissyState? = nil
local isLerping = false

local function clearKissy()
	if currentKissy then
		currentKissy.cframeConn:Disconnect()
		currentKissy = nil
	end
end

local function onKissyAdded(model: Instance)
	if not model:IsA("Model") then
		return
	end

	clearKissy()

	local hrp = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not hrp or model.Parent == nil then
		return
	end

	local state: KissyState = {
		model = model,
		hrp = hrp,
		target = hrp.CFrame,
		cframeConn = hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
			if isLerping then
				return
			end
			if currentKissy and currentKissy.hrp == hrp then
				currentKissy.target = hrp.CFrame
			end
		end),
	}

	currentKissy = state
end

local function onKissyRemoved(model: Instance)
	if currentKissy and currentKissy.model == model then
		clearKissy()
	end
end

function KissySmoothingController:Init()
	CollectionService:GetInstanceAddedSignal("KissyNPC"):Connect(onKissyAdded)
	CollectionService:GetInstanceRemovedSignal("KissyNPC"):Connect(onKissyRemoved)

	for _, instance in CollectionService:GetTagged("KissyNPC") do
		task.spawn(onKissyAdded, instance)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		if not currentKissy then
			return
		end

		local hrp = currentKissy.hrp
		local target = currentKissy.target

		if (hrp.Position - target.Position).Magnitude >= SNAP_THRESHOLD then
			isLerping = true
			hrp.CFrame = target
			isLerping = false
			return
		end

		local alpha = 1 - math.exp(-dt * GameConfig.KISSY_VISUAL_LERP_RATE)
		isLerping = true
		hrp.CFrame = hrp.CFrame:Lerp(target, alpha)
		isLerping = false
	end)

	print("[KissySmoothingController] Initialized")
end

return KissySmoothingController
