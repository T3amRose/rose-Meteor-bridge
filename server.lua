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
    return tostring(w or ''):upper():find('METEOR', 1, true) ~= nil
end

-- Sucht in allen Feldern von getState() nach "METEOR" (Wetter, Event, Show ...)
local function stateHasMeteors(state)
    if type(state) ~= 'table' then return false end
    for _, v in pairs(state) do
        if type(v) == 'string' and isMeteorWeather(v) then return true end
        if type(v) == 'table' then
            for _, v2 in pairs(v) do
                if type(v2) == 'string' and isMeteorWeather(v2) then return true end
            end
        end
    end
    return false
end

local bridgeStorm = false -- Sturm, den die Bridge selbst gestartet hat

local function stormActive()
    if bridgeStorm then return true end
    return stateHasMeteors(getState())
end

-- Debug: zeigt in der Konsole jede Aenderung von getState(), damit man sieht,
-- was gg_weathersystem waehrend eines Meteor-Sturms meldet.
CreateThread(function()
    local last
    while true do
        Wait(10000)
        if Config.Debug then
            local state = getState()
            local encoded = state and json.encode(state) or 'nil'
            if encoded ~= last then
                last = encoded
                print(('^5[rose_Meteor_bridge]^7 getState: %s | Sturm erkannt: %s'):format(encoded, tostring(stormActive())))
            end
        end
    end
end)

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
-- Aufprall: Stein, Explosion, SmartFires
---------------------------------------------------------------------
local pending = {}   -- [id] = { host, x, y, big, expires }
local rocks = {}     -- Liste { entity, expires }
local nextId = 0

local function nearestPlayer(x, y, range)
    local best, bestDist = nil, range
    for _, src in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            local d = #(vector2(c.x, c.y) - vector2(x, y))
            if d < bestDist then best, bestDist = tonumber(src), d end
        end
    end
    return best
end

local function deleteRock(ent)
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
end

local function spawnRock(x, y, z, model)
    local r = Config.Impact.Rock
    local ent = CreateObjectNoOffset(model, x, y, z - r.SinkDepth, true, true, false)
    if not ent or ent == 0 then
        log('Stein konnte nicht erstellt werden (OneSync aktiv?)')
        return
    end
    local t = GetGameTimer() + 2000
    while not DoesEntityExist(ent) and GetGameTimer() < t do Wait(0) end
    if not DoesEntityExist(ent) then
        log('Stein wurde erstellt, existiert aber nicht')
        return
    end
    log('Stein gesetzt bei %.0f, %.0f, %.1f', x, y, z)

    SetEntityRotation(ent, math.random(-25, 25) + 0.0, math.random(-25, 25) + 0.0, math.random(0, 359) + 0.0, 2, true)
    FreezeEntityPosition(ent, true)

    rocks[#rocks + 1] = { entity = ent, expires = r.Lifetime > 0 and (os.time() + r.Lifetime * 60) or nil }
    while #rocks > r.MaxRocks do
        deleteRock(table.remove(rocks, 1).entity)
    end
end

---------------------------------------------------------------------
-- Easter Egg: /dixi <id> <menge>
-- Die Dixiklos erstellt der Client des Ziel-Spielers (damit sie sofort fallen).
-- Der Server merkt sie sich nur, um sie spaeter wieder zu entfernen.
---------------------------------------------------------------------
local dixis = {}         -- Liste { entity, expires }
local dixiPending = {}   -- [id] = { target, count, expires }

RegisterNetEvent('rose_meteor:dixiDone', function(id, netIds)
    local src = source
    local p = dixiPending[id]
    if not p or p.target ~= src then return end
    dixiPending[id] = nil
    if type(netIds) ~= 'table' then return end

    Wait(500) -- kurz warten, bis die Entities beim Server angekommen sind
    local d = Config.Dixi
    local n = 0
    for i, netId in ipairs(netIds) do
        if i > p.count then break end
        local ent = type(netId) == 'number' and NetworkGetEntityFromNetworkId(netId) or 0
        if ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3 then
            dixis[#dixis + 1] = { entity = ent, expires = d.Lifetime > 0 and (os.time() + d.Lifetime * 60) or nil }
            n = n + 1
        end
    end
    while #dixis > d.MaxTotal do
        deleteRock(table.remove(dixis, 1).entity)
    end
    log('%d Dixiklo(s) auf Spieler %s abgeworfen', n, src)
end)

if Config.Dixi.Enabled then
    RegisterCommand(Config.Dixi.Command, function(source, args)
        local function reply(msg)
            if source == 0 then print('[rose_Meteor_bridge] ' .. msg)
            else TriggerClientEvent('chat:addMessage', source, { args = { '🚽', msg } }) end
        end

        local target = tonumber(args[1]) or (source ~= 0 and source or nil)
        if not target or not GetPlayerName(target) then
            return reply(('Nutzung: /%s <id> <menge>'):format(Config.Dixi.Command))
        end
        local count = math.floor(tonumber(args[2]) or Config.Dixi.DefaultCount)
        count = math.max(1, math.min(count, Config.Dixi.MaxCount))

        nextId = nextId + 1
        dixiPending[nextId] = { target = target, count = count, expires = os.time() + 60 }
        TriggerClientEvent('rose_meteor:dixi', target, nextId, count)
        reply(('%d Dixiklo(s) fliegen auf %s zu!'):format(count, GetPlayerName(target)))
    end, true)

    -- /dixiclear: entfernt alle abgeworfenen Dixiklos
    RegisterCommand(Config.Dixi.ClearCommand or 'dixiclear', function(source)
        local n = 0
        for _, r in ipairs(dixis) do
            if DoesEntityExist(r.entity) then
                DeleteEntity(r.entity)
                n = n + 1
            end
        end
        dixis = {}
        local msg = ('%d Dixiklo(s) entfernt.'):format(n)
        if source == 0 then print('[rose_Meteor_bridge] ' .. msg)
        else TriggerClientEvent('chat:addMessage', source, { args = { '🚽', msg } }) end
    end, true)
end

local function fillCommand(cmd, x, y, z, big)
    return (cmd:gsub('{x}', ('%.2f'):format(x))
               :gsub('{y}', ('%.2f'):format(y))
               :gsub('{z}', ('%.2f'):format(z))
               :gsub('{big}', big and '1' or '0'))
end

local function startSmartFire(x, y, z, big)
    local sf = Config.SmartFire
    if not sf.Enabled then return end
    if sf.BigOnly and not big then return end
    if math.random(1, 100) > sf.Chance then return end
    if sf.Mode ~= 'custom' and GetResourceState(sf.Resource) ~= 'started' then
        log('SmartFires (%s) laeuft nicht', sf.Resource)
        return
    end

    local ok, err = pcall(function()
        if sf.Mode == 'export' then
            exports[sf.Resource][sf.Export](exports[sf.Resource], sf.Args(x, y, z, big))
        elseif sf.Mode == 'event' then
            TriggerEvent(sf.Event, sf.Args(x, y, z, big))
        elseif sf.Mode == 'command' then
            ExecuteCommand(fillCommand(sf.Command, x, y, z, big))
        elseif sf.Mode == 'custom' then
            sf.Custom(x, y, z, big)
        end
    end)
    if ok then
        log('SmartFire gestartet bei %.0f, %.0f, %.0f', x, y, z)
    else
        log('SmartFire fehlgeschlagen: %s', tostring(err))
    end
end

local function scheduleImpact(x, y, big, host, delay)
    host = host or nearestPlayer(x, y, Config.Impact.HostRange)
    if not host then
        log('Kein Spieler in %d m: kein Stein/Explosion', math.floor(Config.Impact.HostRange))
        return
    end
    nextId = nextId + 1
    local id = nextId
    pending[id] = { host = host, x = x, y = y, big = big, expires = os.time() + 60 }
    log('Aufprall %d geplant bei %.0f, %.0f, Spieler %s berechnet ihn', id, x, y, host)
    SetTimeout(math.floor((delay or Config.Impact.Delay) * 1000), function()
        if pending[id] then
            TriggerClientEvent('rose_meteor:impact', host, id, x, y, big)
        end
    end)
end

RegisterNetEvent('rose_meteor:impactDone', function(id, z, model, water)
    local src = source
    local p = pending[id]
    if not p or p.host ~= src then return end
    pending[id] = nil

    if type(z) ~= 'number' or z < -200 or z > 2000 then
        log('Aufprall %d: Bodenhoehe nicht gefunden', id)
        return
    end
    log('Aufprall %d: Boden z=%.1f, Wasser=%s, Modell=%s', id, z, tostring(water), tostring(model))

    if model and not water and Config.Impact.Rock.Enabled then
        spawnRock(p.x, p.y, z, model)
    elseif Config.Impact.Rock.Enabled and not water then
        log('Kein gueltiges Stein-Modell in der Config gefunden')
    end
    startSmartFire(p.x, p.y, z, p.big)
end)

-- Aufraeumen
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for id, p in pairs(pending) do
            if p.expires < now then pending[id] = nil end
        end
        for id, p in pairs(dixiPending) do
            if p.expires < now then dixiPending[id] = nil end
        end
        for _, list in ipairs({ rocks, dixis }) do
            for i = #list, 1, -1 do
                local r = list[i]
                if not DoesEntityExist(r.entity) then
                    table.remove(list, i)
                elseif r.expires and r.expires < now then
                    deleteRock(r.entity)
                    table.remove(list, i)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, r in ipairs(rocks) do deleteRock(r.entity) end
    for _, r in ipairs(dixis) do deleteRock(r.entity) end
end)

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
    scheduleImpact(x, y, big)
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
-- Befehl: /meteorbridge strike [big] | test [big] | start | stop | status | clear | on | off
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
    elseif sub == 'test' then
        -- Testet Stein + Explosion direkt neben dir, ohne gg_weathersystem und ohne Sturm
        if source == 0 then return reply('Nur im Spiel nutzbar.') end
        local c = GetEntityCoords(GetPlayerPed(source))
        local ang = math.random() * 2 * math.pi
        local x, y = c.x + math.cos(ang) * 20.0, c.y + math.sin(ang) * 20.0
        scheduleImpact(x, y, (args[2] or ''):lower() == 'big', tonumber(source), 3.0)
        reply('Test-Aufprall in 3 s, 20 m neben dir.')
    elseif sub == 'clear' then
        local n = #rocks + #dixis
        for _, r in ipairs(rocks) do deleteRock(r.entity) end
        for _, r in ipairs(dixis) do deleteRock(r.entity) end
        rocks, dixis = {}, {}
        reply(('%d Steine/Dixiklos entfernt.'):format(n))
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
