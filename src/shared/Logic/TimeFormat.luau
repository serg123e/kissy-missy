local TimeFormat = {}

function TimeFormat.format(seconds: number): string
	local clamped = math.max(0, seconds)
	local m = math.floor(clamped / 60)
	local s = math.floor(clamped % 60)
	return string.format("%d:%02d", m, s)
end

return TimeFormat
