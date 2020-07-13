--[[
--  TODO: convert to using spawn queues combined with scheduled function
--        it is more efficient and resource management is easier.
--
--  Example:
--      given a CAP spawn priority queue
--
--      allows to easily determine if CAPs have already been requested
--      by checking the depth of the queue, since no newly requested
--      CAP can possibly arrive before the already requested ones there
--      is no point in requesting more if alive + queued == 1.2 * max.
--
--      since spawn objects can be treated polymorphicly a global spawn
--      queue can be used to control resource creation and prevent spawn
--      flooding
--]]

max_caps_for_player_count = function(players)
    if players == nil then
        players = get_player_count()
    end
    local caps = 0

    if players < 5 then
        caps = 2
    elseif players >= 5 and players < 8 then
        caps = 4
    elseif players >= 8 and players < 17 then
        caps = 6
    else
        caps = 7
    end
    return caps
end

cap_spawn_zones = {
    --Zones in the ME where we might try to spawn some air-based CAP
    "RED_CAP_SPAWN_1",
    "RED_CAP_SPAWN_2",
    "RED_CAP_SPAWN_3",
    "RED_CAP_SPAWN_4",
    "RED_CAP_SPAWN_5",
    "RED_CAP_SPAWN_6"
}

get_player_count = function()
    local bluePlanes = mist.makeUnitTable({'[blue][plane]'})
    local bluePlaneCount = 0
    for i,v in pairs(bluePlanes) do
        if Unit.getByName(v) then bluePlaneCount = bluePlaneCount + 1 end
    end
    return bluePlaneCount
end

--[[
--  Utility here is rooted in the concepts of utility theory.
--
--  c2_utility - represents the command efficiency over a theater
--      Simply put as command installations are taken out it becomes
--      increasingly harder for the AI commander it issue orders and receive
--      timely intel to make decisions. The reason a rotate quadratic curve was
--      used is used to depict the non-linear fall-off nature of what happened
--      in the real world when commands are taken out but there is enough
--      redundancy in the system that the fall-off is not quite linear.
--
--  radar_utility - represents the raw radar coverage of the ewr in theater
--      AWACS are effectively worth two EWR sites and the sum of the two are
--      multiplied by 3/4ths to represent ground masking due to placement
--      (blind spots) in the radar coverage.
--
--  logistics_utility - represents how well the enemy can supply itself with
--      its remaining ammo dumps
--      A logistics function is used to simply not have a linear fall-off, it
--      is also a nice representation that of how travel times are non-linear.
--
--  comms_utility - a simple linear representation of the ability for the emeny
--      to communicate.
--
--  detection_efficiency - the combination of command and control capability and
--      radar coverage. If either type of asset still exists some amount of
--      detection is still possible, however, the moment one is completely
--      wiped out detection should no longer be possible. This is suppose to
--      represent a central command and control type organization. Which was a
--      Russian doctrinal mainstay during the cold war.
--
--  airbase_attack - the ability to conduct airstrikes
--      As ammo dumps are hit fewer and fewer resources will be allocated to
--      airstrikes until all command assets are taken out.
--
--  command_delay - is simply the inverse of command_efficiency (c2_utility)
--      As command efficiency reduces the delay for command to issue new orders
--      increases.
--]]

c2_utility = function(stats)
    return (math.pow(stats.c2.alive/stats.c2.nominal, 1/2))
end

radar_utility = function(stats)
    return (.75 * ((stats.ewr.alive/stats.ewr.nominal) +
        (2*stats.awacs.alive)/stats.ewr.nominal))
end

logistics_utility = function(stats)
    return (1/(1+math.exp(-2*(stats.ammo.alive - stats.ammo.nominal/2))))
end

comms_utility = function(stats)
    return (stats.comms.alive/stats.comms.nominal)
end

detection_efficiency = function(c2s, radar)
    return clamp(c2s * radar, 0, 1)
end

airbase_attack = function(c2s, logistics)
    if c2s < 0.10 then
        return 0
    end
    return logistics
end

command_delay = function(util, min, max)
    return clamp((1-util) * max, min, max)
end

calculate_utilities = function(stats)
    local utils = {
        command_efficiency   = c2_utility(stats),
        radar_coverage       = radar_utility(stats),
        logistics            = logistics_utility(stats),
        comms                = comms_utility(stats),
        detection_efficiency = 0,
        airbase_strike       = 0,
    }

    utils.detection_efficiency =
    detection_efficiency(utils.command_efficiency,
        utils.radar_coverage)
    utils.airbase_strike =
    airbase_attack(utils.command_efficiency,
        utils.logistics)
    return utils
end

spawn_cap = function(spawn)
    local stats = GameStats:get()
    if stats.caps.alive >= stats.caps.nominal then
        return
    end
    if math.random() > 0.5 then
        -- Spawn them at a random zone instead of where they were going to be.
        local spawnZone = randomFromList(cap_spawn_zones)
        log("Russian Commander is going to spawn CAP in zone [" .. spawnZone .. "] instead of the default spot.")
        spawn:SpawnInZone(spawnZone)
    else
        spawn:Spawn()
    end
end

request_cap = function(caps, delay_time, utils)
    if caps.alive >= caps.nominal then
        return
    end

    local delay = {
        airbase = {
            max   =  360,
            min   =  180,
            sigma =   60,
        },
        offmap = {
            max   = 600,
            min   = 240,
            sigma =  80,
        },
    }
    local spawn = 0
    local d = 0

    log("Russian Commander is going to request " ..
        (caps.nominal - caps.alive) .. " additional CAP units.")

    for i = caps.alive + 1, caps.nominal do
        if math.random() > 0.75 or (utils.command_efficiency < .6 and utils.comms > 0) then
            d = command_delay(utils.detection_efficiency,
                delay.offmap.min,
                delay.offmap.max)
            d = addstddev(d, delay.offmap.sigma)
            log("Russian Commander is going to request an air-start CAP with a delay of [" .. d .. "] seconds.")
            if math.random() < (utils.comms * 0.85) + 0.3 then
                spawn = randomFromList(goodcaps)
            else
                spawn = randomFromList(poopcaps)
            end
        else
            d = command_delay(utils.detection_efficiency,
                delay.airbase.min,
                delay.airbase.max)
            d = addstddev(d, delay.airbase.sigma)
            log("Russian Commander is going to request an ground-start CAP with a delay of [" .. d .. "] seconds.")
            if math.random() < (utils.logistics + 0.3) then
                spawn = randomFromList(goodcapsground)
            else
                spawn = randomFromList(poopcapsground)
            end
        end
        mist.scheduleFunction(spawn_cap, {spawn}, delay_time + d)
    end
end

spawn_bai = function()
    local stats = GameStats:get()
    if stats.bai.alive >= stats.bai.nominal then
        return
    end

    local baispawn = baispawns[math.random(#baispawns)][1]
    local zone_index = math.random(13)
    local zone = "NorthCAS" .. zone_index
    baispawn:SpawnInZone(zone)
end

request_bai = function(bai, delay_time, utils)
    local delay_max = 1200
    local delay_min = 180
    local sigma = 60
    local delay = delay_time + command_delay(utils.command_efficiency, delay_min, delay_max)

    if bai.alive < bai.nominal then
        log("Russian Commander is going to request " ..
            (bai.nominal - bai.alive) ..
            " additional strategic ground units")
        for i = bai.alive + 1, bai.nominal do
            mist.scheduleFunction(spawn_bai, {}, addstddev(delay, sigma))
        end
    end
end

request_sam = function(sam, delay_time, utils)
    local delay_max = 900
    local delay_min = 480
    local sigma = 120
    local delay = delay_time + command_delay(utils.command_efficiency, delay_min, delay_max)
    log("Sams Alive: " .. sam.alive .. " -- Sam Nomimal: " .. sam.nominal)

    if sam.alive < sam.nominal then
        log("Russian Commander is going to request " ..
            (sam.nominal - sam.alive) ..
            " additional strategic SAM sites. Command Delay: " .. delay .. " Sigma: " .. sigma)
        for i = sam.alive +1, sam.nominal do
            local samSpawn = randomchoice(SAMSpawns)
            local spawner = samSpawn[1]
            local zone = getFreeZone(samSpawn[2])
            local pt = mist.getRandomPointInZone(zone)
            mist.scheduleFunction(spawn_sam, {spawner, pt}, addstddev(delay, sigma))
        end
    end
end
spawn_sam = function(spawner, point, force)
    local stats = GameStats:get()
    if stats.sam.alive >= stats.sam.nominal and not force then
        return
    end
    local samSpawner = spawner[1]
    local spawnType = spawner[2]

    local samGroup = samSpawner:SpawnAtPoint(point)
    mist.scheduleFunction(function()
        local ctrl = samGroup:getController()
        ctrl:setOnOff(false)
        local gameStateGroup = game_state["StrategicSAM"][samGroup:getName()]
        if (gameStateGroup) then
            local callSign = gameStateGroup["callsign"]
            MessageToAll("A new SAM Site is being constructed! Objective " .. callSign ..
                                    " ( " .. spawnType .. " ) will be online in approximately 10 minutes.", 15)
            mist.scheduleFunction(function()
                if (samGroup) then
                    local ctrller = samGroup:getController()
                    ctrller:setOnOff(true)
                    MessageToAll("Objective " .. callSign .." has come online!", 15)
                    log("SAM [" .. callSign .. "] of type [" .. spawnType .. "] to is fully operational.")
                end
            end, {}, timer.getTime() + 600)
        else
            log("I spawned a SAM and lost it... wtf")
        end
    end, {}, timer.getTime() + 1)
end

constructSAMsNearBAIs = function(bai_stats, delay_time, utils)
    if (bai_stats.constructing_sam) then
        log("SAM site construction already ordered. Skipping.")
        return
    end
    local delay_max = 10800 --180m
    local delay_min = 5400 -- 90m
    local sigma = 1800 -- 30m
    local delay = delay_time + command_delay(utils.command_efficiency, delay_min, delay_max)
    log("Commander is seeking to construct SAMS near BAI Objectives. Delay: ["..delay.."] Current Time: ["..timer.getTime().."]")
    game_stats.bai.constructing_sam = true

    mist.scheduleFunction(function()
        log("Continuing BAI SAM construction.")
        game_stats.bai.constructing_sam = false
        local spawner = SAMSpawns[math.random(#SAMSpawns)]
        local objTable, baiGroupName = randomchoice(game_state["BAI"])
        if not baiGroupName then
            log("Couldn't find a BAI to build near...")
            return
        end
        local grp = Group.getByName(baiGroupName)
        if not grp then
            log("Tried getting BAI group " .. baiGroupName .. " and got nil")
            return
        end
        local pt = GetCoordinate(grp)
        if not pt then
            log("Could not find group location for " .. baiGroupName.. " aborting SAM construction")
            return
        end
        spawn_sam(spawner, pt)
        MessageToAll("BAI Objective " .. objTable["callsign"] .. " has begun construction of a SAM Site!")
    end, {}, addstddev(delay, sigma))
end

log_cmdr_stats = function(stats)
    log("Russian commander has " .. stats.bai.alive   .. " ground squads alive.")
    log("Russian commander has " .. stats.ewr.alive   .. " EWRs available.")
    log("Russian commander has " .. stats.sam.alive   .. " SAMs available.")
    log("Russian commander has " .. stats.c2.alive    .. " command posts available.")
    log("Russian commander has " .. stats.ammo.alive  .. " Ammo Dumps available.")
    log("Russian commander has " .. stats.comms.alive .. " Comms Arrays available.")
    log("Russian commander has " .. stats.caps.alive  .. " flights alive.")
end

-- Main game loop, decision making about spawns happen here.
russian_commander = function()
    log("Russian commander is thinking...")

    local time = timer.getTime()
    local stats = GameStats:get()
    local utils = calculate_utilities(stats)

    log_cmdr_stats(stats)

    request_bai(stats.bai, time, utils)
    request_cap(stats.caps, time, utils)
    request_sam(stats.sam, time, utils)
    constructSAMsNearBAIs(stats.bai, time, utils)

    if #enemy_interceptors == 0 and
        math.random() < utils.detection_efficiency then
        RussianTheaterMig312ShipSpawn:Spawn()
    end
    log("The commander has " .. #enemy_interceptors .. " interceptors alive")

    if timer.getTime() > game_state["last_redfor_cap"] + 2200 then
        for i,target in ipairs(AttackableAirbases(Airbases)) do
            if not AirfieldIsDefended("DefenseZone" .. target) then
                if utils.airbase_strike and
                    math.random() < utils.airbase_strike then
                    log("Russian commander has decided to strike " ..
                        target .. " airbase")
                    local spawn = SpawnForTargetAirbase(target)
                    spawn:Spawn()
                    game_state["last_redfor_cap"] = timer.getTime()
                end
            end
        end
    end
end

log("commander.lua complete")
