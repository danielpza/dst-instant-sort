local utils = {}

local function cast_booelan(v) return v and true or false end

---@param a boolean
---@param b boolean
---@return number
function utils.cmp_boolean(a, b)
   local aa = cast_booelan(a)
   local bb = cast_booelan(b)
   if aa == bb then return 0 end
   return aa and -1 or 1
end

---@param a string
---@param b string
---@return number
function utils.cmp_string(a, b)
   if a == b then return 0 end
   return a < b and -1 or 1
end

---@param a number
---@param b number
---@return number end
function utils.cmp_number(a, b) return a - b end

---@generic T
---@param cmps (fun (a: T, b: T): number)[]
---@return fun(a: T, b: T): number
function utils.cmp_many(cmps)
   return function(a, b)
      for _, cmp in ipairs(cmps) do
         local result = cmp(a, b)
         if result ~= 0 then return result end
      end
      return 0
   end
end

--- Comparator adapter from `(a, b): number` to `(a, b): boolean` by groupping a bunch of comparators.
--- We need to return a number in the comparator function in order to be able to sort by many comparators,
--- but `table.sort` expects a boolean
---@generic T
---@param cmp fun (a: T, b: T): number
---@return fun(a: T, b: T): boolean
function utils.sort_adapter(cmp)
   return function(a, b) return cmp(a, b) < 0 end
end

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
