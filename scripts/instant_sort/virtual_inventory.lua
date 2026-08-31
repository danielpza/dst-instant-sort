local virtual_inventory = {}

---@generic T
---@param arr T[]
---@return T[]
local function shallow_copy(arr)
   local sorted = {}
   for _, value in ipairs(arr) do
      sorted[#sorted + 1] = value
   end
   return sorted
end

---@param invslots ds.widgets.invslot[]
---@param positions ds.vector3[]
---@param comp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean
function virtual_inventory.sort_invslots(invslots, positions, comp)
   local sorted_slots = shallow_copy(invslots)
   table.sort(sorted_slots, comp)

   for k, slot in ipairs(sorted_slots) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(positions[k])
   end
end

---@param invslots ds.widgets.invslot[]
---@param positions ds.vector3[]
function virtual_inventory.reset_invslots(invslots, positions)
   for k, slot in ipairs(invslots) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(positions[k])
   end
end

---@param invslots ds.widgets.invslot[]
function virtual_inventory.get_positions(invslots)
   ---@type ds.vector3[]
   local positions = {}
   for k, slot in ipairs(invslots) do
      positions[k] = slot:GetPosition()
   end
   return positions
end

local KEY = "___INSTANT_SORT_DATA"
---@param invslots ds.widgets.invslot[]
---@return virual_inventory_data
function virtual_inventory.from(invslots)
   ---@diagnostic disable-next-line: return-type-mismatch
   if invslots[KEY] then return invslots[KEY] end

   ---@class virual_inventory_data
   local wrapper = {
      ---@type ds.vector3[]
      positions = nil,
   }

   function wrapper:Rebuild() self.positions = virtual_inventory.get_positions(invslots) end
   function wrapper:Reset()
      if not self.positions then return end
      virtual_inventory.reset_invslots(invslots, self.positions)
   end
   ---@param comp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean
   function wrapper:Sort(comp)
      if not self.positions then return end
      virtual_inventory.sort_invslots(invslots, self.positions, comp)
   end
   function wrapper:Kill()
      -- called from container widget
      self.positions = nil
   end

   ---@diagnostic disable-next-line: assign-type-mismatch
   invslots[KEY] = wrapper

   return wrapper
end

return virtual_inventory
