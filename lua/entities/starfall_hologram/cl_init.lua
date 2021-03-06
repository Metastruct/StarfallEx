include("shared.lua")

ENT.RenderGroup = RENDERGROUP_BOTH

-- Umsgs may be recieved before the entity is initialized, place
-- them in here until initialization.
local msgQueueNames = {}
local msgQueueData = {}

local function msgQueueAdd (umname, ent, udata)
	local names, data = msgQueueNames[ent], msgQueueData[ent]
	if not names then
		names, data = {}, {}
		msgQueueNames[ent] = names
		msgQueueData[ent] = data
	end
	
	local i = #names + 1
	names[i] = umname
	data[i] = udata
end

local function msgQueueProcess (ent)
	local entid = ent:EntIndex()
	local names, data = msgQueueNames[entid], msgQueueData[entid]
	if names then
		for i = 1 , #names do
			local name = names[i]
			if name == "scale" then
				ent:SetHoloScale(data[i])
			elseif name == "clip" then
				ent:UpdateClip(unpack(data[i]))
			end
		end
		
		msgQueueNames[entid] = nil
		msgQueueData[entid] = nil
	end
end

-- ------------------------ MAIN FUNCTIONS ------------------------ --

function ENT:Initialize()
	self.clips = {}
	self.initialised = true
	msgQueueProcess(self)
end

function ENT:setupClip ()
	-- Setup Clipping
	local l = #self.clips
	if l > 0 then
		render.EnableClipping(true)
		for _, clip in pairs(self.clips) do
			if clip.enabled and clip.normal and clip.origin then
				local norm = clip.normal
				local origin = clip.origin

				if clip.islocal then
					norm = self:LocalToWorld(norm) - self:GetPos()
					origin = self:LocalToWorld(origin)
				end
				render.PushCustomClipPlane(norm, norm:Dot(origin))
			end
		end
	end
end

function ENT:finishClip ()
	for i = 1, #self.clips do
		render.PopCustomClipPlane()
	end
	render.EnableClipping(false)
end

function ENT:setupRenderGroup ()
	local alpha = self:GetColor().a

	if alpha == 0 then return end

	if alpha ~= 255 then
		self.RenderGroup = RENDERGROUP_BOTH
	else
		self.RenderGroup = RENDERGROUP_OPAQUE
	end
end

function ENT:Draw()
	self:setupRenderGroup()
	self:setupClip()

	render.SuppressEngineLighting(self:GetSuppressEngineLighting())
	if self.rendered_once and self.custom_mesh then
		if self.custom_meta_data[self.custom_mesh] then
			local m = self:GetBoneMatrix(0)
			if self.scale_matrix then m = m * self.scale_matrix end
			cam.PushModelMatrix(m)
			local mat = Material(self:GetMaterial())
			if mat then render.SetMaterial(mat) end
			local col = self:GetColor()
			render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
			self:DrawModel() --For some reason won't draw without this call
			self.custom_mesh:Draw()
			cam.PopModelMatrix()
		else
			self.custom_mesh = nil
		end
	else
		self:DrawModel()
		self.rendered_once = true
	end
	render.SuppressEngineLighting(false)

	self:finishClip()
end

-- ------------------------ CLIPPING ------------------------ --

--- Updates a clip plane definition.
function ENT:UpdateClip(index, enabled, origin, normal, islocal)
	local clip = self.clips[index]
	if not clip then
		clip = {}
		self.clips[index] = clip
	end

	clip.enabled = enabled
	clip.normal = normal
	clip.origin = origin
	clip.islocal = islocal
end

net.Receive("starfall_hologram_clip", function ()
	local entid = net.ReadUInt(32)
	local holoent = Entity(entid)
	if (not IsValid(holoent)) or (not holoent.initialised) then
		-- Uninitialized
		msgQueueAdd("clip", entid, {
			net.ReadUInt(16),
			net.ReadBit() ~= 0,
			net.ReadVector(),
			net.ReadVector(),
			net.ReadBit() ~= 0
		})
	else
		holoent:UpdateClip (net.ReadUInt(16),
			net.ReadBit() ~= 0,
			net.ReadVector(),
			net.ReadVector(),
			net.ReadBit() ~= 0)
	end
end)

-- ------------------------ SCALING ------------------------ --

--- Sets the hologram scale
-- @param scale Vector scale
function ENT:SetHoloScale (scale)
	if scale == vector_origin then return end
	if scale == Vector(1, 1, 1) then
		self.scale_matrix = Matrix()
		self:DisableMatrix("RenderMultiply")
	else
		self.scale_matrix = Matrix()
		self.scale_matrix:Scale(scale)
		self:EnableMatrix("RenderMultiply", self.scale_matrix)
	end
	self.scale = scale

	local propmax = self:OBBMaxs()
	local propmin = self:OBBMins()
	
	propmax.x = scale.x * propmax.x
	propmax.y = scale.y * propmax.y
	propmax.z = scale.z * propmax.z
	propmin.x = scale.x * propmin.x
	propmin.y = scale.y * propmin.y
	propmin.z = scale.z * propmin.z
	
	self:SetRenderBounds(propmax, propmin)
end

net.Receive("starfall_hologram_scale", function ()
	local entid = net.ReadUInt(32)
	local holoent = Entity(entid)
	if (not IsValid (holoent)) or (not holoent.initialised) then
		-- Uninitialized
		msgQueueAdd("scale", entid, Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()))
	else
		holoent:SetHoloScale(Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()))
	end
end)

hook.Add("NetworkEntityCreated", "starfall_hologram_rescale", function(ent)
	if ent.SetHoloScale then
		if ent.scale then
			ent:SetHoloScale(ent.scale)
		else
			net.Start("starfall_hologram_init")
			net.WriteEntity(ent)
			net.SendToServer()
		end
	end
end)

local function ShowHologramOwners()
	for _, ent in pairs(ents.FindByClass("starfall_hologram")) do
		local name = "No Owner"
		local steamID = ""
		local ply = ent:GetHoloOwner()
		if ply:IsValid() then
			name = ply:Name()
			steamID = ply:SteamID()
		end
		
		local vec = ent:GetPos():ToScreen()
		
		draw.DrawText(name .. "\n" .. steamID, "DermaDefault", vec.x, vec.y, Color(255, 0, 0, 255), 1)
	end
end

local display_owners = false
concommand.Add("sf_holograms_display_owners", function()
	display_owners = not display_owners

	if display_owners then 
		hook.Add("HUDPaint", "sf_holograms_showowners", ShowHologramOwners)
	else
		hook.Remove("HUDPaint", "sf_holograms_showowners")
	end
end)
