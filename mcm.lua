local this = {}
this.name = "DPS Tooltips"
local config = require("longod.DPSTooltips.config")

function this.OnModConfigReady()
    local data = config.Load()

    local template = mwse.mcm.createTemplate(this.name)
    template:saveOnClose(config.configPath, data)
    template:register()

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
        label = "Use accurate damage",
        description = "Use accurate damage considering strength and weapon condition to DPS.",
        variable = mwse.mcm.createTableVariable{
            id = "accurateDamage",
            table = data,
        }
    }
    page:createOnOffButton{
        label = "Display Min - Max",
        description = "",
        variable = mwse.mcm.createTableVariable{
            id = "minmaxRange",
            table = data,
        }
    }
    page:createOnOffButton{
        label = "Display a breakdown of DPS",
        description = "Display a breakdown of DPS",
        variable = mwse.mcm.createTableVariable{
            id = "breakdown",
            table = data,
        }
    }
    page:createDropdown{
        label = "Logging Level",
        description = "Set the log level.",
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

return this.OnModConfigReady

