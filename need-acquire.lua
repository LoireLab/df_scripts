-- need-acquire.lua
-- ver 0.9
-- Assign existing Trinkets to Citizen for them to collect
-- to fulfill their Acquire Object Need.
--

local utils=require('utils')

validArgs = utils.invert({
    'help',
    't'
})
local args = utils.processArgs({...}, validArgs)
local aquire_need_id = 20 
local aquire_threshold = -1000
local helpme = [===[
Assign existing trinkets to citizen for them to collect,
to fulfill their "Acquire Object" Need.
This does not simple change the need.
You need the have the Trinkets in your fortress and the dwarfs will
go and collect their new Items.
Setup:
	-An stockpile full of trinkets 
arguments:
    -t
        Expects an integer value.
        The negativ need  threshhold to trigger for each citizen
        Default is 3000
    -help 
        Display this text
]===] 


--######
--Helper
--######

function getAllCititzen()
local citizen = {}
local my_civ = df.global.world.world_data.active_site[0].entity_links[0].entity_id
for n, unit in ipairs(df.global.world.units.all) do
        if unit.civ_id == my_civ and dfhack.units.isCitizen(unit) then
            if unit.profession ~= df.profession.BABY and unit.profession ~= df.profession.CHILD then
                table.insert(citizen, unit)
            end
        end
end
return citizen
end
local citizen = getAllCititzen()

function findNeed(unit,need_id) 
    local needs =  unit.status.current_soul.personality.needs
    local need_index = -1
    for k = #needs-1,0,-1 do
        if needs[k].id == need_id then
            need_index = k
            break
        end
    end    
	if (need_index ~= -1 ) then 
        return needs[need_index]
    end
    return nil
end

--######
--Main
--######


function getFreeTrinkets() 
    -- Where are the items that we can we give away?
    local item_count = 0
    local aquire_item_list =  {}
    local trinket_list =  {}
    for _, i in ipairs(df.global.world.items.other.EARRING) do
        table.insert(trinket_list,i)
    end
    for _, i in ipairs(df.global.world.items.other.RING) do
        table.insert(trinket_list,i)
    end
    for _, i in ipairs(df.global.world.items.other.AMULET) do
        table.insert(trinket_list,i)
    end
    for _, i in ipairs(df.global.world.items.other.BRACELET) do
        table.insert(trinket_list,i)
    end
    for _, i in ipairs(trinket_list) do
        if ( not i.flags.trader and
            not i.flags.in_job and
            not i.flags.construction and
            not i.flags.removed and
            not i.flags.forbid and
            not i.flags.dump and
            not i.flags.owned) then
                        item_count = item_count+1
                        table.insert(aquire_item_list,i)    
                --end
        end
    end    
    return aquire_item_list
end


function giveItems() 
    local aquire_item_list = getFreeTrinkets()
    --WHo needs to acquire new Item real bad?
    local aquire_count = 0
    local missing_item_count = 0
    local fullfilled_count = 0
    for i, unit in ipairs(citizen) do
        -- Find local need
        local need = findNeed(unit,aquire_need_id)
        if (need ~= nil ) then  
        if ( need.focus_level  < aquire_threshold ) then
            aquire_count = aquire_count+1        
            if ( aquire_item_list[aquire_count] ~= nill) then
                fullfilled_count = fullfilled_count+1
                dfhack.items.setOwner(aquire_item_list[aquire_count],unit)    
                need.focus_level = 200
                need.need_level = 1
            else  
                missing_item_count = missing_item_count+1
            end
        end
        end
    end
    dfhack.print("need-acquire  | Need: ".. aquire_count )
    dfhack.print(" Done: ".. fullfilled_count )
    dfhack.println(" TODO: ".. missing_item_count )
    if (missing_item_count > 0) then
        dfhack.print("need-acquire  | ")
        dfhack.printerr("Need " .. missing_item_count .. " more Trinkets to fulfill needs!")
    return 
    end                    
end

if (args.help) then
    print(helpme)
    return
end

if (args.t) then
    aquire_threshold = 0-tonumber(args.t)
end

giveItems()