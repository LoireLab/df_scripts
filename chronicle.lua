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
        item_counts = {}, -- item creation summary per year
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
    -- convert game strings to console encoding and remove non-printable characters
    local str = dfhack.df2console(text or '')
    -- strip control characters that may have leaked through
    str = str:gsub('[%z\1-\31]', '')
    return str
end

local function add_entry(text)
    table.insert(state.entries, sanitize(text))
    persist_state()
end

local CATEGORY_MAP = {
    -- food and food-related
    DRINK='food', DRINK2='food', FOOD='food', MEAT='food', FISH='food',
    FISH_RAW='food', PLANT='food', PLANT_GROWTH='food', SEEDS='food',
    EGG='food', CHEESE='food', POWDER_MISC='food', LIQUID_MISC='food',
    GLOB='food',
    -- weapons and defense
    WEAPON='weapons', TRAPCOMP='weapons',
    AMMO='ammo', SIEGEAMMO='ammo',
    ARMOR='armor', PANTS='armor', HELM='armor', GLOVES='armor',
    SHOES='armor', SHIELD='armor', QUIVER='armor',
    -- materials
    WOOD='wood', BOULDER='stone', ROCK='stone', ROUGH='gems', SMALLGEM='gems',
    BAR='bars_blocks', BLOCKS='bars_blocks',
    -- misc
    COIN='coins',
    -- finished goods and furniture
    FIGURINE='finished_goods', AMULET='finished_goods', SCEPTER='finished_goods',
    CROWN='finished_goods', RING='finished_goods', EARRING='finished_goods',
    BRACELET='finished_goods', CRAFTS='finished_goods', TOY='finished_goods',
    TOOL='finished_goods', GOBLET='finished_goods', FLASK='finished_goods',
    BOX='furniture', BARREL='furniture', BED='furniture', CHAIR='furniture',
    TABLE='furniture', DOOR='furniture', WINDOW='furniture', BIN='furniture',
}

local IGNORE_TYPES = {
    CORPSE=true, CORPSEPIECE=true, REMAINS=true,
}

local function get_category(item)
    local t = df.item_type[item:getType()]
    return CATEGORY_MAP[t] or 'other'
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
        if rec and rec.id > state.last_artifact_id then
            state.last_artifact_id = rec.id
        end
        -- artifact announcements are captured via REPORT events
        return
    end

    local type_name = df.item_type[item:getType()]
    if IGNORE_TYPES[type_name] then return end

    local year = df.global.cur_year
    local category = get_category(item)
    state.item_counts[year] = state.item_counts[year] or {}
    state.item_counts[year][category] = (state.item_counts[year][category] or 0) + 1
    persist_state()
end

local function on_invasion(invasion_id)
    if state.known_invasions[invasion_id] then return end
    state.known_invasions[invasion_id] = true
    local date = format_date(df.global.cur_year, df.global.cur_year_tick)
    add_entry(string.format('%s: Invasion started', date))
end

-- capture artifact announcements verbatim from reports
local pending_artifact_report
local function on_report(report_id)
    local rep = df.report.find(report_id)
    if not rep or not rep.flags.announcement then return end
    local text = dfhack.df2console(rep.text)
    if pending_artifact_report then
        if text:find(' offers it to ') then
            local date = format_date(df.global.cur_year, df.global.cur_year_tick)
            add_entry(string.format('%s: %s %s', date, pending_artifact_report, text))
            pending_artifact_report = nil
            return
        else
            local date = format_date(df.global.cur_year, df.global.cur_year_tick)
            add_entry(string.format('%s: %s', date, pending_artifact_report))
            pending_artifact_report = nil
        end
    end
    if text:find(' has created ') then
        pending_artifact_report = text
    end
end
-- legacy scanning functions for artifacts and invasions have been removed in
-- favor of event-based tracking. the main loop is no longer needed.

local function do_enable()
    state.enabled = true
    eventful.enableEvent(eventful.eventType.ITEM_CREATED, 1)
    eventful.enableEvent(eventful.eventType.INVASION, 1)
    eventful.enableEvent(eventful.eventType.REPORT, 1)
    eventful.onUnitDeath[GLOBAL_KEY] = on_unit_death
    eventful.onItemCreated[GLOBAL_KEY] = on_item_created
    eventful.onInvasion[GLOBAL_KEY] = on_invasion
    eventful.onReport[GLOBAL_KEY] = on_report
    persist_state()
end

local function do_disable()
    state.enabled = false
    eventful.onUnitDeath[GLOBAL_KEY] = nil
    eventful.onItemCreated[GLOBAL_KEY] = nil
    eventful.onInvasion[GLOBAL_KEY] = nil
    eventful.onReport[GLOBAL_KEY] = nil
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
        eventful.onReport[GLOBAL_KEY] = nil
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
elseif cmd == 'summary' then
    local years = {}
    for year in pairs(state.item_counts) do table.insert(years, year) end
    table.sort(years)
    if #years == 0 then
        print('No item creation records.')
        return
    end
    for _,year in ipairs(years) do
        local counts = state.item_counts[year]
        local parts = {}
        for cat,count in pairs(counts) do
            table.insert(parts, string.format('%d %s', count, cat))
        end
        table.sort(parts)
        print(string.format('Year %d: %s', year, table.concat(parts, ', ')))
    end
else
    print(dfhack.script_help())
end

persist_state()
