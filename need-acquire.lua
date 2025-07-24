-- Assign trinkets to citizens so they can satisfy the "Acquire Object" need.
-- Derived from github.com/skeldark/scripts and updated for modern DFHack.
--@module = true

local help = [=[
need-acquire
============
Assign trinkets to citizens who have a strong "Acquire Object" need.

Usage:
    need-acquire [-t <focus_threshold>]

Options:
    -t <threshold>  Focus level below which the need is considered unmet
                    (default: -3000).
    -help           Show this help text.
]=]

local utils = require('utils')

local valid_args = utils.invert{'help', 't'}

local ACQUIRE_NEED_ID = df.need_type.AcquireObject
local acquire_threshold = -3000

local function get_citizens()
    local result = {}
    for _, unit in ipairs(dfhack.units.getCitizens(true)) do
        if unit.profession ~= df.profession.BABY and
                unit.profession ~= df.profession.CHILD then
            table.insert(result, unit)
        end
    end
    return result
end

local function find_need(unit, need_id)
    if not unit.status.current_soul then return nil end
    local needs = unit.status.current_soul.personality.needs
    for idx = #needs - 1, 0, -1 do
        if needs[idx].id == need_id then
            return needs[idx]
        end
    end
end

local function get_free_trinkets()
    local trinkets = {}
    local function add(list) for _, i in ipairs(list) do table.insert(trinkets, i) end end
    add(df.global.world.items.other.EARRING)
    add(df.global.world.items.other.RING)
    add(df.global.world.items.other.AMULET)
    add(df.global.world.items.other.BRACELET)
    local free = {}
    for _, item in ipairs(trinkets) do
        if not (item.flags.trader or item.flags.in_job or item.flags.construction or
                item.flags.removed or item.flags.forbid or item.flags.dump or
                item.flags.owned) then
            table.insert(free, item)
        end
    end
    return free
end

local function give_items()
    local trinkets = get_free_trinkets()
    local needs, fulfilled = 0, 0
    local idx = 1
    for _, unit in ipairs(get_citizens()) do
        local need = find_need(unit, ACQUIRE_NEED_ID)
        if need and need.focus_level < acquire_threshold then
            needs = needs + 1
            local item = trinkets[idx]
            if item then
                dfhack.items.setOwner(item, unit)
                need.focus_level = 200
                need.need_level = 1
                fulfilled = fulfilled + 1
                idx = idx + 1
            end
        end
    end
    local missing = needs - fulfilled
    dfhack.println(('need-acquire | Need: %d Done: %d TODO: %d'):format(needs, fulfilled, missing))
    if missing > 0 then
        dfhack.printerr('Need ' .. missing .. ' more trinkets to fulfill needs!')
    end
end

local function main(args)
    args = utils.processArgs(args, valid_args)
    if args.help then
        print(help)
        return
    end
    if args.t then
        acquire_threshold = -tonumber(args.t)
    end
    give_items()
end

if not dfhack_flags.module then
    main({...})
end

