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
  },
}

-- Armour plates for the wagons' equipment grid. Each resistance is { flat, percent }.
-- Several plates: the flat values add up, the percentages apply one after the other
-- (two times 20 % make 36 %), capped at config.armor_cap.
config.plates = {
  {
    name = "composite-armor-plate",
    resistances = { physical = { 4, 20 } },
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
