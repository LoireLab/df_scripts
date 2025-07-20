-- Stack severed body parts into piles that can be stored in containers
--@module = true
--[====[
stack-bodyparts
===============
Makes teeth and other body parts stackable so they can be gathered in bins or bags.
Running this tool will also combine existing parts in stockpiles.
]====]

local argparse = require('argparse')

local opts, args = {help=false, here=false, dry_run=false}, {...}
argparse.processArgsGetopt(args, {
    {'h', 'help', handler=function() opts.help=true end},
    {nil, 'here', handler=function() opts.here=true end},
    {nil, 'dry-run', handler=function() opts.dry_run=true end},
})

if opts.help then
    print(dfhack.script_help())
    return
end

-- mark corpse pieces as stackable
local cp_attr = df.item_type.attrs[df.item_type.CORPSEPIECE]
if not cp_attr.is_stackable then
    cp_attr.is_stackable = true
end

-- run combine to merge existing parts
local cmd = {'combine', opts.here and 'here' or 'all', '--types=parts'}
if opts.dry_run then table.insert(cmd, '--dry-run') end

if dfhack.isMapLoaded() and df.global.gamemode == df.game_mode.DWARF then
    dfhack.run_command(table.unpack(cmd))
end
