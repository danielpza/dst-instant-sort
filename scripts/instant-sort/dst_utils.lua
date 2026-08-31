local dst_utils = {}

---@param item ds.entityscript
---@return boolean
function dst_utils.is_equippable(item) return item and item.replica and item.replica.equippable and true or false end

---@param item ds.entityscript
---@param slot ds.equipslot
---@return boolean
function dst_utils.can_be_equipped_in_slot(item, slot)
   return item and item.components and item.components.equippable and item.components.equippable.equipslot == slot
end

return dst_utils
