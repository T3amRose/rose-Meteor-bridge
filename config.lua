Config = {}

-- Debug-Ausgaben in der Server-Konsole
Config.Debug = true

-- Admin-Befehl /meteorbridge (in server.cfg: add_ace group.admin command.meteorbridge allow)
Config.Command = 'meteorbridge'

---------------------------------------------------------------------
-- ZUFAELLIGE EINSCHLAEGE
-- Waehrend eines Meteor-Sturms schickt die Bridge zusaetzliche Einschlaege
-- an zufaellige Positionen (Zonen auf der Karte oder irgendwo um einen Spieler).
---------------------------------------------------------------------
Config.Strikes = {
    Enabled = true,

    -- Nur waehrend eines Meteor-Sturms (true) oder immer (false)
    OnlyDuringStorm = true,

    -- Abstand zwischen zwei Einschlaegen (Sekunden, zufaellig zwischen Min und Max)
    IntervalMin = 20,
    IntervalMax = 60,

    -- Chance auf einen grossen Einschlag (0-100 %)
    BigChance = 10,

    -- Chance, dass der Einschlag irgendwo um einen zufaelligen Spieler herum landet (0-100 %).
    -- Sonst landet er in einer zufaelligen Zone aus Config.Zones.
    NearPlayerChance = 35,

    -- Abstand zum Spieler bei "NearPlayer" (Meter)
    NearPlayerMinDist = 50,
    NearPlayerMaxDist = 900,

    -- Wenn kein Spieler online ist, trotzdem in Zonen einschlagen lassen?
    WithoutPlayers = false,
}

-- Zonen fuer zufaellige Einschlaege (Rechtecke in Weltkoordinaten, nur X/Y).
-- weight = wie oft die Zone gewaehlt wird. Werte sind Naeherungen auf Land,
-- du kannst sie beliebig anpassen, entfernen oder neue hinzufuegen.
Config.Zones = {
    { name = 'Downtown Los Santos', minX = -800,  maxX = 900,   minY = -1800, maxY = -500,  weight = 3 },
    { name = 'Vinewood Hills',      minX = -1500, maxX = 1000,  minY = 100,   maxY = 900,   weight = 2 },
    { name = 'Vespucci / Del Perro',minX = -1600, maxX = -1100, minY = -1200, maxY = -300,  weight = 1 },
    { name = 'East Los Santos',     minX = 800,   maxX = 1400,  minY = -2000, maxY = -400,  weight = 2 },
    { name = 'Flughafen LSIA',      minX = -1700, maxX = -900,  minY = -3300, maxY = -2400, weight = 1 },
    { name = 'Tataviam Berge',      minX = 1600,  maxX = 2600,  minY = -1600, maxY = 0,     weight = 1 },
    { name = 'Great Chaparral',     minX = -800,  maxX = 200,   minY = 1700,  maxY = 2600,  weight = 1 },
    { name = 'Grand Senora Wueste', minX = 200,   maxX = 1500,  minY = 2600,  maxY = 3300,  weight = 3 },
    { name = 'Sandy Shores',        minX = 1400,  maxX = 2200,  minY = 3500,  maxY = 3900,  weight = 2 },
    { name = 'Fort Zancudo',        minX = -2700, maxX = -1800, minY = 2900,  maxY = 3400,  weight = 1 },
    { name = 'Grapeseed',           minX = 1600,  maxX = 2700,  minY = 4400,  maxY = 5200,  weight = 2 },
    { name = 'Mount Chiliad',       minX = 0,     maxX = 1100,  minY = 5000,  maxY = 5800,  weight = 1 },
    { name = 'Paleto Bay',          minX = -400,  maxX = 300,   minY = 6000,  maxY = 6600,  weight = 2 },
}

---------------------------------------------------------------------
-- OPTIONAL: Meteor-Sturm selbst zufaellig starten (Standard: aus,
-- gg_weathersystem startet ihn ueber "Random Sky Events" schon selbst)
---------------------------------------------------------------------
Config.RandomStorm = {
    Enabled = false,
    CheckIntervalMin = 30,  -- Minuten
    CheckIntervalMax = 90,
    Chance = 25,            -- % pro Wurf
    Cooldown = 120,         -- Minuten zwischen zwei Stuermen
    StartDelay = 15,        -- erster Wurf X Min nach Serverstart
    Duration = 16,          -- Minuten, dann altes Wetter zurueck
    RestorePreviousWeather = true,
    AllowedHours = nil,     -- z.B. { from = 20, to = 5 } fuer nur nachts
    MinPlayers = 1,
    Instant = false,
}
