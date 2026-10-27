local rig = require("prototypes.rig")
local wagon_config = require("config")
local graphics = require("prototypes.graphics")

-- Mine launcher wagon: an artillery wagon with six launcher baskets on its roof. Each
-- basket is a hidden artillery turret riding on the wagon (control.lua) that throws a
-- package of land mines, only where the player points the mine launcher remote.
-- The baskets fire a copy of the wagon mine with its own category, which only the remote's
-- flares call for: real artillery ignores those flares, the vanilla artillery flare gets
-- the artillery shell category in data-final-fixes.lua, and the wagon's own gun, loaded
-- with the wagon mines the baskets are refilled from, never answers any flare.
local CATEGORY = "wagon-mine"
local BASKET_CATEGORY = wagon_config.shell_prefix .. "wagon-mine"
local BASKET_AMMO = wagon_config.shell_prefix .. "wagon-mine"
-- control.lua notes each basket's shot with this script trigger
local SHOT_EFFECT = "military-wagons-basket-shot"
local RANGE = 120
local MIN_RANGE = 16
-- one thrown mine is a package of this many land mines, scattered around the target
local MINES_PER_SHOT = 5
local SCATTER = 2.5

-- config: this wagon's entry in config.wagons
return function(config)
  local wagon = table.deepcopy(data.raw["artillery-wagon"]["artillery-wagon"])
  wagon.name = config.name
  wagon.icons = {
    { icon = "__base__/graphics/icons/artillery-wagon.png", icon_size = 64 },
    { icon = "__base__/graphics/icons/land-mine.png", icon_size = 64, scale = 0.3, shift = { 8, -8 } },
  }
  wagon.icon = nil
  wagon.minable = { mining_time = 0.5, result = config.name }
  wagon.gun = "mine-launcher"
  wagon.disable_automatic_firing = true
  wagon.inventory_size = 2
  wagon.ammo_stack_limit = 100
  wagon.automated_ammo_count = 20
  wagon.color = { r = 0.33, g = 0.35, b = 0.24, a = 1 }
  wagon.allow_manual_color = true
  wagon.factoriopedia_simulation = nil
  -- the baskets on the roof are turrets of their own: no vanilla cannon on the wagon
  wagon.cannon_base_pictures = nil
  wagon.cannon_barrel_pictures = nil
  wagon.cannon_base_shift_when_horizontal = 0
  wagon.cannon_base_shift_when_vertical = 0
  wagon.cannon_base_height = 1.9
  wagon.cannon_parking_frame_count = 0
  wagon.rotating_sound = nil
  rig.armour(wagon)
  local pictures = graphics.wagon_pictures(config.variant)
  if pictures then wagon.pictures = pictures end
  wagon.icons = graphics.icons(config.variant, "__base__/graphics/icons/land-mine.png") or wagon.icons

  local item = table.deepcopy(data.raw["item-with-entity-data"]["artillery-wagon"])
  item.name = config.name
  item.icons = wagon.icons
  item.icon = nil
  item.place_result = config.name
  item.order = "c[rolling-stock]-e[artillery-wagon]-m[mine-launcher-wagon]"

  local gun = table.deepcopy(data.raw["gun"]["artillery-wagon-cannon"])
  gun.name = "mine-launcher"
  gun.attack_parameters.ammo_category = CATEGORY
  gun.attack_parameters.ammo_categories = nil
  gun.attack_parameters.range = RANGE
  gun.attack_parameters.min_range = MIN_RANGE

  local basket_gun = table.deepcopy(gun)
  basket_gun.name = config.turret
  basket_gun.attack_parameters.ammo_category = BASKET_CATEGORY
  basket_gun.attack_parameters.cooldown = config.reload
  basket_gun.attack_parameters.projectile_creation_distance = 0
  basket_gun.attack_parameters.projectile_center = { 0, 0 }
  basket_gun.attack_parameters.projectile_creation_parameters = nil

  -- A basket: an artillery turret without base, turning on its own. Its rendered picture
  -- (graphics/mine/entity/turret.lua) sits at its height on the wagon. Without renders
  -- the baskets are invisible and the wagon picture shows them.
  local basket = rig.hide(table.deepcopy(data.raw["artillery-turret"]["artillery-turret"]), config.turret)
  basket.gun = config.turret
  basket.inventory_size = 1
  basket.ammo_stack_limit = config.refill
  basket.automated_ammo_count = nil
  basket.disable_automatic_firing = true
  -- the remote's flares count as manual targets: no range bonus over the 120 tiles
  basket.manual_range_modifier = 1
  basket.alert_when_attacking = false
  basket.turret_rotation_speed = 0.01
  basket.turn_after_shooting_cooldown = 0
  basket.cannon_parking_frame_count = 0
  basket.base_picture = nil
  basket.cannon_barrel_pictures = nil
  basket.cannon_base_pictures = graphics.turret_animation(config.variant)
  basket.rotating_sound = nil
  basket.factoriopedia_simulation = nil

  -- the package flies like a shell and scatters armed land mines of the wagon's force
  local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
  projectile.name = "wagon-mine-projectile"
  projectile.reveal_map = false
  projectile.picture = {
    filename = "__base__/graphics/icons/land-mine.png",
    width = 64,
    height = 64,
    scale = 0.25,
  }
  projectile.chart_picture = nil
  projectile.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        {
          type = "create-entity",
          entity_name = "land-mine",
          repeat_count = MINES_PER_SHOT,
          offset_deviation = { { -SCATTER, -SCATTER }, { SCATTER, SCATTER } },
          find_non_colliding_position = true,
          non_colliding_search_radius = 2,
          check_buildability = true,
        },
      },
    },
  }
  projectile.final_action = nil

  local shell = data.raw["ammo"]["artillery-shell"]
  local ammo_type = table.deepcopy(shell.ammo_type)
  ammo_type.action.action_delivery.projectile = "wagon-mine-projectile"

  -- the baskets' copy tells control.lua which basket fired
  local basket_ammo_type = table.deepcopy(ammo_type)
  local delivery = basket_ammo_type.action.action_delivery
  local source_effects = delivery.source_effects or {}
  if source_effects.type then source_effects = { source_effects } end
  source_effects[#source_effects + 1] = { type = "script", effect_id = SHOT_EFFECT }
  delivery.source_effects = source_effects

  local flare = table.deepcopy(data.raw["artillery-flare"]["artillery-flare"])
  flare.name = "mine-launcher-flare"
  flare.shot_category = BASKET_CATEGORY
  flare.shots_per_flare = 1
  flare.map_color = { 0.9, 0.6, 0.1 }

  local remote = table.deepcopy(data.raw["capsule"]["artillery-targeting-remote"])
  remote.name = "mine-launcher-remote"
  remote.icons = {
    { icon = "__base__/graphics/icons/artillery-targeting-remote.png", icon_size = 64, tint = { 1, 0.75, 0.4 } },
    { icon = "__base__/graphics/icons/land-mine.png", icon_size = 64, scale = 0.3, shift = { 8, 8 } },
  }
  remote.icon = nil
  remote.capsule_action = { type = "artillery-remote", flare = "mine-launcher-flare" }
  remote.order = "zz[mine-launcher-remote]"

  local tech_units = {
    count = 200,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "military-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  }

  data:extend({
    { type = "ammo-category", name = CATEGORY },
    { type = "ammo-category", name = BASKET_CATEGORY, hidden = true },
    wagon,
    item,
    gun,
    basket_gun,
    {
      type = "ammo",
      name = BASKET_AMMO,
      localised_name = { "item-name.wagon-mine" },
      localised_description = { "item-description.wagon-mine" },
      icons = {
        { icon = "__base__/graphics/icons/land-mine.png", icon_size = 64 },
        { icon = "__base__/graphics/icons/explosives.png", icon_size = 64, scale = 0.3, shift = { 8, 8 } },
      },
      ammo_category = BASKET_CATEGORY,
      ammo_type = basket_ammo_type,
      hidden = true,
      hidden_in_factoriopedia = true,
      auto_recycle = false,
      stack_size = 20,
    },
    projectile,
    flare,
    remote,
    {
      type = "ammo",
      name = "wagon-mine",
      icons = {
        { icon = "__base__/graphics/icons/land-mine.png", icon_size = 64 },
        { icon = "__base__/graphics/icons/explosives.png", icon_size = 64, scale = 0.3, shift = { 8, 8 } },
      },
      ammo_category = CATEGORY,
      ammo_type = ammo_type,
      subgroup = "ammo",
      order = "e[wagon-mine]",
      stack_size = 20,
    },
    {
      type = "recipe",
      name = "wagon-mine",
      energy_required = 4,
      enabled = false,
      ingredients = {
        { type = "item", name = "land-mine", amount = MINES_PER_SHOT },
        { type = "item", name = "explosives", amount = 1 },
      },
      results = { { type = "item", name = "wagon-mine", amount = 1 } },
    },
    -- like the artillery remote: no recipe, the shortcut bar puts it in the cursor
    {
      type = "shortcut",
      name = "give-mine-launcher-remote",
      order = "e[spidertron-remote]-m[mine-launcher-remote]",
      action = "spawn-item",
      technology_to_unlock = config.name,
      unavailable_until_unlocked = true,
      item_to_spawn = "mine-launcher-remote",
      icons = {
        {
          icon = "__base__/graphics/icons/shortcut-toolbar/mip/artillery-targeting-remote-x56.png",
          icon_size = 56,
          tint = { 1, 0.75, 0.4 },
        },
      },
      small_icons = {
        {
          icon = "__base__/graphics/icons/shortcut-toolbar/mip/artillery-targeting-remote-x24.png",
          icon_size = 24,
          tint = { 1, 0.75, 0.4 },
        },
      },
    },
    {
      type = "recipe",
      name = config.name,
      energy_required = 5,
      enabled = false,
      ingredients = {
        { type = "item", name = "cargo-wagon", amount = 1 },
        { type = "item", name = "steel-plate", amount = 40 },
        { type = "item", name = "iron-gear-wheel", amount = 20 },
        { type = "item", name = "advanced-circuit", amount = 10 },
      },
      results = { { type = "item", name = config.name, amount = 1 } },
    },
    {
      type = "technology",
      name = config.name,
      icons = {
        { icon = "__base__/graphics/technology/railway.png", icon_size = 256 },
        { icon = "__base__/graphics/technology/land-mine.png", icon_size = 256, scale = 0.25, shift = { 32, 32 } },
      },
      effects = {
        { type = "unlock-recipe", recipe = config.name },
        { type = "unlock-recipe", recipe = "wagon-mine" },
      },
      prerequisites = { "railway", "land-mine", "explosives" },
      unit = tech_units,
    },
  })
  data:extend(rig.variants(basket, config.mounts))
end
