-- Setup an initial state object and provide functions for manipulating that state.
primaryFARPS = {"SW Warehouse", "NW Warehouse", "SE Warehouse", "NE Warehouse", "MK Warehouse"}
primaryAirfields = {"Maykop-Khanskaya"}
game_state = {
    ["last_launched_time"] = 0,
    ["CurrentTheater"] = "Russian Theater",
    ["last_cap_spawn"] = 0,
    ["last_redfor_cap"] = 0,
    ["Airfields"] = {
        ["Gelendzhik"] = Airbase.getByName("Gelendzhik"):getCoalition(),
        ["Krymsk"] = Airbase.getByName("Krymsk"):getCoalition(),
        ["Krasnodar-Center"] = Airbase.getByName("Krasnodar-Center"):getCoalition(),
        ["Krasnodar-Pashkovsky"] = Airbase.getByName("Krasnodar-Pashkovsky"):getCoalition(),
    },
    ["Primary"] = {
        ["Maykop-Khanskaya"] = false,
    },
    ["StrategicSAM"] = {},
    ["C2"] = {},
    ["EWR"] = {},
    ["CASTargets"] = {},
    ["StrikeTargets"] = {},
    ["InterceptTargets"] = {},
    ["DestroyedStatics"] = {},
    ["OpforCAS"] = {},
    ["CAP"] = {},
    ["BAI"] = {},
    ["AWACS"] = {},
    ["Tanker"] = {},
    ["NavalStrike"] = {},
    ["CTLD_ASSETS"] = {},
    ['Convoys'] ={},
    ["FARPS"] = {
        ["SW Warehouse"] = Airbase.getByName("SW Warehouse"):getCoalition(),
        ["NW Warehouse"] = Airbase.getByName("NW Warehouse"):getCoalition(),
        ["SE Warehouse"] = Airbase.getByName("SE Warehouse"):getCoalition(),
        ["NE Warehouse"] = Airbase.getByName("NE Warehouse"):getCoalition(),
        ["MK Warehouse"] = Airbase.getByName("MK Warehouse"):getCoalition(),
    }
}
log("DONE Creating game state")

log("Creating last airbase state")
last_airbase_state = {
    ['FARPS'] = mist.utils.deepCopy(game_state['FARPS']),
    ['Airfields'] = mist.utils.deepCopy(game_state['Airfields'])
}

log("Creating abs and FARPS list")
abs_and_farps = game_state['Airfields']
for farpname, coa in pairs(game_state['FARPS']) do
    abs_and_farps[farpname] = coa
end

game_stats = {
    c2    = {
        alive = 0,
        nominal = 3,
        tbl   = game_state["C2"],
    },
    sam = {
        alive = 0,
        nominal = 6,
        tbl = game_state["StrategicSAM"]
    },
    ewr = {
        alive = 0,
        nominal = 3,
        tbl   = game_state["EWR"],
    },
    awacs = {
        alive = 0,
        nominal = 1,
        tbl   = game_state["AWACS"],
    },
    bai = {
        alive = 0,
        nominal = 7,
        constructing_sam = false,
        tbl = game_state["BAI"],
    },
    ammo = {
        alive = 0,
        nominal = 3,
        tbl   = game_state["StrikeTargets"],
        subtype = "AmmoDump",
    },
    comms = {
        alive = 0,
        nominal = 2,
        tbl   = game_state["StrikeTargets"],
        subtype = "CommsArray",
    },
    caps = {
        alive = 0,
        nominal = 9,
        tbl = game_state["CAP"],
    },
    airports = {
        alive = 0,
        nominal = 3,
        tbl = game_state["Airfields"],
    },
}

log("Game State INIT")


abslots = {
    ['Gelendzhik'] = {},
    ['Krymsk'] = {"Krymsk Gazelle M", "Krymsk Gazelle L", "Krymsk Huey 1", "Krymsk Huey 2", "Krymsk Mi-8 1", "Krymsk Mi-8 2"},
    ['Krasnodar-Center'] = {"Krasnador Huey 1", "Kras Mi-8 1", "Krasnador Huey 2", "Kras Mi-8 2"},
    ['Krasnodar-Pashkovsky'] = {"Krasnador2 Huey 1", "Kras2 Mi-8 1", "Krasnador2 Huey 2", "Kras2 Mi-8 2"},
    ['SW Warehouse'] = {"SWFARP Huey 1", "SWFARP Huey 2", "SWFARP Mi-8 1", "SWFARP Mi-8 2"},
    ['NW Warehouse'] = {"NWFARP Huey 1", "NWFARP Huey 2", "NWFARP Mi-8 1", "NWFARP Mi-8 2", "NWFARP KA50"},
    ['SE Warehouse'] = {"SEFARP Gazelle M", "SEFARP Gazelle L", "SEFARP Huey 1", "SEFARP Huey 2", "SEFARP Mi-8 1", "SEFARP Mi-8 2", "SEFARP KA50"},
    ['NE Warehouse'] = {"NEFARP Huey 1", "NEFARP Huey 2", "NEFARP Mi-8 1", "NEFARP Mi-8 2"},
    ['MK Warehouse'] = {"MKFARP Huey 1", "MKFARP Huey 2", "MKFARP Mi-8 1", "MKFARP Mi-8 2", "MK FARP Ka-50"},
}

logiSlots = {
    ['Gelendzhik'] = nil,
    ['Krymsk'] = KryLogiSpawn,
    ['Krasnodar-Center'] = KrasCenterLogiSpawn,
    ['Krasnodar-Pashkovsky'] = KrasPashLogiSpawn,
    ['MK Warehouse'] = MaykopLogiSpawn
}
