LootWhatIWant_panel = ""
LootWhatIWant_GlobalBlackList = { }
local LootWhatIWant_blacklist_placeholder = ""
LWIW_Options_ThresholdlDropDown_Menu_List = {
	{ name = "|cff1eff00Uncommon|r", number= "2" },
	{ name = "|cff0070ddRare|r", number= "3" },
	{ name = "|cffa335eeEpic|r", number= "4" },
};

function LWIW_GUI_OnLoad(panel)
	-- Panel to incorporate into blizz's built in frame
        panel.name = "LootWhatIWant-Настройки";
	LootWhatIWant_panel = panel
   
	
        InterfaceOptions_AddCategory(panel);
	
	LWIW_DeleteOption:SetChecked(LootWhatIWant.deleteItems)
	
end

function LWIW_Options_OnLoad(panel2)
	--local panel2 = "LWIW_DeleteOption"
	panel2.name = "LWIW-Черный список";
	panel2.parent = "LootWhatIWant-Настройки";
	InterfaceOptions_AddCategory(panel2);
	
	
	StaticPopupDialogs["LWIW_DeleteItem"] = {
		text = "Вы действительно хотите удалить %s из черного списка? ",
		button1 = "Да",
		button2 = "Нет",
		OnAccept = function()
		      LWIW_Remove(LootWhatIWant.blacklistcount[(LootWhatIWant.blacklist_GUI_linenumber + FauxScrollFrame_GetOffset(LWIW_BlackList_ScrollBar))], LootWhatIWant.blacklist[LootWhatIWant.blacklistcount[(LootWhatIWant.blacklist_GUI_linenumber + FauxScrollFrame_GetOffset(LWIW_BlackList_ScrollBar))]])
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	};
	StaticPopupDialogs["LWIW_DeleteBagItems"] = {
		text = "Вы действительно хотите удалить все предметы в ваших сумках из Черного списка?",
		button1 = "Да",
		button2 = "Нет",
		OnAccept = function()
		      LWIW_ProcessDeletes()
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	};
	StaticPopupDialogs["LWIW_ChangeGrayValue"] = {
		text = "Измените параметры удаления серого (0 - не удалять, -1 - Всё удалять, \n - Удалить весь хлам дешевле - <[стоимость])",
		button1 = "Ok",
		button2 = "Выход",
		OnShow = function (self, data)
		    self.editBox:SetText(LootWhatIWant.deleteGrays)
		end,
		OnAccept = function (self, data, data2)
		    local ttext = self.editBox:GetText()
		    LWIW_SetDeleteGrays(ttext)
		end,
		hasEditBox = true,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	};
			
	LWIW_BlackList_ScrollBar:Show()
end

function LWIW_ProfileFrame_OnLoad(panel3)
	panel3.name = "LWIW-Профили";
	panel3.parent = "LootWhatIWant-Настройки";
	InterfaceOptions_AddCategory(panel3);
	StaticPopupDialogs["LWIW_CopyBLToGlobal"] = {
		text = "Вы действительно хотите скопировать свой черный список в глобальный, чтобы другие ваши персонажи могли получить к нему доступ?",
		button1 = "Yes",
		button2 = "No",
		OnAccept = function()
		      LWIW_TransferLocalBLtoGlobalBL()
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	};
	StaticPopupDialogs["LWIW_CopyGlobalBLtoLocal"] = {
		text = "Вы действительно хотите скопировать черный список %s в свой?",
		button1 = "Yes",
		button2 = "No",
		OnAccept = function()
		      LWIW_TransferGlobalBLtoLocalBL(UIDropDownMenu_GetSelectedName(LWIW_ProfileDown_Menu))
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	};
	LWIW_ProfilesBlackList_ScrollBar:Show()
end

function LWIW_ProfileDownMenu_OnLoad()
	
	if (LootWhatIWant_GlobalBlackList == nil or (#LootWhatIWant_GlobalBlackList == 0))then
		
		info            = {};
		info.text       = "Профили";
		--info.value      = "OptionVariable";
		--info.func       = FunctionCalledWhenOptionIsClicked 
			 -- can also be done as function() FunctionCalledWhenOptionIsClicked() end;
	       
	       -- Add the above information to the options menu as a button.
		UIDropDownMenu_AddButton(info);
		UIDropDownMenu_SetSelectedName(LWIW_ProfileDown_Menu, "Профили")
	else
		for i = 1, #LootWhatIWant_GlobalBlackList do
			info            = {};
			info.text       = LootWhatIWant_GlobalBlackList[i].playername;
			info.func     = LWIW_ProfileDownMenu_OnClick
			UIDropDownMenu_AddButton(info);
		end
		
	end
end

function LWIW_ThresholdDownMenu_OnLoad()
	for i = 1, getn(LWIW_Options_ThresholdlDropDown_Menu_List), 1 do
		info = { };
		info.text = LWIW_Options_ThresholdlDropDown_Menu_List[i].name;
		info.func = LWIW_Options_ThresholdDropDown_Menu_OnClick;
		UIDropDownMenu_AddButton(info);
	end
	UIDropDownMenu_SetSelectedID(LWIW_ThresholdDown_Menu, (LootWhatIWant.lootRarity - 1))
	UIDropDownMenu_SetSelectedName(LWIW_ThresholdDown_Menu, LWIW_Options_ThresholdlDropDown_Menu_List[(LootWhatIWant.lootRarity - 1)].name)
end

function LWIW_BlackListSB_Update()
	local line; -- 1 through 5 of our window to scroll
	local lineplusoffset; -- an index into our data calculated from the scroll offset
	local totallines
	if (#LootWhatIWant.blacklistcount < 22) then
		totallines = 22
	else
		totallines = #LootWhatIWant.blacklistcount
	end
	FauxScrollFrame_Update(LWIW_BlackList_ScrollBar,totallines,22,16);
	for line=1,22 do
		lineplusoffset = line + FauxScrollFrame_GetOffset(LWIW_BlackList_ScrollBar);
		if lineplusoffset <= #LootWhatIWant.blacklistcount then
			getglobal("LWIW_ButtonEntry_BlackList"..line):SetText(lineplusoffset..". "..LootWhatIWant.blacklist[LootWhatIWant.blacklistcount[lineplusoffset]]);
			getglobal("LWIW_ButtonEntry_BlackList"..line):Show();
		else
			getglobal("LWIW_ButtonEntry_BlackList"..line):Hide();
		end
	end
end

function LWIW_ProfileBlackListSB_Update()
	local line; -- 1 through 5 of our window to scroll
	local lineplusoffset; -- an index into our data calculated from the scroll offset
	local totallines
	
	local LWIW_ProfilesBlacklist_Placeholder = UIDropDownMenu_GetSelectedID(LWIW_ProfileDown_Menu)
	
	if (#LootWhatIWant_GlobalBlackList[LWIW_ProfilesBlacklist_Placeholder].blacklistcount < 22) then
		totallines = 22
	else
		totallines = #LootWhatIWant_GlobalBlackList[LWIW_ProfilesBlacklist_Placeholder].blacklistcount
	end
	FauxScrollFrame_Update(LWIW_ProfilesBlackList_ScrollBar,totallines,22,16);
	for line=1,22 do
		
		lineplusoffset = line + FauxScrollFrame_GetOffset(LWIW_ProfilesBlackList_ScrollBar);
		if lineplusoffset <= #LootWhatIWant_GlobalBlackList[LWIW_ProfilesBlacklist_Placeholder].blacklistcount then
			getglobal("LWIW_ProfilesButtonEntry_BlackList"..line):SetText(lineplusoffset..". "..LootWhatIWant_GlobalBlackList[LWIW_ProfilesBlacklist_Placeholder].blacklist[LootWhatIWant_GlobalBlackList[LWIW_ProfilesBlacklist_Placeholder].blacklistcount[lineplusoffset]]);
			getglobal("LWIW_ProfilesButtonEntry_BlackList"..line):Show();
		else
			getglobal("LWIW_ProfilesButtonEntry_BlackList"..line):Hide();
		end
	end
end

