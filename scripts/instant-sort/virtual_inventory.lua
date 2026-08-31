local utils = require("instant-sort/utils")

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

   for k, slot in ipairs(inventorybar.inv) do
      self.positions[k] = slot:GetPosition()
   end
end

---@param inventorybar ds.widgets.inventorybar.inv
function virtual_inventory:SetupInventorybarHooks(inventorybar)
   local s = self
   local Rebuild = inventorybar.Rebuild
   function inventorybar:Rebuild()
      Rebuild(inventorybar)
      s:_Rebuild(inventorybar)
   end
end

---@param cmp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean
function virtual_inventory:SortInvSlots(cmp)
   local inventorybar = self.inventorybar

   local sorted_slots = utils.shallow_copy(inventorybar.inv)
   table.sort(sorted_slots, cmp)

   for k, slot in ipairs(sorted_slots) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(virtual_inventory.positions[k])
   end
end

function virtual_inventory:Reset()
   local inventorybar = self.inventorybar
   for k, slot in ipairs(inventorybar.inv) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(virtual_inventory.positions[k])
   end
end

return virtual_inventory
