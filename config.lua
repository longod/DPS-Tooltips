--- @module '"longod.DPSTooltips.config"'

--- @type table
local this = {}

--- @class Config: table
--- @field enable boolean Enable the mod.
--- @field minmaxRange boolean Show the minimum and maximum range of the weapon.
--- @field preDivider boolean Show the pre-divider damage value.
--- @field postDivider boolean Show the post-divider damage value.
--- @field accurateDamage boolean Show the accurate damage value.
--- @field maxDurability boolean Show the maximum durability of the weapon.
--- @field breakdown boolean Show the damage breakdown.
--- @field coloring boolean Enable coloring of the tooltip.
--- @field showIcon boolean Show the icon in the tooltip.
--- @field logLevel string The log level to use. One of "DEBUG", "INFO", "WARN", "ERROR", or "FATAL".
this.defaultConfig = {
    enable = true,
    minmaxRange = true,
    preDivider = false,
    postDivider = false,
    accurateDamage = true,
    maxDurability = true,
    breakdown = true,
    coloring = true,
    showIcon = true,
    logLevel = "INFO",
}

--- @type Config
this.config = nil
--- @type string
this.configPath = "longod.DPSTooltips"

--- Loads the configuration for the DPS module from disk or returns the cached configuration if it has already been loaded.
--- @return Config @The configuration object for the DPS module.
function this.Load()
    this.config = this.config or mwse.loadConfig(this.configPath, this.defaultConfig)
    return this.config
end

--- Returns the default configuration table.
--- @return Config @The default configuration table.
function this.Default()
    return table.deepcopy(this.defaultConfig)
end

return this
