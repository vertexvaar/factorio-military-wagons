local config = require("config")

for _, wagon in ipairs(config.enabled()) do
  require("prototypes." .. wagon.variant)(wagon)
end

require("prototypes.armor_steel")
