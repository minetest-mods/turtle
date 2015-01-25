local MOVE_COST = 100
local FUEL_EFFICIENCY = 10000
tl = {}

local function delay(x)
	return function() return x end
end

local function create_turtle_player(turtle_id, dir)
	local info = turtles.get_turtle_info(turtle_id)
	local inv = turtles.get_turtle_inventory(turtle_id)
	local under_pos = vector.add(info.spos, dir)
	local above_pos = vector.add(under_pos, dir)
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
	local pointed_thing = {type = "node", under = under_pos, above = above_pos}
	return player, pointed_thing
end

function tl.select(turtle, cptr, slot)
	if 1 <= slot and slot < turtles.get_turtle_inventory(turtle):get_size("main") then
		turtles.get_turtle_info(turtle).wield_index = slot
	end
end

local function tl_move(turtle, cptr, dir)
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
	local info = turtles.get_turtle_info(turtle)
	info.ndir = (info.dir + 3) % 4
	info.rotate = math.pi / 2
	info.moving = true
	cptr.paused = true
end

function tl.turnright(turtle, cptr)
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
	local player, pointed_thing = create_turtle_player(turtle, dir)
	local wieldstack = player:get_wielded_item()
	local on_use = (minetest.registered_items[wieldstack:get_name()] or {}).on_use
	if on_use then
		player:set_wielded_item(on_use(wieldstack, player, pointed_thing) or wieldstack)
	else
		local pos = pointed_thing.under
		local node = minetest.get_node(pos)
		local def = ItemStack({name = node.name}):get_definition()
		local toolcaps = wieldstack:get_tool_capabilities()
		local dp = minetest.get_dig_params(def.groups, toolcaps)
		if dp.diggable and def.diggable and (not def.can_dig or def.can_dig(pos, player)) and
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
	local player, pointed_thing = create_turtle_player(turtle, dir)
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
