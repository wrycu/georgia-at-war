-- Setup JSON
local jsonlib = lfs.writedir() .. "Scripts\\GAW\\json.lua"
json = loadfile(jsonlib)()

-- Setup logging
logFile = io.open(lfs.writedir()..[[Logs\Hoggit-GAW.log]], "w")
--JSON = (loadfile "JSON.lua")()

_stats_add = function(statobj, objtype, val)
    statobj[objtype].alive = statobj[objtype].alive + val
    return statobj[objtype].alive
end

GameStats = {
    increment = function(self, objtype)
        return _stats_add(game_stats, objtype, 1)
    end,
    decrement = function(self, objtype)
        return _stats_add(game_stats, objtype, -1)
    end,
    get = function(self)
        game_stats.caps.nominal = max_caps_for_player_count(get_player_count())
        return game_stats
    end,
}

GAW = {}
function log(str)
    if str == nil then str = 'nil' end
    if logFile then
        logFile:write(os.date("!%Y-%m-%dT%TZ") .. " | " .. str .."\r\n")
        logFile:flush()
    end
end

SecondsToClock = function(seconds)
    local seconds = tonumber(seconds)

    if seconds <= 0 then
        return "00m 00s";
    else
        mins = string.format("%02.f", math.floor(seconds/60));
        secs = string.format("%02.f", math.floor(seconds - mins *60));
        return mins.."m "..secs.."s"
    end
end

--Disables the RTB options on the provided group, provided the group is not nil,
--and the group is an AI with a Controller assigned to it.
DisableRTB = function(grp)
    if grp then
        local ctrler = grp:getController()
        mist.scheduleFunction(function()
            if ctrler then
                --log("Checking " .. grp:getName() .. " for task: " .. tostring(ctrler:hasTask()))
                ctrler:setOption(AI.Option.Air.id.RTB_ON_BINGO, false)
                ctrler:setOption(AI.Option.Air.id.RTB_ON_OUT_OF_AMMO, 0)
            end
        end, {}, timer.getTime() + 1)
    end
end

-- Replace the spawn stuff
Spawner = function(grpName)
    local CallBack = {}
    local handleSpawnedGroup = function(spawnedGroup)
        if spawnedGroup and spawnedGroup:getCoalition() == coalition.side.RED then
            --I really want this only to affect red air fighters.
            --I don't think we need to filter by fighters because
            --the larger planes can probably survive in the air
            --for the duration of the mission (~4 hr).
            DisableRTB(spawnedGroup)
        end
    end
    local executeCallBack = function(addedGroup)
        if CallBack.func then
            if not CallBack.args then CallBack.args = {} end
            mist.scheduleFunction(CallBack.func, {addedGroup, unpack(CallBack.args)}, timer.getTime() + 1)
        end
        --Also run any additional handlers when we spawn groups
        handleSpawnedGroup(addedGroup)
    end
    return {
        _spawnAttempts = 0,
        MEName = grpName,
        Spawn = function(self)
            local added_grp = Group.getByName(mist.cloneGroup(grpName, true).name)
            executeCallBack(added_grp)
            return added_grp
        end,
        SpawnAtPoint = function(self, point, noDisperse)
            local vars = {
                groupName = grpName,
                point = point,
                action = "clone",
                disperse = true,
                maxDisp = 1000,
                route = mist.getGroupRoute(grpName, 'task')
            }

            if noDisperse then
                vars.disperse = false
            end

            local new_group = mist.teleportToPoint(vars)
            if new_group then
                local spawned_grp = Group.getByName(new_group.name)
                executeCallBack(spawned_grp)
                return spawned_grp
            else
                if self._spawnAttempts >= 10 then
                    log("Error spawning " .. grpName .. " after " .. self._spawnAttempts .." attempts." )
                else
                    self._spawnAttempts = self._spawnAttempts + 1
                    self:SpawnAtPoint(point, noDisperse)
                end
            end
        end,
        SpawnInZone = function(self, zoneName)
            local zone = trigger.misc.getZone(zoneName)
            local point = mist.getRandPointInCircle(zone.point, zone.radius)
            return self:SpawnAtPoint(point)
        end,
        OnSpawnGroup = function(self, f, args)
            CallBack.func = f
            CallBack.args = args
        end
    }
end

StaticSpawner = function(groupName, numberInGroup, groupOffsets)
    local CallBack = {}
    return {
        Spawn = function(self, firstPos)
            local names = {}
            for i=1,numberInGroup do
                local groupData = mist.getGroupData(groupName .. i)
                groupData.units[1].x = firstPos[1] + groupOffsets[i][1]
                groupData.units[1].y = firstPos[2] + groupOffsets[i][2]
                groupData.clone = true
                table.insert(names, mist.dynAddStatic(groupData).name)
            end

            if CallBack.func then
                if not CallBack.args then CallBack.args = {} end
                mist.scheduleFunction(CallBack.func, {names, firstPos, unpack(CallBack.args)}, timer.getTime() + 1)
            end

            return names
        end,
        OnSpawnGroup = function(self, f, args)
            CallBack.func = f
            CallBack.args = args
        end
    }
end

GetCoordinate = function(grp)
    local firstUnit = grp:getUnit(1)
    if firstUnit then
        return firstUnit:getPosition().p
    end
end

-- Coalition Menu additions
CoalitionMenu = function( coalition, text )
    return missionCommands.addSubMenuForCoalition( coalition, text )
end
GAW.GroupMenuAdded={}
GroupMenu = function( groupId, text, parent )
    if GAW.GroupMenuAdded[tostring(groupId)] == nil then
        log("No commands from groupId " .. groupId .. " yet. Initializing menu state")
        GAW.GroupMenuAdded[tostring(groupId)] = {}
    end
    if not GAW.GroupMenuAdded[tostring(groupId)][text] then
        log("Adding " .. text .. " to groupId: " .. tostring(groupId))
        GAW.GroupMenuAdded[tostring(groupId)][text] = missionCommands.addSubMenuForGroup( groupId, text, parent )
    end
    return GAW.GroupMenuAdded[tostring(groupId)][text]
end


HandleError = function(err)
    log("Error in pcall: "  .. err)
    if debug then log(debug.traceback()) end
    return err
end

try = function(func, catch)
    return function()
        local r, e = xpcall(func, HandleError)
        if not r then
            catch(e)
        end
    end
end

CoalitionCommand = function(coalition, text, parent, handler)
    callback = try(handler, function(err) log("Error in coalition command: " .. err) end)
    missionCommands.addCommandForCoalition( coalition, text, parent, callback)
end

-- This is a global to hold records of which groups have had
-- group menus added to already.
-- We might try and add menus to the same group twice, this
-- should prevent that.
GAW.GroupCommandAdded= {}
GroupCommand = function(group, text, parent, handler)
    if GAW.GroupCommandAdded[tostring(group)] == nil then
        log("No commands from group " .. group .. " yet. Initializing menu state")
        GAW.GroupCommandAdded[tostring(group)] = {}
    end
    if not GAW.GroupCommandAdded[tostring(group)][text] then
        log("Adding " .. text .. " to group: " .. tostring(group))
        callback = try(handler, function(err) log("Error in group command" .. err) end)
        missionCommands.addCommandForGroup( group, text, parent, callback)
        GAW.GroupCommandAdded[tostring(group)][text] = true
    end
end

MessageToGroup = function(groupId, text, displayTime, clear)
    if not displayTime then displayTime = 10 end
    if clear == nil then clear = false end
    trigger.action.outTextForGroup( groupId, text, displayTime, clear)
end

MessageToAll = function( text, displayTime )
    if not displayTime then displayTime = 10 end
    trigger.action.outText( text, displayTime )
end

standbycassound = "l10n/DEFAULT/standby.ogg"
ninelinecassound = "l10n/DEFAULT/marked.ogg"
targetdestroyedsound = "l10n/DEFAULT/targetdestroyed.ogg"
terminatecassound = "l10n/DEFAULT/depart.ogg"
ableavesound =  "l10n/DEFAULT/transport.ogg"
farpleavesound =  "l10n/DEFAULT/transportfarp.ogg"
abcapsound = "l10n/DEFAULT/arrive.ogg"
farpcapsound = "l10n/DEFAULT/arrivefarp.ogg"

oncall_cas = {}
enemy_interceptors = {}

--function log(str)end
log("Logging System INIT")

function isAlive(group)
    local grp = nil
    if type(group) == "string" then
        grp = Group.getByName(group)
    else
        grp = group
    end
    if grp and grp:isExist() and grp:getSize() > 0 then return true else return false end
end

function groupIsDead(groupName)
    if (Group.getByName(groupName) and Group.getByName(groupName):isExist() == false) or (Group.getByName(groupName) and #Group.getByName(groupName):getUnits() < 1) or not Group.getByName(groupName) then
        return true
    end
    return false
end

function allOnGround(group)
    local grp = nil
    local allOnGround = true
    if type(group) == "string" then
        grp = Group.getByName(group)
    else
        grp = group
    end
    if not grp then return false end

    for i,unit in ipairs(grp:getUnits()) do
        if unit:inAir() then allOnGround = false end
    end

    return allOnGround
end

checkedSams = {}
checkedEWRs = {}
checkedC2s = {}

buildCheckSAMEvent = function(group, callsign)
    checkedSams[group:getName()] = callsign
end

buildCheckEWREvent = function(group, callsign)
    checkedEWRs[group:getName()] = callsign
end

buildCheckC2Event = function(group, callsign)
    checkedC2s[group:getName()] = callsign
end

function handleDeaths(event)
    -- The scheduledSpawn stuff only works for groups with a single unit atm.
    if event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_ENGINE_SHUTDOWN or event.id == world.event.S_EVENT_CRASH then
        --log("Death event handler")
        if event.initiator == nil then
            log("event.initiator was nil. Skipping handleDeaths")
            return
        end
        if not event.initiator.getGroup then
            if event.initiator.getName then
                local sobname = event.initiator.getName(event.initiator)
                --log('Static object destroyed: ' .. sobname)
                for k, v in ipairs(DestructibleStatics) do
                    if string.match(sobname, v) then
                        --log('adding ' .. sobname .. ' to list of destroyed static objects')
                       game_state['DestroyedStatics'][sobname] = true
                    end
                end
            end
            --We're done.
            return
        end
        local grp = event.initiator:getGroup()
        if not grp then return end
        --log("Death for grp " .. grp:getName())
        if checkedSams[grp:getName()] then
            local radars = 0
            local launchers = 0
            --log("Group death is a sam group. Iterating units")
            for i, unit in pairs(grp:getUnits()) do
                local type_name = unit:getTypeName()
                if type_name == "Kub 2P25 ln" then launchers = launchers + 1 end
                if type_name == "Kub 1S91 str" then radars = radars + 1 end
                if type_name == "S-300PS 64H6E sr" then radars = radars + 1 end
                if type_name == "S-300PS 40B6MD sr" then radars = radars + 1 end
                if type_name == "S-300PS 40B6M tr" then radars = radars + 1 end
                if type_name == "S-300PS 5P85C ln" then launchers = launchers + 1 end
                if type_name == "S-300PS 5P85D ln" then launchers = launchers + 1 end
            end

            --log("Done iterating sam units")
            if radars == 0 or launchers == 0 then
                --log("SAM considered dead. removing from state")
                removeObjectiveMark(game_state['StrategicSAM'][grp:getName()])
                game_state['StrategicSAM'][grp:getName()] = nil
                trigger.action.outText("SAM " .. checkedSams[grp:getName()] .. " has been destroyed!", 15)
                GameStats:decrement("sam")
                checkedSams[grp:getName()] = nil
            end
        end

        if checkedC2s[grp:getName()] then
            --log("Group death is a c2 group")
            local cps = 0
            --log("Iterating c2 units")
            for i, unit in pairs(grp:getUnits()) do
                if unit:getTypeName() == "SKP-11" then cps = cps + 1 end
            end

            if cps == 0 then
                --log("C2 group considered dead. removing from state")
                removeObjectiveMark(game_state['C2'][grp:getName()])
                game_state['C2'][grp:getName()] = nil
                trigger.action.outText("C2 " .. checkedC2s[grp:getName()] .. " has been destroyed!", 15)
                checkedC2s[grp:getName()] = nil
            end
        end

        if checkedEWRs[grp:getName()] then
            --log("Group death is EWR. Iterating units.")
            local ewrs = 0
            for i, unit in pairs(grp:getUnits()) do
                if unit:getTypeName() == "1L13 EWR" then ewrs = ewrs + 1 end
            end

            if ewrs == 0 then
                --log("EWR considered dead. removing from state")
                removeObjectiveMark(game_state['EWR'][grp:getName()])
                game_state['EWR'][grp:getName()] = nil
                trigger.action.outText("EWR " .. checkedEWRs[grp:getName()] .. " has been destroyed!", 15)
                checkedEWRs[grp:getName()] = nil
            end
        end

        if scheduledSpawns[event.initiator:getName()] then
            --log("Dead group was a scheduledSpawn.")
            local spawner = scheduledSpawns[event.initiator:getName()][1]
            local stimer = scheduledSpawns[event.initiator:getName()][2]
            scheduledSpawns[event.initiator:getName()] = nil
            mist.scheduleFunction(function()
                spawner:Spawn()
                if grp and grp:isExist() then
                    grp:destroy()
                end
            end, {}, timer.getTime() + stimer)
    end
end
end

mist.addEventHandler(handleDeaths)

removeObjectiveMark = function(group_table)
    if group_table == nil then return end
    local markerId = group_table['markerID']
    log("Removing mark with id [" .. markerId .. "] for objective [" .. group_table['callsign'] .. "]")
    if (markerId) then trigger.action.removeMark(markerId) end
end

function respawnGroundGroup(existingGrp, spawnerObject, pos)
    if existingGrp ~= nil then
	        --log('destroying existing ground group ' .. existingGrp:getName())
        existingGrp:destroy()
    end
    return spawnerObject:SpawnAtPoint(pos)
end


function spawnSecurityForceFromTransport(transportGroupName)
    local transportData = activeBlueXports[transportGroupName]
    if transportData ~= nil then
        local transportGroup = Group.getByName(transportGroupName)
        local abname = transportData[2]
        if transportData[3] then abname = abname .. " Warehouse" end
        log('Xport just landed at ' .. abname)
        if transportGroup then
            local leader = transportGroup:getUnit(1)
            if leader then
                local grpLoc = transportGroup:getUnit(1):getPosition().p
                local landPos = Airbase.getByName(abname):getPosition().p
                local distance = mist.utils.get2DDist(grpLoc, landPos)
                --log("Transport landed " .. distance .. " meters from target")
                if (distance <= 2500) then
                    --log("Within range, spawning Friendly Forces")
                    if transportData[3] then
                        trigger.action.outSoundForCoalition(2, farpcapsound)
                    else
                        trigger.action.outSoundForCoalition(2, abcapsound)
                    end

                    local pos = {
                        x = landPos.x + 30,
                        y = landPos.z - 30
                    }

                    -- check if FSW/Defense group is already spawned at target
                    -- destroy it if it exists before creating a new one
                    BlueSecurityForcesGroups[abname] = respawnGroundGroup(BlueSecurityForcesGroups[abname], AirfieldDefense, pos)
                    BlueFarpSupportGroups[abname] = respawnGroundGroup(BlueFarpSupportGroups[abname], FSW, { x = pos.x - 10, y = pos.y - 10 })

                    log("Security forces have spawned")
                end
                mist.scheduleFunction(transportGroup.destroy, {transportGroup}, timer.getTime() + 10)
            end
        end
    end
end

function securityForcesLanding(event)
    if event.id == world.event.S_EVENT_LAND or event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
        --log("Land or Engine Shutdown Event!")
        if event.initiator == nil then
            --log("Event with event.id ["..event.id .. "] had a nil initiator. Checking if security forces are on the ground")
            for grpName,_ in pairs(activeBlueXports) do
                local grp = Group.getByName(grpName)
                if grp and grp:getUnit(1):inAir() == false then
                    --log("Found a security forces group [ " .. grpName .. " ] on the ground. Spawning security forces")
                    spawnSecurityForceFromTransport(grpName)
                end
            end
        else
            --log("Event with event.id ["..event.id .. "] had an initiator. Checking if it's security forces.")
            local grpName = event.initiator:getGroup():getName()
            spawnSecurityForceFromTransport(grpName)
        end
    end
end
mist.addEventHandler(securityForcesLanding)

function getBaseOwners(logislots)
    for abname,_ in pairs(abs_and_farps) do
        local is_farp = false
        if string.match(abname, "Warehouse") then
            is_farp = true
        end
        local ab = Airbase.getByName(abname)
        local coalition = ab:getCoalition()
        local last_coalition = -1
        if is_farp then
            last_coalition = last_airbase_state['FARPS'][abname]
        else
            last_coalition = last_airbase_state['Airfields'][abname]
        end

        if last_coalition ~= coalition and last_coalition ~= -1 then
            if coalition > 0 then
                local coaName = "BLUE"
                if coalition == 1 then coaName = "RED" end
                trigger.action.outText(abname .. " has been captured by " .. coaName, 20)
                local flagval = 0
                log("Set flagval")
                if coalition == 1 then
                    flagval = 100
                elseif coalition == 2 then
                    --trigger.action.outText("Starting blue cap proc", 10)
                    --flagval = 0
                    --log("Starting reading logi slots")
                    --for logiab_name, spawn in pairs(logislots) do
                    --    log("Checking " .. logiab_name .. " against " .. abname)
                    --    if abname == logiab_name then
                    --        activateLogi(spawn)
                    --    end
                    --end
                    log("Logi slots DONE")


                    if abslots[abname] then
                        local message = "The following units are now available:\n"
                        for i,grp in ipairs(abslots[abname]) do
                            message = message .. "\n" .. grp
                            trigger.action.setUserFlag(grp, flagval)
                        end
                        trigger.action.outText(message, 20)
                    end
                end

                if is_farp then
                    game_state['FARPS'][abname] = coalition
                else
                    game_state['Airfields'][abname] = coalition
                end

                -- update primary goal state
                if abname == 'Sukhumi-Babushara' or abname == 'Beslan' then
                    if coalition == 2 then
                        game_state['Primary'][abname] = true
                    else
                        game_state['Primary'][abname] = false
                    end
                end

                -- disable Sukhumi airport red CAP spawn if it is captured by blufor
                if abname == 'Sukhumi-Babushara' then
                    if coalition == 2 then
                        poopcapsground = {RussianTheaterF5SpawnGROUND}
                        goodcapsground = {RussianTheaterJ11SpawnGROUND}
                    else
                        poopcapsground = {RussianTheaterMig212ShipSpawnGROUND, RussianTheaterF5SpawnGROUND}
                        goodcapsground = {RussianTheaterMig292ShipSpawnGROUND, RussianTheaterSu272sShipSpawnGROUND, RussianTheaterJ11SpawnGROUND}
                    end
                end
            end
        end
    end

    last_airbase_state = {
        FARPS = mist.utils.deepCopy(game_state['FARPS']),
        Airfields = mist.utils.deepCopy(game_state['Airfields'])
    }

end

local objectiveTypeMap = {
    ["NavalStrike"] = "NAVAL",
    ["StrategicSAM"] = "SAM",
    ["Convoys"] = "CONVOY",
    ["C2"] = "C2",
    ["EWR"] = "EWR",
    ["StrikeTargets"] = "STRIKE",
    ["InterceptTargets"] = "INTERCEPT",
    ["BAI"] = "BAI",
    ["AWACS"] = "AWACS",
    ["Tanker"] = "Tanker"
}

objectiveCounter = 99
AddObjective = function(type, id)
    return function(group, spawn_name, callsign)
        if not group then
            return
        end
        local unit = group:getUnit(1)
        if unit then
            game_state[type][group:getName()] = {
                ["callsign"] = callsign,
                ["spawn_name"] = spawn_name,
                ["position"] = unit:getPosition().p,
                ["markerID"] = id
            }

            trigger.action.markToCoalition(id, objectiveTypeMap[type] .. " - " .. callsign, unit:getPosition().p, 2, true)
        end
    end
end

AddStaticObjective = function(id, callsign, spawn_name, staticNames)
    local point = StaticObject.getByName(staticNames[1]):getPosition().p
    local type = "StrikeTargets"
    game_state[type]["strike" .. id] = {
        ['callsign'] = callsign,
        ['spawn_name'] = spawn_name,
        ['position'] = point,
        ['markerID'] = id,
        ['statics'] = staticNames
    }

    trigger.action.markToCoalition(id, objectiveTypeMap[type] .. " - " .. callsign, point, 2, true)
end

AddConvoy = function(group, spawn_name, callsign)
    log("Adding convoy " .. callsign)
   game_state['Convoys'][group:getName()] = {spawn_name, callsign}
end

AddCAP = function(theater)
    return function(group)
        table.insert(game_state["CAP"], group:getName())
    end
end

AddRussianTheaterCAP = function(group)
    AddCAP("Russian Theater")(group)
end

AddAWACSTarget = function(theater)
    return function(group)
        table.insert(game_state["AWACS"], group:getName())
    end
end

AddRussianTheaterAWACSTarget = function(group)
    AddAWACSTarget("Russian Theater")(group)
end

AddTankerTarget = function(theater)
    return function(group)
        table.insert(game_state["Tanker"], group:getName())
    end
end

AddRussianTheaterTankerTarget = function(group)
    AddTankerTarget("Russian Theater")(group)
end

SpawnDefenseForces = function(target_string, time, last_launched_time, spawn)
    log("Defense forces requested to " .. target_string)
    local launch_frequency_seconds = 120
    if time > (last_launched_time + launch_frequency_seconds) then
        log("Time OK. Spawning Security forces")
        spawn:Spawn()
        MessageToAll("Security Forces en route to ".. target_string, 30)
        return time
    else
        log("Can't send security forces yet. Still on cooldown")
        MessageToAll("Unable to send security forces, next mission available in " .. SecondsToClock(launch_frequency_seconds + last_launched_time - time), 30)
        return nil
    end
end

TheaterUpdate = function(theater)
    log("Doing theater Update")
    local output = "OPFOR Strategic Report: " .. theater .. "\n--------------------------\n\nSAM COVERAGE: "
    local numsams = 0
    for i,sam in pairs(game_state['StrategicSAM']) do
        numsams = numsams + 1
    end

    if numsams > 5 then
        output = output .. "Fully Operational"
    elseif numsams > 3 then
        output = output .. "Degraded"
    elseif numsams > 0 then
        output = output .. "Critical"
    else
        output = output .. "None"
    end

    local numc2 = 0
    for i,c2 in pairs(game_state['C2']) do
        numc2 = numc2 + 1
    end

    output = output .. "\n\nCOMMAND AND CONTROL: "
    if numc2 == 3 then
        output = output .. "Fully Operational"
    elseif numc2 == 2 then
        output = output .. "Degraded"
    elseif numc2 == 1 then
        output = output .. "Critical"
    else
        output = output .. "Destroyed"
    end

    local numewr = 0
    for i,ewr in pairs(game_state['EWR']) do
        numewr = numewr + 1
    end
    output = output .. "\n\nEW RADAR COVERAGE: "
    if numewr == 3 then
        output = output .. "Fully Operational"
    elseif numewr == 2 then
        output = output .. "Degraded"
    elseif numewr == 1 then
        output = output .. "Critical"
    else
        output = output .. "None"
    end

    output = output .. "\n\nPRIMARY AIRFIELDS: \n"
    for name,capped in pairs(game_state["Primary"]) do
        output = output .. "    " .. name .. ": "
        if capped then output = output .. "Captured\n" else output = output .. "NOT CAPTURED\n" end
    end

    output = output .. "\n\nTHEATER OBJECTIVE:  Destroy all strike targets, all Command and Control (C2) units, and capture all primary airfields."

    log("Done theater update")
    return output
end

log("GAW.lua complete")
