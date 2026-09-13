return {
    LrSdkVersion = 15.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = "com.studiomarclay.xtreme.stackclassifier",
    LrPluginName = "Xtreme Stack Classifier",
    LrPluginInfoUrl = "https://studiomarclay.com",

    VERSION = { major = 2, minor = 4, revision = 0, build = 2026 },

    LrInitPlugin = "PluginInit.lua",

    LrLibraryMenuItems = {
        {
            title = "Xtreme Stack Classifier (abrir no Windows)...",
            file = "XtremeStackClassifier.lua",
        },
        {
            title = "Classificar no Classic",
            file = "Dialog.lua",
        },
        {
            title = "Sincronizar classificações com o catálogo",
            file = "SyncBackToCatalog.lua",
        },
        {
            title = "Configurar executável Windows (.exe)...",
            file = "ConfigureExeMenu.lua",
        },
        {
            title = "Aplicar sidecars XMP",
            file = "ApplyXmp.lua",
        },
    },

    LrPluginInfoProvider = "PluginInfo.lua",
}
