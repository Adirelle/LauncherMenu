--[[
LauncherMenu - LDB launcher and addon panel menu

Copyright (C) 2009 Adirelle

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
--]]

local addonName = ...

local LDB = LibStub('LibDataBroker-1.1')
local dataobj = LDB:NewDataObject('LauncherMenu', {
	type = 'data source',
	text = 'Launchers',
	icon = [[Interface\Icons\Ability_Hunter_Quickshot]],
})

--------------------------------------------------------------------------------
-- Button handling
--------------------------------------------------------------------------------

local tooltip

local function GetAnchor(frame)
	local x,y = frame:GetCenter()
	if not x or not y then return "TOPLEFT", frame, "BOTTOMLEFT" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf, 0, 0
end

local function GetGameTooltip(anchor)
	tooltip = GameTooltip
	tooltip:SetOwner(anchor, "ANCHOR_NONE")
	return tooltip
end

local function Button_OnEnter(self)
	self.OnEnter(self.arg, self.anchor, self)
	if tooltip then
		tooltip:SetPoint(GetAnchor(self.anchor))
		tooltip:Show()
	end
end

local function Button_OnLeave(self)
	self.OnLeave(self.arg, self.anchor, self)
	if tooltip then
		if tooltip ~= GameTooltip or tooltip:IsOwned(self.anchor) then
			tooltip:Hide()
		end
		tooltip = nil
	end
end

local function Button_OnClick(self, button)
	if self.OnClick(self.arg, self.anchor, button) then
		self.anchor:Hide()
	end
end

--------------------------------------------------------------------------------
-- Menu handling
--------------------------------------------------------------------------------

local OPTION_HEIGHT = 16
local ICON_SIZE = OPTION_HEIGHT
local MENU_PADDING = 10
local MENU_VSPACING = 6
local MENU_HSPACING = 2
local MAX_BUTTONS_PER_COLUMN = 16

local function LayoutMenu(menu)
	if not menu.dirtyLayout then
		return
	end
	menu.dirtyLayout = nil
	local numButtons, buttons = menu.numButtons, menu.buttons
	local columnHeight = MAX_BUTTONS_PER_COLUMN
	if numButtons > MAX_BUTTONS_PER_COLUMN then
		columnHeight = math.ceil(numButtons / math.ceil(numButtons / MAX_BUTTONS_PER_COLUMN))
	end
	local width = 0
	local x, y = MENU_PADDING, MENU_PADDING
	for i = 1, numButtons do
		local button = buttons[i]
		button:SetPoint("TOPLEFT", menu, "TOPLEFT", x, -y)
		width = math.max(width, button.text:GetStringWidth())
		if i % columnHeight == 0 or i == numButtons then
			for j = 0, (i-1) % columnHeight do
				buttons[i-j]:SetWidth(width)
			end
			x = x + width + MENU_VSPACING
			y = MENU_PADDING
			width = 0
		else
			y = y + OPTION_HEIGHT + MENU_HSPACING
		end
	end
	menu:SetWidth(MENU_PADDING + x)
	menu:SetHeight(MENU_PADDING * 2 + (OPTION_HEIGHT + MENU_HSPACING) * math.min(columnHeight, numButtons) - MENU_HSPACING)
end

local function CreateMenu()
	local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	frame:Hide()
	frame:SetScript('OnShow', LayoutMenu)
	frame:SetScript('OnHide', function(self) self.anchorFrame = nil end)
	frame:EnableMouse(true)

	frame:SetBackdrop({
	  bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	  edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	  tile = true, tileSize = 16, edgeSize = 16,
	  insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	frame:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
	frame:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);
	frame:SetFrameStrata("TOOLTIP")
	frame:SetClampedToScreen(true)

	local timer = CreateFrame("Frame", nil, frame)
	local delay = 0
	timer:SetScript('OnUpdate', function(self, elapsed)
		if MouseIsOver(frame) or (frame.anchorFrame and MouseIsOver(frame.anchorFrame)) then
			delay = 0
		else
			delay = delay + elapsed
			if delay > 0.5 then
				frame:Hide()
			end
		end
	end)

	frame.buttons = {}
	frame.numButtons = 0
	frame.dirtyLayout = true
	return frame
end

local function WipeMenu(menu)
	for i,button in ipairs(menu.buttons) do
		button:Hide()
	end
	menu.numButtons = 0
	menu:Hide()
end

local function CreateButton(menu)
	local button = CreateFrame("Button", nil, menu)
	button.anchor = menu

	button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
	button:SetHeight(OPTION_HEIGHT)

	button:SetScript('OnEnter', Button_OnEnter)
	button:SetScript('OnLeave', Button_OnLeave)

	button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
	button:SetScript('OnClick', Button_OnClick)

	local text = button:CreateFontString()
	text:SetAllPoints(button)
	text:SetFontObject(GameTooltipText)
	button.text = text

	return button
end

local function AddOption(menu, option)
	local index = menu.numButtons + 1
	local button = menu.buttons[index]
	if not button then
		button = CreateButton(menu)
		menu.buttons[index] = button
	end
	menu.numButtons = index
	menu.dirtyLayout = true

	button.title = option.title
	button.notes = option.notes
	button.OnClick = option.OnClick
	button.OnEnter = option.OnEnter
	button.OnLeave = option.OnLeave
	button.arg = option.arg

	local title = option.title
	if option.icon then
		title = "\124T"..option.icon..":"..ICON_SIZE.."\124t "..title
	end
	button.text:SetText(title)

	button:Show()
end

--------------------------------------------------------------------------------
-- Entry handlers
--------------------------------------------------------------------------------

local function Default_OnEnter(_, anchor, item)
	local tooltip = GetGameTooltip(anchor)
	tooltip:AddLine(item.title, 1, 1, 1)
	if item.notes then
		tooltip:AddLine(item.notes)
	end
end

local function Default_OnLeave()
end

local function Launcher_OnEnter(dataobj, anchor, item)
	if dataobj.tooltip then
		tooltip = dataobj.tooltip
	elseif type(dataobj.OnEnter) == "function" then
		dataobj.OnEnter(anchor)
	elseif type(dataobj.OnTooltipShow) == "function" then
		dataobj.OnTooltipShow(GetGameTooltip(anchor))
	elseif dataobj.tooltiptext then
		GetGameTooltip(anchor):SetText(dataobj.tooltiptext)
	else
		Default_OnEnter(dataobj, anchor, item)
	end
end

local function Launcher_OnLeave(dataobj, anchor, item)
	if type(dataobj.OnLeave) == "function" then
		dataobj.OnLeave(anchor)
	end
end

local function Launcher_OnClick(dataobj, anchor, button)
	dataobj.OnClick(anchor, button)
end

local function BlizPanel_OnClick(panel)
	InterfaceOptionsFrame_OpenToCategory(panel)
	return true
end

local Waterfall
local function Waterfall_OnClick(id)
	if Waterfall:IsOpen(id) then
		Waterfall:Close(id)
	else
		Waterfall:Open(id)
		return true
	end
end

--------------------------------------------------------------------------------
-- Menu Building
--------------------------------------------------------------------------------

local function MenuCompare(a, b)
	return tostring(a.title):lower() < tostring(b.title):lower()
end

local function SearchAddonInfo(...)
	for i = 1, select('#', ...) do
		local tocname = select(i, ...)
		if tocname then
			local name, title, notes, _, _, reason = GetAddOnInfo(tocname)
			if name and reason ~= 'MISSING' then
				return title, notes
			end
		end
	end
end

local seen = {}
local function IsUnique(...)
	local n = select('#', ...)
	for i = 1,n do
		local k = select(i, ...)
		if k and seen[k] then
			return false
		end
	end
	for i = 1,n do
		local k = select(i, ...)
		if k then
			seen[k] = true
		end
	end
	return true
end

local function BuildMenu(menu)
	wipe(seen)
	local options = {}

	-- Fetch LDB launchers
	for name, obj in LDB:DataObjectIterator() do
		if obj ~= dataobj and obj.type == 'launcher' and type(obj.OnClick) == "function" then
			local prefix = (obj.label or obj.text or name):match("^(.*)Launcher$")
			local title, notes = SearchAddonInfo(obj.tocname, prefix, name)
			title = obj.label or title or obj.text or prefix or name
			if IsUnique(title, name, obj.tocname) then
				tinsert(options, {
					title = title,
					notes = notes,
					icon = obj.icon,
					arg = obj,
					OnClick = Launcher_OnClick,
					OnEnter = Launcher_OnEnter,
					OnLeave = Launcher_OnLeave,
				})
			end
		end
	end

	-- Fetch interface addon panels
	for i, panel in ipairs(INTERFACEOPTIONS_ADDONCATEGORIES) do
		if panel.name and not panel.parent then
			local title, notes = SearchAddonInfo(panel.tocname, panel.name)
			title = title or panel.name
			if IsUnique(title, panel.name, panel.tocname) then
				tinsert(options, {
					title = title,
					notes = notes,
					arg = panel,
					OnClick = BlizPanel_OnClick,
					OnEnter = Default_OnEnter,
					OnLeave = Default_OnLeave,
				})
			end
		end
	end

	-- Fetch waterfall registered settings
	if not Waterfall then
		Waterfall = AceLibrary and AceLibrary:HasInstance("Waterfall-1.0") and AceLibrary:GetInstance("Waterfall-1.0")
	end
	if Waterfall and type(Waterfall.registry) == "table" then
		for id, settings in pairs(Waterfall.registry) do
			local title, notes = SearchAddonInfo(id, settings.title)
			title = title or settings.title
			if IsUnique(id, title) then
				tinsert(options, {
					title = title,
					notes = notes,
					arg = id,
					OnClick = Waterfall_OnClick,
					OnEnter = Default_OnEnter,
					OnLeave = Default_OnLeave,
				})
			end
		end
	end

	-- Sort the options
	table.sort(options, MenuCompare)

	-- Add them all to the menu
	WipeMenu(menu)
	for i, option in ipairs(options) do
		AddOption(menu, option)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local menu
local dirty = true

local function UpdateAndShowMenu()
	if dirty then
		BuildMenu(menu)
		dirty = false
	end
	menu:Show()
end

local function SetDirty()
	dirty = true
	if menu and menu:IsShown() then
		UpdateAndShowMenu(menu)
	end
end

local function RegisterLauncher(name, obj)
	if obj.type == "launcher" then
		LDB.RegisterCallback(dataobj, 'LibDataBroker_AttributeChanged_'..name, SetDirty)
		SetDirty()
	end
end

LDB.RegisterCallback(dataobj, 'LibDataBroker_DataObjectCreated', RegisterLauncher)
for name, obj in LDB:DataObjectIterator() do
	RegisterLauncher(name, obj)
end

hooksecurefunc('InterfaceOptions_AddCategory', function(frame)
	if frame and frame.parent == nil then
		SetDirty()
	end
end)

function dataobj.OnClick(frame)
	if not menu then
		menu = CreateMenu()
	end
	menu.anchorFrame = frame
	menu:ClearAllPoints()
	menu:SetPoint(GetAnchor(frame))
	UpdateAndShowMenu()
end

--------------------------------------------------------------------------------
-- LibDBIcon support
--------------------------------------------------------------------------------

local DBI = LibStub("LibDBIcon-1.0", true)
if DBI then
	local f = CreateFrame("Frame", nil, UIParent)
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", function(_, event, name)
		if event ~= "ADDON_LOADED" or name ~= addonName then
			return
		end
		f:UnregisterEvent("ADDON_LOADED")

		if not _G.LauncherMenuDBIcon then
			_G.LauncherMenuDBIcon = {}
		end
		DBI:Register('LauncherMenu', dataobj, _G.LauncherMenuDBIcon)
	end)
end
