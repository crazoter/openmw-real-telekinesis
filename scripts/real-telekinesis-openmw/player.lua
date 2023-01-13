-- IMPORTS
-- ALL SCRIPTS
local Interfaces = require('openmw.interfaces')
local Util = require('openmw.util')
local Core = require('openmw.core')
local Types = require('openmw.types')
-- PLAYER SCRIPTS ONLY
local Camera = require('openmw.camera')
local Ui = require('openmw.ui')
-- LOCAL SCRIPTS ONLY
local Nearby = require('openmw.nearby')
local Self = require('openmw.self')

-- CONSTANTS
local ANY_PHY = Nearby.COLLISION_TYPE.AnyPhysical
local ACTOR = Nearby.COLLISION_TYPE.Actor

-- SCRIPT CONFIGURABLE CONSTANTS
local PUSH_Z_OFFSET = 10            -- Offset from the ground, to prevent collision with ground
local PULL_Z_OFFSET = 10            -- Offset from the ground, to prevent collision with ground
local PULL_INITIAL_Z_OFFSET = 30        -- Offset from the ground, to prevent collision with ground
local BUMP_OFFSET = 100             -- Offset to prevent repeated pushes from pushing through wall
local PULL_SMOOTH = 0.6

local M_TO_UNITS = 100              -- Conversion from meters to... whatever units Morrowind uses for distance
local TERMINAL_VELOCITY = 53 * M_TO_UNITS   -- Maximum downward velocity by gravity
local GRAVITY_MS2 = 9.80665 * M_TO_UNITS    -- The power of Earth's love

-- USER CONFIGURABLE CONSTANTS
local DIST_DMG_MULT = 0             -- Speed damage multiplier
local powerDistance = 2000          -- Distance whereby telekinesis is effective
local powerPush = 1000              -- Distance to push target
local pushSpeed = 1000 / 2          -- Speed per second to push targets at
local pullRange = 200               -- Distance from player to pull target to
local pullSpeed = 100               -- Speed per second to pull targets at
local rotaSpeed = 0                 -- You spin me right round right round

-- SCRIPT LOCAL VARIABLES
local grabbedObject = Nil           
local ragDollData = {}              -- [{   target: GameObject,  v: Vector3 (directional vector), 
                                    --  gravity: boolean, zOffset: int, origDist: int, distance: int, prevPos: Vector 3 }... ]
                                    -- Ragdoll object until it hits something, stops moving (due to water), or travelled the sufficient distance (if > 0)
                                    -- origDist just there to smooth the pull animation

-- GENERIC FUNCTIONS
-- Safely rm items from an array table while iterating
-- For your fnKeep, return true if keeping element, otherwise false
function ArrayIter(t, fnKeep)
    local j, n = 1, #t
    for i=1,n do
        if (fnKeep(t,i,j)) then
            if(i~=j) then 
                t[j] = t[i];
            end
            j = j+1;
        end
    end
    table.move(t,n+1,n+n-j+1,j)
    return t;
end

-- HELPER FUNCTIONS
local function dealDamage(target, dmg)
    if target ~= Self.object then
        target:sendEvent('TK_Damage', { damage=dmg })
        local targetName = "Target"
        if target.type == Types.NPC then targetName = Types.NPC.record(target).name end
        if target.type == Types.Creature then targetName = Types.Creature.record(target).name end
        Ui.showMessage(targetName .. " got hurt for " .. dmg .. " damage!")
    else
        -- Wait... Player shouldn't get hurt
    end
end

-- Teleport with collision handling
-- Returns true if collision happened, otherwise false
local function tpWithCollision(target, newPos, zOffset)
    local obstacle = Nearby.castRay(
        zOffset > 0 and Util.vector3(target.position.x, target.position.y, target.position.z + zOffset) or target.position,
        zOffset > 0 and Util.vector3(newPos.x, newPos.y, newPos.z + zOffset) or newPos,
        {
            collisionType = ANY_PHY,
            ignore = target
        }
    )
    if obstacle.hitPos and obstacle.hitObject ~= Self.object then
        -- Deal damage to everyone involved
        local dmg = (target.position - newPos):length() * DIST_DMG_MULT
        dealDamage(target, dmg)
        if obstacle.hitObject and obstacle.hitObject.type and obstacle.hitObject.type.baseType == Types.Actor then
            dealDamage(obstacle.hitObject, dmg)
        end
        -- Shift it back a little so that subsequent pushes won't push through the wall
        local actualNewPos = obstacle.hitPos + (target.position - obstacle.hitPos):normalize() * BUMP_OFFSET
        Core.sendGlobalEvent('TK_Teleport', { object = target, newPos = actualNewPos })
        return true
    else
        local newRota = target.rotation + Util.vector3(rotaSpeed, rotaSpeed, rotaSpeed)
        Core.sendGlobalEvent('TK_Teleport', { object = target, newPos = newPos, rotation = newRota })
        return false
    end
end

local function getActorInCrosshairs()
    local pos = Camera.getPosition()
    local pitch = -(Camera.getPitch() + Camera.getExtraPitch())
    local yaw = (Camera.getYaw() + Camera.getExtraYaw())
    local xzLen = math.cos(pitch)
    local x = xzLen * math.sin(yaw)
    local y = xzLen * math.cos(yaw)
    local z = math.sin(pitch)
    local v = Util.vector3(x, y, z)
    local dist = powerDistance + Camera.getThirdPersonDistance()
    local result = Nearby.castRenderingRay(pos, pos + v * dist)
    -- Allow user to interact with actors and items
    if result.hitObject and result.hitObject.type and (result.hitObject.type.baseType == Types.Item or result.hitObject.type.baseType == Types.Actor) then
        return result, v
    else
        return {}, v
    end
    --return Nearby.castRay(
    --  pos,
    --  pos + v * dist,
    --  {
    --      collisionType = ACTOR,
    --      ignore = Self.object
    --  }
    --), v
    -- return result, v
end

-- ENGINE HANDLERS
function update(deltaSeconds)
    -- Basic physics ragdolling
    ArrayIter(ragDollData, function(ragDollData, i, j)
        -- Apply gravity's effects to speed vector
        if ragDollData[i].gravity then
            ragDollData[i].v.z = ragDollData[i].v.z - GRAVITY_MS2 * deltaSeconds
        end

        -- Apply friction
        -- ragDollData[i].v = ragDollData[i].v - ragDollData[i].v * friction * deltaSeconds

        -- Evaluate distance by the actual distance teleported
        if ragDollData[i].distance > 0 then
            ragDollData[i].distance = ragDollData[i].distance - (ragDollData[i].target.position - ragDollData[i].prevPos):length()
            -- Add a nice sliding effect
            ragDollData[i].v = ragDollData[i].v * (PULL_SMOOTH + ragDollData[i].distance / ragDollData[i].origDist)
            if ragDollData[i].distance <= 0 then
                -- ragDollData[i].target:sendEvent('TK_Ai', { enabled=true })
                -- target:sendEvent('TK_Fatigue', { reset=true })
                -- target:sendEvent('TK_Fatigue', {})
                return false
            end
            ragDollData[i].prevPos = ragDollData[i].target.position
        end

        -- Apply movement
        local speedV = ragDollData[i].v * deltaSeconds
        local newPos = ragDollData[i].target.position + speedV
        if tpWithCollision(ragDollData[i].target, newPos, ragDollData[i].zOffset) then
            -- ragDollData[i].target:sendEvent('TK_Ai', { enabled=true })
            -- target:sendEvent('TK_Fatigue', { reset=true })
            -- target:sendEvent('TK_Fatigue', {})
            return false
        end
        return true
    end)

    -- Drag grabbed target around
    if grabbedObject then
    end
end

local function onKeyPress(key)
    -- Visual test
    if key.symbol == 'k' then
        local result, v = getActorInCrosshairs()
        local test = Nearby.castRenderingRay(Camera.getPosition(), Camera.getPosition() + v * 10000)
        if test.hitObject then
            if test.hitObject.type.baseType == Types.Item then
                Ui.showMessage("Pull!")
                local target = test.hitObject
                local newPos = Util.vector3(Self.position.x, Self.position.y, Self.position.z)
                local speedVector = (newPos - target.position):normalize() * pullSpeed
                local distance = (newPos - target.position):length()
                local newPos = Util.vector3(target.position.x, target.position.y, target.position.z + 100)
                Core.sendGlobalEvent('TK_Teleport', { object = target, newPos = newPos })
                table.insert(ragDollData, { target = target, v = speedVector, gravity = false, zOffset = PULL_Z_OFFSET, origDist = distance, distance = distance, prevPos = target.position })
            end
        end
    end
    -- Grab
    if key.symbol == 'y' then
        local result = getActorInCrosshairs()
        if result.hitObject then
            Ui.showMessage("Hit Object!")
            local target = result.hitObject
            local newPos = Util.vector3(target.position.x, target.position.y, target.position.z + 100)
            dealDamage(target, 0)
            target:sendEvent('TK_Fatigue', {})
            Core.sendGlobalEvent('TK_Teleport', { object = target, newPos = newPos })
        else
            Ui.showMessage("Nothing in range to grab.")
        end
    end
    -- Push
        if key.symbol == 'u' then
        local result, v = getActorInCrosshairs()
        if result.hitObject then
            Ui.showMessage("Push!")
            local target = result.hitObject
            local newOrigin = Util.vector3(v.x, v.y, 0.1)
            local newPos = Util.vector3(target.position.x, target.position.y, target.position.z) + newOrigin * powerPush
            -- tpWithCollision(target, newPos, PUSH_Z_OFFSET)
            -- local initPos = Util.vector3(target.position.x, target.position.y, target.position.z + 700)
            -- Core.sendGlobalEvent('TK_Teleport', { object = target, newPos = initPos })
            local distance = 600
            target:sendEvent('TK_Fatigue', {})
            -- Register it for animation
            table.insert(ragDollData, { target = target, v = newOrigin * pushSpeed, gravity = false, zOffset = PUSH_Z_OFFSET, origDist = distance, distance = distance, prevPos = target.position })
        else
            Ui.showMessage("Nothing in range to push.")
        end
    end
    -- Pull
    if key.symbol == 'i' then
        local result, v = getActorInCrosshairs()
        if result.hitObject then
            Ui.showMessage("Pull!")
            local target = result.hitObject
            local newPos = Util.vector3(Self.position.x, Self.position.y, Self.position.z) + v * pullRange 
            -- tpWithCollision(target, newPos, PULL_Z_OFFSET)
            local speedVector = (newPos - target.position):normalize() * pullSpeed
            local distance = (newPos - target.position):length()
            -- Give it some airtime to prevent weird glitch-through-floor issues
            -- local newPos = Util.vector3(target.position.x, target.position.y, target.position.z + 100)
            -- Core.sendGlobalEvent('TK_Teleport', { object = target, newPos = newPos })
            -- Register it for animation
            -- target:sendEvent('TK_Fatigue', {})
            table.insert(ragDollData, { target = target, v = speedVector, gravity = false, zOffset = PULL_Z_OFFSET, origDist = distance, distance = distance, prevPos = target.position })
        else
            Ui.showMessage("Nothing in range to pull.")
        end
    end
end

return {
    engineHandlers = { onUpdate = update, onKeyPress = onKeyPress }
}