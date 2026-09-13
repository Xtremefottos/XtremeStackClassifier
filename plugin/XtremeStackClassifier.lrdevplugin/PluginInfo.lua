local LrPathUtils = import "LrPathUtils"

local Locale = dofile(LrPathUtils.child(_PLUGIN.path, "Locale.lua"))

return {
    sectionsForTopOfDialog = function (f, propertyTable)
        local locale = "pt"
        local okPrefs, prefs = pcall(function ()
            return import("LrPrefs").prefsForPlugin()
        end)
        if okPrefs and prefs and prefs.locale then
            locale = prefs.locale
        end
        local body = Locale.t(locale, "infoBody")

        return {
            {
                title = "Xtreme Stack Classifier",
                synopsis = "v2.4 — Studio Marclay",
                bind_to_object = propertyTable,
                f:column {
                    spacing = f:control_spacing(),
                    f:static_text {
                        title = "Xtreme Stack Classifier 2.4",
                        font = "title",
                    },
                    f:static_text {
                        title = body,
                        width_in_chars = 78,
                        height_in_lines = 9,
                    },
                    f:static_text {
                        title = "Library → Plug-in Extras → Xtreme Stack Classifier",
                        width_in_chars = 78,
                    },
                    f:static_text {
                        title = "SDK 6–15  ·  Lightroom Classic only  ·  com.studiomarclay.xtreme.stackclassifier",
                        width_in_chars = 78,
                    },
                },
            },
        }
    end,
}
