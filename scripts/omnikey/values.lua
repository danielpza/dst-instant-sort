local values = {}

local LIGHT_ITEMS = {
   "torch",
   "lighter",
   "tarlamp",
   "minerhat",
   "lantern",
   "bottlelantern",
   "molehat",
   "gears_hat_goggles",
}

values.USAGE_MULT = 10
values.DAMAGE_MULT = 100
values.ARMOR_MULT = 100000
values.CONSUMPTION_MULT = 1000
values.SLINGSHOT_PRIORITY = 1000000
values.HAMBAT_PRIORITY = 10000
values.NO_FINITEUSES_VALUE = 100

---@generic T
---@param arr T[]
---@param value T
local function index_of(arr, value)
   for i, v in ipairs(arr) do
      if value == v then return i end
   end
   return -1
end

local function can_be_equipped(item, slot)
   return item.components.equippable and item.components.equippable.equipslot == slot
end

local function value_usage(item)
   if item.components.finiteuses == nil then return 0 end
   return item.components.finiteuses.total * values.USAGE_MULT - item.components.finiteuses.current
end

local function value_dapperness(item)
   if not item.components.equippable then return 0 end
   return item.components.equippable.dapperness or 0
end

local function value_insulation(item)
   if not item.components.insulator or not item.components.insulator.insulation then return 0 end
   return item.components.insulator.insulation
end

local function value_damage(item)
   if not item.components.weapon then return 0 end
   return item.components.weapon.damage * values.DAMAGE_MULT + value_usage(item)
end

local function action_value_consumption(item, action)
   if item.components.finiteuses == nil then return values.NO_FINITEUSES_VALUE end
   return 1 / item.components.finiteuses.consumption[action]
end

local function value_armor(item)
   if not item.components.armor then return 0 end
   return item.components.armor.absorb_percent * values.ARMOR_MULT - item.components.armor.condition
end

local function action_value_tool(item, action)
   if not item.components.tool or not item.components.tool.actions[action] then return 0 end
   return action_value_consumption(item, action) * values.CONSUMPTION_MULT + value_usage(item)
end

---@param item ds.entityscript
---@param slot ds.equipslot
local function slot_value_cloth(item, slot)
   if not can_be_equipped(item, slot) then return 0 end
   return value_insulation(item) + value_dapperness(item) / 10
end

---@param item ds.entityscript
---@param slot ds.equipslot
local function slot_value_armor(item, slot)
   if not can_be_equipped(item, slot) then return 0 end
   return value_armor(item) + slot_value_cloth(item, slot)
end

---@param action ds.actions.action
function values.tool(action)
   ---@param item ds.entityscript
   return function(item) return action_value_tool(item, action) end
end

---@param item ds.entityscript
function values.weapon(item) return value_damage(item) end

---@param slot ds.equipslot
function values.slot_cloth(slot)
   ---@param item ds.entityscript
   return function(item) return slot_value_cloth(item, slot) end
end

---@param slot ds.equipslot
function values.slot_armor(slot)
   ---@param item ds.entityscript
   return function(item) return slot_value_armor(item, slot) end
end

---@param item ds.entityscript
function values.light(item)
   local i = index_of(LIGHT_ITEMS, item.prefab)
   if i == -1 then return 0 end
   return 1 / i
end

---@param item ds.entityscript
function values.cane(item)
   if
      not item.components.equippable
      or not item.components.equippable.walkspeedmult
      or item.components.equippable.walkspeedmult <= 1
   then
      return 0
   end
   return item.components.equippable.walkspeedmult
end

return values
