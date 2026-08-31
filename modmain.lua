local virtual_inventory = require("instant_sort/virtual_inventory")
local utils = require("instant_sort/utils")
-- for debugging
GLOBAL.CHEATS_ENABLED = true
require("debugkeys")
--

local KEY_TOGGLE = GetModConfigData("KEY_TOGGLE")

----------------------------HELPERS2----------------------------------

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

---@type table<string, ds.entityscript>
local cache = {}
---@param item_ ds.entityscript
---@return ds.entityscript
local function get_cached_mastersim_prefab(item_)
   if not cache[item_.prefab] then
      cache[item_.prefab] = simulate_mastersim_prefab(
         item_.prefab,
         function(item)
            return item
               and {
                  components = item.components and {
                     equippable = item.components.equippable and {
                        equipslot = item.components.equippable.equipslot,
                     },
                  },
               }
         end
      )
   end
   return cache[item_.prefab]
end

local function unregister_events(instance, events, handler, target)
   for _, event in ipairs(events) do
      instance:RemoveEventCallback(event, handler, target)
   end
end

local function register_events(instance, events, handler, target)
   for _, event in ipairs(events) do
      instance:ListenForEvent(event, handler, target)
   end
   return function() unregister_events(instance, events, handler, target) end
end

----------------------------HELPERS2----------------------------------

----------------------------VALUES----------------------------------
---@alias item_value fun(a: ds.entityscript): any
---@alias invslot_value fun(a: ds.widgets.invslot): any

---@alias cmp_item fun(a: ds.entityscript, b: ds.entityscript): boolean
---@alias cmp_invslot fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean

---@param item_ ds.entityscript
---@param slot ds.equipslot
---@return boolean
local function can_item_be_equipped_in_slot(item_, slot)
   local item = get_cached_mastersim_prefab(item_)
   return item and item.components and item.components.equippable and item.components.equippable.equipslot == slot
end

---@type invslot_value
local function invslot_is_equippable(invslot)
   local item = invslot and invslot.tile and invslot.tile.item
   return item and item.replica and item.replica.equippable
end

---@param slot ds.equipslot
---@return invslot_value
local function invslot_can_be_equipped_in_slot(slot)
   return function(invslot)
      local item = invslot and invslot.tile and invslot.tile.item
      return item and can_item_be_equipped_in_slot(item, slot)
   end
end

---@type invslot_value
local function invslot_is_empty(invslot) return not (invslot and invslot.tile and invslot.tile.item) end

---@type invslot_value
local function invslot_is_filled(invslot) return (invslot and invslot.tile and invslot.tile.item) end

---@type invslot_value
local function invslot_name_value(invslot)
   local item = invslot and invslot.tile and invslot.tile.item
   return item and item.prefab
end

---@param prefabs string[]
---@return invslot_value
local function invslot_prefabs(prefabs)
   return function(invslot)
      local item = invslot and invslot.tile and invslot.tile.item
      -- this code is ugly, there might be a simpler way
      if not item then return 0 end
      local i = utils.index_of(prefabs, item.prefab)
      if i == 0 then return #prefabs + 1 end
      return i
   end
end

---@param prefabs string[]
---@return invslot_value
local function invslot_prefabs_back(prefabs)
   return function(invslot)
      local item = invslot and invslot.tile and invslot.tile.item
      return item and utils.index_of(prefabs, item.prefab)
   end
end

----------------------------VALUES----------------------------------

local function sort_by(criteria)
   ---@type cmp_invslot
   return function(a, b)
      for _, get_value in ipairs(criteria) do
         local result = utils.cmp(get_value(a), get_value(b))
         if result ~= 0 then return result < 0 end
      end
      return false
   end
end

---@type invslot_value
local inventory_sort_cmp = sort_by({
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HANDS),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HEAD),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.BODY),
   invslot_is_equippable,
   invslot_is_empty,
   invslot_prefabs_back({ "cutgrass", "twigs", "goldnugget", "flint", "rocks", "log" }),
   invslot_name_value,
})

---@type invslot_value
local container_sort_cmp = sort_by({
   invslot_is_filled,
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HANDS),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HEAD),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.BODY),
   invslot_is_equippable,
   invslot_prefabs({ "cutgrass", "twigs", "goldnugget", "flint", "rocks", "log" }),
   invslot_name_value,
})

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

local INTEGRATED_BACKPACK_EVENTS = {
   "itemget",
   "itemlose",
   "refresh",
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

local keepitsorted = true

local function refresh()
   if not keepitsorted then return end
   if not player_is_ready() then return end
   local inventorybar = get_player_inventorybar()
   if not inventorybar then return end

   virtual_inventory.from(inventorybar.inv):Sort(inventory_sort_cmp)
end

local function toggle_sort()
   if not player_is_ready() then return end
   if not get_player_inventorybar() then return end
   local inventorybar = get_player_inventorybar()
   if not inventorybar then return end

   keepitsorted = not keepitsorted
   if keepitsorted then
      refresh()
   else
      virtual_inventory.from(inventorybar.inv):Reset()
   end
end

GLOBAL.TheInput:AddKeyUpHandler(KEY_TOGGLE, toggle_sort)

---@param self ds.widgets.containerwidget
AddClassPostConstruct("widgets/containerwidget", function(self)
   local function refresh_container()
      if not keepitsorted then return end
      if self.inv then virtual_inventory.from(self.inv):Sort(container_sort_cmp) end
   end

   local function rebuild() virtual_inventory.from(self.inv):Rebuild() end

   local Open = self.Open
   ---@diagnostic disable-next-line: inject-field
   function self:Open(container, doer)
      local result = Open(self, container, doer)
      rebuild()
      refresh_container()
      return result
   end
   local OnItemLose = self.OnItemLose
   ---@diagnostic disable-next-line: inject-field
   function self:OnItemLose(data)
      local result = OnItemLose(self, data)
      refresh_container()
      return result
   end
   local OnItemGet = self.OnItemGet
   ---@diagnostic disable-next-line: inject-field
   function self:OnItemGet(data)
      local result = OnItemGet(self, data)
      refresh_container()
      return result
   end
   local Refresh = self.Refresh
   ---@diagnostic disable-next-line: inject-field
   function self:Refresh()
      local result = Refresh(self)
      refresh_container()
      return result
   end
end)

---@param self ds.widgets.inventorybar.inv
AddClassPostConstruct("widgets/inventorybar", function(self)
   local inventorybar = self
   if inventorybar.owner ~= GLOBAL.ThePlayer then return end

   local function rebuild()
      virtual_inventory.from(self.inv):Rebuild()
      refresh()
   end

   local function refresh_backpack()
      if not keepitsorted then return end
      virtual_inventory.from(self.backpackinv):Sort(inventory_sort_cmp)
   end

   local function rebuild_backpack()
      virtual_inventory.from(self.backpackinv):Rebuild()
      refresh_backpack()
   end

   local unregiser_backpack_events = nil

   register_events(self.inst, EVENTS, refresh, self.owner)

   local Rebuild = inventorybar.Rebuild
   function inventorybar:Rebuild()
      Rebuild(inventorybar)
      rebuild()

      -- similar to what the original code does for the integrated backpack mount/unmount:
      if unregiser_backpack_events then
         unregiser_backpack_events()
         unregiser_backpack_events = nil
      end
      ---@diagnostic disable-next-line: undefined-field
      if self.backpack then
         unregiser_backpack_events =
            ---@diagnostic disable-next-line: undefined-field
            register_events(self.inst, INTEGRATED_BACKPACK_EVENTS, refresh_backpack, self.backpack)
         rebuild_backpack()
      end
   end
end)
