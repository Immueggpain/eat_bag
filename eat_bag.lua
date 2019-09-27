CreateFrame("FRAME", "eat_bag_frame", UIParent, "ContainerFrameTemplate")

--[[
ToggleAllBags = function ()
	if ( not UIParent:IsShown() ) then
		return;
	end

	if ( not CanOpenPanels() ) then
		if ( UnitIsDead("player") ) then
			NotWhileDeadError();
		end
		return;
	end
	
	local size = 0
	for id= BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		size = size + GetContainerNumSlots(id)
	end

	local containerShowing;
	local containerFrame;
	if ( not containerShowing ) then
		eat_bag_frame：Show()
	end
end
]]

local function moveAnItem(srcItemID, srcBagID, srcSlot, bagItems, slotIndxMap)
	print('move an', srcBagID, srcSlot)
	local perItem = bagItems[srcItemID]
	local dstBagID = perItem.bagID
	local dstSlot = perItem.slot
	local dstSlotIndx = perItem.slotIndx
	print('dst base', dstBagID, dstSlot)
	
	-- loop is over when src stack is empty, or src stack is dst stack
	while true do
		if dstBagID == srcBagID and dstSlot == srcSlot then
			-- do nothing, cuz src & dest is same slot, break
			break
		else
			local destItemID = GetContainerItemID(dstBagID, dstSlot)
			if srcItemID ~= destItemID then
				-- swap, cuz src dest are different items, break
				print('swap', srcBagID, ',', srcSlot, '->', dstBagID, ',', dstSlot)
				PickupContainerItem(srcBagID, srcSlot)
				PickupContainerItem(dstBagID, dstSlot)
				break
			else
				-- same itemID
				local _, srcCount = GetContainerItemInfo(srcBagID, srcSlot)
				local _, dstCount = GetContainerItemInfo(dstBagID, dstSlot)
				if dstCount == perItem.itemMaxStack then
					-- do nothing, cuz dest stack is full, continue
				else
					-- fill dest stack, but there may be leftover, may need continue
					print('fill', srcBagID, ',', srcSlot, '->', dstBagID, ',', dstSlot)
					PickupContainerItem(srcBagID, srcSlot)
					PickupContainerItem(dstBagID, dstSlot)
					if srcCount+dstCount > perItem.itemMaxStack then
						-- do nothing, continue
					else
						-- no leftover, break
						break
					end
				end
			end
		end
		dstSlotIndx = dstSlotIndx+1
		dstBagID = slotIndxMap[dstSlotIndx].bagID
		dstSlot = slotIndxMap[dstSlotIndx].slot
	end
end

local function fixOneSlot(dstExpectItemID, dstExpectCount, dstSlotIndx, slotIndxMap)
	local dstBagID = slotIndxMap[dstSlotIndx].bagID
	local dstSlot = slotIndxMap[dstSlotIndx].slot
	
	while _, dstItemCount, _, _, _, _, _, _, _, dstItemID = GetContainerItemInfo(dstBagID, dstSlot); dstItemID~=dstExpectItemID or dstItemCount~=dstExpectCount do
	end
end

local function sortBags()
	print('aha')
	
	-- scan bags
	local bagItems={}
	for container = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(container)
		--if no container, slots is 0
		for slot = 1, slots do
			local item_id = GetContainerItemID(container, slot)
			if item_id ~= nil then
				local texture, count, locked, quality, readable, lootable, link, isFiltered = GetContainerItemInfo(container, slot)
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(item_id)
				local perItem = bagItems[item_id]
				if perItem == nil then
					perItem = {}
					perItem.quantity = 0
					bagItems[item_id] = perItem
				end
				perItem.itemID = item_id
				perItem.itemName = itemName
				perItem.itemClassID = itemClassID
				perItem.itemSubClassID = itemSubClassID
				perItem.itemMaxStack = itemStackCount
				perItem.quantity = perItem.quantity + count
			end
		end
	end
	
	local sortTable = {}
	for _,perItem in pairs(bagItems) do
		tinsert(sortTable, perItem)
	end
	sort(sortTable, function(a, b)
		return a.itemClassID < b.itemClassID or (a.itemClassID == b.itemClassID and a.itemSubClassID < b.itemSubClassID) or (a.itemClassID == b.itemClassID and a.itemSubClassID == b.itemSubClassID and a.itemID < b.itemID)
	end)
	
	-- map bagID,slot to continuous slot index
	local slotIndxMap = {}
	for container = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(container)
		for slot = 1, slots do
			local tuple = {}
			tuple.bagID = container
			tuple.slot = slot
			tinsert(slotIndxMap, tuple)
		end
	end
	
	-- now we have order of itemIDs, map it to actual slots
	local slotIndx = 1
	for i,perItem in ipairs(sortTable) do
		perItem.slotIndx = slotIndx
		perItem.stacks = ceil(perItem.quantity/perItem.itemMaxStack)
		perItem.leftover = math.fmod(perItem.quantity,perItem.itemMaxStack)
		perItem.bagID = slotIndxMap[slotIndx].bagID
		perItem.slot = slotIndxMap[slotIndx].slot
		slotIndx = slotIndx + perItem.stacks
	end
	
	-- moving items
	for container = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(container)
		--if no container, slots is 0
		for slot = 1, slots do
			local item_id = GetContainerItemID(container, slot)
			if item_id ~= nil then
				moveAnItem(item_id, container, slot, bagItems, slotIndxMap)
			end
		end
	end
	
	for _,v in ipairs(sortTable) do
		print(v.bagID, v.slot, v.itemName, v.stacks)
	end
	print('bang!')
end

--create a frame for receiving events
CreateFrame("FRAME", "eat_bag_event_frame");
eat_bag_event_frame:RegisterEvent("MERCHANT_SHOW");
--cas_frame:RegisterEvent("BAG_UPDATE");
--cas_frame:RegisterEvent("BAG_UPDATE_DELAYED");
--cas_frame:RegisterEvent("ITEM_PUSH");
eat_bag_event_frame:SetScript("OnEvent", onEvent);

--create slash command
SlashCmdList['eat_bag_sort'] = sortBags
SLASH_eat_bag_sort1 = '/sort'
SLASH_eat_bag_sort2 = '/sortbag'
SLASH_eat_bag_sort3 = '/sb'