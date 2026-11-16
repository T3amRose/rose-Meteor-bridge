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
    NearPlayerChance = 55,

    -- Abstand zum Spieler bei "NearPlayer" (Meter)
    NearPlayerMinDist = 50,
    NearPlayerMaxDist = 300,

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

---------------------------------------------------------------------
-- AUFPRALL: Stein + Explosion/Druckwelle
-- Gilt fuer die Einschlaege, die diese Bridge schickt.
---------------------------------------------------------------------
Config.Impact = {
    -- Sekunden zwischen meteorStrike und Aufprall (gg_weathersystem: ca. 9 s)
    Delay = 9.0,

    -- Nur ausfuehren, wenn ein Spieler naeher als X Meter ist
    -- (der naechste Spieler berechnet die Bodenhoehe, weiter weg ist die Karte nicht geladen)
    HostRange = 1500.0,

    Explosion = {
        Enabled = true,
        -- false = nur Druckwelle/Effekt ohne Schaden, true = echter Schaden
        Damage = true,
        -- Explosionstypen siehe https://docs.fivem.net/natives/?_0xE3AD2BDBAEE269AC
        Normal = { Type = 5,  DamageScale = 1.0, CameraShake = 1.0 }, -- 5 = TANKSHELL
        Big    = { Type = 8,  DamageScale = 1.5, CameraShake = 2.0 }, -- 8 = PLANE
    },

    Rock = {
        Enabled = true,
        -- Wie lange der Stein liegen bleibt (Minuten, 0 = bis Restart)
        Lifetime = 20,
        -- Maximal gleichzeitig liegende Steine (aelteste werden entfernt)
        MaxRocks = 25,
        -- Wie tief der Stein im Boden steckt (Meter)
        SinkDepth = 0.6,
        -- Prop-Modelle (ungueltige werden automatisch uebersprungen)
        Models = {
            'prop_rock_1_a', 'prop_rock_1_b', 'prop_rock_1_c',
            'prop_rock_1_d', 'prop_rock_1_e', 'prop_rock_1_f',
        },
        BigModels = {
            'prop_rock_4_big', 'prop_rock_4_big2', 'prop_rock_4_c', 'prop_rock_4_d',
        },
    },
}

---------------------------------------------------------------------
-- EASTER EGG: /dixi <id> <menge> 🚽
-- Laesst ueber dem Spieler mit der ID Dixiklos vom Himmel fallen.
-- Nur fuer Admins (ACE: command.dixi). Keine Explosion, kein Feuer.
---------------------------------------------------------------------
Config.Dixi = {
    Enabled = true,

    -- Befehlsname
    Command = 'dixi',

    -- Befehl zum Entfernen aller Dixiklos
    ClearCommand = 'dixiclear',

    -- Prop-Modelle (ungueltige werden automatisch uebersprungen)
    Models = { 'prop_portaloo_01a' },

    -- Aus welcher Hoehe ueber dem Spieler sie fallen (Meter)
    DropHeight = 60.0,

    -- Menge, wenn keine angegeben wird / Maximum pro Befehl
    DefaultCount = 1,
    MaxCount = 30,

    -- Wie weit sie um den Spieler herum landen (Meter). Das erste faellt genau auf ihn.
    Spread = 6.0,

    -- Wie lange sie liegen bleiben (Minuten, 0 = bis Restart)
    Lifetime = 10,

    -- Maximal gleichzeitig liegende Dixiklos (aelteste werden entfernt)
    MaxTotal = 60,
}

---------------------------------------------------------------------
-- SMARTFIRES (London Studios) – optional
-- Die genaue API haengt von deiner SmartFires-Version ab. Trage hier ein,
-- was in der SmartFires-Doku unter "Exports/Developer" steht.
---------------------------------------------------------------------
Config.SmartFire = {
    Enabled = false,

    -- Ordnername der Ressource
    Resource = 'SmartFires',

    -- Chance, dass ein Einschlag ein SmartFire startet (0-100 %)
    Chance = 100,
    -- Nur bei grossen Einschlaegen?
    BigOnly = false,

    -- Wie das Feuer gestartet wird:
    --   'export'  = Server-Export   -> exports[Resource][Export](Args(...))
    --   'event'   = Server-Event    -> TriggerEvent(Event, Args(...))
    --   'command' = Konsolenbefehl  -> ExecuteCommand(Command) mit {x} {y} {z} {big}
    --   'custom'  = eigene Funktion -> Custom(x, y, z, big)
    Mode = 'export',

    Export  = 'CreateFire',             -- Name laut SmartFires-Doku eintragen
    Event   = 'SmartFires:CreateFire',  -- Name laut SmartFires-Doku eintragen
    Command = 'startfire {x} {y} {z}',  -- Befehl laut SmartFires-Doku eintragen

    -- Welche Werte an Export/Event uebergeben werden. Reihenfolge an die Doku anpassen.
    Args = function(x, y, z, big)
        return vector3(x, y, z), big and 'large' or 'normal'
    end,

    Custom = function(x, y, z, big)
        -- Beispiel: exports['SmartFires']:IrgendeinExport(vector3(x, y, z))
    end,
}
