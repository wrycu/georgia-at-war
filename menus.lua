-- Global Menu, available to everyone
XportMenu = CoalitionMenu(coalition.side.BLUE, "Deploy Airfield Security Forces")
FARPXportMenu = CoalitionMenu(coalition.side.BLUE, "Deploy FARP/Warehouse Security Forces")

GetBRString = function(src_pt, tgt_pt, metric)
    local unit = metric and 'km' or 'nm'
    local dist = mist.utils.get2DDist(src_pt, tgt_pt)
    local bearing_rad = getBearingRad(src_pt, tgt_pt)
    return mist.tostringBR(bearing_rad, dist, nil, metric) .. unit
end

--- Returns a string of coordinates in a format appropriate for the planes of the
--- provided group. i.e. if the group contains F/A-18Cs then we'll return Degrees Minutes Seconds format
--@param grp The group the coordinates are going to be presented to
--@param position The position (table of x,y,z) coordinates to be translated.
--@return String containing the formatted coordinates. Returns an empty string if either grp or position are nil
CoordsForGroup = function(grp, position)
    if grp == nil or position == nil then return "" end
    local u = grp:getUnit(1)
    if not u then return "" end -- Can't get any units from the group to inspect.

    local groupPlaneType = u:getTypeName()
    return CoordForPlaneType(groupPlaneType, position)
end

--- Given a plane type and position, return a string representing the position in a format useful for that planetype.
--@param planeType String indicating the DCS plane type. See Unit.getTypeName() in DCS Scripting docs.
--@param position The position (table of x,y,z) coordinates to be translated
--@return String of coordinates formatted so they can be useful for the given planeType
CoordForPlaneType = function(planeType, pos)
    local lat,long = coord.LOtoLL(pos)
    local dms = function()
        return mist.tostringLL(lat, long, 0, "")
    end
    local ddm = function()
        return mist.tostringLL(lat, long, 3)
    end
    local ddm2 = function()
        return mist.tostringLL(lat, long, 2)
    end
    local mgrs = function()
        return mist.tostringMGRS(coord.LLtoMGRS(lat,long),4)
    end
    local endms6 = function()
        --return mist.tostringLL(lat, lon, 2, "")
        return tostringViggenLL(lat, long, 2)
    end
    --log("Coordinate for [".. planeType .. "]")
    --If it's not defined here we'll use dms.
    local unitCoordTypeTable = {
        ["Ka-50"] = ddm,
        ["M-2000C"] = ddm,
        ["A-10C"] = mgrs,
        ["AJS37"] = endms6,
        ["F-14B"] = ddm,
        ["FA-18C_hornet"] = ddm2
        -- Everything else will default to dms. Add things here if we need exclusions.
    }
    local f = unitCoordTypeTable[planeType]
    if f then return f() else return dms() end
end

GetCoordinateString = function(grp, pos)
    return CoordsForGroup(grp, pos) .. " -- " .. GetBRString(GetCoordinate(grp), pos)
end

-- Per group menu, called on groupspawn
buildMenu = function(Group)
    GroupCommand(Group:getID(), "FARP/WAREHOUSE Locations", nil, function()
        local output = [[NW FARP: 45 12'10"N 38 4'45" E
SW FARP: 44 55'45"N 38 5'17" E
NE FARP: 45 10'4" N 38 55'22"E
SE FARP: 44 50'7" N 38 46'34"E
MAYKOP AREA FARP: 44 42'47" N 39 34' 55"E]]
        MessageToGroup( Group:getID(), output, 60 )
    end)

    local MissionMenu = GroupCommand(Group:getID(), "Get Mission Status", nil, function()
        MessageToGroup(Group:getID(), TheaterUpdate("Russian Theater"), 60)
    end)


    local MissionMenu = GroupMenu(Group:getID(), "Get Current Missions")

    GroupCommand(Group:getID(), "SEAD", MissionMenu, function()
        log("Sending SAM report")
        local sams ="ACTIVE SAM REPORT:\n"
        for group_name, group_table in pairs(game_state["StrategicSAM"]) do
            local type_name = group_table["spawn_name"]
            local callsign = group_table['callsign']
            sams = sams .. "OBJ: ".. callsign .." -- TYPE: " .. type_name ..": \t" .. GetCoordinateString(Group, group_table["position"]) .. "\n"
        end
        MessageToGroup(Group:getID(), sams, 60)
    end)

    GroupCommand(Group:getID(), "Air Interdiction", MissionMenu, function()
        local bais ="BAI TASK LIST:\n"
        for id,group_table in pairs(game_state["BAI"]) do
            local type_name = group_table["spawn_name"]
            local lat,long = coord.LOtoLL(group_table["position"])
            bais = bais .. "OBJ: " .. group_table["callsign"] .. " -- " .. type_name .. ": \t" .. GetCoordinateString(Group, group_table["position"]) .. "\n"
        end
        MessageToGroup(Group:getID(), bais, 60)
    end)

    GroupCommand(Group:getID(), "Strike", MissionMenu, function()
        local strikes ="STRIKE TARGET LIST:\n"
        for group_name,group_table in pairs(game_state["C2"]) do
            local lat,long = coord.LOtoLL(group_table["position"])
            local callsign = group_table['callsign']
            strikes = strikes .. "OBJ: " .. callsign .. " -- MOBILE CP: \t" .. GetCoordinateString(Group, group_table["position"]) .. "\n"
        end

        for group_name,group_table in pairs(game_state["StrikeTargets"]) do
            local lat,long = coord.LOtoLL(group_table["position"])
            local callsign = group_table['callsign']
            local spawn_name = group_table['spawn_name']
            strikes = strikes .. "OBJ: " .. callsign .. " -- " .. spawn_name .. ": \t" .. GetCoordinateString(Group, group_table["position"]) .. "\n"
        end

        MessageToGroup(Group:getID(), strikes, 60)
    end)

    GroupCommand(Group:getID(), "Interception", MissionMenu, function()
        local intercepts ="INTERCEPTION TARGETS:\n"
        for group_name, group_table in pairs(game_state["AWACS"]) do
            log("Found AWACS group named " .. group_name .. ". Being queried by " .. Group:getName())
            local g = Group.getByName(group_name)
            local GroupPos = GetCoordinate(Group)
            local group_point = GetCoordinate(g)
            local lat,long = coord.LOtoLL(group_point)
            if lat and long then
                intercepts = intercepts .. "AWACS: " .. group_table["callsign"] .. "\t--\t" .. GetBRString(GroupPos, group_point, true) .. "\n"
            end
        end

        for i,group_name in ipairs(game_state["Tanker"]) do
            local g = Group.getByName(group_name)
            local group_point = GetCoordinate(g)
            intercepts = intercepts .. "Tanker" .. group_table["callsign"] .. "\t--\t" .. GetBRString(GetCoordinate(Group), group_point, true) .. "\n"
        end
        MessageToGroup(Group:getID(), intercepts, 60)
    end)
end

for name,spawn in pairs(NorthGeorgiaTransportSpawns) do
    log("Preparing menus for NorthGeorgiaTransportSpawns")
    local curMenu = CoalitionCommand(coalition.side.BLUE, "Deploy to " .. name, XportMenu, function()
        log("Requested deploy to " .. name)
        local spawn_idx =1
        local ab = Airbase.getByName(name)
        if ab:getCoalition() == 1 then spawn_idx = 2 end
        local new_spawn_time = SpawnDefenseForces(name, timer.getAbsTime() + env.mission.start_time, game_state["last_launched_time"], spawn[spawn_idx])
        if new_spawn_time ~= nil then
            trigger.action.outSoundForCoalition(2, ableavesound)
            game_state["last_launched_time"] = new_spawn_time
        end
    end)
    log("Done preparing menus for NorthGeorgiaTransportSpawns")
end

for name,spawn in pairs(NorthGeorgiaFARPTransportSpawns) do
    log("Preparing menus for NorthGeorgiaFARPTransportSpawns")
    local curMenu = CoalitionCommand(coalition.side.BLUE, "Deploy to " .. name .. " FARP/WAREHOUSE", FARPXportMenu, function()
        log("Requested deploy to " .. name)
        local new_spawn_time = SpawnDefenseForces(name, timer.getAbsTime() + env.mission.start_time, game_state["last_launched_time"], spawn[1])
        if new_spawn_time ~= nil then
            trigger.action.outSoundForCoalition(2, farpleavesound)
            game_state["last_launched_time"] = new_spawn_time
        end
    end)
    log("Done Preparing menus for NorthGeorgiaFARPTransportSpawns")
end


function groupBirthHandler( Event )
    if Event.id ~= world.event.S_EVENT_BIRTH then return end
    if not Event.initiator then return end
    if not Event.initiator.getGroup then return end
    local grp = Event.initiator:getGroup()
    if grp then
        for i,u in ipairs(grp:getUnits()) do
            if u:getPlayerName() and u:getPlayerName() ~= "" then
                buildMenu(grp)
            end
        end
    end
end
mist.addEventHandler(groupBirthHandler)
log("Event Handler complete")
log("menus.lua complete")
