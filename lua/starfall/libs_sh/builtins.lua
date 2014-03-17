-------------------------------------------------------------------------------
-- Builtins.
-- Functions built-in to the default environment
-------------------------------------------------------------------------------

local dgetmeta = debug.getmetatable

--- Built in values. These don't need to be loaded; they are in the default environment.
-- @name builtin
-- @shared
-- @class library
-- @libtbl SF.DefaultEnvironment

-- ------------------------- Lua Ports ------------------------- --
-- This part is messy because of LuaDoc stuff.

--- Same as the Gmod vector type
-- @name SF.DefaultEnvironment.Vector
-- @class function
-- @param x
-- @param y
-- @param z
-- @return New vector
SF.DefaultEnvironment.Vector = Vector
--- Same as the Gmod angle type
-- @name SF.DefaultEnvironment.Angle
-- @class function
-- @param p Pitch
-- @param y Yaw
-- @param r Roll
-- @return New angle
SF.DefaultEnvironment.Angle = Angle
--- Same as the Gmod VMatrix type
-- @name SF.DefaultEnvironment.VMatrix
-- @class function
--SF.DefaultEnvironment.Matrix = Matrix
--- Same as Lua's tostring
-- @name SF.DefaultEnvironment.tostring
-- @class function
-- @param obj
-- @return obj as string
SF.DefaultEnvironment.tostring = tostring
--- Same as Lua's tonumber
-- @name SF.DefaultEnvironment.tonumber
-- @class function
-- @param obj
-- @return obj as number
SF.DefaultEnvironment.tonumber = tonumber

local function mynext( t, idx )
	SF.CheckType( t, "table" )
	
	local dm = dgetmeta( t )
	if dm and type(dm.__metatable) == "string" then
		return next(dm.__index,idx)
	else
		return next(t,idx)
	end
end
--- Same as Lua's ipairs
-- @name SF.DefaultEnvironment.ipairs
-- @class function
-- @param tbl Table to iterate over
-- @return Iterator function
-- @return Table tbl
-- @return 0 as current index
SF.DefaultEnvironment.ipairs = function( tbl ) return mynext, tbl, 0 end
--- Same as Lua's pairs
-- @name SF.DefaultEnvironment.pairs
-- @class function
-- @param tbl Table to iterate over
-- @return Iterator function
-- @return Table tbl
-- @return nil as current index
SF.DefaultEnvironment.pairs = function( tbl ) return mynext, tbl, nil end
--- Same as Lua's type
-- @name SF.DefaultEnvironment.type
-- @class function
-- @param obj Object to get type of
-- @return 
SF.DefaultEnvironment.type = function( val )
	local tp = getmetatable( val )
	return type(tp) == "string" and tp or type( val )
end
--- Same as Lua's next
-- @name SF.DefaultEnvironment.next
-- @class function
-- @param tbl Table to get the next key-value pair of
-- @param k Previous key (can be nil)
-- @return Key or nil
-- @return Value or nil
SF.DefaultEnvironment.next = mynext
--- Same as Lua's assert.
-- @name SF.DefaultEnvironment.assert
-- @class function
-- @param condition
-- @param msg
SF.DefaultEnvironment.assert = function ( condition, msg ) if not condition then error( msg or "assertion failed!", 2 ) end end
--- Same as Lua's unpack
-- @name SF.DefaultEnvironment.unpack
-- @class function
-- @param tbl
-- @return Elements of tbl
SF.DefaultEnvironment.unpack = unpack

--- Same as Lua's setmetatable. Doesn't work on most internal metatables
-- @param tbl The table to set the metatable of
-- @param meta The metatable to use
-- @return tbl with metatable set to meta
SF.DefaultEnvironment.setmetatable = setmetatable
--- Same as Lua's getmetatable. Doesn't work on most internal metatables
-- @param tbl Table to get metatable of
-- @return The metatable of tbl
SF.DefaultEnvironment.getmetatable = function(tbl)
	SF.CheckType(tbl,"table")
	return getmetatable(tbl)
end
--- Throws an error. Can't change the level yet.
-- @param msg Error message
SF.DefaultEnvironment.error = function(msg) error(msg or "an unspecified error occured",2) end

--- Constant that denotes whether the code is executed on the client
-- @name SF.DefaultEnvironment.CLIENT
-- @class field
SF.DefaultEnvironment.CLIENT = CLIENT
--- Constant that denotes whether the code is executed on the server
-- @name SF.DefaultEnvironment.SERVER
-- @class field
SF.DefaultEnvironment.SERVER = SERVER

--- Gets the amount of ops used so far
-- @return Operations used in this second
function SF.DefaultEnvironment.opsUsed()
	return SF.instance.ops
end

--- Gets the ops hard quota
-- @return Maximum operations per second
function SF.DefaultEnvironment.opsMax()
	return SF.instance.context.ops()
end

-- The below modules have the Gmod functions removed (the ones that begin with a capital letter),
-- as requested by Divran

-- Filters Gmod Lua files based on Garry's naming convention.
local function filterGmodLua(lib, original, gm)
	original = original or {}
	gm = gm or {}
	for name, func in pairs(lib) do
		if name:match("^[A-Z]") then
			gm[name] = func
		else
			original[name] = func
		end
	end
	return original, gm
end

-- String library
local string_methods, string_metatable = SF.Typedef("Library: string")
filterGmodLua(string,string_methods)
string_metatable.__newindex = function() end
string_methods.explode = function(str,separator,withpattern) return string.Explode(separator,str,withpattern) end
--- Lua's (not glua's) string library
-- @name SF.DefaultEnvironment.string
-- @class table
SF.DefaultEnvironment.string = setmetatable({},string_metatable)

--- Color type
local color_methods, color_metatable = SF.Typedef("Color")
color_metatable.__newindex = function() end

--- Same as the Gmod Color type
-- @name SF.DefaultEnvironment.Color
-- @class function
-- @param r - Red
-- @param g - Green
-- @param b - Blue
-- @param a - Alpha
-- @return New color
SF.DefaultEnvironment.Color = function ( r, g, b, a )
	return setmetatable( Color( r, g, b, a ), color_metatable )
end


-- Math library
local math_methods, math_metatable = SF.Typedef("Library: math")
filterGmodLua(math,math_methods)
math_metatable.__newindex = function() end
math_methods.clamp = math.Clamp
math_methods.round = math.Round
math_methods.randfloat = math.Rand
math_methods.calcBSplineN = nil
--- Lua's (not glua's) math library, plus clamp, round, and randfloat
-- @name SF.DefaultEnvironment.math
-- @class table
SF.DefaultEnvironment.math = setmetatable({},math_metatable)

local table_methods, table_metatable = SF.Typedef("Library: table")
filterGmodLua(table,table_methods)
table_metatable.__newindex = function() end
--- Lua's (not glua's) table library
-- @name SF.DefaultEnvironment.table
-- @class table
SF.DefaultEnvironment.table = setmetatable({},table_metatable)

-- ------------------------- Functions ------------------------- --

--- Loads a library.
-- @name SF.DefaultEnvironment.loadLibrary
-- @class function
-- @param ... A list of strings representing libraries eg "hook", "ent", "render"
-- @return Loaded libraries
function SF.DefaultEnvironment.loadLibrary(...)
	local t = {...}
	local r = {}

	local instance = SF.instance

	for _,v in pairs(t) do
		SF.CheckType(v,"string")

		if instance.context.libs[v] then
			r[#r+1] = setmetatable({}, instance.context.libs[v])
		else
			r[#r+1] = SF.Libraries.Get(v)
		end
	end

	return unpack(r)
end

--- Gets a list of all libraries
-- @return Table containing the names of each available library
function SF.DefaultEnvironment.getLibraries()
	local ret = {}
	for k,v in pairs( SF.Libraries.libraries ) do
		ret[#ret+1] = k
	end
	return ret
end



if SERVER then
	--- Prints a message to the player's chat.
	-- @shared
	-- @param ... Values to print
	function SF.DefaultEnvironment.print(...)
		local str = ""
		local tbl = {...}
		for i=1,#tbl do str = str .. tostring(tbl[i]) .. (i == #tbl and "" or "\t") end
		SF.instance.player:ChatPrint(str)
	end
else
	-- Prints a message to the player's chat.
	function SF.DefaultEnvironment.print(...)
		if SF.instance.player ~= LocalPlayer() then return end
		local str = ""
		local tbl = {...}
		for i=1,#tbl do str = str .. tostring(tbl[i]) .. (i == #tbl and "" or "\t") end
		LocalPlayer():ChatPrint(str)
	end
end

local function printTableX( target, t, indent, alreadyprinted )
	for k,v in SF.DefaultEnvironment.pairs( t ) do
		if SF.GetType( v ) == "table" and not alreadyprinted[v] then
			alreadyprinted[v] = true
			target:ChatPrint( string.rep( "\t", indent ) .. tostring(k) .. ":" )
			printTableX( target, v, indent + 1, alreadyprinted )
		else
			target:ChatPrint( string.rep( "\t", indent ) .. tostring(k) .. "\t=\t" .. tostring(v) )
		end
	end
end

--- Prints a table to player's chat
-- @param tbl Table to print
function SF.DefaultEnvironment.printTable( tbl )
	if CLIENT and SF.instance.player ~= LocalPlayer() then return end
	SF.CheckType( tbl, "table" )

	printTableX( (SERVER and SF.instance.player or LocalPlayer()), tbl, 0, {[t] = true} )
end


--- Runs an included script and caches the result.
-- Works pretty much like standard Lua require()
-- @param file The file to include. Make sure to --@include it
-- @return Return value of the script
function SF.DefaultEnvironment.require(file)
	SF.CheckType(file, "string")
	local loaded = SF.instance.data.reqloaded
	if not loaded then
		loaded = {}
		SF.instance.data.reqloaded = loaded
	end
	
	if loaded[file] then
		return loaded[file]
	else
		local func = SF.instance.scripts[file]
		if not func then error("Can't find file '"..file.."' (did you forget to --@include it?)",2) end
		loaded[file] = func() or true
		return loaded[file]
	end
end

--- Runs an included script, but does not cache the result.
-- Pretty much like standard Lua dofile()
-- @param file The file to include. Make sure to --@include it
-- @return Return value of the script
function SF.DefaultEnvironment.dofile(file)
	SF.CheckType(file, "string")
	local func = SF.instance.scripts[file]
	if not func then error("Can't find file '"..file.."' (did you forget to --@include it?)",2) end
	return func()
end

-- @param func Function to call
-- @return True if the call was successful
-- @return If the call was successful, the return values. Otherwise, the error message
function SF.DefaultEnvironment.pcall ( func )
    local ok, err = pcall( func )

    -- don't catch quota errors
    if SF.instance.ops > SF.instance.context.ops() then
        error( err, 0 )
    end

    return ok, err
end

--- GLua's loadstring
-- Works like loadstring, except that it executes by default in the main environment
-- @param str String to execute
-- @return Function of str
function SF.DefaultEnvironment.loadstring ( str )
	local func = CompileString( str, "SF: " .. tostring( SF.instance.env ), false )
	
	-- CompileString returns an error as a string, better check before setfenv
	if type( func ) == "function" then
		return setfenv( func, SF.instance.env )
	end
	
	return func
end

--- Lua's setfenv
-- Works like setfenv, but is restricted on functions
-- @param func Function to change environment of
-- @param tbl New environment
-- @return func with environment set to tbl
function SF.DefaultEnvironment.setfenv ( func, tbl )
	if type( func ) ~= "function" then error( "Main Thread is protected!" ) end
	return setfenv( func, tbl )
end

--- Simple version of Lua's getfenv
-- Returns the current environment
-- @return Current environment
function SF.DefaultEnvironment.getfenv ()
	return getfenv()
end

-- ------------------------- Restrictions ------------------------- --
-- Restricts access to builtin type's metatables

local _R = debug.getregistry()
local function restrict(instance, hook, name, ok, err)
	_R.Vector.__metatable = "Vector"
	_R.Angle.__metatable = "Angle"
	_R.VMatrix.__metatable = "VMatrix"
end

local function unrestrict(instance, hook, name, ok, err)
	_R.Vector.__metatable = nil
	_R.Angle.__metatable = nil
	_R.VMatrix.__metatable = nil
end

SF.Libraries.AddHook("prepare", restrict)
SF.Libraries.AddHook("cleanup", unrestrict)

-- ------------------------- Hook Documentation ------------------------- --

--- Think hook. Called once per game tick
-- @name think
-- @class hook
-- @shared
