-- for debugging
GLOBAL.CHEATS_ENABLED = true
require("debugkeys")
--

local CONFIG_EXAMPLE_BOOLEAN_OPTION = GetModConfigData("EXAMPLE_BOOLEAN_OPTION")
local CONFIG_EXAMPLE_KEYBINDING = GetModConfigData("EXAMPLE_KEYBINDING")

---@generic T
---@param cmps (fun (a: T, b: T): number)[]
---@return fun(a: T, b: T): boolean
local function cmp_all_(cmps)
   return function(a, b)
      for _, cmp in ipairs(cmps) do
         local result = cmp(a, b)
         if result ~= 0 then return result < 0 end
      end
      return false
   end
end

---@param fn fun(item: ds.entityscript): boolean
---@return fun(a: ds.entityscript, b: ds.entityscript): number
local function cmp_by(fn)
   return function(a, b)
      local va = fn(a)
      local vb = fn(b)
      if va == vb then return 0 end
      return va and -1 or 1
   end
end

---@type fun(a: ds.entityscript, b: ds.entityscript): number
local function cmp_name(a, b)
   if a.name == b.name then return 0 end
   return a.name < b.name and -1 or 1
end

local cmp_equippable = cmp_by(
   function(item) return item and item.replica and item.replica.equippable and true or false end
)

local SORT_ORDER = {
   cmp_equippable,
   cmp_name,
}

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

-- virtual inventory manager
local virtual_inv = {
   ---@type ds.vector3[]
   positions = {},
   ---@type ds.widgets.inventorybar.inv
   inventorybar = nil,
}

---@param inventorybar ds.widgets.inventorybar.inv
function virtual_inv:_Rebuild(inventorybar)
   for k, slot in ipairs(inventorybar.inv) do
      self.positions[k] = slot:GetPosition()
   end
end

---@param inventorybar ds.widgets.inventorybar.inv
function virtual_inv:SetupInventorybarHooks(inventorybar)
   local s = self
   s.inventorybar = inventorybar
   local Rebuild = inventorybar.Rebuild
   function inventorybar:Rebuild()
      Rebuild(inventorybar)
      s:_Rebuild(inventorybar)
   end
end

---@param cmp fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean
function virtual_inv:SortInvSlots(cmp)
   local inventorybar = self.inventorybar

   ---@type ds.widgets.invslot[]
   local sorted_slots = {}

   for _, slot in ipairs(inventorybar.inv) do
      sorted_slots[#sorted_slots + 1] = slot
   end

   table.sort(sorted_slots, cmp)

   for k, slot in ipairs(sorted_slots) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(virtual_inv.positions[k])
   end
end

function virtual_inv:Reset()
   local inventorybar = self.inventorybar
   for k, slot in ipairs(inventorybar.inv) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(virtual_inv.positions[k])
   end
end

---@return ds.widgets.inventorybar.inv|nil
local function get_player_inventorybar()
   ---@diagnostic disable-next-line: return-type-mismatch
   return GLOBAL.ThePlayer
      and GLOBAL.ThePlayer.HUD
      and GLOBAL.ThePlayer.HUD.controls
      and GLOBAL.ThePlayer.HUD.controls.inv
end

local function player_is_ready()
   return GLOBAL.ThePlayer ~= nil or GLOBAL.TheFrontEnd:GetActiveScreen() == GLOBAL.ThePlayer.HUD
end

local cmp_all = cmp_all_(SORT_ORDER)

---@type fun(a: ds.widgets.invslot, b: ds.widgets.invslot): boolean
local function inv_slot_cmp(a, b)
   if not (a and a.tile and a.tile.item) then return false end
   if not (b and b.tile and b.tile.item) then return true end
   return cmp_all(a.tile.item, b.tile.item)
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
end)
