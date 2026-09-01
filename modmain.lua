-- for debugging
-- GLOBAL.CHEATS_ENABLED = true
-- require("debugkeys")
--

local virtual_inventory = require("instant_sort/virtual_inventory")
local utils = require("instant_sort/utils")

----------------------------HELPERS----------------------------------

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
                  prefab = item.prefab,
                  components = item.components and {
                     equippable = item.components.equippable and {
                        equipslot = item.components.equippable.equipslot,
                        walkspeedmult = item.components.equippable.walkspeedmult,
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

----------------------------HELPERS----------------------------------

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

---@type invslot_value
local function invslot_walkspeed_mult(invslot)
   local item_ = invslot and invslot.tile and invslot.tile.item
   local item = item_ and get_cached_mastersim_prefab(item_)
   return item
      and item.components.equippable
      and item.components.equippable.walkspeedmult
      and item.components.equippable.walkspeedmult > 1
      and -item.components.equippable.walkspeedmult
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
   -- TODO
   invslot_walkspeed_mult,
   -- hambat
   -- weapons
   -- armor
   -- light
   -- insulation/raincoat/etc
   -- tools
   -- sanity
   -- healing
   -- food
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

local INVENTORYBAR_EVENTS = {
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

---@type virual_inventory_data
local player_virtual_inventory = nil

---@param self ds.widgets.containerwidget
AddClassPostConstruct("widgets/containerwidget", function(self)
   local function refresh_container()
      -- if not keepitsorted then return end
      if not self.inv then return end
      virtual_inventory.from(self.inv):Sort(container_sort_cmp)
   end

   local function rebuild()
      if not self.inv then return end
      virtual_inventory.from(self.inv):Rebuild()
      refresh_container()
   end

   local Open = self.Open
   ---@diagnostic disable-next-line: inject-field
   function self:Open(container, doer)
      local result = Open(self, container, doer)
      rebuild()
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

AddClassPostConstruct("screens/playerhud", function(self)
   local REGION_1_START = GLOBAL.CONTROL_INV_1
   local REGION_1_END = GLOBAL.CONTROL_INV_10
   local REGION_1_OFFSET = GLOBAL.CONTROL_INV_1 - 1

   local REGION_2_START = GLOBAL.CONTROL_INV_11
   local REGION_2_END = GLOBAL.CONTROL_INV_15
   local REGION_2_OFFSET = GLOBAL.CONTROL_INV_11 - 1

   local CONTROL_BORDER = GLOBAL.CONTROL_INV_10 - REGION_1_OFFSET

   local OnControl = self.OnControl
   function self:OnControl(control, down)
      -- intercept control
      if player_virtual_inventory and control >= REGION_1_START and control <= REGION_1_END then
         local hot_key_num = control - REGION_1_OFFSET
         local new_hot_key_num = player_virtual_inventory:GetOriginalSlot(hot_key_num)

         if new_hot_key_num <= CONTROL_BORDER then
            control = new_hot_key_num + REGION_1_OFFSET
         else
            control = new_hot_key_num + REGION_2_OFFSET - CONTROL_BORDER
         end
      elseif player_virtual_inventory and control >= REGION_2_START and control <= REGION_2_END then
         local hot_key_num = control - REGION_2_OFFSET + CONTROL_BORDER
         local new_hot_key_num = player_virtual_inventory:GetOriginalSlot(hot_key_num)

         if new_hot_key_num <= CONTROL_BORDER then
            control = new_hot_key_num + REGION_1_OFFSET
         else
            control = new_hot_key_num + REGION_2_OFFSET - CONTROL_BORDER
         end
      end

      return OnControl(self, control, down)
   end
end)

---@param self ds.widgets.inventorybar.inv
AddClassPostConstruct("widgets/inventorybar", function(self)
   local inventorybar = self
   if inventorybar.owner ~= GLOBAL.ThePlayer then return end

   local function refresh()
      -- if not keepitsorted then return end
      virtual_inventory.from(self.inv):Sort(inventory_sort_cmp)
   end

   local function rebuild()
      virtual_inventory.from(self.inv):Rebuild()
      player_virtual_inventory = virtual_inventory.from(self.inv)
      refresh()
   end

   local function refresh_backpack()
      -- if not keepitsorted then return end
      virtual_inventory.from(self.backpackinv):Sort(inventory_sort_cmp)
   end

   local function rebuild_backpack()
      virtual_inventory.from(self.backpackinv):Rebuild()
      refresh_backpack()
   end

   local unregiser_backpack_events = nil

   register_events(self.inst, INVENTORYBAR_EVENTS, refresh, self.owner)

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
