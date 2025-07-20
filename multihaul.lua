-- Allow haulers to pick up multiple nearby items when using bags or wheelbarrows
--@module = true
--@enable = true

local eventful = require('plugins.eventful')

local GLOBAL_KEY = 'multihaul'

enabled = enabled or false

function isEnabled()
    return enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {enabled=enabled})
end

local function load_state()
    local data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = data.enabled or false
end

local function add_nearby_items(job)
    if #job.items == 0 then return end
    local container
    for _,jitem in ipairs(job.items) do
        if jitem.item and (jitem.item:isWheelbarrow() or (jitem.item.flags.container and jitem.item:isBag())) then
            container = jitem.item
            break
        end
    end
    if not container then return end

    local target = job.items[0].item
    if not target then return end
    local x,y,z = dfhack.items.getPosition(target)
    if not x then return end

    local count = 0
    for _,it in ipairs(df.global.world.items.other.IN_PLAY) do
        if it ~= target and not it.flags.in_job and it.flags.on_ground and it.pos.z == z and math.abs(it.pos.x - x) <= 1 and math.abs(it.pos.y - y) <= 1 then
            dfhack.job.attachJobItem(job, it, df.job_role_type.Reagent, -1, -1)
            count = count + 1
            if count >= 4 then break end
        end
    end
end

local function on_new_job(job)
    if job.job_type ~= df.job_type.StoreItemInStockpile then return end
    add_nearby_items(job)
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
    unit_test_hooks = {on_new_job=on_new_job, enable=enable, load_state=load_state}
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

local cmd = args[1]
if cmd == 'enable' then
    enable(true)
elseif cmd == 'disable' then
    enable(false)
elseif cmd == 'status' or not cmd then
    print(enabled and 'multihaul is enabled' or 'multihaul is disabled')
else
    qerror('Usage: multihaul [enable|disable|status]')
end
