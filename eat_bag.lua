CreateFrame("FRAME", "eat_bag_frame", UIParent, "ContainerFrameTemplate")

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
