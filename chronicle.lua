-- Chronicles fortress events: unit deaths, item creation, and invasions
--@module = true

local eventful = require('plugins.eventful')
local utils = require('utils')

local help = [====[
chronicle
========

Chronicles fortress events: unit deaths, item creation, and invasions

Usage:
	chronicle enable
	chronicle disable 

    chronicle [print] - prints 25 last recorded events 
	chronicle print [number] - prints last [number] recorded events 
	chronicle export - saves current chronicle to a txt file 
	chronicle clear - erases current chronicle (DANGER)
	
	chronicle summary - shows how much items were produced per category in each year
	
	chronicle masterworks [enable|disable] - enables or disables logging of masterful crafted items events
]====]

local GLOBAL_KEY = 'chronicle'

local function get_default_state()
    return {
        entries = {},
        last_artifact_id = -1,
        known_invasions = {},
        item_counts = {}, -- item creation summary per year
        log_masterworks = true, -- capture "masterpiece" announcements
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

local function transliterate(str)
    -- replace unicode punctuation with ASCII equivalents
    str = str:gsub('[\226\128\152\226\128\153]', "'") -- single quotes
    str = str:gsub('[\226\128\156\226\128\157]', '"') -- double quotes
    str = str:gsub('\226\128\147', '-') -- en dash
    str = str:gsub('\226\128\148', '-') -- em dash
    str = str:gsub('\226\128\166', '...') -- ellipsis

    local accent_map = {
        ['á']='a', ['à']='a', ['ä']='a', ['â']='a', ['ã']='a', ['å']='a',
        ['Á']='A', ['À']='A', ['Ä']='A', ['Â']='A', ['Ã']='A', ['Å']='A',
        ['é']='e', ['è']='e', ['ë']='e', ['ê']='e',
        ['É']='E', ['È']='E', ['Ë']='E', ['Ê']='E',
        ['í']='i', ['ì']='i', ['ï']='i', ['î']='i',
        ['Í']='I', ['Ì']='I', ['Ï']='I', ['Î']='I',
        ['ó']='o', ['ò']='o', ['ö']='o', ['ô']='o', ['õ']='o',
        ['Ó']='O', ['Ò']='O', ['Ö']='O', ['Ô']='O', ['Õ']='O',
        ['ú']='u', ['ù']='u', ['ü']='u', ['û']='u',
        ['Ú']='U', ['Ù']='U', ['Ü']='U', ['Û']='U',
        ['ç']='c', ['Ç']='C', ['ñ']='n', ['Ñ']='N', ['ß']='ss',
        ['Æ']='AE', ['æ']='ae', ['Ø']='O', ['ø']='o',
        ['Þ']='Th', ['þ']='th', ['Ð']='Dh', ['ð']='dh',
    }
    for k,v in pairs(accent_map) do
        str = str:gsub(k, v)
    end
    return str
end

local function sanitize(text)
    -- convert game strings to UTF-8 and remove non-printable characters
    local str = dfhack.df2utf(text or '')
    -- strip control characters that may have leaked through
    str = str:gsub('[%z\1-\31]', '')
    str = transliterate(str)
    -- strip quality wrappers from item names
    -- e.g. -item-, +item+, *item*, ≡item≡, ☼item☼, «item»
    str = str:gsub('%-([^%-]+)%-', '%1')
    str = str:gsub('%+([^%+]+)%+', '%1')
    str = str:gsub('%*([^%*]+)%*', '%1')
    str = str:gsub('≡([^≡]+)≡', '%1')
    str = str:gsub('☼([^☼]+)☼', '%1')
    str = str:gsub('«([^»]+)»', '%1')
    -- remove any stray wrapper characters that might remain
    str = str:gsub('[☼≡«»]', '')
    -- strip any remaining characters outside of latin letters, digits, and
    -- basic punctuation
    str = str:gsub("[^A-Za-z0-9%s%.:,;!'\"%?()%+%-]", '')

    return str
end

local function add_entry(text)
    table.insert(state.entries, sanitize(text))
    persist_state()
end

local function export_chronicle(path)
    path = path or (dfhack.getSavePath() .. '/chronicle.txt')
    local ok, f = pcall(io.open, path, 'w')
    if not ok or not f then
        qerror('Cannot open file for writing: ' .. path)
    end
    for _,entry in ipairs(state.entries) do
        f:write(entry, '\n')
    end
    f:close()
    print('Chronicle written to: ' .. path)
end

local DEATH_TYPES = reqscript('gui/unit-info-viewer').DEATH_TYPES

local function trim(str)
    return str:gsub('^%s+', ''):gsub('%s+$', '')
end

local function get_race_name(race_id)
    return df.creature_raw.find(race_id).name[0]
end

local function death_string(cause)
    if cause == -1 then return 'died' end
    return trim(DEATH_TYPES[cause] or 'died')
end

local function describe_unit(unit)
    local name = dfhack.units.getReadableName(unit)
    if unit.name.nickname ~= '' and not name:find(unit.name.nickname, 1, true) then
        name = name:gsub(unit.name.first_name, unit.name.first_name .. ' "' .. unit.name.nickname .. '"')
    end
    local titles = {}
    local prof = dfhack.units.getProfessionName(unit)
    if prof and prof ~= '' then table.insert(titles, prof) end
    for _, np in ipairs(dfhack.units.getNoblePositions(unit) or {}) do
        if np.position and np.position.name and np.position.name[0] ~= '' then
            table.insert(titles, np.position.name[0])
        end
    end
    if #titles > 0 then
        name = name .. ' (' .. table.concat(titles, ', ') .. ')'
    end
    return name
end

local function format_death_text(unit)
    local str = unit.name.has_name and '' or 'The '
    str = str .. describe_unit(unit)
    str = str .. ' ' .. death_string(unit.counters.death_cause)
    local incident = df.incident.find(unit.counters.death_id)
    if incident then
        str = str .. (' in year %d'):format(incident.event_year)
        if incident.criminal then
            local killer = df.unit.find(incident.criminal)
            if killer then
                str = str .. (', killed by the %s'):format(get_race_name(killer.race))
                if killer.name.has_name then
                    str = str .. (' %s'):format(dfhack.translation.translateName(dfhack.units.getVisibleName(killer)))
                end
            end
        end
    end
    return str
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
    local date = format_date(df.global.cur_year, df.global.cur_year_tick)
    add_entry(string.format('%s: %s', date, format_death_text(unit)))
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

-- capture artifact announcements from reports
local pending_artifact_report
local function on_report(report_id)
    local rep = df.report.find(report_id)
    if not rep or not rep.flags.announcement then return end
    local text = sanitize(rep.text)
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
        return
    end

    if state.log_masterworks and text:lower():find('has created a master') then
        local date = format_date(df.global.cur_year, df.global.cur_year_tick)
        add_entry(string.format('%s: %s', date, text))
        return
    end

    -- other notable announcements
    local date = format_date(df.global.cur_year, df.global.cur_year_tick)
    if text:find('The enemy have come') then
        add_entry(string.format('%s: %s', date, text))
    elseif text:find(' has bestowed the name ') then
        add_entry(string.format('%s: %s', date, text))
    elseif text:find(' has been found dead') then
        add_entry(string.format('%s: %s', date, text))
    elseif text:find('Mission Report') then
        add_entry(string.format('%s: %s', date, text))
    end
end

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
elseif cmd == 'masterworks' then
    local sub = args[2]
    if sub == 'enable' then
        state.log_masterworks = true
    elseif sub == 'disable' then
        state.log_masterworks = false
    else
        print(string.format('Masterwork logging is currently %s.',
            state.log_masterworks and 'enabled' or 'disabled'))
        return
    end
    persist_state()
elseif cmd == 'export' then
    export_chronicle(args[2])
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
    print(help)
end

persist_state()
