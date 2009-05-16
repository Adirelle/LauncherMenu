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

local function GetGameTooltip(self)
	tooltip = GameTooltip
	tooltip:SetOwner(self.anchor, "ANCHOR_NONE")
	return tooltip
end

local function Button_OnEnter(self)
	local dataobj = self.dataobj
	if dataobj then
		if dataobj.tooltip then
			tooltip = dataobj.tooltip
		elseif type(dataobj.OnEnter) == "function" then
			dataobj.OnEnter(self.anchor)
		elseif type(dataobj.OnTooltipShow) == "function" then
			dataobj.OnTooltipShow(GetGameTooltip(self))
		elseif dataobj.tooltiptext then
			GetGameTooltip(self):SetText(dataobj.tooltiptext)
		else
			GetGameTooltip(self)
			tooltip:AddLine(self.title, 1, 1, 1)
			if self.notes then
				tooltip:AddLine(self.notes)
			end
		end
	else
		GetGameTooltip(self)
		tooltip:AddLine(self.title, 1, 1, 1)
		if self.notes then
			tooltip:AddLine(self.notes)
		end
	end
	if tooltip then		
		tooltip:SetPoint(GetAnchor(self.anchor))
		tooltip:Show()
	end
end

local function Button_OnLeave(self)
	if self.dataobj and type(self.dataobj.OnLeave) == "function" then
		self.dataobj.OnEnter(self.anchor)
	elseif tooltip then
		if tooltip ~= GameTooltip or tooltip:IsOwned(self.anchor) then
			tooltip:Hide()
		end
		tooltip = nil
	end
end

local function Button_OnClick(self, button)
	if self.dataobj then
		self.dataobj.OnClick(self.anchor, button)
	elseif self.panel then
		InterfaceOptionsFrame_OpenToCategory(self.panel)
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
	local frame = CreateFrame("Frame", nil, UIParent)
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
			if delay > 1 then
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
	button.dataobj = option.dataobj
	button.panel = option.panel
	
	local title = option.title
	if option.icon then
		title = "\124T"..option.icon..":"..ICON_SIZE.."\124t "..title
	end
	button.text:SetText(title)
	
	button:Show()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function MenuCompare(a, b)
	return tostring(a.title) < tostring(b.title)
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

local function BuildMenu(menu)
	local seen = {}
	local names = {}
	local options = {}

	-- Fill the menu with LDB launchers
	for name, obj in LDB:DataObjectIterator() do
		if obj ~= dataobj and obj.type == 'launcher' and type(obj.OnClick) == "function" then
			local prefix = (obj.label or obj.text or name):match("^(.*)Launcher$")
			local title, notes = SearchAddonInfo(obj.tocname, prefix, name)
			title = obj.label or title or obj.text or prefix or name
			local key = obj.tocname or title
			if not names[title] and not seen[key] then
				tinsert(options, {
					title = title,
					notes = notes,
					icon = obj.icon,
					dataobj = obj,
				})
				names[title] = true
				seen[key] = true
			end
		end
	end
	
	-- Fill the menu with interface panel
	for i, panel in ipairs(INTERFACEOPTIONS_ADDONCATEGORIES) do
		if panel.name and not panel.parent then
			local title, notes = SearchAddonInfo(panel.tocname, panel.name)
			title = title or panel.name
			local key = panel.tocname or title
			if not names[title] and not seen[key] then
				tinsert(options, { 
					title = title,
					notes = notes, 
					panel = panel,
				})
				names[title] = true
				seen[key] = true
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

LDB.RegisterCallback(dataobj, 'LibDataBroker_DataObjectCreated', function(name, obj)
	if obj.type == "launcher" then
		dirty = true 
	end
end)
hooksecurefunc('InterfaceOptions_AddCategory', function(frame)
	if frame and frame.parent == nil then
		dirty = true 
	end
end)

function dataobj.OnClick(frame)
	if dirty or not menu then
		if not menu then
			menu = CreateMenu()
		end
		BuildMenu(menu)
		dirty = false
	end
	menu:ClearAllPoints()
	menu.anchorFrame = frame
	menu:SetPoint(GetAnchor(frame))
	menu:Show()
end

