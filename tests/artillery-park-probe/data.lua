-- Copies of the mine launcher wagon with single prototype values changed, to find out
-- which one keeps its cannon from parking (and the train from leaving).
local variants = {
  -- parking frames as in vanilla
  { name = "probe-park-frames", parking = 8, auto = false },
  -- automatic firing on
  { name = "probe-park-auto", parking = 0, auto = true },
  { name = "probe-park-both", parking = 8, auto = true },
  -- both, and a faster cannon
  { name = "probe-park-fast", parking = 8, auto = true, speed = 0.004 },
}
for _, v in pairs(variants) do
  local wagon = table.deepcopy(data.raw["artillery-wagon"]["mine-launcher-wagon"])
  wagon.name = v.name
  wagon.cannon_parking_frame_count = v.parking
  wagon.disable_automatic_firing = not v.auto
  if v.speed then wagon.turret_rotation_speed = v.speed end
  data:extend({ wagon })
end
