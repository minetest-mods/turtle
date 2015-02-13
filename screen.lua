screen = {}

local MAX_LINE_LENGTH = 28
local function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

local function newline(text, toadd)
	local f = lines(text)
	table.insert(f, toadd)
	return table.concat(f, "\n", 2)
end

local function add_char(text, char)
	local ls = lines(text)
	local ll = ls[#ls]
	if char == "\n" or char == "\r" then
		return newline(text, "")
	elseif string.len(ll) >= MAX_LINE_LENGTH then
		return newline(text, char)
	else
		return text .. char
	end
end

local function escape(text)
	-- Remove all \0's in the string, that cannot be done using string.gsub as there can't be \0's in a pattern
	local text2 = ""
	for i = 1, string.len(text) do
		if string.byte(text, i) ~= 0 then text2 = text2 .. string.sub(text, i, i) end
	end
	return minetest.formspec_escape(text2)
end

function screen.new()
	return "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
end

function screen.add_text(text, toadd)
	for i = 1, string.len(toadd) do
		text = add_char(text, string.sub(toadd, i, i))
	end
	return text
end

function screen.create_text_formspec(text, basex, basey)
	local f = lines(text)
	local s = ""
	local i = basey - 0.25
	for _, x in ipairs(f) do
		s = s .. "]label[" .. basex .. "," .. tostring(i) .. ";" .. escape(x)
		i = i + 0.3
	end
	s = s .. "]field[" .. tostring(basex + 0.3) .. "," .. tostring(i + 0.4) .. ";4.4,1;f;;]"
	return s:sub(2, -1)
end

------------------
-- Screen nodes --
------------------

local screens = {}

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

local function screen_digiline_receive(pos, node, channel, msg)
	local meta = minetest.get_meta(pos)
	if channel == meta:get_string("channel") then
		local ntext = screen.add_text(meta:get_string("text"), msg)
		meta:set_string("text", ntext)
		local hash = hashpos(pos)
		if not screens[hash] then
			screens[hash] = {pos = vector.new(pos), fmodif = true, playernames = {}}
		else
			screens[hashpos(pos)].fmodif = true
		end
	end
end

local function create_screen_formspec(text)
	return "size[5,4.5;]" .. screen.create_text_formspec(text, 0, 0)
end

minetest.register_globalstep(function(dtime)
	for screenhash, i in pairs(screens) do
		if i.fmodif then
			i.fmodif = false
			local meta = minetest.get_meta(i.pos)
			for pname, _ in pairs(i.playernames) do
				minetest.show_formspec(pname, "screen" .. screenhash,
					create_screen_formspec(meta:get_string("text")))
			end
		end
	end
end)

local MAX_TEXT_SEND = 80
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1,6) ~= "screen" then return end
	local hash = formname:sub(7, -1)
	local s = screens[hash]
	if s == nil then return end
	local pos = s.pos
	if fields["f"] == nil or fields["f"] == "" then
		if fields["quit"] ~= nil then
			s.playernames[player:get_player_name()] = nil
		end
		return
	end
	if string.len(fields["f"]) > MAX_TEXT_SEND then
		fields["f"] = string.sub(fields["f"], 1, MAX_TEXT_SEND)
	end
	digiline:receptor_send(pos, digiline.rules.default, "screen", fields["f"])
	local meta = minetest.get_meta(pos)
	local ntext = screen.add_text(meta:get_string("text"), fields["f"])
	meta:set_string("text", ntext)
	minetest.show_formspec(player:get_player_name(), formname, create_screen_formspec(ntext))
end)

minetest.register_node("turtle:screen", {
	description = "Screen",
	tiles = {"screen_top.png", "screen_bottom.png", "screen_right.png", "screen_left.png", "screen_back.png", "screen_front.png"},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	node_box = {
		type = "fixed",
		fixed = {
				{ -16/32, -16/32, 1/32, 16/32, 16/32, 13/32 }, -- Monitor Screen
				{ -13/32, -13/32, 13/32, 13/32, 13/32, 16/32 }, -- Monitor Tube
				{ -16/32, -16/32, -16/32, 16/32, -12/32, 1/32 }, -- Keyboard
			}
	},
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	digiline = 
	{
		receptor = {},
		effector = {action = screen_digiline_receive},
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("text", "\n\n\n\n\n\n\n\n\n\n\n\n")
		screens[hashpos(pos)] = {pos = pos, fmodif = false, playernames = {}}
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
		local hash = hashpos(pos)
		if screens[hash] == nil then
			screens[hash] = {pos = pos, fmodif = false, playernames = {}}
		end
		screens[hash].playernames[name] = true
		minetest.show_formspec(name, "screen" .. hash,
			create_screen_formspec(meta:get_string("text")))
	end,
})

