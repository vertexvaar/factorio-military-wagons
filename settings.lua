local config = require("config")

for i, wagon in ipairs(config.wagons) do
  data:extend({
    {
      type = "bool-setting",
      name = config.setting(wagon),
      setting_type = "startup",
      default_value = true,
      order = "a-" .. i,
    },
  })
end
