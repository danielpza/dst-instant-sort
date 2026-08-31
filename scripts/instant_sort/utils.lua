local utils = {}

function utils.cast_number(v)
   if type(v) == "number" then return v end
   if v == nil then return 0 end
   if v == false then return 0 end
   return -1
end

---@param a string
---@param b string
---@return number
function utils.cmp_string(a, b)
   if a == b then return 0 end
   return a < b and -1 or 1
end

function utils.cmp(a, b)
   if type(a) == "string" and type(b) == "string" then return utils.cmp_string(a, b) end
   return utils.cast_number(a) - utils.cast_number(b)
end

---@generic T
---@param arr T[]
---@param item T
---@return integer
function utils.index_of(arr, item)
   for i, v in ipairs(arr) do
      if v == item then return i end
   end
   return 0
end

return utils
