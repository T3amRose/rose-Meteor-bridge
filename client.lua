-- Wird nur auf EINEM Client ausgefuehrt (dem Spieler, der dem Einschlag am naechsten ist).
-- Er ermittelt die Bodenhoehe, loest die Explosion aus und meldet die Position an den Server.

local function findGroundZ(x, y)
    for _, startZ in ipairs({ 1000.0, 600.0, 300.0, 150.0, 50.0 }) do
        RequestCollisionAtCoord(x, y, startZ)
        local found, z = GetGroundZFor_3dCoord(x, y, startZ, false)
        if found then return z end
    end
    return nil
end

local function pickModel(list)
    local valid = {}
    for _, name in ipairs(list or {}) do
        local hash = joaat(name)
        if IsModelInCdimage(hash) then valid[#valid + 1] = hash end
    end
    if #valid == 0 then return nil end
    return valid[math.random(#valid)]
end

local function loadModel(hash)
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(hash)
end

-- Easter Egg: Erstellt die Dixiklos ueber dem Spieler, schaltet Physik an und gibt die Netz-IDs zurueck
local function spawnToilets(x, y, z, count)
    local f = Config.Dixi
    local hash = pickModel(f.Models)
    if not hash or not loadModel(hash) then
        print('[rose_Meteor_bridge] Kein gueltiges Dixiklo-Modell in Config.Dixi.Models')
        return {}
    end

    local netIds = {}
    count = math.min(count, f.MaxCount)
    for i = 1, count do
        local ox = (i == 1) and 0.0 or (math.random() * 2 - 1) * f.Spread
        local oy = (i == 1) and 0.0 or (math.random() * 2 - 1) * f.Spread
        local ent = CreateObject(hash, x + ox, y + oy, z + f.DropHeight + (i - 1) * 4.0, true, true, true)
        if ent and ent ~= 0 then
            SetEntityRotation(ent, math.random(-40, 40) + 0.0, math.random(-40, 40) + 0.0, math.random(0, 359) + 0.0, 2, true)
            FreezeEntityPosition(ent, false)
            SetEntityDynamic(ent, true)
            SetEntityHasGravity(ent, true)
            ActivatePhysics(ent)
            SetEntityVelocity(ent, 0.0, 0.0, -20.0)

            local t = GetGameTimer() + 2000
            while not NetworkGetEntityIsNetworked(ent) and GetGameTimer() < t do Wait(0) end
            if NetworkGetEntityIsNetworked(ent) then
                local netId = NetworkGetNetworkIdFromEntity(ent)
                SetNetworkIdCanMigrate(netId, true)
                netIds[#netIds + 1] = netId
            end
        end
    end
    SetModelAsNoLongerNeeded(hash)
    return netIds
end

RegisterNetEvent('rose_meteor:dixi', function(id, count)
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('rose_meteor:dixiDone', id, spawnToilets(c.x, c.y, c.z, count))
end)

RegisterNetEvent('rose_meteor:impact', function(id, x, y, big)
    local z
    local deadline = GetGameTimer() + 3000
    repeat
        z = findGroundZ(x, y)
        if not z then Wait(250) end
    until z or GetGameTimer() > deadline

    if not z then
        print(('[rose_Meteor_bridge] Aufprall %d: kein Boden gefunden bei %.0f, %.0f'):format(id, x, y))
        TriggerServerEvent('rose_meteor:impactDone', id, nil)
        return
    end
    print(('[rose_Meteor_bridge] Aufprall %d bei %.0f, %.0f, %.1f'):format(id, x, y, z))

    -- Liegt der Punkt im Wasser?
    local inWater, waterZ = GetWaterHeight(x, y, z + 50.0)
    local water = inWater and waterZ > z

    local cfg = Config.Impact.Explosion
    if cfg.Enabled then
        local e = big and cfg.Big or cfg.Normal
        AddExplosion(x, y, (water and waterZ or z) + 0.5, e.Type, cfg.Damage and e.DamageScale or 0.0,
            true, false, e.CameraShake)
    end

    local rockCfg = Config.Impact.Rock
    local model = nil
    if rockCfg.Enabled and not water then
        model = pickModel(big and rockCfg.BigModels or rockCfg.Models)
    end

    TriggerServerEvent('rose_meteor:impactDone', id, z, model, water)
end)
