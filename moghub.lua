--[[----------------------------------------------------------------------------
    FFR_SharedProgress -- MogHub plugin (settings page in the Mods menu)

    EXP: every character who has joined (join status Join, TemporalLeave or Leave; not the ones still to come) is
    raised to the level and level-bar share of the furthest one. Synchro: every owned vision, with every such
    character, is raised to the highest synchro mastery points of any of them (capped at each vision's maximum;
    visions with a steeper curve can show a lower rank for the same points). Values only ever go up;
    the change is written into the save the next time the game saves. Awakening (item upgrades 0..3) is left alone.

    WHEN: after each battle and after a save is loaded, never during a battle, an encounter or a loading screen.

    HOW (found with dev_eval)
      roster   : CPP_BFL_SaveDataUnit GetSaveDataUnitParameterListFromJoinStatus(out list, status); elements are
                 structs with UnitId and Experience (units still to join already carry their join EXP)
      curves   : CPP_BFL_Unit GetLevelReachWithExp(id, exp) / GetExpForReachLevel(id, lv); two curves exist (1001-1004
                 need 3139 for Lv 10, 1006/1008 2851), both end at 99, so the level and the bar share are carried over,
                 not the raw EXP
      write    : CPP_BFL_Unit SetPlayableUnitExperience(id, exp, false) updates level and max HP / MP as well
      synchro  : CPP_BFL_Vision GetAllVisionIdList, HasVision(id), Get/SetSynchroMasteryPoint(vision, unit[, point]);
                 the points belong to a vision and a character together, -1 for visions not owned; the game derives
                 the mastery level from the points itself
    ----------------------------------------------------------------------------]]
local mod, kit = ...

local cfg = mod:settings{
    { key = "Exp", label = "Share EXP", type = "toggle", default = true,
      help = "After each battle and on loading, every character who has joined is raised to the level of the furthest one. Stays in the save." },
    { key = "Synchro", label = "Share vision synchro", type = "toggle", default = true,
      help = "After each battle and on loading, every vision's synchro mastery is raised for every character to the highest points of any vision. Stays in the save." },
}

-- eUnitJoinStatus values that count: Join, Leave, TemporalLeave (NotJoin and Lost do not)
local JOINED = { 0, 2, 3 }
local MAX_LEVEL = 99

local logged = {}
local function logOnce(key, fmt, ...)
    if logged[key] then return end
    logged[key] = true
    mod:log(fmt, ...)
end

local function call(libName, fn, ...)
    local o = kit.game.lib(libName)
    if not o then
        logOnce("nolib:" .. libName, "%s not found", libName)
        return nil
    end
    local args = { ... }
    local ok, r = pcall(function() return o[fn](o, table.unpack(args)) end)
    if not ok then
        logOnce("fail:" .. fn, "%s.%s failed: %s", libName, fn, tostring(r))
        return nil
    end
    return r
end

-- { { id, exp }, ... } of every character who has joined
local function roster()
    local out = {}
    for _, status in ipairs(JOINED) do
        local list = {}
        call("CPP_BFL_SaveDataUnit", "GetSaveDataUnitParameterListFromJoinStatus", list, status)
        for _, p in pairs(list) do
            pcall(function()
                local s = p:get()
                out[#out + 1] = { id = s.UnitId, exp = s.Experience }
            end)
        end
    end
    return out
end

---------------------------------------------------------------------------------------------------
-- EXP
---------------------------------------------------------------------------------------------------
local function expFor(id, level) return tonumber(call("CPP_BFL_Unit", "GetExpForReachLevel", id, level)) end

-- level and share of the bar to the next level (0 at the cap)
local function progress(id, exp)
    local lv = tonumber(call("CPP_BFL_Unit", "GetLevelReachWithExp", id, exp))
    if not lv or lv < 1 then return nil end
    if lv >= MAX_LEVEL then return MAX_LEVEL, 0 end
    local lo, hi = expFor(id, lv), expFor(id, lv + 1)
    if not lo or not hi or hi <= lo then return lv, 0 end
    return lv, math.max(0, math.min(1, (exp - lo) / (hi - lo)))
end

-- this character's EXP for that level and bar share
local function expAt(id, lv, share)
    local lo = expFor(id, lv)
    if not lo then return nil end
    if lv >= MAX_LEVEL then return lo end
    local hi = expFor(id, lv + 1)
    if not hi or hi <= lo then return lo end
    return lo + math.floor(share * (hi - lo))
end

local function shareExp(units)
    local best
    for _, u in ipairs(units) do
        u.lv, u.share = progress(u.id, u.exp)
        if u.lv and (not best or u.lv > best.lv or (u.lv == best.lv and u.share > best.share)) then best = u end
    end
    if not best then return end
    local raised = 0
    for _, u in ipairs(units) do
        if u ~= best and u.lv then
            local exp = expAt(u.id, best.lv, best.share)
            if exp and exp > u.exp then
                call("CPP_BFL_Unit", "SetPlayableUnitExperience", u.id, exp, false)
                raised = raised + 1
                mod:log("unit %d: EXP %d -> %d (Lv %d -> %d, like unit %d)", u.id, u.exp, exp, u.lv, best.lv, best.id)
            end
        end
    end
    if raised > 0 then mod:log("EXP: %d character(s) raised to Lv %d (%.0f%%)", raised, best.lv, best.share * 100) end
end

---------------------------------------------------------------------------------------------------
-- Synchro
---------------------------------------------------------------------------------------------------
local function visionIds()
    local ids = {}
    local arr = call("CPP_BFL_Vision", "GetAllVisionIdList")
    if arr then pcall(function() for i = 1, #arr do ids[#ids + 1] = arr[i]:get() end end) end
    return ids
end

local SYNCHRO = 1   -- eVisionMasteryType

local function shareSynchro(units)
    -- the highest points of any owned vision with any character
    local owned, points, best = {}, {}, 0
    for _, vid in ipairs(visionIds()) do
        if call("CPP_BFL_Vision", "HasVision", vid) == true then
            owned[#owned + 1] = vid
            points[vid] = {}
            for _, u in ipairs(units) do
                local p = tonumber(call("CPP_BFL_Vision", "GetSynchroMasteryPoint", vid, u.id)) or -1
                points[vid][u.id] = p
                if p > best then best = p end
            end
        end
    end
    -- every pair gets them, capped at that vision's maximum
    local raised = 0
    for _, vid in ipairs(owned) do
        local cap = tonumber(call("CPP_BFL_Vision", "GetMaxMasteryPoint", vid, SYNCHRO))
        local target = (cap and cap > 0) and math.min(best, cap) or best
        for _, u in ipairs(units) do
            local p = points[vid][u.id]
            if p >= 0 and p < target and call("CPP_BFL_Vision", "SetSynchroMasteryPoint", vid, u.id, target) == true then
                raised = raised + 1
                mod:log("vision %d, unit %d: synchro %d -> %d", vid, u.id, p, target)
            end
        end
    end
    if raised > 0 then mod:log("synchro: %d value(s) raised to %d", raised, best) end
end

---------------------------------------------------------------------------------------------------
-- When: never in a battle, an encounter or behind a loading screen (the setters would write the battle copy),
-- and only with the player on a game map: the title screen has a save object of its own (seen at game start,
-- before any load), which must be left alone.
---------------------------------------------------------------------------------------------------
local NOT_IN_GAME = { Title = true, Boot = true }

local function onGameMap()
    local unit = call("CPP_BFL_Map", "GetPlayerMapUnit")
    if not kit.valid(unit) then return false end
    local ok, name = pcall(function() return unit:GetFullName() end)
    local category = ok and name:match("/Game/Map/(%w+)")
    return category ~= nil and not NOT_IN_GAME[category]
end

local function ready()
    if not kit.game.saveData() or kit.loading or kit.events.battle or kit.game.inBattle() then return false end
    return call("CPP_BFL_Map", "IsDuringEncount") == false and onGameMap()
end

local function sync()
    if not (cfg.Exp or cfg.Synchro) then return true end
    if not ready() then return false end
    local units = roster()
    if #units < 2 then return true end
    if cfg.Exp then shareExp(units) end
    if cfg.Synchro then shareSynchro(units) end
    return true
end

-- tries again every second until the game is ready
local function syncSoon(delay)
    local function try()
        if not sync() then mod:after(1000, try, "shared progress retry") end
    end
    mod:after(delay, try, "shared progress")
end

mod:on("saveLoaded", function() syncSoon(2000) end)
mod:on("battleEnd", function() syncSoon(2000) end)
cfg:onChange(function(_, value) if value then syncSoon(500) end end)
mod:onToggle(function(on) if on then syncSoon(500) end end)

mod:log("v%s ready: EXP %s, synchro %s", mod.version, tostring(cfg.Exp), tostring(cfg.Synchro))
