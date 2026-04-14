-- Minimal Enum stub so GameConfig.luau can load under Lune.
-- Usage: require this module before requiring GameConfig.
-- It sets the global `Enum` table with a KeyCode metatable
-- that returns { Name = key } for any index.

local enumKeyCode = setmetatable({}, {
	__index = function(_, k)
		return { Name = k }
	end,
})

Enum = {
	KeyCode = enumKeyCode,
}

return true
