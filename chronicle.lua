-- Chronicles fortress events: unit deaths, item creation, and invasions
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

local months = {
    'Granite', 'Slate', 'Felsite',
    'Hematite', 'Malachite', 'Galena',
    'Limestone', 'Sandstone', 'Timber',
    'Moonstone', 'Opal', 'Obsidian',
}

local seasons = {
    'Early Spring', 'Mid Spring', 'Late Spring',
    'Early Summer', 'Mid Summer', 'Late Summer',
    'Early Autumn', 'Mid Autumn', 'Late Autumn',
    'Early Winter', 'Mid Winter', 'Late Winter',
}

local function ordinal(n)
    local rem100 = n % 100
    local rem10 = n % 10
    local suffix = 'th'
    if rem100 < 11 or rem100 > 13 then
        if rem10 == 1 then suffix = 'st'
        elseif rem10 == 2 then suffix = 'nd'
        elseif rem10 == 3 then suffix = 'rd'
        end
    end
    return ('%d%s'):format(n, suffix)
end

local function format_date(year, ticks)
    local day_of_year = math.floor(ticks / 1200) + 1
    local month = math.floor((day_of_year - 1) / 28) + 1
    local day = ((day_of_year - 1) % 28) + 1
    local month_name = months[month] or ('Month' .. tostring(month))
    local season = seasons[month] or 'Unknown Season'
    return string.format('%s %s, %s of Year %d', ordinal(day), month_name, season, year)
end

local function sanitize(text)
    -- convert game strings to utf8 and remove non-printable characters
    local str = dfhack.df2utf(text or '')
    -- strip control characters that may have leaked through
    str = str:gsub('[%z\1-\31]', '')
    return str
end

local function add_entry(text)
    table.insert(state.entries, sanitize(text))
    persist_state()
end

local function on_unit_death(unit_id)
    local unit = df.unit.find(unit_id)
    if not unit then return end
    local name = dfhack.units.getReadableName(unit)
    local date = format_date(df.global.cur_year, df.global.cur_year_tick)
    add_entry(string.format('%s: Death of %s', date, name))
end

local function on_item_created(item_id)
    local item = df.item.find(item_id)
    if not item then return end

    local date = format_date(df.global.cur_year, df.global.cur_year_tick)

    if item.flags.artifact then
        local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.IS_ARTIFACT)
        local rec = gref and df.artifact_record.find(gref.artifact_id) or nil
        local name = rec and dfhack.translation.translateName(rec.name) or 'unknown artifact'
        if rec and rec.id > state.last_artifact_id then
            state.last_artifact_id = rec.id
        end
        add_entry(string.format('%s: Artifact "%s" created', date, name))
    else
        local desc = dfhack.items.getDescription(item, 0, true)
        add_entry(string.format('%s: Item "%s" created', date, desc))
    end
end

local function on_invasion(invasion_id)
    if state.known_invasions[invasion_id] then return end
    state.known_invasions[invasion_id] = true
    local date = format_date(df.global.cur_year, df.global.cur_year_tick)
    add_entry(string.format('%s: Invasion started', date))
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
    local count = tonumber(args[2]) or 25
    if #state.entries == 0 then
        print('Chronicle is empty.')
    else
        local start_idx = math.max(1, #state.entries - count + 1)
        for i = start_idx, #state.entries do
            print(state.entries[i])
        end
    end
else
    print(dfhack.script_help())
end

persist_state()
