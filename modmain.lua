-- for debugging
GLOBAL.CHEATS_ENABLED = true
require("debugkeys")
--

local virtual_inv = require("instant-sort/virtual_inventory")

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

---@param fn item_value
---@return invslot_value
local function wiht_invslot_item(fn)
   return function(invslot)
      local item = invslot and invslot.tile and invslot.tile.item
      return item and fn(item)
   end
end

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

----------------------------VALUES----------------------------------

---@type invslot_value[]
local SORT_BY = {
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HANDS),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.HEAD),
   invslot_can_be_equipped_in_slot(GLOBAL.EQUIPSLOTS.BODY),
   invslot_is_equippable,
   invslot_is_empty,
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

local keepitsorted = false

local function refresh()
   if not keepitsorted then return end
   if not player_is_ready() then return end
   if not get_player_inventorybar() then return end
   virtual_inv:SortInvSlots(invslot_cmp)
end

local function toggle_sort()
   if not player_is_ready() then return end
   if not get_player_inventorybar() then return end

   keepitsorted = not keepitsorted
   if keepitsorted then
      refresh()
   else
      virtual_inv:Reset()
   end
end

GLOBAL.TheInput:AddKeyUpHandler(KEY_TOGGLE, toggle_sort)

---@param self ds.widgets.inventorybar.inv
AddClassPostConstruct("widgets/inventorybar", function(self)
   local inventorybar = self
   if inventorybar.owner ~= GLOBAL.ThePlayer then return end

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
