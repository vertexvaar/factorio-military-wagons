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
  -- an artillery wagon with six launcher baskets on its roof. Each basket is an artillery
  -- turret of its own that throws a mine package where the remote points. The wagon's
  -- own gun never fires; its ammo slots are the baskets' supply.
  {
    name = "mine-launcher-wagon",
    turret = "mine-launcher-basket",
    variant = "mine",
    fluid = false,
    -- { along, across }: two rows of three, the across offset to the right of the front
    mounts = { { -2.05, -0.47 }, { -0.95, -0.47 }, { 0.15, -0.47 }, { -2.05, 0.47 }, { -0.95, 0.47 }, { 0.15, 0.47 } },
    -- one package per basket, so a few packages spread over all baskets
    refill = 1,
    -- the baskets take their own copy of the wagon mines (see prototypes/mine.lua)
    loads = { ["wagon-mine"] = "military-wagons-wagon-mine" },
    -- no target priorities: the baskets fire only where the remote points
    targets = false,
  },
}

-- How many entries a wagon's target priority list has.
config.priority_slots = 8

-- Armour plates for the wagons' equipment grid. Each resistance is { flat, percent }.
-- Several plates: the flat values add up, the percentages apply one after the other
-- (two times 20 % make 36 %), capped at config.armor_cap.
config.plates = {
  { name = "composite-armor-plate", resistances = { physical = { 0.5, 4 } } },
  { name = "reactive-armor-plate", resistances = { explosion = { 1.5, 5 } } },
  { name = "acid-armor-plate", resistances = { acid = { 0.5, 5 } } },
  { name = "fire-armor-plate", resistances = { fire = { 1, 5 } } },
  -- tungsten plates need Space Age
  {
    name = "tungsten-carbide-armor-plate",
    resistances = { physical = { 1, 6 }, acid = { 0, 2 }, fire = { 0, 3 } },
    space_age = true,
  },
  {
    name = "tungsten-reactive-armor-plate",
    resistances = { explosion = { 3, 7 }, physical = { 0, 2 } },
    space_age = true,
  },
  {
    name = "tungsten-carbide-acid-armor-plate",
    resistances = { acid = { 1, 7 }, fire = { 0, 3 } },
    space_age = true,
  },
}
config.armor_cap = 80
-- each quality level makes a plate this much stronger (shields: 30 % more capacity per level)
config.armor_quality_bonus = 0.3
-- the wagons' equipment grid, like a tank's
config.grid_size = { width = 6, height = 8 }

-- Wagon turrets fire their own copies of the tank shells, which pass their own side:
-- from a turret on a train, a shell starts among its own wagons. The copies are named
-- config.shell_prefix .. original and loaded from the original shells in the cargo.
config.shell_category = "military-wagons-cannon-shell"
config.shell_prefix = "military-wagons-"
-- how far the shell copies fly: tank shells stop at 30, the howitzer reaches 36
config.shell_range = 40
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
