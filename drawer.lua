local Drawer = {}
function Drawer.new()
    local drawer = {}
    setmetatable(drawer, { __index = Drawer })
    return drawer
end

local shared = require("longod.DPSTooltips.shared")
local logger = require("longod.DPSTooltips.logger")
local config = require("longod.DPSTooltips.config").Load()

local function PrintTable(table, indent)
    if not indent then
        indent = 0
    end
    ---@diagnostic disable: need-check-nil
    for k, v in pairs(table) do
        local space = string.rep("    ", indent)
        local str = space .. k .. ": "
        if type(v) == "table" then
            logger:trace(str .. "{")
            PrintTable(v, indent + 1)
            logger:trace(space .. "}")
        elseif type(v) == 'boolean' then
            logger:trace(str .. tostring(v))
        else
            logger:trace(str .. v)
        end
    end
end

local function DisplayStub(data)
    if config.logLevel == "TRACE" then
        PrintTable(data)
    end
end

function Drawer.Initialize(self)
    self.names = {
        [shared.key.attack] = { gmst = tes3.gmst.sAttack, name = nil },
        [shared.key.slash] = { gmst = tes3.gmst.sSlash, name = nil },
        [shared.key.thrust] = { gmst = tes3.gmst.sThrust, name = nil },
        [shared.key.chop] = { gmst = tes3.gmst.sChop, name = nil },
        [shared.key.fire] = { gmst = tes3.gmst.sEffectFireDamage, name = nil },
        [shared.key.frost] = { gmst = tes3.gmst.sEffectFrostDamage, name = nil },
        [shared.key.shock] = { gmst = tes3.gmst.sEffectShockDamage, name = nil },
        [shared.key.poison] = { gmst = tes3.gmst.sEffectPoison, name = nil, },
        [shared.key.absorbHealth] = { gmst = tes3.gmst.sEffectAbsorbHealth, name = nil, },
        [shared.key.damageHealth] = { gmst = tes3.gmst.sEffectDamageHealth, name = nil, },
        [shared.key.drainHealth] = { gmst = tes3.gmst.sEffectDrainHealth, name = nil, },
        [shared.key.sunDamage] = { gmst = tes3.gmst.sEffectSunDamage, name = nil, },
    }

    self.colors = {
        [shared.key.fire] = { palette = tes3.palette.healthColor, color = {
            0.78431379795074, 0.23529413342476, 0.11764706671238,
        }
        },
        [shared.key.frost] = { palette = tes3.palette.miscColor, color = {
            0, 0.80392163991928, 0.80392163991928,
        }
        },
        [shared.key.shock] = { palette = tes3.palette.linkColor, color = {
            0.43921571969986, 0.49411767721176, 0.8117647767067,
        }
        },
        [shared.key.poison] = { palette = tes3.palette.fatigueColor, color = {
            0, 0.58823531866074, 0.23529413342476,
        }
        },
        [shared.key.absorbHealth] = { palette = nil, color = nil },
        [shared.key.damageHealth] = { palette = nil, color = nil },
        [shared.key.drainHealth] = { palette = nil, color = nil },
        [shared.key.sunDamage] = { palette = nil, color = nil },
    }

    for k, v in pairs(self.names) do
        if v.gmst and not v.name then
            v.name = tes3.findGMST(v.gmst).value
        end
    end
    for k, v in pairs(self.colors) do
        if v.palette and not v.color then
            v.color = tes3ui.getPalette(v.palette)
        end
    end
    -- PrintTable(self.names)
    -- PrintTable(self.colors)

    self.headerColor = tes3ui.getPalette(tes3.palette.headerColor)
    self.weakColor = tes3ui.getPalette(tes3.palette.disabledColor)

    self.idDPSLabel = tes3ui.registerID("DPSTooltips_DPSLabel")
    self.idBorder = tes3ui.registerID("DPSTooltips_Border")
    self.idWeaponBlock = tes3ui.registerID("DPSTooltips_WeaponBlock")
    self.idWeaponIcon = tes3ui.registerID("DPSTooltips_WeaponIcon")
    self.idWeaponLabel = tes3ui.registerID("DPSTooltips_WeaponLabel")
    self.idEffectBlock = tes3ui.registerID("DPSTooltips_EffectBlock")
    self.idEffectIcon = tes3ui.registerID("DPSTooltips_EffectIcon")
    self.idEffectLabel = tes3ui.registerID("DPSTooltips_EffectLabel")
end

local function CreateBlock(element, id, color)
    local block = element:createBlock { id = id }
    block.autoWidth = true
    block.autoHeight = true
    if color then
        block.color = color
    end
    return block
end

local function CreateLabel(element, id, text, color)
    local label = element:createLabel { text = text, id = id }
    label.wrapText = true
    if color then
        label.color = color
    end
    return label
end

function Drawer.DisplayDPS(self, element, data)
    local text = nil
    -- need localize?
    if config.minmaxRange then
        text = string.format("DPS: %.1f - %.1f", data.weaponDamageRange.min + data.effectTotal,
            data.weaponDamageRange.max + data.effectTotal)
    else
        text = string.format("DPS: %.1f", data.weaponDamageRange.max + data.effectTotal)
    end
    local label = CreateLabel(element, self.idDPSLabel, text)
    label.color = self.headerColor
end

function Drawer.DisplayWeaponDPS(self, element, data)
    -- TODO fixed order if undsired order
    for k, v in pairs(data.weaponDamages) do
        local block = CreateBlock(element, self.idWeaponBlock)
        block.borderAllSides = 1

        -- icons if exists
        if data.icons[k] then
            for _, path in ipairs(data.icons[k]) do
                local icon = block:createImage({
                    id = self.idWeaponIcon,
                    path = string.format("icons\\%s", path)
                })
                icon.borderTop = 1
                icon.borderRight = 6
            end
        end

        -- label
        local text = nil
        if config.minmaxRange then
            text = string.format("%s: %.1f - %.1f", self.names[k].name, v.min, v.max)
        else
            text = string.format("%s: %.1f", self.names[k].name, v.max)
        end
        local label = CreateLabel(block, self.idWeaponLabel, text)
        if not data.highestType[k] and self.weakColor then
            label.color = self.weakColor
        end
    end
end

function Drawer.DisplayEnchantmentDPS(self, element, data)
    -- TODO fixed order if undsired order
    for k, v in pairs(data.effectDamages) do
        if v > 0 then
            local block = CreateBlock(element, self.idEffectBlock)
            block.borderAllSides = 1

            -- icons
            if data.icons[k] then
                for _, path in ipairs(data.icons[k]) do
                    local icon = block:createImage({
                        id = self.idEffectIcon,
                        path = string.format("icons\\%s", path)
                    })
                    icon.borderTop = 1
                    icon.borderRight = 6
                end
            end

            -- label
            local label = CreateLabel(block, self.idEffectLabel, string.format("%s: %.1f", self.names[k].name, v))
            local col = self.colors[k]
            if col and col.color then
                label.color = col.color
            end
        end
    end
end

function Drawer.Display(self, tooltip, data)
    if not data then
        return
    end

    DisplayStub(data)

    if not tooltip then
        return
    end
    -- tooltip:createDivider()

    self:DisplayDPS(tooltip, data)

    if config.breakdown then
        local frame = tooltip:createThinBorder({ id = self.idBorder })
        frame.flowDirection = "top_to_bottom"
        frame.borderAllSides = 4
        frame.borderLeft = 6
        frame.borderRight = 6
        frame.autoWidth = true
        frame.autoHeight = true
        -- for children layout
        frame.paddingAllSides = 4
        frame.paddingLeft = 6
        frame.paddingRight = 6

        self:DisplayWeaponDPS(frame, data)
        self:DisplayEnchantmentDPS(frame, data)
    end

    -- tooltip:createDivider()

    tooltip:updateLayout()
end

return Drawer
