local this = {}

---@class Config
this.defaultConfig = {
    enable = true,
    minmaxRange = true,
    accurateDamage = true,
    maxDurability = true,
    breakdown = true,
    -- always or pressed key
    -- hitRate = false,
    -- armor = false,
    -- blocking = false,
    -- difficulty = false,
    coloring = true,
    showIcon = true,
    logLevel = "INFO",
}
this.config = nil ---@type Config
this.configPath = "longod.DPSTooltips"

---@return Config
function this.Load()
    this.config = this.config or mwse.loadConfig(this.configPath, this.defaultConfig)
    return this.config
end

---@return Config
function this.Default()
    return table.deepcopy(this.defaultConfig)
end

return this
