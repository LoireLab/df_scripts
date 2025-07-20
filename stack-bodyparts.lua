-- Make teeth and other body parts stackable
--@module=true
--@enable=true

local argparse = require('argparse')
local utils = require('utils')

local GLOBAL_KEY = 'stack-bodyparts'

enabled = enabled or false
local attr = df.item_type.attrs[df.item_type.CORPSEPIECE]
orig_stackable = orig_stackable or attr.is_stackable

function isEnabled()
    return enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {enabled=enabled})
end

local function load_state()
    local data = dfhack.persistent.getSiteData(GLOBAL_KEY, {enabled=false})
    enabled = data.enabled
end

local function apply_patch()
    attr.is_stackable = true
end

local function remove_patch()
    attr.is_stackable = orig_stackable
end

local function enable(state)
    enabled = state
    if state then
        apply_patch()
    else
        remove_patch()
    end
    persist_state()
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_LOADED then
        load_state()
        if enabled then
            apply_patch()
        end
    elseif sc == SC_MAP_UNLOADED then
        remove_patch()
    end
end

if dfhack_flags.module then
    return
end

if dfhack_flags.enable then
    enable(dfhack_flags.enable_state)
    return
end

if not dfhack.isMapLoaded() then
    qerror('stack-bodyparts requires a loaded map to run')
end

local args = {...}
local cmd = args[1]
if cmd == 'enable' then
    enable(true)
elseif cmd == 'disable' then
    enable(false)
elseif not cmd or cmd == 'status' then
    print(('stack-bodyparts is %s.'):format(enabled and 'enabled' or 'disabled'))
else
    print(dfhack.script_help())
end
