local CYCLES_PER_STEP = 1000
local MAX_CYCLES = 100000
local FUEL_EFFICIENCY = 3	-- How many moves can the turtle do with a second fuel

local function file_exists(name)
	local f = io.open(name, "r")
	if f then
		f:close()
		return true
	end
	return false
end

function loadpkg(na)
	local modpath = minetest.get_modpath("forth_computer")
	local ol = package.cpath
	local sp
	if file_exists(modpath.."/INIT.LUA") then
		-- On windows, if we try to open the others we get a crash
		-- even with pcall
		sp = {modpath.."/?.dll"}
	else
		sp = {modpath.."/?.so.32", modpath.."/?.so.64"}
	end
	for i=1,#sp do
		package.cpath = sp[i]
		e, lib = pcall(require, na)
		package.cpath = ol
		if e then
			return lib
		end
	end
	package.cpath = ol
	return nil
end

local modpath = minetest.get_modpath("turtle")

if bit32 == nil and jit == nil then
	-- No need to use the library if LuaJIT is there, the Lua one is more efficient
	bit32 = loadpkg("bit32")
end
if bit32 == nil then
	-- bit32 has not been loaded, using a Lua implementation of what we need
	dofile(modpath.."/bit32.lua")
	if jit == nil then
		print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> "..
			"WARNING: bit32 could not loaded, you should fix"..
			" that or use LuaJIT for better performance"..
			" <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<")
	end
end

local function s16(x)
	if bit32.band(x, 0x8000)~=0 then
		return bit32.band(x, 0xffff)-0x10000
	end
	return bit32.band(x, 0xffff)
end

local function u16(x)
	return bit32.band(x, 0xffff)
end

local function s32(x)
	if bit32.band(x, 0x80000000)~=0 then
		return bit32.band(x, 0xffffffff)-0x100000000
	end
	return bit32.band(x, 0xffffffff)
end

local function u32(x)
	return bit32.band(x, 0xffffffff)
end

local function readC(cptr, addr)
	return cptr[addr]
end

local function writeC(cptr, addr, value)
	cptr[addr] = bit32.band(value, 0xff)
end

local function read(cptr, addr)
	return cptr[addr] + 256*cptr[u16(addr+1)]
end

local function write(cptr, addr, value)
	cptr[addr] = bit32.band(value, 0xff)
	cptr[addr+1] = bit32.band(math.floor(value/256), 0xff)
end

local function push(cptr, value)
	cptr.SP = u16(cptr.SP+2)
	write(cptr, cptr.SP, value)
end

local function pop(cptr, value)
	local n = read(cptr, cptr.SP)
	cptr.SP = u16(cptr.SP-2)
	return n
end

local function rpush(cptr, value)
	cptr.RP = u16(cptr.RP+2)
	write(cptr, cptr.RP, value)
end

local function rpop(cptr, value)
	local n = read(cptr, cptr.RP)
	cptr.RP = u16(cptr.RP-2)
	return n
end

local function string_at(cptr, addr, len)
	local l = {}
	for k=1, len do
		local i = u16(addr+k-1)
		local s = cptr[i]
		l[k] = string.char(s)
	end
	return table.concat(l, "")
end

local function receive(cptr, caddr, clen, raddr)
	local channel = string_at(cptr, caddr, clen)
	local event = cptr.digiline_events[channel]
	if event and type(event)=="string" then
		if string.len(event)>80 then
			event = string.sub(event,1,80)
		end
		for i=1,string.len(event) do
			cptr[u16(raddr-1+i)] = string.byte(event,i)
		end
		cptr.X = string.len(event)
	else
		cptr.X = u16(-1)
	end
end

local function delete_message(cptr, caddr, clen)
	local channel = string_at(cptr, caddr, clen)
	cptr.digiline_events[channel] = nil
end

local function set_channel(cptr, caddr, clen)
	local channel = string_at(cptr, caddr, clen)
	cptr.channel = channel
end

local function send_message(turtle, cptr, maddr, mlen)
	local msg = string_at(cptr, maddr, mlen)
	cptr.digiline_events[cptr.channel] = msg
	turtle_receptor_send(turtle, cptr.channel, msg)
end

local function getv(dir)
	if dir==0 then return {x=0,y=0,z=1}
	elseif dir==1 then return {x=1,y=0,z=0}
	elseif dir==2 then return {x=0,y=0,z=-1}
	elseif dir==3 then return {x=-1,y=0,z=0} end
end

local function turtle_can_go(nname)
	return nname=="air" or minetest.registered_nodes[nname].liquidtype~="none"
end

local tl = {}

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

function run_computer(turtle, cptr)
	if cptr.stopped then return end
	cptr.cycles = math.max(MAX_CYCLES,cptr.cycles+CYCLES_PER_STEP)
	while 1 do
		instr = cptr[cptr.PC]
		local f = ITABLE[instr]
		if f == nil then return end
		cptr.PC = bit32.band(cptr.PC+1, 0xffff)
		setfenv(f, {cptr = cptr, turtle=turtle, receive=receive, delete_message=delete_message, set_channel=set_channel, send_message=send_message, u16=u16, u32=u32, s16=s16, s32=s32, read=read, write=write, readC=readC, writeC=writeC, push=push, pop=pop, rpush=rpush, rpop=rpop, bit32=bit32, math=math, tl=tl})
		f()
		cptr.cycles = cptr.cycles - 1
		if cptr.paused or cptr.cycles <= 0 then
			cptr.paused = false
			return
		end
	end
end

function create_cptr()
	local cptr = create_cptr_memory()
	cptr.X = 0
	cptr.Y = 0
	cptr.Z = 0
	cptr.I = 0
	cptr.PC = 0xff00
	cptr.RP = 0
	cptr.SP = 0
	cptr.paused = false
	cptr.stopped = false
	cptr.has_input = false
	cptr.digiline_events = {}
	cptr.channel = ""
	cptr.cycles = 0
	return cptr
end

ITABLE_RAW = {
	[0x28] = "cptr.I = rpop(cptr)",
	[0x29] = "cptr.PC = read(cptr, cptr.I); cptr.I = u16(cptr.I+2)",
	[0x2a] = "rpush(cptr, cptr.I); cptr.I = u16(cptr.PC+2); cptr.PC=read(cptr, cptr.PC)",
	[0x2b] = "cptr.X = read(cptr, cptr.I); cptr.I = u16(cptr.I+2)",
	
	[0x08] = "cptr.X = cptr.SP",
	[0x09] = "cptr.X = cptr.RP",
	[0x0a] = "cptr.X = cptr.PC",
	[0x0b] = "cptr.X = cptr.I",
	
	[0x00] = "cptr.paused = true",
	
	[0x01] = "rpush(cptr, cptr.X)",
	[0x02] = "rpush(cptr, cptr.Y)",
	[0x03] = "rpush(cptr, cptr.Z)",
	[0x10] = "cptr.X = read(cptr, cptr.RP)",
	[0x11] = "cptr.X = rpop(cptr)",
	[0x12] = "cptr.Y = rpop(cptr)",
	[0x13] = "cptr.Z = rpop(cptr)",
	
	[0x20] = "write(cptr, cptr.SP, cptr.X)",
	[0x21] = "push(cptr, cptr.X)",
	[0x22] = "push(cptr, cptr.Y)",
	[0x23] = "push(cptr, cptr.Z)",
	[0x30] = "cptr.X = read(cptr, cptr.SP)",
	[0x31] = "cptr.X = pop(cptr)",
	[0x32] = "cptr.Y = pop(cptr)",
	[0x33] = "cptr.Z = pop(cptr)",
	
	[0x04] = "cptr.X = read(cptr, cptr.X)",
	[0x05] = "cptr.X = read(cptr, cptr.Y)",
	[0x06] = "cptr.Y = read(cptr, cptr.X)",
	[0x07] = "cptr.Y = read(cptr, cptr.Y)",
	
	[0x14] = "cptr.X = readC(cptr, cptr.X)",
	[0x15] = "cptr.X = readC(cptr, cptr.Y)",
	[0x16] = "cptr.Y = readC(cptr, cptr.X)",
	[0x17] = "cptr.Y = readC(cptr, cptr.Y)",
	
	[0x25] = "write(cptr, cptr.X, cptr.Y)",
	[0x26] = "write(cptr, cptr.Y, cptr.X)",
	
	[0x35] = "writeC(cptr, cptr.X, cptr.Y)",
	[0x36] = "writeC(cptr, cptr.Y, cptr.X)",
	
	[0x0c] = "n=cptr.X+cptr.Y; cptr.Y = u16(n); cptr.X = u16(math.floor(n/0x10000))",
	[0x0d] = "n=cptr.X-cptr.Y; cptr.Y = u16(n); cptr.X = u16(math.floor(n/0x10000))",
	[0x0e] = "n=cptr.X*cptr.Y; cptr.Y = u16(n); cptr.X = u16(math.floor(n/0x10000))",
	[0x0f] = "n=s16(cptr.X)*s16(cptr.Y); cptr.Y = u16(n); cptr.X = u16(math.floor(n/0x10000))",
	[0x1e] = "if cptr.Z~=0 then n = cptr.X*0x10000+cptr.Y; cptr.Y = u16(math.floor(n/cptr.Z)); cptr.X = u16(math.floor((n/cptr.Z)/0x10000)); cptr.Z = u16(n%cptr.Z) end",
	[0x1f] = "if cptr.Z~=0 then n = s32(cptr.X*0x10000+cptr.Y); cptr.Y = u16(math.floor(n/s16(cptr.Z))); cptr.X = u16(math.floor((n/s16(cptr.Z))/0x10000)); cptr.Z = u16(n%s16(cptr.Z)) end",
	[0x2c] = "cptr.X = u16(bit32.band(cptr.X, cptr.Y))",
	[0x2d] = "cptr.X = u16(bit32.bor(cptr.X, cptr.Y))",
	[0x2e] = "cptr.X = u16(bit32.bxor(cptr.X, cptr.Y))",
	[0x2f] = "cptr.X = u16(bit32.bnot(cptr.X))",
	[0x3c] = "cptr.X = bit32.rshift(cptr.X, cptr.Y)",
	[0x3d] = "cptr.X = u16(bit32.arshift(s16(cptr.X), cptr.Y))",
	[0x3e] = "n = cptr.X; cptr.X = u16(bit32.lshift(n, cptr.Y)); cptr.Y = u16(bit32.lshift(n, cptr.Y-16))",
	[0x3f] = "if s16(cptr.Y)<0 then cptr.X = u16(-1) else cptr.X = 0 end",
	
	[0x38] = "cptr.PC = u16(cptr.PC+read(cptr, cptr.PC)+2)",
	[0x39] = "if cptr.X~=0 then cptr.PC = u16(cptr.PC+read(cptr, cptr.PC)) end; cptr.PC = u16(cptr.PC+2)",
	[0x3a] = "if cptr.Y~=0 then cptr.PC = u16(cptr.PC+read(cptr, cptr.PC)) end; cptr.PC = u16(cptr.PC+2)",
	[0x3b] = "if cptr.Z~=0 then cptr.PC = u16(cptr.PC+read(cptr, cptr.PC)) end; cptr.PC = u16(cptr.PC+2)",
	
	[0x18] = "cptr.SP = cptr.X",
	[0x19] = "cptr.RP = cptr.X",
	[0x1a] = "cptr.PC = cptr.X",
	[0x1b] = "cptr.I = cptr.X",
	
	[0x40] = "cptr.Z = cptr.X",
	[0x41] = "cptr.Z = cptr.Y",
	[0x42] = "cptr.X = cptr.Z",
	[0x43] = "cptr.Y = cptr.Z",
	[0x44] = "cptr.X = cptr.Y",
	[0x45] = "cptr.Y = cptr.X",
	
	[0x46] = "cptr.X = u16(cptr.X-1)",
	[0x47] = "cptr.Y = u16(cptr.Y-1)",
	[0x48] = "cptr.Z = u16(cptr.Z-1)",
	
	[0x49] = "cptr.X = u16(cptr.X+1)",
	[0x4a] = "cptr.Y = u16(cptr.Y+1)",
	[0x4b] = "cptr.Z = u16(cptr.Z+1)",
	
	[0x4d] = "cptr.X = read(cptr, cptr.PC); cptr.PC = u16(cptr.PC+2)",
	[0x4e] = "cptr.Y = read(cptr, cptr.PC); cptr.PC = u16(cptr.PC+2)",
	[0x4f] = "cptr.Z = read(cptr, cptr.PC); cptr.PC = u16(cptr.PC+2)",
	
	[0x52] = "receive(cptr, cptr.X, cptr.Y, cptr.Z)", -- Digiline receive
	[0x53] = "delete_message(cptr, cptr.X, cptr.Y)",
	[0x54] = "send_message(turtle, cptr, cptr.X, cptr.Y)", -- Digiline send
	[0x55] = "set_channel(cptr, cptr.X, cptr.Y)", -- Digiline set channel
	
	-- Turtle commands
	[0x60] = "tl.forward(turtle, cptr)",
	[0x61] = "tl.backward(turtle, cptr)",
	[0x62] = "tl.up(turtle, cptr)",
	[0x63] = "tl.down(turtle, cptr)",
	[0x64] = "tl.turnleft(turtle, cptr)",
	[0x65] = "tl.turnright(turtle, cptr)",
	
	[0x70] = "tl.refuel(turtle, cptr, cptr.X, cptr.Y)",
}

ITABLE = {}

for i, v in pairs(ITABLE_RAW) do
	ITABLE[i] = loadstring(v) -- Parse everything at the beginning, way faster
end

function on_computer_digiline_receive(turtle, channel, msg)
	local info = get_turtle_info(turtle)
	local cptr = info.cptr
	cptr.digiline_events[channel] = msg
end
