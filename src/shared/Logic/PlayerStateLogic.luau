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

function PlayerStateLogic.countAlive(map: { [any]: { state: string } }): number
	local count = 0
	for _, data in map do
		if data.state == "Alive" then
			count += 1
		end
	end
	return count
end

return PlayerStateLogic
