local module_folder = lfs.writedir()..[[Scripts\GAW\]]
package.path = module_folder .. "?.lua;" .. package.path
local ctld_config = require("ctld_config")

local statefile = io.open(lfs.writedir() .. "Scripts\\GAW\\state.json", 'r')

-- log when we started up so we can send warning messages & schedule the restart
--game_state["startup_time"] = os.date("%H:%M:%S", os.time())
game_state["startup_time"] = os.time()

-- Enable slotblock
trigger.action.setUserFlag("SSB",100)
if statefile then
    local ab_logi_slots = {
        ["Gelendzhik"] = nil,
        ["Krymsk"] = KryLogiSpawn,
        ["Krasnodar-Center"] = KrasCenterLogiSpawn,
        ["Krasnodar-Pashkovsky"] = nil,
    }

    trigger.action.outText("Found a statefile.  Processing it instead of starting a new game", 40)
    local state = statefile:read("*all")
    statefile:close()
    local saved_game_state = json:decode(state)
    trigger.action.outText("Game state read", 10)
    for name, coalition in pairs(saved_game_state["Airfields"]) do
        local flagval = 100
        local ab = Airbase.getByName(name)
        local apV3 = ab:getPosition().p
        local posx = apV3.x + math.random(800, 1000)
        local posy = apV3.z - math.random(100, 200)
        game_state["Airfields"][name] = coalition

        if coalition == 1 then
            if AirbaseSpawns[name] then
                AirbaseSpawns[name][3]:Spawn()
                flagval = 100
            end
        elseif coalition == 2 then
            BlueSecurityForcesGroups[name] = AirfieldDefense:SpawnAtPoint({
                    x = posx,
                    y = posy
                })

            posx = posx + math.random(100, 200)
            posy = posy + math.random(100, 200)
            BlueFarpSupportGroups[name] = FSW:SpawnAtPoint({x=posx, y=posy})
            flagval = 0
        end

        if abslots[name] then
            for i,grp in ipairs(abslots[name]) do
                trigger.action.setUserFlag(grp, flagval)
            end
        end
    end

    trigger.action.outText("Finished processing airfields", 10)

    local markerID = 1
    for name, coalition in pairs(saved_game_state["FARPS"]) do
        if not string.match(name, "Anapa Area FARP") then
            log("Processing FARP " .. name)
            local flagval = 100
            local ab = Airbase.getByName(name)
            local apV3 = ab:getPosition().p

            --trigger.action.markToAll(number id, string text, table vec3 , boolean readOnly, string message)
            if string.match("MK Warehouse", name) then
                trigger.action.markToAll(markerID, name, {x = apV3.x, z = apV3.z+20.0, y = apV3.y}, true)
            else
                trigger.action.markToAll(markerID, name.."\nCapture to provide weapons to Anapa", {x = apV3.x, z = apV3.z+20.0, y = apV3.y}, true)
            end
            markerID = markerID + 1

            apV3.x = apV3.x + math.random(-25, 25)
            apV3.z = apV3.z + math.random(-25, 25)
            local spawns = {NWFARPDEF, SWFARPDEF, NEFARPDEF, SEFARPDEF}
            game_state["FARPS"][name] = coalition

            if coalition == 1 then
                spawns[math.random(4)]:SpawnAtPoint({x = apV3.x, y= apV3.z})
                flagval = 100
            elseif coalition == 2 then
                BlueSecurityForcesGroups[name] = AirfieldDefense:SpawnAtPoint(apV3)
                apV3.x = apV3.x + 50
                apV3.z = apV3.z - 50
                BlueFarpSupportGroups[name] = FSW:SpawnAtPoint({x=apV3.x, y=apV3.z}, true)
                flagval = 0

                if ab_logi_slots[name] then
                    --activateLogi(ab_logi_slots[name])
                end
            end

            if abslots[name] then
                for i,grp in ipairs(abslots[name]) do
                    trigger.action.setUserFlag(grp, flagval)
                end
            end

            if name == "MK Warehouse" and coalition == 2 then
                --activateLogi(MaykopLogiSpawn)
            end
        end

    end

    trigger.action.outText("Finished processing FARPs", 10)

    for name, data in pairs(saved_game_state["StrategicSAM"]) do
        local spawn
        if data.spawn_name == "SA6" then spawn = RussianTheaterSA6Spawn[1] end
        if data.spawn_name == "SA10" then spawn = RussianTheaterSA10Spawn[1] end
        spawn:SpawnAtPoint({
                x = data['position'].x,
                y = data['position'].z
            })
    end

    for name, data in pairs(saved_game_state["C2"]) do
        RussianTheaterC2Spawn[1]:SpawnAtPoint({
                x = data['position'].x,
                y = data['position'].z
            })
    end

    for name, data in pairs(saved_game_state["EWR"]) do
        RussianTheaterEWRSpawn[1]:SpawnAtPoint({
                x = data['position'].x,
                y = data['position'].z
            })
    end

    trigger.action.outText("Finished processing strategic assets", 10)

    for name, data in pairs(saved_game_state["StrikeTargets"]) do
        local spawn
        log('spawning ' .. data['spawn_name'])
        if data['spawn_name'] == 'AmmoDump' then spawn = AmmoDumpSpawn end
        if data['spawn_name'] == 'CommsArray' then spawn = CommsArraySpawn end
        if data['spawn_name'] == 'PowerPlant' then spawn = PowerPlantSpawn end
        local static = spawn:Spawn({
                data['position'].x,
                data['position'].z
            })
    end


    for name, data in pairs(saved_game_state["BAI"]) do
        local spawn
        if data['spawn_name'] == "ARTILLERY" then spawn = RussianHeavyArtySpawn[1] end
        if data['spawn_name'] == "ARMOR COLUMN" then spawn = ArmorColumnSpawn[1] end
        if data['spawn_name'] == "MECH INF" then spawn = MechInfSpawn[1] end
        local baitarget = spawn:SpawnAtPoint({
                x = data['position'].x,
                y = data['position'].z
            })
    end

    trigger.action.outText("Finished processing BAI", 10)

    --LOAD CTLD FROM STATE
    ---------------------------------------------------------------------------

    INIT_CTLD_UNITS = function(args, coords2D, _country, ctld_unitIndex, key)
    --Spawns the CTLD unit at a given point using the ctld_config templates,
    --returning the unit object so that it can be tracked later.
    --
    --Inputs
    --  args : table
    --    The ctld_config unit template to spawn.
    --    Ex. ctld_config.unit_config["M818 Transport"]
    --  coord2D : table {x,y}
    --    The location to spawn the unit at.
    --  _country : int or str
    --    The country ID that the spawned unit will belong to. Ex. 2='USA'
    --  cltd_unitIndex : table
    --    The table of unit indices to help keep track of unit IDs. This table
    --    will be accessed by keys so that the indices are passed by reference
    --    rather than by value.
    --  key : str
    --    The table entry of cltd_unitIndex that will be incremented after a
    --    unit and group name are assigned.
    --    Ex. key = "Gepard_Index"
    --
    --Outputs
    --  Group_Object : obj
    --    A reference to the spawned group object so that it can be tracked.

        local unitNumber = ctld_unitIndex[key]
        local CTLD_Group = {
            ["visible"] = false,
            ["hidden"] = false,
            ["units"] = {
              [1] = {
                ["type"] = args.type,                           --unit type
                ["name"] = args.name .. unitNumber,             --unit name
                ["heading"] = 0,
                ["playerCanDrive"] = args.playerCanDrive,
                ["skill"] = args.skill,
                ["x"] = coords2D.x,
                ["y"] = coords2D.y,
              },
            },
            ["name"] = args.name .. unitNumber,                 --group name
            ["task"] = {},
            ["category"] = Group.Category.GROUND,
            ["country"] = _country                              --group country
        }

        --Debug
        --trigger.action.outTextForCoalition(2,"CTLD Unit: "..CTLD_Group.name, 30)

        --Increment Index and spawn unit
        ctld_unitIndex[key] = unitNumber + 1
        local _spawnedGroup = mist.dynAdd(CTLD_Group)

        return Group.getByName(_spawnedGroup.name)              --Group object
    end


    log("START: Spawning CTLD units from state")
    local ctld_unitIndex = ctld_config.unit_index
    for idx, data in ipairs(saved_game_state["CTLD_ASSETS"]) do

        local coords2D = { x = data.pos.x, y = data.pos.z}
        local country = 2   --USA

        if data.name == 'mlrs' then
            local key = "M270_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["MLRS M270"], coords2D, country, ctld_unitIndex, key)
        end

        if data.name == 'M-109' then
            local key = "M109_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["M109 Paladin"], coords2D, country, ctld_unitIndex, key)
        end

        if data.name == 'abrams' then
            local key = "M1A1_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["M1A1 Abrams"], coords2D, country, ctld_unitIndex, key)
        end

        if data.name == 'jtac' then
            local key = "JTAC_Index"
            local _spawnedGroup = INIT_CTLD_UNITS(ctld_config.unit_config["HMMWV JTAC"], coords2D, country, ctld_unitIndex, key)

            local _code = table.remove(ctld.jtacGeneratedLaserCodes, 1)
            table.insert(ctld.jtacGeneratedLaserCodes, _code)
            ctld.JTACAutoLase(_spawnedGroup:getName(), _code)
        end

        if data.name == 'ammo' then
            local key = "M818_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["M818 Transport"], coords2D, country, ctld_unitIndex, key)
        end

        if data.name == 'gepard' then
            local key = "Gepard_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["Flugabwehrkanonenpanzer Gepard"], coords2D, country, ctld_unitIndex, key)
        end

        if data.name == 'vulcan' then
            local key = "Vulcan_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["M163 Vulcan"], coords2D, country, ctld_unitIndex, key)
        end

        if data.name == 'avenger' then
            local key = "Avenger_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["M1097 Avenger"], coords2D, country, ctld_unitIndex, key)
        end

        if data.name == 'chaparral' then
            local key = "Chaparral_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["M48 Chaparral"], coords2D, country, ctld_unitIndex, key)
        end

        if data.name == 'roland' then
            local key = "Roland_Index"
            INIT_CTLD_UNITS(ctld_config.unit_config["Roland ADS"], coords2D, country, ctld_unitIndex, key)
        end
    end

    local CTLDstate = saved_game_state["Hawks"]
    if CTLDstate ~= nil then
        for k,v in pairs(CTLDstate) do
            respawnHAWKFromState(v)
        end
    end

    game_state["CTLD_ASSETS"] = saved_game_state["CTLD_ASSETS"]
    log("COMPLETE: Spawning CTLD units from state")


    local destroyedStatics = saved_game_state["DestroyedStatics"]
    if destroyedStatics ~= nil then
        for k, v in pairs(destroyedStatics) do
            local obj = StaticObject.getByName(k)
            if obj ~= nil then
                StaticObject.destroy(obj)
            end
        end
        game_state["DestroyedStatics"] = saved_game_state["DestroyedStatics"]
    end

else
    -- Populate the world and gameplay environment.
    trigger.action.outText("No state file detected.  Creating new situation", 10)
    for i=1, 4 do
        local zone_index = math.random(23)
        local zone = "NorthSA6Zone"
        RussianTheaterSA6Spawn[1]:SpawnInZone(zone .. zone_index)
    end

    for i=1, 3 do
        if i < 3 then
            local zone_index = math.random(8)
            local zone = "NorthSA10Zone"
            RussianTheaterSA10Spawn[1]:SpawnInZone(zone .. zone_index)
        end

        local zone_index = math.random(9)
        local zone = "NorthSA10Zone"
        RussianTheaterEWRSpawn[1]:SpawnInZone(zone .. zone_index)

        local zone_index = math.random(8)
        local zone = "NorthSA10Zone"
        RussianTheaterC2Spawn[1]:SpawnInZone(zone .. zone_index)
    end

    for i=1, 10 do
        local zone_index = math.random(18)
        local zone = "NorthStatic" .. zone_index
        local StaticSpawns = {AmmoDumpSpawn, PowerPlantSpawn, CommsArraySpawn}
        local spawn_index = math.random(3)
        local vec2 = mist.getRandomPointInZone(zone)
        local id = StaticSpawns[spawn_index]:Spawn({vec2.x, vec2.y})
    end


    AirbaseSpawns["Krasnodar-Pashkovsky"][1]:Spawn()
    NWFARPDEF:Spawn()
    SWFARPDEF:Spawn()
    NEFARPDEF:Spawn()
    SEFARPDEF:Spawn()
    MKFARPDEF:Spawn()

    -- Disable slots
    trigger.action.setUserFlag("Krymsk Huey 1",100)
    trigger.action.setUserFlag("Krymsk Huey 2",100)
    trigger.action.setUserFlag("Krymsk Mi-8 1",100)
    trigger.action.setUserFlag("Krymsk Mi-8 2",100)

    trigger.action.setUserFlag("Krymsk Gazelle M",100)
    trigger.action.setUserFlag("Krymsk Gazelle L",100)

    trigger.action.setUserFlag("Krasnador Huey 1",100)
    trigger.action.setUserFlag("Krasnador Huey 2",100)
    trigger.action.setUserFlag("Kras Mi-8 1",100)
    trigger.action.setUserFlag("Kras Mi-8 2",100)

    trigger.action.setUserFlag("Krasnador2 Huey 1",100)
    trigger.action.setUserFlag("Krasnador2 Huey 2",100)
    trigger.action.setUserFlag("Kras2 Mi-8 1",100)
    trigger.action.setUserFlag("Kras2 Mi-8 2",100)

    -- FARPS
    trigger.action.setUserFlag("SWFARP Huey 1",100)
    trigger.action.setUserFlag("SWFARP Huey 2",100)
    trigger.action.setUserFlag("SWFARP Mi-8 2",100)
    trigger.action.setUserFlag("SWFARP Mi-8 2",100)

    trigger.action.setUserFlag("SEFARP Gazelle M",100)
    trigger.action.setUserFlag("SEFARP Gazelle L",100)

    trigger.action.setUserFlag("NWFARP Huey 1",100)
    trigger.action.setUserFlag("NWFARP Huey 2",100)
    trigger.action.setUserFlag("SWFARP Mi-8 2",100)
    trigger.action.setUserFlag("SWFARP Mi-8 2",100)

    trigger.action.setUserFlag("NEFARP Huey 1",100)
    trigger.action.setUserFlag("NEFARP Huey 2",100)
    trigger.action.setUserFlag("SWFARP Mi-8 2",100)
    trigger.action.setUserFlag("SWFARP Mi-8 2",100)

    trigger.action.setUserFlag("SEFARP Huey 1",100)
    trigger.action.setUserFlag("SEFARP Huey 2",100)
    trigger.action.setUserFlag("SWFARP Mi-8 2",100)
    trigger.action.setUserFlag("SWFARP Mi-8 2",100)

    trigger.action.setUserFlag("NWFARP KA50",100)
    trigger.action.setUserFlag("SEFARP KA50",100)

    trigger.action.setUserFlag("MK FARP Ka-50", 100)
end

-- Kick off supports
mist.scheduleFunction(function()
    -- Friendly
    TexacoSpawn:Spawn()
    ShellSpawn:Spawn()
    OverlordSpawn:Spawn()

    -- Enemy
    RussianTheaterAWACSSpawn:Spawn()
end, {}, timer.getTime() + 10)

mist.scheduleFunction(function()
    RussianTheaterCASSpawn:Spawn()
    log("Spawned CAS Groups...")
end, {}, timer.getTime() + 10, 1000)
-- Spawn enemy carrier CAP
mist.scheduleFunction(spawn_cap, {RussianCarrierFlight}, timer.getTime() + 10, 900)
-- Kick off the commanders
mist.scheduleFunction(russian_commander, {}, timer.getTime() + 10, 600)

-- Check base ownership
mist.scheduleFunction(getBaseOwners, {logiSlots}, timer.getTime() + 10, 120)

log("init.lua complete")
