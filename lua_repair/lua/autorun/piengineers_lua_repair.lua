--[[
Workshop:		https://steamcommunity.com/sharedfiles/filedetails/?id=2403043112
Profile Page:	https://steamcommunity.com/id/Piengineer12
GitHub Page:	https://github.com/Piengineer12/public-addons/tree/master/lua_repair
Donate:			https://ko-fi.com/piengineer12

Links above are confirmed working as of 2021-06-23. All dates are in ISO 8601 format. 
]]

LUA_REPAIR_VERSION = "1.3.1"
LUA_REPAIR_VERSION_DATE = "2021-06-23"

local FIXED
local color_aqua = Color(0, 255, 255)

local function Log(...)
	local message = {color_aqua, "[Lua Repair] ", color_white, ...}
	table.insert(message, '\n')
	MsgC(unpack(message))
end

-- aaand pretty much everything here is dangerous
local function FixAllErrors()
	if LUA_REPAIR_FIXED then return end
	
	local NIL = getmetatable(nil) or {}
	local STRING = getmetatable("")
	local VECTOR = FindMetaTable("Vector")
	local CLUAEMITTER = FindMetaTable("CLuaEmitter")
	local NULL_META = getmetatable(NULL)
	local newNilMeta = {
		__add = function(a,b)
			return a or b
		end,
		__sub = function(a,b)
			return a or b
		end,
		__mul = function(a,b)
			return a or b
		end,
		__div = function(a,b)
			return a
		end,
		__pow = function(a,b)
			if not b then return 1 else return 0 end
		end,
		__unm = function(a)
			return a
		end,
		__concat = function(a,b)
			return tostring(a) .. tostring(b)
		end,
		__len = function()
			return 0
		end,
		__lt = function(a,b)
			if isnumber(a) or isnumber(b) then
				return (a or 0) < (b or 0)
			else
				return tostring(a) < tostring(b)
			end
		end,
		__le = function(a,b)
			if isnumber(a) or isnumber(b) then
				return (a or 0) <= (b or 0)
			else
				return tostring(a) <= tostring(b)
			end
		end,
		__index = function()
		end,
		__newindex = function()
		end,
		__call = function()
		end
	}
	for k,v in pairs(newNilMeta) do
		NIL[k] = v
	end
	STRING.__concat = function(a,b)
		return tostring(a)..tostring(b)
	end
	STRING.IsValid = function()
		return true
	end
	local oldadd,oldsub = VECTOR.__add,VECTOR.__sub
	local oldmul,olddiv = VECTOR.__mul,VECTOR.__div
	VECTOR.__add = function(a,b)
		return oldadd(isvector(a) and a or Vector(a),isvector(b) and b or Vector(b))
	end
	VECTOR.__sub = function(a,b)
		return oldsub(isvector(a) and a or Vector(a),isvector(b) and b or Vector(b))
	end
	VECTOR.__mul = function(a,b)
		return oldmul(a or 1,b or 1)
	end
	VECTOR.__div = function(a,b)
		return olddiv(a or 1,b or 1)
	end
	local oldGC = NULL_META.GetClass
	NULL_META.GetClass = function(ent,...)
		if ent == NULL then
			return ent.__tostring(ent,...)
		else return oldGC(ent,...)
		end
	end
	local oldPos = NULL_META.GetPos
	NULL_META.GetPos = function(ent,...)
		if ent == NULL then
			return vector_origin
		else return oldPos(ent,...)
		end
	end
	--[[local oldindex = NULL_META.__index
	NULL_META.__index = function(ent,key)
		if rawget() then
			local args = {pcall(oldindex,ent,key)}
			if not args[1] then
				error("Attempt to call \""..key.."\" on a NULL entity (tell the owner of \"Lua and Model Error Fixers\" about it!)")
			end
		else return oldindex(ent,key)
		end
	end]]
	if CLUAEMITTER then
		local oldFinish = CLUAEMITTER.Finish
		CLUAEMITTER.Finish = function(emitter,...)
			if emitter:IsValid() then return oldFinish(emitter,...) end
		end		
	end
	
	debug.setmetatable(nil,NIL)
	
	hook.Add("Initialize", "LUA_REPAIR", function()
		local shouldBlockCommands = {
			["con_filter_enable"] = true,
			["con_filter_text_out"] = true,
			["crosshair"] = true,
			["sv_cheats"] = true
		}
		local blockedCommands = {}
		
		local function ReportBlockedCommand(cmd)
			if not blockedCommands[cmd] then
				Log("An addon tried to use the console command "..cmd.." which is not allowed.")
				if table.IsEmpty(blockedCommands) then
					Log("(You will only see this message once per console command.)")
				end
				blockedCommands[cmd] = true
			end
		end
		
		local oldRunConsoleCommand = RunConsoleCommand
		RunConsoleCommand = function(cmd, ...)
			if shouldBlockCommands[cmd] then
				ReportBlockedCommand(cmd)
			else
				oldRunConsoleCommand(cmd, ...)
				--[[local resultTab = {pcall(oldRunConsoleCommand, cmd, ...)}
				if not resultTab[1] then
					ReportBlockedCommand(cmd)
				end]]
			end
		end
		local oldGameConsoleCommand = game.ConsoleCommand
		game.ConsoleCommand = function(cmdStr, ...)
			local cmd = string.match(cmdStr, "^\"([^\"]+)\"")
			if not cmd then
				cmd = string.match(cmdStr, "^[^%s%c]+")
			end
			if shouldBlockCommands[cmd] then
				ReportBlockedCommand(cmd)
			else
				oldGameConsoleCommand(cmdStr, ...)
				--[[local resultTab = {pcall(oldGameConsoleCommand, cmdStr, ...)}
				if not resultTab[1] then
					ReportBlockedCommand(cmd)
				end]]
			end
		end
		local PLAYER = FindMetaTable("Player")
		local oldConCommand = PLAYER.ConCommand
		PLAYER.ConCommand = function(self, cmdStr, ...)
			local cmd = string.match(cmdStr, "^\"([^\"]+)\"")
			if not cmd then
				cmd = string.match(cmdStr, "^[^%s%c]+")
			end
			if shouldBlockCommands[cmd] then
				ReportBlockedCommand(cmd)
			else
				oldConCommand(self, cmdStr, ...)
				--[[local resultTab = {pcall(oldConCommand, cmdStr, ...)}
				if not resultTab[1] then
					ReportBlockedCommand(cmd)
				end]]
			end
		end
		
		ErrorNoHalt = function(...)
			--Log("ErrorNoHalt: ", ...)
		end
		Error = function(...)
			--Log("Error: ", ...)
		end
		
		if SERVER then
			Log("Replaced server console command functions!")
		end
		if CLIENT then
			Log("Replaced client console command functions!")
		end
	end)
	
	LUA_REPAIR_FIXED = true
end

FixAllErrors()

if SERVER then
	Log("Serverside Lua has been repaired! Remember that if you are a Lua developer, please disable this addon or your users may get errors from your code!")
end
if CLIENT then
	Log("Clientside Lua has been repaired! If you still see errors remember to report the full error message to the creator of Lua Repair!")
end

--[[function SetAutoFix(bool)
	if bool then
		cookie.Delete("dont_lua_repair")
	else
		cookie.Set("dont_lua_repair", 1)
	end
end

function GetAutoFix()
	return not cookie.GetString("dont_lua_repair")
end

if GetAutoFix() then
	FixAllErrors()
end]]

if SERVER then util.AddNetworkString("lua_repair") end

if CLIENT then
	concommand.Add("lua_repair_run",function(ply,cmd,args,str)
		FixAllErrors()
		net.Start("lua_repair")
		net.SendToServer()
	end)
end

net.Receive("lua_repair",function()
	FixAllErrors()
end)

hook.Add("AddToolMenuCategories","lua_repair",function()
	spawnmenu.AddToolCategory("Utilities","lua_repair","Lua Repair")
end)

hook.Add("OnReloaded","lua_repair",function()
	if FIXED and CLIENT then
		chat.AddText(Color(255,0,0),"Make sure to turn off Lua Repair first before editing your Lua files!")
	end
end)

hook.Add("PopulateToolMenu","lua_repair",function()
	spawnmenu.AddToolMenuOption("Utilities","lua_repair","lua_repair","Lua Repair","","",function(DForm)
		local DLabel = DForm:Help("WARNING: If you are a Lua developer, make sure that this feature is OFF before testing your code!\n\n\z
		Note that this functionality might cause slight performance issues.")
		DLabel:SetTextColor(Color(255,0,0))
		DForm:Button("Run Lua Repair","lua_repair_run")
		--[[local checkBoxLabel = vgui.Create("DCheckBoxLabel")
		checkBoxLabel:SetText("Run On Startup")
		checkBoxLabel:SetValue(GetAutoFix())
		function checkBoxLabel:OnChange(bool)
			SetAutoFix(bool)
		end
		DForm:AddItem(checkBoxLabel)]]
	end)
end)