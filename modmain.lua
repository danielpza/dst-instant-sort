-- for debugging
GLOBAL.CHEATS_ENABLED = true
require("debugkeys")
--

local CONFIG_EXAMPLE_BOOLEAN_OPTION = GetModConfigData("EXAMPLE_BOOLEAN_OPTION")
local CONFIG_EXAMPLE_KEYBINDING = GetModConfigData("EXAMPLE_KEYBINDING")

---@param fn fun(item: ds.entityscript): boolean
---@return fun(a: ds.entityscript, b: ds.entityscript): boolean
local function cmp_by(fn)
   return function(a, b) return fn(a) and not fn(b) end
end

---@type fun(a: ds.entityscript, b: ds.entityscript): boolean
local function cmp_name(a, b) return a.name < b.name end

local cmp_equippable = cmp_by(function(item) return item.replica.equippable and true or false end)

local SORT_ORDER = {
   cmp_equippable,
   cmp_name,
}

---@param a ds.entityscript
---@param b ds.entityscript
local function cmp_all(a, b)
   for _, cmp in ipairs(SORT_ORDER) do
      if cmp(a, b) then return true end
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

local function refresh()
   ---@type ds.widgets.inventorybar.inv
   local inventorybar = GLOBAL.ThePlayer.HUD.inventorybar
   if not inventorybar then return end

   -- for k, slot in ipairs(inventorybar.inv) do
   --    slot.SetPosition(positions[num_slot - k - 1])
   -- end
   -- -- slot.tile.item
end

GLOBAL.TheInput:AddKeyUpHandler(GLOBAL.KEY_P, function()
   if not player_is_ready() then return end
   local inventorybar = get_player_inventorybar()
   if not inventorybar then return end

   local num_slot = #inventorybar.inv
   for k, slot in ipairs(inventorybar.inv) do
      ---@diagnostic disable-next-line: missing-parameter
      slot:SetPosition(virtual_inv.positions[num_slot - k + 1])
   end
end)

GLOBAL.TheInput:AddKeyUpHandler(GLOBAL.KEY_O, function()
   if not player_is_ready() then return end
   local inventorybar = get_player_inventorybar()
   if not inventorybar then return end

   virtual_inv:Reset()
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
