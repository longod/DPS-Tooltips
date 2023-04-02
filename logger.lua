local config = require("longod.DPSTooltips.config").Load()
local logger = require("logging.logger")
local _ = logger.new({
    name = "DPSTooltips",
    logLevel = config and config.logLevel or "INFO",
    logToConsole = false,
    includeTimestamp = false,
})

return logger.getLogger("DPSTooltips")
