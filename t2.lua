local DEBUG = true

-------------------------
-- Read data from file --
-------------------------

local turtle_infos = db.read_file("turtle_infos")

minetest.register_on_shutdown(function()
	for id, info in pairs(turtle_infos) do
		info.turtle = nil
		info.playernames = {}
	end
	db.write_file("turtle_infos", turtle_infos)
end)

------------------
-- Some helpers --
------------------

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

function turtles.update_formspec(turtle_id)
	local info = turtles.get_turtle_info(turtle_id)
	local pos = info.spos
	local formspec = "size[13,9]"..
		screen.create_text_formspec(info.screen, 0, 0)..
		"list[nodemeta:"..pos.x..","..pos.y..","..pos.z..";main;4.8,0;8,4;]"..
		"image_button[1,7.6;2.5,1;turtle_reboot.png;reboot;]"..
		"list[nodemeta:"..pos.x..","..pos.y..","..pos.z..";floppy;0,7.6;1,1;]"..
		"list[current_player;main;4.8,4.6;8,4;]"
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

local function on_disk_digiline_receive(turtle, channel, msg)
	local inv = turtles.get_turtle_inventory(turtle)
	floppy.disk_digiline_receive(inv, channel, msg, "boot",
		function(msg) turtle_receptor_send(turtle, "boot", msg) end)
end

function turtle_receptor_send(turtle, channel, msg)
	on_screen_digiline_receive(turtle, channel, msg)
	on_computer_digiline_receive(turtle, channel, msg)
	on_disk_digiline_receive(turtle, channel, msg)
	local info = turtles.get_turtle_info(turtle)
	digiline:receptor_send(info.spos, digiline.rules.default, channel, msg)
end

local function turtle_receive(turtle, channel, msg)
	on_screen_digiline_receive(turtle, channel, msg)
	on_computer_digiline_receive(turtle, channel, msg)
	on_disk_digiline_receive(turtle, channel, msg)
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
		return true
	end
	if fields.reboot then
		local info = turtles.get_turtle_info(turtle_id)
		info.cptr = create_cptr()
		return true
	end
	if fields.quit then
		local info = turtles.get_turtle_info(turtle_id)
		info.playernames[player:get_player_name()] = nil
	end
	return true
end)

local function update_craftpreview(turtle)
	local inv = turtles.get_turtle_inventory(turtle)
	local info = turtles.get_turtle_info(turtle)
	local dir = minetest.facedir_to_dir(info.dir)
	local player = turtles.create_turtle_player(turtle, dir, 0)
	inv:set_stack("craftpreview", 1,
		minetest.craft_predict(
			minetest.get_craft_result({method = "normal", items = inv:get_list("craft"), width = inv:get_width("craft")}).item,
			player,
			inv:get_list("craft"),
			inv))
end

minetest.register_node("turtle:turtle", {
	description = "Turtle",
	drawtype = "airlike",
	inventory_image = "turtle_turtle_inv.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	digiline = 
	{
		receptor = {},
		effector = {action = function(pos, node, channel, msg)
			local meta = minetest.get_meta(pos)
			local turtle = meta:get_int("turtle_id")
			turtle_receive(turtle, channel, msg)
		end},
	},
	after_place_node = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("floppy", 1)
		inv:set_size("main", 8 * 4)
		inv:set_size("craft", 3 * 3)
		inv:set_width("craft", 3)
		inv:set_size("craftpreview", 1)
		inv:set_size("craftresult", 1)
		local id = turtles.create_turtle_id()
		meta:set_int("turtle_id", id)
		local info = turtles.get_turtle_info(id)
		info.spos = vector.new(pos)
		info.dir = 0
		info.energy = 0
		info.wield_index = 1
		info.screen = screen.new()
		info.cptr = create_cptr()
		info.playernames = {}
		turtles.update_formspec(id)
		local le = minetest.add_entity(pos, "turtle:turtle"):get_luaentity()
		info.turtle = le
		le.turtle_id = id
	end,
	on_metadata_inventory_move = function(pos)
		update_craftpreview(minetest.get_meta(pos):get_int("turtle_id"))
	end,
	on_metadata_inventory_take = function(pos)
		update_craftpreview(minetest.get_meta(pos):get_int("turtle_id"))
	end,
	on_metadata_inventory_put = function(pos)
		update_craftpreview(minetest.get_meta(pos):get_int("turtle_id"))
	end,
	on_rightclick = function(pos, node, clicker)
		local turtle_id = minetest.get_meta(pos):get_int("turtle_id")
		local info = turtles.get_turtle_info(turtle_id)
		local name = clicker:get_player_name()
		info.playernames[name] = true
		minetest.show_formspec(name, "turtle:" .. tostring(turtle_id), info.formspec)
	end,
})

minetest.register_node("turtle:turtle2", {
	description = "turtle:turtle2 (You hacker you)",
	groups = {not_in_creative_inventory = 1},
	drawtype = "airlike",
	paramtype = "light",
	walkable = false,
	pointable = false,
	sunlight_propagates = true,
})

local function done_move(pos, spos, npos)
	return vector.dot(vector.subtract(npos, spos),
	                  vector.subtract(npos, pos)) <= 0
end

local function done_rotation(yaw, nyaw, rotate_speed)
	return (((nyaw - yaw + rotate_speed) % (2 * math.pi)) - math.pi) * (((nyaw - yaw) % (2 * math.pi) - math.pi)) <= 0
end

minetest.register_entity("turtle:turtle", {
	physical = true,
	collisionbox = {-0.4999, -0.4999, -0.4999, 0.4999, 0.4999, 0.4999}, -- Not 0.5 to avoid the turtle being stuck due to rounding errors
	collides_with_objects = false,
	--visual = "wielditem", -- TODO: change that to a mesh, and add animations
	--visual_size = {x = 2/3, y = 2/3},
	--textures = {"default:wood"},
	visual = "mesh",
	mesh = "turtle.obj",
	textures = {"turtle.png"},
	visual_size = {x = 10, y = 10},
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
				local nyaw = -info.ndir * math.pi/2
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
		if self.turtle_id == nil then return end
		local info = turtles.get_turtle_info(self.turtle_id)
		local name = clicker:get_player_name()
		info.playernames[name] = true
		minetest.show_formspec(name, "turtle:" .. tostring(self.turtle_id), info.formspec)
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if self.turtle_id == nil then return end
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
		if self.turtle_id == nil then return "" end
		return tostring(self.turtle_id)
	end,
})
