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

-- KINDS[wagon name] = Kind, only the turret wagons switched on in the startup settings
local KINDS = {}
local WAGON_NAMES = {}
-- every turret prototype of every kind, to find orphans
local TURRET_NAMES = {}
-- every wagon switched on, also those without roof turrets (they get armour too)
local ARMORED_NAMES = {}
local ARMORED = {}
for _, kind in pairs(config.enabled()) do
  ARMORED_NAMES[#ARMORED_NAMES + 1] = kind.name
  ARMORED[kind.name] = true
  if #kind.mounts > 0 then
    kind.sink_steps = rigging.sink_steps(kind.mounts)
    KINDS[kind.name] = kind
    WAGON_NAMES[#WAGON_NAMES + 1] = kind.name
    for _, range in pairs(kind.min_ranges or { false }) do
      local name = range and rigging.range_name(kind.turret, range, kind.min_ranges) or kind.turret
      TURRET_NAMES[#TURRET_NAMES + 1] = name .. "-elevated"
      for k = 0, kind.sink_steps do
        TURRET_NAMES[#TURRET_NAMES + 1] = rigging.sink_name(name, k)
      end
    end
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
---@field targets table<integer, string>? priority list slot -> entity name
---@field ignore boolean? the turrets shoot only at targets on the priority list
---@field min_range number? chosen minimum range, nil = the turret's own

-- storage.rigs[wagon unit number] = Rig

-- Where the turrets are mounted: the wagon's drawn position. It is lifted on elevated
-- rails and lies south of the wagon's position when the wagon runs north-south.
local function anchor(wagon)
  local draw = wagon.draw_data
  return draw.position, ELEVATED_RAILS and draw.height > 1.5
end

-- The rig's turret prototype before the elevated or sink variant is picked.
local function turret_name(rig)
  local kind = KINDS[rig.kind]
  if not (kind.min_ranges and rig.min_range) then return kind.turret end
  return rigging.range_name(kind.turret, rig.min_range, kind.min_ranges)
end

-- Gives a turret the target priorities the player set on the wagon.
local function apply_targets(rig, turret)
  for slot = 1, config.priority_slots do
    turret.set_priority_target(slot, rig.targets and rig.targets[slot] or nil)
  end
  turret.ignore_unprioritised_targets = rig.ignore or false
end

local function create_turret(rig, elevated, sink, position)
  local wagon = rig.wagon
  local name = turret_name(rig)
  local turret = wagon.surface.create_entity({
    name = elevated and name .. "-elevated" or rigging.sink_name(name, sink),
    position = position,
    force = wagon.force,
    quality = wagon.quality,
    create_build_effect_smoke = false,
  })
  turret.destructible = false
  if rig.targets or rig.ignore then apply_targets(rig, turret) end
  return turret
end

-- Replaces turret i by another variant (elevated, or another sink step), keeping its ammo and aim.
local function swap(rig, i, elevated, sink)
  local old = rig.turrets[i]
  local new = create_turret(rig, elevated, sink, old.position)
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
    rig.turrets[i] = create_turret(rig, elevated, 0, pos)
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

-- [wagon name][item or fluid name in the wagon] = the item or fluid the turret takes for it, filled lazily
local turret_accepts = {}

local function accepted(kind)
  if turret_accepts[kind.name] then return turret_accepts[kind.name] end
  local accepts = {}
  turret_accepts[kind.name] = accepts
  local params = prototypes.entity[kind.turret].attack_parameters
  if kind.fluid then
    for _, f in pairs(params.fluids or {}) do
      local name = type(f.type) == "string" and f.type or f.type.name
      accepts[name] = name
    end
  else
    local categories = {}
    for _, c in pairs(params.ammo_categories or {}) do
      categories[c] = true
    end
    for name, item in pairs(prototypes.get_item_filtered({ { filter = "type", type = "ammo" } })) do
      local category = item.ammo_category
      if category and categories[category.name] then
        -- a shell copy is loaded from the original in the cargo
        local original = category.name == config.shell_category and name:sub(#config.shell_prefix + 1)
        accepts[original and prototypes.item[original] and original or name] = name
      end
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
        local load = accepts[stack.name]
        if load and (not loaded or (loaded.name == load and loaded.quality.name == stack.quality)) then
          local moved = ammo.insert({ name = load, quality = stack.quality, count = math.min(need, stack.count) })
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

-- The original of a shell copy, or the item itself.
local function original_item(name)
  if name:sub(1, #config.shell_prefix) ~= config.shell_prefix then return name end
  local original = name:sub(#config.shell_prefix + 1)
  return prototypes.item[original] and original or name
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
        local stack = ammo[i]
        if stack.valid_for_read then
          local original = original_item(stack.name)
          event.buffer.insert(
            original == stack.name and stack or { name = original, quality = stack.quality, count = stack.count }
          )
        end
      end
    end
  end
  destroy_rig(wagon.unit_number)
  update_tick_handler()
end

local function on_destroyed(event)
  if event.type == defines.target_type.entity then storage.health[event.useful_id] = nil end
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
  -- the tungsten plates exist only with Space Age
  for damage_type, r in pairs(prototypes.equipment[plate.name] and plate.resistances or {}) do
    PLATES[damage_type] = PLATES[damage_type] or {}
    table.insert(PLATES[damage_type], { name = plate.name, flat = r[1], factor = 1 - r[2] / 100 })
  end
end
local FLOOR = 1 - config.armor_cap / 100

-- What the plates in a grid add against a damage type: flat decrease and the share of
-- the damage that is left (capped).
local function plating(grid, damage_type)
  local flat, factor = 0, 1
  for _, plate in pairs(PLATES[damage_type] or {}) do
    local n = grid.count(plate.name)
    if n > 0 then
      flat = flat + n * plate.flat
      factor = factor * plate.factor ^ n
    end
  end
  return flat, math.max(factor, FLOOR)
end

-- Factorio's resistance formula: flat first, then percent; a hit never does nothing.
local function resist(damage, flat, factor)
  if damage > flat then return (damage - flat) * factor end
  return factor / (2 + flat - damage)
end

-- storage.health[wagon unit number] = health after the last hit. A lethal hit leaves the
-- wagon at 0 health without saying how much it had, so that comes from here. Repairs
-- since then only make it an underestimate: then the plates save a little less.

local function on_damaged(event)
  local wagon = event.entity
  if not wagon.valid then return end
  local id = wagon.unit_number
  local before = storage.health[id]
  if not before then script.register_on_object_destroyed(wagon) end
  storage.health[id] = event.final_health
  local grid = wagon.grid
  if not grid then return end
  local flat, factor = plating(grid, event.damage_type.name)
  if flat == 0 and factor == 1 then return end
  local damage = event.final_damage_amount
  local armored = resist(damage, flat, factor)
  local health = event.final_health + damage - armored
  if event.final_health <= 0 then
    -- killed: what it had before the hit, as far as known, minus the armoured damage
    health = math.min(before or wagon.max_health, damage) - armored
  end
  if health > 0 then
    wagon.health = health
    storage.health[id] = wagon.health
  end
end

-- Wagon settings -------------------------------------------------------------
-- A panel beside the wagon window: what its armour plates do, target priorities for
-- turret wagons, and the minimum range on wagons that have a choice. While it is open, the player (and only
-- that player) sees the turrets' minimum and maximum range around the wagon.

local PANEL = "military-wagons-panel"
-- entity types a priority list can name
local TARGET_TYPES = {
  ["unit"] = true,
  ["unit-spawner"] = true,
  ["turret"] = true,
  ["spider-unit"] = true,
  ["segmented-unit"] = true,
  ["asteroid"] = true,
}
local target_filter -- filled on first use, prototypes are not readable while loading

local function target_names()
  if not target_filter then
    local names = {}
    for name, prototype in pairs(prototypes.entity) do
      if TARGET_TYPES[prototype.type] and not prototype.hidden then names[#names + 1] = name end
    end
    target_filter = { { filter = "name", name = names } }
  end
  return target_filter
end

local function set_targets(rig)
  for _, turret in pairs(rig.turrets) do
    if turret.valid then apply_targets(rig, turret) end
  end
end

local function set_min_range(rig, range)
  local kind = KINDS[rig.kind]
  rig.min_range = range ~= kind.min_ranges[1] and range or nil
  if not intact(rig) then return end
  for i in pairs(rig.turrets) do
    swap(rig, i, rig.elevated, rig.sinks and rig.sinks[i] or 0)
  end
end

local function max_range(rig) return prototypes.entity[KINDS[rig.kind].turret].attack_parameters.range end

local function close_panel(player)
  local open = storage.panels[player.index]
  if open then
    for _, circle in pairs(open.circles) do
      if circle.valid then circle.destroy() end
    end
  end
  storage.panels[player.index] = nil
  if player.gui.relative[PANEL] then player.gui.relative[PANEL].destroy() end
end

-- the damage types the plates cover, in the order the panel lists them
local ARMOR_TYPES = { "physical", "explosion", "acid", "fire" }

-- Fills a flow with one line per damage type the wagon's plates protect against.
local function show_armor(flow, wagon)
  flow.clear()
  local any = false
  -- decimal comma where the player's language uses one
  local locale = game.get_player(flow.player_index).locale
  local comma = locale == "de" or locale == "fr" or locale == "es-ES" or locale == "it" or locale == "nl" or locale == "pl"
  for _, damage_type in pairs(ARMOR_TYPES) do
    local flat, factor = plating(wagon.grid, damage_type)
    if flat > 0 or factor < 1 then
      any = true
      flow.add({
        type = "label",
        caption = {
          "military-wagons.armor-line",
          { "damage-type-name." .. damage_type },
          comma and (string.format("%g", flat):gsub("%.", ",")) or string.format("%g", flat),
          string.format("%d", math.floor((1 - factor) * 100 + 0.5)),
        },
      })
    end
  end
  if not any then flow.add({ type = "label", caption = { "military-wagons.no-armor" } }) end
end

-- rig is nil for wagons without roof turrets: then the panel only shows the armour
local function open_panel(player, wagon, rig)
  close_panel(player)
  local kind = rig and KINDS[rig.kind]
  local frame = player.gui.relative.add({
    type = "frame",
    name = PANEL,
    caption = { "military-wagons.panel" },
    direction = "vertical",
    anchor = {
      -- a cargo wagon's window is a container window
      gui = defines.relative_gui_type.container_gui,
      position = defines.relative_gui_position.right,
      names = ARMORED_NAMES,
    },
  })
  local inner = frame.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  inner.add({ type = "label", caption = { "military-wagons.armor" }, style = "caption_label" })
  local open = { wagon = wagon, circles = {}, armor = inner.add({ type = "flow", direction = "vertical" }) }
  show_armor(open.armor, wagon)
  storage.panels[player.index] = open
  if not rig then return end
  inner.add({ type = "line" })
  inner.add({ type = "label", caption = { "military-wagons.targets" }, style = "caption_label" })
  local slots = inner.add({ type = "table", column_count = 4 })
  for slot = 1, config.priority_slots do
    slots.add({
      type = "choose-elem-button",
      elem_type = "entity",
      entity = rig.targets and rig.targets[slot],
      elem_filters = target_names(),
      tags = { military_wagons = "target", slot = slot },
    })
  end
  inner.add({
    type = "checkbox",
    caption = { "military-wagons.ignore" },
    state = rig.ignore or false,
    tags = { military_wagons = "ignore" },
  })
  if kind.min_ranges then
    local ranges = kind.min_ranges
    local range = rig.min_range or ranges[1]
    inner.add({ type = "line" })
    local row = inner.add({ type = "flow", direction = "horizontal" })
    row.style.vertical_align = "center"
    row.add({ type = "label", caption = { "military-wagons.min-range" } })
    row.add({
      type = "slider",
      minimum_value = ranges[1],
      maximum_value = ranges[#ranges],
      value = range,
      value_step = ranges[2] - ranges[1],
      discrete_values = true,
      tags = { military_wagons = "min-range" },
    })
    open.label = row.add({ type = "label", caption = tostring(range) })
    for _, radius in pairs({ range, max_range(rig) }) do
      open.circles[#open.circles + 1] = rendering.draw_circle({
        color = { 0.6, 0.15, 0.1, 0.5 },
        radius = radius,
        width = 3,
        filled = false,
        target = rig.wagon,
        surface = rig.wagon.surface,
        players = { player },
        draw_on_ground = true,
      })
    end
  end
end

-- The rig a player's panel belongs to, if the wagon is still there.
local function panel_rig(event)
  local element = event.element
  if not (element and element.valid and element.tags.military_wagons) then return end
  local open = storage.panels[event.player_index]
  if not (open and open.wagon.valid) then return end
  return storage.rigs[open.wagon.unit_number], element, open
end

local function on_gui_opened(event)
  local wagon = event.entity
  if not (wagon and wagon.valid and ARMORED[wagon.name]) then return end
  local rig = KINDS[wagon.name] and (storage.rigs[wagon.unit_number] or create_rig(wagon))
  open_panel(game.get_player(event.player_index), wagon, rig)
end

local function on_gui_closed(event)
  local wagon = event.entity
  if wagon and wagon.valid and ARMORED[wagon.name] then close_panel(game.get_player(event.player_index)) end
end

-- Plates built in or taken out while the wagon window is open.
local function on_equipment_changed(event)
  local open = storage.panels[event.player_index]
  if open and open.wagon.valid and open.armor.valid and open.wagon.grid == event.grid then
    show_armor(open.armor, open.wagon)
  end
end

local function on_elem_changed(event)
  local rig, element = panel_rig(event)
  if not (rig and element.tags.military_wagons == "target") then return end
  rig.targets = rig.targets or {}
  rig.targets[element.tags.slot] = element.elem_value
  set_targets(rig)
end

local function on_checked(event)
  local rig, element = panel_rig(event)
  if not (rig and element.tags.military_wagons == "ignore") then return end
  rig.ignore = element.state or nil
  set_targets(rig)
end

local function on_value_changed(event)
  local rig, element, open = panel_rig(event)
  if not (rig and element.tags.military_wagons == "min-range") then return end
  local range = element.slider_value
  if range == (rig.min_range or KINDS[rig.kind].min_ranges[1]) then return end
  set_min_range(rig, range)
  open.label.caption = tostring(range)
  if open.circles[1].valid then open.circles[1].radius = range end
end

-- Copy and paste of entity settings between wagons of the same kind.
local function on_settings_pasted(event)
  local from, to = event.source, event.destination
  if not (KINDS[from.name] and from.name == to.name) then return end
  local source, target = storage.rigs[from.unit_number], storage.rigs[to.unit_number]
  if not (source and target) then return end
  target.targets = source.targets and table.deepcopy(source.targets)
  target.ignore = source.ignore
  set_targets(target)
  if KINDS[to.name].min_ranges then set_min_range(target, source.min_range or KINDS[to.name].min_ranges[1]) end
end

-- Rebuilds the bookkeeping from the map: rigs for every wagon, no orphaned turrets.
local function rebuild()
  storage.rigs = storage.rigs or {}
  storage.panels = storage.panels or {}
  storage.health = storage.health or {}
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
  script.on_event(defines.events.on_gui_elem_changed, on_elem_changed)
  script.on_event(defines.events.on_gui_checked_state_changed, on_checked)
  script.on_event(defines.events.on_gui_value_changed, on_value_changed)
  script.on_event(defines.events.on_entity_settings_pasted, on_settings_pasted)
end
if next(ARMORED_NAMES) then
  local filter = {}
  for _, name in pairs(ARMORED_NAMES) do
    filter[#filter + 1] = { filter = "name", name = name }
  end
  script.on_event(defines.events.on_entity_damaged, on_damaged, filter)
  script.on_event(defines.events.on_gui_opened, on_gui_opened)
  script.on_event(defines.events.on_gui_closed, on_gui_closed)
  script.on_event(defines.events.on_player_placed_equipment, on_equipment_changed)
  script.on_event(defines.events.on_player_removed_equipment, on_equipment_changed)
end
script.on_event(defines.events.on_object_destroyed, on_destroyed)
script.on_nth_tick(REFILL_INTERVAL, on_refill)

script.on_init(rebuild)
script.on_configuration_changed(rebuild)
script.on_load(function()
  if next(storage.rigs) then script.on_event(defines.events.on_tick, on_tick) end
end)

remote.add_interface("military-wagons", {
  -- what the wagon panel sets: { targets = { entity names }, ignore = bool, min_range = number }
  configure = function(wagon, settings)
    local rig = storage.rigs[wagon.unit_number]
    if not rig then return end
    if settings.targets then
      rig.targets = settings.targets
      rig.ignore = settings.ignore or nil
      set_targets(rig)
    end
    if settings.min_range and KINDS[rig.kind].min_ranges then set_min_range(rig, settings.min_range) end
  end,
  -- for tests: the turrets riding on a wagon
  turrets = function(wagon) return storage.rigs[wagon.unit_number] and storage.rigs[wagon.unit_number].turrets end,
  -- for tests: how far south of its mount a turret sits so it is drawn after the wagon
  sink = function(turret)
    local k = turret.name:match("%-sink%-(%d+)$")
    return not turret.name:match("%-elevated$") and rigging.sink(tonumber(k) or 0) or 0
  end,
})
