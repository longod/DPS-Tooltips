---@class Test
local Test = {}

---@return Test
function Test.new()
    local test = {}
    setmetatable(test, { __index = Test })
    return test
end

---@param shutdown boolean?
function Test.Run(shutdown)
    local config = require("longod.DPSTooltips.config").Default() -- use non-persisitent config for testing
    local dps = require("longod.DPSTooltips.dps").new(config)
    local combat = require("longod.DPSTooltips.combat")
    local logger = require("longod.DPSTooltips.logger")

    local unitwind = require("unitwind").new {
        enabled = true,
        beforeAll = function()
        end,
    }

    -- add equality for floating point error
    ---@param result any #The result to check
    ---@param epsilon number?
    ---@return UnitWind.expects #An object with functions to perform expectations on the result
    function unitwind.approxExpect(self, result, epsilon)
        local expectTypes = {
            toBe = function(expectedResult, isNot)
                if not self.enabled then return false end
                if (type(result) == "number") then
                    if (combat.NearyEqual(result, expectedResult, epsilon)) == isNot then
                        error(string.format("Expected value to %sbe %s, got: %s.", isNot and "not " or "", expectedResult,
                            result))
                    end
                else
                    -- fallback
                    return self:expect(result).toBe(expectedResult, isNot)
                end
                return true
            end,
        }
        ---@type UnitWind.expects
        local expects = {}
        ---@type UnitWind.expects.NOT
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

    -- TODO switch case true/false
    --[[
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
    ]]--


    require("longod.DPSTooltips.combat"):RunTest(unitwind)
    require("longod.DPSTooltips.effect"):RunTest(unitwind)

    
    --dps:Initialize()

    if shutdown then
        logger:debug("Shutdown")
        os.exit()
    end
end

return Test
