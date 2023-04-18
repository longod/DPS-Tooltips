--- @module '"longod.DPSTooltips.test"'

--- @class Test
local Test = {}

--- Creates a new instance of the Test class.
--- @return Test @A new instance of the Test class.
function Test.new()
    return setmetatable({}, { __index = Test })
end

--- Runs the test suite for the DPS Tooltips mod.
---@param shutdown boolean? If true, shuts down the program after running the test suite.
function Test.Run(shutdown)
    local config = require("longod.DPSTooltips.config").Default() -- use non-persisitent config for testing
    local combat = require("longod.DPSTooltips.combat")
    local logger = require("longod.DPSTooltips.logger")
    local unitwind = require("unitwind").new({ enabled = true, beforeAll = function() end })

    --- Adds a new expectation method to the UnitWind library for performing floating point equality checks with an epsilon.
    --- @param result any The result to check.
    --- @param epsilon number? The acceptable error margin.
    --- @return UnitWind.expects @An object with functions to perform expectations on the result.    
    function unitwind.approxExpect(self, result, epsilon)
        local expectTypes = {
            toBe = function(expectedResult, isNot)
                if not self.enabled then return false end
                if (type(result) == "number") then
                    if (combat.NearlyEqual(result, expectedResult, epsilon)) == isNot then
                        error(string.format("Expected value to %sbe %s, got: %s.", isNot and "not " or "", expectedResult, result))
                    end
                else
                    return self:expect(result).toBe(expectedResult, isNot)
                end
                return true
            end,
        }
        --- @type UnitWind.expects
        local expects = {}
        --- @type UnitWind.expects.NOT
        expects.NOT = {}
        for expectType, func in pairs(expectTypes) do
            expects[expectType] = function(...)
                return func(..., false)
            end
            expects.NOT[expectType] = function(...)
                return func(..., true)
            end
        end
        return expects
    end

    --[[
    --- TODO: Consider using a switch statement for better readability.
    --- Mock several Morrowind functions using the UnitWind library for testing purposes.
    --- tes3.findGMST: Returns mock values for various game settings.
    --- tes3.hasCodePatchFeature: Always returns false to prevent interference from external mods.
    --- tes3.isModActive: Always returns false to prevent interference from external mods.
    --- tes3.isLuaModActive: Always returns false to prevent interference from external mods.
    --- TODO: Add mocks for tes3.mobilePlayer and tes3.worldController.
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
        return { value = tostring(id) } -- Temporarily return the ID as a string for debugging.
    end)
    ]]--

    require("longod.DPSTooltips.combat"):RunTest(unitwind)
    require("longod.DPSTooltips.effect"):RunTest(unitwind)
    
    if shutdown then
        logger:debug("Shutdown")
        os.exit()
    end
end

return Test
