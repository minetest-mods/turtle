local MAX_LINE_LENGHT = 28
local DEBUG = true

local serialize_inv = function(l)
	local l2={}
	for _,i in pairs(l or {}) do
		l2[_]=i:to_table()
	end
	return l2
end

local deserialize_inv = function(l)
	local l2={}
	for _,i in pairs(l or {}) do
		l2[_]=ItemStack(i)
	end
	return l2
end

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

turtle_infos = read_file(wpath.."/turtle_infos")
floppies = read_file(wpath.."/floppies")

minetest.register_on_shutdown(function()
	for turtle,i in pairs(turtle_infos) do
		i.turtle = nil
		i.playernames = nil
		i.inventory = serialize_inv(turtle_invs:get_list(turtle))
		i.floppy = serialize_inv(turtle_floppy:get_list(turtle))
	end
	write_file(wpath.."/turtle_infos",turtle_infos)
	write_file(wpath.."/floppies", floppies)
end)

function get_turtle_info(turtle)
	if turtle_infos[turtle]==nil then turtle_infos[turtle]={} end
	return turtle_infos[turtle]
end

local function get_turtle_id()
	i=0
	while true do
		if turtle_infos["turtle"..tostring(i)]==nil then return "turtle"..tostring(i) end
		i=i+1
	end
end

local function get_floppy_id()
	return #floppies + 1
end

local function round_pos(p)
	return {x=math.floor(p.x+0.5),
		y=math.floor(p.y+0.5),
		z=math.floor(p.z+0.5)}
end

function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

function escape(text)
	-- Remove all \0's in the string, that cannot be done using string.gsub as there can't be \0's in a pattern
	text2 = ""
	for i=1, string.len(text) do
		if string.byte(text, i)~=0 then text2 = text2..string.sub(text, i, i) end
	end
	return minetest.formspec_escape(text2)
end

function create_text_formspec(text)
	local f = lines(text)
	s = ""
	i = -0.25
	for _,x in ipairs(f) do
		s = s.."]label[0,"..tostring(i)..";"..escape(x)
		i = i+0.3
	end
	s = s.."]field[0.3,"..tostring(i+0.4)..";4.4,1;f;;]"
	return s:sub(2, -1)
	--return "textarea[0.3,0;4.4,4.1;;"..escape(text)..";]field[0.3,3.6;4.4,1;f;;]"
end

local update_formspec = function(turtle)
	local info = get_turtle_info(turtle)
	local formspec = "size[9,10]"..
		create_text_formspec(info.text)..
		"list[detached:turtle:invs;"..turtle..";4.8,0;4,4;]"..
		"image_button[1,4.6;2.5,1;turtle_execute.png;reboot;]"..
		"list[detached:turtle:floppy;"..turtle..";0,4.6;1,1;]"..
		"list[current_player;main;0.5,6;8,4;]"
	if info.formspec ~= formspec then
		info.formspec = formspec
		info.formspec_changed = true
	end
end

local function on_screen_digiline_receive(turtle, channel, msg)
	if channel == "screen" then
		local info = get_turtle_info(turtle)
		info.text = add_text(info.text, msg)
		update_formspec(turtle)
	end
end

local function handle_floppy_meta(stack)
	if stack.metadata == "" or stack.metadata == nil then
		local id = get_floppy_id()
		stack.metadata = tostring(id)
		floppies[stack.metadata] = string.rep(string.char(0), 16384)
		return floppies[id], true
	elseif string.len(stack.metadata) >= 1000 then
		local id = get_floppy_id()
		floppies[id] = stack.metadata
		stack.metadata = tostring(id)
		return floppies[id], true
	else
		return floppies[tonumber(stack.metadata)], false
	end
end

local function set_floppy_contents(name, contents)
	floppies[tonumber(name)] = contents
end

local on_disk_digiline_receive = function (turtle, channel, msg)
	if channel == "boot" then
		if string.len(msg) ~= 1 and string.len(msg) ~= 65 then return end -- Invalid message, it comes probably from the disk itself
		local page = string.byte(msg, 1)
		if page == nil then return end
		local stack = turtle_floppy:get_stack(turtle, 1):to_table()
		if stack == nil then return end
		if stack.name ~= "turtle:floppy" then return end
		--if stack.metadata == "" then stack.metadata = string.rep(string.char(0), 16384) end
		local floppy_contents, update = handle_floppy_meta(stack)
		if update then
			turtle_floppy:set_stack(turtle, 1, ItemStack(stack))
		end
		msg = string.sub(msg, 2, -1)
		if string.len(msg) == 0 then -- read
			local ret = string.sub(floppy_contents, page*64+1, page*64+64)
			turtle_receptor_send(turtle, channel, ret)
		else -- write
			floppy_contents = string.sub(floppy_contents, 1, page*64)..msg..string.sub(floppy_contents, page*64+65, -1)
			--turtle_floppy:set_stack(turtle, 1, ItemStack(stack))
			set_floppy_contents(stack.metadata,floppy_contents)
		end
	end
end

minetest.register_craftitem("turtle:floppy",{
	description = "Floppy disk",
	inventory_image = "floppy.png",
	stack_max = 1,
})

local progs = {["Empty"] = string.rep(string.char(0), 16536),
		["Forth Boot Disk"] = create_forth_floppy(),
		}

minetest.register_node("turtle:floppy_programmator",{
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
		if stack:get_name() == "turtle:floppy" then return 1 end
		return 0
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		if fields.prog then
			local inv = meta:get_inventory()
			local prog = progs[fields.pselector]
			local stack = inv:get_stack("floppy", 1):to_table()
			if stack == nil then return end
			if stack.name ~= "turtle:floppy" then return end
			local contents, update = handle_floppy_meta(stack)
			set_floppy_contents(stack.metadata, prog)
			--stack.metadata = prog
			if update then
				inv:set_stack("floppy", 1, ItemStack(stack))
			end
		end
	end,
})

function turtle_receptor_send(turtle, channel, msg)
	on_screen_digiline_receive(turtle, channel, msg)
	on_computer_digiline_receive(turtle, channel, msg)
	on_disk_digiline_receive(turtle, channel, msg)
	--on_turtle_command_receive(turtle, channel, msg)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1,6) ~= "turtle" then return end
	if fields.f ~= nil and fields.f ~= "" then
		if string.len(fields.f) > 80 then
			fields.f = string.sub(fields.f, 1, 80)
		end
		turtle_receptor_send(formname, "screen", fields.f)
		update_formspec(formname)
		return
	end
	if fields.reboot then
		local info = get_turtle_info(formname)
		info.cptr = create_cptr()
		return
	end
	if fields.quit then
		local info = get_turtle_info(formname)
		info.playernames[player:get_player_name()] = nil
	end
end)

minetest.register_craftitem("turtle:turtle",{
	description = "Turtle",
	image = "turtle_turtle_inv.png",
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then return end
		local obj = minetest.add_entity(pointed_thing.above, "turtle:turtle")
		itemstack:take_item()
		--return itemstack
	end
})

turtle_invs = minetest.create_detached_inventory("turtle:invs")
turtle_floppy = minetest.create_detached_inventory("turtle:floppy")
for turtle,i in pairs(turtle_infos) do
	turtle_invs:set_size(turtle, 16)
	for l,stack in pairs(deserialize_inv(i.inventory)) do
		turtle_invs:set_stack(turtle, l, stack)
	end
	turtle_floppy:set_size(turtle, 1)
	for l,stack in pairs(deserialize_inv(i.floppy)) do
		turtle_floppy:set_stack(turtle, l, stack)
	end
end

local function dot(v1, v2)
	return v1.x*v2.x + v1.y*v2.y + v1.z*v2.z
end

local function done_move(pos, spos, npos)
	local dir = vector.subtract(npos, spos)
	local move = vector.subtract(npos, pos)
	s = dot(dir, move)
	return dot(dir, move) <= 0
end

local function done_rotation(yaw, nyaw, rotate_speed)
	return (nyaw - yaw + rotate_speed - math.pi/2)%(2*math.pi) < math.pi
end

minetest.register_entity("turtle:turtle", {
	physical = true,
	force_load = TURTLES_FORCE_LOAD,
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	collides_with_objects = false,
	visual = "wielditem",
	visual_size = {x = 2/3, y = 2/3},
	textures = {"default:wood"},
	on_activate = function(self, staticdata)
		local info
		if staticdata == nil or staticdata == "" then
			self.n = get_turtle_id()
			info = get_turtle_info(self.n)
			turtle_invs:set_size(self.n, 16)
			turtle_floppy:set_size(self.n, 1)
			info.turtle = self
			info.spos = round_pos(self.object:getpos())
			info.dir = 0
			info.fuel = 0
			info.text = "\n\n\n\n\n\n\n\n\n\n"
			info.cptr = create_cptr()
			info.playernames = {}
			-- Build formspec
			update_formspec(self.n)
		else
			self.n = staticdata
			info = get_turtle_info(self.n)
			info.turtle = self
			info.playernames = {}
		end
	end,
	on_step = function(self, dtime)
		local info = get_turtle_info(self.n)
		if info.rotate then
			self.object:setyaw(self.object:getyaw()+info.rotate*dtime)
		end
		if info.moving then
			if info.npos ~= nil then
				local pos = self.object:getpos()
				local npos = info.npos
				local spos = info.spos
				if done_move(pos, spos, npos) then
					self.object:setpos(npos)
					self.object:setvelocity({x=0, y=0, z=0})
					info.spos = npos
					info.npos = nil
					info.moving = nil
				else
					self.object:setvelocity(vector.subtract(npos, spos))
				end
			elseif info.ndir ~= nil then
				local yaw = self.object:getyaw()
				local rotate_speed = info.rotate
				local nyaw = info.ndir*math.pi/2
				if done_rotation(yaw, nyaw, rotate_speed) then
					self.object:setyaw(nyaw)
					info.dir = info.ndir
					info.ndir = nil
					info.rotate = nil
					info.moving = nil
				end
			end
		end
		if not info.moving then
			run_computer(self.n, info.cptr)
		end
		if info.formspec_changed then
			for playername, _ in pairs(info.playernames) do
				if DEBUG then
					print(info.text)
					print("------------------------------------")
				end
				minetest.show_formspec(playername, self.n, info.formspec)
			end
			info.formspec_changed = nil
		end
	end,
	on_rightclick = function(self, clicker)
		local info = get_turtle_info(self.n)
		local name = clicker:get_player_name()
		info.playernames[name] = true
		minetest.show_formspec(name, self.n, info.formspec)
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		self.object:remove()
		minetest.add_item(turtle_infos[self.n].spos, "turtle:turtle")
		
		for i=1,16 do
			local stack = turtle_invs:get_stack(self.n, i)
			minetest.add_item(turtle_infos[self.n].spos, stack)
			turtle_invs:set_stack(self.n, i, ItemStack(""))
		end
		
		local stack = turtle_floppy:get_stack(self.n, 1)
		minetest.add_item(turtle_infos[self.n].spos, stack)
		turtle_floppy:set_stack(self.n, 1, ItemStack(""))
		
		turtle_infos[self.n] = nil
	end,
	get_staticdata = function(self)
		return self.n
	end,
})
