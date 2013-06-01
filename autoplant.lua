-- To enable leaf decay for a node, add it to the "autoplant" group.
--
-- The rating of the group determines how far from a node in the group "tree"
-- the node can be without decaying.
--
-- If param2 of the node is ~= 0, the node will always be preserved. Thus, if
-- the player places a node of that kind, you will want to set param2=1 or so.


local entity

-- registered
local registered = function(case,name)
	local params = {}
	local list
	if case == "item" then list = minetest.registered_items end
	if case == "node" then list = minetest.registered_nodes end
	if case == "craftitem" then list = minetest.registered_craftitems end
	if case == "tool" then list = minetest.registered_tools end
	if case == "entity" then list = minetest.registered_entities end
	if list then
		for k,v in pairs(list[name]) do
			params[k] = v
		end
	end
	return params
end

-- default leaves
entity = registered("node","default:leaves")
entity.groups = {snappy=3, autoplant=3, flammable=2, leaves=1}
minetest.register_node(":default:leaves", entity)

--[[
-- jungle leaves
entity = registered("node","default:jungleleaves")
entity.groups = {snappy=3, autoplant=3, flammable=2, leaves=1},
minetest.register_node(":default:jungleleaves", entity)
--]]

-- jungle leaves
minetest.register_node(":default:jungleleaves", {
	description = "Jungle Leaves",
	drawtype = "allfaces_optional",
	visual_scale = 1.3,
	tiles = {"default_jungleleaves.png"},
	paramtype = "light",
	groups = {snappy=3, autoplant=3, flammable=2, leaves=1},
	drop = {
		max_items = 1,
		items = {
			{
				-- player will get sapling with 1/20 chance
				items = {'default:junglesapling'},
				rarity = 20,
			},
			{
				-- player will get leaves only if he get no saplings,
				-- this is because max_items is 1
				items = {'default:jungleleaves'},
			}
		}
	},
	sounds = default.node_sound_leaves_defaults(),
})

--[[
-- conifers leaves
local leavedecay_group = minetest.get_item_group("conifers:leaves", "leavedecay")
if leavedecay_group ~= 0 and leavedecay_group ~= nil then
	local autoplant_group = "autoplant="..leavedecay_group..""
	entity.groups = {snappy=3, autoplant_group, flammable=2}
	entity = registered("node","conifers:leaves")
	minetest.register_node(":conifers:leaves", entity)
end
	
-- conifers leaves
local leavedecay_group = minetest.get_item_group("conifers:leaves_special", "leavedecay")
if leavedecay_group ~= 0 and leavedecay_group ~= nil then
	local autoplant_group = "autoplant="..leavedecay_group..""
	entity.groups = {snappy=3, autoplant_group, flammable=2}
	entity = registered("node","conifers:leaves_special")
	minetest.register_node(":conifers:leaves_special", entity)
end
--]]

-- default saplings
minetest.register_abm({
	nodenames = {"default:sapling", "default:junglesapling"},
	interval = 3,
	chance = 5,
	action = function(pos)
		pos.y=pos.y-1
		if minetest.env:get_node(pos).name ~= "default:dirt" and minetest.env:get_node(pos).name ~= "default:dirt_with_grass" then
			pos.y = pos.y+1
			minetest.env:add_node(pos, {name="air"})
		end
	end,
})

minetest.register_abm({
	nodenames = {"default:sapling", "default:junglesapling"},
	neighbors = {"default:sapling", "default:tree", "default:junglesapling", "default:jungletree"},
	interval = 3,
	chance = 5,
	action = function(pos)
		minetest.env:add_node(pos, {name="air"})
	end,
})



-- leavedecay

autoplant_trunk_cache = {}
autoplant_enable_cache = true
-- Spread the load of finding trunks
autoplant_trunk_find_allow_accumulator = 0

minetest.register_globalstep(function(dtime)
	local finds_per_second = 5000
	autoplant_trunk_find_allow_accumulator =
			math.floor(dtime * finds_per_second)
end)

minetest.register_abm({
	nodenames = {"group:autoplant"},
	neighbors = {"air", "group:liquid"},
	-- A low interval and a high inverse chance spreads the load
	interval = 2,
	chance = 5,

	action = function(p0, node, _, _)
		--print("autoplant ABM at "..p0.x..", "..p0.y..", "..p0.z..")")
		local do_preserve = false
		local d = minetest.registered_nodes[node.name].groups.autoplant
		if not d or d == 0 then
			--print("not groups.autoplant")
			return
		end
		local n0 = minetest.env:get_node(p0)
		if n0.param2 ~= 0 then
			--print("param2 ~= 0")
			return
		end
		local p0_hash = nil
		if autoplant_enable_cache then
			p0_hash = minetest.hash_node_position(p0)
			local trunkp = autoplant_trunk_cache[p0_hash]
			if trunkp then
				local n = minetest.env:get_node(trunkp)
				local reg = minetest.registered_nodes[n.name]
				-- Assume ignore is a trunk, to make the thing work at the border of the active area
				if n.name == "ignore" or (reg.groups.tree and reg.groups.tree ~= 0) then
					--print("cached trunk still exists")
					return
				end
				--print("cached trunk is invalid")
				-- Cache is invalid
				table.remove(autoplant_trunk_cache, p0_hash)
			end
		end
		if autoplant_trunk_find_allow_accumulator <= 0 then
			return
		end
		autoplant_trunk_find_allow_accumulator =
				autoplant_trunk_find_allow_accumulator - 1
		-- Assume ignore is a trunk, to make the thing work at the border of the active area
		local p1 = minetest.env:find_node_near(p0, d, {"ignore", "group:tree"})
		if p1 then
			do_preserve = true
			if autoplant_enable_cache then
				--print("caching trunk")
				-- Cache the trunk
				autoplant_trunk_cache[p0_hash] = p1
			end
		end
		if not do_preserve then
			-- Drop stuff other than the node itself
			itemstacks = minetest.get_node_drops(n0.name)
			for _, itemname in ipairs(itemstacks) do
				if itemname ~= n0.name then
					local p_drop = {
						x = math.floor(p0.x + 0.5),
						y = math.floor(p0.y + 0.5),
						z = math.floor(p0.z + 0.5),
					}
--					minetest.env:add_item(p_drop, itemname)
					spawn_falling_node(p_drop, itemname)
				end
			end
			-- Remove node
			minetest.env:remove_node(p0)
		end
	end
})
