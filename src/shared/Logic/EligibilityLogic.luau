local EligibilityLogic = {}

function EligibilityLogic.isEligibleForSurvivalReward(
	data: { state: string, joinedRound: number },
	currentRound: number
): boolean
	return data.state == "Alive" and data.joinedRound == currentRound
end

function EligibilityLogic.snapshotEligible(playerDataMap: { [any]: { joinedRound: number } }, roundNumber: number)
	for _, data in playerDataMap do
		data.joinedRound = roundNumber
	end
end

return EligibilityLogic
