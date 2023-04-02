
require("longod.DPSTooltips.test").new():Run(false)

local dps = require("longod.DPSTooltips.dps").new()
local drawer = require("longod.DPSTooltips.drawer").new()
local config = require("longod.DPSTooltips.config").Load()

local function IsWeapon(object)
    if object then
        if object.objectType == tes3.objectType.weapon
        or object.objectType == tes3.objectType.ammunition then
            return true
        end
    end
    return false
end

local function OnUiObjectTooltip(e)
    if config.enable and IsWeapon(e.object) then
        local data = dps:CalculateDPS(e.object, e.itemData)
        drawer:Display(e.tooltip, data)
    end
end

local function OnInitialized()
    dps:Initialize()
    drawer:Initialize()
    event.register(tes3.event.uiObjectTooltip, OnUiObjectTooltip, { priority = 0 }) -- todo after other UI mods
end

event.register(tes3.event.initialized, OnInitialized)

event.register(tes3.event.modConfigReady, require("longod.DPSTooltips.mcm"))
