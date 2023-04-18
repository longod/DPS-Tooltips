require("longod.DPSTooltips.test").new().Run(false)

local config = require("longod.DPSTooltips.config").Load()
local dps = require("longod.DPSTooltips.dps").new(config)
local drawer = require("longod.DPSTooltips.drawer").new(config)

--- Checks if the provided object is a weapon or ammunition.
--- @param object tes3physicalObject The object to check.
--- @return boolean @Returns true if the object is a weapon or ammunition, false otherwise.
local function IsWeapon(object)
    if object and (object.objectType == tes3.objectType.weapon or object.objectType == tes3.objectType.ammunition) then
        return true
    end
    return false
end

--- Event callback function for displaying DPS information in weapon tooltips.
--- @param e uiObjectTooltipEventData The event data.
local function OnUiObjectTooltip(e)
    if config.enable and IsWeapon(e.object) then
        local useBestAttack = tes3.worldController.useBestAttack
        local object = e.object ---@cast object tes3weapon
        local data = dps:CalculateDPS(object, e.itemData, useBestAttack)
        drawer:Display(e.tooltip, data, useBestAttack)
    end
end

--- Initializes the DPS Tooltips mod.
local function OnInitialized()
    dps:Initialize()
    drawer:Initialize()
    event.register(tes3.event.uiObjectTooltip, OnUiObjectTooltip, { priority = 0 }) -- TODO tweaks priority
end

event.register(tes3.event.initialized, OnInitialized)
event.register(tes3.event.modConfigReady, require("longod.DPSTooltips.mcm").OnModConfigReady)
