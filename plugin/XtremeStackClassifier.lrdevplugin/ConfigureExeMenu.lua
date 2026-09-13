--[[
  ConfigureExeMenu.lua
  Permite ao fotógrafo apontar o executável Xtreme_Stack_Classifier.exe ou Abrir_Xtreme_Classifier.bat.
]]

local LrDialogs = import 'LrDialogs'
local LrPrefs = import 'LrPrefs'
local LrFileUtils = import 'LrFileUtils'

local prefs = LrPrefs.prefsForPlugin()
local currentPath = prefs.appExecutablePath or "Nenhum selecionado (usando deteccao automatica)"

local chosen = LrDialogs.runOpenPanel {
  title = "Selecione o Xtreme_Stack_Classifier.exe ou Abrir_Xtreme_Classifier.bat",
  canChooseFiles = true,
  canChooseDirectories = false,
  allowsMultipleSelection = false,
  fileTypes = { "exe", "bat", "lnk" },
}

if chosen and #chosen > 0 then
  prefs.appExecutablePath = chosen[1]
  LrDialogs.message(
    "Configuracao Salva",
    "O executavel do Xtreme Stack Classifier foi configurado com sucesso:\n\n" .. chosen[1],
    "info"
  )
end
