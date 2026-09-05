local mastersim_prefabs = {}

---@generic T
---@param prefab string
---@param fn fun(item: ds.entityscript): T
---@return T
local function simulate_mastersim_prefab(prefab, fn)
   local isMasterSim = TheWorld.ismastersim
   TheWorld.ismastersim = true
   local entity = SpawnPrefab(prefab)
   local result = fn(entity)
   entity:Remove()
   TheWorld.ismastersim = isMasterSim
   return result
end

---@type table<string, ds.entityscript>
local prefab_cache = setmetatable({}, {
   __index = function(tbl, prefab)
      local data = simulate_mastersim_prefab(
         prefab,
         function(item)
            return item
               and {
                  prefab = item.prefab,
                  components = item.components
                     and {
                        equippable = item.components.equippable
                           and {
                              equipslot = item.components.equippable.equipslot,
                              walkspeedmult = item.components.equippable.walkspeedmult,
                           },
                        weapon = item.components.weapon and {
                           damage = item.components.weapon.damage,
                        },
                        armor = item.components.armor
                           and {
                              absorb_percent = item.components.armor.absorb_percent,
                           },
                     },
               }
         end
      )
      tbl[prefab] = data
      return data
   end,
})

---@param item ds.entityscript
---@return ds.entityscript
function mastersim_prefabs.get_mastersim_prefab_data(item) return prefab_cache[item.prefab] end

return mastersim_prefabs
