--- Provides permissions for clients

local P = {}
P.id = "client"
P.name = "Client Permissions"
P.settings = {}
P.settingsdesc = {}
P.settingsoptions = { "Only You", "Friends Only", "Anyone", "No one" }

function P.registered (id, name, description, arg)

	if arg and arg.Client then
		P.settingsdesc[id] = { name, description }
		if not P.settings[id] then
			P.settings[id] = arg.Client.default or 3
		end
	end

end

P.checks = {
	function(principal, target, key)
		return LocalPlayer()==principal
	end,
	function(principal, target, key)
		local me = LocalPlayer()
		if me==principal then return true end
		if not IsValid(principal) then return false end
		if me.IsFriend then return me:IsFriend(principal) end
		return principal:GetFriendStatus()=="friend"
	end,
	function() return true end,
	function() return false end
}

SF.Permissions.registerProvider(P)
