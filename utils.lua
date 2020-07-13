function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function randomFromList(list)
    local idx = math.random(1, #list)
    return list[idx]
end


-- https://gist.github.com/jdev6/1e7ff30671edf88d03d4
function randomchoice(t) --Selects a random item from a table
    local keys = {}
    for key, value in pairs(t) do
        keys[#keys+1] = key --Store keys in another table
    end
    index = keys[math.random(1, #keys)]
    return t[index], index
end


function listContains(list, elem)
    for _, value in ipairs(list) do
        if value == elem then
            return true
        end
    end

    return false
end

tableIndex = function(tbl, val)
    for i,v in pairs(tbl) do
        if val == v then
            return i
        end
    end
end

function clamp(x, min, max)
    return math.min(math.max(x, min), max)
end

function addstddev(val, sigma)
    return val + math.random(-sigma, sigma)
end

function getBearingRad(src_pt, tgt_pt)
    local bearing_vector = {
        x = tgt_pt.x - src_pt.x,
        y = tgt_pt.y - src_pt.y,
        z = tgt_pt.z - src_pt.z
    }
    local bearing_rad = math.atan2(bearing_vector.z, bearing_vector.x)
    if bearing_rad < 0 then
        bearing_rad = bearing_rad + (2 * math.pi)
    end
    return bearing_rad
end

function tostringViggenLL(lat, lon, acc)
  --Provides functionality similar to mist.tostringLL(lat, lon, acc, DMS) except
  --the east coordinate is reported prior to the north coordinate for the Viggen

  local latHemi, lonHemi
  if lat > 0 then latHemi = 'N' else latHemi = 'S' end
  if lon > 0 then lonHemi = 'E' else lonHemi = 'W' end

  lat = math.abs(lat)
  lon = math.abs(lon)

  local latDeg = math.floor(lat)
  local latMin = (lat - latDeg)*60

  local lonDeg = math.floor(lon)
  local lonMin = (lon - lonDeg)*60

  -- degrees, decimal minutes.
  latMin = mist.utils.round(latMin, acc)
  lonMin = mist.utils.round(lonMin, acc)

  if latMin == 60 then
    latMin = 0
    latDeg = latDeg + 1
  end

  if lonMin == 60 then
    lonMin = 0
    lonDeg = lonDeg + 1
  end

  local minFrmtStr -- create the formatting string for the minutes place
  if acc <= 0 then  -- no decimal place.
    minFrmtStr = '%02d'
  else
    local width = 3 + acc -- 01.310 - that's a width of 6, for example.
    minFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
  end

  return string.format('%02d', lonDeg) .. ' ' .. string.format(minFrmtStr, lonMin) .. '\'' .. lonHemi .. '   '
  .. string.format('%02d', latDeg) .. ' ' .. string.format(minFrmtStr, latMin) .. '\'' .. latHemi
end

function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

--Given a zone with name zoneName, return the number of red vehicles within
--that zone's boundary.
function getRedUnitCountInZone(zoneName)
  local count = mist.getUnitsInZones(mist.makeUnitTable({'[red][vehicle]'}), { zoneName })
  return #count
end
