-- IMPORTS
local Types = require('openmw.types')
-- LOCAL SCRIPTS ONLY
local Self = require('openmw.self')

-- MAKE THEM SUFFER
local function damageHandler(data)
	local stats = Types.Actor.stats.dynamic.health(Self)
	stats.current = stats.current - data.damage
end

local function toggleAIHandler(data)
	Self.enableAI(data.enabled)
end

local function fatigueHandler(data)
	local stats = Types.Actor.stats.dynamic.fatigue(Self)
	if data.reset then
		-- Note that calling this from the update function screws it up...
		stats.current = stats.base
	else
		-- Knockdown target
		stats.current = -1
	end
end

return {
	eventHandlers = {
		TK_Damage = damageHandler, 
		TK_Ai = toggleAIHandler,
		TK_Fatigue = fatigueHandler
	}
}