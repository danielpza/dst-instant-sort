-- for debugging
GLOBAL.CHEATS_ENABLED = true
require("debugkeys")
--

local virtual_inv = require("instant-sort/virtual_inventory")
local dst_utils = require("instant-sort/dst_utils")
local utils = require("instant-sort/utils")
local CONFIG_EXAMPLE_BOOLEAN_OPTION = GetModConfigData("EXAMPLE_BOOLEAN_OPTION")
local CONFIG_EXAMPLE_KEYBINDING = GetModConfigData("EXAMPLE_KEYBINDING")

---@generic T
---@param cmp fun(a: T, b: T): number
---@return fun(a: T, b: T): number
function desc(cmp)
   return function(a, b) return -cmp(a, b) end
end

---@generic T
---@param prefab string
---@param fn fun(item: ds.entityscript): T
---@return T
local function simulate_mastersim_prefab(prefab, fn)
   local isMasterSim = GLOBAL.TheWorld.ismastersim
   GLOBAL.TheWorld.ismastersim = true
   local entity = GLOBAL.SpawnPrefab(prefab)
   local result = fn(entity)
   entity:Remove()
   GLOBAL.TheWorld.ismastersim = isMasterSim
   return result
end

---@generic T
---@param fn fun(item: ds.entityscript): T
---@return fun(item: ds.entityscript): T
local function with_mastersim_prefab(fn)
   return function(item) return simulate_mastersim_prefab(item, fn) end
end

---@alias cmp_item fun(a: ds.entityscript, b: ds.entityscript): number
---@alias cmp_invslot fun(a: ds.widgets.invslot, b: ds.widgets.invslot): number

---@type cmp_item
local function cmp_item_by_name(a, b)
   if a.name == b.name then return 0 end
   return a.name < b.name and -1 or 1
end

---@type cmp_item
local function cmp_item_equippable(a, b)
   return utils.cmp_boolean(dst_utils.is_equippable(a), dst_utils.is_equippable(b))
end

-- ---@param slot ds.equipslot
-- ---@return cmp_item
-- local function cmp_item_slot_equippable(slot)
--    return function(a, b) end
-- end

---@param item_cmp cmp_item
---@return cmp_invslot
local function cmp_invslot_item_(item_cmp)
   return function(a, b)
      local aitem = a and a.tile and a.tile.item
      local bitem = b and b.tile and b.tile.item

      if not aitem and not bitem then return 0 end
      if not aitem then return 1 end
      if not bitem then return -1 end

      return item_cmp(aitem, bitem)
   end
end

---@type cmp_invslot
local function cmp_invslot_has_item(a, b)
   return utils.cmp_boolean(a and a.tile and a.tile.item, b and b.tile and b.tile.item)
end

-- local SORT_ORDER = {
--    cmp_item_equippable,
--    cmp_item_by_name,
-- }

local inv_slot_cmp = utils.sort_adapter(utils.cmp_many({
   cmp_invslot_item_(cmp_item_equippable),
   -- desc(cmp_invslot_has_item),
   cmp_invslot_item_(cmp_item_by_name),
}))

local EVENTS = {
   "builditem",
   "itemget",
   "equip",
   "unequip",
   "newactiveitem",
   "itemlose",
   "refreshinventory",
   "onplacershown",
   "onplacerhidden",
}

---@return ds.widgets.inventorybar.inv|nil
local function get_player_inventorybar()
   ---@diagnostic disable-next-line: return-type-mismatch
   return GLOBAL.ThePlayer
      and GLOBAL.ThePlayer.HUD
      and GLOBAL.ThePlayer.HUD.controls
      and GLOBAL.ThePlayer.HUD.controls.inv
end

local function player_is_ready()
   return GLOBAL.ThePlayer ~= nil and GLOBAL.TheFrontEnd:GetActiveScreen() == GLOBAL.ThePlayer.HUD
end

local keepitsorted = false

local function refresh()
   if not keepitsorted then return end
   if not player_is_ready() then return end
   if not get_player_inventorybar() then return end
   virtual_inv:SortInvSlots(inv_slot_cmp)
end

GLOBAL.TheInput:AddKeyUpHandler(GLOBAL.KEY_P, function()
   if not player_is_ready() then return end
   if not get_player_inventorybar() then return end

   virtual_inv:SortInvSlots(inv_slot_cmp)
   keepitsorted = true
end)

GLOBAL.TheInput:AddKeyUpHandler(GLOBAL.KEY_O, function()
   if not player_is_ready() then return end
   if not get_player_inventorybar() then return end

   virtual_inv:Reset()
   keepitsorted = false
end)

---@param self ds.widgets.inventorybar.inv
AddClassPostConstruct("widgets/inventorybar", function(self)
   local inventorybar = self
   if inventorybar.owner ~= GLOBAL.ThePlayer then return end

   virtual_inv:SetupInventorybarHooks(inventorybar)

   for _, event in ipairs(EVENTS) do
      self.inst:ListenForEvent(event, refresh, self.owner)
   end

   local Rebuild = inventorybar.Rebuild
   function inventorybar:Rebuild()
      Rebuild(inventorybar)
      virtual_inv:_Rebuild(inventorybar)
      refresh()
   end
end)
