DOWN=-300

function v3add(v1,v2)
	return {x=v1.x+v2.x, y=v1.y+v2.y, z=v1.z+v2.z}
end
function v3sub(v1,v2)
	return {x=v1.x-v2.x, y=v1.y-v2.y, z=v1.z-v2.z}
end

function forward(iid)
	mem.pos = v3add(mem.pos, mem.dir)
	turtle.forward(iid)
end

function back(iid)
	mem.pos = v3sub(mem.pos, mem.dir)
	turtle.back(iid)
end

function up(iid)
	mem.pos.y=mem.pos.y+1
	turtle.up(iid)
end

function down(iid)
	mem.pos.y=mem.pos.y-1
	turtle.down(iid)
end

function turnleft(iid)
	mem.dir={x=mem.dir.z, y=mem.dir.y, z=-mem.dir.x}
	turtle.turnleft(iid)
end

function turnright(iid)
	mem.dir={x=-mem.dir.z, y=mem.dir.y, z=mem.dir.x}
	turtle.turnright(iid)
end

function gotoface(iid, dir)
	if dir.x==0 then
		if mem.dir.x==-dir.z then
			turnleft(iid)
		elseif mem.dir.x==dir.z then
			turnright(iid)
		elseif mem.dir.z==dir.z then
			interrupt(0, iid)
		else
			mem.gotofaceiid=iid
			turnleft("gotoface")
		end
	else
		if mem.dir.z==dir.x then
			turnleft(iid)
		elseif mem.dir.z==-dir.x then
			turnright(iid)
		elseif mem.dir.x==dir.x then
			interrupt(0, iid)
		else
			mem.gotofaceiid=iid
			turnleft("gotoface")
		end
	end
end


function nface(iid)
	gotoface(iid, {x=0,y=0,z=1})
end

function put_all_except(name)
	if turtle.getstack(1).name~=name then
		turtle.drop(1)
	end
	if turtle.getstack(2).name~=name then
		turtle.drop(2)
	end
	if turtle.getstack(3).name~=name then
		turtle.drop(3)
	end
	if turtle.getstack(4).name~=name then
		turtle.drop(4)
	end
	if turtle.getstack(5).name~=name then
		turtle.drop(5)
	end
	if turtle.getstack(6).name~=name then
		turtle.drop(6)
	end
	if turtle.getstack(7).name~=name then
		turtle.drop(7)
	end
	if turtle.getstack(8).name~=name then
		turtle.drop(8)
	end
	if turtle.getstack(9).name~=name then
		turtle.drop(9)
	end
	if turtle.getstack(10).name~=name then
		turtle.drop(10)
	end
	if turtle.getstack(11).name~=name then
		turtle.drop(11)
	end
	if turtle.getstack(12).name~=name then
		turtle.drop(12)
	end
	if turtle.getstack(13).name~=name then
		turtle.drop(13)
	end
	if turtle.getstack(14).name~=name then
		turtle.drop(14)
	end
	if turtle.getstack(15).name~=name then
		turtle.drop(15)
	end
	if turtle.getstack(16).name~=name then
		turtle.drop(16)
	end
end

function put_all(name)
	if turtle.getstack(1).name==name then
		turtle.drop(1)
	end
	if turtle.getstack(2).name==name then
		turtle.drop(2)
	end
	if turtle.getstack(3).name==name then
		turtle.drop(3)
	end
	if turtle.getstack(4).name==name then
		turtle.drop(4)
	end
	if turtle.getstack(5).name==name then
		turtle.drop(5)
	end
	if turtle.getstack(6).name==name then
		turtle.drop(6)
	end
	if turtle.getstack(7).name==name then
		turtle.drop(7)
	end
	if turtle.getstack(8).name==name then
		turtle.drop(8)
	end
	if turtle.getstack(9).name==name then
		turtle.drop(9)
	end
	if turtle.getstack(10).name==name then
		turtle.drop(10)
	end
	if turtle.getstack(11).name==name then
		turtle.drop(11)
	end
	if turtle.getstack(12).name==name then
		turtle.drop(12)
	end
	if turtle.getstack(13).name==name then
		turtle.drop(13)
	end
	if turtle.getstack(14).name==name then
		turtle.drop(14)
	end
	if turtle.getstack(15).name==name then
		turtle.drop(15)
	end
	if turtle.getstack(16).name==name then
		turtle.drop(16)
	end
end

function find_stack(name)
	if turtle.getstack(1).name==name then
		return 1
	elseif turtle.getstack(2).name==name then
		return 2
	elseif turtle.getstack(3).name==name then
		return 3
	elseif turtle.getstack(4).name==name then
		return 4
	elseif turtle.getstack(5).name==name then
		return 5
	elseif turtle.getstack(6).name==name then
		return 6
	elseif turtle.getstack(7).name==name then
		return 7
	elseif turtle.getstack(8).name==name then
		return 8
	elseif turtle.getstack(9).name==name then
		return 9
	elseif turtle.getstack(10).name==name then
		return 10
	elseif turtle.getstack(11).name==name then
		return 11
	elseif turtle.getstack(12).name==name then
		return 12
	elseif turtle.getstack(13).name==name then
		return 13
	elseif turtle.getstack(14).name==name then
		return 14
	elseif turtle.getstack(15).name==name then
		return 15
	elseif turtle.getstack(16).name==name then
		return 16
	end
	return nil
end

--print(event)
if event.type=="program" then
	mem.spx=1
	mem.spy=1
	mem.pos = {x=0,y=0,z=0}
	mem.dir = {x=0,y=0,z=1}
	turtle.dig()
	turtle.refuel(1)
	forward("cuttree")
	mem.return_to="firsttree"
elseif event.type=="endmove" or event.type=="interrupt" then
	if event.iid=="gotoface" then
		turnleft(mem.gotofaceiid)
	elseif event.iid=="cuttree" then
		turtle.dig()
		mem.origface={x=mem.dir.x,y=mem.dir.y,z=mem.dir.z}
		name = turtle.detectup()
		if name=="air" then
			down("endcuttree")
		else
			turtle.digup()
			up("cuttree2")
		end
	elseif event.iid=="cuttree2" then
		turtle.dig()
		turnleft("cuttree3")
	elseif event.iid=="cuttree3" then
		turtle.dig()
		turnleft("cuttree4")
	elseif event.iid=="cuttree4" then
		turtle.dig()
		turnleft("cuttree5")
	elseif event.iid=="cuttree5" then
		turtle.dig()
		name = turtle.detectup()
		if name=="air" then
			down("endcuttree")
		else
			turtle.digup()
			up("cuttree2")
		end
	elseif event.iid=="endcuttree" then
		name = turtle.detectdown()
		turtle.suckdown()
		if name=="air" then
			down("endcuttree")
		else
			gotoface(mem.return_to, mem.origface)
		end
	elseif event.iid=="firsttree" then
		nface("firsttree1")
	elseif event.iid=="firsttree1" then
		turtle.dropup(2)
		turtle.dropup(3)
		turtle.craft(3)
		turtle.dropup(1)
		turtle.moveto(2,1,1)
		turtle.moveto(2,3,5)
		turtle.moveto(2,5,1)
		turtle.moveto(2,7,1)
		turtle.moveto(2,9,1)
		turtle.moveto(2,10,1)
		turtle.moveto(2,11,1)
		turtle.craft(1)
		turtle.place(1)
		turtle.craft(4)
		turtle.drop(1)
		interrupt(5,"firsttree2")
	elseif event.iid=="firsttree2" then
		turtle.suckup()
		turtle.suckup()
		turtle.suckup()
		turtle.suckup() -- Excess suckups are whenever saplings fell
		turtle.suckup()
		turtle.suckup()
		turtle.suckup()
		turtle.suckup()
		turnleft("firsttree3")
	elseif event.iid=="firsttree3" then
		local s=nil
		s=find_stack("default:leaves")
		if s==nil then --we don't have leaves, only spalings
			interrupt(0.1,"plant_sapling")
		else
			mem.leaves_stack=s
			turtle.place(s)
			mem.return_to="plant_sapling"
			interrupt(0.1,"leaves_dig")
		end
	elseif event.iid=="leaves_dig" then
		turtle.dig()
		interrupt(0.1, "leaves_place")
	elseif event.iid=="leaves_place" then
		if turtle.getstack(mem.leaves_stack).name=="default:leaves" then
			turtle.place(mem.leaves_stack)
			interrupt(0.1,"leaves_dig")
		else --no more leaves
			interrupt(0.1,mem.return_to)
		end
	elseif event.iid=="plant_sapling" then
		local s
		local w
		s=find_stack("default:sapling")
		w=find_stack("default:tree")
		mem.sapstack=s
		turtle.place(s)
		turtle.refuel(w, 1)
		mem.ddown = math.floor(turtle.get_fuel_time()/2)-10
		turnleft("plant_sapling2")
	elseif event.iid=="plant_sapling2" then
		turtle.place(mem.sapstack)
		turnleft("plant_sapling3")
	elseif event.iid=="plant_sapling3" then
		turtle.place(mem.sapstack)
		turnright("dig1")
	elseif event.iid=="dig" then
		m=find_stack("default:mese_crystal")
		d=find_stack("default:diamond")
		if m~=nil and d~=nil and turtle.getstack(m).count>=30 and turtle.getstack(d).count>=7 then
			nface("craft")
		else
			w=find_stack("default:tree")
			if w~=nil then
				turtle.refuel(w)
			end
			c=find_stack("default:coal_lump")
			if c~=nil then
				turtle.refuel(c)
			end
			ddown = math.floor(turtle.get_fuel_time()/2)-30
			if ddown>mem.ddown+30 then
				mem.ddown=ddown
				interrupt(0,"dig1")
			else
				turnright("checktree")
			end
		end
	elseif event.iid=="dig1" then
		if mem.pos.y==-mem.ddown then
			turtle.dig()
			forward("dig2")
		elseif mem.pos.y==DOWN then
			mem.mmove=(mem.ddown+DOWN)*2
			mem.spx=mem.spx-1
			mem.spy=mem.spy-1
			interrupt(0,"dig5")
			mem.sx=0
			mem.sy=0
		else
			turtle.digdown()
			down("dig1")
		end
	elseif event.iid=="dig2" then
		if mem.pos.y==-2 then
			back("dig3")
		else
			turtle.digup()
			up("dig2")
		end
	elseif event.iid=="dig3" then
		up("dig4")
	elseif event.iid=="dig4" then
		if mem.pos.y==0 then
			turnright("checktree")
		else
			turtle.digup()
			up("dig4")
		end
	elseif event.iid=="dig5" then
		mem.mmove=mem.mmove-1
		turtle.digup()
		turtle.digdown()
		if mem.mmove%100==0 then put_all("default:cobble") end
		if mem.sx==mem.spx then
			mem.spx=mem.spx+1
			turnleft("dig6")
		elseif mem.mmove<=0 and mem.sx==0 then
			if mem.sy==0 then
				gotoface("dig4",{x=0,y=0,z=-1})
			else
				turnleft("dig6")
			end
		else
			turtle.dig()
			mem.sx=mem.sx+1
			forward("dig5")
		end
	elseif event.iid=="dig6" then
		mem.mmove=mem.mmove-1
		turtle.digup()
		turtle.digdown()
		if mem.mmove%100==0 then put_all("default:cobble") end
		if mem.sy==mem.spy then
			mem.spy=mem.spy+1
			turnleft("dig7")
		elseif mem.mmove<=0 and mem.sy==0 then
			if mem.sx==0 then
				gotoface("dig4",{x=0,y=0,z=-1})
			else
				turnleft("dig7")
			end
		else
			turtle.dig()
			mem.sy=mem.sy+1
			forward("dig6")
		end
	elseif event.iid=="dig7" then
		mem.mmove=mem.mmove-1
		turtle.digup()
		turtle.digdown()
		if mem.mmove%100==0 then put_all("default:cobble") end
		if mem.sx==-mem.spx then
			turnleft("dig8")
		elseif mem.mmove<=0 and mem.sx==0 then
			if mem.sy==0 then
				gotoface("dig4",{x=0,y=0,z=-1})
			else
				turnleft("dig8")
			end
		else
			turtle.dig()
			mem.sx=mem.sx-1
			forward("dig7")
		end
	elseif event.iid=="dig8" then
		mem.mmove=mem.mmove-1
		turtle.digup()
		turtle.digdown()
		if mem.mmove%100==0 then put_all("default:cobble") end
		if mem.sy==-mem.spy then
			turnleft("dig5")
		elseif mem.mmove<=0 and mem.sy==0 then
			if mem.sx==0 then
				gotoface("dig4",{x=0,y=0,z=-1})
			else
				turnleft("dig5")
			end
		else
			turtle.dig()
			mem.sy=mem.sy-1
			forward("dig8")
		end
	elseif event.iid=="checktree" then
		put_all("default:cobble")
		local name=turtle.detect()
		if name=="default:tree" then
			mem.return_to="endchecktree"
			turtle.dig()
			forward("cuttree")
		elseif name=="air" then
			sapstack = find_stack("default:sapling")
			if sapstack==nil then
				s=find_stack("default:leaves")
				mem.leaves_stack=s
				turtle.place(s)
				mem.return_to="checktree"
				interrupt(0.1,"leaves_dig")
			else
				turtle.place(sapstack)
				interrupt(0, "checktree")
			end
		else
			turnleft("checktree2")
		end
	elseif event.iid=="endchecktree" then
		back("checktree")
	elseif event.iid=="checktree2" then
		local name=turtle.detect()
		if name=="default:tree" then
			mem.return_to="endchecktree2"
			turtle.dig()
			forward("cuttree")
		elseif name=="air" then
			sapstack = find_stack("default:sapling")
			if sapstack==nil then
				s=find_stack("default:leaves")
				mem.leaves_stack=s
				turtle.place(s)
				mem.return_to="checktree2"
				interrupt(0.1,"leaves_dig")
			else
				turtle.place(sapstack)
				interrupt(0, "checktree2")
			end
		else
			turnleft("checktree3")
		end
	elseif event.iid=="endchecktree2" then
		back("checktree2")
	elseif event.iid=="checktree3" then
		local name=turtle.detect()
		if name=="default:tree" then
			mem.return_to="endchecktree3"
			turtle.dig()
			forward("cuttree")
		elseif name=="air" then
			sapstack = find_stack("default:sapling")
			if sapstack==nil then
				s=find_stack("default:leaves")
				mem.leaves_stack=s
				turtle.place(s)
				mem.return_to="checktree3"
				interrupt(0.1,"leaves_dig")
			else
				turtle.place(sapstack)
				interrupt(0, "checktree3")
			end
		else
			turnright("dig")
		end
	elseif event.iid=="endchecktree3" then
		back("checktree3")
	elseif event.iid=="craft" then
		d=find_stack("default:diamond")
		turtle.drop(d)
		interrupt(5,"craft2")
	elseif event.iid=="craft2" then
		put_all_except("default:mese_crystal")
		m=find_stack("default:mese_crystal")
		turtle.moveto(m,16,99)
		turtle.moveto(16,1,4)
		turtle.moveto(16,2,4)
		turtle.moveto(16,3,4)
		turtle.moveto(16,5,3)
		turtle.moveto(16,6,3)
		turtle.moveto(16,7,3)
		turtle.moveto(16,9,3)
		turtle.moveto(16,10,3)
		turtle.moveto(16,11,3)
		turtle.dropup(16)
		turtle.craft(3)
		turtle.suck()
		turtle.drop(4)
		turtle.moveto(5,6,1)
		turtle.moveto(5,10,15)
		turtle.craft(1)
		turtle.dropup(10)
		turtle.moveto(1,2,1)
		interrupt(5,"craft3")
	elseif event.iid=="craft3" then
		turtle.suck()
		turtle.moveto(1,6,1)
		turtle.moveto(1,9,1)
		turtle.moveto(1,11,1)
		turtle.suck()
		turtle.moveto(1,3,1)
		turtle.moveto(1,5,1)
		turtle.moveto(1,7,1)
		turtle.moveto(1,10,1)
		turtle.craft(1)
		turtle.suckup()
		turtle.suckup()
		turtle.suckup()
		turtle.suckup()
		turtle.suckup()
		put_all_except()
	end
end
