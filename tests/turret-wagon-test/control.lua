-- Headless test scene for the turret wagon mods, run via tests/run.py (factorio --benchmark).
-- Works for whichever of the three mods is active. Every check logs
-- "WAGONTEST PASS ..." or "WAGONTEST FAIL ...", the end "WAGONTEST DONE".

local SPECS = {
  ["gun-turret-wagon"] = { mounts = 3, refill = 10, ammo = "firearm-magazine", amount = 50, distance = 12 },
  ["flamethrower-turret-wagon"] = { mounts = 2, refill = 100, fluid = "light-oil", amount = 1000, distance = 12 },
  -- rockets have a minimum range: their targets keep their distance
  ["rocket-turret-wagon"] = { mounts = 2, refill = 10, ammo = "rocket", amount = 50, distance = 22, hold = true },
  ["twin-cannon-wagon"] = { mounts = 2, refill = 10, ammo = "cannon-shell", amount = 50, distance = 14 },
  -- the howitzer has a minimum range of 12
  -- it turns slowly and fires at half the tank's rate: passing at speed it gets most, not all
  ["howitzer-wagon"] = {
    mounts = 1,
    refill = 10,
    ammo = "cannon-shell",
    amount = 50,
    distance = 22,
    hold = true,
    track_misses = 2,
  },
}
-- tests/run.py writes wagon.lua: the wagon under test
local MOD = require("wagon")
local SPEC = SPECS[MOD]
local TURRET = MOD .. "-turret"

local function report(ok, what, detail)
  log(string.format("WAGONTEST %s %s%s", ok and "PASS" or "FAIL", what, detail and (" (" .. detail .. ")") or ""))
end

local function rail_line(surface, vertical, fixed, from, to)
  for c = from, to, 2 do
    surface.create_entity({
      name = "straight-rail",
      position = vertical and { fixed, c } or { c, fixed },
      direction = vertical and defines.direction.north or defines.direction.east,
      force = "player",
    })
  end
end

-- A closed loop: a straight going north at x from y1 to y0, a right U-turn, the same
-- straight back south and a second U-turn onto the start. Built with the rail planner's
-- own extensions, always the tightest right turn. Returns the number of rails and a rail
-- in the middle of the far straight, or nil if the loop does not close.
local function rail_loop(surface, x, y0, y1)
  rail_line(surface, true, x, y0 + 1, y1 - 1)
  local first = surface.find_entities_filtered({ name = "straight-rail", position = { x, y0 + 1 } })[1]
  local start = first.get_rail_end(defines.rail_direction.front)
  if start.location.direction ~= defines.direction.north then
    start = first.get_rail_end(defines.rail_direction.back)
  end
  local stop = surface.find_entities_filtered({ name = "straight-rail", position = { x, y1 - 1 } })[1]
  local rails = (y1 - y0) / 2
  local head = start.make_copy()
  local function extend(direction)
    for _, ext in pairs(head.get_rail_extensions("rail")) do
      if ext.goal.direction == direction then
        local rail = surface.create_entity({
          name = ext.name,
          position = ext.position,
          direction = ext.direction,
          force = "player",
        })
        if not rail then return false end
        rails = rails + 1
        return head.move_natural()
      end
    end
    return false
  end
  local function u_turn()
    local target = (head.location.direction + 8) % 16
    while head.location.direction ~= target do
      if not extend((head.location.direction + 1) % 16) then return false end
    end
    return true
  end
  if not u_turn() then return nil end
  local far
  for k = 1, (y1 - y0) / 2 do
    if not extend(head.location.direction) then return nil end
    if k == (y1 - y0) / 4 then far = head.rail end
  end
  if not u_turn() then return nil end
  -- the last rail of the second U-turn must meet the start rail's south end
  if not head.move_natural() or head.rail ~= stop then return nil end
  return rails, far
end

-- Locomotive plus turret wagon, both facing east (or north).
local function train(surface, vertical, fixed, wagon_at, quality)
  local dir = vertical and defines.direction.north or defines.direction.east
  local loco_at = vertical and wagon_at - 7 or wagon_at + 7
  local loco = surface.create_entity({
    name = "locomotive",
    force = "player",
    direction = dir,
    position = vertical and { fixed, loco_at } or { loco_at, fixed },
  })
  local wagon = surface.create_entity({
    name = MOD,
    force = "player",
    direction = dir,
    raise_built = true,
    quality = quality,
    position = vertical and { fixed, wagon_at } or { wagon_at, fixed },
  })
  loco.train.manual_mode = true
  return wagon, loco
end

local function fill(wagon, amount)
  if SPEC.fluid then
    wagon.insert_fluid({ name = SPEC.fluid, amount = amount or SPEC.amount })
  else
    wagon.insert({ name = SPEC.ammo, count = amount or SPEC.amount })
  end
end

local function turrets(wagon) return remote.call("military-wagons", "turrets", wagon) or {} end

local function load_of(entity)
  if SPEC.fluid then return entity.get_fluid_contents()[SPEC.fluid] or 0 end
  local inv = entity.get_inventory(
    entity.type == "cargo-wagon" and defines.inventory.cargo_wagon or defines.inventory.turret_ammo
  )
  -- cannon turrets hold the mod's copy of the shell, which passes its own side
  local copy = "military-wagons-" .. SPEC.ammo
  return inv.get_item_count(SPEC.ammo) + (prototypes.item[copy] and inv.get_item_count(copy) or 0)
end

-- Where the wagon's drawn front points, as in the mod. Wagons with symmetric mounts follow
-- the orientation. The mine launcher's sprites have back equal to front, so the game draws it
-- turned round (orientation + 0.5) the same; which half it picks follows its choice among
-- 256 directions.
local SYMMETRIC = { ["mine-launcher-wagon"] = false }
local function drawn(wagon)
  local o = wagon.orientation
  if SYMMETRIC[wagon.name] ~= false then return o % 1 end
  return (math.floor(o * 256 + 0.5) % 256 >= 128 and o - 0.5 or o) % 1
end

-- offset: tiles along the wagon axis, or { along, across } with across to the right of the front
local function mount(wagon, offset)
  local along, across = offset, 0
  if type(offset) == "table" then
    along, across = offset[1], offset[2]
  end
  local a = drawn(wagon) * 2 * math.pi
  -- the mod mounts on the drawn wagon and foreshortens north-south offsets like its sprite
  local draw = wagon.draw_data.position
  local f = math.sin(math.rad(50))
  return draw.x + math.sin(a) * along + math.cos(a) * across,
    draw.y - math.cos(a) * along * f + math.sin(a) * across * f
end

-- the mount offsets in config.lua
local MOUNTS = {
  ["gun-turret-wagon"] = { -1.9, 0, 1.9 },
  ["flamethrower-turret-wagon"] = { -1.5, 1.5 },
  ["rocket-turret-wagon"] = { -1.5, 1.5 },
  ["twin-cannon-wagon"] = { -1.6, 1.6 },
  ["howitzer-wagon"] = { 0 },
  ["mine-launcher-wagon"] = {
    { -2.05, -0.47 },
    { -0.95, -0.47 },
    { 0.15, -0.47 },
    { -2.05, 0.47 },
    { -0.95, 0.47 },
    { 0.15, 0.47 },
  },
}
local function mounts() return MOUNTS[MOD] end

-- How far the turrets are from their mounts; positions defaults to where they are now.
local function deviation(wagon, positions)
  local worst = 0
  for i, t in pairs(turrets(wagon)) do
    local x, y = mount(wagon, MOUNTS[wagon.name][i])
    local p = positions and positions[i] or t.position
    -- turrets north of the wagon centre sit further south so they are drawn after the wagon;
    -- a turret swapped for another sink step since positions were taken has its own
    local sink = p.sink or (t.valid and remote.call("military-wagons", "sink", t) or 0)
    worst = math.max(worst, math.abs(p.x - x), math.abs(p.y - sink - y))
  end
  return worst
end

local function positions(wagon)
  local list = {}
  for i, t in pairs(turrets(wagon)) do
    list[i] = { x = t.position.x, y = t.position.y, sink = remote.call("military-wagons", "sink", t) }
  end
  return list
end

local function alive(list)
  local n = 0
  for _, e in pairs(list) do
    if e.valid then n = n + 1 end
  end
  return n
end

local function setup()
  -- wagons switched off in the startup settings must not exist at all
  for name in pairs(SPECS) do
    if not settings.startup["military-wagons-" .. name].value then
      report(
        not prototypes.entity[name] and not prototypes.recipe[name] and not prototypes.technology[name],
        "switched off wagon does not exist",
        name
      )
    end
  end
  -- armour steel: 4 steel, 1 copper, 2 carbon, 20 water, quenched to steam
  local recipe = prototypes.recipe["armor-steel"]
  local amounts = {}
  for _, i in pairs(recipe and recipe.ingredients or {}) do
    amounts[i.name] = i.amount
  end
  report(
    amounts["steel-plate"] == 4 and amounts["copper-plate"] == 1 and amounts["carbon"] == 2 and amounts["water"] == 20,
    "armor steel recipe ingredients",
    serpent.line(amounts)
  )
  local steam = false
  for _, p in pairs(recipe and recipe.products or {}) do
    steam = steam or p.name == "steam"
  end
  report(steam, "armor steel recipe gives off steam")
  local unlocks = {}
  for _, effect in pairs(prototypes.technology["armor-steel"].effects) do
    if effect.type == "unlock-recipe" then unlocks[effect.recipe] = true end
  end
  report(unlocks["armor-steel"], "armor steel technology unlocks the recipe")
  -- carbon comes from Space Age if present, otherwise from our coal recipe
  local own_carbon = prototypes.recipe["military-wagons-carbon"] ~= nil
  report(
    own_carbon ~= (script.active_mods["space-age"] ~= nil)
      and (own_carbon == (unlocks["military-wagons-carbon"] == true)),
    "carbon recipe only without Space Age"
  )
  local surface = game.surfaces.nauvis
  game.map_settings.enemy_expansion.enabled = false
  surface.request_to_generate_chunks({ 0, 0 }, 6)
  surface.force_generate_chunk_requests()
  for _, e in pairs(surface.find_entities_filtered({ force = "enemy" })) do
    e.destroy()
  end
  for _, e in pairs(surface.find_entities_filtered({ area = { { -160, -160 }, { 160, 160 } } })) do
    if e.type ~= "character" then e.destroy() end
  end
  local tiles = {}
  for x = -160, 159 do
    for y = -160, 159 do
      tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)

  local s = { surface = surface }
  storage.scene = s
  storage.start = game.tick

  -- A: standing train, horizontal
  rail_line(surface, false, 1, -61, 61)
  s.a, s.a_loco = train(surface, false, 1, -9)
  report(s.a and s.a.valid, "wagon can be built on rails")
  report(#turrets(s.a) == SPEC.mounts, "wagon gets its turrets", #turrets(s.a) .. " turrets")
  local all_safe = true
  for _, t in pairs(turrets(s.a)) do
    all_safe = all_safe and t.valid and not t.destructible and t.name == TURRET and t.force.name == "player"
  end
  report(all_safe, "turrets are indestructible and belong to the wagon's force")
  report(deviation(s.a) < 0.01, "turrets sit on the wagon axis", string.format("%.3f", deviation(s.a)))
  fill(s.a)

  -- wagon panel: target priorities reach every turret, also turrets made later
  remote.call("military-wagons", "configure", s.a, { targets = { "small-biter", nil, "medium-biter" }, ignore = true })
  local prioritised = true
  for _, t in pairs(turrets(s.a)) do
    local first, third = t.get_priority_target(1), t.get_priority_target(3)
    prioritised = prioritised
      and first
      and first.name == "small-biter"
      and third
      and third.name == "medium-biter"
      and t.ignore_unprioritised_targets
  end
  report(prioritised, "target priorities reach the turrets")
  if MOD == "rocket-turret-wagon" then
    remote.call("military-wagons", "configure", s.a, { min_range = 16 })
    local ranged = true
    for _, t in pairs(turrets(s.a)) do
      ranged = ranged
        and t.prototype.attack_parameters.min_range == 16
        and t.get_priority_target(1) ~= nil
        and t.ignore_unprioritised_targets
    end
    report(ranged, "minimum range can be raised and keeps the priorities", turrets(s.a)[1].name)
    remote.call("military-wagons", "configure", s.a, { min_range = 8 })
    report(turrets(s.a)[1].name == TURRET, "minimum range back to 8 gives the plain turret", turrets(s.a)[1].name)
  end
  remote.call("military-wagons", "configure", s.a, { targets = {} })
  -- reading past the end of the priority list is an error
  report(#turrets(s.a)[1].priority_targets == 0, "target priorities can be cleared")

  -- B: moving train with enemies along the track
  rail_line(surface, false, -81, -151, 151)
  s.b, s.b_loco = train(surface, false, -81, -130)
  fill(s.b)
  s.b_start = s.b.position.x

  -- C: vertical train
  rail_line(surface, true, 101, -61, 61)
  s.c = train(surface, true, 101, 0)
  local cx = turrets(s.c)[1]
  report(
    cx
      and math.abs(cx.position.x - s.c.position.x) < 0.01
      and (mounts()[1] == 0 or math.abs(cx.position.y - s.c.position.y) > 1),
    "turrets follow a vertical wagon",
    string.format("%.3f", deviation(s.c))
  )
  -- the wagon is sorted by its position, so every turret must sit south of it; the
  -- sprites are lifted back by the same amount, so they stay on the drawn roof
  local behind = math.huge
  for _, t in pairs(turrets(s.c)) do
    behind = math.min(behind, t.position.y - s.c.position.y)
  end
  report(
    behind > 0 and deviation(s.c) < 0.01,
    "turrets of a vertical wagon are drawn after the wagon and sit on their mounts",
    string.format("closest %.2f south of the wagon, %.3f off the mounts", behind, deviation(s.c))
  )

  -- D/E: removal paths
  rail_line(surface, false, 61, -61, 61)
  s.d = train(surface, false, 61, -30)
  s.e = train(surface, false, 61, 20)
  s.d_turrets = turrets(s.d)
  s.e_turrets = turrets(s.e)

  -- F: quality wagon gets quality turrets
  if script.active_mods["quality"] then
    rail_line(surface, false, 121, -61, 61)
    s.f = train(surface, false, 121, 0, "rare")
    local t = turrets(s.f)[1]
    report(t and t.quality.name == "rare", "turrets share the wagon's quality", t and t.quality.name)
  end

  -- G: elevated rails
  if prototypes.entity["elevated-straight-rail"] then
    for x = -61, 61, 2 do
      surface.create_entity({
        name = "elevated-straight-rail",
        position = { x, 141 },
        direction = defines.direction.east,
        force = "player",
      })
    end
    s.g = train(surface, false, 141, 0)
    local t = turrets(s.g)[1]
    report(t and t.name == TURRET .. "-elevated", "wagon on a bridge gets elevated turrets", t and t.name)
    local draw = s.g.draw_data.position
    report(
      t and math.abs(t.position.y - draw.y) < 0.01,
      "elevated turrets sit on the drawn wagon",
      t and string.format("turret y %.2f, wagon drawn at %.2f", t.position.y, draw.y)
    )
    fill(s.g)
  end

  -- H: armour plates in the equipment grid
  rail_line(surface, true, -121, -41, 41)
  local h = train(surface, true, -121, 0)
  local grid = h.grid
  report(grid and grid.width == 6 and grid.height == 8, "wagon has a 6x8 equipment grid")
  report(h.max_health == 2000, "wagon has as much health as a tank", tostring(h.max_health))
  report(grid and grid.put({ name = "energy-shield-equipment" }) ~= nil, "grid takes tank equipment")
  -- bare wagon: physical 5 / 30 %, so 100 damage does 66.5
  h.damage(100, "enemy", "physical")
  report(math.abs(h.health - 1933.5) < 0.01, "unplated wagon takes its normal damage", string.format("%.2f", h.health))
  h.health = 2000
  -- four composite plates: physical 4 * 0.5 / 1 - 0.96^4 on top, (66.5 - 2) * 0.96^4
  local plates = {}
  for k = 1, 4 do
    plates[k] = grid and grid.put({ name = "composite-armor-plate" })
  end
  report(plates[4] ~= nil, "grid takes four armour plates")
  h.damage(100, "enemy", "physical")
  report(
    math.abs(h.health - (2000 - 64.5 * 0.96 ^ 4)) < 0.01,
    "armour plates reduce physical damage",
    string.format("%.2f", h.health)
  )
  h.health = 2000
  h.damage(100, "enemy", "explosion")
  report(
    math.abs(h.health - 1937) < 0.01,
    "armour plates leave other damage types alone",
    string.format("%.2f", h.health)
  )
  -- a hit that would destroy the bare wagon but not the plated one
  -- brought down by hits, so the mod knows its health: explosion (2780 - 10) * 0.7 = 1939
  h.health = 2000
  h.damage(2780, "enemy", "explosion")
  h.damage(100, "enemy", "physical")
  report(
    h.valid and math.abs(h.health - (61 - 64.5 * 0.96 ^ 4)) < 0.01,
    "armour plates catch a hit that would be lethal",
    h.valid and string.format("%.2f", h.health) or "destroyed"
  )
  if h.valid then
    h.health = 2000
    for _, plate in pairs(plates) do
      grid.take({ equipment = plate })
    end
    h.damage(100, "enemy", "physical")
    report(math.abs(h.health - 1933.5) < 0.01, "removed plates stop protecting", string.format("%.2f", h.health))
    -- better quality, stronger plate: uncommon is level 1, so 0.65 flat and 5.2 %
    if prototypes.quality["uncommon"] then
      h.health = 2000
      local better = grid.put({ name = "composite-armor-plate", quality = "uncommon" })
      h.damage(100, "enemy", "physical")
      report(
        math.abs(h.health - (2000 - 65.85 * 0.948)) < 0.01,
        "better quality plates protect more",
        string.format("%.2f", h.health)
      )
      grid.take({ equipment = better })
    end
    -- two reactive plates: explosion (63 - 3) * 0.95^2
    h.health = 2000
    grid.put({ name = "reactive-armor-plate" })
    grid.put({ name = "reactive-armor-plate" })
    h.damage(100, "enemy", "explosion")
    report(
      math.abs(h.health - (2000 - 60 * 0.95 ^ 2)) < 0.01,
      "reactive plates reduce explosion damage",
      string.format("%.2f", h.health)
    )
    local tungsten = prototypes.equipment["tungsten-reactive-armor-plate"] ~= nil
    report(tungsten == (script.active_mods["space-age"] ~= nil), "tungsten plates only with Space Age")
  end

  -- the tank's own shells still hit their own side; only the wagon copies pass it
  if prototypes.item["military-wagons-cannon-shell"] then
    report(
      prototypes.item["military-wagons-cannon-shell"].ammo_category.name == "military-wagons-cannon-shell"
        and prototypes.item["cannon-shell"].ammo_category.name == "cannon-shell",
      "cannon wagons fire their own copies of the tank shells"
    )
  end

  -- I: mine launcher, whenever it is switched on: its six baskets throw mine packages only
  -- at its own flares, each basket one every 10 s, so six go out at once and the last two later
  if prototypes.entity["mine-launcher-wagon"] then
    rail_line(surface, true, -141, -41, 41)
    s.mine = surface.create_entity({
      name = "mine-launcher-wagon",
      force = "player",
      direction = defines.direction.north,
      position = { -141, 0 },
      raise_built = true,
    })
    s.mine.get_inventory(defines.inventory.artillery_wagon_ammo).insert({ name = "wagon-mine", count = 8 })
    report(s.mine.grid ~= nil, "mine launcher has an equipment grid")
    local baskets = remote.call("military-wagons", "turrets", s.mine)
    report(baskets and #baskets == 6, "mine launcher has six baskets", baskets and #baskets)
    for k = 0, 7 do
      surface.create_entity({
        name = "mine-launcher-flare",
        position = { -125 + 4 * k, 12 },
        force = "player",
        movement = { 0, 0 },
        height = 0,
        vertical_speed = 0,
        frame_speed = 0,
      })
    end
    -- a plain artillery flare, which the launcher must leave alone
    surface.create_entity({
      name = "artillery-flare",
      position = { -111, -10 },
      force = "player",
      movement = { 0, 0 },
      height = 0,
      vertical_speed = 0,
      frame_speed = 0,
    })
  end

  -- L: loop with curves and diagonals: locomotive, the wagon under test and, when switched on,
  -- a mine launcher drive one lap forwards and one backwards by schedule, stopping halfway and
  -- at the end; flares come all the time, the baskets may fire only while the train stands
  s.l_rails, s.l_far = rail_loop(surface, 111, -40, 40)
  report(s.l_rails ~= nil, "test loop closes", s.l_rails and s.l_rails .. " rails")
  if s.l_rails then
    -- the two mine launchers are more than their 120 tiles apart: neither answers the other one's flares
    s.l_loco = surface.create_entity({
      name = "locomotive",
      force = "player",
      direction = defines.direction.north,
      position = { 111, -20 },
    })
    s.l_loco.get_fuel_inventory().insert({ name = "coal", count = 20 })
    s.l_wagons = {}
    local at = -13
    for _, name in pairs({ MOD, "mine-launcher-wagon" }) do
      if prototypes.entity[name] then
        local wagon = surface.create_entity({
          name = name,
          force = "player",
          direction = defines.direction.north,
          raise_built = true,
          position = { 111, at },
        })
        s.l_wagons[#s.l_wagons + 1] = wagon
        at = at + 7
      end
    end
    s.l_loco.train.manual_mode = true
    report(
      #s.l_loco.train.carriages == 1 + #s.l_wagons,
      "loop train is coupled",
      #s.l_loco.train.carriages .. " carriages"
    )
    s.l_mine = s.l_wagons[2]
    if s.l_mine then
      s.l_mine.get_inventory(defines.inventory.artillery_wagon_ammo).insert({ name = "wagon-mine", count = 20 })
    end
    -- per direction and wagon: worst deviation, with the tick and wagon orientation it happened at
    s.l_worst = { forward = {}, backward = {} }
    s.l_phase = "start"
    s.l_turned = 0
    s.l_fired = {}
    s.l_moving_shots = {}
    s.l_home = surface.find_entities_filtered({ name = "straight-rail", position = { 111, -31 } })[1]
  end

  -- P: a mine launcher whose basket fired holds its train until the baskets are home, then it
  -- leaves by schedule, and fires again once it stands; Q: one with nothing to fire leaves at once
  if prototypes.entity["mine-launcher-wagon"] then
    for _, k in pairs({ "p", "q" }) do
      local y = k == "p" and -121 or -131
      rail_line(surface, false, y, -81, 41)
      local loco = surface.create_entity({
        name = "locomotive",
        force = "player",
        direction = defines.direction.east,
        position = { -33, y },
      })
      loco.get_fuel_inventory().insert({ name = "coal", count = 20 })
      s[k] = surface.create_entity({
        name = "mine-launcher-wagon",
        force = "player",
        direction = defines.direction.east,
        position = { -40, y },
        raise_built = true,
      })
      loco.train.manual_mode = true
      s[k .. "_target"] = surface.find_entities_filtered({ name = "straight-rail", position = { -11, y } })[1]
    end
    s.p.get_inventory(defines.inventory.artillery_wagon_ammo).insert({ name = "wagon-mine", count = 6 })
    s.p_moving_shots = 0

    -- R: a basket still turning towards a flare, not fired yet, when the train is sent off; a
    -- force of its own, so P's baskets leave its flare alone
    rail_line(surface, false, -141, -81, 41)
    s.r_force = game.forces["wagon-lock"] or game.create_force("wagon-lock")
    s.r_force.set_friend("player", true)
    game.forces.player.set_friend(s.r_force, true)
    local r_loco = surface.create_entity({
      name = "locomotive",
      force = s.r_force,
      direction = defines.direction.east,
      position = { -33, -141 },
    })
    r_loco.get_fuel_inventory().insert({ name = "coal", count = 20 })
    s.r = surface.create_entity({
      name = "mine-launcher-wagon",
      force = s.r_force,
      direction = defines.direction.east,
      position = { -40, -141 },
      raise_built = true,
    })
    r_loco.train.manual_mode = true
    s.r_target = surface.find_entities_filtered({ name = "straight-rail", position = { -11, -141 } })[1]
    s.r.get_inventory(defines.inventory.artillery_wagon_ammo).insert({ name = "wagon-mine", count = 6 })

    -- S: a mine launcher facing south (orientation 0.5), drawn like one facing north
    rail_line(surface, true, 81, -41, 41)
    s.south = surface.create_entity({
      name = "mine-launcher-wagon",
      force = "player",
      direction = defines.direction.south,
      position = { 81, 0 },
      raise_built = true,
    })
    report(
      deviation(s.south) < 0.01,
      "baskets of a wagon facing south sit on the drawn mounts",
      string.format("orientation %.2f, %.3f off the mounts", s.south.orientation, deviation(s.south))
    )
  end

  -- an empty wagon must not do anything bad
  rail_line(surface, true, -101, -41, 41)
  s.empty = train(surface, true, -101, 0)

  -- J: cannon wagons with explosive shells spare their own buildings, behind the targets
  -- and where the shells that fly on end (40 tiles out)
  if SPEC.ammo == "cannon-shell" then
    rail_line(surface, false, -150, 111, 149)
    s.j = train(surface, false, -150, 125)
    s.j.insert({ name = "explosive-cannon-shell", count = 20 })
    s.j_own = {}
    local function own(name, x, y)
      s.j_own[#s.j_own + 1] = surface.create_entity({ name = name, position = { x, y }, force = "player" })
    end
    for _, y in pairs({ -150 + SPEC.distance + 4, -113, -110 }) do
      for x = 119, 131, 2 do
        own("wooden-chest", x, y)
        own("stone-wall", x, y + 1)
        own("small-electric-pole", x + 1, y)
      end
    end
  end
end

local function check_loaded()
  local s = storage.scene
  local total, each_full = load_of(s.a), true
  for _, t in pairs(turrets(s.a)) do
    total = total + load_of(t)
    each_full = each_full and load_of(t) >= SPEC.refill - 1
  end
  report(each_full, "turrets are loaded from the wagon")
  report(math.abs(total - SPEC.amount) < 1, "no ammo created or lost", string.format("%.1f of %d", total, SPEC.amount))
  for _, t in pairs(turrets(s.empty)) do
    if load_of(t) ~= 0 then report(false, "empty wagon leaves turrets empty") end
  end
end

local function spawn_enemies()
  local s = storage.scene
  s.a_enemies = {}
  for i = -2, 2 do
    local biter =
      s.surface.create_entity({ name = "small-biter", force = "enemy", position = { -9 + i * 2, 1 + SPEC.distance } })
    if SPEC.hold then
      biter.commandable.set_command({ type = defines.command.stop, ticks_to_wait = 100000 })
    else
      biter.commandable.set_command({ type = defines.command.attack, target = s.a })
    end
    s.a_enemies[#s.a_enemies + 1] = biter
  end
  report(alive(s.a_enemies) == 5, "enemies spawned near the standing train")
  if s.j then
    s.j_enemies = {}
    for x = 119, 131, 4 do
      local biter =
        s.surface.create_entity({ name = "small-biter", force = "enemy", position = { x, -150 + SPEC.distance } })
      biter.commandable.set_command({ type = defines.command.stop, ticks_to_wait = 100000 })
      s.j_enemies[#s.j_enemies + 1] = biter
    end
  end
end

-- as on the straight track
local LOOP_LIMIT = 0.05
local LOOP_FLARE = { 80, -40 }
-- the last tick the test waits for the loop train (tests/run.py runs a few more)
local LOOP_TICKS = 3900
-- R: the tick of the flare behind the wagon, and of sending the train off
local R_FLARE = 400
local R_SEND = 420
-- how long a train may wait for its baskets to turn home
local PARK_LIMIT = 120

local function flare(position, force)
  storage.scene.surface.create_entity({
    name = "mine-launcher-flare",
    position = position,
    force = force or "player",
    movement = { 0, 0 },
    height = 0,
    vertical_speed = 0,
    frame_speed = 0,
  })
end

-- Mine packages a mine launcher has: in the wagon plus in its baskets.
local function packages(wagon)
  local n = wagon.get_inventory(defines.inventory.artillery_wagon_ammo).get_item_count("wagon-mine")
  for _, t in pairs(turrets(wagon)) do
    n = n + t.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("military-wagons-wagon-mine")
  end
  return n
end
local function loop_mines() return packages(storage.scene.l_mine) end

-- Sends a train to a rail by schedule, waiting there for ticks.
local function send(train, rail, ticks)
  local schedule = train.get_schedule()
  schedule.add_record({ rail = rail, temporary = true, wait_conditions = { { type = "time", ticks = ticks } } })
  train.manual_mode = false
  schedule.go_to_station(1)
end

-- How far the basket furthest from home is turned away from the wagon's drawn front (turns).
local function basket_offset(wagon)
  local worst = 0
  for _, t in pairs(turrets(wagon)) do
    local d = (t.relative_turret_orientation - drawn(wagon)) % 1
    worst = math.max(worst, math.min(d, 1 - d))
  end
  return worst
end

-- P and Q: the departure lock of the mine launcher.
local function check_lock(age)
  local s = storage.scene
  if not s.p then return end
  if age == 2 then flare({ -50, -155 }) end
  local n = packages(s.p)
  if s.p_count and n < s.p_count then
    if s.p.speed ~= 0 then s.p_moving_shots = s.p_moving_shots + 1 end
    s.p_last_shot = age
  end
  s.p_count = n
  if age == 150 then
    report(
      s.p_last_shot ~= nil and s.p.relative_turret_orientation ~= 0,
      "a basket that fired locks its standing train",
      string.format(
        "last shot at tick %s, wagon cannon at %.3f, baskets up to %.3f from home",
        tostring(s.p_last_shot),
        s.p.relative_turret_orientation,
        basket_offset(s.p)
      )
    )
    s.q_offset, s.q_lock = basket_offset(s.q), s.q.relative_turret_orientation
    send(s.p.train, s.p_target, 6000)
    send(s.q.train, s.q_target, 6000)
  end
  if age > 150 and not s.p_left and s.p.speed ~= 0 then
    s.p_left = age
    report(
      age - 150 > 1 and age - 150 <= PARK_LIMIT,
      "train waits for its baskets to turn home, then leaves",
      (age - 150) .. " ticks"
    )
    report(
      basket_offset(s.p) <= 0.002,
      "baskets are home when the train leaves",
      string.format("%.4f", basket_offset(s.p))
    )
  end
  if age > 150 and not s.q_left and s.q.speed ~= 0 then
    s.q_left = age
    report(
      age - 150 <= 5,
      "train without turned baskets leaves at once",
      string.format(
        "%d ticks; when sent off its baskets were up to %.3f from home, wagon cannon at %.3f",
        age - 150,
        s.q_offset,
        s.q_lock
      )
    )
  end
  if s.p_left and not s.p_arrived and s.p.train.state == defines.train_state.wait_station then
    s.p_arrived = age
    s.p_shots_before = s.p_last_shot
    flare({ s.p.position.x - 10, -155 })
  end
  if s.p_arrived and not s.p_again and s.p_last_shot ~= s.p_shots_before then s.p_again = age end

  -- R: flare behind the wagon at R_FLARE, sent off R_SEND ticks later
  local r = packages(s.r)
  if s.r_count and r < s.r_count and not s.r_shot then s.r_shot = age end
  s.r_count = r
  if age == R_FLARE then flare({ -100, -141 }, s.r_force) end
  if age == R_SEND then
    s.r_sent_offset = basket_offset(s.r)
    report(
      s.r_sent_offset > 0.002 and not s.r_shot,
      "a basket is still turning, not fired, when its train is sent off",
      string.format("baskets up to %.3f from home, shot at tick %s", s.r_sent_offset, tostring(s.r_shot))
    )
    send(s.r.train, s.r_target, 6000)
  end
  if age > R_SEND and not s.r_left and s.r.speed ~= 0 then
    s.r_left = age
    report(
      basket_offset(s.r) <= 0.002 and age - R_SEND > 1,
      "train with a basket turning waits until all baskets are home",
      string.format("left after %d ticks, baskets %.4f from home", age - R_SEND, basket_offset(s.r))
    )
  end
end

local function report_lock()
  local s = storage.scene
  if not s.p then return end
  if not s.r_left then report(false, "train with a basket turning waits until all baskets are home", "never left") end
  if not s.p_left then report(false, "train waits for its baskets to turn home, then leaves", "never left") end
  if not s.q_left then report(false, "train without turned baskets leaves at once", "never left") end
  report(s.p_moving_shots == 0, "baskets do not fire while their train moves", s.p_moving_shots .. " shots")
  report(
    s.p_again ~= nil,
    "baskets fire again once the train stands",
    s.p_again and (s.p_again - s.p_arrived) .. " ticks after arriving" or "no shot"
  )
end

-- One tick of the loop drive: forwards until the wagon has turned once around, a short
-- stop, then backwards until it has turned back.
local function drive_loop(age)
  local s = storage.scene
  if not s.l_rails or s.l_phase == "done" then return end
  local lead = s.l_wagons[1]
  if not (lead.valid and s.l_loco.valid) then
    s.l_phase = "done"
    return
  end
  -- turrets are placed for the wagon position after this tick's train update,
  -- so compare last tick's turret positions with the wagons now
  -- the first ticks after a start are left out, like on the straight track
  if lead.speed == 0 then
    s.l_started = nil
  elseif not s.l_started then
    s.l_started = age
  end
  if s.l_last and (s.l_phase == "forward" or s.l_phase == "backward") and s.l_started and age > s.l_started + 5 then
    for i, wagon in pairs(s.l_wagons) do
      local d = deviation(wagon, s.l_last[i])
      if d > 0.5 then
        log(
          string.format(
            "WAGONDEBUG loop tick %d %s orientation %.6f last %.6f off %.3f",
            age,
            wagon.name,
            wagon.orientation,
            s.l_last_o and s.l_last_o[i] or -1,
            d
          )
        )
      end
      local worst = s.l_worst[s.l_phase][wagon.name] or { d = 0, off = 0, ticks = 0 }
      s.l_worst[s.l_phase][wagon.name] = worst
      worst.ticks = worst.ticks + 1
      if d >= LOOP_LIMIT then worst.off = worst.off + 1 end
      if d > worst.d then
        worst.d, worst.tick, worst.orientation = d, age, wagon.orientation
      end
    end
  end
  s.l_last = {}
  s.l_last_o = {}
  for i, wagon in pairs(s.l_wagons) do
    s.l_last[i] = positions(wagon)
    s.l_last_o[i] = wagon.orientation
  end
  if s.l_orientation then
    local turn = lead.orientation - s.l_orientation
    if turn > 0.5 then turn = turn - 1 end
    if turn < -0.5 then turn = turn + 1 end
    s.l_turned = s.l_turned + turn
  end
  s.l_orientation = lead.orientation
  local train = s.l_loco.train
  local idle = train.speed == 0 and train.get_schedule().get_record_count() == 0
  if s.l_phase == "start" then
    -- forwards: halfway round to the far straight, then on round to the start
    for _, rail in pairs({ s.l_far, s.l_home }) do
      send(train, rail, 120)
    end
    s.l_phase = "forward"
  elseif s.l_phase == "forward" and idle and age > 10 then
    -- backwards: a locomotive at the other end takes over, the first one leaves
    local last = s.l_wagons[#s.l_wagons]
    local back = s.surface.create_entity({
      name = "locomotive",
      force = "player",
      direction = defines.direction.south,
      position = { last.position.x, last.position.y + 7 },
    })
    if not back then
      log("WAGONDEBUG no room for the second locomotive behind " .. serpent.line(last.position))
      s.l_phase = "done"
      return
    end
    back.get_fuel_inventory().insert({ name = "coal", count = 20 })
    s.l_loco.destroy()
    s.l_loco = back
    for _, rail in pairs({ s.l_far, s.l_home }) do
      send(back.train, rail, 120)
    end
    s.l_phase = "backward"
  elseif s.l_phase == "backward" and idle then
    s.l_phase = "done"
  end
  if s.l_mine then
    -- a flare every 30 ticks keeps the baskets busy; record every package that leaves
    if age % 30 == 0 then flare(LOOP_FLARE) end
    local n = loop_mines()
    for _ = n + 1, s.l_count or n do
      s.l_fired[#s.l_fired + 1] = age
      if s.l_mine.speed ~= 0 then s.l_moving_shots[#s.l_moving_shots + 1] = age end
    end
    s.l_count = n
    -- baskets the mod replaced (another sink step), to tell them apart from shots
    s.l_baskets = s.l_baskets or {}
    s.l_swaps = s.l_swaps or {}
    for i, b in pairs(turrets(s.l_mine)) do
      if s.l_baskets[i] and s.l_baskets[i] ~= b.unit_number then s.l_swaps[#s.l_swaps + 1] = i .. "@" .. age end
      s.l_baskets[i] = b.unit_number
    end
  end
end

local function report_loop()
  local s = storage.scene
  if not s.l_rails then return end
  report(
    s.l_phase == "done",
    "loop train drove a lap forwards and one backwards",
    string.format("phase %s, turned %.2f", s.l_phase, s.l_turned)
  )
  for _, phase in pairs({ "forward", "backward" }) do
    for _, wagon in pairs(s.l_wagons) do
      local worst = s.l_worst[phase][wagon.name]
      report(
        worst and worst.d < LOOP_LIMIT,
        "turrets stay on their mounts around the loop, " .. phase .. " (" .. wagon.name .. ")",
        worst
          and string.format(
            "max %.4f at tick %d, orientation %.3f; %d of %d ticks off by %.2f or more",
            worst.d,
            worst.tick or 0,
            worst.orientation or 0,
            worst.off,
            worst.ticks,
            LOOP_LIMIT
          )
      )
    end
  end
  if s.l_mine then
    -- six baskets, each once every 10 s: never more than six packages within 600 ticks
    local most = 0
    for i, t in pairs(s.l_fired) do
      local n = 0
      for k = i, #s.l_fired do
        if s.l_fired[k] < t + 600 then n = n + 1 end
      end
      most = math.max(most, n)
    end
    log("WAGONDEBUG loop packages fired at " .. serpent.line(s.l_fired))
    log("WAGONDEBUG loop baskets replaced (basket@tick) " .. table.concat(s.l_swaps or {}, " "))
    local spots = {}
    for _, m in pairs(s.surface.find_entities_filtered({ name = "land-mine" })) do
      local k = math.floor(m.position.x / 20) * 20 .. "," .. math.floor(m.position.y / 20) * 20
      spots[k] = (spots[k] or 0) + 1
    end
    log("WAGONDEBUG mines by 20-tile square " .. serpent.line(spots))
    report(#s.l_fired > 0, "loop mine launcher fires at its stops", #s.l_fired .. " packages")
    report(
      #s.l_moving_shots == 0,
      "loop mine launcher does not fire while the train moves",
      #s.l_moving_shots .. " packages" .. (#s.l_moving_shots > 0 and " at " .. serpent.line(s.l_moving_shots) or "")
    )
    report(
      most <= 6,
      "baskets do not fire twice within their cooldown around the loop",
      most .. " packages within 600 ticks"
    )
  end
end

local function spawn_track_enemies()
  local s = storage.scene
  s.b_enemies = {}
  for x = -60, 60, 30 do
    local biter =
      s.surface.create_entity({ name = "small-biter", force = "enemy", position = { x, -81 - SPEC.distance } })
    -- stay put, so the train has to hit them while passing
    biter.commandable.set_command({ type = defines.command.stop, ticks_to_wait = 100000 })
    s.b_enemies[#s.b_enemies + 1] = biter
  end
  s.b_loco.train.speed = 0.35
end

script.on_event(defines.events.on_tick, function()
  if not prototypes.entity[MOD] then
    report(false, "wagon under test is switched off")
    log("WAGONTEST DONE")
    return
  end
  if not storage.scene then
    setup()
    return
  end
  local s = storage.scene
  local age = game.tick - storage.start
  if age == 2 then spawn_track_enemies() end
  if age >= 2 then
    drive_loop(age)
    check_lock(age)
  end
  if age > 2 and age < 1200 and s.b.valid then
    -- turrets are placed for the wagon position after this tick's train update,
    -- so compare last tick's turret positions with the wagon now
    if s.b_last and age > 5 then s.b_worst = math.max(s.b_worst or 0, deviation(s.b, s.b_last)) end
    s.b_last = positions(s.b)
    -- the train keeps going; give it a little push against friction
    if s.b_loco.train.speed < 0.3 and s.b.position.x < 90 then s.b_loco.train.speed = 0.3 end
  end
  if age == 10 then
    s.d.die()
    s.e.destroy({ raise_destroy = true })
    local gone = true
    for _, t in pairs(s.e_turrets) do
      gone = gone and not t.valid
    end
    report(gone, "script-destroyed wagon removes its turrets")
  end
  if age == 12 then
    local gone = true
    for _, t in pairs(s.d_turrets) do
      gone = gone and not t.valid
    end
    report(gone, "destroyed wagon removes its turrets")
  end
  if age == 70 then
    check_loaded()
    if s.g then
      local loaded = true
      for _, t in pairs(turrets(s.g)) do
        loaded = loaded and load_of(t) > 0
      end
      report(loaded, "elevated turrets are loaded too")
    end
  end
  if age == 80 then spawn_enemies() end
  if age == 400 and s.mine then
    local mines = s.surface.count_entities_filtered({ name = "land-mine", area = { { -130, 5 }, { -90, 19 } } })
    report(mines == 30, "six baskets fire one package each, five mines per package", mines .. " mines")
  end
  if age == 1200 then
    report(s.b.valid, "moving train survives its own fire")
    if not s.b.valid then
      log("WAGONTEST DONE")
      return
    end
    report(
      s.b.position.x - s.b_start > 200,
      "test train moved",
      string.format("%.1f tiles", s.b.position.x - s.b_start)
    )
    report((s.b_worst or 1) < 0.05, "turrets stay on the moving wagon", string.format("max %.4f", s.b_worst or -1))
  end
  if age == 1300 then
    report(alive(s.a_enemies) == 0, "standing train kills nearby enemies", alive(s.a_enemies) .. " left")
    report(s.a.valid and s.a_loco.valid, "standing train is still there after the fight")
    if not (s.a.valid and s.a_loco.valid) then
      log("WAGONTEST DONE")
      return
    end
    report(
      s.a.health > s.a.max_health * 0.9,
      "wagon survives the fight",
      string.format(
        "wagon %.0f/%.0f, locomotive %.0f/%.0f",
        s.a.health,
        s.a.max_health,
        s.a_loco.health,
        s.a_loco.max_health
      )
    )
    for _, e in pairs(s.b_enemies) do
      if e.valid then log(string.format("WAGONDEBUG left %.1f,%.1f hp %.0f", e.position.x, e.position.y, e.health)) end
    end
    report(
      alive(s.b_enemies) <= (SPEC.track_misses or 0),
      "moving train kills enemies along the track",
      alive(s.b_enemies) .. " left"
    )
    local expected = 0
    for _, wagon in pairs(s.surface.find_entities_filtered({ name = MOD })) do
      expected = expected + SPEC.mounts
    end
    local names = { TURRET, TURRET .. "-elevated" }
    for k = 1, 9 do
      if prototypes.entity[TURRET .. "-sink-" .. k] then names[#names + 1] = TURRET .. "-sink-" .. k end
    end
    local count = s.surface.count_entities_filtered({ name = names })
    report(count == expected, "no orphaned turrets", count .. " turrets, " .. expected .. " expected")
    if s.j then
      local damaged = 0
      for _, e in pairs(s.j_own) do
        if not e.valid or e.health < e.max_health then damaged = damaged + 1 end
      end
      report(alive(s.j_enemies) < #s.j_enemies, "explosive shells kill enemies", alive(s.j_enemies) .. " left")
      report(damaged == 0, "explosive shells spare own buildings", damaged .. " of " .. #s.j_own .. " damaged")
    end
    if s.mine then
      local at_flare = s.surface.count_entities_filtered({ name = "land-mine", area = { { -130, 5 }, { -90, 19 } } })
      local at_artillery =
        s.surface.count_entities_filtered({ name = "land-mine", position = { -111, -10 }, radius = 4 })
      report(at_flare == 40, "reloaded baskets fire the last two packages", at_flare .. " mines")
      report(at_artillery == 0, "mine launcher ignores artillery flares", at_artillery .. " mines")
    end
    s.main_done = true
  end
  -- the loop and the departure lock take longer; give up on them after LOOP_TICKS
  if s.main_done and not s.finished and (s.l_phase == "done" or not s.l_rails or age >= LOOP_TICKS) then
    s.finished = true
    report_loop()
    report_lock()
    log("WAGONTEST DONE")
  end
end)
