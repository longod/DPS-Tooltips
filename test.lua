local Test = {}
function Test.new()
    local test = {}
    setmetatable(test, { __index = Test })
    return test
end

function Test.Run(self, shutdown)
    -- todo use non-persisitent config for testing
    ---@diagnostic disable: need-check-nil
    local logger = require("longod.DPSTooltips.logger")
    local dps = require("longod.DPSTooltips.dps").new()

    local unitwind = require("unitwind").new {
        enabled = true,
        beforeAll = function()
            -- TODO logger set warn for spamming
            dps:Initialize()
        end,
        -- afterAll = function ()
        -- TODO logger set default
        -- end,
    }

    -- global mock
    -- todo switch case true/false
    unitwind:mock(tes3, "findGMST", function(id)
        if id == tes3.gmst.fDamageStrengthBase then
            return { value = 0.5 }
        elseif id == tes3.gmst.fDamageStrengthMult then
            return { value = 0.1 }
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
    unitwind:mock(tes3ui, "getPalette", function(name)
        return { 1, 1, 1 }
    end)

    -- TODO 
    -- tes3.getMagicEffectName

    unitwind:start("DPSTooltips Unittest")

    dps:RunTest(unitwind)

    unitwind:finish()

    if shutdown then
        logger:debug("Shutdown")
        os.exit()
    end
end

return Test
