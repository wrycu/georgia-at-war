do
-- create the IADS for later adding SAM units to
redIADS = SkynetIADS:create('red')

-- uncomment the below lines to get debug output

--local iadsDebug = redIADS:getDebugSettings()
--iadsDebug.IADSStatus = true
--iadsDebug.samWentDark = true
--iadsDebug.contacts = true
--iadsDebug.radarWentLive = true
--iadsDebug.noWorkingCommmandCenter = false
--iadsDebug.ewRadarNoConnection = false
--iadsDebug.samNoConnection = false
--iadsDebug.jammerProbability = true
--iadsDebug.addedEWRadar = false
--iadsDebug.hasNoPower = false
--iadsDebug.harmDefence = true
--iadsDebug.samSiteStatusEnvOutput = true
--iadsDebug.earlyWarningRadarStatusEnvOutput = true
--redIADS:addRadioMenu()

-- activate the IADS
redIADS:activate()

end
