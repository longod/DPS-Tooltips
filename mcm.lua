local this = {}
this.name = "DPS Tooltips"
local config = require("longod.DPSTooltips.config")

function this.OnModConfigReady()
    local data = config.Load()

    local template = mwse.mcm.createTemplate(this.name)
    template:saveOnClose(config.configPath, data)
    template:register()

    -- TODO descriptions

    local page = template:createSideBarPage{
        label = "Settings",
        description = (
            "Display DPS on the tooltip."
        )
    }

    page:createOnOffButton{
        label = "Enable DPS Tooltip",
        description = "Show Weapon DPS on tooltip.",
        variable = mwse.mcm.createTableVariable{
            id = "enable",
            table = data,
        }
    }

    page:createOnOffButton{
        label = "Display Min - Max",
        description = "\n\nDefault: On",
        variable = mwse.mcm.createTableVariable{
            id = "minmaxRange",
            table = data,
        }
    }

    page:createOnOffButton{
        label = "Insert Pre-Divider",
        description = "\n\nDefault: Off",
        variable = mwse.mcm.createTableVariable{
            id = "preDivider",
            table = data,
        }
    }

    page:createOnOffButton{
        label = "Insert Post-Divider",
        description = "\n\nDefault: Off",
        variable = mwse.mcm.createTableVariable{
            id = "postDivider",
            table = data,
        }
    }

    do
        local sub = page:createCategory("Accurate DPS")
        sub:createOnOffButton{
            label = "Use accurate damage",
            description = "Use accurate damage considering strength and weapon condition to DPS.\n\nDefault: On",
            variable = mwse.mcm.createTableVariable{
                id = "accurateDamage",
                table = data,
            }
        }
        sub:createOnOffButton{
            label = "Use best weapon condition",
            description = "",
            variable = mwse.mcm.createTableVariable{
                id = "maxDurability",
                table = data,
            }
        }
    end

    do
        local sub = page:createCategory("Breakdown Appearance")
        sub:createOnOffButton{
            label = "Display a breakdown of DPS",
            description = "Display a breakdown of DPS\n\nDefault: On",
            variable = mwse.mcm.createTableVariable{
                id = "breakdown",
                table = data,
            }
        }
        sub:createOnOffButton{
            label = "Coloring text",
            description = "\n\nDefault: On",
            variable = mwse.mcm.createTableVariable{
                id = "coloring",
                table = data,
            }
        }
        sub:createOnOffButton{
            label = "Show Effect Icons",
            description = "\n\nDefault: On",
            variable = mwse.mcm.createTableVariable{
                id = "showIcon",
                table = data,
            }
        }
    end
    page:createDropdown{
        label = "Logging Level",
        description = "Set the log level.\n\nDefault: INFO",
        options = {
            { label = "TRACE", value = "TRACE"},
            { label = "DEBUG", value = "DEBUG"},
            { label = "INFO", value = "INFO"},
            { label = "WARN", value = "WARN"},
            { label = "ERROR", value = "ERROR"},
            { label = "NONE", value = "NONE"},
        },
        variable = mwse.mcm.createTableVariable{ id = "logLevel", table = data },
        callback = function(self)
            local logger = require("longod.DPSTooltips.logger")
            ---@diagnostic disable: need-check-nil
            logger:setLogLevel(self.variable.value)
        end
    }
end

return this

