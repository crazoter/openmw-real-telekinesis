-- IMPORTS
local Types = require('openmw.types')
-- LOCAL SCRIPTS ONLY
local Self = require('openmw.self')

-- MAKE THEM SUFFER
local function damageHandler(data)
	if data.damage then
		local stats = Types.Actor.stats.dynamic.health(Self)
		stats.current = stats.current - data.damage
	end
	if data.fatigueDamage then
		local stats = Types.Actor.stats.dynamic.fatigue(Self)
		stats.current = stats.current - data.fatigueDamage
	end
end

local function toggleAIHandler(data)
	Self.enableAI(data.enabled)
end

local function emptyFatigueHandler(data)
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
		TK_EmptyFatigue = emptyFatigueHandler
	}
}