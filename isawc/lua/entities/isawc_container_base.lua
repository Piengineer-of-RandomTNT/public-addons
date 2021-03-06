ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName = "Base Container"
ENT.Category = "ISAWC"
ENT.Author = "Piengineer"
ENT.Contact = "http://steamcommunity.com/id/Piengineer12/"
ENT.Purpose = "Base container for the Inventory System."
ENT.Instructions = "Link this container to something."
ENT.AutomaticFrameAdvance = true
ENT.Editable = true

ENT.ContainerModel = Model("models/props_junk/watermelon01.mdl")
ENT.OpenAnimTime = 1
ENT.CloseAnimTime = 1
ENT.ContainerMassMul = 1
ENT.ContainerVolumeMul = 1
ENT.ContainerCountMul = 1
ENT.OpenSounds = {}
ENT.CloseSounds = {}

ENT.ISAWC_Inventory = {}
ENT.ISAWC_Openers = {}

AddCSLuaFile()

function ENT:SetupDataTables()
	self:NetworkVar("Bool",0,"IsPublic",{KeyName="is_public",Edit={type="Boolean",title="Anyone Can Use",order=1}})
	self:NetworkVar("Int",0,"ContainerHealth",{KeyName="isawc_health",Edit={type="Int",title="Container Health",min=0,max=1000,order=2}})
	self:NetworkVar("Int",1,"OwnerAccountID")
	self:NetworkVar("Int",2,"PlayerTeam")
	self:NetworkVar("Float",0,"MassMul",{KeyName="isawc_mass_mul",Edit={type="Float",category="Multipliers",title="Mass Mul.",min=0,max=10,order=5}})
	self:NetworkVar("Float",1,"VolumeMul",{KeyName="isawc_volume_mul",Edit={type="Float",category="Multipliers",title="Volume Mul.",min=0,max=10,order=6}})
	self:NetworkVar("Float",2,"CountMul",{KeyName="isawc_count_mul",Edit={type="Float",category="Multipliers",title="Count Mul.",min=0,max=10,order=7}})
	self:NetworkVar("String",1,"FileID")
	self:NetworkVar("String",2,"EnderInvName",{KeyName="enderchest_inv_name",Edit={type="Generic",title="Inv. ID (for EnderChests)",order=3}})
	
	self:SetMassMul(1)
	self:SetVolumeMul(1)
	self:SetCountMul(1)
end

function ENT:SpawnFunction(ply,trace,classname)
	if not trace.Hit then return end
	
	local ent = ents.Create(classname)
	ent:Spawn()
	ent:Activate()
	ent:SetPos(trace.HitPos-trace.HitNormal*ent:OBBMins().z)
	local ang = ply:GetAngles()
	ang.p = 0
	ang.y = ang.y + 180
	ent:SetAngles(ang)
	
	return ent
end

function ENT:ISAWC_Initialize()
end

function ENT:Initialize()
	if SERVER then
		self:SetModel(self.ContainerModel)
		self:SetTrigger(true)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local physobj = self:GetPhysicsObject()
		if IsValid(physobj) then
			physobj:Wake()
			if ISAWC.ConAutoHealth:GetFloat() > 0 and self:GetContainerHealth()==0 then
				self:SetContainerHealth(math.max(math.Round(physobj:GetVolume()*0.001*ISAWC.ConAutoHealth:GetFloat(),-1),10))
			end
		end
		self:PrecacheGibs()
		self:SendInventoryUpdate()
		if WireLib then
			self.Inputs = WireLib.CreateSpecialInputs(self,
				{"Disable"},
				{"NORMAL"}
			)
			self.Outputs = WireLib.CreateSpecialOutputs(self,
				{"Mass", "Volume", "Count", "MaxMass", "MaxVolume", "MaxCount"},
				{"NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL"}
			)
			local baseClass = baseclass.Get("base_wire_entity")
			self.ISAWC_OnRemove = baseClass.OnRemove
			self.OnRestore = baseClass.OnRestore
			self.BuildDupeInfo = baseClass.BuildDupeInfo
			self.ApplyDupeInfo = baseClass.ApplyDupeInfo
			self.PreEntityCopy = baseClass.PreEntityCopy
			self.OnEntityCopyTableFinish = baseClass.OnEntityCopyTableFinish
			self.OnDuplicated = baseClass.OnDuplicated
			self.PostEntityPaste = baseClass.PostEntityPaste
		end
	end
	self:ISAWC_Initialize()
	if SERVER and (IsValid(self:GetCreator()) and self:GetCreator():IsPlayer()) then
		self:SetOwnerAccountID(self:GetCreator():AccountID() or 0)
		self:SetPlayerTeam(self:GetCreator():Team())
	end
	local endername = self:GetEnderInvName()
	if (endername or "")~="" and table.IsEmpty(self.ISAWC_Inventory) then
		for k,v in pairs(ents.GetAll()) do
			if (IsValid(v) and v.Base=="isawc_container_base" and v:GetEnderInvName()==endername and not table.IsEmpty(v.ISAWC_Inventory)) then
				self.ISAWC_Inventory = v.ISAWC_Inventory break
			end
		end
	end
	if (self:GetFileID() or "")=="" and SERVER then
		local container_ents = {}
		for k,v in pairs(ents.GetAll()) do
			if v.Base == "isawc_container_base" then
				container_ents[v:GetFileID()] = v
			end
		end
		local function GenStringFile()
			local str = ""
			for i=1,8 do
				str = str .. string.char(math.random(32, 126))
			end
			return str
		end
		while self:GetFileID()=="" or file.Exists("isawc_containers/"..self:GetFileID()..".dat","DATA") or container_ents[self:GetFileID()] do
			self:SetFileID(GenStringFile())
		end
	end
	if ISAWC.ConSaveIntoFile:GetBool() then
		if file.Exists("isawc_containers/"..self:GetFileID()..".dat","DATA") then
			self.ISAWC_Inventory = table.DeSanitise(util.JSONToTable(util.Decompress(file.Read("isawc_containers/"..self:GetFileID()..".dat"))))
		end
	end
	self.MagnetScale = self:BoundingRadius()
	self.NextRegenThink = CurTime()
	self.MagnetTraceResult = {}
end

function ENT:Touch(ent)
	if ISAWC.ConDragAndDropOntoContainer:GetInt()==1 and not self.ISAWC_Disabled then
		if ISAWC:CanProperty(self,ent) then
			ISAWC:PropPickup(self,ent)
			self:SendInventoryUpdate()
		end
	end
end

function ENT:StartTouch(ent)
	if ISAWC.ConDragAndDropOntoContainer:GetInt()==2 and not self.ISAWC_Disabled then
		if ISAWC:CanProperty(self,ent) then
			ISAWC:PropPickup(self,ent)
			self:SendInventoryUpdate()
		end
	end
end

function ENT:TriggerInput(input, value)
	if input == "Disable" then
		self.ISAWC_Disabled = tobool(value)
	end
end

function ENT:Use(activator,caller,typ,data)
	if activator:IsPlayer() then
		if self:GetOwnerAccountID()==0 then
			self:SetOwnerAccountID(activator:AccountID() or 0)
		end
		if self:GetPlayerTeam()==0 then
			self:SetPlayerTeam(activator:Team() or 0)
		end
		if ISAWC:IsLegalContainer(self, activator, true) then
			for k,v in pairs(self.ISAWC_Openers) do
				if not IsValid(k) then self.ISAWC_Openers[k] = nil end
			end
			if not next(self.ISAWC_Openers) then
				net.Start("isawc_general")
				net.WriteString("container_open")
				net.WriteEntity(self)
				if self.ISAWC_Template then -- This is a really bad way to make sure clients know the sounds this container makes... I can't be bothered to make this better though.
					net.WriteString(table.concat(self.OpenSounds,'|'))
					net.WriteString(table.concat(self.CloseSounds,'|'))
				end
				net.SendPAS(self:GetPos())
			end
			self.ISAWC_Openers[activator] = true
			net.Start("isawc_general")
			net.WriteString("inv_container")
			net.WriteEntity(self)
			net.Send(activator)
		else
			ISAWC:NoPickup("Only the container's owner can open this!",activator)
		end
	end
end

function ENT:OpenAnim()
end

function ENT:CloseAnim()
end

function ENT:OnTakeDamage(dmginfo)
	local physobj = self:GetPhysicsObject()
	if IsValid(physobj) then
		physobj:AddVelocity(dmginfo:GetDamageForce()/physobj:GetMass())
	end
	if self:GetMaxHealth() > 0 then
		self:SetHealth(self:Health()-dmginfo:GetDamage())
		if self:Health() <= 0 then
			if IsValid(physobj) then
				self:GibBreakServer(dmginfo:GetDamageForce()*physobj:GetMass())
			else
				self:GibBreakServer(dmginfo:GetDamageForce())
			end
			self:Remove()
		end
	end
end

function ENT:OnRemove()
	if SERVER and self.ISAWC_Inventory and ISAWC.ConDropOnDeathContainer:GetBool() and IsValid(self:GetCreator()) then
		ISAWC:SetSuppressUndo(true)
		for i=1,#self.ISAWC_Inventory do
			local dupe = self.ISAWC_Inventory[i]
			if dupe then
				ISAWC:SpawnDupe2(dupe,true,true,i,self:GetCreator(),self)
			end
		end
		ISAWC:SetSuppressUndo(false)
		table.Empty(self.ISAWC_Inventory)
		ISAWC:SaveContainerInventory(self)
		if (self.ISAWC_OnRemove) then
			self:ISAWC_OnRemove()
		end
	end
end

function ENT:Think()
	if SERVER then
		if self.CHealth~=self:GetContainerHealth() then
			self.CHealth = self:GetContainerHealth()
			self:SetHealth(self.CHealth)
			self:SetMaxHealth(self.CHealth)
		end
		if not self.NextRegenThink then
			self.NextRegenThink = CurTime()
		end
		if self.NextRegenThink <= CurTime() and ISAWC.ConContainerRegen:GetFloat() ~= 0 then
			while self.NextRegenThink <= CurTime() do
				self.NextRegenThink = self.NextRegenThink + math.abs(1/ISAWC.ConContainerRegen:GetFloat())
				if ISAWC.ConContainerRegen:GetFloat() > 0 and self:Health() < self:GetMaxHealth() then
					self:SetHealth(self:Health()+1)
				elseif ISAWC.ConContainerRegen:GetFloat() < 0 then
					self:TakeDamage(1,self,self)
				end
			end
		end
		if ISAWC.ConMagnet:GetFloat() > 0 and not ISAWC:StringMatchParams(self:GetClass(), ISAWC.BlackContainerMagnetList) and not self.ISAWC_IsDeathDrop then
			self:FindMagnetablesInSphere()
		elseif self.ISAWC_IsDeathDrop and not self.ISAWC_Inventory[1] then
			timer.Simple(ISAWC.ConDeathRemoveDelay:GetFloat()-4.24, function()
				if IsValid(self) then
					self:SetRenderMode(RENDERMODE_GLOW)
					self:SetRenderFX(kRenderFxFadeSlow)
					timer.Simple(4.24,function()
						SafeRemoveEntity(self)
					end)
				end
			end)
		end
	end
	if CLIENT then
		if (self.FinishOpenAnimTime or 0) >= CurTime() then
			self.ContainerState="opening"
			self:OpenAnim(1-(self.FinishOpenAnimTime-CurTime())/self.OpenAnimTime)
		elseif self.ContainerState=="opening" then
			self.ContainerState="opened"
			self:OpenAnim(1)
		end
		if (self.FinishCloseAnimTime or 0) >= CurTime() then
			self.ContainerState="closing"
			self:CloseAnim(1-(self.FinishCloseAnimTime-CurTime())/self.CloseAnimTime)
		elseif self.ContainerState=="closing" then
			self.ContainerState="closed"
			self:CloseAnim(1)
		end
	end
end

function ENT:FindMagnetablesInSphere()
	self.MagnetScale = self.MagnetScale or self:BoundingRadius()
	for k,v in pairs(ents.FindInSphere(self:LocalToWorld(self:OBBCenter()), ISAWC.ConMagnet:GetFloat()*self.MagnetScale)) do
		if v ~= self then
			if ISAWC.ConUseMagnetWhitelist:GetBool() then
				if ISAWC:StringMatchParams(v:GetClass(), ISAWC.WhiteMagnetList) then
					self:Magnetize(v)
				end
			else
				self:Magnetize(v)
			end
		end
	end
end

function ENT:Magnetize(ent)
	if not IsValid(ent:GetParent()) and ISAWC:CanPickup(self,ent,true) then
		local trace = util.TraceLine({
			start = self:GetPos(),
			endpos = ent:GetPos(),
			filter = self,
			mask = MASK_SOLID,
			output = self.MagnetTraceResult
		})
		local result = self.MagnetTraceResult
		if not result.Hit or result.HitNonWorld and result.Entity == ent then
			if IsValid(ent:GetPhysicsObject()) and ent:GetMoveType()==MOVETYPE_VPHYSICS then
				local dir = self:GetPos()-ent:GetPos()
				local nDir = dir:GetNormalized()
				nDir:Mul(math.min(self.MagnetScale*5e4*ISAWC.ConMagnet:GetFloat()/dir:LengthSqr(), 1000))
				ent:GetPhysicsObject():AddVelocity(nDir)
			else
				self:Touch(ent)
				self:StartTouch(ent)
			end
		end
	end
end

function ENT:SendInventoryUpdate()
	--[[for k,v in pairs(self.ISAWC_Openers) do
		if IsValid(k) then
			ISAWC:SendInventory2(k, self)
		else
			self.ISAWC_Openers[k] = nil
		end
	end]]
	if WireLib then
		local stats = ISAWC:GetClientStats(self)
		Wire_TriggerOutput(self, "Mass", stats[1])
		Wire_TriggerOutput(self, "MaxMass", stats[2])
		Wire_TriggerOutput(self, "Volume", stats[3] * ISAWC.dm3perHu)
		Wire_TriggerOutput(self, "MaxVolume", stats[4] * ISAWC.dm3perHu)
		Wire_TriggerOutput(self, "Count", stats[5])
		Wire_TriggerOutput(self, "MaxCount", stats[6])
	end
end