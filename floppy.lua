floppy = {}

local floppies = db.read_file("floppies")

minetest.register_on_shutdown(function()
	db.write_file("floppies", floppies)
end)

local function create_floppy_id()
	return #floppies + 1
end

local function handle_floppy_meta(stack)
	if stack.metadata == "" or stack.metadata == nil then
		local id = create_floppy_id()
		stack.metadata = tostring(id)
		floppies[id] = string.rep(string.char(0), 16384)
		return floppies[id], true
	elseif string.len(stack.metadata) >= 1000 then
		local id = create_floppy_id()
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
			if stack.name ~= "turtle:floppy" or stack.count == 0 then return end
			local contents, update = handle_floppy_meta(stack)
			set_floppy_contents(stack.metadata, prog)
			if update then
				inv:set_stack("floppy", 1, ItemStack(stack))
			end
		end
	end,
})

function floppy.disk_digiline_receive(inv, channel, msg, disk_channel, send_func)
	if channel == disk_channel then
		if string.len(msg) ~= 1 and string.len(msg) ~= 65 then return end -- Invalid message, it comes probably from the disk itself
		local page = string.byte(msg, 1)
		if page == nil then return end
		local stack = inv:get_stack("floppy", 1):to_table()
		if stack == nil then return end
		if stack.name ~= "turtle:floppy" then return end
		local floppy_contents, update = handle_floppy_meta(stack)
		if update then
			inv:set_stack("floppy", 1, ItemStack(stack))
		end
		msg = string.sub(msg, 2, -1)
		if string.len(msg) == 0 then -- read
			send_func(string.sub(floppy_contents, page * 64 + 1, page * 64 + 64))
		else -- write
			floppy_contents = string.sub(floppy_contents, 1, page * 64) ..
			                  msg ..
			                  string.sub(floppy_contents, page * 64 + 65, -1)
			set_floppy_contents(stack.metadata, floppy_contents)
		end
	end
end

minetest.register_node("turtle:disk",{
	description = "Disk drive",
	paramtype2 = "facedir",
	tiles = {"floppy_drive_top.png", "floppy_drive_bottom.png", "floppy_drive_right.png", "floppy_drive_left.png", "floppy_drive_back.png", "floppy_drive_front.png"},
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	digiline = 
	{
		receptor = {},
		effector = {action = function(pos, node, channel, msg)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local disk_channel = meta:get_string("channel")
			floppy.disk_digiline_receive(inv, channel, msg, disk_channel, function(msg)
				digiline:receptor_send(pos, digiline.rules.default, disk_channel, msg)
			end)
		end},
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
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
		if stack:get_name() == "turtle:floppy" then return 1 end
		return 0
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		fields.channel = fields.channel or meta:get_string("channel")
		meta:set_string("channel", fields.channel)
	end,
})
