-- Turtle mod for Minetest
-- License: LGPL

local FUEL_EFFICIENCY = 3	-- How many moves can the turtle do with a second fuel
local TURTLES_FORCE_LOAD = true	-- Useless for now, has to wait until force_load is merged



--TODO: Change serialization so that it supports functions
local safe_serialize = function(value)
	return minetest.serialize(value)
end
local safe_deserialize = minetest.deserialize

local turtle_invs
local turtle_updates

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

local get_turtle_info

turtle_infos = read_file(wpath.."/turtle_infos")
for _,i in pairs(turtle_infos) do
	if i["co"]~= nil then
		local env=create_environment(_)
		i["co"]=pluto.unpersist({["coroutine.yield"]=env.coroutine.yield,
					["turtle.forward"]=env.turtle.forward,
					["delay"]=env.delay},i["co"])
		i["env"]=env
	end
end
turtle_updates = read_file(wpath.."/turtle_updates")

turtle_updates_to_add={}

local tupdate

minetest.register_globalstep(function(dtime)
	for _, timer in ipairs(turtle_updates_to_add) do
		table.insert(turtle_updates, timer)
	end
	turtle_updates_to_add = {}
	for index, timer in ipairs(turtle_updates) do
		local info = get_turtle_info(timer.update.turtle)
		if info["turtle"]~=nil then --turtle is loaded
			timer.time = timer.time - dtime
			if timer.time <= 0 then
				tupdate(timer.update)
				table.remove(turtle_updates,index)
			end
		end
	end
end)

minetest.register_globalstep(function(dtime)
	for _,i in ipairs(turtle_infos) do
		wait = i["wait"]
		print(wait)
		if wait~=nil then
			wait = wait-dtime
			if wait<=0 then
				_,wait=coroutine.resume(i["co"])
				print(dump(_))
			end
			i["wait"]=wait
		end
	end
end)

local function turtle_add_update(time, update)
	table.insert(turtle_updates_to_add, {time=time, update=update})
end

minetest.register_on_shutdown(function()
	for turtle,i in pairs(turtle_infos) do
		i["turtle"]=nil
		i["inventory"]=serialize_inv(turtle_invs:get_list(turtle))
		if i["co"]~=nil then
			env = i["env"]
			i["env"]=nil
			print("Serialize")
			local perms={[env.turtle.forward]="turtle.forward",
						[env.delay]="delay",
						[env.coroutine.yield]="coroutine.yield"}
			print("Perms set")
			i["co"]=pluto.persist(perms,i["co"])
			print("Done")
		end
	end
	write_file(wpath.."/turtle_infos",turtle_infos)
	for _, timer in ipairs(turtle_updates_to_add) do
		table.insert(turtle_updates, timer)
	end
	write_file(wpath.."/turtle_updates",turtle_updates)
end)

get_turtle_info = function(turtle)
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

local function round_pos(p)
	return {x=math.floor(p.x+0.5),
		y=math.floor(p.y+0.5),
		z=math.floor(p.z+0.5)}
end

local update_formspec = function(turtle, code, errmsg, filename, player, exit)
	local info = get_turtle_info(turtle)
	info["code"]=code or ""
	if minetest.formspec_escape then
		code = minetest.formspec_escape(code or "")
		errmsg = minetest.formspec_escape(errmsg or "")
	else
		code = string.gsub(code or "", "%[", "(") -- would otherwise
		code = string.gsub(code, "%]", ")") -- corrupt formspec
		errmsg = string.gsub(errmsg or "", "%[", "(") -- would otherwise
		errmsg = string.gsub(errmsg, "%]", ")") -- corrupt formspec
	end
	info["filename"] = filename
	info["formspec"]= "size[9,10]"..
		"textarea[0.3,0;4.7,5;code;;"..code.."]"..
		"list[detached:turtle:invs;"..turtle..";4.8,0;4,4;]"..
		"image_button[0,4.6;2.5,1;turtle_execute.png;program;]"..
		"image_button_exit[8.72,-0.25;0.425,0.4;turtle_close.png;exit;]"..
		"label[4.6,4;"..errmsg.."]"..
		"list[current_player;main;0.5,6;8,4;]"..
		"field[3,5;4,1;filename;Filename:;"..filename.."]"..
		"button[7,4.65;1,1;open;Open]"..
		"button[8,4.65;1,1;save;Save]"
	info["heat"]=0
	if exit==nil then
		minetest.show_formspec(player:get_player_name(), turtle, info["formspec"])
	end
end

--------------------
-- Overheat stuff --
--------------------

local heat = function (turtle) -- warm up
	local info = get_turtle_info(turtle)
	local h = info["heat"]
	if h ~= nil then
		info["heat"]=h+1
	else
		info["heat"]=1
	end
end

local cool = function (turtle) -- cool down after a while
	local info = get_turtle_info(turtle)
	local h = info["heat"]
	if h ~= nil then
		info["heat"]=h-1
	end
end

local overheat = function (turtle) -- determine if too hot
	local info = get_turtle_info(turtle)
	local h = info["heat"]
	return h==nil or h>400
end

-------------------
-- Parsing stuff --
-------------------

local code_prohibited = function(code)
	-- Clean code
	local prohibited = {"while", "for", "repeat", "until", "goto"}--, "function"}
	for _, p in ipairs(prohibited) do
		if string.find(code, "%A"..p.."%A") then
			return "Prohibited command: "..p
		end
	end
end

local safe_print = function(param)
	print(dump(param))
end

local interrupt = function(params)
	turtle_update(params.turtle, {type="interrupt", iid = params.iid})
end

local getinterrupt = function(turtle)
	local interrupt = function (time, iid) -- iid = interrupt id
		if type(time) ~= "number" then return end
		local iid = iid or math.random()
		local info = get_turtle_info(turtle)
		--local interrupts = safe_deserialize(info["interrupts"]) or {}
		local interrupts = info["interrupts"] or {}
		local found = false
		local search = safe_serialize(iid)
		for _, i in ipairs(interrupts) do
			if safe_serialize(i) == search then
				found = true
				break
			end
		end
		if not found then
			table.insert(interrupts, iid)
			--info["interrupts"]= safe_serialize(interrupts)
			info["interrupts"]=interrupts
		end
		turtle_add_update(time, {turtle=turtle, type="interrupt", iid = iid})
	end
	return interrupt
end

local function getv(dir)
	if dir==0 then return {x=0,y=0,z=1}
	elseif dir==1 then return {x=1,y=0,z=0}
	elseif dir==2 then return {x=0,y=0,z=-1}
	elseif dir==3 then return {x=-1,y=0,z=0} end
end

local function v3add(v1,v2)
	return {x=v1.x+v2.x,y=v1.y+v2.y,z=v1.z+v2.z}
end

local function turtle_can_go(nname)
	return nname=="air" or minetest.registered_nodes[nname].liquidtype~="none"
end

local function stack_set_count(stack, count)
	stack = stack:to_table()
	if stack==nil then return nil end
	stack.count=count
	return ItemStack(stack)
end

--------------------------
--    /\     |--\    |  --
--   /--\    |__/    |  --
--  /    \   |       |  --
--------------------------

tupdate = function(update)
	local turtle = update.turtle
	local t = update.type
	local info = get_turtle_info(turtle)
	if t=="failmove" then
		turtle_update(turtle,{type="failmove",iid=update.iid})
	elseif t=="endmove" then
		info["moveint"]=nil
		info["spos"]=info["npos"]
		info["npos"]=nil
		local tobject = info["turtle"]
		tobject.object:setvelocity({x=0,y=0,z=0})
		tobject.object:setpos(info["spos"])
		turtle_update(turtle,{type="endmove",iid=update.iid})
	elseif t=="endturn" then
		info["moveint"]=nil
		info["dir"]=info["ndir"]
		info["ndir"]=nil
		info["rotate"]=nil
		local tobject = info["turtle"]
		tobject.object:setyaw(info["dir"]*math.pi/2)
		turtle_update(turtle,{type="endmove",iid=update.iid})
	elseif t=="interrupt" then
		interrupt(update)
	elseif t=="cool" then
		cool(turtle)
	end
end

get_turtle_funcs = function(turtle)	
	return {
		forward = function()
			local info = get_turtle_info(turtle)
			local tobject = info["turtle"]
			--if info["fuel"]==0 then
			--	coroutine.yield(0)
			--	return false
			--end
			--if info["moveint"]==nil then
				local spos = info["spos"]
				local dir = info["dir"]
				info["npos"] = v3add(spos, getv(dir))
				if not turtle_can_go(minetest.env:get_node(info["npos"]).name) then
					info["npos"]=nil
					coroutine.yield(0)
					return false
				end
				info["fuel"]=info["fuel"]-1
				--info["moveint"]=true
				tobject.object:setvelocity(getv(dir))
				coroutine.yield(1)
				info["spos"]=info["npos"]
				info["npos"]=nil
				tobject.object:setvelocity({x=0,y=0,z=0})
				tobject.object:setpos(info["spos"])
				return true
			--else
			--	coroutine.yield(0) -- How did this happen ?
			--	return false
			--end
		end,
		--[[back = function(iid)
			if iid==nil then iid="nil" end
			local info = get_turtle_info(turtle)
			local tobject = info["turtle"]
			if info["fuel"]==0 then
				turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
				return
			end
			if info["moveint"]==nil then
				local spos = info["spos"]
				local dir = (info["dir"]+2)%4
				info["npos"] = v3add(spos, getv(dir))
				if not turtle_can_go(minetest.env:get_node(info["npos"]).name) then
					info["npos"]=nil
					turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
					return
				end
				info["fuel"]=info["fuel"]-1
				info["moveint"]=iid
				tobject.object:setvelocity(getv(dir))
				turtle_add_update(1,{turtle=turtle, type="endmove", iid=iid})
			else
				turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
			end
		end,
		up = function(iid)
			if iid==nil then iid="nil" end
			local info = get_turtle_info(turtle)
			local tobject = info["turtle"]
			if info["fuel"]==0 then
				turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
				return
			end
			if info["moveint"]==nil then
				local spos = info["spos"]
				info["npos"] = v3add(spos, {x=0,y=1,z=0})
				if not turtle_can_go(minetest.env:get_node(info["npos"]).name) then
					info["npos"]=nil
					turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
					return
				end
				info["fuel"]=info["fuel"]-1
				info["moveint"]=iid
				tobject.object:setvelocity({x=0,y=1,z=0})
				turtle_add_update(1,{turtle=turtle, type="endmove", iid=iid})
			else
				turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
			end
		end,
		down = function(iid)
			if iid==nil then iid="nil" end
			local info = get_turtle_info(turtle)
			local tobject = info["turtle"]
			if info["fuel"]==0 then
				turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
				return
			end
			if info["moveint"]==nil then
				local spos = info["spos"]
				info["npos"] = v3add(spos, {x=0,y=-1,z=0})
				if not turtle_can_go(minetest.env:get_node(info["npos"]).name) then
					info["npos"]=nil
					turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
					return
				end
				info["fuel"]=info["fuel"]-1
				info["moveint"]=iid
				tobject.object:setvelocity({x=0,y=-1,z=0})
				turtle_add_update(1,{turtle=turtle, type="endmove", iid=iid})
			else
				turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
			end
		end,
		turnleft = function(iid)
			if iid==nil then iid="nil" end
			local info = get_turtle_info(turtle)
			local tobject = info["turtle"]
			if info["moveint"]==nil then
				local dir = info["dir"]
				info["ndir"]=(dir+3)%4
				info["moveint"]=iid
				info["rotate"]=math.pi/2
				turtle_add_update(1,{turtle=turtle, type="endturn", iid=iid})
			else
				turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
			end
		end,
		turnright = function(iid)
			if iid==nil then iid="nil" end
			local info = get_turtle_info(turtle)
			local tobject = info["turtle"]
			if info["moveint"]==nil then
				local dir = info["dir"]
				info["ndir"]=(dir+1)%4
				info["moveint"]=iid
				info["rotate"]=-math.pi/2
				turtle_add_update(1,{turtle=turtle, type="endturn", iid=iid})
			else
				turtle_add_update(0,{turtle=turtle, type="failmove", iid=iid})
			end
		end,
		detect = function()
			local info = get_turtle_info(turtle)
			local pos = v3add(info["spos"],getv(info["dir"]))
			return minetest.env:get_node(pos).name
		end,
		detectup = function()
			local info = get_turtle_info(turtle)
			local pos = v3add(info["spos"],{x=0,y=1,z=0})
			return minetest.env:get_node(pos).name
		end,
		detectdown = function()
			local info = get_turtle_info(turtle)
			local pos = v3add(info["spos"],{x=0,y=-1,z=0})
			return minetest.env:get_node(pos).name
		end,
		dig = function()
			local info = get_turtle_info(turtle)
			local dpos = v3add(info["spos"],getv(info["dir"]))
			local dnode = minetest.env:get_node(dpos)
			if turtle_can_go(dnode.name) or dnode.name=="ignore" then return false end
			local drops = minetest.get_node_drops(dnode.name, "default:pick_mese")
			local _, dropped_item
			for _, dropped_item in ipairs(drops) do
				local leftover = turtle_invs:add_item(turtle,dropped_item)
				minetest.env:add_item(info["spos"],leftover)
			end
			minetest.env:remove_node(dpos)
			return true
		end,
		digup = function()
			local info = get_turtle_info(turtle)
			local dpos = v3add(info["spos"],{x=0,y=1,z=0})
			local dnode = minetest.env:get_node(dpos)
			if turtle_can_go(dnode.name) or dnode.name=="ignore" then return false end
			local drops = minetest.get_node_drops(dnode.name, "default:pick_mese")
			local _, dropped_item
			for _, dropped_item in ipairs(drops) do
				local leftover = turtle_invs:add_item(turtle,dropped_item)
				minetest.env:add_item(info["spos"],leftover)
			end
			minetest.env:remove_node(dpos)
			return true
		end,
		digdown = function()
			local info = get_turtle_info(turtle)
			local dpos = v3add(info["spos"],{x=0,y=-1,z=0})
			local dnode = minetest.env:get_node(dpos)
			if turtle_can_go(dnode.name) or dnode.name=="ignore" then return false end
			local drops = minetest.get_node_drops(dnode.name, "default:pick_mese")
			local _, dropped_item
			for _, dropped_item in ipairs(drops) do
				local leftover = turtle_invs:add_item(turtle,dropped_item)
				minetest.env:add_item(info["spos"],leftover)
			end
			minetest.env:remove_node(dpos)
			return true
		end,
		place = function(slot)
			local info = get_turtle_info(turtle)
			local ppos = v3add(info["spos"],getv(info["dir"]))
			local dnode = minetest.env:get_node(ppos)
			if (not turtle_can_go(dnode.name)) or dnode.name=="ignore" then return false end
			local stack = turtle_invs:get_stack(turtle,slot)
			if stack:is_empty() or minetest.registered_nodes[stack:get_name()]==nil then return false end
			minetest.env:set_node(ppos, {name=stack:get_name()})
			stack:take_item()
			turtle_invs:set_stack(turtle, slot, stack)
			return true
		end,
		placeup = function(slot)
			local info = get_turtle_info(turtle)
			local ppos = v3add(info["spos"],{x=0,y=1,z=0})
			local dnode = minetest.env:get_node(ppos)
			if (not turtle_can_go(dnode.name)) or dnode.name=="ignore" then return false end
			local stack = turtle_invs:get_stack(turtle,slot)
			if stack:is_empty() or minetest.registered_nodes[stack:get_name()]==nil then return false end
			minetest.env:set_node(ppos, {name=stack:get_name()})
			stack:take_item()
			turtle_invs:set_stack(turtle, slot, stack)
			return true
		end,
		placedown = function(slot)
			local info = get_turtle_info(turtle)
			local ppos = v3add(info["spos"],{x=0,y=-1,z=0})
			local dnode = minetest.env:get_node(ppos)
			if (not turtle_can_go(dnode.name)) or dnode.name=="ignore" then return false end
			local stack = turtle_invs:get_stack(turtle,slot)
			if stack:is_empty() or minetest.registered_nodes[stack:get_name()]==nil then return false end
			minetest.env:set_node(ppos, {name=stack:get_name()})
			stack:take_item()
			turtle_invs:set_stack(turtle, slot, stack)
			return true
		end,
		getstack = function(slot)
			local s = turtle_invs:get_stack(turtle,slot):to_table()
			if s==nil then return {name="", count=0} end
			return s
		end,
		moveto = function(slot1,slot2, nmax)
			local stack1 = turtle_invs:get_stack(turtle,slot1)
			local stack2 = turtle_invs:get_stack(turtle,slot2)
			local move
			if nmax==0 then nmax = stack1:get_count() end
			if stack2:is_empty() then
				move = math.min(stack1:get_count(), nmax)
				local taken = stack1:take_item(move)
				stack2:add_item(taken)
			else
				if stack1:get_name()~=stack2:get_name() then return 0 end
				move = math.min(stack1:get_count(), stack2:get_free_space(), nmax)
				local taken = stack1:take_item(move)
				stack2:add_item(taken)
			end
			turtle_invs:set_stack(turtle,slot1,stack1)
			turtle_invs:set_stack(turtle,slot2,stack2)
			return move
		end,
		refuel = function(slot, nmax)
			local info = get_turtle_info(turtle)
			local stack = turtle_invs:get_stack(turtle, slot)
			local fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = {stack}})
			if fuel.time<=0 then return false end
			if nmax==nil then nmax=stack:get_count() end
			local count = math.min(stack:get_count(), nmax)
			local fs = stack:to_table()
			fs["count"]=1
			local fstack = ItemStack(fs)
			local fuel, afterfuel
			fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = {fstack}})
			info["fuel"]=info["fuel"]+FUEL_EFFICIENCY*count*fuel.time
			stack:take_item(count)
			if afterfuel~=nil then
				afterfuel = afterfuel.items[1]
			end
			if afterfuel~=nil then
				afterfuel = stack_set_count(afterfuel, afterfuel:get_count()*count)
			end
			if afterfuel~=nil then
				local leftover = stack:add_item(ItemStack(afterfuel))
				turtle_invs:set_stack(turtle, slot, stack)
				local leftover2 = turtle_invs:add_item(turtle, leftover)
				minetest.env:add_item(info["spos"],leftover2)
			else
				turtle_invs:set_stack(turtle, slot, stack)
			end
		end,
		get_fuel_time = function()
			local info = get_turtle_info(turtle)
			return info["fuel"]
		end,
		craft = function(nmax)
			local info = get_turtle_info(turtle)
			local invl = turtle_invs:get_list(turtle)
			local recipe = {}
			local craftmax=nmax
			for i=1,16 do
				recipe[i]=ItemStack({name=invl[i]:get_name(),count=1})
				if invl[i]:get_count()>0 then
					craftmax=math.min(craftmax, invl[i]:get_count())
				end
			end
			local result,new=minetest.get_craft_result({method="normal",width=4,items=recipe})
			if result.item:is_empty() then return 0 end
			result=result.item
			for i=1,16 do
				invl[i]:take_item(craftmax)
				turtle_invs:set_stack(turtle, i, invl[i])
			end
			result = stack_set_count(result, result:get_count()*craftmax)
			local leftover = turtle_invs:add_item(turtle,result)
			minetest.env:add_item(info["spos"],leftover)
			for i=1,16 do
				local s=stack_set_count(new.items[i], new.items[i]:get_count()*craftmax)
				if s~=nil then
					local leftover = turtle_invs:add_item(turtle,s)
					minetest.env:add_item(info["spos"],leftover)
				end
			end
		end,
		drop = function(slot)
			local info = get_turtle_info(turtle)
			local stack = turtle_invs:get_stack(turtle, slot)
			turtle_invs:set_stack(turtle, slot, ItemStack(""))
			local spos = info["spos"]
			local item = tube_item({x=spos.x,y=spos.y,z=spos.z},stack)
			item:get_luaentity().start_pos = {x=spos.x,y=spos.y,z=spos.z}
			item:setvelocity(getv(info["dir"]))		
		end,
		dropup = function(slot)
			local info = get_turtle_info(turtle)
			local stack = turtle_invs:get_stack(turtle, slot)
			turtle_invs:set_stack(turtle, slot, ItemStack(""))
			local spos = info["spos"]
			local item = tube_item({x=spos.x,y=spos.y,z=spos.z},stack)
			item:get_luaentity().start_pos = {x=spos.x,y=spos.y,z=spos.z}
			item:setvelocity({x=0,y=1,z=0})		
		end,
		dropdown = function(slot)
			local info = get_turtle_info(turtle)
			local stack = turtle_invs:get_stack(turtle, slot)
			turtle_invs:set_stack(turtle, slot, ItemStack(""))
			local spos = info["spos"]
			local item = tube_item({x=spos.x,y=spos.y,z=spos.z},stack)
			item:get_luaentity().start_pos = {x=spos.x,y=spos.y,z=spos.z}
			item:setvelocity({x=0,y=-1,z=0})		
		end,
		suck = function()
			local info = get_turtle_info(turtle)
			local frompos=v3add(info["spos"],getv(info["dir"]))
			local fromnode=minetest.env:get_node(frompos)
			local frominv
			if not (minetest.registered_nodes[fromnode.name].tube and 
				minetest.registered_nodes[fromnode.name].tube.input_inventory) then
				for _,object in ipairs(minetest.env:get_objects_inside_radius(frompos, 1)) do
					if not object:is_player() and object:get_luaentity() and object:get_luaentity().name == "__builtin:item" then
						if object:get_luaentity().itemstring ~= "" then
							local leftover = turtle_invs:add_item(turtle,ItemStack(object:get_luaentity().itemstring))
							minetest.env:add_item(info["spos"],leftover)
							object:get_luaentity().itemstring = ""
							object:remove()
							return
						end
					end
				end
				return
			end
			local frommeta=minetest.env:get_meta(frompos)
			local frominvname=minetest.registered_nodes[fromnode.name].tube.input_inventory
			local frominv=frommeta:get_inventory()
			for spos,stack in ipairs(frominv:get_list(frominvname)) do
				if stack:get_name()~="" then
					local leftover = turtle_invs:add_item(turtle,stack)
					frominv:set_stack(spos, leftover)
					return
				end
			end
		end,
		suckup = function()
			local info = get_turtle_info(turtle)
			local frompos=v3add(info["spos"],{x=0,y=1,z=0})
			local fromnode=minetest.env:get_node(frompos)
			local frominv
			if not (minetest.registered_nodes[fromnode.name].tube and 
				minetest.registered_nodes[fromnode.name].tube.input_inventory) then
				for _,object in ipairs(minetest.env:get_objects_inside_radius(frompos, 1)) do
					if not object:is_player() and object:get_luaentity() and object:get_luaentity().name == "__builtin:item" then
						if object:get_luaentity().itemstring ~= "" then
							local leftover = turtle_invs:add_item(turtle,ItemStack(object:get_luaentity().itemstring))
							minetest.env:add_item(info["spos"],leftover)
							object:get_luaentity().itemstring = ""
							object:remove()
							return
						end
					end
				end
				return
			end
			local frommeta=minetest.env:get_meta(frompos)
			local frominvname=minetest.registered_nodes[fromnode.name].tube.input_inventory
			local frominv=frommeta:get_inventory()
			for spos,stack in ipairs(frominv:get_list(frominvname)) do
				if stack:get_name()~="" then
					local leftover = turtle_invs:add_item(turtle,stack)
					frominv:set_stack(spos, leftover)
					return
				end
			end
		end,
		suckdown = function()
			local info = get_turtle_info(turtle)
			local frompos=v3add(info["spos"],{x=0,y=-1,z=0})
			local fromnode=minetest.env:get_node(frompos)
			local frominv
			if not (minetest.registered_nodes[fromnode.name].tube and 
				minetest.registered_nodes[fromnode.name].tube.input_inventory) then
				for _,object in ipairs(minetest.env:get_objects_inside_radius(frompos, 1)) do
					if not object:is_player() and object:get_luaentity() and object:get_luaentity().name == "__builtin:item" then
						if object:get_luaentity().itemstring ~= "" then
							local leftover = turtle_invs:add_item(turtle,ItemStack(object:get_luaentity().itemstring))
							minetest.env:add_item(info["spos"],leftover)
							object:get_luaentity().itemstring = ""
							object:remove()
							return
						end
					end
				end
				return
			end
			local frommeta=minetest.env:get_meta(frompos)
			local frominvname=minetest.registered_nodes[fromnode.name].tube.input_inventory
			local frominv=frommeta:get_inventory()
			for spos,stack in ipairs(frominv:get_list(frominvname)) do
				if stack:get_name()~="" then
					local leftover = turtle_invs:add_item(turtle,stack)
					frominv:set_stack(spos, leftover)
					return
				end
			end
		end,]]
	}
end



create_environment = function(turtle)
	-- Gather variables for the environment
	local t = get_turtle_funcs(turtle)
	local e = {
			--[[print = safe_print,]]
			turtle = t,
			--[[tostring = tostring,
			tonumber = tonumber,]]
			delay = coroutine.yield,
			coroutine = {
				yield = coroutine.yield,
			},
			--[[string = {
				byte = string.byte,
				char = string.char,
				find = string.find,
				format = string.format,
				gmatch = string.gmatch,
				gsub = string.gsub,
				len = string.len,
				lower = string.lower,
				match = string.match,
				rep = string.rep,
				reverse = string.reverse,
				sub = string.sub,
			},
			math = {
				abs = math.abs,
				acos = math.acos,
				asin = math.asin,
				atan = math.atan,
				atan2 = math.atan2,
				ceil = math.ceil,
				cos = math.cos,
				cosh = math.cosh,
				deg = math.deg,
				exp = math.exp,
				floor = math.floor,
				fmod = math.fmod,
				frexp = math.frexp,
				huge = math.huge,
				ldexp = math.ldexp,
				log = math.log,
				log10 = math.log10,
				max = math.max,
				min = math.min,
				modf = math.modf,
				pi = math.pi,
				pow = math.pow,
				rad = math.rad,
				random = math.random,
				sin = math.sin,
				sinh = math.sinh,
				sqrt = math.sqrt,
				tan = math.tan,
				tanh = math.tanh,
			},
			table = {
				insert = table.insert,
				maxn = table.maxn,
				remove = table.remove,
				sort = table.sort
			},]]
	}
	get_turtle_info(turtle)["env"]=e
	return e
end

local create_sandbox = function (code, env)
	-- Create Sandbox
	if code:byte(1) == 27 then
		return _, "You Hacker You! Don't use binary code!"
	end
	f, msg = loadstring(code)
	if not f then return _, msg end
	setfenv(f, env)
	return f
end

local do_overheat = function (turtle)
	-- Overheat protection
	heat(turtle)
	turtle_add_update(0.5,{turtle=turtle, type="cool"})
	if overheat(turtle) then
		--TODO
		return true
	end
end

local load_memory = function(turtle)
	local info = get_turtle_info(turtle)
	return info["memory"] or {}
end

local save_memory = function(turtle, mem)
	local info = get_turtle_info(turtle)
	info["memory"] = mem
end

local interrupt_allow = function (turtle, event)
	if event.type ~= "interrupt" then return true end
	local info = get_turtle_info(turtle)
	local interrupts = info["interrupts"] or {}
	local search = safe_serialize(event.iid)
	for _, i in ipairs(interrupts) do
		if safe_serialize(i) == search then
			return true
		end
	end

	return false
end

----------------------
-- Parsing function --
----------------------

--local handlers = setmetatable({}, {__mode='kv'})

--function error(e, level_) --FIX:level not handled
--  coroutine.yield(e)
--end

launch_turtle = function (turtle)
	local info = get_turtle_info(turtle)
	--if not interrupt_allow(turtle, event) then return end
	--if do_overheat(turtle) then return end

	-- load code & mem from memory
	--local mem  = load_memory(turtle)
	local code = info["code"]
	code = luahelpers.add_yields(code)
	-- make sure code is ok and create environment
	--local prohibited = code_prohibited(code)
	--if prohibited then return prohibited end
	local env = create_environment(turtle)
	local chunk, msg = create_sandbox (code, env)
	if not chunk then return msg end
	local co=coroutine.create(chunk)
	coroutine.resume(co)
	info["co"]=co
	info["wait"]=2
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1,6)~="turtle" then return end
	update_formspec(formname, fields.code, "", fields.filename, player, fields.exit)
	if fields.program~=nil or fields.exit~=nil then
		--local err = turtle_update(formname, {type="program"})
		local err = launch_turtle(formname)
		if err then print(err) end
		update_formspec(formname, fields.code, err, fields.filename, player, fields.exit)
	end
	if fields.save then
		if fields.filename:sub(1,1)=="." then return end -- Not allowed to save because could change the user's files (including the mod's files, dangerous)
		local fn = minetest.get_modpath("turtle").."/progs/"..fields.filename..".lua"
		local f = io.open(fn, "w")
		f:write(fields.code)
		f:close()
	end
	if fields.open then
		local fn = minetest.get_modpath("turtle").."/progs/"..fields.filename..".lua"
		local f = io.open(fn, "r")
		local code
		if f==nil then
			code=""
		else
			code = f:read("*all")
			f:close()
		end
		if code==nil then code="" end
		update_formspec(formname, code, "", fields.filename, player)
	end
end)

minetest.register_craftitem("turtle:turtle",{
	description="Turtle",
	image = "turtle_turtle_inv.png",
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type~="node" then return end
		local obj = minetest.env:add_entity(pointed_thing.above, "turtle:turtle")
		itemstack:take_item()
		return itemstack
	end
})

minetest.register_craft( {
	output = "turtle:turtle",
	recipe = {
		{ "default:diamond", "default:pick_mese", "default:diamond" },
	        { "default:diamond", "default:mese", "default:diamond" },
		{ "default:mese", "default:diamond", "default:mese" },
	},
})

turtle_invs = minetest.create_detached_inventory("turtle:invs")
for turtle,i in pairs(turtle_infos) do
	turtle_invs:set_size(turtle,16)
	for l,stack in pairs(deserialize_inv(i["inventory"])) do
		turtle_invs:set_stack(turtle, l, stack)
	end
end

minetest.register_entity("turtle:turtle", {
	physical = true,
	force_load = TURTLES_FORCE_LOAD,
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "mesh",
	mesh="turtle.x",
	textures = {"default_wood.png","default_wood.png"},
	visual_size = {x=1, y=1},
	on_activate = function(self, staticdata)
		local info
		if staticdata==nil or staticdata=="" then
			self.n=get_turtle_id()
			info=get_turtle_info(self.n)
			turtle_invs:set_size(self.n,16)
			info["turtle"]=self
			info["spos"]=round_pos(self.object:getpos())
			info["dir"]=0
			info["fuel"]=0
			info["formspec"]= "size[9,10]"..
				"textarea[0.3,0;4.7,5;code;;]"..
				"list[detached:turtle:invs;"..self.n..";4.8,0;4,4;]"..
				"image_button[0,4.6;2.5,1;turtle_execute.png;program;]"..
				"image_button_exit[8.72,-0.25;0.425,0.4;turtle_close.png;exit;]"..
				"label[4.6,4;]"..
				"list[current_player;main;0.5,6;8,4;]"..
				"field[3,5;4,1;filename;Filename:;]"..
				"button[7,4.65;1,1;open;Open]"..
				"button[8,4.65;1,1;save;Save]"
		else
			self.n=staticdata
			info=get_turtle_info(self.n)
			info["turtle"]=self
		end
	end,
	on_step = function(self, dtime)
		local info=get_turtle_info(self.n)
		if info["rotate"] then
			self.object:setyaw(self.object:getyaw()+info["rotate"]*dtime)
		end
	end,
	on_rightclick = function(self, clicker)
		minetest.show_formspec(clicker:get_player_name(), self.n, get_turtle_info(self.n)["formspec"])
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		self.object:remove()
		minetest.env:add_item(turtle_infos[self.n]["spos"],"turtle:turtle")
		for i=1,16 do
			turtle_invs:set_stack(self.n, i, ItemStack(""))
		end
		turtle_infos[self.n] = nil
	end,
	get_staticdata = function(self)
		return self.n
	end,
})
