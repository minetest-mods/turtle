luahelpers={}

function long_string(s,i)
	local ii=i
	local ls=string.len(s)
	local depth=0
	while i<=ls do
		i=i+1
		c=string.sub(s,i,i)
		if c=='[' then
			i=i+1
			break
		else
			depth=depth+1
		end
	end
	while i<=ls-depth-1 do
		i=i+1
		c=string.sub(s,i,i+depth+1)
		if c==']'..string.rep("=",depth).."]" then
			i=i+depth+2
			break
		end
	end
	return i,string.sub(s,ii,i-1)
end

function countb(s,i)
	local x=0
	while string.sub(s,i,i)=="\\" do
		i=i-1
		x=x+1
	end
	return x
end

function luahelpers.remove_comments(s)
	local i=1
	local ls=string.len(s)
	local l2=""
	while i<=ls do
		local c=string.sub(s,i,i)
		if c=="-" then
			if i==ls then
				l2=l2.."-"
				break
			end
			local c2=string.sub(s,i+1,i+1)
			if c2=="-" then
				--comment
				if i==ls-1 then break end
				local c3=string.sub(s,i+2,i+2)
				if c3=="[" then --long comment
					local k=""
					i,k=long_string(s,i+2)
					print(k)
				else --short comment
					i=i+2
					c=string.sub(s,i,i)
					while i<=ls and c~="\n" do
						c=string.sub(s,i,i)
						i=i+1
					end
					l2=l2.."\n"
				end
			else
				i=i+1
				l2=l2.."-"
			end
		elseif c=='"' then
			c=string.sub(s,i,i)
			while i<=ls do
				l2=l2..c
				i=i+1
				c=string.sub(s,i,i)
				if c=='"' then
					local c2=countb(s,i-1)
					if c2%2==0 then
						i=i+1
						l2=l2..'"'
						break
					end
				end
			end
		elseif c=="'" then
			c=string.sub(s,i,i)
			while i<=ls do
				l2=l2..c
				i=i+1
				c=string.sub(s,i,i)
				if c=="'" then
					local c2=countb(s,i-1)
					if c2%2==0 then
						i=i+1
						l2=l2.."'"
						break
					end
				end
			end
		elseif c=="[" then
			if i==ls then
				l2=l2.."["
				break
			end
			local c2=string.sub(s,i+1,i+1)
			if c2=="[" or c2=="=" then
				local k=""
				i,k=long_string(s,i)
				l2=l2..k
			else
				i=i+1
				l2=l2.."["
			end
		else
			l2=l2..c
			i=i+1
		end
	end
	return l2
end

function luahelpers.add_yields(s)
	s=luahelpers.remove_comments(s)
	s="\n"..s.."\n"
	s=string.gsub(s, "[^_%w]while[^_%w].-[^_%w]do[^_%w]", "%1 coroutine.yield(0);")
	s=string.gsub(s, "[^_%w]for[^_%w].-[^_%w]do[^_%w]", "%1 coroutine.yield(0);")
	s=string.gsub(s, "[^_%w]repeat[^_%w]", "%1 coroutine.yield(0);")
	s=string.gsub(s, "[^_%w]function[^_%w].-%)", "%1 coroutine.yield(0);")
	return s
end

--[======[ DEBUG CODE
print(luahelpers.remove_comments([====[
gzvsvs--gsv
fsd"--hkj"fvd
[=[--[[]=]
--[[fzffs]]
]====]))
print(luahelpers.remove_comments([====[
--[[fzffs]]
]====]))
--]======]

print(luahelpers.add_yields([[
while true do
	turtle.forward()
end]]))
