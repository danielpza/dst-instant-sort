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

-- memoize function
-- see https://lodash.info/doc/memoize
function utils.memoize(fn, get_key)
   local cache = {}
   return function(param)
      local key = get_key(param)
      if not cache[key] then cache[key] = fn(param) end
      return cache[key]
   end
end

---@generic T
---@param to T[]
---@param from T[]
---@return T[]
function utils.table_append_many(to, from)
   for _, value in ipairs(from) do
      to[#to + 1] = value
   end
   return to
end

---@generic T
---@param tbl T[]
---@return T[]
function utils.table_shallow_copy(tbl) return utils.table_append_many({}, tbl) end

---@generic T
---@param tbl1 T[][]
---@return T[]
function utils.table_flatten(tbls)
   local result = {}
   for _, tbl in ipairs(tbls) do
      utils.table_append_many(result, tbl)
   end
   return result
end

return utils
