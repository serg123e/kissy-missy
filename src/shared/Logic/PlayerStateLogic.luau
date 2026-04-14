--!strict
local PlayerStateLogic = {}

function PlayerStateLogic.canCapture(data: { state: string }?): boolean
	if not data then
		return false
	end
	return data.state == "Alive"
end

function PlayerStateLogic.canFree(data: { state: string }?): boolean
	if not data then
		return false
	end
	return data.state == "Captured"
end

return PlayerStateLogic
