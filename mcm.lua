local this = {}
this.name = "DPS Tooltips"
local config = require("longod.DPSTooltips.config")

function this.OnModConfigReady()
    local data = config.Load()

    local template = mwse.mcm.createTemplate(this.name)
    template:saveOnClose(config.configPath, data)
    template:register()

    local page = template:createSideBarPage {
        label = "Settings",
        description = (
            "This mod analytically calculates weapon DPS and displays it in weapon tooltips.\n" ..
            "You can know which weapons are actually stronger for your player character."
            )
    }

    page:createOnOffButton {
        label = "Enable DPS Tooltip",
        description = (
            "Enable this tooltip feature.\n" ..
            "\nDefault: On"
            ),
        variable = mwse.mcm.createTableVariable {
            id = "enable",
            table = data,
        }
    }

    page:createOnOffButton {
        label = "Display Min - Max",
        description = (
            "Show minimum to maximum DPS range. When disabled, only display maximum.\n" ..
            "In Morrowind, the weapon's damage range is determined by how long the attack key is held, not by RNG. Therefore, the average value does not become DPS.\n" ..
            "\nDefault: On"
            ),
        variable = mwse.mcm.createTableVariable {
            id = "minmaxRange",
            table = data,
        }
    }

    page:createOnOffButton {
        label = "Insert Pre-Divider",
        description = (
            "Insert a dividing line BEFORE the DPS display. Makes it easier to distinguish when using other tooltips mods.\n" ..
            "\nDefault: Off"
            ),
        variable = mwse.mcm.createTableVariable {
            id = "preDivider",
            table = data,
        }
    }

    page:createOnOffButton {
        label = "Insert Post-Divider",
        description = (
            "Insert a dividing line AFTER the DPS display. Makes it easier to distinguish when using other tooltips mods.\n" ..
            "\nDefault: Off"
            ),
        variable = mwse.mcm.createTableVariable {
            id = "postDivider",
            table = data,
        }
    }

    do
        local sub = page:createCategory("Accurate DPS")
        sub:createOnOffButton {
            label = "Use accurate weapon damage",
            description = (
                "Use accurate weapon damage dealt, taking into account the player character's attributes and the weapon condition.\n" ..
                "\nDefault: On"
                ),
            variable = mwse.mcm.createTableVariable {
                id = "accurateDamage",
                table = data,
            }
        }
        sub:createOnOffButton {
            label = "Use best weapon condition",
            description = (
                "Always determine DPS as the weapon with the best durability. This is useful when you want to consider theoretical values.\n" ..
                "\nDefault: On"
                ),
            variable = mwse.mcm.createTableVariable {
                id = "maxDurability",
                table = data,
            }
        }
    end

    do
        local sub = page:createCategory("Breakdown Appearance")
        sub:createOnOffButton {
            label = "Display DPS breakdown",
            description = (
                "You can know the difference in damage for each weapon swing type, and damages caused by enchantments.\n" ..
                "\nDefault: On"
                ),
            variable = mwse.mcm.createTableVariable {
                id = "breakdown",
                table = data,
            }
        }
        sub:createOnOffButton {
            label = "Coloring text",
            description = (
                "For each damage, add color to text by elemental or school.\n" ..
                "\nDefault: On"
                ),
            variable = mwse.mcm.createTableVariable {
                id = "coloring",
                table = data,
            }
        }
        sub:createOnOffButton {
            label = "Display effect icons",
            description = (
                "For each damage, display enchantment icons that affected it. For example, it makes it easier to see what the weakness spell has affected.\n" ..
                "\nDefault: On"
                ),
            variable = mwse.mcm.createTableVariable {
                id = "showIcon",
                table = data,
            }
        }
    end
    page:createDropdown {
        label = "Logging Level",
        description = (
            "Set the log level.\n" .. "\nDefault: INFO"
            ),
        options = {
            { label = "TRACE", value = "TRACE" },
            { label = "DEBUG", value = "DEBUG" },
            { label = "INFO",  value = "INFO" },
            { label = "WARN",  value = "WARN" },
            { label = "ERROR", value = "ERROR" },
            { label = "NONE",  value = "NONE" },
        },
        variable = mwse.mcm.createTableVariable { id = "logLevel", table = data },
        callback = function(self)
            local logger = require("longod.DPSTooltips.logger")
            ---@diagnostic disable: need-check-nil
            logger:setLogLevel(self.variable.value)
        end
    }
end

return this
