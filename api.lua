local MOVE_COST = 100
local FUEL_EFFICIENCY = 10000
tl = {}

local function delay(x)
	return function() return x end
end

local function pointable(stack, node)
	local nodedef = minetest.registered_nodes[node.name]
	local def = minetest.registered_items[stack:get_name()]
	return nodedef and def and (nodedef.pointable or (nodedef.liquidtype ~= "none" and def.liquid_pointable))
end

local function create_turtle_player(turtle_id, dir, only_player)
	local info = turtles.get_turtle_info(turtle_id)
	local inv = turtles.get_turtle_inventory(turtle_id)
	local pitch
	local yaw
	if dir.z > 0 then
		yaw = 0
		pitch = 0
	elseif dir.z < 0 then
		yaw = math.pi
		pitch = 0
	elseif dir.x > 0 then
		yaw = 3*math.pi/2
		pitch = 0
	elseif dir.x < 0 then
		yaw = math.pi/2
		pitch = 0
	elseif dir.y > 0 then
		yaw = 0
		pitch = -math.pi/2
	else
		yaw = 0
		pitch = math.pi/2
	end
	local player = {
		get_inventory_formspec = delay(""), -- TODO
		get_look_dir = delay(vector.new(dir)),
		get_look_pitch = delay(pitch),
		get_look_yaw = delay(yaw),
		get_player_control = delay({jump = false, right = false, left = false, LMB = false, RMB = false, sneak = false, aux1 = false, down = false, up = false}),
		get_player_control_bits = delay(0),
		get_player_name = delay("turtle:" .. tostring(turtle_id)),
		is_player = delay(true),
		is_turtle = true,
		set_inventory_formspec = delay(),
		getpos = function() vector.subtract(info.spos, {x = 0, y = 1.5, z = 0}) end,
		get_hp = delay(20),
		get_inventory = function() return turtles.get_turtle_inventory(turtle_id) end,
		get_wielded_item = function() return turtles.get_turtle_inventory(turtle_id):get_stack("main", info.wield_index or 1) end,
		get_wield_index = function() return info.wield_index or 1 end,
		get_wield_list = delay("main"),
		moveto = delay(), -- TODO
		punch = delay(),
		remove = delay(),
		right_click = delay(), -- TODO
		setpos = delay(), -- TODO
		set_hp = delay(),
		set_properties = delay(),
		set_wielded_item = function(self, item)
			turtles.get_turtle_inventory(turtle_id):set_stack("main", info.wield_index or 1, item)
		end,
		set_animation = delay(),
		set_attach = delay(), -- TODO???
		set_detach = delay(),
		set_bone_position = delay(),
	}
	if only_player then return player end
	local above, under = nil, nil
	local wieldstack = player:get_wielded_item()
	local pos = vector.add(info.spos, dir)
	if pointable(wieldstack, minetest.get_node(pos)) then
		above = vector.new(info.spos)
		under = pos
	elseif pointable(wieldstack, minetest.get_node(vector.add(pos, dir))) then
		above = pos
		under = vector.add(pos, dir)
	else
		for i = 0, 5 do
			local dir2 = directions.side_to_dir(i)
			if vector.dot(dir2, dir) == 0 and pointable(wieldstack, minetest.get_node(vector.add(pos, dir2))) then
				under = vector.add(pos, dir2)
				break
			end
		end
		above = pos
	end
	local pointed_thing = nil
	if under ~= nil then
		pointed_thing = {type = "node", above = above, under = under}
	end
	return player, pointed_thing
end

function tl.select(turtle, cptr, slot)
	if 1 <= slot and slot < turtles.get_turtle_inventory(turtle):get_size("main") then
		turtles.get_turtle_info(turtle).wield_index = slot
	end
end

local function tl_move(turtle, cptr, dir)
	tl.close_form(turtle)
	local info = turtles.get_turtle_info(turtle)
	if info.energy < MOVE_COST then
		cptr.X = 0
		return
	end
	local spos = info.spos
	local npos = vector.add(spos, dir)
	if minetest.get_node(npos).name == "air" then
		minetest.set_node(npos, {name = "turtle:turtle2"})
		info.npos = npos
		info.moving = true
		info.energy = info.energy - MOVE_COST
		cptr.X = u16(-1)
		cptr.paused = true
	else
		cptr.X = 0
	end
end

function tl.forward(turtle, cptr)
	local dir = turtles.get_turtle_info(turtle).dir
	tl_move(turtle, cptr, minetest.facedir_to_dir(dir))
end

function tl.backward(turtle, cptr)
	local dir = turtles.get_turtle_info(turtle).dir
	tl_move(turtle, cptr, vector.multiply(minetest.facedir_to_dir(dir), -1))
end

function tl.up(turtle, cptr)
	tl_move(turtle, cptr, {x = 0, y = 1, z = 0})
end

function tl.down(turtle, cptr)
	tl_move(turtle, cptr, {x = 0, y = -1, z = 0})
end

function tl.turnleft(turtle, cptr)
	tl.close_form(turtle)
	local info = turtles.get_turtle_info(turtle)
	info.ndir = (info.dir + 3) % 4
	info.rotate = math.pi / 2
	info.moving = true
	cptr.paused = true
end

function tl.turnright(turtle, cptr)
	tl.close_form(turtle)
	local info = turtles.get_turtle_info(turtle)
	info.ndir = (info.dir + 1) % 4
	info.rotate = - math.pi / 2
	info.moving = true
	cptr.paused = true
end

local function write_string_at(cptr, addr, str)
	for i = 1, string.len(str) do
		cptr[u16(addr - 1 + i)] = string.byte(str, i)
	end
	cptr.X = string.len(str)
end

local function turtle_detect(turtle, cptr, dir)
	local info = turtles.get_turtle_info(turtle)
	local pos = vector.add(info.spos, dir)
	local name = minetest.get_node(pos).name
	write_string_at(cptr, cptr.X, name)
end

function tl.detect(turtle, cptr)
	local info = turtles.get_turtle_info(turtle)
	turtle_detect(turtle, cptr, minetest.facedir_to_dir(info.dir))
end

function tl.detectup(turtle, cptr)
	turtle_detect(turtle, cptr, {x = 0, y = 1, z = 0})
end

function tl.detectdown(turtle, cptr)
	turtle_detect(turtle, cptr, {x = 0, y = -1, z = 0})
end

local function turtle_dig(turtle, cptr, dir)
	tl.close_form(turtle)
	local player, pointed_thing = create_turtle_player(turtle, dir)
	if pointed_thing == nil then return end
	local info = turtles.get_turtle_info(turtle)
	local wieldstack = player:get_wielded_item()
	local on_use = (minetest.registered_items[wieldstack:get_name()] or {}).on_use
	if on_use then
		player:set_wielded_item(on_use(wieldstack, player, pointed_thing) or wieldstack)
	else
		local pos = info.spos
		local node = minetest.get_node(pos)
		local def = ItemStack({name = node.name}):get_definition()
		local toolcaps = wieldstack:get_tool_capabilities()
		local dp = minetest.get_dig_params(def.groups, toolcaps)
		local dp2 = minetest.get_dig_params(def.groups, ItemStack(""):get_tool_capabilities())
		if (dp.diggable or dp2.diggable) and def.diggable and def.pointable and (not def.can_dig or def.can_dig(pos, player)) and
				(not minetest.is_protected(pos, player:get_player_name())) then
			local on_dig = (minetest.registered_nodes[node.name] or {on_dig = minetest.node_dig}).on_dig
			on_dig(pos, node, player)
		end
	end
end

function tl.dig(turtle, cptr)
	local info = turtles.get_turtle_info(turtle)
	turtle_dig(turtle, cptr, minetest.facedir_to_dir(info.dir))
end

function tl.digup(turtle, cptr)
	turtle_dig(turtle, cptr, {x = 0, y = 1, z = 0})
end

function tl.digdown(turtle, cptr)
	turtle_dig(turtle, cptr, {x = 0, y = -1, z = 0})
end

local function turtle_place(turtle, cptr, dir)
	tl.close_form(turtle)
	local player, pointed_thing = create_turtle_player(turtle, dir)
	if pointed_thing == nil then return end
	local formspec = minetest.get_meta(pointed_thing.under):get_string("formspec")
	if formspec ~= nil then
		local info = turtles.get_turtle_info(turtle)
		info.open_formspec = tl.read_formspec(formspec)
		info.formspec_type = {type = "node", pos = pointed_thing.under}
		info.formspec_fields = {}
		return
	end
	local wieldstack = player:get_wielded_item()
	local on_place = (minetest.registered_items[wieldstack:get_name()] or {on_place = minetest.item_place}).on_place
	player:set_wielded_item(on_place(wieldstack, player, pointed_thing) or wieldstack)
end

function tl.place(turtle, cptr)
	local info = turtles.get_turtle_info(turtle)
	turtle_place(turtle, cptr, minetest.facedir_to_dir(info.dir))
end

function tl.placeup(turtle, cptr)
	turtle_place(turtle, cptr, {x = 0, y = 1, z = 0})
end

function tl.placedown(turtle, cptr)
	turtle_place(turtle, cptr, {x = 0, y = -1, z = 0})
end

local function stack_set_count(stack, count)
	stack = stack:to_table()
	if stack == nil then return nil end
	stack.count = count
	return ItemStack(stack)
end

function tl.refuel(turtle, cptr, slot, nmax)
	local info = turtles.get_turtle_info(turtle)
	local inv = turtles.get_turtle_inventory(turtle)
	local stack = inv:get_stack("main", slot)
	local fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = {stack}})
	if fuel.time <= 0 then
		cptr.X = 0
		return
	end
	local count = math.min(stack:get_count(), nmax)
	local fs = stack:to_table()
	fs.count = 1
	local fstack = ItemStack(fs)
	local fuel, afterfuel
	fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = {fstack}})
	stack:take_item(count)
	if afterfuel ~= nil then
		afterfuel = afterfuel.items[1]
	end
	if afterfuel ~= nil then
		afterfuel = stack_set_count(afterfuel, afterfuel:get_count()*count)
		local leftover = stack:add_item(ItemStack(afterfuel))
		inv:set_stack("main", slot, stack)
		local leftover2 = inv:add_item("main", leftover)
		minetest.add_item(info.spos, leftover2)
	else
		inv:set_stack("main", slot, stack)
	end
	info.energy = info.energy + FUEL_EFFICIENCY * count * fuel.time
	cptr.X = u16(-1)
end

function tl.get_energy(turtle, cptr)
	local info = turtles.get_turtle_info(turtle)
	cptr.Y = u16(info.energy)
	cptr.X = u16(math.floor(info.energy / 0x10000))
end

--------------
-- Formspec --
--------------
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if player:get_player_name():sub(1, 7) == "turtle:" and formname == "turtle:inventory" then
		return true
	end
end)

local function send_fields(turtle)
	local info = turtles.get_turtle_info(turtle)
	local fields = info.formspec_fields
	info.formspec_fields = {}
	if info.formspec_type.type == "show" then
		local dir = minetest.facedir_to_dir(info.dir)
		local player = create_turtle_player(turtle, dir, true)
		for _, func in ipairs(minetest.registered_on_receive_fields) do
			if func(player, info.formspec_type.formname, fields) then
				return
			end
		end
	else
		local pos = info.formspec_type.pos
		local nodedef = minetest.registered_nodes[minetest.get_node(pos).name]
		if nodedef and nodedef.on_receive_fields then
			local dir = vector.normalize(vector.sub(pos, info.spos))
			local player = create_turtle_player(turtle, dir, true)
			nodedef.on_receive_fields(vector.new(pos), "", fields, player)
		end
	end
end

function tl.close_form(turtle)
	local info = turtles.get_turtle_info(turtle)
	if info.formspec_fields then
		info.formspec_fields["quit"] = "true"
		send_fields(turtle)
		info.open_formspec = nil
		info.formspec_type = nil
		info.formspec_fields = nil
	end
end

local function split_str(str, delim)
	local parsed = {}
	local i = 1
	local s = ""
	while i <= string.len(str) do
		if str:sub(i, i) == "\\" then
			s = s .. str:sub(i, i + 1)
			i = i + 2
		elseif str:sub(i, i) == delim then
			parsed[#parsed + 1] = s
			s = ""
			i = i + 1
		else
			s = s .. str:sub(i, i)
			i = i + 1
		end
	end
	parsed[#parsed + 1] = s
	return parsed
end

local function parse_list(lstdef)
	local parsed = split_str(lstdef, ";")
	local psize = split_str(parsed[4], ",")
	if parsed[1] == "current_name" then parsed[1] = "context" end
	return {location = parsed[1], listname = parsed[2],
		size = tonumber(psize[1]) * tonumber(psize[2]),
		start_index = ((parsed[5] and tonumber(parsed[5])) or 0) + 1}
end

local function merge_adjacent_lists(lsts)
	local function merge_at(t, ind)
		if t.starts[ind] and t.ends[ind] then
			t.starts[t.ends[ind]] = t.starts[ind]
			t.ends[t.starts[ind]] = t.ends[ind]
			t.starts[ind] = nil
			t.ends[ind] = nil
		end
	end
	local locs = {}
	for _, lst in ipairs(lsts) do
		local loc = lst.location .. ";" .. lst.listname
		if locs[loc] == nil then
			locs[loc] = {location = lst.location, listname = lst.listname, starts = {}, ends = {}}
		end
		local starti, endi = lst.start_index, lst.start_index + lst.size
		locs[loc].ends[endi] = starti
		locs[loc].starts[starti] = endi
		merge_at(locs[loc], endi)
		merge_at(locs[loc], starti)
	end
	local new = {}
	for _, lst in pairs(locs) do
		for starti, endi in pairs(lst.starts) do
			new[#new + 1] = {location = lst.location, listname = lst.listname, size = endi - starti, start_index = starti}
		end
	end
	return new
end

function tl.read_formspec(formspec)
	local parsed = split_str(formspec, "]")
	local lsts = {}
	for _, item in ipairs(parsed) do
		if item:sub(1, 5) == "list[" then
			lsts[#lsts + 1] = parse_list(item:sub(6, -1))
		end
	end
	return {lists = merge_adjacent_lists(lsts)}
end

local old_show_formspec = minetest.show_formspec
function minetest.show_formspec(playername, formname, formspec)
	if playername:sub(1, 7) == "turtle:" then
		local id = tonumber(playername:sub(8, -1))
		local info = turtles.get_turtle_info(id)
		info.open_formspec = tl.read_formspec(formspec)
		info.formspec_type = {type = "show", formname = formname}
		info.formspec_fields = {}
		return
	end
	old_show_formspec(playername, formname, formspec)
end

function tl.open_inv(turtle, cptr)
	tl.close_form(turtle)
	local info = turtles.get_turtle_info(turtle)
	info.open_formspec = tl.read_formspec(
		"list[current_player;main;0,4.25;8,4;]"..
		"list[current_player;craft;1.75,0.5;3,3;]"..
		"list[current_player;craftpreview;5.75,1.5;1,1;]")
	info.formspec_type = {type = "show", formname = "turtle:inventory"}
end

-- Formspec memory layout
-- +-----+-----+-----+-----+----
-- |     |  Pointer  |     |
-- | Tag |  to next  | ID  | Data
-- |     |  element  |     |
-- +-----+-----+-----+-----+----
-- 
-- For last element (TAG_END), only tag is present

local function push(cptr, addr, value)
	cptr[addr] = bit32.band(value, 0xff)
	cptr[u16(addr + 1)] = bit32.band(math.floor(value/256), 0xff)
	return u16(addr + 2)
end

local function pushC(cptr, addr, value)
	cptr[addr] = bit32.band(value, 0xff)
	return u16(addr + 1)
end

local function push_string(cptr, addr, str)
	for i = 1, string.len(str) do
		cptr[u16(addr - 1 + i)] = string.byte(str, i)
	end
	return u16(addr + string.len(str))
end

local function push_string_counted(cptr, addr, str)
	-- String length (2 bytes)
	-- String contents
	return push_string(cptr, push(cptr, addr, string.len(str)), str)
end

local function push_stack(cptr, addr, stack)
	-- Count (2 bytes)
	-- Wear (2 bytes)
	-- Item name
	return push_string_counted(cptr,
		push(cptr,
		push(cptr, addr,
			stack:get_count()),
			stack:get_wear()),
			stack:get_name())
end

local TAG_END = 0
local TAG_LIST = 1
function tl.get_formspec(turtle, cptr, addr)
	local info = turtles.get_turtle_info(turtle)
	if not info.open_formspec then
		pushC(cptr, addr, TAG_END)
		return
	end
	local i = 0
	for _, lst in ipairs(info.open_formspec.lists) do
		addr = pushC(cptr, addr, TAG_LIST)
		local old_addr = addr
		addr = u16(addr + 2)
		addr = pushC(cptr, addr, i)
		i = i + 1
		addr = push_string_counted(cptr, addr, lst.location)
		addr = push_string_counted(cptr, addr, lst.listname)
		addr = push(cptr, addr, lst.size)
		addr = push(cptr, addr, lst.start_index)
		push(cptr, old_addr, addr) -- Pointer to next element
	end
	pushC(cptr, addr, TAG_END)
end

local function get_element_by_id(formspec, elem_id)
	return formspec.lists[elem_id + 1]
end

local function get_inventory_from_location(turtle, location)
	if location == "current_player" then
		return turtles.get_turtle_inventory(turtle)
	elseif location == "context" then
		local info = turtles.get_turtle_info(turtle)
		local formspec = info.formspec_type
		if formspec and formspec.type == "node" then
			return minetest.get_meta(formspec.pos):get_inventory()
		end
		print("WARNING: tried to access context without open node formspec")
	elseif location:sub(1, 8) == "nodemeta" then
		local p = split_str(location, ":")
		local spos = split_str(p[2], ",")
		local pos = {x = tonumber(spos[1]), y = tonumber(spos[2]), z = tonumber(spos[3])}
		if pos.x and pos.y and pos.z then
			return minetest.get_meta(pos):get_inventory()
		end
		print("WARNING: incorrect nodemeta element: " .. location)
	else
		print("WARNING: unimplemented location type: " .. location)
	end
end

function tl.get_stack(turtle, cptr, elem_id, slot, addr)
	local info = turtles.get_turtle_info(turtle)
	local stack = ItemStack("")
	if info.open_formspec then
		local formspec = info.open_formspec
		local elem = get_element_by_id(formspec, elem_id)
		if elem and elem.location and
				elem.start_index <= slot and slot <= elem.start_index + elem.size then
			local inv = get_inventory_from_location(turtle, elem.location)
			if inv then
				stack = inv:get_stack(elem.listname, slot)
			end
		end
	end
	push_stack(cptr, addr, stack)
end
