-- Objective Names

local objective_names
local extra_objective_names = {"Annihilation","Argument","Blind Knuckle","Blocka",
                "Cartwheel","Charlie","Crossword","Flintlock","Full Steam","India","Javelin",
                "Leviathan","Machete","Monsoon Rain","Morass","Ocean Obelisk","Oscar",
                "Pre-Release","Purple Dust","Purple Ghost","Purple Knife","Purple Truth",
                "Python","Red Snow","Sourdough","Vampire","Yellow Lilly","Abracadabra",
                "Anvil","Blind Gate","Brannigan","Bronze Citadel","Bronze Shark","Bronze Tornado",
                "Buffoon","Chronicle","Crackpot","Desperado","Disenchant","Epiphany","Feature Length",
                "Fire Fighter","Gemini","Good Fortune","Harlequin","Homesick","Horseshoe","Mastermind",
                "Mesmerize","Oak Tree","Obelisk","Ocean Whirlwind","Predator","Resurrection",
                "Sea Charger","Silver Champion","Silver Doom","Steamroller","Tango","Taurus",
                "Twiligt Zone","Urban Gate","Urban Paladin","Voodoo Vibes","Water Nymph","White Truth",
                "Yellow Phantom"}
local objectiveFile = io.open(lfs.writedir() .. "Scripts\\objectives.json", 'r')
if (objectiveFile) then
    local objective_names_reader = objectiveFile:read("*all")
    objectiveFile:close()
    objective_names = json:decode(objective_names_reader)
else
    objective_names = extra_objective_names
end
if (#objective_names <= 15) then
    -- Just add a few more in case supporters haven't been entering theirs.
    for _, obj in ipairs(extra_objective_names) do
        table.insert(objective_names, obj)
        if (#objective_names > 30) then
            break
        end
    end
end
objective_names = shuffle(objective_names)


objective_idx = 1

getMarkerId = function()
    objectiveCounter = objectiveCounter + 1
    return objectiveCounter
end

getCallsign = function()
    local callsign = objective_names[objective_idx]
    objective_idx = objective_idx + 1
    if objective_idx > #objective_names then
        log("Not enough objectives. Circling around to 1 again")
        objective_idx = 1
    end
    return callsign
end


function respawnHAWKFromState(_points)
    log("Spawning hawk from state")
    -- spawn HAWK crates around center point
    ctld.spawnCrateAtPoint("blue",551, _points["Hawk pcp"])
    ctld.spawnCrateAtPoint("blue",540, _points["Hawk ln"])
    ctld.spawnCrateAtPoint("blue",545, _points["Hawk sr"])
    ctld.spawnCrateAtPoint("blue",550, _points["Hawk tr"])

    -- spawn a helper unit that will "build" the site
    local _SpawnObject = Spawner( "HawkHelo" )
    local _SpawnGroup = _SpawnObject:SpawnAtPoint({x=_points["Hawk pcp"]["x"], y=_points["Hawk pcp"]["z"]})
    local _unit=_SpawnGroup:getUnit(1)

    -- enumerate nearby crates
    local _crates = ctld.getCratesAndDistance(_unit)
    local _crate = ctld.getClosestCrate(_unit, _crates)
    local terlaaTemplate = ctld.getAATemplate(_crate.details.unit)

    ctld.unpackAASystem(_unit, _crate, _crates, terlaaTemplate)
    _SpawnGroup:destroy()
    log("Done Spawning hawk from state")
end

SA6SpawnZones = {
    "NorthSA6Zone1",
    "NorthSA6Zone2",
    "NorthSA6Zone3",
    "NorthSA6Zone4",
    "NorthSA6Zone5",
    "NorthSA6Zone6",
    "NorthSA6Zone7",
    "NorthSA6Zone8",
    "NorthSA6Zone9",
    "NorthSA6Zone10",
    "NorthSA6Zone11",
    "NorthSA6Zone12",
    "NorthSA6Zone13",
    "NorthSA6Zone14",
    "NorthSA6Zone15",
    "NorthSA6Zone16",
    "NorthSA6Zone17",
    "NorthSA6Zone18",
    "NorthSA6Zone19",
    "NorthSA6Zone20",
    "NorthSA6Zone21",
    "NorthSA6Zone22",
    "NorthSA6Zone23"
}

SA10SpawnZones = {
    "NorthSA10Zone1",
    "NorthSA10Zone2",
    "NorthSA10Zone3",
    "NorthSA10Zone4",
    "NorthSA10Zone5",
    "NorthSA10Zone6",
    "NorthSA10Zone7",
    "NorthSA10Zone8"
}
--local logispawn = SPAWNSTATIC:NewFromStatic("logistic3", country.id.USA)
local logispawn = {
    type = "HEMTT TFFT",
    country = "USA",
    category = "Ground vehicles"
}

-- Forward Logistics spawns
KryLogiSpawn = {logispawn, "HEMTT TFFT",
    {
        ['x'] = -5951.622558,
        ['y'] = 293862.25
    },
    "krymsklogizone"
}

KrasCenterLogiSpawn = {logispawn, "HEMTT TFFT",
    {
        ['x'] = 11981.98046875,
        ['y'] = 364532.65625
    },
    "krascenterlogizone"
}

KrasPashLogiSpawn = {logispawn, "HEMTT TFFT",
    {
        ['x'] = 8229.2353515625,
        ['y'] = 386831.65625
    },
    "kraspashlogizone"
}

MaykopLogiSpawn = {logispawn, "HEMTT TFFT",
    {
        ['x'] = -26322.15625,
        ['y'] = 421495.96875
    },
    "mklogizone"
}

SEFARPLogiSpawn = {logispawn, "HEMTT TFFT",
    {
        ['x'] = -26322.15625,
        ['y'] = 421495.96875
    },
    "sefarplogizone"
}

-- Transport Spawns
NorthGeorgiaTransportSpawns = {
    ['Gelendzhik'] = {Spawner("GelenTransport"), Spawner("GelenTransportHelo"), nil},
    ['Krasnodar-Center'] = {Spawner("KDARTransport"), Spawner("KrasCenterTransportHelo"), KrasCenterLogiSpawn},
    ['Krasnodar_Pashkovsky'] = {Spawner("KDAR2Transport"), Spawner("KrasPashTransportHelo"), nil},
    ['Krasnodar-Pashkovsky'] = {Spawner("KDAR2Transport"), Spawner("KrasPashTransportHelo"), nil},
    ['Krymsk'] = {Spawner("KrymskTransport"), Spawner("KrymskTransportHelo"), KryLogiSpawn}
}

NorthGeorgiaFARPTransportSpawns = {
    ["NW"] = {Spawner("NW FARP HELO"), nil, nil},
    ["NE"] = {Spawner("NE FARP HELO"), nil, nil},
    ["SW"] = {Spawner("SW FARP HELO"),nil, nil},
    ["SE"] = {Spawner("SE FARP HELO"),nil, SEFARPLogiSpawn},
    ["MK"] = {Spawner("MK FARP HELO"), nil, MaykopLogiSpawn}
}

getSA6Zone = function()
    local zone = randomchoice(SA6SpawnZones)
    log("SAMSPAWN -- Got free zone [".. zone .."] for an SA6 Spawn Zone")
    return zone
end

getSA10Zone = function()
    local zone = randomchoice(SA10SpawnZones)
    log("SAMSPAWN -- Got free zone [".. zone .."] for an SA10 Spawn Zone")
    return zone
end
--Tries to get you a free zone, where no other red units exist.
-- zoneFunc - A nullary function that returns the
getFreeZone = function(zoneFunc)
    for i = 1, 5 do
        local zone = zoneFunc()
        local unitCount = getRedUnitCountInZone(zone)
        log("Checking zone ["..zone .."] for red unit count.")
        if unitCount == 0 then return zone end
        log("Zone ["..zone .."] had ["..unitCount.."] red units present. Trying to find another zone.")
    end
    -- Couldn't find a red-unit-free zone in 5 attempts. Give em back the next one.
    local zone = zoneFunc()
    log("Couldn't find a red-unit-free zone after 5 attempts. Returning zone ["..zone.."].")
    return zone
end
-- Tells a tanker (or other aircraft for that matter) to orbit between two points at a set altitude

WeatherPositioning = {}
WeatherPositioning.hMaxFlightAlt	= 5486	-- meters [18 000']: Don't let the aircraft fly higher than this as Hogs won't be able to refuel. TODO: Make overrideable
WeatherPositioning.vSpeed			= 160		-- m/s [300kts]: Default speed of the unit
WeatherPositioning.hClearance		= 305		-- meters [1000']: Default clearance to deconflict
-- Realistically if we use this to deconflict tankers as well, we'd need 2000' as chicks approach them 1000' low
WeatherPositioning.stdDensity = 1.225	-- kg/m^3
WeatherPositioning.stdPressure_inHg = 29.92	-- inHg so that we can use the feet calculations
WeatherPositioning.stdTemperature = 15	-- Celsius


-- Uses the aviation-level approximations for getting the pressure and density altitudes, except we use a slightly more accurate 1inHg/1200' linear approximation for presure lapse rate
-- Between 10-18000' this conversion is accurate to +-5knots
function WeatherPositioning.IAStoTAS(IASIn, altitude)

	local weather = env.mission.weather

	local seaLevelTemp	= weather.season.temperature
	local qnh			= weather.qnh / 25.4	-- Convert mmHg to inHg

	env.info("Sea Level Temperature: " .. seaLevelTemp)
	env.info("QNH: " .. qnh)

	-- Calculate Pressure Height
	local altFeet		= altitude * 3.28084										-- meters to feet
	local dQ			= qnh - WeatherPositioning.stdPressure_inHg
	local pressureAlt	= altFeet - dQ * 1200										-- 1200' for every inHg
	local tempDelta		= seaLevelTemp - WeatherPositioning.stdTemperature			-- DCS appears to model variation in temperature over height as the standard (-2 C per 1000' up to 36000'), so we can just get the ISA variation at sea level
	local densityAlt	= pressureAlt + 120 * tempDelta								-- 120' for every C above ISA

	local tempAlt		= WeatherPositioning.stdTemperature - (densityAlt / 500)							-- Get the approximated temperature at the input altitude (-2 C per 1000' up to 36000')
	local tempAbsAlt	= 273.15 + tempAlt											-- Convert temperature to Kelvin
	local absPressure	= 101325 * (WeatherPositioning.stdPressure_inHg - (densityAlt / 1200)) / WeatherPositioning.stdPressure_inHg	-- Calculate Absolute pressure at the given density alt
	local altDensity	= absPressure * 0.0289644 / (8.31447 * tempAbsAlt)			-- density = pressure * Molar mass / (Ideal Gas Constant * Absolute Temperature) [p = pM/RT]

	return IASIn * math.sqrt(WeatherPositioning.stdDensity / altDensity)
end

-- Generic altitude deconfliction
function WeatherPositioning.deconflictAltitude(altitudeIn, deconflictBase, deconflictTop)
    local hAltitude = altitudeIn
    if deconflictTop >= (altitudeIn - WeatherPositioning.hClearance) then
        hAltitude = math.min(deconflictBase - WeatherPositioning.hClearance, altitudeIn)
    end
    return hAltitude
end

function WeatherPositioning.avoidCloudLayer(planeGroup, MEGroupName, vSpeedIAS_ms)
    vSpeedIAS_ms = vSpeedIAS_ms or WeatherPositioning.vSpeed

    -- Calculate orbit height. Ignore for partial cloud conditions
    local clouds = env.mission.weather.clouds
    local cloudBase = clouds.base
    local cloudTop = clouds.base + clouds.thickness
    local hOrbit = WeatherPositioning.hMaxFlightAlt

    if clouds.density >= 7 then
        hOrbit = WeatherPositioning.deconflictAltitude(hOrbit, cloudBase, cloudTop)
    end

	-- Adjust input IAS into a TAS for the given altitude
	local vSpeedTAS = WeatherPositioning.IAStoTAS(vSpeedIAS_ms, hOrbit)

    local curRoute = mist.getGroupRoute(MEGroupName, true)

    for i = 1, #curRoute do
        curRoute[i].alt = hOrbit
        curRoute[i].speed = vSpeedTAS

        -- Modify any orbit taskings
        if #curRoute[i] ~= nil
            and #curRoute[i].task ~= nil
            and #curRoute[i].task.params ~= nil
            and #curRoute[i].task.params.tasks ~= nil then

            for _, curTask in pairs(curRoute[i].task.params.tasks) do
                if curTask.id == "Orbit" then
                    curTask.params.altitude = hOrbit
                    curTask.params.speed = vSpeedTAS
                end
            end
        end
    end
    log("Setting Orbit Height of ['"..planeGroup:getName().."' based on '"..MEGroupName.."'] to " .. hOrbit .."m @ " .. vSpeedTAS .. "m/s")
    return mist.goRoute(planeGroup, curRoute)
end


scheduledSpawns = {}
DestructibleStatics = {}
DestroyedStatics = {}
BlueSecurityForcesGroups = {}
BlueFarpSupportGroups = {}

-- Support Spawn
TexacoSpawn = Spawner("Texaco")
TexacoSpawn:OnSpawnGroup(function(grp)
    scheduledSpawns[grp:getUnit(1):getName()] = {TexacoSpawn, 600}
    WeatherPositioning.avoidCloudLayer(grp, TexacoSpawn.MEName, 129) -- Init against cloud base at 129 m/s (250 knots)
end)

ShellSpawn = Spawner("Shell")
ShellSpawn:OnSpawnGroup(function(grp)
    scheduledSpawns[grp:getUnit(1):getName()] = {ShellSpawn, 600}
    WeatherPositioning.avoidCloudLayer(grp, ShellSpawn.MEName, 144) -- Init against cloud base at 144 m/s (280 knots)
end)

OverlordSpawn = Spawner("AWACS Overlord")
OverlordSpawn:OnSpawnGroup(function(grp)
    scheduledSpawns[grp:getUnit(1):getName()] = {OverlordSpawn, 600}
end)

-- Local defense spawns.  Usually used after a transport spawn lands somewhere.
AirfieldDefense = Spawner("AirfieldDefense")

-- Strategic REDFOR spawns
RussianTheaterSA10Spawn = { Spawner("SA10"), "SA10" }
RussianTheaterSA6Spawn = { Spawner("SA6"), "SA6" }
RussianTheaterEWRSpawn = { Spawner("EWR"), "EWR" }
RussianTheaterC2Spawn = { Spawner("C2"), "C2" }
RussianTheaterAWACSSpawn = Spawner("A50")
RussianTheaterAWACSPatrol = Spawner("SU27-RUSAWACS Patrol")

RussianTheaterAWACSSpawn:OnSpawnGroup(function(grp)
    scheduledSpawns[grp:getUnit(1):getName()] = {RussianTheaterAWACSSpawn, 1800}
end)

-- REDFOR specific airfield defense spawns
DefKrasPash = Spawner("Red Airfield Defense Kras-Pash 1")
DefKrasCenter = Spawner("Red Airfield Defense Kras-Center 1")
DefKrymsk = Spawner("Red Airfield Defense Krymsk 1")
DefGlensPenis = Spawner("Red Airfield Defense GlensDick 1")

-- CAP Redfor spawns
RussianTheaterMig212ShipSpawn = Spawner("Mig21-2ship")
RussianTheaterMig292ShipSpawn = Spawner("Mig29-2ship")
RussianTheaterSu272sShipSpawn = Spawner("Su27-2ship")
RussianTheaterF5Spawn = Spawner("f52ship")
RussianTheaterJ11Spawn = Spawner("j112ship")

RussianTheaterMig212ShipSpawnGROUND = Spawner("Mig21-2shipGROUND")
RussianTheaterMig292ShipSpawnGROUND = Spawner("Mig29-2shipGROUND")
RussianTheaterSu272sShipSpawnGROUND = Spawner("Su27-2shipGROUND")
RussianTheaterF5SpawnGROUND = Spawner("f52shipGROUND")
RussianTheaterJ11SpawnGROUND = Spawner("j112shipGROUND")

RussianTheaterMig312ShipSpawn = Spawner("Mig31-2ship")

RussianTheaterMig312ShipSpawn:OnSpawnGroup(function(spawned_group)
    table.insert(enemy_interceptors, spawned_group:getName())
end)

-- Strike Target Spawns
RussianHeavyArtySpawn = { Spawner("ARTILLERY"), "ARTILLERY" }
ArmorColumnSpawn = { Spawner("ARMOR COLUMN"), "ARMOR COLUMN" }
MechInfSpawn = { Spawner("MECH INF"), "MECH INF" }
AmmoDumpDef = Spawner("Ammo DumpDEF")
CommsArrayDef = Spawner("Comms ArrayDEF")
PowerPlantDef = Spawner("Power PlantDEF")

AmmoDumpSpawn = StaticSpawner("Ammo Dump", 7, {
        {0, 0},
        {40, 0},
        {80, -50},
        {80, 0},
        {90, 50},
        {0, 90},
        {-90, 0}
    })

AmmoDumpSpawn:OnSpawnGroup(function(staticNames, pos)
    local callsign = getCallsign()
    AddStaticObjective(getMarkerId(), callsign, "AmmoDump", staticNames)

    --Offset to get the defense group in the right location (318° for 83m)
    --defense_offset = {-55.5, 61.7}
    SpawnStaticDefense("Ammo DumpDEF", pos, {-55.5, 61.7})
    GameStats:increment("ammo")
end)

CommsArraySpawn = StaticSpawner("Comms Array", 3, {
        {0, 0},
        {80, 0},
        {80, -50},
    })

CommsArraySpawn:OnSpawnGroup(function(staticNames, pos)
    local callsign = getCallsign()
    AddStaticObjective(getMarkerId(), callsign, "CommsArray", staticNames)

    --Offset to get the defense group in the right location (319° for 73m)
    --defense_offset = {-47.9, 55.1}
    SpawnStaticDefense("Comms ArrayDEF", pos, {-47.9, 55.1})
    GameStats:increment("comms")
end)

PowerPlantSpawn = StaticSpawner("Power Plant", 7, {
        {0, 0},
        {100, 0},
        {200, 150},
        {400, 150},
        {130,  200},
        {160, 200},
        {190, 200}
    })

PowerPlantSpawn:OnSpawnGroup(function(staticNames, pos)
    local callsign = getCallsign()
    AddStaticObjective(getMarkerId(), callsign, "PowerPlant", staticNames)

    --Offset to get the defense group in the right location (43° for 370m)
    --defense_offset = {270.6, 272.3}
    SpawnStaticDefense("Power PlantDEF", pos, {270.6, 292.3})
end)

SpawnStaticDefense = function(group_name, position, defense_offset)
    --Inputs
    --  group_name : str
    --    The group to spawn in the Mission Editor.
    --  position : table {x, y}
    --    The position of the strike target.
    --  defense_offset : table {x, y} (Optional)
    --    The offset of the defense force with respect to the strike target position.
    --    Ommiting this will potentially cause the first defense unit to spawn on
    --    top of strike target buildings.

    if not defense_offset then defense_offset = {0., 0.} end

    local groupData = mist.getGroupData(group_name)
    local leaderPos = {groupData.units[1].x, groupData.units[1].y}
    for i,unit in ipairs(groupData.units) do
        local separation = {}
        separation[1] = unit.x - leaderPos[1]
        separation[2] = unit.y - leaderPos[2]
        unit.x = position[1] + separation[1] + defense_offset[1]
        unit.y = position[2] + separation[2] + defense_offset[2]
    end

    groupData.clone = true
    mist.dynAdd(groupData)
end

-- Naval Strike target Spawns
--PlatformGroupSpawn = {SPAWNSTATIC:NewFromStatic("Oil Platform", country.id.RUSSIA), "Oil Platform"}

-- Airfield CAS Spawns
RussianTheaterCASSpawn = Spawner("Su25T-CASGroup")

--Russian Carrier Flight
RussianCarrierFlight = Spawner("SU-33-2shipCARRIER")

-- FARP defenses
NWFARPDEF = Spawner("FARP DEFENSE")
SWFARPDEF = Spawner("FARP DEFENSE #001")
NEFARPDEF = Spawner("FARP DEFENSE #003")
SEFARPDEF = Spawner("FARP DEFENSE #002")
MKFARPDEF = Spawner("FARP DEFENSE #004")

-- FARP Support Groups
FSW = Spawner("FARP Support West")

-- Group spanws for easy randomization
local allcaps = {
    RussianTheaterMig212ShipSpawn, RussianTheaterSu272sShipSpawn, RussianTheaterMig292ShipSpawn, RussianTheaterJ11Spawn, RussianTheaterF5Spawn,
    RussianTheaterMig212ShipSpawnGROUND, RussianTheaterSu272sShipSpawnGROUND, RussianTheaterMig292ShipSpawnGROUND, RussianTheaterJ11SpawnGROUND, RussianTheaterF5SpawnGROUND
}
poopcaps = {RussianTheaterMig212ShipSpawn, RussianTheaterF5Spawn}
goodcaps = {RussianTheaterMig292ShipSpawn, RussianTheaterSu272sShipSpawn, RussianTheaterJ11Spawn}
poopcapsground = {RussianTheaterMig212ShipSpawnGROUND, RussianTheaterF5SpawnGROUND}
goodcapsground = {RussianTheaterMig292ShipSpawnGROUND, RussianTheaterSu272sShipSpawnGROUND, RussianTheaterJ11SpawnGROUND}
baispawns = {RussianHeavyArtySpawn, ArmorColumnSpawn, MechInfSpawn}
SAMSpawns = {
    { RussianTheaterSA6Spawn, getSA6Zone },
    { RussianTheaterSA10Spawn, getSA10Zone }
}



function activateLogi(spawn)
    if spawn then
        local statictable = mist.utils.deepCopy(logispawn)
        statictable.x = spawn[3].x
        statictable.y = spawn[3].y
        local static = mist.dynAddStatic(statictable)
        table.insert(ctld.logisticUnits, static.name)
        ctld.activatePickupZone(spawn[4])

        if not hasRadioBeacon[spawn[4]] == true then 
            log("Spawning radio beacon for " .. spawn[4])
            ctld.createRadioBeaconAtZone(spawn[4], "blue", 1440, spawn[4])
            hasRadioBeacon[spawn[4]] = true
        end
    end
end

RussianTheaterAWACSSpawn:OnSpawnGroup(function(SpawnedGroup)
    local callsign = "Overseer"
    AddObjective("AWACS", getMarkerId())(SpawnedGroup, "AWACS", callsign)
    RussianTheaterAWACSPatrol:Spawn()
    GameStats:increment("awacs")
end)

RussianTheaterSA6Spawn[1]:OnSpawnGroup(function(SpawnedGroup)
    local callsign = getCallsign()
    AddObjective("StrategicSAM", getMarkerId())(SpawnedGroup, RussianTheaterSA6Spawn[2], callsign)
    buildCheckSAMEvent(SpawnedGroup, callsign)
    GameStats:increment("sam")
end)

RussianTheaterSA10Spawn[1]:OnSpawnGroup(function(SpawnedGroup)
    local callsign = getCallsign()
    AddObjective("StrategicSAM", getMarkerId())(SpawnedGroup, RussianTheaterSA10Spawn[2], callsign)
    buildCheckSAMEvent(SpawnedGroup, callsign)
    GameStats:increment("sam")
end)

RussianTheaterEWRSpawn[1]:OnSpawnGroup(function(SpawnedGroup)
    local callsign = getCallsign()
    AddObjective("EWR", getMarkerId())(SpawnedGroup, RussianTheaterEWRSpawn[2], callsign)
    buildCheckEWREvent(SpawnedGroup, callsign)
    GameStats:increment("ewr")
end)

RussianTheaterC2Spawn[1]:OnSpawnGroup(function(SpawnedGroup)
    local callsign = getCallsign()
    AddObjective("C2", getMarkerId())(SpawnedGroup, RussianTheaterC2Spawn[2], callsign)
    buildCheckC2Event(SpawnedGroup, callsign)
    GameStats:increment("c2")
end)

SpawnOPFORCas = function(spawn)
    --log("===== CAS Spawn begin")
    local casGroup = spawn:Spawn()
end

for i,v in ipairs(baispawns) do
    v[1]:OnSpawnGroup(function(SpawnedGroup)
        local callsign = getCallsign()
        AddObjective("BAI", getMarkerId())(SpawnedGroup, v[2], callsign)
        GameStats:increment("bai")
    end)
end

for i,v in ipairs(allcaps) do
    v:OnSpawnGroup(function(SpawnedGroup)
        AddRussianTheaterCAP(SpawnedGroup)
        GameStats:increment("caps")
    end)
end

activeBlueXports = {}

addToActiveBlueXports = function(group, defense_group_spawner, target, is_farp, xport_data)
    activeBlueXports[group:getName()] = {defense_group_spawner, target, is_farp, xport_data}
    log("Added " .. group:getName() .. " to active blue transports")
end

removeFromActiveBlueXports = function(group, defense_group_spawner, target)
    activeBlueXports[group:getName()] = nil
end

for name,spawn in pairs(NorthGeorgiaTransportSpawns) do
    for i=1,2 do
        if i == 1 then
            spawn[i]:OnSpawnGroup(function(SpawnedGroup)
                addToActiveBlueXports(SpawnedGroup, AirfieldDefense, name, false, spawn[i])
            end)
        end

        if i == 2 then
            spawn[i]:OnSpawnGroup(function(SpawnedGroup)
                addToActiveBlueXports(SpawnedGroup, AirfieldDefense, name, false, spawn[i])
            end)
        end

    end
end

for name,spawn in pairs(NorthGeorgiaFARPTransportSpawns) do
    spawn[1]:OnSpawnGroup(function(SpawnedGroup)
        addToActiveBlueXports(SpawnedGroup, AirfieldDefense, name, true, spawn[1])
    end)
end

log("spawns.lua complete")
