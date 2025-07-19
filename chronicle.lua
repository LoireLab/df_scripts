-- Chronicles fortress events: unit deaths, artifact creation, and invasions
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

local function on_item_created(item_id)
    local item = df.item.find(item_id)
    if not item or not item.flags.artifact then return end

    local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.IS_ARTIFACT)
    local rec = gref and df.artifact_record.find(gref.artifact_id) or nil
    if not rec then return end

    local name = dfhack.translation.translateName(rec.name)
    local date = format_date(rec.year, rec.season_tick or 0)
    if rec.id > state.last_artifact_id then
        state.last_artifact_id = rec.id
    end
    add_entry(string.format('Artifact "%s" created on %s', name, date))
end

local function on_invasion(invasion_id)
    if state.known_invasions[invasion_id] then return end
    state.known_invasions[invasion_id] = true
    local date = format_date(df.global.cur_year, df.global.cur_year_tick)
    add_entry(string.format('Invasion started on %s', date))
end
-- legacy scanning functions for artifacts and invasions have been removed in
-- favor of event-based tracking. the main loop is no longer needed.

local function do_enable()
    state.enabled = true
    eventful.enableEvent(eventful.eventType.ITEM_CREATED, 1)
    eventful.enableEvent(eventful.eventType.INVASION, 1)
    eventful.onUnitDeath[GLOBAL_KEY] = on_unit_death
    eventful.onItemCreated[GLOBAL_KEY] = on_item_created
    eventful.onInvasion[GLOBAL_KEY] = on_invasion
    persist_state()
end

local function do_disable()
    state.enabled = false
    eventful.onUnitDeath[GLOBAL_KEY] = nil
    eventful.onItemCreated[GLOBAL_KEY] = nil
    eventful.onInvasion[GLOBAL_KEY] = nil
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
        eventful.onItemCreated[GLOBAL_KEY] = nil
        eventful.onInvasion[GLOBAL_KEY] = nil
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
