-- Armour steel: the base material of the wagon armour plates. Steel, copper and
-- carbon, quenched in water in a chemical plant, which gives off steam.
--
-- Space Age has carbon; without it this mod brings the item and a recipe that
-- cokes it from coal. With Space Age the player has to get carbon the usual way.

local space_age = data.raw.item["carbon"] ~= nil

local carbon_tech
if space_age then
  -- whichever technology unlocks Space Age's carbon recipe
  for name, tech in pairs(data.raw.technology) do
    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == "carbon" then carbon_tech = name end
    end
  end
else
  data:extend({
    {
      type = "item",
      name = "carbon",
      icons = { { icon = "__base__/graphics/icons/coal.png", icon_size = 64, tint = { 0.55, 0.55, 0.6 } } },
      subgroup = "raw-material",
      order = "b[carbon]",
      stack_size = 50,
      weight = 2000,
    },
    {
      type = "recipe",
      name = "military-wagons-carbon",
      categories = { "smelting" },
      energy_required = 3.2,
      enabled = false,
      ingredients = { { type = "item", name = "coal", amount = 2 } },
      results = { { type = "item", name = "carbon", amount = 1 } },
    },
  })
end

local effects = { { type = "unlock-recipe", recipe = "armor-steel" } }
if not space_age then table.insert(effects, 1, { type = "unlock-recipe", recipe = "military-wagons-carbon" }) end

local prerequisites = { "steel-processing", "military-2" }
if carbon_tech then prerequisites[#prerequisites + 1] = carbon_tech end

data:extend({
  {
    type = "item",
    name = "armor-steel",
    icons = { { icon = "__base__/graphics/icons/steel-plate.png", icon_size = 64, tint = { 0.7, 0.8, 0.95 } } },
    subgroup = "intermediate-product",
    order = "a[armor-steel]",
    stack_size = 100,
  },
  {
    type = "recipe",
    name = "armor-steel",
    categories = { "chemistry" },
    energy_required = 4,
    enabled = false,
    ingredients = {
      { type = "item", name = "steel-plate", amount = 4 },
      { type = "item", name = "copper-plate", amount = 1 },
      { type = "item", name = "carbon", amount = 2 },
      { type = "fluid", name = "water", amount = 20 },
    },
    results = {
      { type = "item", name = "armor-steel", amount = 1 },
      -- quenching: the water boils off
      { type = "fluid", name = "steam", amount = 20, temperature = 165 },
    },
    main_product = "armor-steel",
    allow_productivity = true,
  },
  {
    type = "technology",
    name = "armor-steel",
    icons = {
      { icon = "__base__/graphics/technology/steel-processing.png", icon_size = 256, tint = { 0.7, 0.8, 0.95 } },
    },
    effects = effects,
    prerequisites = prerequisites,
    unit = {
      count = 200,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "military-science-pack", 1 },
      },
      time = 30,
    },
  },
})
