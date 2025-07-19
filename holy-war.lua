-- Trigger wars based on conflicts between deity spheres
--@ module = true

local utils = require('utils')

local help = [====[
holy-war
========

Provoke wars with civilizations that do not share deity spheres with
your civilization or the temples in your fortress. Religious
persecution grudges in the historical record also trigger war.

Usage:
    holy-war [--dry-run]

If ``--dry-run`` is specified, no diplomatic changes are made and a list of
potential targets is printed instead.
]====]

local valid_args = utils.invert({ 'dry-run', 'help' })

local RELIGIOUS_PERSECUTION_GRUDGE =
    df.vague_relationship_type.RELIGIOUS_PERSECUTION_GRUDGE or
    df.vague_relationship_type.religious_persecution_grudge

local function merge(dst, src)
    for k in pairs(src) do dst[k] = true end
end

local function get_deity_spheres(hfid)
    local spheres = {}
    local hf = df.historical_figure.find(hfid)
    if hf and hf.info and hf.info.metaphysical then
        for _, sph in ipairs(hf.info.metaphysical.spheres) do
            spheres[sph] = true
        end
    end
    return spheres
end

local function get_civ_spheres(civ)
    local spheres = {}
    for _, deity_id in ipairs(civ.relations.deities) do
        merge(spheres, get_deity_spheres(deity_id))
    end
    return spheres
end

local function get_fort_spheres()
    local spheres = {}
    for _, bld in ipairs(df.global.world.buildings.all) do
        if bld:getType() == df.building_type.Temple then
            local dtype = bld.deity_type
            if dtype == df.religious_practice_type.WORSHIP_HFID then
                merge(spheres, get_deity_spheres(bld.deity_data.HFID))
            elseif dtype == df.religious_practice_type.RELIGION_ENID then
                local rciv = df.historical_entity.find(bld.deity_data.Religion)
                if rciv then merge(spheres, get_civ_spheres(rciv)) end
            end
        end
    end
    return spheres
end

local function union(a, b)
    local u = {}
    merge(u, a)
    merge(u, b)
    return u
end

local function share(p1, p2)
    for k in pairs(p1) do
        if p2[k] then return true end
    end
    return false
end

local function get_civ_hists(civ)
    local hfs = {}
    for _, id in ipairs(civ.histfig_ids) do hfs[id] = true end
    return hfs
end

local function has_religious_grudge(p_hfs, t_hfs)
    if not RELIGIOUS_PERSECUTION_GRUDGE then return false end
    for _, set in ipairs(df.global.world.history.relationship_events) do
        for i = 0, set.next_element-1 do
            if set.relationship[i] == RELIGIOUS_PERSECUTION_GRUDGE then
                local src = set.source_hf[i]
                local tgt = set.target_hf[i]
                if (p_hfs[src] and t_hfs[tgt]) or (p_hfs[tgt] and t_hfs[src]) then
                    return true
                end
            end
        end
    end
    return false
end

local function change_relation(target, relation)
    local pciv = df.historical_entity.find(df.global.plotinfo.civ_id)
    for _, state in ipairs(pciv.relations.diplomacy.state) do
        if state.group_id == target.id then
            state.relation = relation
        end
    end
    for _, state in ipairs(target.relations.diplomacy.state) do
        if state.group_id == pciv.id then
            state.relation = relation
        end
    end
end

local function main(...)
    local args = utils.processArgs({...}, valid_args)

    if args.help then
        print(help)
        return
    end

    local dry_run = args['dry-run']
    local pciv = df.historical_entity.find(df.global.plotinfo.civ_id)
    local player_spheres = union(get_civ_spheres(pciv), get_fort_spheres())
    local player_hfs = get_civ_hists(pciv)

    for _, civ in ipairs(df.global.world.entities.all) do
        if civ.type == 0 and civ.id ~= pciv.id then
            local p_status
            for _, state in ipairs(pciv.relations.diplomacy.state) do
                if state.group_id == civ.id then
                    p_status = state.relation
                    break
                end
            end
            local c_status
            for _, state in ipairs(civ.relations.diplomacy.state) do
                if state.group_id == pciv.id then
                    c_status = state.relation
                    break
                end
            end
            if p_status ~= 1 or c_status ~= 1 then -- not already mutually at war
                local civ_spheres = get_civ_spheres(civ)
                local civ_hfs = get_civ_hists(civ)
                if not share(player_spheres, civ_spheres) or
                        has_religious_grudge(player_hfs, civ_hfs) then
                    local name = dfhack.translation.translateName(civ.name, true)
                    if dry_run then
                        print(('Would declare war on %s over divine conflict.'):format(name))
                    else
                        change_relation(civ, 1) -- war
                        dfhack.gui.showAnnouncement(
                            ('Religious persecution sparks war with %s!'):format(name),
                            COLOR_RED, true)
                    end
                end
            end
        end
    end
end

if not dfhack_flags.module then
    main(...)
end
