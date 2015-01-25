local MOVE_COST = 100
local FUEL_EFFICIENCY = 300
tl = {}

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
	-- TODO
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

local function turtle_place(turtle, cptr, dir, slot)
	-- TODO
end

function tl.place(turtle, cptr, slot)
	local info = turtles.get_turtle_info(turtle)
	turtle_place(turtle, cptr, minetest.facedir_to_dir(info.dir), slot)
end

function tl.placeup(turtle, cptr, slot)
	turtle_place(turtle, cptr, {x = 0, y = 1, z = 0}, slot)
end

function tl.placedown(turtle, cptr, slot)
	turtle_place(turtle, cptr, {x = 0, y = -1, z = 0}, slot)
end

local function stack_set_count(stack, count)
	stack = stack:to_table()
	if stack == nil then return nil end
	stack.count = count
	return ItemStack(stack)
end

function tl.refuel(turtle, cptr, slot, nmax)
	-- TODO: update that
	local info = turtles.get_turtle_info(turtle)
	info.energy = info.energy + 100 * MOVE_COST
	--[[local info = get_turtle_info(turtle)
	local stack = turtle_invs:get_stack(turtle, slot)
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
	end
	if afterfuel ~= nil then
		local leftover = stack:add_item(ItemStack(afterfuel))
		turtle_invs:set_stack(turtle, slot, stack)
		local leftover2 = turtle_invs:add_item(turtle, leftover)
		minetest.add_item(info.spos,leftover2)
	else
		turtle_invs:set_stack(turtle, slot, stack)
	end
	info.fuel = info.fuel+FUEL_EFFICIENCY*count*fuel.time
	cptr.X = u16(FUEL_EFFICIENCY*count*fuel.time)]]
end
