turtles = {}

local modpath = minetest.get_modpath("turtle")

-- Database handler (for turtles and floppies)
dofile(modpath .. "/db.lua")

-- Initial computer state: bootloader
dofile(modpath .. "/computer_memory.lua")

-- Data for the forth floppy, created from forth.fth file by f.py
dofile(modpath .. "/forth_floppy.lua")

-- Computer simulation code
dofile(modpath .. "/cptr.lua")

-- Screen handler for formspec
dofile(modpath .. "/screen.lua")

-- Floppy, floppy programmator, and disk
dofile(modpath .. "/floppy.lua")

-- Turtle code
dofile(modpath .. "/t2.lua")
