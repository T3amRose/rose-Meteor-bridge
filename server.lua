local WS = 'gg_weathersystem'

local function log(msg, ...)
    if Config.Debug then
        print(('^5[rose_Meteor_bridge]^7 ' .. msg):format(...))
    end
end

local function wsReady()
    return GetResourceState(WS) == 'started'
end

local function getState()
    if not wsReady() then return nil end
    local ok, state = pcall(function() return exports[WS]:getState() end)
    if ok then return state end
    return nil
end

local function setWeather(name, instant)
    local ok, res = pcall(function() return exports[WS]:setWeather(name, instant) end)
    return ok and res ~= false
end

local function isMeteorWeather(w)
    w = tostring(w or ''):upper()
    return w == 'METEORSTORM' or w == 'METEORS'
end

local bridgeStorm = false -- Sturm, den die Bridge selbst gestartet hat

local function stormActive()
    if bridgeStorm then return true end
    local state = getState()
    return state ~= nil and isMeteorWeather(state.weather)
end

---------------------------------------------------------------------
-- Zufaellige Position
---------------------------------------------------------------------
local function pickZone()
    local total = 0
    for _, z in ipairs(Config.Zones) do total = total + (z.weight or 1) end
    if total <= 0 then return nil end
    local r = math.random() * total
    for _, z in ipairs(Config.Zones) do
        r = r - (z.weight or 1)
        if r <= 0 then return z end
    end
    return Config.Zones[#Config.Zones]
end

local function randomInZone()
    local z = pickZone()
    if not z then return nil end
    local x = z.minX + math.random() * (z.maxX - z.minX)
    local y = z.minY + math.random() * (z.maxY - z.minY)
    return x, y, z.name
end

local function randomNearPlayer()
    local players = GetPlayers()
    if #players == 0 then return nil end
    local src = players[math.random(#players)]
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    local s = Config.Strikes
    local dist = s.NearPlayerMinDist + math.random() * (s.NearPlayerMaxDist - s.NearPlayerMinDist)
    local ang = math.random() * 2 * math.pi
    return c.x + math.cos(ang) * dist, c.y + math.sin(ang) * dist, ('%d m um Spieler %s'):format(math.floor(dist), src)
end

local function randomPosition()
    if math.random(1, 100) <= Config.Strikes.NearPlayerChance then
        local x, y, label = randomNearPlayer()
        if x then return x, y, label end
    end
    return randomInZone()
end

---------------------------------------------------------------------
-- Einschlag ausloesen
---------------------------------------------------------------------
local function strike(big, x, y, label)
    if not x then
        x, y, label = randomPosition()
        if not x then return false, 'keine Position gefunden' end
    end
    if big == nil then
        big = math.random(1, 100) <= Config.Strikes.BigChance
    end
    local ok, err = pcall(function()
        return exports[WS]:meteorStrike(nil, big, x + 0.0, y + 0.0)
    end)
    if not ok then
        log('meteorStrike fehlgeschlagen: %s', tostring(err))
        return false, err
    end
    log('%s Einschlag bei %.0f, %.0f (%s) in ca. 9 s', big and 'GROSSER' or 'Normaler', x, y, label or '?')
    return true
end

CreateThread(function()
    math.randomseed(os.time())
    Wait(5000)
    while true do
        local s = Config.Strikes
        Wait(math.random(s.IntervalMin, math.max(s.IntervalMin, s.IntervalMax)) * 1000)
        if s.Enabled and wsReady()
            and (not s.OnlyDuringStorm or stormActive())
            and (s.WithoutPlayers or #GetPlayers() > 0) then
            strike()
        end
    end
end)

---------------------------------------------------------------------
-- Optional: Sturm zufaellig starten
---------------------------------------------------------------------
local previousWeather, lastStorm, nextRoll, stormToken = nil, 0, 0, 0

local function hourAllowed(hour)
    local h = Config.RandomStorm.AllowedHours
    if not h or hour == nil then return true end
    if h.from <= h.to then return hour >= h.from and hour < h.to end
    return hour >= h.from or hour < h.to
end

local function stopStorm(reason)
    if not bridgeStorm then return false end
    bridgeStorm = false
    stormToken = stormToken + 1
    local state = getState()
    if Config.RandomStorm.RestorePreviousWeather and previousWeather and state and isMeteorWeather(state.weather) then
        setWeather(previousWeather, false)
    end
    log('Sturm beendet (%s)', reason)
    previousWeather = nil
    return true
end

local function startStorm(force)
    local rs = Config.RandomStorm
    if bridgeStorm then return false, 'Sturm laeuft bereits' end
    local state = getState()
    if not state then return false, 'gg_weathersystem nicht bereit' end
    if not force then
        if #GetPlayers() < rs.MinPlayers then return false, 'zu wenige Spieler' end
        if os.time() - lastStorm < rs.Cooldown * 60 then return false, 'Cooldown' end
        if state.quake then return false, 'Erdbeben aktiv' end
        if isMeteorWeather(state.weather) or tostring(state.weather):upper() == 'HURRICANE' then
            return false, 'anderes Event aktiv'
        end
        if not hourAllowed(state.time) then return false, 'Uhrzeit nicht erlaubt' end
    end

    local ok = setWeather('METEORSTORM', rs.Instant) or setWeather('meteors', rs.Instant)
    if not ok then return false, 'setWeather fehlgeschlagen' end

    bridgeStorm = true
    previousWeather = not isMeteorWeather(state.weather) and state.weather or nil
    lastStorm = os.time()
    stormToken = stormToken + 1
    local token = stormToken
    log('Meteor-Sturm gestartet (vorher: %s)', tostring(previousWeather))
    SetTimeout(rs.Duration * 60 * 1000, function()
        if token == stormToken then stopStorm('Zeit abgelaufen') end
    end)
    return true
end

CreateThread(function()
    local rs = Config.RandomStorm
    nextRoll = os.time() + rs.StartDelay * 60
    while true do
        Wait(15000)
        if rs.Enabled and os.time() >= nextRoll then
            if math.random(1, 100) <= rs.Chance then
                local ok, why = startStorm(false)
                if not ok then log('Kein Sturm: %s', why) end
            end
            nextRoll = os.time() + math.random(rs.CheckIntervalMin, math.max(rs.CheckIntervalMin, rs.CheckIntervalMax)) * 60
        end
    end
end)

---------------------------------------------------------------------
-- Befehl: /meteorbridge strike [big] | start | stop | status | on | off
---------------------------------------------------------------------
RegisterCommand(Config.Command, function(source, args)
    local sub = (args[1] or 'status'):lower()
    local function reply(msg)
        if source == 0 then
            print('[rose_Meteor_bridge] ' .. msg)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { 'Meteor-Bridge', msg } })
        end
    end

    if sub == 'strike' then
        local ok, why = strike((args[2] or ''):lower() == 'big' or nil)
        reply(ok and 'Zufaelliger Einschlag gesendet.' or ('Fehlgeschlagen: ' .. tostring(why)))
    elseif sub == 'start' then
        local ok, why = startStorm(true)
        reply(ok and 'Meteor-Sturm gestartet.' or ('Fehlgeschlagen: ' .. tostring(why)))
    elseif sub == 'stop' then
        reply(stopStorm('manuell') and 'Sturm beendet.' or 'Kein Sturm der Bridge aktiv.')
    elseif sub == 'on' then
        Config.Strikes.Enabled = true
        reply('Zufaellige Einschlaege aktiviert.')
    elseif sub == 'off' then
        Config.Strikes.Enabled = false
        reply('Zufaellige Einschlaege deaktiviert.')
    else
        local state = getState()
        reply(('Einschlaege: %s | Wetter laut gg_weathersystem: %s | Sturm erkannt: %s')
            :format(tostring(Config.Strikes.Enabled), tostring(state and state.weather), tostring(stormActive())))
    end
end, true)

exports('RandomStrike', function(big) return strike(big) end)
exports('StrikeAt', function(x, y, big) return strike(big or false, x, y, 'Export') end)
exports('StartMeteorStorm', function() return startStorm(true) end)
exports('StopMeteorStorm', function() return stopStorm('export') end)
