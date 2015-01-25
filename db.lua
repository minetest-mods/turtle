db = {}

local worldpath = minetest.get_worldpath() .. "/"
function db.read_file(filename)
	local file = io.open(worldpath .. filename, "r")
	if file == nil then
		return {}
	end
	local contents = file:read("*all")
	file:close()
	if contents == "" or contents == nil then
		return {}
	end
	return minetest.deserialize(contents)
end

function db.write_file(filename, data)
	local file = io.open(worldpath .. filename, "w")
	file:write(minetest.serialize(data))
	file:close()
end
