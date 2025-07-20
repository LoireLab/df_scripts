-- Allow haulers to pick up multiple nearby items when using bags or wheelbarrows
--@module = true
--@enable = true

local eventful = require('plugins.eventful')
local utils = require('utils')

local GLOBAL_KEY = 'multihaul'

enabled = enabled or false
debug_enabled = debug_enabled or false
radius = radius or 10
max_items = max_items or 10

function isEnabled()
    return enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled=enabled,
        debug_enabled=debug_enabled,
        radius=radius,
        max_items=max_items,
    })
end

local function load_state()
    local data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = data.enabled or false
    debug_enabled = data.debug_enabled or false
    radius = data.radius or 10
    max_items = data.max_items or 10
end

local function add_nearby_items(job)
    if #job.items == 0 then return end

    local target = job.items[0].item
    if not target then return end
    local x,y,z = dfhack.items.getPosition(target)
    if not x then return end

    local count = 0
    for _,it in ipairs(df.global.world.items.other.IN_PLAY) do
        if it ~= target and not it.flags.in_job and it.flags.on_ground and it.pos.z == z and math.abs(it.pos.x - x) <= radius and math.abs(it.pos.y - y) <= radius then
            dfhack.job.attachJobItem(job, it, df.job_role_type.Hauled, -1, -1)
            count = count + 1
            if debug_enabled then
                dfhack.gui.showAnnouncement(
                    ('multihaul: added %s to hauling job'):format(
                        dfhack.items.getDescription(it, 0)),
                    COLOR_CYAN)
            end
            if count >= max_items then break end
        end
    end
    if debug_enabled and count > 0 then
        dfhack.gui.showAnnouncement(('multihaul: added %d item(s) nearby'):format(count),COLOR_CYAN)
    end
end

local function on_new_job(job)
	if job.job_type ~= df.job_type.StoreItemInStockpile then return end
    add_nearby_items(job)
	for _,jitem in ipairs(job.items) do
        if jitem.item and (dfhack.items.getCapacity(jitem.item)>0) then
            container = jitem.item
            break
        end
    end
    if not container then return 
	else emptyContainedItems(container) 
	end
end

local function emptyContainedItems(wheelbarrow)
    local items = dfhack.items.getContainedItems(wheelbarrow)
    if #items == 0 then return end
    e_count = e_count + 1
    for _,item in ipairs(items) do
        if not dryrun then
            if item.flags.in_job then
                local job_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
                if job_ref then
                    dfhack.job.removeJob(job_ref.data.job)
                end
            end
            dfhack.items.moveToGround(item, wheelbarrow.pos)
        end
        i_count = i_count + 1
    end
end

local function enable(state)
    enabled = state
    if enabled then
        eventful.onJobInitiated[GLOBAL_KEY] = on_new_job
    else
        eventful.onJobInitiated[GLOBAL_KEY] = nil
    end
    persist_state()
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {on_new_job=on_new_job, enable=enable,  load_state=load_state}
end

-- state change handler

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        eventful.onJobInitiated[GLOBAL_KEY] = nil
        return
    end
    if sc == SC_MAP_LOADED then
        load_state()
        if enabled then
            eventful.onJobInitiated[GLOBAL_KEY] = on_new_job
        end
    end
end

if dfhack_flags.module then
    return
end

local args = {...}
if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        enable(true)
    else
        enable(false)
    end
    return
end

local function parse_options(start_idx)
    local i = start_idx
    while i <= #args do
        local a = args[i]
        if a == '--debug' then
            debug_enabled = true
        elseif a == '--no-debug' then
            debug_enabled = false
        elseif a == '--radius' then
            i = i + 1
            radius = tonumber(args[i]) or radius
                elseif a == '--max-items' then
            i = i + 1
            max_items = tonumber(args[i]) or max_items
        end
        i = i + 1
    end
end

local cmd = args[1]
if cmd == 'enable' then
    parse_options(2)
    enable(true)
elseif cmd == 'disable' then
    enable(false)
elseif cmd == 'status' or not cmd then
    print((enabled and 'multihaul is enabled' or 'multihaul is disabled'))
    print(('radius=%d max-items=%d debug=%s')
          :format(radius, max_items, debug_enabled and 'on' or 'off'))
elseif cmd == 'config' then
    parse_options(2)
    persist_state()
    print(('multihaul config: radius=%d max-items=%d debug=%s')
          :format(radius, max_items, debug_enabled and 'on' or 'off'))
else
    qerror('Usage: multihaul [enable|disable|status|config] [--radius N] [--max-items N] [--debug|--no-debug]')
end
