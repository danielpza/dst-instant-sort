---@diagnostic disable:lowercase-global

local function GenerateOptions()
   local keys, dividers, boolOptions

   keys = {}
   string = ""

   for i = string.byte("0"), string.byte("9") do
      keys[#keys + 1] = { description = string.upper(string.char(i)), data = i }
   end
   for i = string.byte("a"), string.byte("z") do
      keys[#keys + 1] = { description = string.upper(string.char(i)), data = i }
   end

   dividers = 0

   boolOptions = { { description = "No", data = false }, { description = "Yes", data = true } }

   local utils = {}
   function utils.BooleanOption(name, def, label, hover)
      return { name = name, default = def, options = boolOptions, label = label, hover = hover }
   end

   function utils.Keybind(name, def, label, hover)
      return { name = name, label = label, default = string.byte(def), options = keys, hover = hover }
   end

   function utils.Title(title, hover)
      -- https://dst-api-docs.fandom.com/wiki/Modinfo.lua#How_to_make_title_in_options:
      dividers = dividers + 1
      return {
         name = "__" .. string.format("%d", dividers) .. "title",
         label = title,
         hover = hover,
         options = { { description = "", data = false } }, -- A list of one item - boolean option without a description
         default = false,
      }
   end

   return utils
end

name = "modname-dev"
description = "Add keybindings to use with tools, weapons, armor and much more."
author = "danielpza"
version = "0.9.2"

-- icon_atlas = "icon_atlas.xml"
-- icon = "icon.tex"

api_version = 10

dont_starve_compatible = false
dst_compatible = true

all_clients_require_mod = false
client_only_mod = true

local utils = GenerateOptions()

configuration_options = {
   utils.Title("Options"),
   utils.BooleanOption("EXAMPLE_BOOLEAN_OPTION", true, "Example Boolean Option"),
   utils.Title("Keybindings"),
   utils.Keybind("EXAMPLE_KEYBINDING", "g", "Keybinding"),
}
