local FUEL_EFFICIENCY = 3	-- How many moves can the turtle do with a second of fuel

tl = {}
local function getv(dir)
	if dir==0 then return {x=0,y=0,z=1}
	elseif dir==1 then return {x=1,y=0,z=0}
	elseif dir==2 then return {x=0,y=0,z=-1}
	elseif dir==3 then return {x=-1,y=0,z=0} end
end

local function turtle_can_go(nname)
	return nname == "air" or minetest.registered_nodes[nname].liquidtype ~= "none"
end

function tl.forward(turtle, cptr)
	local info = get_turtle_info(turtle)
	if info.fuel == 0 then
		cptr.X = 0
		return
	end
	local spos = info.spos
	local dir = info.dir
	local npos = vector.add(spos, getv(dir))
	if turtle_can_go(minetest.get_node(npos).name) then
		info.npos = npos
		info.moving = true
		info.fuel = info.fuel - 1
		cptr.X = u16(-1)
		cptr.paused = true
	else
		cptr.X = 0
	end
end

function tl.backward(turtle, cptr)
	local info = get_turtle_info(turtle)
	if info.fuel == 0 then
		cptr.X = 0
		return
	end
	local spos = info.spos
	local dir = info.dir
	local npos = vector.add(spos, getv((dir+2)%4))
	if turtle_can_go(minetest.get_node(npos).name) then
		info.npos = npos
		info.moving = true
		info.fuel = info.fuel - 1
		cptr.X = u16(-1)
		cptr.paused = true
	else
		cptr.X = 0
	end
end

function tl.up(turtle, cptr)
	local info = get_turtle_info(turtle)
	if info.fuel == 0 then
		cptr.X = 0
		return
	end
	local spos = info.spos
	local npos = vector.add(spos, {x=0, y=1, z=0})
	if turtle_can_go(minetest.get_node(npos).name) then
		info.npos = npos
		info.moving = true
		info.fuel = info.fuel - 1
		cptr.X = u16(-1)
		cptr.paused = true
	else
		cptr.X = 0
	end
end

function tl.down(turtle, cptr)
	local info = get_turtle_info(turtle)
	if info.fuel == 0 then
		cptr.X = 0
		return
	end
	local spos = info.spos
	local npos = vector.add(spos, {x=0, y=-1, z=0})
	if turtle_can_go(minetest.get_node(npos).name) then
		info.npos = npos
		info.moving = true
		info.fuel = info.fuel - 1
		cptr.X = u16(-1)
		cptr.paused = true
	else
		cptr.X = 0
	end
end

function tl.turnleft(turtle, cptr)
	local info = get_turtle_info(turtle)
	info.ndir = (info.dir+3)%4
	info.rotate = math.pi/2
	info.moving = true
	cptr.paused = true
end

function tl.turnright(turtle, cptr)
	local info = get_turtle_info(turtle)
	info.ndir = (info.dir+1)%4
	info.rotate = -math.pi/2
	info.moving = true
	cptr.paused = true
end

local function write_string_at(cptr, addr, str)
	for i=1, string.len(str) do
		cptr[u16(addr-1+i)] = string.byte(str, i)
	end
	cptr.X = string.len(str)
end

local function turtle_detect(turtle, cptr, dir)
	local info = get_turtle_info(turtle)
	local pos = vector.add(info.spos, dir)
	local name = minetest.get_node(pos).name
	write_string_at(cptr, cptr.X, name)
end

function tl.detect(turtle, cptr)
	local info = get_turtle_info(turtle)
	turtle_detect(turtle, cptr, getv(info.dir))
end

function tl.detectup(turtle, cptr)
	turtle_detect(turtle, cptr, {x = 0, y = 1, z = 0})
end

function tl.detectdown(turtle, cptr)
	turtle_detect(turtle, cptr, {x = 0, y = -1, z = 0})
end

local function turtle_dig(turtle, cptr, dir)
	local info = get_turtle_info(turtle)
	local dpos = vector.add(info.spos, dir)
	local dnode = minetest.env:get_node(dpos)
	if turtle_can_go(dnode.name) or dnode.name == "ignore" then
		cptr.X = 0
		return
	end
	local drops = minetest.get_node_drops(dnode.name, "default:pick_mese")
	local _, dropped_item
	for _, dropped_item in ipairs(drops) do
		local leftover = turtle_invs:add_item(turtle,dropped_item)
		minetest.add_item(info.spos,leftover)
	end
	minetest.remove_node(dpos)
	cptr.X = u16(-1)
	cptr.paused = true
end

function tl.dig(turtle, cptr)
	local info = get_turtle_info(turtle)
	turtle_dig(turtle, cptr, getv(info.dir))
end

function tl.digup(turtle, cptr)
	turtle_dig(turtle, cptr, {x = 0, y = 1, z = 0})
end

function tl.digdown(turtle, cptr)
	turtle_dig(turtle, cptr, {x = 0, y = -1, z = 0})
end

local function stack_set_count(stack, count)
	stack = stack:to_table()
	if stack==nil then return nil end
	stack.count=count
	return ItemStack(stack)
end

function tl.refuel(turtle, cptr, slot, nmax)
	local info = get_turtle_info(turtle)
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
	cptr.X = u16(FUEL_EFFICIENCY*count*fuel.time)
end
