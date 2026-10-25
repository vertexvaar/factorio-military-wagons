-- The wagons' equipment grid and the armour plates that go into it.
--
-- Plates are powerless dummy equipment: their resistances are applied by control.lua,
-- since equipment cannot give a vehicle resistances. The grid also takes everything a
-- tank's grid takes (added in data-final-fixes.lua, after all mods have set up theirs).

local config = require("config")

local PLATE_ICON = "__base__/graphics/icons/steel-plate.png"
-- rendered graphics (tools/blender/plates.py, build_icons.py), if there are any
local ok, rendered = pcall(require, "graphics.armor.icons")
if not ok or type(rendered) ~= "table" then rendered = {} end
local GRAPHICS = "__military-wagons__/graphics/armor/"

data:extend({
  { type = "equipment-category", name = config.armor_category },
  {
    type = "equipment-grid",
    name = config.grid,
    width = 16,
    height = 16,
    equipment_categories = { config.armor_category },
  },
})

local space_age = data.raw.item["tungsten-carbide"] ~= nil

local STEEL_TINT = { 0.7, 0.8, 0.95 }
local TUNGSTEN_TINT = { 0.35, 0.35, 0.4 }

local MILITARY = {
  { "automation-science-pack", 1 },
  { "logistic-science-pack", 1 },
  { "military-science-pack", 1 },
}
local TUNGSTEN = {
  { "automation-science-pack", 1 },
  { "logistic-science-pack", 1 },
  { "military-science-pack", 1 },
  { "chemical-science-pack", 1 },
  { "space-science-pack", 1 },
  { "metallurgic-science-pack", 1 },
}

-- Recipes and badges of the plates; the resistances are in config.lua.
local PLATES = {
  ["composite-armor-plate"] = {
    tint = STEEL_TINT,
    ingredients = { { "armor-steel", 10 }, { "steel-plate", 5 } },
    technology = "composite-armor-plate",
  },
  ["reactive-armor-plate"] = {
    tint = STEEL_TINT,
    badge = "__base__/graphics/icons/explosives.png",
    ingredients = { { "armor-steel", 8 }, { "explosives", 4 } },
    technology = "reactive-armor-plate",
  },
  ["acid-armor-plate"] = {
    tint = STEEL_TINT,
    badge = "__base__/graphics/icons/plastic-bar.png",
    ingredients = { { "armor-steel", 8 }, { "plastic-bar", 10 } },
    technology = "acid-armor-plate",
  },
  ["fire-armor-plate"] = {
    tint = STEEL_TINT,
    badge = "__base__/graphics/icons/stone-brick.png",
    ingredients = { { "armor-steel", 8 }, { "stone-brick", 10 } },
    technology = "fire-armor-plate",
  },
  ["tungsten-carbide-armor-plate"] = {
    tint = TUNGSTEN_TINT,
    ingredients = { { "armor-steel", 4 }, { "tungsten-carbide", 8 } },
    technology = "tungsten-armor-plates",
  },
  ["tungsten-reactive-armor-plate"] = {
    tint = TUNGSTEN_TINT,
    badge = "__base__/graphics/icons/explosives.png",
    ingredients = { { "armor-steel", 4 }, { "tungsten-plate", 6 }, { "explosives", 4 } },
    technology = "tungsten-armor-plates",
  },
  ["tungsten-carbide-acid-armor-plate"] = {
    tint = TUNGSTEN_TINT,
    badge = "__base__/graphics/icons/plastic-bar.png",
    ingredients = { { "armor-steel", 2 }, { "tungsten-carbide", 10 } },
    technology = "tungsten-armor-plates",
  },
}

local TECHNOLOGIES = {
  ["composite-armor-plate"] = { prerequisites = { "armor-steel" }, count = 150, packs = MILITARY, tint = STEEL_TINT },
  ["reactive-armor-plate"] = {
    prerequisites = { "armor-steel", "explosives" },
    count = 200,
    packs = MILITARY,
    tint = STEEL_TINT,
  },
  ["acid-armor-plate"] = {
    prerequisites = { "armor-steel", "plastics" },
    count = 200,
    packs = MILITARY,
    tint = STEEL_TINT,
  },
  ["fire-armor-plate"] = { prerequisites = { "armor-steel" }, count = 150, packs = MILITARY, tint = STEEL_TINT },
  ["tungsten-armor-plates"] = {
    prerequisites = { "composite-armor-plate", "reactive-armor-plate", "acid-armor-plate", "tungsten-steel" },
    count = 500,
    packs = TUNGSTEN,
    tint = TUNGSTEN_TINT,
    space_age = true,
  },
}

-- the rendered icon, or a tinted steel plate with a badge as placeholder
local function icons(name, plate)
  if rendered[name] then return { { icon = GRAPHICS .. name .. "-icon.png", icon_size = 64 } } end
  local list = { { icon = PLATE_ICON, icon_size = 64, tint = plate.tint } }
  if plate.badge then list[2] = { icon = plate.badge, icon_size = 64, scale = 0.3, shift = { 8, 8 } } end
  return list
end

for order, entry in ipairs(config.plates) do
  local name, plate = entry.name, PLATES[entry.name]
  if space_age or not entry.space_age then
    local ingredients = {}
    for i, ingredient in ipairs(plate.ingredients) do
      ingredients[i] = { type = "item", name = ingredient[1], amount = ingredient[2] }
    end
    data:extend({
      {
        type = "item",
        name = name,
        icons = icons(name, plate),
        place_as_equipment_result = name,
        subgroup = "military-equipment",
        order = string.format("f[military-wagon-armor]-%02d", order),
        stack_size = 20,
      },
      {
        -- equipment that needs no energy and shows no power line under the grid
        type = "inventory-bonus-equipment",
        name = name,
        sprite = rendered[name]
            and { filename = GRAPHICS .. name .. "-equipment.png", width = 256, height = 256, scale = 0.5 }
          or { filename = PLATE_ICON, width = 64, height = 64, scale = 2, tint = plate.tint },
        shape = { width = 4, height = 4, type = "full" },
        inventory_size_bonus = 0,
        categories = { config.armor_category },
      },
      {
        type = "recipe",
        name = name,
        -- tungsten plates also in the foundry
        categories = entry.space_age and { "metallurgy", "crafting" } or nil,
        energy_required = entry.space_age and 15 or 10,
        enabled = false,
        ingredients = ingredients,
        results = { { type = "item", name = name, amount = 1 } },
      },
    })
  end
end

for name, technology in pairs(TECHNOLOGIES) do
  if space_age or not technology.space_age then
    local effects = {}
    for _, entry in ipairs(config.plates) do
      if PLATES[entry.name].technology == name then
        effects[#effects + 1] = { type = "unlock-recipe", recipe = entry.name }
      end
    end
    data:extend({
      {
        type = "technology",
        name = name,
        icons = {
          { icon = "__base__/graphics/technology/steel-processing.png", icon_size = 256, tint = technology.tint },
        },
        effects = effects,
        prerequisites = technology.prerequisites,
        unit = { count = technology.count, ingredients = technology.packs, time = 30 },
      },
    })
  end
end
