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


local function sortCompare (a, b)
	
	
	return a.itemClassID < b.itemClassID or (a.itemClassID == b.itemClassID and a.itemSubClassID < b.itemSubClassID) or (a.itemClassID == b.itemClassID and a.itemSubClassID == b.itemSubClassID and a.itemID < b.itemID)
end

local num_to_bits={0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4}
local function countSetBitsRec(num) 
	local nibble = 0
	if 0 == num then
		return num_to_bits[0] 
	end

	nibble = num & 0xf
	return num_to_bits[nibble] + countSetBitsRec(num >> 4)
end

local function fixOneSlot(dstExpectItemID, dstExpectCount, dstSlotIndx, slotIndxMap)
	local dstBagID = slotIndxMap[dstSlotIndx].bagID
	local dstSlot = slotIndxMap[dstSlotIndx].slot
	
	local maxLoop = 10
	local curLoop = 1
	while curLoop <= maxLoop do
		-- first wait for unlock
		while true do
			local _, _, dstLocked, _, _, _, _, _, _, _ = GetContainerItemInfo(dstBagID, dstSlot)
			if dstLocked then 
				coroutine.yield()
			else
				break
			end
		end
		
		local _, dstItemCount, _, _, _, _, _, _, _, dstItemID = GetContainerItemInfo(dstBagID, dstSlot)
		
		if dstItemID==dstExpectItemID and dstItemCount==dstExpectCount then break end
		
		--print(dstBagID, dstSlot, ':', '#'..curLoop, GetItemInfo(dstExpectItemID), ',', dstExpectCount, ':', dstItemID and GetItemInfo(dstItemID), ',', dstItemCount)
		
		for srcSlotIndx = dstSlotIndx + 1, #slotIndxMap do
			local srcBagID = slotIndxMap[srcSlotIndx].bagID
			local srcSlot = slotIndxMap[srcSlotIndx].slot
			local srcItemID = GetContainerItemID(srcBagID, srcSlot)
			if srcItemID == dstExpectItemID then
				--print('move', srcBagID, ',', srcSlot, '->', dstBagID, ',', dstSlot)
				PickupContainerItem(srcBagID, srcSlot)
				PickupContainerItem(dstBagID, dstSlot)
				
				-- everytime we move, we must check lock, cuz at next loop, we always check if dst slot is ok
				while true do
					local _, _, srcLocked, _, _, _, _, _, _, _ = GetContainerItemInfo(srcBagID, srcSlot)
					local _, _, dstLocked, _, _, _, _, _, _, _ = GetContainerItemInfo(dstBagID, dstSlot)
					if srcLocked or dstLocked then 
						coroutine.yield()
					else
						break
					end
				end
				
				break
			end
		end
		curLoop = curLoop + 1
	end
end

local function sortBags()
	-- first we scan bags, get all iteminfo, merge same items to get total. merge needs a map
	-- then we sort items, sorting needs a list
	-- then we expand the list to real slots, produce a expectSlotList with slotIndx
	-- then we build a slotIndxMap, mapping bagID/slot to slotIndx, cuz we need it when iterating through unfixed slots when fixing one slot.
	-- last we fix slot by slot, iterating expectSlotList
	print('aha')
	
	-- first we scan bags, get all iteminfo, merge same items to get total. merge needs a map, mergedItemMap.
	local mergedItemMap={}
	for container = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(container)
		--if no container, slots is 0
		for slot = 1, slots do
			local item_id = GetContainerItemID(container, slot)
			if item_id ~= nil then
				local texture, count, locked, quality, readable, lootable, link, isFiltered = GetContainerItemInfo(container, slot)
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(item_id)
				local bagType = GetItemFamily(item_id)
				local perItem = mergedItemMap[item_id]
				if perItem == nil then
					perItem = {}
					perItem.quantity = 0
					mergedItemMap[item_id] = perItem
				end
				perItem.itemID = item_id
				perItem.itemName = itemName
				perItem.itemClassID = itemClassID
				perItem.itemSubClassID = itemSubClassID
				perItem.itemMaxStack = itemStackCount
				perItem.bagType = bagType
				perItem.quantity = perItem.quantity + count
			end
		end
	end
	
	-- expand to unputItemList
	local unputItemList = {}
	for _, perItem in pairs(mergedItemMap) do
		for j = 1, perItem.quantity, perItem.itemMaxStack do
			local itemStack = {}
			itemStack.itemID = perItem.itemID
			itemStack.itemName = perItem.itemName
			itemStack.itemClassID = perItem.itemClassID
			itemStack.itemSubClassID = perItem.itemSubClassID
			itemStack.bagType = perItem.bagType
			itemStack.count = min(perItem.quantity-j+1, perItem.itemMaxStack)
			tinsert(unputItemList, itemStack)
		end
	end
	
	-- create some bagTypeLists and a expectSlotList, share elements
	local expectSlotList = {}
	local bagTypeLists = {}
	for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(bagID)
		if slots > 0 then
			local bagItemID = GetInventoryItemID("player", ContainerIDToInventoryID(bagID))
			local bagType = GetItemFamily(bagItemID)
			local bagTypeList = bagTypeLists[bagType]
			if bagTypeList == nil then
				bagTypeList = {}
				bagTypeLists[bagType] = bagTypeList
			end
			
			local slots = GetContainerNumSlots(bagID)
			for slot = 1, slots do
				local slotInfo = {}
				slotInfo.bagID = bagID
				slotInfo.slot = slot
				tinsert(expectSlotList, slotInfo)
				tinsert(bagTypeList, slotInfo)
			end
		end
	end
	
	-- foreach bagTypeList, pick out all compatible items from unputItemList, sort, put at most #bagTypeList items in bagTypeList, put rest back to unputItemList
	local bagTypeOrder = {}
	for bagType in pairs(bagTypeLists) do
		tinsert(bagTypeOrder, bagType)
	end
	sort(bagTypeOrder, function(a,b)
		local aBitCount = countSetBitsRec(a.bagType)
		local bBitCount = countSetBitsRec(b.bagType)
		return aBitCount < bBitCount or (aBitCount == bBitCount and a.bagType < b.bagType)
	end)
	for i, bagType in ipairs(bagTypeOrder) do
		print(i, bagType)
		local bagTypeList = bagTypeLists[bagType]
		local unputBagTypeList = {}
		for j, itemStack in ipairs(unputItemList) do
			--???if itemStack.bagType bit& bagType then itemStack.put=true; tinsert end
			tinsert(unputBagTypeList, itemStack)
		end
	end
	
	
	-- if unputItemList still has items, print error
	-- follow same routine
	
	-- then we sort items, sorting needs a list, mergedItemList.
	local mergedItemList = {}
	for _, perItem in pairs(mergedItemMap) do
		tinsert(mergedItemList, perItem)
	end
	sort(mergedItemList, sortCompare)
	
	-- then we expand the list to real slots, produce a expectSlotList with slotIndx
	local expectSlotList = {}
	for i, perItem in ipairs(mergedItemList) do
		for j = 1, perItem.quantity, perItem.itemMaxStack do
			local expectSlotInfo = {}
			expectSlotInfo.itemID = perItem.itemID
			expectSlotInfo.itemName = perItem.itemName
			expectSlotInfo.count = min(perItem.quantity-j+1, perItem.itemMaxStack)
			tinsert(expectSlotList, expectSlotInfo)
		end
	end
	
	-- then we build a slotIndxMap, mapping bagID/slot to slotIndx, cuz we need it when iterating through unfixed slots when fixing one slot.
	local slotIndxMap = {}
	for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(bagID)
		for slot = 1, slots do
			local bagSlot = {}
			bagSlot.bagID = bagID
			bagSlot.slot = slot
			tinsert(slotIndxMap, bagSlot)
		end
	end
	
	-- last we fix slot by slot, iterating expectSlotList
	for slotIndx, expectSlotInfo in ipairs(expectSlotList) do 
		if expectSlotInfo.itemID ~= nil then
			fixOneSlot(expectSlotInfo.itemID, expectSlotInfo.count, slotIndx, slotIndxMap)
		end
	end
	
	--[[
	for slotIndx,v in ipairs(expectSlotList) do
		print(slotIndxMap[slotIndx].bagID, slotIndxMap[slotIndx].slot, v.itemName, v.count)
	end
	print('bang!')
	]]
end

local sortBagsCO

local function sortBagsStart()
	sortBagsCO = coroutine.create(sortBags)
end

local function onUpdate()
	if sortBagsCO ~= nil then
		local canResume, errMsg = coroutine.resume(sortBagsCO)
		if canResume == false then
			sortBagsCO = nil
			print(errMsg)
		end
	end
end

--create a frame for receiving events
CreateFrame("FRAME", "eat_bag_event_frame");
eat_bag_event_frame:RegisterEvent("MERCHANT_SHOW");
--cas_frame:RegisterEvent("BAG_UPDATE");
--cas_frame:RegisterEvent("BAG_UPDATE_DELAYED");
--cas_frame:RegisterEvent("ITEM_PUSH");
--eat_bag_event_frame:SetScript("OnEvent", onEvent);
eat_bag_event_frame:SetScript("OnUpdate", onUpdate);

--create slash command
SlashCmdList['eat_bag_sort'] = sortBagsStart
SLASH_eat_bag_sort1 = '/sort'
SLASH_eat_bag_sort2 = '/sortbag'
SLASH_eat_bag_sort3 = '/sb'