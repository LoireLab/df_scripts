-- Chronicles fortress events (currently only unit deaths)
--@module = true
--@enable = true

local eventful = require('plugins.eventful')
local utils = require('utils')

local GLOBAL_KEY = 'chronicle'

local function get_default_state()
    return {
        entries = {},
        last_artifact_id = -1,
        known_invasions = {},
    }
end

state = state or get_default_state()

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

local function format_date(year, ticks)
    local julian_day = math.floor(ticks / 1200) + 1
    local month = math.floor(julian_day / 28) + 1
    local day = julian_day % 28
    return string.format('%03d-%02d-%02d', year, month, day)
end

local function add_entry(text)
    table.insert(state.entries, text)
    persist_state()
end

local function on_unit_death(unit_id)
    local unit = df.unit.find(unit_id)
    if not unit then return end
    local name = dfhack.units.getReadableName(unit)
    local date = format_date(df.global.cur_year, df.global.cur_year_tick)
    add_entry(string.format('Death of %s on %s', name, date))
end
local function check_artifacts()
    local last_id = state.last_artifact_id
    for _, rec in ipairs(df.global.world.artifacts.all) do
        if rec.id > last_id then
            local name = dfhack.translation.translateName(rec.name)
            -- artifact_record stores the creation tick in `season_tick`
            local date = format_date(rec.year, rec.season_tick or 0)
            add_entry(string.format('Artifact "%s" created on %s', name, date))
            last_id = rec.id
        end
    end
    state.last_artifact_id = last_id
end

local function check_invasions()
    for _, inv in ipairs(df.global.plotinfo.invasions.list) do
        if inv.flags.active and not state.known_invasions[inv.id] then
            state.known_invasions[inv.id] = true
            local date = format_date(df.global.cur_year, df.global.cur_year_tick)
            add_entry(string.format('Invasion started on %s', date))
        end
    end
end

-- main loop; artifact and invasion tracking disabled to avoid scanning large
-- data structures, which was causing hangs on some forts
local function event_loop()
    if not state.enabled then return end
    dfhack.timeout(1200, 'ticks', event_loop)
end

local function do_enable()
    state.enabled = true
    eventful.onUnitDeath[GLOBAL_KEY] = on_unit_death
    persist_state()

    event_loop()
end

local function do_disable()
    state.enabled = false
    eventful.onUnitDeath[GLOBAL_KEY] = nil
    persist_state()
end

local function load_state()
    state = get_default_state()
    utils.assign(state, dfhack.persistent.getSiteData(GLOBAL_KEY, state))
end

-- State change hook

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        eventful.onUnitDeath[GLOBAL_KEY] = nil
        state.enabled = false
        return
    end
    if sc ~= SC_MAP_LOADED or not dfhack.world.isFortressMode() then
        return
    end

    load_state()
    if state.enabled then
        do_enable()
    end
end

if dfhack.isMapLoaded() and dfhack.world.isFortressMode() then
    load_state()
    if state.enabled then
        do_enable()
    end
end

if dfhack_flags.module then return end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('chronicle requires a loaded fortress map')
end

load_state()
local args = {...}
local cmd = args[1] or 'print'

if cmd == 'enable' then
    do_enable()
elseif cmd == 'disable' then
    do_disable()
elseif cmd == 'clear' then
    state.entries = {}
    persist_state()
elseif cmd == 'print' then
    for _, entry in ipairs(state.entries) do
        print(entry)
    end
else
    print(dfhack.script_help())
end

persist_state()
