local utils = {}

---@generic T
---@param arr T[]
---@return T[]
function utils.shallow_copy(arr)
   ---@type T[]
   local sorted = {}
   for _, value in ipairs(arr) do
      sorted[#sorted + 1] = value
   end
   return sorted
end

return utils
