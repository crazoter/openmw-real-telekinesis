-- IMPORTS
-- ALL SCRIPTS
local Interfaces = require('openmw.interfaces')
local Util = require('openmw.util')
local Core = require('openmw.core')
local Types = require('openmw.types')
-- PLAYER SCRIPTS ONLY
local Camera = require('openmw.camera')
local Ui = require('openmw.ui')
local Input = require('openmw.input')
-- LOCAL SCRIPTS ONLY
local Nearby = require('openmw.nearby')
local Self = require('openmw.self')

-- CONSTANTS
local ANY_PHY = Nearby.COLLISION_TYPE.AnyPhysical
local ACTOR = Nearby.COLLISION_TYPE.Actor

-- SCRIPT CONFIGURABLE CONSTANTS
local PUSH_Z_OFFSET = 10            -- Offset from the ground, to prevent collision with ground
local GRAB_Z_OFFSET = 10            -- Offset from the ground, to prevent collision with ground
local PULL_Z_OFFSET = 10            -- Offset from the ground, to prevent collision with ground
local PULL_INITIAL_Z_OFFSET = 30    -- Offset from the ground, to prevent collision with ground
local BUMP_OFFSET = 25              -- Offset to prevent teleports from pushing objects through wall / floor
local PULL_SMOOTH = 0.03            -- Base number to put together with smoothing
local MIN_PUSH_Z = 0.1              -- Alwys push target off the ground if possible to avoid ground collision
local STUCK_DIST_THRESHOLD = 0.0001 -- Object has to move more than this distance per tick or sequence ends
local STUCK_COUNT_THRESHOLD = 7     -- Number of frames the object has been stuck
local MAX_TIMEOUT = 5               -- Maximum timeout (seconds) for fail-safe purposes
local PLAYER_WIDTH = 100            -- For camera purposes, if in 3rd person, specify distance to "ignore" player
local COLLISION_ATTEMPTS = 100      -- Maximum collision attempts to prevent possible inf loops
local DMG_MOVE_THRESHOLD = 200      -- Must've travelled this much distance or no damage
local GRAB_DMG_MOVE_THRESHOLD = 400 -- Must've travelled this much distance or no damage
local GRAB_CRUSH_RAND_ROTA = 0.0001 -- Limits for crush effect
local ITEM_HALF_WIDTH = 20
local ITEM_HEIGHT = 20
local PREV_POS_UPDATE_DT = 50/1000
local BOUNDING_DATA_PTS = 6

local M_TO_UNITS = 400              -- Gut-feel conversion from meters to... whatever units Morrowind uses for distance
local TERMINAL_VELOCITY = 53 * M_TO_UNITS   -- Maximum downward velocity by gravity. Super basic physics ok
local GRAVITY_MS2 = 9.80665 * M_TO_UNITS    -- The power of Earth's love

-- USER CONFIGURABLE CONSTANTS
local DMG_MULT_SPD = 0.6            -- Damage = spd/s * this multiplier. Usual is 80-100
local DMG_MULT_DIST = 0.03          -- Damage = distance travelled * this multiplier. Usual is 1k to 6k
local DMG_MULT_GRABBED = 0.25       -- Damage multiplier when smacking a grabbed target against environment
local DMG_CRUSH = 100               -- Damaage per second
local SKILL_RANGE = 1000            -- Distance whereby telekinesis is effective
local PUSH_SPD = 5000               -- Speed per second to push targets at
local PULL_OFFSET = 200             -- Distance from player to pull target to
local PULL_SPD = 10000              -- Speed per second to pull targets at
local PULL_WATERSLOW = 0.2          -- Factor by which water will slow an actor moving through water down. Currently bugged
local LIFT_OFFSET = 250             -- Distance to lift objects by
local LIFT_SPD = 1200
local GRAB_MOVE_SPD = 2000          -- Speed per second to push / pull a grabbed object
local GRAB_MIN_DIST = 100
local GRAB_MAX_DIST = SKILL_RANGE
local GRAB_THROW_MULT = 5           -- Multiply vector of grab throw by this factor
local GRAB_THROW_DIST_MULT = 5000   -- Multiply vector of grab throw by this factor / distance
local GRAB_THROW_MULT_MAX = 25
local KEY_GRAB = 'y'
local KEY_PUSH = 'u'
local KEY_PULL = 'i'
local KEY_LIFT = 'o'
local DETACH_CAM_WHEN_GRABBING = true
local rotaSpeed = 0                 -- You spin me right round right round

-- SCRIPT LOCAL VARIABLES
local grabbedObject = Nil
local grabData = {
    boundingData = Nil,
    release = false,            -- Flag to set when releasing, so that the object is properly released on the next update
    isPulling = false,          -- Flags to track when the button is pressed
    isPushing = false,          -- Flags to track when the button is pressed
    crushDmg = 0,               -- Counter to track how much damage you crushed enemy for
    v = Nil,                    -- Directional vector that object is moving in, not to be confused with camera direction.
                                -- Note that for simplicity, the tracking is immediate; v here is simply to track user movement for releasing the object.
    camDistance = Nil,          -- Current distance between camera and grabbed object. Used for tracking position
    prevPos = Nil,
    travelled = 0               -- Travelled distance by object
}

local ragDollData = {}
--[[
    When adding objects to this array, each object in this array follows this format: {
        Name        Type            Descript
        target      GameObject      
        boundingData
        seqs        Sequence[]      Array of Sequences in inverted order; the last occurs first.
        contOnHit   boolean         Optional: Continue animating on colliding with a physical object.
        
        Helper params for the ragdoll logic to work properly
        seqInit     boolean         For the updater to track if these params have been initialized
        origDist    int             There to smooth animation when using targetP
        prevPos     Vector 3        
        dtPrevPos   float           dt since last prevPos update.
        tElapsed    float           Time elapsed
        stuckCount  int             Counter for number of frames item has been stuck
        travelled   float           Distance travelled
    }

    A Sequence comprises of: {
        v           Vector3         Directional vector. Either v or targetP must be set.
        targetP     Vector3         Target position; if set, v is ignored and object is tweened to position instead.
        spd         float           Speed for targetP.
        smoothing   float           Multiplier applied to dist / origDist
        applyG      boolean         Optional: If set, apply gravity to v.
        timeout     float           Optional: Maximum time elapsed (seconds) until terminating sequence
        waterSlow   float           Optional: If set, continually reduce speed by this factor while in water.
        contOnHit   boolean         Optional: Continue on hit. Otherwise, the sequence will be removed immediately.
    }

    Implicit rules:
    1. Collisions wlll stop sequences / the entire animating logic by default.
    2. If spd drops to zero or less than 0, or object stops moving (tracked by prevPos), sequence is removed.
    3. Gravity no longer applies when actor is in water
--]]

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
    if target ~= Self.object and dmg > 0 and target.type.baseType == Types.Actor then
        target:sendEvent('TK_Damage', { damage=dmg })
        local targetName = "Target"
        if target.type == Types.NPC then targetName = Types.NPC.record(target).name end
        if target.type == Types.Creature then targetName = Types.Creature.record(target).name end
        local stats = Types.Actor.stats.dynamic.health(target)
        -- print(stats.current)
        if stats.current > 0 then
            Ui.showMessage(targetName .. " got hurt for " .. dmg .. " damage!")
        else
            Ui.showMessage("Stop! " .. targetName .. " is already dead!")
        end
    end
    -- Players or objects shouldn't get hurt
end

-- Teleport with collision handlingxxx
-- Returns true (hitPos) if collision happened, otherwise false
local function tpWithCollision(target, boundingData, newPos, deltaSeconds, travelled, rotation)
    local pos = Util.vector3(target.position.x, target.position.y, target.position.z)

    local dirVector = (newPos - pos):normalize()
    local currVectorLen = (newPos - pos):length()
    local validForDamage = (target == grabbedObject and travelled > GRAB_DMG_MOVE_THRESHOLD) or
        (target ~= grabbedObject and travelled > DMG_MOVE_THRESHOLD)
    local maxDamage = 0
    local collidedWithSomething = false

    -- Iterate through all bounding points, pushing back the travelled distance as necessary
    for idx = 1, BOUNDING_DATA_PTS do
        local tmpPos = pos + boundingData.sideVectors[idx]
        local obstacle = Nearby.castRay(
            tmpPos,
            tmpPos + dirVector * math.max(0, currVectorLen),
            {
                collisionType = ANY_PHY,
                ignore = target
            }
        )
        if obstacle.hitPos and obstacle.hitObject ~= Self.object then
            collidedWithSomething = true

            -- Shorten the actual moved amount
            local f = currVectorLen
            currVectorLen = (tmpPos - obstacle.hitPos):length() - BUMP_OFFSET
            print("hit", f, currVectorLen)

            -- Deal damage to parties involved
            if validForDamage then
                local dmg = (pos - newPos):length() * DMG_MULT_SPD + travelled * DMG_MULT_DIST
                if target == grabbedObject then
                    dmg = dmg * DMG_MULT_GRABBED
                end
                dmg = math.floor(dmg)
                maxDamage = math.max(maxDamage, dmg)
                -- Deal damage to collided object
                if obstacle.hitObject and obstacle.hitObject.type and obstacle.hitObject.type.baseType == Types.Actor then
                    dealDamage(obstacle.hitObject, dmg)
                end
            end
        end
    end

    if maxDamage > 0 then
        dealDamage(target, maxDamage)
    end

    if collidedWithSomething then
        print("p", dirVector, currVectorLen)
        local actualNewPos = pos + dirVector * currVectorLen
        Core.sendGlobalEvent('TK_Teleport', { object = target, newPos = actualNewPos, rotation = rotation })
        return actualNewPos
    else
        Core.sendGlobalEvent('TK_Teleport', { object = target, newPos = newPos, rotation = rotation })
        return false
    end
end

local function getCameraDirData()
    local pos = Camera.getPosition()
    local pitch = -(Camera.getPitch() + Camera.getExtraPitch())
    local yaw = (Camera.getYaw() + Camera.getExtraYaw())
    local xzLen = math.cos(pitch)
    local x = xzLen * math.sin(yaw)
    local y = xzLen * math.cos(yaw)
    local z = math.sin(pitch)
    return pos, Util.vector3(x, y, z)
end

local function getObjInCrosshairs()
    local pos, v = getCameraDirData()
    local dist = SKILL_RANGE + Camera.getThirdPersonDistance()
    local result = Nearby.castRenderingRay(pos, pos + v * dist)
    -- Ignore player if in 3rd person
    if result.hitObject and result.hitObject == Self.object then
        result = Nearby.castRenderingRay(result.hitPos + v * PLAYER_WIDTH, result.hitPos + v * (PLAYER_WIDTH + dist))
    end
    -- Allow user to interact with actors and items
    if result.hitObject and result.hitObject.type and (result.hitObject.type.baseType == Types.Item or result.hitObject.type.baseType == Types.Actor) then
        return result, v
    else
        return {}, v
    end
end

-- Returns an object that follows this format:
--[[
    {
        halfWidth
        height
        sideVectors: An array of 6 vector3s for the midpoint of every side of the bounding cube. Add position to get their actual position during runtime.
    }
--]]
local function getBoundingData(target, zOffset)
    -- Items don't have collision
    local halfWidth = ITEM_HALF_WIDTH
    local height = ITEM_HEIGHT
    if target.type.baseType == Types.Actor then
        -- Assumption is that nothing is clipping through the target at time of measurement
        -- Assuming that no actor will be taller than 2000
        -- In the event of failure, just keep it simple & return the default bounds
        local MAX_ACTOR_RADIUS = 2000
        -- Get top
        local refPt = Util.vector3(target.position.x, target.position.y, target.position.z + MAX_ACTOR_RADIUS)
        local ref = Nearby.castRay(target.position, refPt, { collisionType = ANY_PHY, ignore = target })
        if ref.hitPos then refPt = Util.vector3(ref.hitPos.x, ref.hitPos.y, ref.hitPos.z - 1) end
        local bbPos = Nearby.castRay(refPt, target.position, { collisionType = ANY_PHY }).hitPos
        if bbPos then
            height = (bbPos - target.position):length()
        end

        -- Assumes that the that position is the midpoint of the width
        refPt = Util.vector3(target.position.x + MAX_ACTOR_RADIUS, target.position.y, target.position.z + height / 2)
        ref = Nearby.castRay(target.position, refPt, { collisionType = ANY_PHY, ignore = target })
        if ref.hitPos then refPt = Util.vector3(ref.hitPos.x - 1, ref.hitPos.y, ref.hitPos.z) end
        bbPos = Nearby.castRay(refPt, target.position, { collisionType = ANY_PHY }).hitPos
        if bbPos then
            halfWidth = (bbPos - target.position):length()
        end

        -- Get the larger of x / y
        refPt = Util.vector3(target.position.x, target.position.y + MAX_ACTOR_RADIUS, target.position.z + height / 2)
        ref = Nearby.castRay(target.position, refPt, { collisionType = ANY_PHY, ignore = target })
        if ref.hitPos then refPt = Util.vector3(ref.hitPos.x, ref.hitPos.y - 1, ref.hitPos.z) end
        bbPos = Nearby.castRay(refPt, target.position, { collisionType = ANY_PHY }).hitPos
        if bbPos then
            halfWidth = math.max(halfWidth, (bbPos - target.position):length())
        end

        -- Note that target will most likely be lying down if they are dead.
        local health = Types.Actor.stats.dynamic.health(target)
        if health.current <= 0 then height = height / 4 end
    end

    return {
            halfWidth = halfWidth, 
            height = height,
            sideVectors = {
                Util.vector3(0, 0, zOffset), -- Assume position is bottom side
                Util.vector3(0, 0, height), -- top
                Util.vector3(halfWidth, 0, height / 2), -- rest of the sides
                Util.vector3(-halfWidth, 0, height / 2),
                Util.vector3(0, halfWidth, height / 2),
                Util.vector3(0, -halfWidth, height / 2),
            }
        }
end

-- ENGINE HANDLERS
function onUpdate(deltaSeconds)
    -- Basic physics ragdolling
    ArrayIter(ragDollData, function(ragDollData, i, j)
        local o = ragDollData[i]
        -- Stop animating object if it's finished all its sequences
        local lastIdx = table.getn(o.seqs)
        if lastIdx <= 0 then
            return false
        end

        local s = o.seqs[lastIdx]
        -- If not initialized, do so
        if not o.seqInit then
            if not o.travelled then o.travelled = 0 end
            o.seqInit = true
            o.tElapsed = deltaSeconds
            o.prevPos = Nil
            o.dtPrevPos = 0
            o.stuckCount = 0
            if s.targetP then
                o.origDist = (o.target.position - s.targetP):length()
            end
        else 
            -- Else, monitor termination events
            o.tElapsed = o.tElapsed + deltaSeconds
            if o.prevPos and o.dtPrevPos >= PREV_POS_UPDATE_DT then
                o.travelled = o.travelled + (o.target.position - o.prevPos):length()
            end
            -- print(o.target.position, o.prevPos, o.prevPos and (o.target.position - o.prevPos):length())
            if (s.timeout and s.timeout < o.tElapsed) or
                (o.prevPos and (o.target.position - o.prevPos):length() < STUCK_DIST_THRESHOLD and o.dtPrevPos >= PREV_POS_UPDATE_DT) then
                o.stuckCount = o.stuckCount + 1
                if o.stuckCount > STUCK_COUNT_THRESHOLD then
                    print("Removed by timeout")
                    table.remove(o.seqs)
                    o.seqInit = false
                    return true
                end
            end
        end

        if s.targetP then
            -- Set v to tween to position if targetP is set
            -- Update v continually as teleported position is not guaranteed
            s.v = s.targetP - o.target.position
            local currDist = s.v:length()
            -- Add a nice sliding effect
            s.v = s.v:normalize() * s.spd * (s.smoothing + currDist / o.origDist)
        end

        -- Set v modifiers
        if s.applyG and s.v.z < TERMINAL_VELOCITY then
            -- Ideally we want gravity to not affect anything in water, items don't have isSwimming, nor is isSwimming consistent
            s.v = Util.vector3(s.v.x, s.v.y, s.v.z - GRAVITY_MS2 * deltaSeconds)
        end
        if s.waterSlow and o.target.type.baseType == Types.Actor and Types.Actor.isSwimming(o.target) then
            s.v = s.v * (1 - s.waterSlow * deltaSeconds)
        end

        -- Move & check terminations on collision
        if o.dtPrevPos >= PREV_POS_UPDATE_DT then
            o.prevPos = o.target.position
            o.dtPrevPos = 0
        else
            o.dtPrevPos = o.dtPrevPos + deltaSeconds
        end
        local speedV = s.v * deltaSeconds
        local newPos = o.target.position + speedV
        local reachedDestination = false
        if s.targetP then
            local posV = newPos - s.targetP
            -- If +ve, acute angle. Negative, obtuse angle i.e. we've reached out destination
            local isAcute = math.acos(
                math.max(-1, 
                    math.min(1, 
                        s.v:dot(posV) / (s.v:length() * posV:length())
                    )
                )
            )
            if isAcute <= 0 then
                newPos = s.targetP
                reachedDestination = true
            end
        end

        if tpWithCollision(o.target, o.boundingData, newPos, deltaSeconds, o.travelled, Nil) then
            if not o.contOnHit then
                return false
            elseif not s.contOnHit then
                print("Removed by hit")
                table.remove(o.seqs)
                o.seqInit = false
            end
        end

        if reachedDestination then
            print("Removed by arrival")
            table.remove(o.seqs)
            o.seqInit = false
        end
        return true
    end)

    if grabbedObject then
        -- Throw object
        if grabData.release and grabData.v then
            -- This must be placed after the update code above
            table.insert(ragDollData, {
                target = grabbedObject,
                boundingData = grabData.boundingData,
                seqs = {
                    {
                        v = grabData.v * math.min(GRAB_THROW_MULT_MAX, GRAB_THROW_MULT * GRAB_THROW_DIST_MULT / grabData.distance),
                        timeout = MAX_TIMEOUT,
                        waterSlow = PULL_WATERSLOW,
                        applyG = true
                    }
                }
            })

            -- Reset
            grabData.release = false
            grabData.isPulling = false
            grabData.isPushing = false
            grabData.v = Nil
            grabData.crushDmg = 0
            grabData.distance = Nil
            grabData.prevPos = Nil
            grabData.travelled = 0
            grabbedObject = Nil
        else
            local camPos, camV = getCameraDirData()
            -- Initialize params if not already done so
            if not grabData.distance then
                local boundingData = getBoundingData(grabbedObject, GRAB_Z_OFFSET)
                grabData.boundingData = boundingData
                grabData.prevPos = grabbedObject.position
                grabData.distance = (camPos - grabbedObject.position):length()
            end

            -- User interaction
            local newRotation = Nil
            if grabData.isPushing and grabData.isPulling and grabbedObject.type.baseType == Types.Actor then
                -- Deal damage to target if you're applying force in too many ways
                local dmg = DMG_CRUSH * deltaSeconds
                grabbedObject:sendEvent('TK_Damage', { damage = dmg, fatigueDamage = dmg })
                grabData.crushDmg = grabData.crushDmg + dmg
                -- It didn't have the "random effect" that I was going for, but funny enough LOL
                local randNum = math.random(GRAB_CRUSH_RAND_ROTA) - GRAB_CRUSH_RAND_ROTA / 2
                newRotation = Util.vector3(grabbedObject.rotation.x + randNum, grabbedObject.rotation.y + randNum, grabbedObject.rotation.z + randNum)
            elseif grabData.isPushing and grabData.distance < GRAB_MAX_DIST then
                grabData.distance = math.min(grabData.distance + GRAB_MOVE_SPD * deltaSeconds, GRAB_MAX_DIST)
            elseif grabData.isPulling and grabData.distance > GRAB_MIN_DIST then
                grabData.distance = math.max(grabData.distance - GRAB_MOVE_SPD * deltaSeconds, GRAB_MIN_DIST)
            end

            -- Generate move object data
            local newPos = Util.vector3(camPos.x, camPos.y, camPos.z - grabData.boundingData.height / 2) + camV * grabData.distance
            grabData.v = newPos - grabData.prevPos

            -- Update object's params
            local deltaDistance = (grabbedObject.position - grabData.prevPos):length()
            -- print(newPos, grabData.prevPos, grabData.distance, grabData.v, deltaDistance, grabData.travelled)
            grabData.prevPos = grabbedObject.position

            -- Move object. Always move because     otherwise morrowind's gravity will take over
            local actualNewPos = tpWithCollision(grabbedObject, grabData.boundingData, newPos, deltaSeconds, grabData.travelled, newRotation)
            if actualNewPos then
                -- Reset travelled distance so that bump damage will not be per frame
                grabData.travelled = 0
                -- grabData.distance = (actualNewPos - Self.object.position):length()
            end
            grabData.travelled = grabData.travelled + deltaDistance
        end
    end
end

local function onInputAction(id)
    if grabbedObject and id == Input.ACTION.Activate then
        grabData.release = true
    end
end

local function onKeyPress(key)
    if grabbedObject then
        -- Grab
        if key.symbol == KEY_GRAB then
            grabData.release = true
        -- Push
        else
            if key.symbol == KEY_PUSH then
                grabData.isPushing = true
            -- Pull
            elseif key.symbol == KEY_PULL then
                grabData.isPulling = true
            end
            if grabData.isPushing and grabData.isPulling and grabbedObject.type.baseType == Types.Actor then
                Ui.showMessage("You spin your target with a telekinetic whirlwind!")
            end
        end
    else
        -- Grab
        if key.symbol == KEY_GRAB then
            local result = getObjInCrosshairs()
            grabbedObject = result.hitObject
            if grabbedObject then
                Ui.showMessage("Grab Object!")
            else
                Ui.showMessage("Nothing in range to grab.")
            end
        -- Push
        elseif key.symbol == KEY_PUSH then
            local result, v = getObjInCrosshairs()
            local target = result.hitObject
            if target then
                Ui.showMessage("Push!")
                -- Prevent double animation
                ArrayIter(ragDollData, function(ragDollData, i, j)
                    return ragDollData[i].target ~= target
                end)
                -- If target is grounded, push should propel object slightly off the ground
                local setNewZ = target.type.baseType ~= Types.Actor or not Types.Actor.isSwimming(target)
                local newV = setNewZ and Util.vector3(v.x, v.y, math.max(MIN_PUSH_Z, v.z)) or v
                target:sendEvent('TK_EmptyFatigue', {})
                local boundingData = getBoundingData(target, PUSH_Z_OFFSET)
                -- Register it for animation
                table.insert(ragDollData, {
                    target = target,
                    boundingData = boundingData,
                    seqs = {
                        {
                            v = newV * PUSH_SPD,
                            timeout = MAX_TIMEOUT,
                            waterSlow = PULL_WATERSLOW,
                            applyG = true
                        }
                    }
                })
            else
                Ui.showMessage("Nothing in range to push.")
            end
        -- Pull
        elseif key.symbol == KEY_PULL then
            local result, v = getObjInCrosshairs()
            local target = result.hitObject
            if target then
                Ui.showMessage("Pull!")
                ArrayIter(ragDollData, function(ragDollData, i, j)
                    return ragDollData[i].target ~= target
                end)
                local camZ = Camera.getPosition().z
                local newZ = target.type.baseType == Types.Actor and (camZ + Self.position.z) / 2 or camZ
                local newPos = Util.vector3(Self.position.x, Self.position.y, newZ) + v * PULL_OFFSET
                local boundingData = getBoundingData(target, PULL_Z_OFFSET)
                table.insert(ragDollData, {
                    target = target,
                    boundingData = boundingData,
                    seqs = {
                        {
                            targetP = newPos,
                            spd = PULL_SPD,
                            smoothing = PULL_SMOOTH,
                            timeout = MAX_TIMEOUT,
                            waterSlow = PULL_WATERSLOW
                        }
                    }
                })
            else
                Ui.showMessage("Nothing in range to pull.")
            end
        elseif key.symbol == KEY_LIFT then
            local result, v = getObjInCrosshairs()
            local target = result.hitObject
            if target then
                Ui.showMessage("Lift!")
                ArrayIter(ragDollData, function(ragDollData, i, j)
                    return ragDollData[i].target ~= target
                end)
                local newPos = Util.vector3(target.position.x, target.position.y, target.position.z + LIFT_OFFSET)
                local boundingData = getBoundingData(target, PULL_Z_OFFSET)
                table.insert(ragDollData, {
                    target = target,
                    boundingData = boundingData,
                    seqs = {
                        {
                            targetP = newPos,
                            spd = LIFT_SPD,
                            smoothing = PULL_SMOOTH,
                            timeout = MAX_TIMEOUT,
                            waterSlow = PULL_WATERSLOW
                        }
                    }
                })
            else
                Ui.showMessage("Nothing in range to lift.")
            end
        end
    end
end

local function onKeyRelease(key)
    -- Push
    if key.symbol == KEY_PUSH then
        grabData.isPushing = false
        if grabData.isPulling and grabbedObject.type.baseType == Types.Actor then
            Ui.showMessage("You hurt your target with telekinesis for " .. math.floor(grabData.crushDmg) .. " damage!")
            grabData.crushDmg = 0
        end
    -- Pull
    elseif key.symbol == KEY_PULL then
        grabData.isPulling = false
        if grabData.isPushing and grabbedObject.type.baseType == Types.Actor then
            Ui.showMessage("You hurt your target with telekinesis for " .. math.floor(grabData.crushDmg) .. " damage!")
            grabData.crushDmg = 0
        end
    end
end

return {
    engineHandlers = { 
        onUpdate = onUpdate, 
        onKeyPress = onKeyPress, 
        onKeyRelease = onKeyRelease,
        onInputAction = onInputAction
    }
}