local DEBUG = true

-------------------------
-- Read data from file --
-------------------------

local turtle_infos = db.read_file("turtle_infos")
local floppies = db.read_file("floppies")

minetest.register_on_shutdown(function()
	for id, info in pairs(turtle_infos) do
		info.turtle = nil
		info.playernames = {}
	end
	db.write_file("turtle_infos", turtle_infos)
	db.write_file("floppies", floppies)
end)

function turtles.get_turtle_info(turtle_id)
	if turtle_infos[turtle_id] == nil then
		turtle_infos[turtle_id] = {}
	end
	return turtle_infos[turtle_id]
end

function turtles.get_turtle_inventory(turtle_id)
	local info = turtles.get_turtle_info(turtle_id)
	return minetest.get_meta(info.spos):get_inventory()
end

function turtles.create_turtle_id()
	return #turtle_infos + 1
end

function turtles.create_floppy_id()
	return #floppies + 1
end

function turtles.update_formspec(turtle_id)
	local info = turtles.get_turtle_info(turtle_id)
	local pos = info.spos
	local formspec = "size[9,10]"..
		screen.create_text_formspec(info.screen, 0, 0)..
		"list[nodemeta:"..pos.x..","..pos.y..","..pos.z..";main;4.8,0;4,4;]"..
		"image_button[1,4.6;2.5,1;turtle_execute.png;reboot;]"..
		"list[nodemeta:"..pos.x..","..pos.y..","..pos.z..";floppy;0,4.6;1,1;]"..
		"list[current_player;main;0.5,6;8,4;]"
	if info.formspec ~= formspec then
		info.formspec = formspec
		info.formspec_changed = true
	end
end

local function on_screen_digiline_receive(turtle, channel, msg)
	if channel == "screen" then
		local info = turtles.get_turtle_info(turtle)
		info.screen = screen.add_text(info.screen, msg)
		turtles.update_formspec(turtle)
	end
end

local function handle_floppy_meta(stack)
	if stack.metadata == "" or stack.metadata == nil then
		local id = turtles.create_floppy_id()
		stack.metadata = tostring(id)
		floppies[id] = string.rep(string.char(0), 16384)
		return floppies[id], true
	elseif string.len(stack.metadata) >= 1000 then
		local id = turtles.create_floppy_id()
		floppies[id] = stack.metadata
		stack.metadata = tostring(id)
		return floppies[id], true
	else
		if floppies[tonumber(stack.metadata)] == nil then
			floppies[tonumber(stack.metadata)] = string.rep(string.char(0), 16384)
		end
		return floppies[tonumber(stack.metadata)], false
	end
end

local function set_floppy_contents(name, contents)
	floppies[tonumber(name)] = contents
end

function on_disk_digiline_receive(turtle_id, channel, msg)
	if channel == "boot" then
		if string.len(msg) ~= 1 and string.len(msg) ~= 65 then return end -- Invalid message, it comes probably from the disk itself
		local page = string.byte(msg, 1)
		if page == nil then return end
		local inv = turtles.get_turtle_inventory(turtle_id)
		local stack = inv:get_stack("floppy", 1):to_table()
		if stack == nil then return end
		if stack.name ~= "turtle:floppy" then return end
		local floppy_contents, update = handle_floppy_meta(stack)
		if update then
			inv:set_stack("floppy", 1, ItemStack(stack))
		end
		msg = string.sub(msg, 2, -1)
		if string.len(msg) == 0 then -- read
			turtle_receptor_send(turtle_id, channel,
				string.sub(floppy_contents, page * 64 + 1, page * 64 + 64))
		else -- write
			floppy_contents = string.sub(floppy_contents, 1, page * 64) ..
			                  msg ..
			                  string.sub(floppy_contents, page * 64 + 65, -1)
			set_floppy_contents(stack.metadata, floppy_contents)
		end
	end
end

minetest.register_craftitem("turtle:floppy", {
	description = "Floppy disk",
	inventory_image = "floppy.png",
	stack_max = 1,
})

local progs = {
	["Empty"] = string.rep(string.char(0), 16536),
	["Forth Boot Disk"] = create_forth_floppy(),
}

minetest.register_node("turtle:floppy_programmator",{
	description = "Floppy disk programmator",
	tiles = {"floppy_programmator_top.png", "floppy_programmator_bottom.png", "floppy_programmator_right.png",
	         "floppy_programmator_left.png", "floppy_programmator_back.png", "floppy_programmator_front.png"},
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("floppy", 1)
		meta:set_int("selected", 1)
		local s = "size[8,5.5;]" ..
			  "dropdown[0,0;5;pselector;"
		for key, _ in pairs(progs) do
			s = s .. key .. ","
		end
		s = string.sub(s, 1, -2)
		s = s .. ";1]" ..
		         "button[5,0;2,1;prog;Program]" ..
		         "list[current_name;floppy;7,0;1,1;]" ..
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
	if formname:sub(1, 7) ~= "turtle:" then return end
	local turtle_id = tonumber(formname:sub(8, -1))
	if fields.f ~= nil and fields.f ~= "" then
		if string.len(fields.f) > 80 then
			fields.f = string.sub(fields.f, 1, 80)
		end
		turtle_receptor_send(turtle_id, "screen", fields.f)
		turtles.update_formspec(turtle_id)
		return
	end
	if fields.reboot then
		local info = turtles.get_turtle_info(turtle_id)
		info.cptr = create_cptr()
		return
	end
	if fields.quit then
		local info = turtles.get_turtle_info(turtle_id)
		info.playernames[player:get_player_name()] = nil
	end
end)

minetest.register_node("turtle:turtle", {
	description = "Turtle",
	drawtype = "airlike",
	inventory_image = "turtle_turtle_inv.png",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	after_place_node = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("floppy", 1)
		inv:set_size("main", 8 * 4)
		inv:set_size("craft", 3 * 3)
		inv:set_size("craft_output", 1)
		local id = turtles.create_turtle_id()
		meta:set_int("turtle_id", id)
		local info = turtles.get_turtle_info(id)
		info.spos = vector.new(pos)
		info.dir = 0
		info.energy = 0
		info.screen = screen.new()
		info.cptr = create_cptr()
		info.playernames = {}
		turtles.update_formspec(id)
		local le = minetest.add_entity(pos, "turtle:turtle"):get_luaentity()
		info.turtle = le
		le.turtle_id = id
	end,
})

minetest.register_node("turtle:turtle2", {
	description = "turtle:turtle2 (You hacker you)",
	groups = {not_in_creative_inventory = 1},
	drawtype = "airlike",
	walkable = false,
	pointable = false,
})

local function done_move(pos, spos, npos)
	return vector.dot(vector.subtract(npos, spos),
	                  vector.subtract(npos, pos)) <= 0
end

local function done_rotation(yaw, nyaw, rotate_speed)
	return (nyaw - yaw + rotate_speed - math.pi / 2) % (2 * math.pi) < math.pi
end

minetest.register_entity("turtle:turtle", {
	physical = true,
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	collides_with_objects = false,
	visual = "wielditem", -- TODO: change that to a mesh, and add animations
	visual_size = {x = 2/3, y = 2/3},
	textures = {"default:wood"},
	on_activate = function(self, staticdata)
		local id = tonumber(staticdata)
		if id ~= nil then
			self.turtle_id = id
			if turtle_infos[self.turtle_id] == nil then
				minetest.set_node(vector.round(self.object:getpos()), {name = "air"})
				self.object:remove()
				return
			end
			local info = turtles.get_turtle_info(self.turtle_id)
			info.turtle = self
		end
	end,
	on_step = function(self, dtime)
		if self.turtle_id == nil then return end
		local info = turtles.get_turtle_info(self.turtle_id)
		if info.rotate then
			self.object:setyaw(self.object:getyaw() + info.rotate * dtime)
		end
		if info.moving then
			if info.npos ~= nil then
				local pos = self.object:getpos()
				local npos = info.npos
				local spos = info.spos
				if done_move(pos, spos, npos) then
					self.object:setpos(npos)
					self.object:setvelocity({x = 0, y = 0, z = 0})
					info.spos = npos
					info.npos = nil
					info.moving = nil
					local meta = minetest.get_meta(spos):to_table()
					minetest.set_node(spos, {name = "air"})
					minetest.set_node(npos, {name = "turtle:turtle"})
					minetest.get_meta(npos):from_table(meta)
					turtles.update_formspec(self.turtle_id)
				else
					self.object:setvelocity(vector.subtract(npos, spos))
				end
			elseif info.ndir ~= nil then
				local yaw = self.object:getyaw()
				local rotate_speed = info.rotate
				local nyaw = info.ndir * math.pi/2
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
			run_computer(self.turtle_id, info.cptr)
		end
		if info.formspec_changed then
			for playername, _ in pairs(info.playernames) do
				if DEBUG then
					print(info.screen)
					print("------------------------------------")
				end
				minetest.show_formspec(playername, "turtle:" .. tostring(self.turtle_id), info.formspec)
			end
			info.formspec_changed = nil
		end
	end,
	on_rightclick = function(self, clicker)
		local info = turtles.get_turtle_info(self.turtle_id)
		local name = clicker:get_player_name()
		info.playernames[name] = true
		minetest.show_formspec(name, "turtle:" .. tostring(self.turtle_id), info.formspec)
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		self.object:remove()
		local info = turtles.get_turtle_info(self.turtle_id)
		local pos = info.spos
		minetest.add_item(pos, "turtle:turtle")
		local inv = minetest.get_meta(pos):get_inventory()
		
		for list, nslots in pairs({["main"] = 8 * 4, ["floppy"] = 1, ["craft"] = 3 * 3}) do
			for slot = 1, nslots do
				minetest.add_item(pos, inv:get_stack(list, slot))
			end
		end
		
		if info.npos then
			minetest.set_node(info.npos, {name = "air"})
		end
		minetest.set_node(pos, {name = "air"})
		turtle_infos[self.turtle_id] = nil
	end,
	get_staticdata = function(self)
		return tostring(self.turtle_id)
	end,
})
