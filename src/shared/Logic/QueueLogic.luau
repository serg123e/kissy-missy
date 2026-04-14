--!strict
local QueueLogic = {}

type QueueState = {
	activeUser: any?,
	queue: { any },
}

function QueueLogic.tryAssign(state: QueueState, player: any, maxQueueLength: number): (string, number?)
	if not state.activeUser then
		state.activeUser = player
		return "active", 1
	end

	if #state.queue >= maxQueueLength then
		return "rejected", nil
	end

	table.insert(state.queue, player)
	return "queued", #state.queue + 1
end

function QueueLogic.remove(state: QueueState, player: any): (string, any?)
	if state.activeUser == player then
		state.activeUser = nil
		if #state.queue > 0 then
			local promoted = table.remove(state.queue, 1)
			state.activeUser = promoted
			return "wasActive", promoted
		end
		return "wasActive", nil
	end

	for i, p in state.queue do
		if p == player then
			table.remove(state.queue, i)
			return "wasQueued", nil
		end
	end

	return "notPresent", nil
end

function QueueLogic.positionOf(state: QueueState, player: any): number?
	if state.activeUser == player then
		return 1
	end

	for i, p in state.queue do
		if p == player then
			return i + 1
		end
	end

	return nil
end

return QueueLogic
