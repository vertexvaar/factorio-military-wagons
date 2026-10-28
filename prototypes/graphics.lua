-- Wagon sprites from graphics/<variant>/entity/sprites.lua, which tools/blender/build_sprites.py
-- generates from the Blender renders. Without that file the wagon keeps the vanilla look.
local graphics = {}

local function sprites(variant)
  local ok, set = pcall(require, "graphics." .. variant .. ".entity.sprites")
  return ok and type(set) == "table" and set or nil
end

local function sheet(dir, meta, extra)
  local def = {
    width = meta.width,
    height = meta.height,
    shift = meta.shift,
    scale = 0.5,
    direction_count = meta.frame_count,
    -- wagons rendered all the way round (256 directions) have a distinct back
    back_equals_front = meta.frame_count < 256,
    allow_low_quality_rotation = true,
    usage = "train",
    line_length = meta.line_length,
  }
  if #meta.files == 1 then
    def.filename = dir .. "entity/" .. meta.files[1]
  else
    def.filenames = {}
    for i, f in ipairs(meta.files) do
      def.filenames[i] = dir .. "entity/" .. f
    end
    def.lines_per_file = meta.lines_per_file
  end
  for k, v in pairs(extra or {}) do
    def[k] = v
  end
  return def
end

local function path(variant) return "__military-wagons__/graphics/" .. variant .. "/" end

-- RollingStockRotatedSlopedGraphics for the wagon, or nil without renders.
function graphics.wagon_pictures(variant)
  local found = sprites(variant)
  if not found then return nil end
  local set, dir = found.wagon, path(variant)
  return {
    rotated = {
      layers = {
        sheet(dir, set.color),
        sheet(dir, set.mask, { flags = { "mask" }, apply_runtime_tint = true, tint_as_overlay = true }),
        sheet(dir, set.shadow, { draw_as_shadow = true }),
      },
    },
  }
end

-- RotatedAnimation of a rendered turret head (graphics/<variant>/entity/turret.lua), or nil.
-- The head is rendered at its height on the wagon, so it needs no lift.
function graphics.turret_animation(variant)
  local ok, set = pcall(require, "graphics." .. variant .. ".entity.turret")
  if not ok or type(set) ~= "table" then return nil end
  local dir = path(variant)
  local color = sheet(dir, set.color)
  local shadow = sheet(dir, set.shadow, { draw_as_shadow = true })
  for _, layer in pairs({ color, shadow }) do
    -- the barrel points one way: back is not front
    layer.back_equals_front = false
    layer.usage = nil
  end
  return { layers = { color, shadow } }
end

-- Item and entity icon, or nil without renders.
function graphics.icons(variant, badge)
  if not sprites(variant) then return nil end
  return {
    { icon = path(variant) .. "icons/wagon.png", icon_size = 64 },
    { icon = badge, icon_size = 64, scale = 0.3, shift = { 8, -8 } },
  }
end

return graphics
