local this = {}
this.config = nil
this.configPath = "longod.DPSTooltips"
this.defaultConfig = {
    enable = true,
    accurateDamage = true,
    breakdown = true,
    minmaxRange = false,
    -- always or pressed key
    -- hitRate = false,
    -- armor = false,
    -- blocking = false,
    -- showIcon = True,
    logLevel = "INFO",
}

function this.Load()
    this.config = this.config or mwse.loadConfig(this.configPath, this.defaultConfig)
    return this.config
end

return this
