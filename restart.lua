function early_warning_check()
    local early_warning_time = 60 * 160 -- 2 hours 40 minutes
    local early_warning_time = 60 * 1 -- 2 hours 40 minutes
    if os.time() - game_state["startup_time"] >= early_warning_time then
        trigger.action.outText("THE MISSION WILL BE RESTARTING IN 20 MINUTES!  YOU SHOULD PROBABLY START WORKING ON GETTING BACK TO BASE.", 30)
        game_state["startup_time"] = os.time()
        mist.scheduleFunction(warning_check, {}, timer.getTime() + 30)
    else
        mist.scheduleFunction(early_warning_check, {}, timer.getTime() + 30)
    end
end

function warning_check()
    local warning_time = 60 * 15 -- 15 minutes
    local warning_time = 60 * 2 -- 15 minutes
    if os.time() - game_state["startup_time"] >= warning_time then
        trigger.action.outText("THE MISSION IS RESTARTING IN 5 MINUTES.", 30)
        game_state["startup_time"] = os.time()
        mist.scheduleFunction(restart_check, {}, timer.getTime() + 30)
    else
        mist.scheduleFunction(warning_check, {}, timer.getTime() + 30)
    end
end

function restart_check()
    local restart_time = 60 * 5 -- 5 minutes
    local restart_time = 60 * 3 -- 5 minutes
    if os.time() - game_state["startup_time"] >= restart_time then
        trigger.action.setUserFlag(1337, true)
    else
        mist.scheduleFunction(restart_check, {}, timer.getTime() + 30)
    end
end

do
    mist.scheduleFunction(early_warning_check, {}, timer.getTime() + 30)
end
