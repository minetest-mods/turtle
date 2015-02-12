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

