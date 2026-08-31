---@generic T
---@param arr T[]
---@return T[]
local function shallow_copy(arr)
   ---@type T[]
   local sorted = {}
   for _, value in ipairs(arr) do
      sorted[#sorted + 1] = value
   end
   return sorted
end

---@param invslots ds.widgets.invslot[]
---@param positions ds.vector3[]
---@param comp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean
local function sort_invslots(invslots, positions, comp)
   local sorted_slots = shallow_copy(invslots)
   table.sort(sorted_slots, comp)

   for k, slot in ipairs(sorted_slots) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(positions[k])
   end
end

---@param invslots ds.widgets.invslot[]
---@param positions ds.vector3[]
local function reset_invslots(invslots, positions)
   for k, slot in ipairs(invslots) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(positions[k])
   end
end

---@param invslots ds.widgets.invslot[]
local function get_positions(invslots)
   ---@type ds.vector3[]
   local positions = {}
   for k, slot in ipairs(invslots) do
      positions[k] = slot:GetPosition()
   end
   return positions
end

-- virtual inventory manager
local virtual_inventory = {
   ---@type ds.vector3[]
   positions = {},
   ---@type ds.widgets.inventorybar.inv
   inventorybar = nil,
}

---@param inventorybar ds.widgets.inventorybar.inv
function virtual_inventory:_Rebuild(inventorybar)
   self.inventorybar = inventorybar
   self.positions = get_positions(inventorybar.inv)
end

---@param comp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean
function virtual_inventory:SortInvSlots(comp)
   local inventorybar = self.inventorybar
   sort_invslots(inventorybar.inv, self.positions, comp)
end

function virtual_inventory:Reset()
   local inventorybar = self.inventorybar
   reset_invslots(inventorybar.inv, self.positions)
end

return virtual_inventory
