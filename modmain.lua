-- for debugging
-- GLOBAL.CHEATS_ENABLED = true
-- require("debugkeys")
--

local setmetatable = GLOBAL.setmetatable

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
local prefab_cache = setmetatable({}, {
   __index = function(tbl, prefab)
      local data = simulate_mastersim_prefab(
         prefab,
         function(item)
            return item
               and {
                  prefab = item.prefab,
                  components = item.components
                     and {
                        equippable = item.components.equippable
                           and {
                              equipslot = item.components.equippable.equipslot,
                              walkspeedmult = item.components.equippable.walkspeedmult,
                           },
                        weapon = item.components.weapon and {
                           damage = item.components.weapon.damage,
                        },
                        armor = item.components.armor
                           and {
                              absorb_percent = item.components.armor.absorb_percent,
                           },
                     },
               }
         end
      )
      tbl[prefab] = data
      return data
   end,
})

---@param item_ ds.entityscript
---@return ds.entityscript
local function get_cached_mastersim_prefab(item_) return prefab_cache[item_.prefab] end

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

---@param invslots ds.widgets.invslot[]
---@param positions? ds.vector3[]
---@param active_slot? ds.widgets.invslot
---@return integer?
local function find_active_index(invslots, positions, active_slot)
   if not active_slot or not positions then return nil end
   local is_in_invslots = false
   for _, slot in ipairs(invslots) do
      if slot == active_slot then
         is_in_invslots = true
         break
      end
   end
   if not is_in_invslots then return nil end

   ---@type ds.vector3?
   local active_pos = active_slot:GetPosition()
   if not active_pos then return nil end
   local closest_idx = nil
   local min_distsq = 1
   for k, pos in ipairs(positions) do
      local dx = pos.x - active_pos.x
      local dy = pos.y - active_pos.y
      local distsq = dx * dx + dy * dy
      if distsq < min_distsq then
         min_distsq = distsq
         closest_idx = k
      end
   end
   return closest_idx
end

---@param invslots ds.widgets.invslot[]
---@param comp cmp_invslot
local function sort_and_maintain_cursor(invslots, comp)
   if not invslots then return end
   local invbar = GLOBAL.ThePlayer
      and GLOBAL.ThePlayer.HUD
      and GLOBAL.ThePlayer.HUD.controls
      and GLOBAL.ThePlayer.HUD.controls.inv
   local v_inv = virtual_inventory.from(invslots)
   local active_idx = invbar and find_active_index(invslots, v_inv.positions, invbar.active_slot)
   v_inv:Sort(comp)
   if active_idx and invbar and invbar.active_slot then
      local new_active_slot = v_inv:GetVisualSlot(active_idx)
      if new_active_slot and invbar.active_slot ~= new_active_slot then
         invbar:SelectSlot(new_active_slot)
         invbar:UpdateCursor()
      end
   end
end

----------------------------HELPERS----------------------------------

----------------------------VALUES----------------------------------
---@alias item_value fun(a: ds.entityscript): any
---@alias invslot_value fun(a: ds.widgets.invslot): any

---@alias cmp_item fun(a: ds.entityscript, b: ds.entityscript): number
---@alias cmp_invslot fun(a: ds.widgets.invslot, b: ds.widgets.invslot): number

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

---@type invslot_value
local function invslot_damage(invslot)
   local item_ = invslot and invslot.tile and invslot.tile.item
   local item = item_ and get_cached_mastersim_prefab(item_)
   ---@diagnostic disable-next-line: undefined-field
   if item and item.prefab == "wathgrithr_shield" then return -(GLOBAL.TUNING.WATHGRITHR_SHIELD_DAMAGE or 10000) end
   return item
      and item.components
      and item.components.weapon
      and type(item.components.weapon.damage) == "number"
      and -item.components.weapon.damage
end

---@param slot ds.equipslot
---@return invslot_value
local function invslot_armor_slot(slot)
   return function(invslot)
      local item_ = invslot and invslot.tile and invslot.tile.item
      local item = item_ and get_cached_mastersim_prefab(item_)
      return item
         and item.components
         and item.components.armor
         and item.components.armor.absorb_percent
         and -item.components.armor.absorb_percent
   end
end

local function invslot_armor_condition(invslot)
   local item = invslot and invslot.tile and invslot.tile.item
   return item
      and item.components
      and item.components.armor
      and item.components.armor.condition
      and item.components.armor.condition
end

local function invslot_finiteuses(invslot)
   local item = invslot and invslot.tile and invslot.tile.item
   return item
      and item.components
      and item.components.finiteuses
      and item.components.finiteuses.GetUses
      and item.components.finiteuses:GetUses()
end

local function invslot_stacksize(invslot)
   local item = invslot and invslot.tile and invslot.tile.item
   return item
      and item.components
      and item.components.stackable
      and item.components.stackable.StackSize
      and item.components.stackable:StackSize()
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
   local priority_map = {}
   for i, prefab in ipairs(prefabs) do
      priority_map[prefab] = i - #prefabs - 1
   end
   return function(invslot)
      local item = invslot and invslot.tile and invslot.tile.item
      return item and priority_map[item.prefab] or 0
   end
end

---@param prefabs string[]
---@return invslot_value
local function invslot_prefabs_back(prefabs)
   local priority_map = {}
   for i, prefab in ipairs(prefabs) do
      priority_map[prefab] = i
   end
   return function(invslot)
      local item = invslot and invslot.tile and invslot.tile.item
      return item and priority_map[item.prefab] or 0
   end
end
----------------------------VALUES----------------------------------

local function sort_by(criteria)
   ---@type cmp_invslot
   return function(a, b)
      for _, get_value in ipairs(criteria) do
         local result = utils.cmp(get_value(a), get_value(b))
         if result ~= 0 then return result end
      end
      return 0
   end
end

---@type invslot_value
local inventory_sort_cmp = sort_by({
   invslot_walkspeed_mult,
   invslot_prefabs({ "hambat" }),
   invslot_damage,
   invslot_armor_slot(GLOBAL.EQUIPSLOTS.HEAD),
   invslot_armor_slot(GLOBAL.EQUIPSLOTS.BODY),
   -- TODO
   -- light
   -- insulation/raincoat/etc
   -- tools
   -- sanity
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HANDS),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HEAD),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.BODY),
   invslot_is_equippable,
   -- TODO
   -- healing
   -- food
   invslot_prefabs_back({ "cutgrass", "twigs", "goldnugget", "flint", "rocks", "log" }),
   invslot_name_value,
   invslot_armor_condition,
   invslot_finiteuses,
   invslot_stacksize,
})

local container_sort_cmp = inventory_sort_cmp

-- ---@type invslot_value
-- local container_sort_cmp = sort_by({
--    invslot_walkspeed_mult,
--    invslot_prefabs({ "hambat" }),
--    invslot_damage,
--    invslot_armor_slot(GLOBAL.EQUIPSLOTS.HEAD),
--    invslot_armor_slot(GLOBAL.EQUIPSLOTS.BODY),
--    -- TODO
--    -- light
--    -- insulation/raincoat/etc
--    -- tools
--    -- sanity
--    invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HANDS),
--    invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HEAD),
--    invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.BODY),
--    invslot_is_equippable,
--    invslot_prefabs_back({ "cutgrass", "twigs", "goldnugget", "flint", "rocks", "log" }),
--    invslot_name_value,
-- })

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
   "stacksizechange",
}

local INTEGRATED_BACKPACK_EVENTS = {
   "itemget",
   "itemlose",
   "refresh",
   "stacksizechange",
}

---@type virual_inventory_data
local player_virtual_inventory = nil

---@param self ds.widgets.containerwidget
AddClassPostConstruct("widgets/containerwidget", function(self)
   local function refresh_container()
      -- if not keepitsorted then return end
      if not self.inv then return end
      sort_and_maintain_cursor(self.inv, container_sort_cmp)
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

---@diagnostic disable: undefined-field
---@param control integer
local function inventory_input_control_to_index(control)
   if control >= GLOBAL.CONTROL_INV_1 and control <= GLOBAL.CONTROL_INV_10 then
      return control - (GLOBAL.CONTROL_INV_1 - 1)
   elseif control >= GLOBAL.CONTROL_INV_11 and control <= GLOBAL.CONTROL_INV_15 then
      return control - (GLOBAL.CONTROL_INV_11 - 1) + (GLOBAL.CONTROL_INV_10 - (GLOBAL.CONTROL_INV_1 - 1))
   else
      return nil
   end
end

---@param index integer
local function inventory_index_to_input_control(index)
   if index <= (GLOBAL.CONTROL_INV_10 - (GLOBAL.CONTROL_INV_1 - 1)) then
      return index + (GLOBAL.CONTROL_INV_1 - 1)
   else
      return index + (GLOBAL.CONTROL_INV_11 - 1) - (GLOBAL.CONTROL_INV_10 - (GLOBAL.CONTROL_INV_1 - 1))
   end
end
---@diagnostic enable: undefined-field

AddClassPostConstruct("screens/playerhud", function(self)
   local OnControl = self.OnControl
   function self:OnControl(control, down)
      -- intercept control
      if player_virtual_inventory then
         local index = inventory_input_control_to_index(control)
         if index then control = inventory_index_to_input_control(player_virtual_inventory:GetOriginalSlot(index)) end
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
      sort_and_maintain_cursor(self.inv, inventory_sort_cmp)
   end

   local function rebuild()
      virtual_inventory.from(self.inv):Rebuild()
      player_virtual_inventory = virtual_inventory.from(self.inv)
      refresh()
   end

   local function refresh_backpack()
      -- if not keepitsorted then return end
      sort_and_maintain_cursor(self.backpackinv, inventory_sort_cmp)
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
