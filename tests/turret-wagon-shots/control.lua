-- Showcase scene for the turret wagon mods (tests/shots.py runs it with --benchmark-graphics).

local SPECS = {
  ["gun-turret-wagon"] = { ammo = "firearm-magazine", amount = 200, distance = 10 },
  ["flamethrower-turret-wagon"] = { fluid = "light-oil", amount = 20000, distance = 10 },
  ["rocket-turret-wagon"] = { ammo = "rocket", amount = 100, distance = 20 },
  ["twin-cannon-wagon"] = { ammo = "cannon-shell", amount = 100, distance = 14 },
  -- the howitzer has a minimum range of 12: the fight is shot from further out
  ["howitzer-wagon"] = { ammo = "cannon-shell", amount = 100, distance = 22, view = { 0, 12 }, zoom = 0.75 },
}
-- tests/run.py writes wagon.lua: the wagon under test
local MOD = require("wagon")
local SPEC = SPECS[MOD]

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

local function train(surface, vertical, fixed, wagon_at)
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
    position = vertical and { fixed, wagon_at } or { wagon_at, fixed },
  })
  if SPEC.fluid then
    wagon.insert_fluid({ name = SPEC.fluid, amount = SPEC.amount })
  else
    wagon.insert({ name = SPEC.ammo, count = SPEC.amount })
  end
  loco.train.manual_mode = true
  return wagon, loco
end

local function setup()
  local surface = game.surfaces.nauvis
  game.map_settings.enemy_expansion.enabled = false
  surface.request_to_generate_chunks({ 0, 0 }, 6)
  surface.force_generate_chunk_requests()
  surface.always_day = true
  for _, e in pairs(surface.find_entities_filtered({ force = "enemy" })) do
    e.destroy()
  end
  local area = { { -160, -100 }, { 160, 100 } }
  for _, e in pairs(surface.find_entities_filtered({ area = area })) do
    if e.type ~= "character" then e.destroy() end
  end
  local tiles = {}
  for x = -160, 159 do
    for y = -100, 99 do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  surface.destroy_decoratives({ area = area })

  local s = { surface = surface }
  -- standing train under attack
  rail_line(surface, false, 1, -61, 61)
  s.a = train(surface, false, 1, 0)
  -- vertical train
  rail_line(surface, true, 81, -31, 31)
  s.c = train(surface, true, 81, 0)
  -- trains among trees: trees in front must cover the turrets, trees behind must not
  rail_line(surface, false, -31, -31, 31)
  train(surface, false, -31, 0)
  rail_line(surface, true, 121, -31, 31)
  train(surface, true, 121, 0)
  local trees = {
    { -2.5, -33.5 }, { 2.5, -34 }, { -1.5, -28.5 }, { 1.5, -28 }, { 4, -29 },
    { 119, -3 }, { 123, 1.5 }, { 119.5, 2.5 }, { 122.5, -2 }, { 121.5, 4.5 }, { 120.5, -5 },
  }
  for _, p in pairs(trees) do
    surface.create_entity({ name = "tree-01", position = p })
  end
  -- fast train
  rail_line(surface, false, -61, -151, 151)
  s.b, s.b_loco = train(surface, false, -61, -140)
  -- elevated train
  if prototypes.entity["elevated-straight-rail"] then
    for x = -31, 31, 2 do
      surface.create_entity({
        name = "elevated-straight-rail",
        position = { x, 41 },
        direction = defines.direction.east,
        force = "player",
      })
    end
    for x = -28, 28, 8 do
      surface.create_entity({
        name = "rail-support",
        position = { x, 41 },
        direction = defines.direction.east,
        force = "player",
      })
    end
    s.e = train(surface, false, 41, 0)
    log("WAGONSHOT elevated wagon " .. tostring(s.e and s.e.valid) .. " " .. serpent.line(s.e and s.e.draw_data))
  end
  -- mine launcher, whenever it is switched on: throws mines at its flares
  if prototypes.entity["mine-launcher-wagon"] then
    rail_line(surface, true, -121, -31, 31)
    s.mine = surface.create_entity({
      name = "mine-launcher-wagon",
      force = "player",
      direction = defines.direction.north,
      position = { -121, 0 },
      raise_built = true,
    })
    s.mine.get_inventory(defines.inventory.artillery_wagon_ammo).insert({ name = "wagon-mine", count = 20 })
  end
  storage.s = s
end

local function biters(surface, x, y, n)
  for i = 1, n do
    surface.create_entity({ name = "small-biter", force = "enemy", position = { x + i * 1.5, y } })
  end
end

script.on_event(defines.events.on_tick, function()
  if not MOD then return end
  if not storage.s then
    setup()
    storage.start = game.tick
    return
  end
  local s = storage.s
  local age = game.tick - storage.start
  if age == 1 then s.b_loco.train.speed = 1 end
  if s.b_loco.valid and s.b_loco.train.speed < 1 and age < 300 then s.b_loco.train.speed = 1 end
  if age == 60 or age == 150 then biters(s.surface, -6, 1 + SPEC.distance, 6) end
  if age == 100 then biters(s.surface, 40, -61 - SPEC.distance, 6) end
  -- flares for the mine launcher, a few at a time so mines are in the air and on the ground
  local flares = { [20] = { -100, -8 }, [40] = { -97, 4 }, [60] = { -104, 12 }, [80] = { -94, -2 }, [100] = { -101, -14 } }
  if s.mine and flares[age] then
    s.surface.create_entity({
      name = "mine-launcher-flare",
      position = flares[age],
      force = "player",
      movement = { 0, 0 },
      height = 0,
      vertical_speed = 0,
      frame_speed = 0,
    })
  end
  local shots = {
    [5] = { "standing", { 0, 0 }, 1.5 },
    [6] = { "vertical", { 81, 0 }, 1.5 },
    [7] = { "elevated", { 0, 38 }, 1.5 },
    [8] = { "trees", { 0, -31 }, 1.5 },
    [9] = { "trees-vertical", { 121, 0 }, 1.5 },
    [80] = { "fighting", SPEC.view or { 0, 4 }, SPEC.zoom or 1 },
    [170] = { "fighting-2", SPEC.view or { 0, 4 }, SPEC.zoom or 1 },
    [90] = { "fast-1", "b", 1.5 },
    [120] = { "fast-2", "b", 1 },
  }
  -- more moments of the fight and of the mine launcher, to pick one with shots in the air
  for _, t in pairs({ 95, 100, 110, 125, 140, 160, 185 }) do
    shots[t] = shots[t] or { "fighting-" .. t, SPEC.view or { 0, 4 }, SPEC.zoom or 1 }
  end
  if s.mine then
    for _, t in pairs({ 300, 450, 600, 750 }) do
      shots[t] = { "mine-launcher-" .. t, { -108, 0 }, 1 }
    end
  end
  local shot = shots[age]
  if shot then
    local position = shot[2] == "b" and s.b.position or shot[2]
    game.take_screenshot({
      surface = s.surface,
      position = position,
      resolution = { 1600, 900 },
      zoom = shot[3],
      path = "wagon-shots/" .. shot[1] .. ".png",
      show_entity_info = false,
      allow_in_replay = true,
      anti_alias = true,
    })
    log("WAGONSHOT " .. shot[1] .. " at tick " .. game.tick)
  end
end)
