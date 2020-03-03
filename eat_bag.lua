local function sortCompare (a, b)
	return a.itemClassID < b.itemClassID or (a.itemClassID == b.itemClassID and a.itemSubClassID < b.itemSubClassID) or (a.itemClassID == b.itemClassID and a.itemSubClassID == b.itemSubClassID and a.itemID < b.itemID)
end

local num_to_bits={0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4}
local function countSetBitsRec(num) 
	local nibble = 0
	if 0 == num then
		return num_to_bits[0] 
	end

	nibble = bit.band(num, 0xf)
	return num_to_bits[nibble] + countSetBitsRec(bit.rshift(num, 4))
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
	-- 1. scan bags, create mergedItemMap 
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





----------------------NEW CODE-------------------------

-- smaller means item put before others
local function itemPriority (a)
	--hearthstone
	if a.itemID == 6948 then return 0 end
	--杂项
	if a.itemClassID == 15 then return 1 end
	--容器
	if a.itemClassID == 1 then return 2 end
	--武器
	if a.itemClassID == 2 then return 3 end
	--护甲
	if a.itemClassID == 4 then return 4 end
	--配方
	if a.itemClassID == 9 then return 5 end
	--施法材料
	if a.itemClassID == 5 then return 6 end
	--商品（商业技能）
	if a.itemClassID == 7 then return 7 end
	--消耗品
	if a.itemClassID == 0 then return 8 end
	--钥匙
	if a.itemClassID == 13 then return 9 end
	--任务
	if a.itemClassID == 12 then return 10 end
	
	return 100
end

-- return true if a is before b (a<b)
local function compareItemStack (a, b)
	if itemPriority(a) < itemPriority(b) then
		return true
	elseif itemPriority(a) > itemPriority(b) then
		return false
	else
		return a.itemClassID > b.itemClassID or (a.itemClassID == b.itemClassID and a.itemSubClassID < b.itemSubClassID) or (a.itemClassID == b.itemClassID and a.itemSubClassID == b.itemSubClassID and a.itemID < b.itemID)
			or (a.itemClassID == b.itemClassID and a.itemSubClassID == b.itemSubClassID and a.itemID == b.itemID and a.count > b.count)
	end
end

local function sortBagsEasy(bank)
	print('======begin sort=====')
	
	local bank_containers = {-1, 5, 6, 7, 8, 9, 10}
	local character_containers = {0, 1, 2, 3, 4}
	local containers
	if bank then containers = bank_containers else containers = character_containers end
	
	--get all items into a dict
	local allItems = {}
	for _, container in ipairs(containers) do
		local slots = GetContainerNumSlots(container)
		--if no container, slots is 0
		for slot = 1, slots do
			local item_id = GetContainerItemID(container, slot)
			if item_id ~= nil then
				local texture, count, locked, quality, readable, lootable, link, isFiltered = GetContainerItemInfo(container, slot)
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(item_id)
				local bagType = GetItemFamily(item_id)
				local perItem = allItems[item_id]
				if perItem == nil then
					perItem = {}
					perItem.quantity = 0
					allItems[item_id] = perItem
				end
				perItem.itemID = item_id
				perItem.itemName = itemName
				perItem.itemClassID = itemClassID
				perItem.itemSubClassID = itemSubClassID
				perItem.itemMaxStack = itemStackCount
				perItem.itemBagType = bagType
				perItem.quantity = perItem.quantity + count
			end
		end
	end
	
	--[[
	for _, perItem in pairs(allItems) do
		print(string.format("%s(%d,%d) %d", perItem.itemName, perItem.itemClassID, perItem.itemSubClassID, perItem.quantity))
	end
	]]
	
	--allItemStacks is an array, each stack is at max itemMaxStack
	local allItemStacks = {}
	for _, perItem in pairs(allItems) do
		for j = 1, perItem.quantity, perItem.itemMaxStack do
			local itemStack = {}
			itemStack.itemID = perItem.itemID
			itemStack.itemName = perItem.itemName
			itemStack.itemClassID = perItem.itemClassID
			itemStack.itemSubClassID = perItem.itemSubClassID
			itemStack.itemMaxStack = perItem.itemMaxStack
			itemStack.itemBagType = perItem.itemBagType
			itemStack.count = min(perItem.quantity-j+1, perItem.itemMaxStack)
			tinsert(allItemStacks, itemStack)
		end
	end
	
	-- sort
	sort(allItemStacks, compareItemStack)
	
	--[[
	for i, itemStack in ipairs(allItemStacks) do
		print(string.format("%d %d%s(%d,%d) %d", i, itemStack.itemID, itemStack.itemName, itemStack.itemClassID, itemStack.itemSubClassID, itemStack.quantity))
	end
	]]
	
	-- allSlots is the final expected result, with empty slots
	local allSlots = {}
	local index = 1
	for _, container in ipairs(containers) do
		local slots = GetContainerNumSlots(container)
		--if no container, slots is 0
		for slot = 1, slots do
			local perSlot = allItemStacks[index]
			if perSlot == nil then perSlot = {} end
			perSlot.container = container
			perSlot.slot = slot
			perSlot.fixed = false
			tinsert(allSlots, perSlot)
			index = index+1
		end
	end
	
	--[[
	for i, perSlot in ipairs(allSlots) do
		print(string.format("%d %d %d %s %d", i, perSlot.container, perSlot.slot, perSlot.itemName or 'empty', perSlot.count))
	end
	]]
	
	for i, dstSlot in ipairs(allSlots) do
		local _, dstItemCount, _, _, _, _, _, _, _, dstItemID = GetContainerItemInfo(dstSlot.container, dstSlot.slot)
		dstSlot.fixed = true
		if dstItemID == dstSlot.itemID and dstItemCount == dstSlot.count then
			-- is ok
		else
			-- need fix, find src
			for j = #allSlots, 1, -1 do
				local srcSlot = allSlots[j]
				if srcSlot.fixed then
					-- src fixed
				else
					-- src not fixed
					local _, srcItemCount, _, _, _, _, _, _, _, srcItemID = GetContainerItemInfo(srcSlot.container, srcSlot.slot)
					if srcItemID == dstSlot.itemID then
						-- is what we need, move
						PickupContainerItem(srcSlot.container, srcSlot.slot)
						PickupContainerItem(dstSlot.container, dstSlot.slot)
						--print('move', srcSlot.container, ',', srcSlot.slot, '->', dstSlot.container, ',', dstSlot.slot)
						-- everytime we move, we must check lock
						while true do
							local _, _, srcLocked, _, _, _, _, _, _, _ = GetContainerItemInfo(srcSlot.container, srcSlot.slot)
							local _, _, dstLocked, _, _, _, _, _, _, _ = GetContainerItemInfo(dstSlot.container, dstSlot.slot)
							if srcLocked or dstLocked then 
								coroutine.yield()
							else
								break
							end
						end
						-- if dst is ok, break
						_, dstItemCount, _, _, _, _, _, _, _, dstItemID = GetContainerItemInfo(dstSlot.container, dstSlot.slot)
						if dstItemID == dstSlot.itemID and dstItemCount == dstSlot.count then
							break
						end
					end
				end
			end
		end
	end
	
	print('======end sort=====')
end

local function listBag()
	print('======begin list=====')
	
	local character_containers = {0, 1, 2, 3, 4}
	
	--get all items into a dict
	local allItems = {}
	for _, container in ipairs(character_containers) do
		local slots = GetContainerNumSlots(container)
		--if no container, slots is 0
		for slot = 1, slots do
			local item_id = GetContainerItemID(container, slot)
			if item_id ~= nil then
				local texture, count, locked, quality, readable, lootable, link, isFiltered = GetContainerItemInfo(container, slot)
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(item_id)
				local bagType = GetItemFamily(item_id)
				local perItem = allItems[item_id]
				if perItem == nil then
					perItem = {}
					perItem.quantity = 0
					allItems[item_id] = perItem
				end
				perItem.itemID = item_id
				perItem.itemName = itemName
				perItem.itemClassID = itemClassID
				perItem.itemSubClassID = itemSubClassID
				perItem.itemMaxStack = itemStackCount
				perItem.itemBagType = bagType
				perItem.quantity = perItem.quantity + count
			end
		end
	end
	
	for _, perItem in pairs(allItems) do
		print(string.format("%s %d", perItem.itemName, perItem.quantity))
	end
		
	print('======end list=====')
end

local sortBagsCO

local function sortBagsStart()
	sortBagsCO = coroutine.create(function () sortBagsEasy(false) end)
end

local function sortBanksStart()
	sortBagsCO = coroutine.create(function () sortBagsEasy(true) end)
end

local function sortBothStart()
	sortBagsCO = coroutine.create(function () sortBagsEasy(false) sortBagsEasy(true) end)
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

--CreateFrame("FRAME", "eat_bag_frame", UIParent, "ContainerFrameTemplate")
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

SlashCmdList['eat_bag_sortbank'] = sortBanksStart
SLASH_eat_bag_sortbank1 = '/sk'

SlashCmdList['eat_bag_sortboth'] = sortBothStart
SLASH_eat_bag_sortboth1 = '/so'

SlashCmdList['eat_bag_listbag'] = listBag
SLASH_eat_bag_listbag1 = '/ls'