local virtual_inventory = require("instant-sort/virtual_inventory")
-- for debugging
GLOBAL.CHEATS_ENABLED = true
require("debugkeys")
--

local KEY_TOGGLE = GetModConfigData("KEY_TOGGLE")

----------------------------HELPERS----------------------------------
local function cast_number(v)
   if type(v) == "number" then return v end
   if v == nil then return 0 end
   if v == false then return 0 end
   return -1
end

---@param a string
---@param b string
---@return number
local function cmp_string(a, b)
   if a == b then return 0 end
   return a < b and -1 or 1
end

local function cmp(a, b)
   if type(a) == "string" and type(b) == "string" then return cmp_string(a, b) end
   return cast_number(a) - cast_number(b)
end

---@generic T
---@param arr T[]
---@param item T
---@return integer
local function index_of(arr, item)
   for i, v in ipairs(arr) do
      if v == item then return i end
   end
   return 0
end
----------------------------HELPERS----------------------------------

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
---@param item ds.entityscript
---@return ds.entityscript
local function get_cached_mastersim_prefab(item)
   if not cache[item.prefab] then
      cache[item.prefab] = simulate_mastersim_prefab(
         item.prefab,
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
   return cache[item.prefab]
end
----------------------------HELPERS2----------------------------------

----------------------------VALUES----------------------------------
---@alias item_value fun(a: ds.entityscript): any
---@alias invslot_value fun(a: ds.widgets.invslot): any

---@alias cmp_item fun(a: ds.entityscript, b: ds.entityscript): boolean
---@alias cmp_invslot fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean

---@param item ds.entityscript
---@param slot ds.equipslot
---@return boolean
local function can_item_be_equipped_in_slot(item, slot)
   local cached = get_cached_mastersim_prefab(item)
   return cached and cached.components and cached.components.equippable and item.components.equippable.equipslot == slot
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
local function invslot_name_value(invslot)
   local item = invslot and invslot.tile and invslot.tile.item
   return item and item.name
end

---@param prefabs string[]
---@return invslot_value
local function invslot_prefabs(prefabs)
   return function(invslot)
      local item = invslot and invslot.tile and invslot.tile.item
      -- this code is ugly, there might be a simpler way
      if not item then return 0 end
      local i = index_of(prefabs, item.prefab)
      if i == 0 then return #prefabs + 1 end
      return i
   end
end

---@param prefabs string[]
---@return invslot_value
local function invslot_prefabs_back(prefabs)
   return function(invslot)
      local item = invslot and invslot.tile and invslot.tile.item
      return item and (-1 / index_of(prefabs, item.prefab))
   end
end

----------------------------VALUES----------------------------------

---@type invslot_value[]
local SORT_BY = {
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HANDS),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HEAD),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.BODY),
   invslot_is_equippable,
   invslot_is_empty,
   invslot_prefabs_back({ "cutgrass", "twigs", "goldnugget", "flint", "rocks", "log" }),
   invslot_name_value,
}

---@type cmp_invslot
local function invslot_cmp(a, b)
   for _, get_value in ipairs(SORT_BY) do
      local result = cmp(get_value(a), get_value(b))
      if result ~= 0 then return result < 0 end
   end
   return false
end

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

local keepitsorted = true

local function refresh()
   if not keepitsorted then return end
   if not player_is_ready() then return end
   local inventorybar = get_player_inventorybar()
   if not inventorybar then return end

   virtual_inventory.from(inventorybar.inv):Sort(invslot_cmp)

   -- if inventorybar.backpackinv then
   --    virtual_inventory.sort_invslots(inventorybar.backpackinv, backpack_positions, invslot_cmp)
   -- end
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
      -- if inventorybar.backpackinv then
      --    virtual_inventory.reset_invslots(inventorybar.backpackinv, backpack_positions)
      -- end
   end
end

GLOBAL.TheInput:AddKeyUpHandler(KEY_TOGGLE, toggle_sort)

---@param self ds.widgets.inventorybar.inv
AddClassPostConstruct("widgets/inventorybar", function(self)
   local inventorybar = self
   if inventorybar.owner ~= GLOBAL.ThePlayer then return end

   -- local overflow = inventorybar.owner.replica.inventory and inventorybar.owner.replica.inventory:GetOverflowContainer()
   -- local do_integrated_backpack = overflow ~= nil and self.integrated_backpack

   for _, event in ipairs(EVENTS) do
      self.inst:ListenForEvent(event, refresh, self.owner)
      -- if do_integrated_backpack then self.inst:ListenForEvent(event, refresh, overflow.inst) end
   end

   local Rebuild = inventorybar.Rebuild
   function inventorybar:Rebuild()
      Rebuild(inventorybar)
      virtual_inventory.from(inventorybar.inv):Rebuild()
      -- if inventorybar.backpackinv then
      --    backpack_positions = virtual_inventory.get_positions(inventorybar.backpackinv)
      -- else
      --    backpack_positions = {}
      -- end
      refresh()
   end
end)
