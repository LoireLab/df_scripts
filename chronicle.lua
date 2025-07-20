-- Chronicles fortress events: unit deaths, item creation, and invasions
--@module = true

local eventful = require('plugins.eventful')
local utils = require('utils')

-- ensure our random choices vary between runs
math.randomseed(os.time())

local help = [====[
chronicle
========

Chronicles fortress events: unit deaths, item creation, and invasions

Usage:
    chronicle enable
    chronicle disable

    chronicle [print] - prints 25 last recorded events
        chronicle print [number] - prints last [number] recorded events
        chronicle long - prints the full chronicle
        chronicle export - saves current chronicle to a txt file
        chronicle clear - erases current chronicle (DANGER)
        chronicle view - shows the full chronicle in a scrollable window

    chronicle summary - shows how much items were produced per category in each year

    chronicle masterworks [enable|disable] - enables or disables logging of masterwork creation announcements
]====]

local GLOBAL_KEY = 'chronicle'
local MAX_LOG_CHARS = 2^15 -- trim chronicle to most recent ~32KB of text
local FULL_LOG_PATH = dfhack.getSavePath() .. '/chronicle_full.txt'

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

local function escape_pattern(str)
    return str:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
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

local function read_external_entries()
    local f = io.open(FULL_LOG_PATH, 'r')
    if not f then return {} end
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    return lines
end

local function get_full_entries()
    local entries = read_external_entries()
    for _,e in ipairs(state.entries) do table.insert(entries, e) end
    return entries
end

local function trim_entries()
    local total = 0
    local start_idx = #state.entries
    while start_idx > 0 and total <= MAX_LOG_CHARS do
        total = total + #state.entries[start_idx] + 1
        start_idx = start_idx - 1
    end
    if start_idx > 0 then
        local old = {}
        for i=1,start_idx do table.insert(old, table.remove(state.entries, 1)) end
        local ok, f = pcall(io.open, FULL_LOG_PATH, 'a')
        if ok and f then
            for _,e in ipairs(old) do f:write(e, '\n') end
            f:close()
        else
            qerror('Cannot open file for writing: ' .. FULL_LOG_PATH)
        end
    end
end

local function add_entry(text)
    table.insert(state.entries, sanitize(text))
    trim_entries()
    persist_state()
end

local function export_chronicle(path)
    path = path or (dfhack.getSavePath() .. '/chronicle.txt')
    local ok, f = pcall(io.open, path, 'w')
    if not ok or not f then
        qerror('Cannot open file for writing: ' .. path)
    end
    for _,entry in ipairs(read_external_entries()) do
        f:write(entry, '\n')
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
        local pattern = escape_pattern(unit.name.first_name)
        name = name:gsub(pattern, unit.name.first_name .. ' "' .. unit.name.nickname .. '"', 1)
    end
    return name
end

local FORT_DEATH_NO_KILLER = {
    '%s has tragically died',
    '%s met an untimely end',
    '%s perished in sorrow'
}

local FORT_DEATH_WITH_KILLER = {
    '%s was murdered by %s',
    '%s fell victim to %s',
    '%s was slain by %s'
}

local ENEMY_DEATH_WITH_KILLER = {
    '%s granted a glorious death to %s',
    '%s dispatched the wretched %s',
    '%s vanquished pitiful %s'
}

local ENEMY_DEATH_NO_KILLER = {
    '%s met their demise',
    '%s found their end',
    '%s succumbed to death'
}

local function random_choice(tbl)
    return tbl[math.random(#tbl)]
end

local function format_death_text(unit)
    local victim = describe_unit(unit)
    local incident = df.incident.find(unit.counters.death_id)
    local killer
    if incident and incident.criminal then
        killer = df.unit.find(incident.criminal)
    end

    if dfhack.units.isFortControlled(unit) then
        if killer then
            local killer_name = describe_unit(killer)
            return string.format(random_choice(FORT_DEATH_WITH_KILLER), victim, killer_name)
        else
            return string.format(random_choice(FORT_DEATH_NO_KILLER), victim)
        end
    elseif dfhack.units.isInvader(unit) then
        if killer then
            local killer_name = describe_unit(killer)
            return string.format(random_choice(ENEMY_DEATH_WITH_KILLER), killer_name, victim)
        else
            return string.format(random_choice(ENEMY_DEATH_NO_KILLER), victim)
        end
    else
        local str = (unit.name.has_name and '' or 'The ') .. victim
        str = str .. ' ' .. death_string(unit.counters.death_cause)
        if killer then
            str = str .. (', killed by the %s'):format(get_race_name(killer.race))
            if killer.name.has_name then
                str = str .. (' %s'):format(dfhack.translation.translateName(dfhack.units.getVisibleName(killer)))
            end
        end
        return str
    end
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

local ANNOUNCEMENT_PATTERNS = {
    'the enemy have come',
    'a vile force of darkness has arrived',
    'an ambush',
    'snatcher',
    'thief',
    ' has bestowed the name ',
    ' has been found dead',
    'you have ',
    ' has come',
    ' upon you',
    ' it is ',
    ' is visiting',
}

local function get_category(item)
    local t = df.item_type[item:getType()]
    return CATEGORY_MAP[t] or 'other'
end

local function on_unit_death(unit_id)
    local unit = df.unit.find(unit_id)
    if not unit then return end
    if dfhack.units.isWildlife(unit) then return end
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
        if text:find(' offers it to ') or text:find(' claims it ') then
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

    for _,pattern in ipairs(ANNOUNCEMENT_PATTERNS) do
        if text:lower():find(pattern) then
            local date = format_date(df.global.cur_year, df.global.cur_year_tick)
            local msg = transform_notification(text)
            add_entry(string.format('%s: %s', date, msg))
            break
        end
    end
end

local function transform_notification(text)
    -- "You have " >> "Dwarves have "
    if text:sub(1, 9) == "You have " then
        text = "Dwarves have " .. text:sub(10)
    end

    -- "Now you will know why you fear the night." >> "Gods have mercy!"
    text = text:gsub("Now you will know why you fear the night%.", "Gods have mercy!")

    return text
end

local function do_enable()
    state.enabled = true
    eventful.enableEvent(eventful.eventType.ITEM_CREATED, 10)
    eventful.enableEvent(eventful.eventType.INVASION, 10)
    eventful.enableEvent(eventful.eventType.REPORT, 10)
    eventful.enableEvent(eventful.eventType.UNIT_DEATH, 10)
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

local function main(args)
    if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
        qerror('chronicle requires a loaded fortress map')
    end

    load_state()
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
    elseif cmd == 'long' then
        local entries = get_full_entries()
        if #entries == 0 then
            print('Chronicle is empty.')
        else
            for _,entry in ipairs(entries) do print(entry) end
        end
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
    elseif cmd == 'view' then
        if #get_full_entries() == 0 then
            print('Chronicle is empty.')
        else
            reqscript('gui/chronicle').show()
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
end

if not dfhack_flags.module then
    main({...})
end
