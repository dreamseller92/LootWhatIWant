--[[
LootWhatIWant Addon for World of Warcraft
Original code written by Dardack
Modified by Achbed (achbed@dwbrand.net)
Last modified 2/6/2010
Перевод DreamSeller
]]--

--[[

All user control for the addon is via chat commands.  This addon understands the following commands:

enable
	Enables the addon
	
disable
	Disables the addon
	
gui
	Display the Blacklist Interface
    
add [item]
remove [item]
	add/remove item(s) from the blacklist.  Multiple links can follow the command.  Must be an item 
	link (shift-click the item after typing REMOVE).

world
	Enable/disable auto looting in the main world while in a group.  Enabled by default.

instance
	Enable/disable auto looting in the current instance while in a group.  All instances disabled
	by default.
	
zg
mc
kz
aq20
aq40
	Enable/disable auto looting in ZG/MC/KZ/AQ20/AQ40 respectivily.  Shortcuts for the instance
	command.  Disabled by default.

autoclose
	Toggles auto-closing loot window even when some items are not looted.  If the window closes
	when items have not been looted, the user is alerted via chat about what was left behind.
   
gray [value]
	if [value] is negative, all grays will be deleted/not looted.
	if [value] is 0, all grays will be looted.
	if [value] is positive, all grays below that threshold will be deleted/not looted.
	
delete
	Toogles looting then deleting items in your blacklist and/or gray item settings.  Disabled
	by default.  If disabled, and an item is on the blacklist or meets the gray settings, it will
	be left in the corpse (not looted).

cleanup
	Immediately deletes from inventory all items that are in the blacklist or meet the gray threshold.

]]--

local version = "2.0.6 alpha"
local commandPrefix = "/lwiw"

LootWhatIWant_GlobalBlackList = { }
LootWhatIWant = { }
LootWhatIWant.enabled = true
LootWhatIWant.blacklist = { }
LootWhatIWant.blacklistcount = { }
LootWhatIWant.dungeonLootOK = { }
LootWhatIWant.autolootWorldGroup = true
LootWhatIWant.deleteItems = false
LootWhatIWant.deleteGrays = 0
LootWhatIWant.closeLootWindow = true
LootWhatIWant.lootRarity = 2
LootWhatIWant.mouseover = false
LootWhatIWant.blacklist_GUI_linenumber = 0
LootWhatIWant.Inventorylist_GUI_linenumber = 0
LootWhatIWant.MobList_GUI_mobname = nil

local LootBlacklist = 0
local LootedItem = ""
local deleteAtNextBagUpdate = false
local blacklisted = false
local LootWhatIWant_Frame = CreateFrame("Frame", "LootWhatIWantFrame")
local reportNextMapUpdate = false
local LWIW_CurrentLootSlot = 0
local LWIW_SkippedBOP = false
local LWIW_ProfilesBlacklist_Placeholder
local LWIW_debugFlag = false
local LWIW_Rarity = 0

function LWIW_GetItemNumber(str)
    local itemnum
    
    if not str then
		return str
	end
	
    itemnum = string.match(str, "item:(%d+)")
    if not itemnum then
        local itemName, iitemLink, iitemRarity, iitemLevel, iitemMinLevel, iitemType, iitemSubType, iitemStackCount, iitemEquipLoc, iitemTexture, iitemSellPrice = GetItemInfo(str)
        if iitemLink then
	        itemnum = string.match(iitemLink, "item:(%d+)")
        end
    end
    
    return itemnum
end

-- ------------------------------------------------------------------
-- Prints debug info if flag is set.
-- ------------------------------------------------------------------
function LWIW_Debug(str)
    if(LWIW_debugFlag) then
        print("LWIW_DEBUG: "..str)
    end
end


-- ------------------------------------------------------------------
-- Adds a dungeon name to the "auto-loot" list.
-- ------------------------------------------------------------------
function LWIW_AddLootDungeon(dungeonName)

	if (LootWhatIWant.dungeonLootOK == nil) then
		LootWhatIWant.dungeonLootOK = {}
		LootWhatIWant.dungeonLootOK[1] = dungeonName
		LootWhatIWant.dungeonLootOK[2] = true
	    print("LWIW: автоматическое подтверждение для БОЕ в "..dungeonName.." активировано.")
		return
	end
	
	local index = #LootWhatIWant.dungeonLootOK
	
	for i=1, (index-1) do
		if(dungeonName == LootWhatIWant.dungeonLootOK[i]) then
			if(dungeonName == LootWhatIWant.dungeonLootOK[i]) then
				if(LootWhatIWant.dungeonLootOK[i+1] == false) then
					LootWhatIWant.dungeonLootOK[i+1] = true
				    print("LWIW: автоматическое подтверждение для БОЕ в "..dungeonName.." активировано.")
					return true
				else
					LootWhatIWant.dungeonLootOK[i+1] = true
				    print("LWIW: автоматическое подтверждение для БОЕ в "..dungeonName.." уже активно.  Без изменений.")
					return true
				end
			end
		end
	end
	
	LootWhatIWant.dungeonLootOK[index + 1] = dungeonName
	LootWhatIWant.dungeonLootOK[index + 2] = true
	print("LWIW: автоматическое подтверждение для БОЕ в "..dungeonName.." не активно.")
    return true
end


-- ------------------------------------------------------------------
-- Removes a dungeon name from the "auto-loot" list.
-- ------------------------------------------------------------------
function LWIW_DelLootDungeon(dungeonName)
	if (LootWhatIWant.dungeonLootOK == nil) then
	    print("LWIW: автоматическое подтверждение для БОЕ в "..dungeonName.." не активно.")
		return
	end
	
	local index = #LootWhatIWant.dungeonLootOK
	
	for i=1, (index - 1) do
		local testName = LootWhatIWant.dungeonLootOK[i]
		local testStatus = LootWhatIWant.dungeonLootOK[i+1]
		if (not testName) then
			-- 
		else
			if(testName == dungeonName) then
				if(testStatus) then
					LootWhatIWant.dungeonLootOK[i+1] = false
					print("LWIW: автоматическое подтверждение для БОЕ в "..dungeonName.." не активно.")
					return true
				else
					LootWhatIWant.dungeonLootOK[i+1] = false
					print("LWIW: автоматическое подтверждение для БОЕ в "..dungeonName.." уже активно.  Без изменений.")
					return true
				end
			end
		end
	end
    print("LWIW: автоматическое подтверждение для БОЕ в "..dungeonName.." не активно.")
    return true
end


-- ------------------------------------------------------------------
-- Check to see if a dungeon name is on the "auto-loot" list.
-- ------------------------------------------------------------------
function LWIW_MatchLootDungeon(dungeonName)
	if not LootWhatIWant.dungeonLootOK then
		return false
	end
	
	local index = #LootWhatIWant.dungeonLootOK
	
	if (index < 1) then
		return false
	end
	
	for i=1, index do
		local testName = LootWhatIWant.dungeonLootOK[i]
		local testStatus = LootWhatIWant.dungeonLootOK[i+1]
		if (not testName) then
			--
		else
			if(dungeonName == testName) then
				if(not testStatus) then
					return false
				end
				return true
			end
		end
	end
	
	return false
end

--- ------------------------------------------------------------------
-- Toggle a dungeon status in the "auto-loot" list.
-- ------------------------------------------------------------------
function LWIW_ToggleLootDungeon(dungeonName)
	local inInstance, instanceType = IsInInstance()
	if not inInstance then
		-- We're not in an instance.  Return failure.
		print("LWIW: Вы находитесь вне подземлья.  Настройки не изменены.")
		return false
    end
    
    if(LWIW_MatchLootDungeon(dungeonName) == true) then
        LWIW_DelLootDungeon(dungeonName)
    else
        LWIW_AddLootDungeon(dungeonName)
    end
    return true
end


-- ------------------------------------------------------------------
-- Check to see if we're ok to loot BoPs in a group situation.
-- ------------------------------------------------------------------
function LWIW_LootInstanceInGroup()
	if not ((GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0)) then
        -- We're not in a group.  We're clear to loot.
        return true
    end
	
	LWIW_ReportSettingsForZone(false)

	local inInstance, instanceType = IsInInstance()
	if not inInstance then
		-- We're not in an instance.  Use the global group setting.
		return LootWhatIWant.autolootWorldGroup
    end
    
    -- Check the instance name for the auto-confirm BoP status.
    if (LWIW_MatchLootDungeon(GetRealZoneText()) == true) then
        return true
    end

    -- We're not supposed to auto-confirm BoPs here.
    return false
end

-- ------------------------------------------------------------------
-- Handle all events sent by the game.
-- ------------------------------------------------------------------
function LootWhatIWant_EventHandler(self, event)
  -- If we are disabled, quit here.
	if not (LootWhatIWant.enabled) then 
		return 
	end
	
	if not (LootWhatIWant.deleteGrays) then
		LootWhatIWant.deleteGrays = 0
	end
	
	-- look for the LOOT_OPENED event.
	if (event == "WORLD_MAP_UPDATE") then
		if reportNextMapUpdate then
			reportNextMapUpdate = false
			LWIW_ReportSettingsForZone()
		end
		return
 	elseif (event == "BAG_UPDATE") then
		if (deleteAtNextBagUpdate) then
			LWIW_ProcessDeletes()
		end
		return 
 	elseif (event == "LOOT_BIND_CONFIRM") then
 		if LWIW_CurrentLootSlot > 0 then
	 		LWIW_LootBoP()
	 	end
		return 
	elseif (event == "LOOT_OPENED") then
        -- Process the LOOT_OPENED event.
        LWIW_LootOpened()
        return
	elseif (event == "PLAYER_ENTERING_WORLD") then
		reportNextMapUpdate = true
		if (LootWhatIWant.lootRarity == nil) then
			LootWhatIWant.lootRarity = 2
		end
		LWIW_DeleteOption:SetChecked(LootWhatIWant.deleteItems)
		LWIW_EnableDisableOption:SetChecked(LootWhatIWant.enabled)
		LWIW_CloseLootWindowOption:SetChecked(LootWhatIWant.closeLootWindow)
		UIDropDownMenu_SetSelectedID(LWIW_ThresholdDown_Menu, (LootWhatIWant.lootRarity - 1))
		LWIW_GrayValueFrontString()
		return
	end
end

function LWIW_LootBoP()
	local slotToLoot = LWIW_CurrentLootSlot
	LWIW_CurrentLootSlot = 0
	
    -- Check to see if we've enabled auto-confirming BoPs in this area.
    
    if LWIW_LootInstanceInGroup() then
		LootSlot(slotToLoot)
		StaticPopup_Hide("LOOT_BIND")
		ConfirmLootSlot(slotToLoot)
	else
		LWIW_SkippedBOP = slotToLoot
    end
end

-- ------------------------------------------------------------------
-- Report the user's settings for the current zone.
-- ------------------------------------------------------------------
function LWIW_ReportSettingsForZone(showWorld)
	if not reportNextMapUpdate then
		reportNextMapUpdate = false
		return
	end
	
	reportNextMapUpdate = false
	
	if not ((GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0)) then
		if not showWorld then
			return
		end
	end
	
	local inInstance, instanceType = IsInInstance()
	if not inInstance then
		if showWorld then
			-- We're not in an instance.  Use the global group setting.
			if(LootWhatIWant.autolootWorldGroup) then
				print("LWIW: Автоматическое подтверждение элементов BoЕ включено для мира, находясь в группе.")
			else
				print("LWIW: Автоматическое подтверждение элементов BoЕ отключено для мира, находясь в группе.")
			end
			return
		end
    end
       local zone = GetRealZoneText()
    if (LWIW_MatchLootDungeon(zone) == true) then
		print("LWIW: Автоматическое подтверждение элементов BoЕ включено для "..zone..", находясь в группе.")
    else
		print("LWIW: Автоматическое подтверждение элементов BoЕ отключено для "..zone..", находясь в группе.")
    end
end


-- ------------------------------------------------------------------
-- Handle the LOOT_OPENED event.  This checks for looting options and
-- grabs everything in the loot object (if it's ok).
-- ------------------------------------------------------------------
function LWIW_LootOpened()
    -- Check to see if the built=in autoloot is turned on.  If it is, we can't
    -- do our work, and tell the user this.
    local auloot = GetCVar("autoLootDefault")
    if (auloot == "1") then
        print("LWIW: Auto Loot включен, и LootWhatIWant не может работать. Пожалуйста, отключите Auto Loot в настройках вашего интерфейса.")
        return
    end
    
	-- Make sure we have something to loot
	if (GetNumLootItems() > 0) then
		LWIW_SkippedBOP = 0
		-- Process through the loot object contents
		for i = 1, GetNumLootItems() do
			LWIW_CurrentLootSlot = i
			local x = LWIW_LootThisItem(i)
			if (x == true) then
				deleteAtNextBagUpdate = true
			end
		end
        
		if (LootWhatIWant.closeLootWindow) then
			local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()				
			if (not LWIW_NoBagSpaceLeft()) then
				if (LWIW_SkippedBOP == 0) then
					if ((lootmethod == "master") and (masterlooterPartyID == 0) and (LWIW_Rarity >= GetLootThreshold())) then
						print("LWIW: Masterlooter установлен, и вы - ML. Окно добычи будет открытым")
					elseif (( LWIW_Rarity >= LootWhatIWant.lootRarity))then
						print("LWIW: Товар не ниже вашего порогового значения: "..LWIW_Options_ThresholdlDropDown_Menu_List[(LootWhatIWant.lootRarity-1)].name..", keeping loot window open.")
					else
						CloseLoot()
					end
				end
			else
				print("LWIW: Если сумки полны, то окно добычи остается открытым.")
			end
		end
		
		if (LWIW_SkippedBOP > 0) then
			LootSlot(LWIW_SkippedBOP)
		end
	else
		-- We have nothing to loot.  Close the loot window.
		CloseLoot()
	end
	LWIW_Rarity = 0
end

-- ------------------------------------------------
-- Check to see if any bag space is free
-- ------------------------------------------------
function LWIW_NoBagSpaceLeft()
	local unusedbagspace = 0
	for bag = 0, NUM_BAG_SLOTS do
		local numberOfFreeSlots, BagType = GetContainerNumFreeSlots(bag);
		if ((BagType ~= 1) and (BagType ~= 2) and (BagType ~=4)) then
			-- Don't care about ammo/quiver/soul bags since 99.9% of loot can't go in them anyways
			unusedbagspace = unusedbagspace + numberOfFreeSlots
		end
	end
	if (unusedbagspace == 0) then
		return true
	else
		return false
	end
end

-- ---------------------------------------------------------------------------------
-- Copy toons Blacklist to global list so it can be accessed by other toons
-- ---------------------------------------------------------------------------------
function LWIW_TransferLocalBLtoGlobalBL()
	if (LootWhatIWant.blacklistcount == nil) then
		print("В вашем черном списке нет элементов. Нет необходимости копировать в глобальный.")
		return
	end
	if ((LootWhatIWant_GlobalBlackList == nil) or (#LootWhatIWant_GlobalBlackList == 0)) then
		LootWhatIWant_GlobalBlackList = {}
		local playerName = UnitName("player");
		LootWhatIWant_GlobalBlackList[1] = {}
		LootWhatIWant_GlobalBlackList[1].blacklist = { }
		LootWhatIWant_GlobalBlackList[1].blacklistcount = { }
		LootWhatIWant_GlobalBlackList[1].playername = playerName
		LootWhatIWant_GlobalBlackList[1].blacklist = LootWhatIWant.blacklist
		LootWhatIWant_GlobalBlackList[1].blacklistcount = LootWhatIWant.blacklistcount
		for i = 1, #LootWhatIWant_GlobalBlackList do
			info            = {};
			info.text       = LootWhatIWant_GlobalBlackList[i].playername;
			info.func     = LWIW_ProfileDownMenu_OnClick
			UIDropDownMenu_AddButton(info);
		end
	else
		local found = false
		local placeholder = -1
		local playerName = UnitName("player");
		for i = 1, #LootWhatIWant_GlobalBlackList do
			if LootWhatIWant_GlobalBlackList[i].playername ==  playerName then
				found = true
				placeholder = i
			end
		end
		if found then
			LootWhatIWant_GlobalBlackList[placeholder].blacklist = LootWhatIWant.blacklist
			LootWhatIWant_GlobalBlackList[placeholder].blacklistcount = LootWhatIWant.blacklistcount
		else
			
			placeholder = #LootWhatIWant_GlobalBlackList+1
			LootWhatIWant_GlobalBlackList[placeholder] = {}
			LootWhatIWant_GlobalBlackList[placeholder].blacklist = { }
			LootWhatIWant_GlobalBlackList[placeholder].blacklistcount = { }
			LootWhatIWant_GlobalBlackList[placeholder].playername = playerName
			LootWhatIWant_GlobalBlackList[placeholder].blacklist = LootWhatIWant.blacklist
			LootWhatIWant_GlobalBlackList[placeholder].blacklistcount = LootWhatIWant.blacklistcount
			for i = 1, #LootWhatIWant_GlobalBlackList do
				info            = {};
				info.text       = LootWhatIWant_GlobalBlackList[i].playername;
				info.func     = LWIW_ProfileDownMenu_OnClick
				UIDropDownMenu_AddButton(info);
			end
		end
	end
	LWIW_ProfileDownMenu_OnLoad()
end

function LWIW_ProfileDownMenu_OnClick()
	local gid = this:GetID()
	UIDropDownMenu_SetSelectedName(LWIW_ProfileDown_Menu, LootWhatIWant_GlobalBlackList[gid].playername)
	LWIW_ProfileBlackListSB_Update()
end

function LWIW_Options_ThresholdDropDown_Menu_OnClick()
	local gid = this:GetID()
	LootWhatIWant.lootRarity = gid + 1
	UIDropDownMenu_SetSelectedID(LWIW_ThresholdDown_Menu, (LootWhatIWant.lootRarity - 1))
end

function LWIW_TransferGlobalBLtoLocalBL(otherToonName)
	local found
	local placeholder
	for i = 1, #LootWhatIWant_GlobalBlackList do
		if LootWhatIWant_GlobalBlackList[i].playername ==  otherToonName then
			found = true
			placeholder = i
		end
	end
	if (found) then
		LootWhatIWant.blacklist = LootWhatIWant_GlobalBlackList[placeholder].blacklist
		LootWhatIWant.blacklistcount = LootWhatIWant_GlobalBlackList[placeholder].blacklistcount
	end
end
-- -----------
-------------------------------------------------------
-- Loot one item, and return if it matches the delete settings.
-- ------------------------------------------------------------------
function LWIW_LootThisItem(slotNumber)
    local returnValue = false
    
    local lootIcon, lootName, lootQuantity, rarity, locked = GetLootSlotInfo(slotNumber)
    if (rarity >  LWIW_Rarity) then
	LWIW_Rarity = rarity
    end
    local lootLink = GetLootSlotLink(slotNumber)
    if (locked == 1) then
        -- This is a locked item.  We can't do anything, so bail.
        return false
    end
    
    if not (lootQuantity ~= 0) then
        -- This is a coin listing.  Grab it and bail.
        LootSlot(slotNumber)
        return false
    end
    
    if (rarity == 0) then
        -- We have a gray item.  Check for deleting this.
        if not (LootWhatIWant.deleteGrays == 0) then
            returnValue = true
        end
    end
    
    local itemNum = LWIW_GetItemNumber(lootLink)
    
    if itemNum then
		if(LootWhatIWant.blacklist[itemNum]) then
			-- The item is blacklisted.
			returnValue = true
		end
    end

    if ((returnValue == true) and (LootWhatIWant.deleteItems == false)) then
        -- If we're not going to loot the item because we dont want it and we
        -- won't be deleting it, then we dont want to have the calling function
        -- execute the deletion afterwards.  Then inform the user of the skip.
        returnValue = false
        print("LWIW: пропущен "..lootLink)
    else
        -- We want this item. Take it.
		LootSlot(slotNumber)
		
		-- Hide any BoP warnings.  We'll get another shortly is we're staying open.
		StaticPopup_Hide("LOOT_BIND")
    end
    
    return returnValue
end


-- ------------------------------------------------------------------
-- Delete one item from your bags, and display what was done.
-- ------------------------------------------------------------------
function LWIW_DeleteItem(bag, slot)
    if (LootWhatIWant.deleteItems == false) then
        -- We were called, but deleting items is set to OFF. Bail.
        return
    end
    
    local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            
    PickupContainerItem(bag, slot)
    DeleteCursorItem()
    print("LWIW: Удалено: "..link)
end


-- ------------------------------------------------------------------
-- Check your bags for items that match the deletion settings, and clear them out.
-- ------------------------------------------------------------------
function LWIW_ProcessDeletes()
	deleteAtNextBagUpdate = false
	
    if (LootWhatIWant.deleteItems == false) then
        -- We were called, but deleting items is set to OFF. Bail.
        return
    end
    
    for bag = 0, NUM_BAG_SLOTS do
        for slot=1, GetContainerNumSlots(bag) do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if (link ~= nil) then
                local currentItem = string.match(link, "item:(%d+)")
                if (currentItem ~= nil) then
                    local itemName, iitemLink, iitemRarity, iitemLevel, iitemMinLevel, iitemType, iitemSubType, iitemStackCount, iitemEquipLoc, iitemTexture, iitemSellPrice = GetItemInfo(currentItem)

                    -- Is the item in the blacklist?
                    if (LootWhatIWant.blacklist[currentItem]) then
                        LWIW_DeleteItem(bag,slot)
                    else
			if (iitemRarity == 0) then
				-- We have a gray item.  Now what?
				
				-- Are we to delete *ALL* gray items?
				if (LootWhatIWant.deleteGrays == -1) then
					LWIW_DeleteItem(bag,slot)
				end

				-- Get the current stack value for the item
				local currentStackValue = (iitemSellPrice * iitemStackCount)

				-- Is the value of the gray stack below the value threshold?
				if (currentStackValue < LootWhatIWant.deleteGrays) then
					LWIW_DeleteItem(bag,slot)
				end
			end
                    end
                end
            end
        end
    end
end


-- ------------------------------------------------------------------
-- Add an item to the blacklist.
-- ------------------------------------------------------------------
function LWIW_Add(itemnum, name)
	if (LootWhatIWant.blacklist[itemnum] ~= nil) then
		print("LWIW: "..name.." уже в вашем черном списке.")
	else
		print("LWIW: "..name.." добавлен в ваш черный список.")
		LootWhatIWant.blacklist[itemnum] = name
		if (LootWhatIWant.blacklistcount == nil) then
			LootWhatIWant.blacklistcount = {}
			LootWhatIWant.blacklistcount[1] = itemnum
		else
			LootWhatIWant.blacklistcount[(#LootWhatIWant.blacklistcount + 1)] = itemnum
		end
		LWIW_BlackListSB_Update()
	end
end

-------------------------------------------------------------------------------------
-- Changes the gray value of the text field in the gui
-------------------------------------------------------------------------------------
function LWIW_GrayValueFrontString()
	if ((LootWhatIWant.deleteGrays == -1) or (LootWhatIWant.deleteGrays == 0)) then
		LWIW_DeleteGrays4:SetText(LootWhatIWant.deleteGrays)
	else
		LWIW_DeleteGrays4:SetText(GetCoinTextureString(LootWhatIWant.deleteGrays))
	end
end
-- ------------------------------------------------------------------
-- Remove an item from the blacklist.
-- ------------------------------------------------------------------
function LWIW_Remove(itemnum, name)
	if (LootWhatIWant.blacklist[itemnum] ==  nil) then
		print("LWIW: "..name.." нет в вашем черном списке.")
	else
		print("LWIW: "..name.." был удален из вашего черного списка.")
		LootWhatIWant.blacklist[itemnum] = nil
		for i = 1, #LootWhatIWant.blacklistcount do
			if (LootWhatIWant.blacklistcount[i] == itemnum) then
				table.remove(LootWhatIWant.blacklistcount, i)
				break
			end
		end
		LWIW_BlackListSB_Update()
	end
end


-- ------------------------------------------------------------------
-- Toggle ALL gray item deletion.
-- ------------------------------------------------------------------
function LWIW_ToggleGrayDeletes()
    if (LootWhatIWant.deleteGrays == 0) then
        LootWhatIWant.deleteGrays = -1
	print("LWIW: хлам будет удален при следующем поднятии")
    elseif (LootWhatIWant.deleteGrays == -1) then
        LootWhatIWant.deleteGrays = 0
        print("LWIW: хлам не будет удален при следующем поднятии")
    end
    LWIW_GrayValueFrontString()
end


-- ------------------------------------------------------------------
-- Display help for the deletegray setting.
-- ------------------------------------------------------------------
function LWIW_SetDeleteGraysPrintUsage()
    print("Хлам с ценой = 0, хлам будет поднят и сохранен")
    print("Хлам с ценой = -1, весь хлам будет удален при следующем поднятии")
    print("Другая цена, удалить хлам дешевле указанной цены")
end


-- ------------------------------------------------------------------
-- Set deletegray options
-- ------------------------------------------------------------------
function LWIW_SetDeleteGrays(itemValue)
    if (itemValue == "") then
        LWIW_SetDeleteGraysPrintUsage()
        return
    end

    local newValue = tonumber(itemValue)
    
    if (newValue == nil) then
        LWIW_SetDeleteGraysPrintUsage()
        return
    end

    if (newValue < 0) then
        LootWhatIWant.deleteGrays = -1
        print("LWIW: хлам будет удален при следующем поднятии")
	LWIW_GrayValueFrontString()
        return
    end
    
    if (newValue == 0) then
        LootWhatIWant.deleteGrays = 0
        print("LWIW: хлам не будет удален при следующем поднятии")
	LWIW_GrayValueFrontString()
        return
    end
    
    LootWhatIWant.deleteGrays = newValue
    LWIW_GrayValueFrontString()
    print("LWIW: удалить хлам если стак стоит дешевле "..GetCoinTextureString(LootWhatIWant.deleteGrays))
end


-- ------------------------------------------------------------------
-- String function trim() - clears whitespace at front and end of a string
-- ------------------------------------------------------------------
function trim (s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end


-- ------------------------------------------------------------------
-- Adds multiple items to the blacklist
-- ------------------------------------------------------------------
function LWIW_AddToBlacklist(itemList)
    local atLeastOneValidItem = false
    
    local itemTable = LWIW_SplitStringIntoItems(itemList)
    
    for i,n in ipairs(itemTable) do
        itemnum = LWIW_GetItemNumber(n)
        if not (itemnum == nil) then
            LWIW_Add(itemnum, n)
            atLeastOneValidItem = true
        end
    end
    
    if(atLeastOneValidItem == false) then
        print("LWIW: Такого предмета нет")
    end
end


-- ------------------------------------------------------------------
-- Removes multiple items from the blacklist
-- ------------------------------------------------------------------
function LWIW_RemoveFromBlacklist(itemList)
    local atLeastOneValidItem = false
    
    local itemTable = LWIW_SplitStringIntoItems(itemList)
    
    for i,n in ipairs(itemTable) do
        itemnum = LWIW_GetItemNumber(n)
        if not (itemnum == nil) then
            LWIW_Remove(itemnum, n)
            atLeastOneValidItem = true
        end
    end
    
    if(atLeastOneValidItem == false) then
        print("LWIW: Такого предмета нет")
    end
end


-- ------------------------------------------------------------------
-- Splits a string into a table of values based on "[]" delimiters.
-- ------------------------------------------------------------------
function LWIW_SplitStringIntoItems(inString)
    LWIW_Debug(inString)
    
    local itemTable = {}
    local itemStart = 1
    local itemEnd = 1
    repeat
        itemStart = string.find(inString, '%|c', itemEnd)
        if not itemStart then
            return itemTable
        end
        
        itemEnd = string.find(inString, '%|r', itemStart+1)
        if not itemEnd then
            return itemTable
        end
        
        local f = string.sub(inString, itemStart, itemEnd+1)
        table.insert(itemTable, f)
    until itemStart > string.len(inString)
    
    return itemTable
end


-- ------------------------------------------------------------------
-- Toggle item deletion on or off
-- ------------------------------------------------------------------
function LWIW_ToggleDeletes(cmd)
    if (trim(cmd) == "") then
        LootWhatIWant.deleteItems = not (LootWhatIWant.deleteItems)
    else
        LootWhatIWant.deleteItems = parse_truefalse(cmd)
    end
    
    if (LootWhatIWant.deleteItems) then
        print("LWIW: Собирает и удаляет указанные предметы из трупа.")
    else
        print("LWIW: НЕ будет собирать предметы, оставив их в трупе.")
    end
    LWIW_DeleteOption:SetChecked(LootWhatIWant.deleteItems)
end

---------------------------------------
-- Toggle Enable/Disable
--------------------------------------
function LWIW_ToggleEnable(cmd)
	if (trim(cmd) == "") then
		LootWhatIWant.enabled = not (LootWhatIWant.enabled)
	elseif (trim(cmd) == "disable") then
		LootWhatIWant.enabled = false
	elseif (trim(cmd) == "enable") then
		LootWhatIWant.enabled = true
	end
	 if (LootWhatIWant.enabled) then
		print("LWIW: Аддон включен")
	else
		print("LWIW: Аддон отключен")
        end
	LWIW_EnableDisableOption:SetChecked(LootWhatIWant.enabled)
end
        
-- ------------------------------------------------------------------
-- Toggle auto-window closure on or off
-- ------------------------------------------------------------------
function LWIW_ToggleCloseWindow(cmd)
    if (trim(cmd) == "") then
        LootWhatIWant.closeLootWindow = not (LootWhatIWant.closeLootWindow)
    else
        LootWhatIWant.closeLootWindow = parse_truefalse(cmd)
    end
    
    if (LootWhatIWant.closeLootWindow) then
        print("LWIW: Автоматически закроет окно добычи, даже если некоторые предметы не были забраны.")
    else
        print("LWIW: Оставит окно добычи открытым, если некоторые предметы остались в трупе.")
    end
    LWIW_CloseLootWindowOption:SetChecked(LootWhatIWant.closeLootWindow)
end


-- ------------------------------------------------------------------
-- Toggle auto-loot for world groups on or off
-- ------------------------------------------------------------------
function LWIW_ToggleWorldGroupLoot(cmd)
    if (trim(cmd) == "") then
        LootWhatIWant.autolootWorldGroup = not (LootWhatIWant.autolootWorldGroup)
    else
        LootWhatIWant.autolootWorldGroup = parse_truefalse(cmd)
    end
    
    if (LootWhatIWant.autolootWorldGroup) then
        print("LWIW: Автосбор добычи включен в основном мире, находясь в составе группы.")
    else
        print("LWIW: Автосбор добычи отключено в основном мире, находясь в составе группы.")
    end
end


-- ------------------------------------------------------------------
-- Parse a string for a true/false and return the boolean equivalent
-- ------------------------------------------------------------------
function parse_truefalse(str)
	local s = string.lower(trim(str))
	
    if (s == "true") or (s == "on") or (s == "yes") then
        return true
    end
    
    local x = tonumber(s)
    if not x then
        return false
    end
    
    if (x == 0) then
        return false
    end
    
    return true
end


-- ------------------------------------------------------------------
-- Print command usage in chat
-- ------------------------------------------------------------------
function LWIW_PrintUsage()
    print("Использование LootWhatIWant")
    print("Инструкция:  "..commandPrefix.." [command] [options]")
    print("Команды:")
    print("    help -- справка")
    print("    enable -- включить")
    print("    disable -- отключить")
    print("    gui -- отобразить черный список")
    print("    add [item] -- добавить элемент в черный список. Должна быть ссылка на элемент (после ввода ДОБАВИТЬ щелкните элемент, удерживая нажатой клавишу «Shift»).")
    print("    remove [item] -- удалить элемент из черного списка. Должна быть ссылка на элемент (после ввода ДОБАВИТЬ щелкните элемент, удерживая нажатой клавишу «Shift»)")
    print("    world -- Включение / отключение автоматического сбора добычи в основном мире, находясь в составе группы. Включено по умолчанию.")
    print("    instance -- Включение / отключение автоматического сбора добычи в текущем подземлье, находясь в составе группы. По умолчанию отключено.")
    print("    [zg | mc | kz | aq20 | aq40] -- Включение / отключение автоматического мародерства в ZG / MC / KZ / AQ20 / AQ40 соответственно. По умолчанию отключено. ")
    print("    delete -- переключает сбор добычи, а затем удаление предметов из вашего черного списка. По умолчанию отключено. Испытал столько, сколько смог. Используйте это на СВОЙ страх и риск. ")
    print("    autoclose -- Переключает автоматически закрывающееся окно добычи, даже если некоторые предметы не были разграблены. ")
    LWIW_SetDeleteGraysPrintUsage()
end


-- ------------------------------------------------------------------
-- Process chat commands
-- ------------------------------------------------------------------
function LWIW_ProcessChatCommand(cmd, rmd, line)
    cmd = string.lower(cmd)

    if (cmd == "gray") then
        LWIW_SetDeleteGrays(rmd)
		return
	end

    if (cmd == "add") then
        LWIW_AddToBlacklist(rmd)
        return
    end
    
    if (cmd == "remove") then
        LWIW_RemoveFromBlacklist(rmd)
        return
    end
    
    if ((cmd == "disable") or (cmd == "enable"))then
       LWIW_ToggleEnable(cmd)
        return
    end
    
   -- if (cmd == "enable") then
     --   LWIW_ToggleEnable(cmd)
       -- return
    --end
    
    if (cmd == "delete") then
        LWIW_ToggleDeletes(rmd)
        return
    end

    if (cmd == "cleanup") then
        LWIW_ProcessDeletes()
        return
    end

    if (cmd == "autoclose") then
        LWIW_ToggleCloseWindow(rmd)
        return
    end

    if (cmd == "gui") then
        InterfaceOptionsFrame_OpenToCategory(LootWhatIWant_panel)
        return
    end
    
    if (cmd == "instance") then
		if (trim(rmd) == "") then
	        LWIW_ToggleLootDungeon(GetRealZoneText())
	    else
			if (parse_truefalse(rmd)) then
				LWIW_AddLootDungeon(GetRealZoneText())
			else
				LWIW_DelLootDungeon(GetRealZoneText())
			end
		end
        return
    end
    
    if (cmd == "world") then
        LWIW_ToggleWorldGroupLoot(rmd)
        return
    end
    
    -- Emulate old commands with new functions
    
    if (cmd == "deletesomegrays") then
        LWIW_SetDeleteGrays(rmd)
		return
	end

    if (cmd == "deleteallgrays") then
        LWIW_ToggleGrayDeletes()
		return
	end

    if (cmd == "zg") then
        LWIW_ToggleLootDungeon("Zul'Gurub")
        return
    end
    
    if (cmd == "kz") then
        LWIW_ToggleLootDungeon("Karazhan")
        return
    end
    
    if (cmd == "mc") then
        LWIW_ToggleLootDungeon("Molten Core")
        return
    end
    
    if (cmd == "aq20") then
        LWIW_ToggleLootDungeon("Ruins of Ahn'Qiraj")
        return
    end
    
    if (cmd == "aq40") then
        LWIW_ToggleLootDungeon("Temple of Ahn'Qiraj")
        return
    end
    
    LWIW_PrintUsage()
end

-- ------------------------------------------------------------------
-- Setup slash command processing
-- ------------------------------------------------------------------
SLASH_LOOTWHATIWANT1 = commandPrefix
SlashCmdList["LOOTWHATIWANT"] = function(msg)
	if( msg ) then
		local cmd, rmd = msg:match("^(%S*)%s*(.-)$")
        LWIW_ProcessChatCommand(trim(cmd), trim(rmd), trim(msg))
	end
end

LootWhatIWant_Frame:RegisterEvent("WORLD_MAP_UPDATE")
LootWhatIWant_Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
LootWhatIWant_Frame:RegisterEvent("BAG_UPDATE")
LootWhatIWant_Frame:RegisterEvent("LOOT_OPENED")
LootWhatIWant_Frame:RegisterEvent("LOOT_BIND_CONFIRM")

LootWhatIWant_Frame:SetScript("OnEvent", LootWhatIWant_EventHandler)
