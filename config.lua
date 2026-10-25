-- Names and numbers shared by the settings, data and control stage.
local config = {}

config.wagons = {
  {
    name = "gun-turret-wagon",
    turret = "gun-turret-wagon-turret",
    -- graphics/<variant>/ and the variant in tools/blender
    variant = "mg",
    fluid = false,
    -- turret positions along the wagon axis, in tiles from its centre
    mounts = { -1.9, 0, 1.9 },
    -- each turret is topped up to this many magazines from the wagon's cargo
    refill = 10,
  },
  {
    name = "flamethrower-turret-wagon",
    turret = "flamethrower-turret-wagon-turret",
    variant = "flame",
    fluid = true,
    mounts = { -1.5, 1.5 },
    -- each turret is topped up to this much fluid from the wagon's tank
    refill = 100,
  },
  {
    name = "rocket-turret-wagon",
    turret = "rocket-turret-wagon-turret",
    variant = "rocket",
    fluid = false,
    mounts = { -1.5, 1.5 },
    refill = 10,
    -- minimum ranges the player can choose; the first is the turret's own
    min_ranges = { 8, 10, 12, 14, 16, 18, 20, 22, 24 },
  },
  {
    name = "twin-cannon-wagon",
    turret = "twin-cannon-wagon-turret",
    variant = "twin",
    fluid = false,
    mounts = { -1.6, 1.6 },
    refill = 10,
  },
  {
    name = "howitzer-wagon",
    turret = "howitzer-wagon-turret",
    variant = "howitzer",
    fluid = false,
    mounts = { 0 },
    refill = 10,
  },
  -- an artillery wagon that throws mines where the remote points; no roof turrets
  {
    name = "mine-launcher-wagon",
    variant = "mine",
    mounts = {},
  },
}

-- How many entries a wagon's target priority list has.
config.priority_slots = 8

-- Armour plates for the wagons' equipment grid. Each resistance is { flat, percent }.
-- Several plates: the flat values add up, the percentages apply one after the other
-- (two times 20 % make 36 %), capped at config.armor_cap.
config.plates = {
  { name = "composite-armor-plate", resistances = { physical = { 1, 5 } } },
  { name = "reactive-armor-plate", resistances = { explosion = { 3, 6 } } },
  { name = "acid-armor-plate", resistances = { acid = { 1, 6 } } },
  { name = "fire-armor-plate", resistances = { fire = { 2, 6 } } },
  -- tungsten plates need Space Age
  {
    name = "tungsten-carbide-armor-plate",
    resistances = { physical = { 2, 9 }, acid = { 0, 3 }, fire = { 0, 4 } },
    space_age = true,
  },
  {
    name = "tungsten-reactive-armor-plate",
    resistances = { explosion = { 6, 10 }, physical = { 0.5, 3 } },
    space_age = true,
  },
  {
    name = "tungsten-carbide-acid-armor-plate",
    resistances = { acid = { 2, 12 }, fire = { 0, 4 } },
    space_age = true,
  },
}
config.armor_cap = 80
config.grid = "military-wagon-equipment-grid"
config.armor_category = "military-wagon-armor"

function config.setting(wagon) return "military-wagons-" .. wagon.name end

-- Before 0.3.0 every wagon was a mod of its own (since then an empty bridge that
-- depends on this one). If an old version is still active, it brings the wagon.
local function legacy(name)
  local version = (mods or script.active_mods)[name]
  if not version then return false end
  local major, minor = version:match("^(%d+)%.(%d+)")
  return tonumber(major) == 0 and tonumber(minor) < 3
end

-- The wagons switched on in the startup settings.
function config.enabled()
  local list = {}
  for _, wagon in ipairs(config.wagons) do
    if settings.startup[config.setting(wagon)].value and not legacy(wagon.name) then list[#list + 1] = wagon end
  end
  return list
end

return config
