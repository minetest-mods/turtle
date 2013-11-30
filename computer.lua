local CYCLES_PER_STEP = 1000
local MAX_CYCLES = 100000
local MAX_LINE_LENGHT = 42

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

local modpath = minetest.get_modpath("forth_computer")

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

dofile(modpath.."/computer_memory.lua")
dofile(modpath.."/forth_floppy.lua")

local wpath = minetest.get_worldpath()
local function read_file(fn)
	local f = io.open(fn, "r")
	if f==nil then return {} end
	local t = f:read("*all")
	f:close()
	if t=="" or t==nil then return {} end
	return minetest.deserialize(t)
end

local function write_file(fn, tbl)
	local f = io.open(fn, "w")
	f:write(minetest.serialize(tbl))
	f:close()
end

local cptrs = read_file(wpath.."/forth_computers")
local oldcptrs = read_file(wpath.."/forth_computers")
local screens = read_file(wpath.."/screens")

function hacky_swap_node(pos,name)
   local node = minetest.get_node(pos)
   if node.name ~= name then
      local meta = minetest.get_meta(pos)
      local meta0 = meta:to_table()
      node.name = name
      minetest.set_node(pos,node)
      meta = minetest.get_meta(pos)
      meta:from_table(meta0)
   end
   return node.name
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

function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

local function hashpos(pos)
	if pos.x == 0 then pos.x = 0 end -- Fix for signed 0
	if pos.y == 0 then pos.y = 0 end -- Fix for signed 0
	if pos.z == 0 then pos.z = 0 end -- Fix for signed 0
	return tostring(pos.x).."\n"..tostring(pos.y).."\n"..tostring(pos.z)
end

local function dehashpos(str)
	local l = lines(str)
	return {x = tonumber(l[1]), y = tonumber(l[2]), z = tonumber(l[3])}
end

local function newline(text, toadd)
	local f = lines(text)
	table.insert(f, toadd)
	return table.concat(f, "\n", 2)
end

local function add_char(text, char)
	local ls = lines(text)
	local ll = ls[#ls]
	if char=="\n" or char=="\r" then
		return newline(text,"")
	elseif string.len(ll)>=MAX_LINE_LENGHT then
		return newline(text, char)
	else
		return text..char
	end
end

local function add_text(text, toadd)
	for i=1, string.len(toadd) do
		text = add_char(text, string.sub(toadd, i, i))
	end
	return text
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

local function emit(pos, c, cptr)
	local s = string.char(bit32.band(c, 0xff))
	local meta = minetest.get_meta(pos)
	local text = meta:get_string("text")
	local ls = lines(text)
	local ll = ls[#ls]
	if s=="\n" or s=="\r" then
		meta:set_string("text", newline(text,""))
	elseif string.len(ll)>=MAX_LINE_LENGHT then
		meta:set_string("text", newline(text, s))
	else
		meta:set_string("text", text..s)
	end
	cptr.fmodif = true
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

local function send_message(pos, cptr, maddr, mlen)
	local msg = string_at(cptr, maddr, mlen)
	cptr.digiline_events[cptr.channel] = msg
	digiline:receptor_send(pos, digiline.rules.default, cptr.channel, msg)
end

local function run_computer(pos,cptr)
	local meta = minetest.get_meta(pos)
	local oldpos = meta:get_string("pos")
	if oldpos == "" then
		return
	end
	oldpos = minetest.deserialize(oldpos)
	if oldpos.x ~= pos.x or oldpos.y ~= pos.y or oldpos.z ~= pos.z then
		local old_cptr = oldcptrs[hashpos(oldpos)]
		for key, _ in pairs(oldcptrs) do
			print(key)
		end
		meta:set_string("pos", minetest.serialize(pos))
		print(hashpos(oldpos))
		if old_cptr ~= nil then
			cptrs[hashpos(pos)].cptr = old_cptr.cptr
		end
	end
	if cptr.stopped then return end
	cptr.cycles = math.max(MAX_CYCLES,cptr.cycles+CYCLES_PER_STEP)
	while 1 do
		instr = cptr[cptr.PC]
		local f = ITABLE[instr]
		if f == nil then return end
		cptr.PC = bit32.band(cptr.PC+1, 0xffff)
		setfenv(f, {cptr = cptr, pos=pos, emit=emit, receive=receive, delete_message=delete_message, set_channel=set_channel, send_message=send_message, u16=u16, u32=u32, s16=s16, s32=s32, read=read, write=write, readC=readC, writeC=writeC, push=push, pop=pop, rpush=rpush, rpop=rpop, bit32=bit32, math=math})
		f()
		cptr.cycles = cptr.cycles - 1
		if cptr.paused or cptr.cycles == 0 then
			cptr.paused = false
			return
		end
	end
end

local function create_cptr()
	local cptr = create_cptr_memory()
	cptr.X = 0
	cptr.Y = 0
	cptr.Z = 0
	cptr.I = 0
	cptr.PC = 0xff00
	cptr.RP = 0
	cptr.SP = 0
	cptr.paused = false
	cptr.stopped = true
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
	
	-- [0x50] = "if cptr.has_input then\ncptr.has_input = false\nelse\ncptr.paused = true\ncptr.PC = u16(cptr.PC-1)\nend",
	-- [0x51] = "emit(pos, cptr.X, cptr)",
	[0x52] = "receive(cptr, cptr.X, cptr.Y, cptr.Z)", -- Digiline receive
	[0x53] = "delete_message(cptr, cptr.X, cptr.Y)",
	[0x54] = "send_message(pos, cptr, cptr.X, cptr.Y)", -- Digiline send
	[0x55] = "set_channel(cptr, cptr.X, cptr.Y)", -- Digiline set channel
}

ITABLE = {}

for i, v in pairs(ITABLE_RAW) do
	ITABLE[i] = loadstring(v) -- Parse everything at the beginning, way faster
end

local on_computer_digiline_receive = function (pos, node, channel, msg)
	local cptr = cptrs[hashpos(pos)].cptr
	if cptr == nil then return end
	cptr.digiline_events[channel] = msg
end

minetest.register_node("forth_computer:computer",{
	description = "Computer on (you hacker you)",
	paramtype2 = "facedir",
	tiles = {"cpu_top.png", "cpu_bottom.png", "cpu_right.png", "cpu_left.png", "cpu_back.png", "cpu_front.png"},
	groups = {cracky=3, not_in_creative_inventory=1},
	sounds = default.node_sound_stone_defaults(),
	digiline = 
	{
		receptor = {},
		effector = {action = on_computer_digiline_receive},
	},
	on_construct = function(pos)
		if cptrs[hashpos(pos)] then return end
		cptrs[hashpos(pos)] = {pos=pos, cptr=create_cptr()}
		local meta = minetest.get_meta(pos)
		meta:set_string("pos", minetest.serialize(pos))
	end,
	on_destruct = function(pos)
		if cptrs[hashpos(pos)] == nil then return end
		if cptrs[hashpos(pos)].swapping then
			cptrs[hashpos(pos)].swapping = nil
			return
		end
		oldcptrs[hashpos(pos)] = cptrs[hashpos(pos)]
		cptrs[hashpos(pos)] = nil
	end,
	on_punch = function(pos, node, puncher)
		if cptrs[hashpos(pos)] == nil then return end
		local cptr = cptrs[hashpos(pos)].cptr
		cptr.stopped = true
		cptrs[hashpos(pos)].swapping = true
		hacky_swap_node(pos, "forth_computer:computer_off")
	end,
})

minetest.register_node("forth_computer:computer_off",{
	description = "Computer",
	paramtype2 = "facedir",
	tiles = {"cpu_top.png", "cpu_bottom.png", "cpu_right.png", "cpu_left.png", "cpu_back.png", "cpu_front_off.png"},
	groups = {cracky=3},
	sounds = default.node_sound_stone_defaults(),
	digiline = 
	{
		receptor = {},
		effector = {action = on_computer_digiline_receive},
	},
	on_construct = function(pos)
		if cptrs[hashpos(pos)] then return end
		cptrs[hashpos(pos)] = {pos=pos, cptr=create_cptr()}
		local meta = minetest.get_meta(pos)
		meta:set_string("pos", minetest.serialize(pos))
	end,
	on_destruct = function(pos)
		if cptrs[hashpos(pos)] == nil then return end
		if cptrs[hashpos(pos)].swapping then
			cptrs[hashpos(pos)].swapping = nil
			return
		end
		oldcptrs[hashpos(pos)] = cptrs[hashpos(pos)]
		cptrs[hashpos(pos)] = nil
	end,
	on_punch = function(pos, node, puncher)
		if cptrs[hashpos(pos)] == nil then return end
		local cptr = cptrs[hashpos(pos)].cptr
		cptr.stopped = false
		cptrs[hashpos(pos)].swapping = true
		hacky_swap_node(pos, "forth_computer:computer")
	end,
})

local on_screen_digiline_receive = function (pos, node, channel, msg)
	local meta = minetest.get_meta(pos)
	if channel == meta:get_string("channel") then
		local ntext = add_text(meta:get_string("text"), msg)
		meta:set_string("text",ntext)
		screens[hashpos(pos)].fmodif = true
	end
end

minetest.register_node("forth_computer:screen",{
	description = "Screen",
	tiles = {"screen_top.png", "screen_bottom.png", "screen_right.png", "screen_left.png", "screen_back.png", "screen_front.png"},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
			-- X Y Z W H L
			{ -16/32, -16/32, 1/32, 16/32, 16/32, 13/32 }, -- Monitor Screen
			{ -13/32, -13/32, 13/32, 13/32, 13/32, 16/32 }, -- Monitor Tube
			{ -16/32, -16/32, -16/32, 16/32, -12/32, 1/32 }, -- Keyboard
			}
	},
	groups = {cracky=3},
	sounds = default.node_sound_stone_defaults(),
	digiline = 
	{
		receptor = {},
		effector = {action = on_screen_digiline_receive},
	},
	on_construct = function(pos)
		local meta=minetest.get_meta(pos)
		meta:set_string("text","\n\n\n\n\n\n\n\n\n\n\n\n")
		screens[hashpos(pos)] = {pos=pos, fmodif=false}
		meta:set_string("channel", "")
		meta:set_string("formspec", "field[channel;Channel;${channel}]")
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		fields.channel = fields.channel or ""
		meta:set_string("channel", fields.channel)
		meta:set_string("formspec", "")
	end,
	on_destruct = function(pos)
		screens[hashpos(pos)] = nil
	end,
	on_rightclick = function(pos, node, clicker)
		local name = clicker:get_player_name()
		local meta = minetest.get_meta(pos)
		if screens[hashpos(pos)] == nil then
			screens[hashpos(pos)] = {pos=pos, fmodif=false}
		end
		screens[hashpos(pos)].pname = name
		minetest.show_formspec(name,"screen"..hashpos(pos),create_formspec(meta:get_string("text")))
	end,
})

local on_disk_digiline_receive = function (pos, node, channel, msg)
	local meta = minetest.get_meta(pos)
	if channel == meta:get_string("channel") then
		local page = string.byte(msg, 1)
		if page==nil then return end
		local inv = meta:get_inventory()
		local stack = inv:get_stack("floppy", 1):to_table()
		if stack == nil then return end
		if stack.name ~= "forth_computer:floppy" then return end
		if stack.metadata == "" then stack.metadata = string.rep(string.char(0), 16384) end
		msg = string.sub(msg, 2, -1)
		if string.len(msg) == 0 then -- read
			local ret = string.sub(stack.metadata, page*64+1, page*64+64)
			digiline:receptor_send(pos, digiline.rules.default, channel, ret)
		else -- write
			if string.len(msg) ~= 64 then return end
			stack.metadata = string.sub(stack.metadata, 1, page*64)..msg..string.sub(stack.metadata, page*64+65, -1)
		end
		inv:set_stack("floppy", 1, ItemStack(stack))
	end
end

minetest.register_node("forth_computer:disk",{
	description = "Disk drive",
	paramtype2 = "facedir",
	tiles = {"floppy_drive_top.png", "floppy_drive_bottom.png", "floppy_drive_right.png", "floppy_drive_left.png", "floppy_drive_back.png", "floppy_drive_front.png"},
	groups = {cracky=3},
	sounds = default.node_sound_stone_defaults(),
	digiline = 
	{
		receptor = {},
		effector = {action = on_disk_digiline_receive},
	},
	on_construct = function(pos)
		local meta=minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("floppy", 1)
		meta:set_string("channel", "")
		meta:set_string("formspec", "size[9,5.5;]"..
					"field[0,0.5;7,1;channel;Channel:;${channel}]"..
					"list[current_name;floppy;8,0;1,1;]"..
					"list[current_player;main;0,1.5;8,4;]")
	end,
	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("floppy")
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if stack:get_name() == "forth_computer:floppy" then return 1 end
		return 0
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		fields.channel = fields.channel or ""
		meta:set_string("channel", fields.channel)
	end,
})

local function create_from_file(filename)
	local f = io.open(filename, "r")
	if f==nil then return {} end
	local t = f:read("*all")
	f:close()
	local l = lines(t)
	for key, i in ipairs(l) do
		l[key] = i..string.rep(string.char(0), 64-string.len(i))
	end
	t = table.concat(l, "")
	return t..string.rep(string.char(0), 16536-string.len(t))
end

local progs = {["Empty"] = string.rep(string.char(0), 16536),
		["Forth Boot Disk"] = create_forth_floppy(),
		["Double number library"] = create_from_file(modpath.."/double.fth"),
		--["Floating point number library"] = create_from_file(modpath.."/float.fth"),
		["Decompiler"] = create_from_file(modpath.."/see.fth")}
minetest.register_node("forth_computer:floppy_programmator",{
	description = "Floppy disk programmator",
	tiles = {"floppy_programmator_top.png", "floppy_programmator_bottom.png", "floppy_programmator_right.png", "floppy_programmator_left.png", "floppy_programmator_back.png", "floppy_programmator_front.png"},
	groups = {cracky=3},
	sounds = default.node_sound_stone_defaults(),
	on_construct = function(pos)
		local meta=minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("floppy", 1)
		meta:set_int("selected", 1)
		local s = "size[8,5.5;]"..
			"dropdown[0,0;5;pselector;"
		for key, _ in pairs(progs) do
			s = s..key..","
		end
		s = string.sub(s, 1, -2)
		s = s.. ";1]"..
			"button[5,0;2,1;prog;Program]"..
			"list[current_name;floppy;7,0;1,1;]"..
			"list[current_player;main;0,1.5;8,4;]"
		meta:set_string("formspec", s)
	end,
	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("floppy")
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if stack:get_name() == "forth_computer:floppy" then return 1 end
		return 0
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		if fields.prog then
			local inv = meta:get_inventory()
			local prog = progs[fields.pselector]
			local stack = inv:get_stack("floppy", 1):to_table()
			if stack == nil then return end
			if stack.name ~= "forth_computer:floppy" then return end
			stack.metadata = prog
			inv:set_stack("floppy", 1, ItemStack(stack))
		end
	end,
})


minetest.register_craftitem("forth_computer:floppy",{
	description = "Floppy disk",
	inventory_image = "floppy.png",
	stack_max = 1,
})

minetest.register_globalstep(function(dtime)
	for _,i in pairs(cptrs) do
		run_computer(i.pos, i.cptr)
	end
	oldcptrs = {}
	for _,i in pairs(screens) do
		if i.fmodif then
			i.fmodif=false
			if i.pname~=nil then
				local meta = minetest.get_meta(i.pos)
				minetest.show_formspec(i.pname,"screen"..hashpos(i.pos),create_formspec(meta:get_string("text")))
			end
		end
	end
end)

minetest.register_on_shutdown(function()
	for _,i in pairs(screens) do
		i.fmodif = false
		i.pname = nil
	end
	write_file(wpath.."/forth_computers",cptrs)
	write_file(wpath.."/old_forth_computers",oldcptrs)
	write_file(wpath.."/screens",screens)
end)

function escape(text)
	-- Remove all \0's in the string, that cannot be done using string.gsub as there can't be \0's in a pattern
	text2 = ""
	for i=1, string.len(text) do
		if string.byte(text, i)~=0 then text2 = text2..string.sub(text, i, i) end
	end
	return minetest.formspec_escape(text2)
end

function create_formspec(text)
	local f = lines(text)
	s = "size[5,4.5;"
	i = -0.25
	for _,x in ipairs(f) do
		s = s.."]label[0,"..tostring(i)..";"..escape(x)
		i = i+0.3
	end
	s = s.."]field[0.3,"..tostring(i+0.4)..";4.4,1;f;;]"
	return s
	--return "size[5,4.5;]textarea[0.3,0;4.4,4.1;;"..escape(text)..";]field[0.3,3.6;4.4,1;f;;]"
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1,6)~="screen" then return end
	local pos = dehashpos(formname:sub(7,-1))
	local s = screens[hashpos(pos)]
	if s==nil then return end
	if fields["f"]==nil or fields["f"]=="" then
		if fields["quit"] ~= nil then
			s.pname = nil
		end
		return
	end
	if string.len(fields["f"])>MAX_LINE_LENGHT then
		fields["f"] = string.sub(fields["f"],1,MAX_LINE_LENGHT)
	end
	digiline:receptor_send(pos, digiline.rules.default, "screen", fields["f"])
	local meta = minetest.get_meta(pos)
	local ntext = add_text(meta:get_string("text"), fields["f"])
	meta:set_string("text",ntext)
	minetest.show_formspec(player:get_player_name(),formname,create_formspec(ntext))
end)

