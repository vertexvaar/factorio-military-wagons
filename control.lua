-- Military wagons: hidden turrets ride on the wagon roof.
--
-- Factorio has no turrets on rolling stock, so every wagon gets a set of
-- unselectable, indestructible turrets. While the train moves they are
-- teleported along with the wagon (on_tick, only wagons that move do work).
-- Every few ticks they are topped up with ammo or fluid from the wagon itself.

local config = require("config")
local rigging = require("prototypes.rig")

local REFILL_INTERVAL = 30
local FORESHORTEN = rigging.FORESHORTEN

---@class Kind one entry of config.wagons, plus:
---@field sink_steps integer
---@field elevated_turret string

-- KINDS[wagon name] = Kind, only the wagons switched on in the startup settings
local KINDS = {}
local WAGON_NAMES = {}
-- every turret prototype of every kind, to find orphans
local TURRET_NAMES = {}
for _, kind in pairs(config.enabled()) do
  kind.sink_steps = rigging.sink_steps(kind.mounts)
  kind.elevated_turret = kind.turret .. "-elevated"
  KINDS[kind.name] = kind
  WAGON_NAMES[#WAGON_NAMES + 1] = kind.name
  TURRET_NAMES[#TURRET_NAMES + 1] = kind.elevated_turret
  for k = 0, kind.sink_steps do
    TURRET_NAMES[#TURRET_NAMES + 1] = rigging.sink_name(kind.turret, k)
  end
end
-- Without elevated rails every wagon is on the ground.
local ELEVATED_RAILS = script.active_mods["elevated-rails"] ~= nil

---@class Rig
---@field wagon LuaEntity
---@field kind string name of the wagon prototype, key into KINDS
---@field turrets LuaEntity[]
---@field elevated boolean turrets are the elevated variant (drawn above bridges)
---@field sinks integer[]? sink step of each ground turret (see prototypes/rig.lua), nil = 0
---@field last MapPosition? anchor position on the previous tick while moving

-- storage.rigs[wagon unit number] = Rig

-- Where the turrets are mounted: the wagon's drawn position. It is lifted on elevated
-- rails and lies south of the wagon's position when the wagon runs north-south.
local function anchor(wagon)
  local draw = wagon.draw_data
  return draw.position, ELEVATED_RAILS and draw.height > 1.5
end

local function create_turret(wagon, elevated, sink, position)
  local kind = KINDS[wagon.name]
  local turret = wagon.surface.create_entity({
    name = elevated and kind.elevated_turret or rigging.sink_name(kind.turret, sink),
    position = position,
    force = wagon.force,
    quality = wagon.quality,
    create_build_effect_smoke = false,
  })
  turret.destructible = false
  return turret
end

-- Replaces turret i by another variant (elevated, or another sink step), keeping its ammo and aim.
local function swap(rig, i, elevated, sink)
  local old = rig.turrets[i]
  local new = create_turret(rig.wagon, elevated, sink, old.position)
  if KINDS[rig.kind].fluid then
    for name, amount in pairs(old.get_fluid_contents()) do
      new.insert_fluid({ name = name, amount = amount })
    end
  else
    local from = old.get_inventory(defines.inventory.turret_ammo)
    local to = new.get_inventory(defines.inventory.turret_ammo)
    for s = 1, #from do
      if from[s].valid_for_read then to.insert(from[s]) end
    end
  end
  new.orientation = old.orientation
  old.destroy()
  rig.turrets[i] = new
  rig.sinks[i] = sink
  return new
end

local function intact(rig)
  for _, turret in pairs(rig.turrets) do
    if not turret.valid then return false end
  end
  return true
end

-- Moves the turrets onto the wagon. With predict, they are put one tick ahead:
-- on_tick runs before the train moves, so this is where the wagon is drawn.
-- Returns false if a turret went missing (removed by another mod).
local function place(rig, predict)
  local wagon = rig.wagon
  if not intact(rig) then return false end
  local kind = KINDS[rig.kind]
  local pos, elevated = anchor(wagon)
  rig.sinks = rig.sinks or {}
  -- the wagon is sorted by its position, which can lie south of where it is drawn
  local below = math.max(0, wagon.position.y - pos.y)
  local x, y = pos.x, pos.y
  local last = rig.last
  if predict and last then
    x, y = x + x - last.x, y + y - last.y
  end
  rig.last = predict and pos or nil
  local a = wagon.orientation * 2 * math.pi
  -- The mounts follow the drawn (foreshortened) roof, not the world.
  local ax, ay = math.sin(a), -math.cos(a) * FORESHORTEN
  for i, turret in pairs(rig.turrets) do
    local offset = kind.mounts[i]
    local ty = y + ay * offset
    local sink = 0
    if not elevated then
      -- a turret north of the wagon centre sinks south until it is drawn after the wagon
      sink = math.min(kind.sink_steps, math.max(0, math.ceil((below - ay * offset) / rigging.SINK_STEP - 1e-6)))
      ty = ty + rigging.sink(sink)
    end
    if elevated ~= rig.elevated or sink ~= (rig.sinks[i] or 0) then turret = swap(rig, i, elevated, sink) end
    if not turret.teleport({ x + ax * offset, ty }) then return false end
  end
  rig.elevated = elevated
  return true
end

local function destroy_rig(id)
  local rig = storage.rigs[id]
  if not rig then return end
  for _, turret in pairs(rig.turrets) do
    if turret.valid then turret.destroy() end
  end
  storage.rigs[id] = nil
end

local update_tick_handler -- defined below, needs on_tick

-- (Re)creates all turrets of a rig, e.g. when another mod removed one.
local function repair(rig)
  for _, turret in pairs(rig.turrets) do
    if turret.valid then turret.destroy() end
  end
  local pos, elevated = anchor(rig.wagon)
  rig.elevated = elevated
  rig.sinks = {}
  rig.last = nil
  for i in pairs(KINDS[rig.kind].mounts) do
    rig.turrets[i] = create_turret(rig.wagon, elevated, 0, pos)
  end
  place(rig)
end

local function create_rig(wagon)
  local id = wagon.unit_number
  if storage.rigs[id] then return storage.rigs[id] end
  local rig = { wagon = wagon, kind = wagon.name, turrets = {} }
  repair(rig)
  storage.rigs[id] = rig
  script.register_on_object_destroyed(wagon)
  update_tick_handler()
  return rig
end

-- Ammo / fluid supply -------------------------------------------------------

local turret_accepts = {} -- [wagon name][item name or fluid name] = true, filled lazily

local function accepted(kind)
  if turret_accepts[kind.name] then return turret_accepts[kind.name] end
  local accepts = {}
  turret_accepts[kind.name] = accepts
  local params = prototypes.entity[kind.turret].attack_parameters
  if kind.fluid then
    for _, f in pairs(params.fluids or {}) do
      local name = type(f.type) == "string" and f.type or f.type.name
      accepts[name] = true
    end
  else
    local categories = {}
    for _, c in pairs(params.ammo_categories or {}) do
      categories[c] = true
    end
    for name, item in pairs(prototypes.get_item_filtered({ { filter = "type", type = "ammo" } })) do
      local category = item.ammo_category
      if category and categories[category.name] then accepts[name] = true end
    end
  end
  return accepts
end

local function refill_ammo(rig, kind)
  local cargo = rig.wagon.get_inventory(defines.inventory.cargo_wagon)
  if not cargo or cargo.is_empty() then return end
  local accepts = accepted(kind)
  for _, turret in pairs(rig.turrets) do
    local ammo = turret.get_inventory(defines.inventory.turret_ammo)
    local need = kind.refill - ammo.get_item_count()
    if need > 0 then
      local loaded = ammo[1].valid_for_read and ammo[1]
      for _, stack in pairs(cargo.get_contents()) do
        if
          accepts[stack.name] and (not loaded or (loaded.name == stack.name and loaded.quality.name == stack.quality))
        then
          local moved = ammo.insert({ name = stack.name, quality = stack.quality, count = math.min(need, stack.count) })
          if moved > 0 then
            cargo.remove({ name = stack.name, quality = stack.quality, count = moved })
            need = need - moved
            if need <= 0 then break end
          end
        end
      end
    end
  end
end

local function refill_fluid(rig, kind)
  local wagon = rig.wagon
  local fluid = wagon.get_fluid(1)
  if not fluid or not accepted(kind)[fluid.name] then return end
  for _, turret in pairs(rig.turrets) do
    if fluid.amount <= 0 then return end
    -- the turret holds fluid in its fluidbox and in an internal buffer
    local need = kind.refill - (turret.get_fluid_contents()[fluid.name] or 0)
    if need > 1 then
      local moved = turret.insert_fluid({
        name = fluid.name,
        amount = math.min(need, fluid.amount),
        temperature = fluid.temperature,
      })
      if moved > 0 then
        wagon.remove_fluid(1, moved)
        fluid.amount = fluid.amount - moved
      end
    end
  end
end

local function refill(rig)
  local kind = KINDS[rig.kind]
  if kind.fluid then
    refill_fluid(rig, kind)
  else
    refill_ammo(rig, kind)
  end
end

-- Events ---------------------------------------------------------------------

local function on_tick()
  for id, rig in pairs(storage.rigs) do
    local wagon = rig.wagon
    if wagon.valid then
      local ok = true
      if wagon.speed ~= 0 then
        ok = place(rig, true)
      elseif rig.last then
        -- one more update after the train stopped, so the turrets end up exactly on the wagon
        ok = place(rig, false)
      end
      if not ok then repair(rig) end
    else
      destroy_rig(id)
    end
  end
end

update_tick_handler = function() script.on_event(defines.events.on_tick, next(storage.rigs) and on_tick or nil) end

local function on_refill()
  for id, rig in pairs(storage.rigs) do
    if not rig.wagon.valid then
      destroy_rig(id)
    elseif not intact(rig) then
      repair(rig)
    else
      refill(rig)
    end
  end
end

local function on_built(event)
  local wagon = event.entity or event.destination
  if wagon and wagon.valid and KINDS[wagon.name] then create_rig(wagon) end
end

-- Mined wagons give back the ammo that sat in their turrets.
local function on_mined(event)
  local wagon = event.entity
  local rig = storage.rigs[wagon.unit_number]
  if not rig then return end
  if event.buffer and not KINDS[rig.kind].fluid then
    for _, turret in pairs(rig.turrets) do
      local ammo = turret.get_inventory(defines.inventory.turret_ammo)
      for i = 1, #ammo do
        if ammo[i].valid_for_read then event.buffer.insert(ammo[i]) end
      end
    end
  end
  destroy_rig(wagon.unit_number)
  update_tick_handler()
end

local function on_destroyed(event)
  if event.type == defines.target_type.entity and storage.rigs[event.useful_id] then
    destroy_rig(event.useful_id)
    update_tick_handler()
  end
end

-- Armour plates. Equipment cannot give a vehicle resistances, so the plates' share
-- is healed back right after a hit. A hit asks the grid only for the plates that
-- resist its damage type; there is nothing to keep track of when plates come and go.

-- PLATES[damage type] = { { name, flat, factor }, ... }
local PLATES = {}
for _, plate in pairs(config.plates) do
  for damage_type, r in pairs(plate.resistances) do
    PLATES[damage_type] = PLATES[damage_type] or {}
    table.insert(PLATES[damage_type], { name = plate.name, flat = r[1], factor = 1 - r[2] / 100 })
  end
end
local FLOOR = 1 - config.armor_cap / 100

-- Factorio's resistance formula: flat first, then percent; a hit never does nothing.
local function resist(damage, flat, factor)
  if damage > flat then return (damage - flat) * factor end
  return factor / (2 + flat - damage)
end

local function on_damaged(event)
  local plates = PLATES[event.damage_type.name]
  local wagon = event.entity
  if not plates or not wagon.valid then return end
  local grid = wagon.grid
  if not grid then return end
  local flat, factor = 0, 1
  for _, plate in pairs(plates) do
    local n = grid.count(plate.name)
    if n > 0 then
      flat = flat + n * plate.flat
      factor = factor * plate.factor ^ n
    end
  end
  if flat == 0 and factor == 1 then return end
  local damage = event.final_damage_amount
  local heal = damage - resist(damage, flat, math.max(factor, FLOOR))
  if heal > 0 then wagon.health = event.final_health + heal end
end

-- Rebuilds the bookkeeping from the map: rigs for every wagon, no orphaned turrets.
local function rebuild()
  storage.rigs = storage.rigs or {}
  for id, rig in pairs(storage.rigs) do
    local kind = KINDS[rig.kind]
    local complete = rig.wagon.valid and kind and #rig.turrets == #kind.mounts
    for _, turret in pairs(rig.turrets) do
      complete = complete and turret.valid
    end
    if not complete then destroy_rig(id) end
  end
  local known = {}
  for _, rig in pairs(storage.rigs) do
    for _, turret in pairs(rig.turrets) do
      known[turret.unit_number] = true
    end
  end
  -- an empty name list would match every entity
  local surfaces = next(WAGON_NAMES) and game.surfaces or {}
  for _, surface in pairs(surfaces) do
    for _, turret in pairs(surface.find_entities_filtered({ name = TURRET_NAMES })) do
      if not known[turret.unit_number] then turret.destroy() end
    end
    for _, wagon in pairs(surface.find_entities_filtered({ name = WAGON_NAMES })) do
      local rig = storage.rigs[wagon.unit_number]
      if rig then
        place(rig)
      else
        create_rig(wagon)
      end
    end
  end
  update_tick_handler()
end

-- With every wagon switched off there is nothing to listen for (an empty filter would match everything).
if next(WAGON_NAMES) then
  local filter = {}
  for _, name in pairs(WAGON_NAMES) do
    filter[#filter + 1] = { filter = "name", name = name }
  end
  for _, e in pairs({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
    defines.events.on_entity_cloned,
  }) do
    script.on_event(e, on_built, filter)
  end
  for _, e in pairs({
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_space_platform_mined_entity,
    defines.events.script_raised_destroy,
  }) do
    script.on_event(e, on_mined, filter)
  end
  script.on_event(defines.events.on_entity_damaged, on_damaged, filter)
end
script.on_event(defines.events.on_object_destroyed, on_destroyed)
script.on_nth_tick(REFILL_INTERVAL, on_refill)

script.on_init(rebuild)
script.on_configuration_changed(rebuild)
script.on_load(function()
  if next(storage.rigs) then script.on_event(defines.events.on_tick, on_tick) end
end)

remote.add_interface("military-wagons", {
  -- for tests: the turrets riding on a wagon
  turrets = function(wagon) return storage.rigs[wagon.unit_number] and storage.rigs[wagon.unit_number].turrets end,
  -- for tests: how far south of its mount a turret sits so it is drawn after the wagon
  sink = function(turret)
    local k = turret.name:match("%-sink%-(%d+)$")
    return not turret.name:match("%-elevated$") and rigging.sink(tonumber(k) or 0) or 0
  end,
})
