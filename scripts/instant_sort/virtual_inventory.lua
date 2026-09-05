local virtual_inventory = {}

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

local register = setmetatable({}, { __mode = "k" })

---@class virual_inventory_data
---@field invslots ds.widgets.invslot[]
---@field positions ds.vector3[]
---@field slot_redirect table<number, number>
local VirtualInventory = {}
VirtualInventory.__index = VirtualInventory

---@param invslots ds.widgets.invslot[]
---@return virual_inventory_data
function VirtualInventory.new(invslots)
   local self = setmetatable({}, VirtualInventory)
   self.invslots = invslots
   self.positions = nil
   self.slot_redirect = nil
   return self
end

function VirtualInventory:Rebuild() self.positions = virtual_inventory.get_positions(self.invslots) end

function VirtualInventory:Reset()
   if not self.positions then return end
   virtual_inventory.reset_invslots(self.invslots, self.positions)
end

---@param comp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): number
function VirtualInventory:Sort(comp)
   if not self.positions then return end
   self.slot_redirect = virtual_inventory.sort_invslots(self.invslots, self.positions, comp)
end

function VirtualInventory:Kill()
   -- called from container widget
   self.positions = nil
end

function VirtualInventory:GetOriginalSlot(index) return self.slot_redirect and self.slot_redirect[index] or index end

function VirtualInventory:GetVisualSlot(index)
   local orig_index = self:GetOriginalSlot(index)
   return self.invslots[orig_index]
end

---@param invslots ds.widgets.invslot[]
---@return virual_inventory_data
function virtual_inventory.from(invslots)
   ---@diagnostic disable-next-line: return-type-mismatch
   if register[invslots] then return register[invslots] end

   local wrapper = VirtualInventory.new(invslots)
   ---@diagnostic disable-next-line: assign-type-mismatch
   register[invslots] = wrapper

   return wrapper
end

return virtual_inventory
