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
---@param comp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): number
function virtual_inventory.sort_invslots(invslots, positions, comp)
   ---@type { original_index: integer, invslot: ds.widgets.invslot }[]
   local sorted_slots = {}
   for k, value in ipairs(invslots) do
      sorted_slots[#sorted_slots + 1] = { original_index = k, invslot = value }
   end

   table.sort(sorted_slots, function(a, b) return comp(a.invslot, b.invslot) < 0 end)

   ---@type table<number, number>
   local slot_redirect = {}

   for k, slot in ipairs(sorted_slots) do
      ---@diagnostic disable-next-line: missing-parameter
      slot.invslot:SetPosition(positions[k])
      slot_redirect[k] = slot.original_index
   end

   return slot_redirect
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

local register = {}

---@param invslots ds.widgets.invslot[]
---@return virual_inventory_data
function virtual_inventory.from(invslots)
   ---@diagnostic disable-next-line: return-type-mismatch
   if register[invslots] then return register[invslots] end

   ---@class virual_inventory_data
   local wrapper = {
      ---@type ds.vector3[]
      positions = nil,
      ---@type table<number, number>
      slot_redirect = nil,
   }

   function wrapper:Rebuild() self.positions = virtual_inventory.get_positions(invslots) end

   function wrapper:Reset()
      if not self.positions then return end
      virtual_inventory.reset_invslots(invslots, self.positions)
   end

   ---@param comp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): number
   function wrapper:Sort(comp)
      if not self.positions then return end
      self.slot_redirect = virtual_inventory.sort_invslots(invslots, self.positions, comp)
   end

   function wrapper:Kill()
      -- called from container widget
      self.positions = nil
   end

   function wrapper:GetOriginalSlot(index) return self.slot_redirect and self.slot_redirect[index] or index end

   ---@diagnostic disable-next-line: assign-type-mismatch
   register[invslots] = wrapper

   return wrapper
end

return virtual_inventory
