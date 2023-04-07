---@class Test
local Test = {}

---@return Test
function Test.new()
    local test = {}
    setmetatable(test, { __index = Test })
    return test
end

---@param self Test
---@param shutdown boolean?
function Test.Run(self, shutdown)
    ---@diagnostic disable: need-check-nil
    local config = require("longod.DPSTooltips.config").Default() -- use non-persisitent config for testing
    local dps = require("longod.DPSTooltips.dps").new(config)
    local logger = require("longod.DPSTooltips.logger")

    local unitwind = require("unitwind").new {
        enabled = true,
        beforeAll = function()
            dps:Initialize()
        end,
    }

    -- global mock
    -- TODO switch case true/false
    unitwind:mock(tes3, "findGMST", function(id)
        if id == tes3.gmst.fDamageStrengthBase then
            return { value = 0.5 }
        elseif id == tes3.gmst.fDamageStrengthMult then
            return { value = 0.1 }
        elseif id == tes3.gmst.fFatigueBase then
            return { value = 1.25 }
        elseif id == tes3.gmst.fFatigueMult then
            return { value = 0.5 }
        elseif id == tes3.gmst.fCombatInvisoMult then
            return { value = 0.2 }
        elseif id == tes3.gmst.fSwingBlockBase then
            return { value = 1.0 }
        elseif id == tes3.gmst.fSwingBlockMult then
            return { value = 1.0 }
        elseif id == tes3.gmst.fBlockStillBonus then
            return { value = 1.25 }
        elseif id == tes3.gmst.iBlockMinChance then
            return { value = 10 }
        elseif id == tes3.gmst.iBlockMaxChance then
            return { value = 50 }
        elseif id == tes3.gmst.fCombatArmorMinMult then
            return { value = 0.25 }
        elseif id == tes3.gmst.fDifficultyMult then
            return { value = 5.0 }
        end
        return { value = tostring(id) } -- temp
    end)
    unitwind:mock(tes3, "hasCodePatchFeature", function(id)
        return false
    end)
    unitwind:mock(tes3, "isModActive", function(filename)
        return false
    end)
    unitwind:mock(tes3, "isLuaModActive", function(key)
        return false
    end)
    -- TODO tes3.mobilePlayer, tes3.worldController

    unitwind:start("DPSTooltips")

    dps:RunTest(unitwind)

    unitwind:finish()

    if shutdown then
        logger:debug("Shutdown")
        os.exit()
    end
end

return Test
