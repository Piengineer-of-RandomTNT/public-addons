AddCSLuaFile()

--SWEP.Base = "weapon_base"
SWEP.PrintName = "RotgB Game SWEP"
SWEP.Category = "RotgB"
SWEP.Author = "Piengineer"
SWEP.Contact = "http://steamcommunity.com/id/Piengineer12/"
SWEP.Purpose = "The SWEP for RotgB, successor to the Multitool."
SWEP.Instructions = "See the on-screen HUD for instructions."
SWEP.WorldModel = "models/weapons/w_c4.mdl"
SWEP.ViewModel = "models/weapons/cstrike/c_c4.mdl"
SWEP.ViewModelFOV = 30
--SWEP.ViewModelFlip = false
--SWEP.ViewModelFlip1 = false
--SWEP.ViewModelFlip2 = false
SWEP.Spawnable = true
--SWEP.AdminOnly = false
SWEP.Slot = 1
--SWEP.SlotPos = 10
--SWEP.BounceWeaponIcon = true
--SWEP.DrawAmmo = true
SWEP.DrawCrosshair = false
--SWEP.AccurateCrosshair = false
--SWEP.DrawWeaponInfoBox = true
--SWEP.WepSelectIcon = surface.GetTextureID("weapons/swep")
--SWEP.SpeechBubbleLid = surface.GetTextureID("gui/speech_lid")
SWEP.AutoSwitchFrom = false
SWEP.AutoSwitchTo = false
--SWEP.Weight = 5
--SWEP.CSMuzzleFlashes = false
--SWEP.CSMuzzleX = false
--SWEP.BobScale = 1
--SWEP.SwayScale = 1
SWEP.UseHands = true
SWEP.m_WeaponDeploySpeed = 1
--SWEP.m_bPlayPickupSound = true
SWEP.RenderGroup = RENDERGROUP_BOTH
--SWEP.ScriptedEntityType = "weapon"
--SWEP.IconOverride = "materials/entities/base.png"
--SWEP.DisableDuplicator = false
SWEP.Primary = {
	Ammo = "none",
	ClipSize = -1,
	DefaultClip = -1,
	Automatic = false
}
SWEP.Secondary = {
	Ammo = "none",
	ClipSize = -1,
	DefaultClip = -1,
	Automatic = false
}
local ROTGB_TRANSFER = 1
local ROTGB_SETTOWER = 2
local ROTGB_SPEED = 3
local ROTGB_PLAY = 4
local ROTGB_AUTOSTART = 5

if SERVER then
	util.AddNetworkString("rotgb_controller")
end

local ConR = GetConVar("rotgb_range_enable_indicators")
local ConH = GetConVar("rotgb_range_hold_time")
local ConT = GetConVar("rotgb_range_fade_time")
local ConA = GetConVar("rotgb_range_alpha")

local color_black_semiopaque = Color(0, 0, 0, 191)
local color_gray = Color(127, 127, 127)
local color_light_gray = Color(191, 191, 191)
local color_red = Color(255, 0, 0)
local color_light_red = Color(255, 127, 127)
local color_orange = Color(255, 127, 0)
local color_light_orange = Color(255, 191, 127)
local color_green = Color(0, 255, 0)
local color_light_green = Color(127, 255, 127)
local color_aqua = Color(0, 255, 255)
local color_light_aqua = Color(127, 255, 255)
local color_light_blue = Color(127, 127, 255)

local padding = 8
local buttonHeight = 48
local screenMaterial = Material("models/screenspace")

function SWEP:SetupDataTables()
	self:NetworkVar("Int",0,"CurrentTower")
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	if IsValid(self:GetOwner()) and self:GetCurrentTower() ~= 0 then
		local ply = self:GetOwner()
		local trace = self:BuildTraceData(ply)
		if trace.Hit then
			if not self.TowerTable then
				self.TowerTable = self:BuildTowerTable()
			end
			local tempang = ply:GetAngles()
			tempang.p = 0
			tempang.r = 0
			if ply:IsNPC() then
				self:SetCurrentTower(math.random(#self.TowerTable))
			end
			local tower = ents.Create(self.TowerTable[self:GetCurrentTower()].class)
			tower:SetPos(trace.HitPos)
			tower:SetAngles(tempang)
			tower:SetTowerOwner(ply)
			tower:Spawn()
			--util.ScreenShake(ply:GetShootPos(), 4, 20, 0.5, 64)
			tower:EmitSound("phx/epicmetal_soft"..math.random(7)..".wav",60,100,0.5,CHAN_WEAPON)
			if (ply:IsPlayer() and not ply:IsSprinting()) then
				self:SetCurrentTower(0)
				--self:SendWeaponAnim(ACT_VM_DRAW)
			end
		else
			ply:EmitSound("items/medshotno1.wav",60,100,1,CHAN_WEAPON)
		end
	end
end

function SWEP:CanSecondaryAttack()
	return CLIENT and self:GetOwner() == LocalPlayer()
end

function SWEP:SecondaryAttack()
	if game.SinglePlayer() then self:CallOnClient("SecondaryAttack") end
	if self:CanSecondaryAttack() then
		if IsValid(self.TowerMenu) then
			if self.TowerMenu:IsVisible() then
				self.TowerMenu:Hide()
			else
				self.TowerMenu:Show()
				self.TowerMenu:MakePopup()
			end
		else
			self:CreateTowerMenu()
		end
	end
end

function SWEP:PostDrawViewModel(viewmodel, weapon, ply)
	if IsValid(viewmodel) and viewmodel:GetCycle()>0.99 then
		--if self:GetCurrentTower() == 0 then
			local renderPos, renderAngles = LocalToWorld(Vector(26.6,2,-2.5), Angle(1,-95,47), viewmodel:GetPos(), viewmodel:GetAngles())
			cam.Start3D2D(renderPos, renderAngles, 0.02)
			-- screen is 3.8 x 2.0
			if (IsValid(self.TowerMenu) and self.TowerMenu:IsVisible()) then
				draw.SimpleText("Secondary Fire", "Trebuchet24", 95, 38, color_aqua, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("to Hide Menu", "Trebuchet24", 95, 62, color_aqua, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText("Secondary Fire", "Trebuchet24", 95, 38, color_aqua, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("to Show Menu", "Trebuchet24", 95, 62, color_aqua, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			cam.End3D2D()
		--[[else
			local renderPos, renderAngles = LocalToWorld(Vector(19.15,1.3,0.2), Angle(-3,-92,69), viewmodel:GetPos(), viewmodel:GetAngles())
			cam.Start3D2D(renderPos, renderAngles, 0.1)
			-- screen is 3.8 x 2.0
			--draw.SimpleText("TEST")
			cam.End3D2D()
			if viewmodel:GetRenderFX() ~= kRenderFxFadeFast then
				viewmodel:SetRenderFX(kRenderFxFadeFast)
			end
		end]]
	end
end

function SWEP:Think()
	if not self.TowerTable then
		self.TowerTable = self:BuildTowerTable()
		self:SetHoldType("slam")
	end
	if CLIENT then
		if self:GetCurrentTower() == 0 then
			if IsValid(self.ClientsideModel) then
				self.ClientsideModel:Remove()
			end
			
			--[[local viewmodel = LocalPlayer():GetViewModel()
			if (IsValid(viewmodel) and viewmodel:GetRenderFX() ~= kRenderFxSolidFast) then
				viewmodel:SetRenderFX(kRenderFxSolidFast)
			end]]
		else
			local tower = self.TowerTable[self:GetCurrentTower()]
			if not IsValid(self.ClientsideModel) then
				self.ClientsideModel = ClientsideModel(tower.model, RENDERGROUP_BOTH)
				self.ClientsideModel:SetMaterial("models/wireframe")
				self.ClientsideModel:SetModel(tower.model)
				self.ClientsideModel:SetColor(color_aqua)
				self.ClientsideModel.TowerType = self:GetCurrentTower()
				self.ClientsideModel.RenderOverride = function(self)
					self:DrawModel()
					if tower.range < 16384 and ConR:GetBool() then
						local fadeout = ConT:GetFloat()
						self.DrawFadeNext = RealTime()+fadeout+ConH:GetFloat()
						if (self.DrawFadeNext or 0)>RealTime() then
							local scol = self:GetColor() == color_aqua and tower.infinite and color_blue or self:GetColor()
							local alpha = math.Clamp(math.Remap(self.DrawFadeNext-RealTime(),fadeout,0,ConA:GetFloat(),0),0,ConA:GetFloat())
							scol = Color(scol.r,scol.g,scol.b,alpha)
							render.DrawWireframeSphere(self:LocalToWorld(tower.losoffset),-tower.range,32,17,scol,true)
						end
					end
				end
			elseif self.ClientsideModel.TowerType ~= self:GetCurrentTower() then
				self.ClientsideModel:Remove()
			end
			
			local trace = self:BuildTraceData(LocalPlayer())
			if trace.Hit then
				self.ClientsideModel:SetPos(trace.HitPos)
				local tempang = LocalPlayer():EyeAngles()
				tempang.p = 0
				tempang.r = 0
				self.ClientsideModel:SetAngles(tempang)
			end
		end
	end
end

function SWEP:OnRemove()
	self:SetCurrentTower(0)
	if IsValid(self.TowerMenu) then
		self.TowerMenu:Close()
	end
	if IsValid(self.ClientsideModel) then
		self.ClientsideModel:Remove()
	end
	--[[if CLIENT then
		local viewmodel = LocalPlayer():GetViewModel()
		if (IsValid(viewmodel) and viewmodel:GetRenderFX() == kRenderFxFadeFast) then
			viewmodel:SetRenderFX(kRenderFxSolidFast)
		end
	end]]
end

function SWEP:Holster()
	self:SetCurrentTower(0)
	if IsValid(self.TowerMenu) then
		self.TowerMenu:Hide()
	end
	if IsValid(self.ClientsideModel) then
		self.ClientsideModel:Remove()
	end
	return true
end

if SERVER then
	net.Receive("rotgb_controller", function(length, ply)
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass()=="rotgb_control" then
			local func = net.ReadUInt(8)
			if func == ROTGB_TRANSFER then
				local ply2 = net.ReadEntity()
				if IsValid(ply2) and ply2:IsPlayer() and ply ~= ply2 then
					local cash = ROTGB_GetCash(ply)
					local transferAmount = math.floor(math.max(0, cash / 5, math.min(cash, 100)))
					ROTGB_AddCash(transferAmount, ply2)
					ROTGB_RemoveCash(transferAmount, ply)
				end
			elseif func == ROTGB_SETTOWER then
				local desiredtower = net.ReadUInt(8)
				if wep.TowerTable[desiredtower] or desiredtower == 0 then
					--[[if desiredtower == 0 then
						wep:SendWeaponAnim(ACT_VM_DRAW)
					elseif wep:GetCurrentTower() == 0 then
						wep:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
					end]]
					wep:SetCurrentTower(desiredtower)
				end
			elseif func == ROTGB_SPEED then
				local shouldGoFaster = net.ReadBool()
				local newSpeed = math.Clamp(game.GetTimeScale() * (shouldGoFaster and 2 or 0.5), 1, 8)
				game.SetTimeScale(newSpeed)
				if shouldGoFaster then
					ply:EmitSound("buttons/combine_button5.wav",60,80+math.log(game.GetTimeScale(),2)*20,1,CHAN_WEAPON)
				else
					ply:EmitSound("buttons/combine_button3.wav",60,100+math.log(game.GetTimeScale(),2)*20,1,CHAN_WEAPON)
				end
			elseif func == ROTGB_PLAY then
				local spawners = ents.FindByClass("gballoon_spawner")
				if table.IsEmpty(spawners) then
					ply:EmitSound("buttons/button18.wav",60,100,1,CHAN_WEAPON)
					return ply:PrintMessage(HUD_PRINTTALK, "Place one gBalloon Spawner first!")
				end
				for k,v in pairs(spawners) do
					v:Fire("Use")
				end
				ply:EmitSound("buttons/button14.wav",60,100,1,CHAN_WEAPON)
			elseif func == ROTGB_AUTOSTART then
				local shouldAutoStart = net.ReadBool()
				
				local spawners = ents.FindByClass("gballoon_spawner")
				if table.IsEmpty(spawners) then
					ply:EmitSound("buttons/button18.wav",60,100,1,CHAN_WEAPON)
					return ply:PrintMessage(HUD_PRINTTALK, "Place one gBalloon Spawner first!")
				end
				for k,v in pairs(spawners) do
					v:SetAutoStart(shouldAutoStart)
				end
				ply:EmitSound(shouldAutoStart and "buttons/button17.wav" or "buttons/button16.wav",60,100,1,CHAN_WEAPON)
			end
		end
	end)
end

function SWEP:GetCashText(amount)
	if amount == math.huge then return "$∞"
	elseif amount == -math.huge then return "$-∞"
	elseif not (amount < 0 or amount >= 0) then return "$?"
	else return '$'..string.Comma(math.floor(amount,0))
	end
end

function SWEP:BuildTowerTable()
	local towertable = {}
	for k,v in pairs(scripted_ents.GetList()) do
		if v.Base == "gballoon_tower_base" then
			table.insert(towertable, {class=v.t.ClassName, name=v.t.PrintName, purpose=v.t.Purpose, cost=v.t.Cost, model=v.t.Model, infinite=v.t.InfiniteRange, range=v.t.DetectionRadius,
			damage=v.t.AttackDamage, firerate=v.t.FireRate, losoffset=v.t.LOSOffset or vector_origin, material=Material("vgui/entities/"..v.t.ClassName)})
		end
	end
	table.sort(towertable, function(a,b)
		if a.cost == b.cost then
			return a.name < b.name
		else
			return a.cost < b.cost
		end
	end)
	return towertable
end

function SWEP:BuildTraceData(ent)
	self.CommonTraceData = self.CommonTraceData or {}
	self.TraceResult = self.TraceResult or {}
	self.CommonTraceData.start = ent:GetShootPos()
	self.CommonTraceData.endpos = ent:GetShootPos() + ent:GetAimVector() * 32767
	self.CommonTraceData.filter = ent
	self.CommonTraceData.output = self.TraceResult
	util.TraceLine(self.CommonTraceData)
	return self.TraceResult
end

function SWEP:DoTowerSelector(id)
	net.Start("rotgb_controller")
	net.WriteUInt(ROTGB_SETTOWER, 8)
	net.WriteUInt(id, 8)
	net.SendToServer()
end

function SWEP:DoNothing()
	-- needed for UI
end

local function PaintBackground(self, w, h)
	draw.RoundedBox(8, 0, 0, w, h, color_black_semiopaque)
end

function SWEP:CreateTowerMenu()
	local wep = self
	
	local Main = vgui.Create("DFrame")
	Main:SetPos(0,0)
	Main:SetSize(ScrW(),ScrH())
	Main:DockPadding(padding,padding,padding,padding)
	Main.Paint = self.DoNothing
	Main:MakePopup()
	self.TowerMenu = Main
	function Main:CreateButton(text, parent, color1, color2, color3)
		local Button = vgui.Create("DButton", parent)
		Button:SetFont("Trebuchet24")
		Button:SetText(text)
		Button:SetColor(color_black)
		Button:SetTall(buttonHeight)
		
		function Button:Paint(w, h)
			draw.RoundedBox(8, 0, 0, w, h, not self:IsEnabled() and color_gray or self:IsDown() and color3 or self:IsHovered() and color2 or color1)
		end
		
		return Button
	end
	function Main:AddHeader(text, parent)
		local Label = vgui.Create("DLabel", parent)
		Label:SetFont("Trebuchet24")
		Label:SetText(text)
		Label:DockMargin(0,0,0,padding)
		Label:SetColor(color_aqua)
		Label:SizeToContentsY()
		Label:Dock(TOP)
		
		return Label
	end
	function Main:AddSearchBox(parent)
		local TextEntry = vgui.Create("DTextEntry", parent)
		TextEntry:SetFont("Trebuchet24")
		TextEntry:SetPlaceholderText("Search...")
		TextEntry:SetTall(buttonHeight)
		TextEntry:Dock(TOP)
		
		return TextEntry
	end
	function Main:DrawTriangle(centerX, centerY, radius, angle)
		angle = math.rad(angle)
		local deg120 = math.pi*2/3
		local points = {}
		
		draw.NoTexture()
		surface.SetDrawColor(color_black)
		for i=0,2 do
			table.insert(points, {
				x = centerX + radius * math.sin(angle+i*deg120),
				y = centerY + radius * -math.cos(angle+i*deg120) -- y is down, not up
			})
		end
		
		surface.DrawPoly(points)
	end
	
	local LeftDivider = vgui.Create("DHorizontalDivider", Main)
	LeftDivider:Dock(FILL)
	LeftDivider:SetDividerWidth(padding)
	LeftDivider:SetLeftWidth(ScrW()*0.2-padding/2)
	
	local RightDivider = vgui.Create("DHorizontalDivider")
	LeftDivider:SetRight(RightDivider)
	RightDivider:SetDividerWidth(padding)
	RightDivider:SetLeftWidth(ScrW()*0.6-padding/2)
	
	LeftDivider:SetLeft(self:CreateLeftPanel(Main))
	RightDivider:SetRight(self:CreateRightPanel(Main))
	function Main:Think()
		if IsValid(wep) then
			local selectedTower = wep:GetCurrentTower()
			if selectedTower ~= self.TowerSelected then
				self.TowerSelected = selectedTower
				if selectedTower ~= 0 then
					self:SignalTowerSelected(wep, selectedTower)
				elseif selectedTower == 0 then
					self:SignalTowerUnselected(wep)
				end
			end
		else
			Main:Close()
		end
	end
	function Main:SignalTowerSelected(wep, index)
		local data = wep.TowerTable[wep:GetCurrentTower()]
		LeftDivider:GetLeft():Remove()
		LeftDivider:SetLeft(wep:CreateLeftTowerPanel(self, data))
	end
	function Main:SignalTowerUnselected(wep)
		LeftDivider:GetLeft():Remove()
		LeftDivider:SetLeft(wep:CreateLeftPanel(self))
	end
	
	local MiddlePanel = vgui.Create("DPanel")
	--MiddlePanel:DockPadding(padding,padding,padding,padding)
	RightDivider:SetLeft(MiddlePanel)
	MiddlePanel.Paint = self.DoNothing
	MiddlePanel:SetWorldClicker(true)
	
	local CloseButton = Main:CreateButton("Hide Menu", MiddlePanel, color_red, color_light_red, color_white)
	CloseButton:SizeToContentsX(buttonHeight-24)
	function CloseButton:DoClick()
		Main:Hide()
	end
	function MiddlePanel:PerformLayout(w, h)
		CloseButton:SetPos(w/2-CloseButton:GetWide()/2, h-CloseButton:GetTall())
	end
	
	--Main:AddHeader("Secondary Fire to Hide Menu", MiddlePanel)
	
	Main:SetTitle("")
	Main:ShowCloseButton(false)
end

function SWEP:CreateLeftPanel(Main)
	local wep = self
	local LeftPanel = vgui.Create("DPanel")
	LeftPanel.Paint = PaintBackground
	LeftPanel:DockPadding(padding,padding,padding,padding)
	local TransferHeader = Main:AddHeader("Transfer $0 To...", LeftPanel)
	
	local RefreshButton = Main:CreateButton("Refresh List", LeftPanel, color_green, color_light_green, color_white)
	RefreshButton:DockMargin(0,0,0,padding)
	RefreshButton:Dock(TOP)
	
	local ScrollPanel = vgui.Create("DScrollPanel", LeftPanel)
	function RefreshButton:DoClick()
		ScrollPanel:Refresh()
	end
	ScrollPanel:Dock(FILL)
	
	local SearchBox = Main:AddSearchBox(LeftPanel)
	SearchBox:DockMargin(0,0,0,padding)
	function ScrollPanel:Refresh()
		if IsValid(wep) then
			ScrollPanel:Clear()
			local text = SearchBox:GetValue():lower()
			
			for k,v in pairs(player.GetAll()) do
				if v:Nick():lower():find(text) --[[and v ~=LocalPlayer()]] then
					local NameButton = Main:CreateButton("", ScrollPanel, color_aqua, color_light_aqua, color_white)
					NameButton:DockMargin(0,0,0,padding)
					NameButton:Dock(TOP)
					function NameButton:DoClick()
						if IsValid(v) then
							net.Start("rotgb_controller")
							net.WriteUInt(ROTGB_TRANSFER, 8)
							net.WriteEntity(v)
							net.SendToServer()
							
							if not GetConVar("rotgb_individualcash"):GetBool() then
								chat.AddText(color_aqua, "It is pointless to use this option while Individual Cash\nis disabled (ConVar rotgb_individualcash).")
							end
						else
							ScrollPanel:Refresh()
						end
					end
					function NameButton:PaintOver(w,h)
						draw.SimpleText(v:Nick().." ("..wep:GetCashText(ROTGB_GetCash(v))..")", "Trebuchet24", w/2, h/2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
					
					if v == LocalPlayer() then
						NameButton:SetEnabled(false)
					end
				end
			end
		end
	end
	function SearchBox:OnChange()
		ScrollPanel:Refresh()
	end
	function TransferHeader:Think()
		local newCash = ROTGB_GetCash()
		local oldCash = self.cash
		if newCash ~= oldCash and (oldCash == oldCash or newCash == newCash) then -- needed to weed out NaNs
			self.cash = newCash
			local transferAmount = newCash == newCash and math.max(0, self.cash / 5, math.min(self.cash, 100)) or 0/0
			self:SetText(string.format("Transfer %s To...", wep:GetCashText(transferAmount)))
		end
	end
	ScrollPanel:Refresh()
	
	return LeftPanel
end

function SWEP:CreateLeftTowerPanel(Main, data)
	local wep = self
	local LeftPanel = vgui.Create("DPanel")
	LeftPanel.Paint = PaintBackground
	LeftPanel:DockPadding(padding,padding,padding,padding)
	Main:AddHeader(data.name, LeftPanel)
	
	local DescLabel = vgui.Create("DLabel", LeftPanel)
	DescLabel:Dock(TOP)
	DescLabel:SetWrap(true)
	DescLabel:SetAutoStretchVertical(true)
	DescLabel:SetFont("Trebuchet24")
	DescLabel:SetText(data.purpose)
	
	local DamageLabel = vgui.Create("DLabel", LeftPanel)
	DamageLabel:Dock(TOP)
	DamageLabel:SetFont("Trebuchet24")
	DamageLabel:SetText(string.format("Damage: %u", data.damage/10))
	DamageLabel:SetTextColor(color_light_red)
	DamageLabel:SizeToContents()
	
	local FireRateLabel = vgui.Create("DLabel", LeftPanel)
	FireRateLabel:Dock(TOP)
	FireRateLabel:SetFont("Trebuchet24")
	FireRateLabel:SetText(string.format("Fire Rate: %.2f/s", data.firerate))
	FireRateLabel:SetTextColor(color_light_green)
	FireRateLabel:SizeToContents()
	
	local RangePanel = vgui.Create("DLabel", LeftPanel)
	RangePanel:Dock(TOP)
	RangePanel:SetFont("Trebuchet24")
	RangePanel:SetText(string.format("Range: %u Hu", data.range))
	RangePanel:SetTextColor(color_light_blue)
	RangePanel:SizeToContents()
	
	local CancelButton = Main:CreateButton("Cancel Placement", LeftPanel, color_red, color_light_red, color_white)
	CancelButton:Dock(BOTTOM)
	function CancelButton:DoClick()
		wep:DoTowerSelector(0)
	end
	
	return LeftPanel
end

function SWEP:CreateRightPanel(Main)
	local wep = self
	local RightDivider = vgui.Create("DVerticalDivider")
	RightDivider:SetDividerHeight(padding)
	RightDivider:SetTopHeight(ScrH()*0.8)
	
	local UpperPanel = vgui.Create("DPanel")
	RightDivider:SetTop(UpperPanel)
	UpperPanel.Paint = PaintBackground
	UpperPanel:DockPadding(padding,padding,padding,padding)
	Main:AddHeader("Build...", UpperPanel)
	
	local ScrollPanel = vgui.Create("DScrollPanel", UpperPanel)
	ScrollPanel:Dock(FILL)
	
	local TowersPanel = vgui.Create("DIconLayout", ScrollPanel)
	TowersPanel:SetSpaceX(padding)
	TowersPanel:SetSpaceY(padding)
	TowersPanel:Dock(FILL)
	function ScrollPanel:Refresh()
		TowersPanel:Clear()
		
		for k,v in pairs(wep.TowerTable) do
			local TowerPanel = vgui.Create("DImageButton", TowersPanel)
			TowerPanel:SetMaterial(v.material)
			TowerPanel:SetSize(ScrW()/16, ScrW()/16)
			TowerPanel:SetColor(color_gray)
			TowerPanel.affordable = false
			TowerPanel.cashText = wep:GetCashText(v.cost)
			TowerPanel:SetTooltip(v.name)
			
			function TowerPanel:PaintOver(w, h)
				local drawColor = color_white
				if ROTGB_GetCash() < v.cost then
					drawColor = color_red
					if self.affordable then
						self.affordable = false
						self:SetColor(color_gray)
					end
				elseif not self.affordable then
					self.affordable = true
					self:SetColor(color_white)
				end
				
				if self:IsHovered() then
					surface.SetDrawColor(drawColor.r, drawColor.g, drawColor.b, 31)
					surface.DrawRect(0, 0, w, h)
				end
				
				draw.SimpleTextOutlined(self.cashText, "RotgB_font", w/2, h, drawColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
			end
			
			function TowerPanel:DoClick()
				wep:DoTowerSelector(k)
			end
		end
	end
	ScrollPanel:Refresh()
	
	local BottomPanel = vgui.Create("DPanel")
	RightDivider:SetBottom(BottomPanel)
	BottomPanel.Paint = PaintBackground
	BottomPanel:DockPadding(padding,padding,padding,padding)
	
	local AutoCheckBox = vgui.Create("DCheckBoxLabel", BottomPanel)
	AutoCheckBox:SetFont("Trebuchet24")
	AutoCheckBox:SetText("Auto Start")
	AutoCheckBox:SizeToContentsY()
	AutoCheckBox:Dock(BOTTOM)
	AutoCheckBox:DockMargin(0,padding,0,0)
	for k,v in pairs(ents.FindByClass("gballoon_spawner")) do
		if v:GetAutoStart() then
			AutoCheckBox:SetChecked(true)
		end
	end
	function AutoCheckBox:OnChange(value)
		net.Start("rotgb_controller")
		net.WriteUInt(ROTGB_AUTOSTART, 8)
		net.WriteBool(value)
		net.SendToServer()
	end
	
	local ButtonDivider = vgui.Create("DHorizontalDivider", BottomPanel)
	ButtonDivider:Dock(FILL)
	ButtonDivider:SetLeftWidth(ScrW()/15-padding/2)
	
	local SpeedPanel = vgui.Create("DPanel")
	ButtonDivider:SetDividerWidth(padding)
	ButtonDivider:SetLeft(SpeedPanel)
	SpeedPanel.Paint = self.DoNothing
	local FastButton = Main:CreateButton("", SpeedPanel, color_aqua, color_light_aqua, color_white)
	FastButton:DockMargin(0,0,0,padding)
	FastButton:Dock(TOP)
	FastButton:SetEnabled(game.GetTimeScale() < 8)
	function FastButton:PaintOver(w,h)
		local y = h/2
		local size = math.min(w/8,h/4)
		Main:DrawTriangle(w/2-size*0.75, y, size, 90)
		Main:DrawTriangle(w/2+size*0.75, y, size, 90)
	end
	function SpeedPanel:PerformLayout()
		FastButton:SetTall((self:GetTall()-padding)/2)
	end
	local SlowButton = Main:CreateButton("", SpeedPanel, color_orange, color_light_orange, color_white)
	SlowButton:Dock(FILL)
	SlowButton:SetEnabled(game.GetTimeScale() > 1)
	function SlowButton:PaintOver(w,h)
		local y = h/2
		local size = math.min(w/8,h/4)
		Main:DrawTriangle(w/2-size*0.75, y, size, -90)
		Main:DrawTriangle(w/2+size*0.75, y, size, -90)
	end
	function FastButton:DoClick()
		net.Start("rotgb_controller")
		net.WriteUInt(ROTGB_SPEED, 8)
		net.WriteBool(true)
		net.SendToServer()
		
		if game.GetTimeScale() * 2 >= 8 then
			self:SetEnabled(false)
		end
		SlowButton:SetEnabled(true)
	end
	function SlowButton:DoClick()
		net.Start("rotgb_controller")
		net.WriteUInt(ROTGB_SPEED, 8)
		net.WriteBool(false)
		net.SendToServer()
		
		if game.GetTimeScale() / 2 <= 1 then
			self:SetEnabled(false)
		end
		FastButton:SetEnabled(true)
	end
	
	local PlayButton = Main:CreateButton("", BottomPanel, color_green, color_light_green, color_white)
	ButtonDivider:SetRight(PlayButton)
	--PlayButton:NoClipping(true)
	function PlayButton:PaintOver(w,h)
		Main:DrawTriangle(w/2, h/2, math.min(w/4,h/4), 90)
	end
	function PlayButton:DoClick()
		net.Start("rotgb_controller")
		net.WriteUInt(ROTGB_PLAY, 8)
		net.SendToServer()
	end
	
	return RightDivider
end