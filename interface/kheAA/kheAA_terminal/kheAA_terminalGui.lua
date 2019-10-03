require "/scripts/util.lua"
local itemList = "scrollArea.itemList";
local deltatime=0;

function init()
	promise=nil
	self={}
	items = {};
	deltatime=30;
	pos = world.entityPosition(pane.containerEntityId());
	widget.addListItem("scrollArea.itemList")
	filterText = "";
	--widget.focus("filterBox")
	maxItemsAddedPerUpdate = config.getParameter("maxItemsAddedPerUpdate", 5000)
	maxSortsPerUpdate = config.getParameter("maxSortsPerUpdate", 50000)
	refresh()
end


function update(dt)
	deltatime=deltatime+dt;
	
	if refreshingList and coroutine.status(refreshingList) ~= "dead" then
		local a, b = coroutine.resume(refreshingList)
		--sb.logInfo(tostring(a).." : "..tostring(b))
	end
	
	if promise~=nil and promise:finished() then
		if promise:succeeded() then
			local res=promise:result();
			self=res
			promise=nil;
			if deltatime > 30 then
				refresh();
				deltatime=0;
			end
		end
		promise=nil
	else
		if promise==nil then
			promise=world.sendEntityMessage(pane.containerEntityId(),"transferUtil.sendConfig")
		end
		if not promise:finished() then
		end
	end
end



function refresh()
	if not self then
		init()
	end

	local blankList=false
	if self.inContainers==nil then
		blankList=true
	elseif util.tableSize(self.inContainers) == 0 then
		blankList=true
	end
	items={};
	if not blankList then
		for entId,pos in pairs(self.inContainers) do
			containerFound(entId,pos)
		end
	end
	refreshingList = coroutine.create(refreshList)
end

function clearInputs()
	widget.setText("filterBox", "");
	widget.setText("requestAmount", "");
	refreshingList = coroutine.create(refreshList);
end

function containerFound(containerID,pos)
	if containerID == nil then return false end
	--if not world.regionActive(rectPos) then return false end
	if not world.entityExists(containerID) then return false end
	
	local containerItems = world.containerItems(containerID)
	if not containerItems then return false end
	
	for index,item in pairs(containerItems) do
		local conf = root.itemConfig(item, item.level or nil, item.seed or nil)
		table.insert(items, {{containerID, index}, item, conf,pos})
	end
	refreshingList = coroutine.create(refreshList)
	return true
end

function getIcon(item, conf, listItem)
	local icon = item.parameters.inventoryIcon or conf.config.inventoryIcon or conf.config[(conf.config.category or "").."Icon"] or conf.config.icon
	if icon then
		if type(icon) == "string" then
			icon = absolutePath(conf.directory, icon)
			widget.setImage(itemList .. "." .. listItem .. ".itemIcon", icon)
			--local imageSize = rect.size(root.nonEmptyRegion(icon))
			--local scaleDown = math.max(math.ceil(imageSize[1] / iconSize[1]), math.ceil(imageSize[2] / iconSize[2]))
			--widget.setImageScale(string.format("%s.%s.icon", self.list, item), 1 / scaleDown)
		elseif type(icon) == "table" then
			--sb.logInfo("%s",icon)
			for i,v in pairs(icon) do
				local item = widget.addListItem(itemList .. "." .. listItem .. ".compositeIcon")
				widget.setImage(itemList .. "." .. listItem .. ".compositeIcon." .. item ..".icon", absolutePath(conf.directory, v.image))
			end
		end
	end
end

function refreshList()
	listItems = {};
	widget.clearListItems(itemList);
	j = 1
	quicksort(items, 1, #items)
	for i = 1, #items do
		local item = items[i][2]
		local conf = items[i][3]
		local filterOk = true;
		local name = item.parameters.shortdescription or conf.config.shortdescription

		if filterText ~= "" then
			if comparableName(name):find(filterText:gsub('([%(%)%%%.%+%-%*%[%]%?%^%$])', '%%%1'):upper()) == nil then
				filterOk = false;
			end
		end
		if filterOk then
			local listItem = widget.addListItem(itemList)
			widget.setText(itemList .. "." .. listItem .. ".itemName", name);
			widget.setText(itemList .. "." .. listItem .. ".amount", "x" .. item.count);
			pcall(getIcon, item, conf, listItem);
			listItems[listItem] = items[i];
		end
		
		if i % maxItemsAddedPerUpdate == 0 then
			coroutine.yield()
		end
	end
end

function filterBox()
	filterText = widget.getText("filterBox");
	refreshingList = coroutine.create(refreshList);
end

function comparableName(name)
	return name and name:gsub('%^#?%w+;', '')
		:gsub('[₀°]', '0')
		:gsub('[₁¹]', '1')
		:gsub('[₂²]', '2')
		:gsub('[₃³]', '3')
		:gsub('[₄⁴]', '4')
		:gsub('[₅⁵]', '5')
		:gsub('[₆⁶]', '6')
		:gsub('[₇⁷]', '7')
		:gsub('[₈⁸]', '8')
		:gsub('[₉⁹]', '9')
		:upper()
end

function request()
	--pane.playerEntityId()
	local selected = widget.getListSelected(itemList)
	if selected ~= nil and listItems ~= nil and listItems[selected] ~= nil then
		for i = 1, #items do
			if items[i] == listItems[selected] then
				local itemToSend=items[i]
				table.insert(itemToSend,world.entityPosition(pane.playerEntityId()))

				world.sendEntityMessage(pane.containerEntityId(), "transferItem",itemToSend)
				table.remove(items, i);
				refreshingList = coroutine.create(refreshList);
				return;
			end
		end
	end
end

function updateListItem(selectedItem, count)
	if count > 0 then
		widget.setText(itemList .. "." .. selectedItem .. ".amount", "x" .. count);
		deltatime=0
	else
		deltatime=29.9
		refreshingList = coroutine.create(refreshList);
	end
end

function requestAllButOne()
	--pane.playerEntityId()
	local selected = widget.getListSelected(itemList)
	if selected ~= nil and listItems ~= nil and listItems[selected] ~= nil then
		for i = 1, #items do
			if items[i] == listItems[selected] then
				local itemToSend=items[i]
				itemToSend[2].count=itemToSend[2].count-1
				table.insert(itemToSend,world.entityPosition(pane.playerEntityId()))
				--sb.logInfo(sb.printJson({playerPos=temp}))

				world.sendEntityMessage(pane.containerEntityId(), "transferItem",itemToSend)
				--table.remove(items, i);
				items[i][2].count=1
				updateListItem(selected, 1)
				return;
			end
		end
	end
end

--[[

function addInputSlot()
	local text = widget.getText("inputSlotCount")
	if text ~= "" and tonumber(text) >= 0 then
		local slot = tonumber(text);
		for _,v in pairs(inputSlots) do
			if v[1] == slot then
				return;
			end
		end
		local item = widget.addListItem(inputList);
		widget.setText(inputList .. "." .. item .. ".slotNr", slot .. "");
		table.insert(inputSlots, {slot, item})
		syncInputSlots();
	end
end


]]

function requestOne()
	local text = widget.getText("requestAmount")
	if text == "" then
		text = "1"
	end
	if tonumber(text) >= 0 then
		--pane.playerEntityId()
		--itemData={containerID, index}, itemDescriptor, itemConfig,pos
		local selected = widget.getListSelected(itemList)
		if selected ~= nil and listItems ~= nil and listItems[selected] ~= nil then
			for i = 1, #items do
				if items[i] == listItems[selected] then
					local itemToSend=copy(items[i])
					--sb.logInfo("%s",itemToSend)
					itemToSend[2].count=math.min(tonumber(text),itemToSend[2].count)
					items[i][2].count = items[i][2].count - itemToSend[2].count

					table.insert(itemToSend,world.entityPosition(pane.playerEntityId()))
					--sb.logInfo(sb.printJson({playerPos=temp}))
					world.sendEntityMessage(pane.containerEntityId(), "transferItem",itemToSend)
					updateListItem(selected, items[i][2].count)
					return;
				end
			end
		end
	end
end

function absolutePath(directory, path)
	if type(path) ~= "string" then
		return false;
	end
	if string.sub(path, 1, 1) == "/" then
		return path
	else
		return directory..path
	end
end

--Sorting code (copyed from https://github.com/mirven/lua_snippets/blob/master/lua/quicksort.lua and modifed slightly)
function partition(array, left, right, pivotIndex)
	local pivotValue = array[pivotIndex]
	array[pivotIndex], array[right] = array[right], array[pivotIndex]
	
	local storeIndex = left
	
	for i =  left, right-1 do
    	if sortByName(items[i], pivotValue) then
	        array[i], array[storeIndex] = array[storeIndex], array[i]
	        storeIndex = storeIndex + 1
		end
		array[storeIndex], array[right] = array[right], array[storeIndex]
		
		if j % maxSortsPerUpdate == 0 then
			coroutine.yield()
		end
		j = j + 1
	end
	
   return storeIndex
end

function quicksort(array, left, right)
	if right > left then
	    local pivotNewIndex = partition(array, left, right, left)
	    quicksort(array, left, pivotNewIndex - 1)
	    quicksort(array, pivotNewIndex + 1, right)
	end
end

function sortByName(itemA, itemB)
	local sort = comparableName(itemA[3].config.shortdescription) < comparableName(itemB[3].config.shortdescription);
	if itemA[3].config.shortdescription == itemB[3].config.shortdescription then
		sort = itemA[2].count < itemB[2].count;
	end
	return sort;
end