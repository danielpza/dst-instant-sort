local OmnikeyWidgets = {}

local TEMPLATES = require("widgets/templates")
local Widget = require("widgets/widget")

-- layout constants copied from widgets/inventorybar.lua
local W = 68 -- slot size
local SEP = 12 -- gap between slots

-- TEMPLATES.IconButton frames are natively 70x70 (widgets/redux/templates.lua)
local BUTTON_BASE_SIZE = 70

OmnikeyWidgets.SLOT_SIZE = W
OmnikeyWidgets.SLOT_GAP = SEP
OmnikeyWidgets.BUTTON_SCALE = 1.25

-- actual on-screen size of a button after its own scale transform
OmnikeyWidgets.HEIGHT = BUTTON_BASE_SIZE * OmnikeyWidgets.BUTTON_SCALE

-- one button per slot cell, same pitch as the inventory slots themselves
OmnikeyWidgets.SLOT_SPACING = W + SEP

local FALLBACK_ATLAS = "images/inventoryimages.xml"

-- vertical distance from a slot's center to the button row's center:
-- half a slot + SEP gap + half a button
local ROW_HEIGHT = (W + OmnikeyWidgets.HEIGHT) / 2 + SEP

-- vertical offset from a slot's center to the button row's center
OmnikeyWidgets.ROW_HEIGHT = ROW_HEIGHT

---@param image string
---@param text string | nil
---@param onclick fun()
function OmnikeyWidgets.InventoryButton(image, text, onclick)
   local image_name = image .. ".tex"
   local atlas = GetInventoryItemAtlas(image_name) or FALLBACK_ATLAS
   -- local x = OmnikeyWidgets.SLOT_SPACING * offset

   local button = TEMPLATES.IconButton(atlas, image_name, text, nil, nil, onclick)

   button.icon:SetScale(0.7)
   button:SetScale(OmnikeyWidgets.BUTTON_SCALE)
   -- button:SetPosition(x, 0, 0)
   button:MoveToFront()

   return button
end

function OmnikeyWidgets.Container()
   ---@class omnikeywidgets.container: ds.widgets.widget
   local root = Widget("omnikkey_root")

   root.omnikey_offset = 0

   ---@param btn ds.widgets.widget
   function root:AddButton(btn)
      root:AddChild(btn)

      btn:SetPosition(OmnikeyWidgets.SLOT_SPACING * root.omnikey_offset, 0, 0)
      root.omnikey_offset = root.omnikey_offset + 1
   end

   return root
end

return OmnikeyWidgets
