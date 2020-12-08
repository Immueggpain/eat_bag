-- smaller means item put before others
local function itemPriority (a)
	-- mage gems
	if a.itemID == 8008 then return 2001 end
	if a.itemID == 8007 then return 2002 end
	if a.itemID == 5513 then return 2003 end
	if a.itemID == 5514 then return 2004 end
	-- mage foods
	if a.itemID == 8079 or a.itemID == 8076 then return 2000 end
	--hearthstone
	if a.itemID == 6948 then return 0 end
	
	--可装备
	local equippableBase = 100
	if a.itemEquipLoc == 'INVTYPE_HEAD' then
		return equippableBase+1
	elseif a.itemEquipLoc == 'INVTYPE_NECK' then
		return equippableBase+2
	elseif a.itemEquipLoc == 'INVTYPE_SHOULDER' then
		return equippableBase+3
	elseif a.itemEquipLoc == 'INVTYPE_BODY' then
		return equippableBase+4
	elseif a.itemEquipLoc == 'INVTYPE_CHEST' then
		return equippableBase+5
	elseif a.itemEquipLoc == 'INVTYPE_WAIST' then
		return equippableBase+6
	elseif a.itemEquipLoc == 'INVTYPE_LEGS' then
		return equippableBase+7
	elseif a.itemEquipLoc == 'INVTYPE_FEET' then
		return equippableBase+8
	elseif a.itemEquipLoc == 'INVTYPE_WRIST' then
		return equippableBase+9
	elseif a.itemEquipLoc == 'INVTYPE_HAND' then
		return equippableBase+10
	elseif a.itemEquipLoc == 'INVTYPE_FINGER' then
		return equippableBase+11
	elseif a.itemEquipLoc == 'INVTYPE_TRINKET' then
		return equippableBase+12
	elseif a.itemEquipLoc == 'INVTYPE_WEAPON' then
		return equippableBase+13
	elseif a.itemEquipLoc == 'INVTYPE_SHIELD' then
		return equippableBase+14
	elseif a.itemEquipLoc == 'INVTYPE_RANGED' then
		return equippableBase+15
	elseif a.itemEquipLoc == 'INVTYPE_CLOAK' then
		return equippableBase+16
	elseif a.itemEquipLoc == 'INVTYPE_2HWEAPON' then
		return equippableBase+17
	elseif a.itemEquipLoc == 'INVTYPE_BAG' then
		return equippableBase+18
	elseif a.itemEquipLoc == 'INVTYPE_TABARD' then
		return equippableBase+19
	elseif a.itemEquipLoc == 'INVTYPE_ROBE' then
		return equippableBase+20
	elseif a.itemEquipLoc == 'INVTYPE_WEAPONMAINHAND' then
		return equippableBase+21
	elseif a.itemEquipLoc == 'INVTYPE_WEAPONOFFHAND' then
		return equippableBase+22
	elseif a.itemEquipLoc == 'INVTYPE_HOLDABLE' then
		return equippableBase+23
	elseif a.itemEquipLoc == 'INVTYPE_AMMO' then
		return equippableBase+24
	elseif a.itemEquipLoc == 'INVTYPE_THROWN' then
		return equippableBase+25
	elseif a.itemEquipLoc == 'INVTYPE_RANGEDRIGHT' then
		return equippableBase+26
	elseif a.itemEquipLoc == 'INVTYPE_QUIVER' then
		return equippableBase+27
	elseif a.itemEquipLoc == 'INVTYPE_RELIC' then
		return equippableBase+28
	end
	
	--杂项
	if a.itemClassID == 15 then return 200 end
	--容器
	if a.itemClassID == 1 then return 300 end
	--武器
	if a.itemClassID == 2 then return 99999 end
	--护甲
	if a.itemClassID == 4 then return 99999 end
	--配方
	if a.itemClassID == 9 then return 500 end
	--施法材料
	if a.itemClassID == 5 then return 600 end
	--商品（商业技能）
	if a.itemClassID == 7 then return 700 end
	--消耗品
	if a.itemClassID == 0 then return 800 end
	--钥匙
	if a.itemClassID == 13 then return 900 end
	--任务
	if a.itemClassID == 12 then return 1000 end
	
	
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
	--print('======begin sort=====')
	
	local bank_containers = {-1, 5, 6, 7, 8, 9, 10}
	local character_containers = {0, 1, 2, 3, 4}
	local containers
	if bank then containers = bank_containers else containers = character_containers end
	
	-- exclude special bags
	for i = #containers, 2, -1 do
		local container = containers[i]
		local bagItemID = GetInventoryItemID("player", ContainerIDToInventoryID(container))
		if bagItemID ~= nil then
			local bagName = GetItemInfo(bagItemID)
			local bagType = GetItemFamily(bagItemID)
			--print(string.format("%s %d", bagName, bagType))
			if bagType~=0 then table.remove(containers, i) end
		end
	end
	
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
				perItem.itemEquipLoc = itemEquipLoc
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
			itemStack.itemEquipLoc = perItem.itemEquipLoc
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
			for j = 1, #allSlots, 1 do
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
	
	--print('======end sort=====')
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
	
	--sort(allItems, compareItemStack)
	
	for _, a in pairs(allItems) do
		print(string.format("%s n:%d class:%s id:%d", a.itemName, a.quantity, a.itemClassID, a.itemID))
	end
		
	print('======end list=====')
end

local sortBagsCO

local function sortBagsStart()
	sortBagsCO = coroutine.create(function () sortBagsEasy(false) print('整理完成!') end)
end

local function sortBanksStart()
	sortBagsCO = coroutine.create(function () sortBagsEasy(true) print('整理完成!') end)
end

local function sortBothStart()
	sortBagsCO = coroutine.create(function () sortBagsEasy(false) sortBagsEasy(true) print('整理完成!') end)
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