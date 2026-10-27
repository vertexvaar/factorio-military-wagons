-- Probe: does the engine park an artillery wagon's cannon, and hold the train until it has?
-- Logs "PARKPROBE ..." lines; run through tests/run.py's environment (see tests/park_probe.py).
-- A: mine launcher wagon, cannon turned by script while standing, then sent off by schedule
-- B: vanilla artillery wagon after a shot at a flare, then sent off by schedule
-- C: mine launcher wagon driven by setting train.speed, cannon turned by script while moving

local function line(surface, y)
  for x = -101, 301, 2 do
    surface.create_entity({
      name = "straight-rail",
      position = { x, y },
      direction = defines.direction.east,
      force = "player",
    })
  end
end

local function train(surface, y, name)
  line(surface, y)
  local loco = surface.create_entity({
    name = "locomotive",
    force = "player",
    direction = defines.direction.east,
    position = { 7, y },
  })
  loco.get_fuel_inventory().insert({ name = "coal", count = 50 })
  local wagon = surface.create_entity({
    name = name,
    force = "player",
    direction = defines.direction.east,
    position = { 0, y },
    raise_built = true,
  })
  loco.train.manual_mode = true
  return { loco = loco, wagon = wagon, y = y }
end

local function state(t)
  local train = t.loco.train
  local name = "?"
  for k, v in pairs(defines.train_state) do
    if v == train.state then name = k end
  end
  return string.format(
    "speed %.4f state %s rto %s x %.3f",
    train.speed,
    name,
    tostring(t.wagon.relative_turret_orientation),
    t.wagon.position.x
  )
end

local function go(t)
  local rail = t.wagon.surface.find_entities_filtered({ name = "straight-rail", position = { 251, t.y } })[1]
  local schedule = t.loco.train.get_schedule()
  schedule.add_record({ rail = rail, temporary = true, wait_conditions = { { type = "time", ticks = 6000 } } })
  t.loco.train.manual_mode = false
  schedule.go_to_station(schedule.get_record_count())
end

script.on_event(defines.events.on_tick, function()
  if not storage.s then
    local surface = game.surfaces.nauvis
    surface.request_to_generate_chunks({ 0, 0 }, 10)
    surface.force_generate_chunk_requests()
    for _, e in pairs(surface.find_entities_filtered({ area = { { -150, -150 }, { 350, 150 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
    for _, e in pairs(surface.find_entities_filtered({ force = "enemy" })) do
      e.destroy()
    end
    storage.s = {
      a = train(surface, 1, "mine-launcher-wagon"),
      b = train(surface, 21, "artillery-wagon"),
      c = train(surface, 41, "mine-launcher-wagon"),
      -- D: like A, but with mine packages in the wagon
      d = train(surface, 61, "mine-launcher-wagon"),
      -- E: vanilla artillery wagon after a shot, driven off by a player character at the controls
      e = train(surface, 81, "artillery-wagon"),
    }
    -- F: control, a cargo wagon with a driver; G: mine launcher turned to 0.25 by script, with a driver
    storage.s.f = train(surface, 101, "cargo-wagon")
    storage.s.g = train(surface, 121, "mine-launcher-wagon")
    local s = storage.s
    for _, k in pairs({ "f", "g" }) do
      s[k].driver = surface.create_entity({ name = "character", force = "player", position = { 7, s[k].y + 3 } })
      s[k].loco.set_driver(s[k].driver)
    end
    s.e.driver = surface.create_entity({ name = "character", force = "player", position = { 7, 84 } })
    s.e.loco.set_driver(s.e.driver)
    storage.start = game.tick
    local p = prototypes.entity["mine-launcher-wagon"]
    local v = prototypes.entity["artillery-wagon"]
    log(
      string.format(
        "PARKPROBE prototype mine-launcher-wagon turret_rotation_speed %s; artillery-wagon %s",
        tostring(p.turret_rotation_speed),
        tostring(v.turret_rotation_speed)
      )
    )
    return
  end
  local s = storage.s
  local age = game.tick - storage.start
  if age == 1 then
    s.a.wagon.relative_turret_orientation = 0.25
    s.c.wagon.relative_turret_orientation = 0.25
    s.d.wagon.get_inventory(defines.inventory.artillery_wagon_ammo).insert({ name = "wagon-mine", count = 5 })
    s.d.wagon.relative_turret_orientation = 0.25
    s.b.wagon.get_inventory(defines.inventory.artillery_wagon_ammo).insert({ name = "artillery-shell", count = 5 })
    s.e.wagon.get_inventory(defines.inventory.artillery_wagon_ammo).insert({ name = "artillery-shell", count = 5 })
    s.e.wagon.surface.create_entity({
      name = "artillery-flare",
      position = { 0, 81 + 80 },
      force = "player",
      movement = { 0, 0 },
      height = 0,
      vertical_speed = 0,
      frame_speed = 0,
    })
    s.b.wagon.surface.create_entity({
      name = "artillery-flare",
      position = { 0, 21 - 80 },
      force = "player",
      movement = { 0, 0 },
      height = 0,
      vertical_speed = 0,
      frame_speed = 0,
    })
    log("PARKPROBE set A and C to 0.25: A " .. state(s.a) .. " | C " .. state(s.c))
  end
  if age < 300 and age % 20 == 0 then
    log(string.format("PARKPROBE standing tick %d | A %s | B %s | C %s", age, state(s.a), state(s.b), state(s.c)))
  end
  if age == 300 then
    go(s.a)
    go(s.b)
    go(s.d)
    s.c.loco.train.speed = 0.2
    log("PARKPROBE go at tick 300")
  end
  if age > 300 and age <= 480 then
    if s.c.loco.train.speed < 0.2 then s.c.loco.train.speed = 0.2 end
    if age == 360 then
      s.c.wagon.relative_turret_orientation = 0.3
      log("PARKPROBE C set to 0.3 while moving: " .. state(s.c))
    end
    if age <= 330 or age % 5 == 0 then
      log(string.format("PARKPROBE moving tick %d | A %s | B %s | C %s", age, state(s.a), state(s.b), state(s.c)))
    end
  end
  if age == 1 then s.g.wagon.relative_turret_orientation = 0.25 end
  for _, k in pairs({ "e", "f", "g" }) do
    if age >= 300 then
      s[k].loco.riding_state =
        { acceleration = defines.riding.acceleration.accelerating, direction = defines.riding.direction.straight }
    end
    if age >= 290 and age % 10 == 0 then
      log(
        string.format(
          "PARKPROBE %s tick %d driver %s %s",
          k:upper(),
          age,
          tostring(s[k].loco.get_driver() ~= nil),
          state(s[k])
        )
      )
    end
  end
  if age >= 300 and age % 25 == 0 then log(string.format("PARKPROBE D tick %d %s", age, state(s.d))) end
  if age == 600 or age == 690 then
    log(
      string.format(
        "PARKPROBE end tick %d | A %s | B %s | C %s | D %s",
        age,
        state(s.a),
        state(s.b),
        state(s.c),
        state(s.d)
      )
    )
  end
end)
