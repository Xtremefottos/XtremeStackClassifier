--[[
  XTREME STACK CLASSIFIER — v2.4
  Studio Marclay — Lightroom Classic SDK (Lua 5.1)
  
  Ponte única: Classic ↔ programa Windows.
]]

local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local LrSocket = import 'LrSocket'
local LrFunctionContext = import 'LrFunctionContext'

local XmpExporter = require 'XmpExporter'

-- Função utilitária para escapar strings para JSON seguro
local function escapeJson(str)
  if not str then return "" end
  str = tostring(str)
  str = str:gsub('\\', '\\\\')
  str = str:gsub('"', '\\"')
  str = str:gsub('\n', '\\n')
  str = str:gsub('\r', '\\r')
  str = str:gsub('\t', '\\t')
  return str
end

local function getSafeEnv(varName)
  if type(os) == "table" and type(os.getenv) == "function" then
    local ok, val = pcall(os.getenv, varName)
    if ok and val and val ~= "" then return val end
  end
  return nil
end

-- Tenta encontrar o executável ou script .bat no Windows
local function findWindowsExecutable()
  local prefs = LrPrefs.prefsForPlugin()
  if prefs.appExecutablePath and LrFileUtils.exists(prefs.appExecutablePath) then
    return prefs.appExecutablePath
  end

  local candidates = {}
  local isWin = (WIN_ENV == true) or (package.config:sub(1,1) == '\\')
  
  if isWin then
    local tempStd = nil
    pcall(function() tempStd = LrPathUtils.getStandardFilePath('temp') end)
    local appDataStd = nil
    pcall(function() appDataStd = LrPathUtils.getStandardFilePath('appData') end)

    local localAppData = getSafeEnv("LOCALAPPDATA")
    if (not localAppData or localAppData == "") and tempStd then
      localAppData = LrPathUtils.parent(tempStd)
    end

    local roaming = getSafeEnv("APPDATA") or appDataStd
    local userProfile = getSafeEnv("USERPROFILE")
    if (not userProfile or userProfile == "") and localAppData then
      userProfile = LrPathUtils.parent(localAppData)
    end

    local programData = getSafeEnv("PROGRAMDATA") or "C:\\ProgramData"
    local progFiles = getSafeEnv("PROGRAMFILES") or "C:\\Program Files"
    local progFilesX86 = getSafeEnv("PROGRAMFILES(X86)") or "C:\\Program Files (x86)"

    -- 1. Instalações padrão do Electron NSIS no Windows (AppData Local)
    if localAppData then
      table.insert(candidates, localAppData .. "\\Programs\\Xtreme Stack Classifier v2.2\\Xtreme Stack Classifier v2.2.exe")
      table.insert(candidates, localAppData .. "\\Programs\\Xtreme Stack Classifier v2.2\\Xtreme Stack Classifier.exe")
      table.insert(candidates, localAppData .. "\\Programs\\xtreme-stack-classifier\\Xtreme Stack Classifier.exe")
      table.insert(candidates, localAppData .. "\\Programs\\xtreme-stack-classifier\\Xtreme Stack Classifier v2.2.exe")
      table.insert(candidates, localAppData .. "\\Programs\\Xtreme Stack Classifier\\Xtreme Stack Classifier.exe")
      table.insert(candidates, localAppData .. "\\Programs\\Xtreme Stack Classifier\\Xtreme Stack Classifier v2.2.exe")
      table.insert(candidates, localAppData .. "\\XtremeStackClassifier\\Xtreme Stack Classifier.exe")
      table.insert(candidates, localAppData .. "\\Programs\\XtremeStackClassifier\\Xtreme Stack Classifier.exe")
      table.insert(candidates, localAppData .. "\\Programs\\xtreme_stack_classifier\\Xtreme Stack Classifier.exe")
    end

    -- 2. Atalhos do Menu Iniciar do Windows (como 'Xtreme Stack Classifier v2.2')
    if roaming then
      table.insert(candidates, roaming .. "\\Microsoft\\Windows\\Start Menu\\Programs\\Xtreme Stack Classifier v2.2.lnk")
      table.insert(candidates, roaming .. "\\Microsoft\\Windows\\Start Menu\\Programs\\Xtreme Stack Classifier.lnk")
      table.insert(candidates, roaming .. "\\Microsoft\\Windows\\Start Menu\\Programs\\Xtreme Stack Classifier\\Xtreme Stack Classifier v2.2.lnk")
      table.insert(candidates, roaming .. "\\Microsoft\\Windows\\Start Menu\\Programs\\Xtreme Stack Classifier\\Xtreme Stack Classifier.lnk")
      table.insert(candidates, roaming .. "\\Microsoft\\Windows\\Start Menu\\Programs\\xtreme-stack-classifier\\Xtreme Stack Classifier.lnk")
    end

    if programData then
      table.insert(candidates, programData .. "\\Microsoft\\Windows\\Start Menu\\Programs\\Xtreme Stack Classifier v2.2.lnk")
      table.insert(candidates, programData .. "\\Microsoft\\Windows\\Start Menu\\Programs\\Xtreme Stack Classifier.lnk")
      table.insert(candidates, programData .. "\\Microsoft\\Windows\\Start Menu\\Programs\\Xtreme Stack Classifier\\Xtreme Stack Classifier v2.2.lnk")
    end

    -- 3. Área de Trabalho (Desktop)
    if userProfile then
      table.insert(candidates, userProfile .. "\\Desktop\\Xtreme Stack Classifier v2.2.lnk")
      table.insert(candidates, userProfile .. "\\Desktop\\Xtreme Stack Classifier.lnk")
      table.insert(candidates, userProfile .. "\\Desktop\\Xtreme_Stack_Classifier.exe")
      table.insert(candidates, userProfile .. "\\Desktop\\Xtreme Stack Classifier.exe")
      table.insert(candidates, userProfile .. "\\Desktop\\XtremeStackClassifier_v2.3_Windows.exe")
      table.insert(candidates, userProfile .. "\\Desktop\\XtremeStackClassifier_v2.4_Windows.exe")
      table.insert(candidates, userProfile .. "\\Desktop\\Xtreme_Stack_Classifier_Portatil.exe")
      table.insert(candidates, userProfile .. "\\Desktop\\Abrir_Xtreme_Classifier.bat")
      table.insert(candidates, userProfile .. "\\Downloads\\Xtreme_Stack_Classifier.exe")
      table.insert(candidates, userProfile .. "\\Downloads\\Xtreme Stack Classifier.exe")
      table.insert(candidates, userProfile .. "\\Downloads\\XtremeStackClassifier-Desktop-Electron\\Abrir_Xtreme_Classifier.bat")
    end

    local desktop = nil
    pcall(function() desktop = LrPathUtils.getStandardFilePath('desktop') end)
    if desktop then
      table.insert(candidates, LrPathUtils.child(desktop, "Xtreme Stack Classifier v2.2.lnk"))
      table.insert(candidates, LrPathUtils.child(desktop, "Xtreme Stack Classifier.lnk"))
      table.insert(candidates, LrPathUtils.child(desktop, "Xtreme_Stack_Classifier.exe"))
      table.insert(candidates, LrPathUtils.child(desktop, "Xtreme Stack Classifier.exe"))
      table.insert(candidates, LrPathUtils.child(desktop, "Xtreme_Stack_Classifier_Portatil.exe"))
      table.insert(candidates, LrPathUtils.child(desktop, "Abrir_Xtreme_Classifier.bat"))
    end

    -- 4. Pastas padrão de instalação no Windows (Program Files)
    if progFiles then
      table.insert(candidates, progFiles .. "\\Xtreme Stack Classifier\\Xtreme Stack Classifier.exe")
      table.insert(candidates, progFiles .. "\\Xtreme Stack Classifier v2.2\\Xtreme Stack Classifier v2.2.exe")
      table.insert(candidates, progFiles .. "\\Xtreme Stack Classifier v2.2\\Xtreme Stack Classifier.exe")
    end
    if progFilesX86 then
      table.insert(candidates, progFilesX86 .. "\\Xtreme Stack Classifier\\Xtreme Stack Classifier.exe")
      table.insert(candidates, progFilesX86 .. "\\Xtreme Stack Classifier v2.2\\Xtreme Stack Classifier v2.2.exe")
      table.insert(candidates, progFilesX86 .. "\\Xtreme Stack Classifier v2.2\\Xtreme Stack Classifier.exe")
    end
    table.insert(candidates, "C:\\Program Files\\Xtreme Stack Classifier\\Xtreme Stack Classifier.exe")
    table.insert(candidates, "C:\\Program Files (x86)\\Xtreme Stack Classifier\\Xtreme Stack Classifier.exe")
    table.insert(candidates, "C:\\Lightroom Plugins\\Xtreme_Stack_Classifier.exe")
    table.insert(candidates, "C:\\Lightroom Plugins\\Abrir_Xtreme_Classifier.bat")

    -- 5. Pasta do próprio plugin ou vizinha
    if _PLUGIN and _PLUGIN.path then
      local pluginDir = _PLUGIN.path
      local parentDir = LrPathUtils.parent(pluginDir)
      table.insert(candidates, LrPathUtils.child(pluginDir, "Xtreme_Stack_Classifier.exe"))
      table.insert(candidates, LrPathUtils.child(parentDir, "Xtreme_Stack_Classifier.exe"))
      table.insert(candidates, LrPathUtils.child(parentDir, "Xtreme Stack Classifier.exe"))
      table.insert(candidates, LrPathUtils.child(parentDir, "Abrir_Xtreme_Classifier.bat"))
      table.insert(candidates, LrPathUtils.child(parentDir, "XtremeStackClassifier-Desktop-Electron\\Abrir_Xtreme_Classifier.bat"))
    end
  end

  for _, path in ipairs(candidates) do
    if path and LrFileUtils.exists(path) then
      prefs.appExecutablePath = path
      return path
    end
  end

  return nil
end

LrTasks.startAsyncTask(function()
  local catalog = LrApplication.activeCatalog()
  local targetPhotos = catalog:getTargetPhotos()

  if not targetPhotos or #targetPhotos == 0 then
    LrDialogs.message(
      "Xtreme Stack Classifier",
      "Nenhuma foto selecionada no Lightroom Classic.\n\nSelecione uma ou mais fotos (ou pilhas inteiras) no modulo Biblioteca antes de abrir o plugin.",
      "info"
    )
    return
  end

  -- 1. Coleta e Agrupamento das Pilhas (Stacks) e Metadados do Lightroom Classic
  local stacksMap = {}
  local stacksList = {}
  local allPhotosList = {}
  local firstFolderPath = nil

  -- Funções auxiliares seguras para evitar erro de chaves desconhecidas em versões do Lightroom
  local function safeRaw(photo, key, defaultVal)
    local ok, val = pcall(function() return photo:getRawMetadata(key) end)
    if ok and val ~= nil then return val end
    return defaultVal
  end

  local function safeFormatted(photo, key, defaultVal)
    local ok, val = pcall(function() return photo:getFormattedMetadata(key) end)
    if ok and val ~= nil then return val end
    return defaultVal
  end

  -- Função ultra-robusta para obter caminho do arquivo, nome e pasta no Lightroom Classic
  local function getPhotoInfo(photo)
    local fPath = ""
    local fName = ""
    local fFolder = ""

    -- 1. Tentativa direta via getRawMetadata('path')
    local ok1, val1 = pcall(function() return photo:getRawMetadata('path') end)
    if ok1 and val1 and type(val1) == "string" and val1 ~= "" then
      fPath = val1
    end

    -- 2. Tentativa propriedade photo.path
    if fPath == "" then
      pcall(function()
        if photo.path and type(photo.path) == "string" and photo.path ~= "" then
          fPath = photo.path
        end
      end)
    end

    -- 3. Se for cópia virtual, busca o arquivo mestre original
    if fPath == "" then
      pcall(function()
        local isVC = photo:getRawMetadata('isVirtualCopy')
        if isVC then
          local master = photo:getRawMetadata('masterPhoto')
          if master then
            fPath = master:getRawMetadata('path') or master.path or ""
          end
        end
      end)
    end

    -- 4. Obtém o nome real do arquivo no catálogo
    local okName, valName = pcall(function() return photo:getFormattedMetadata('fileName') end)
    if okName and valName and type(valName) == "string" and valName ~= "" then
      fName = valName
    end
    if fName == "" and fPath ~= "" then
      fName = LrPathUtils.leafName(fPath)
    end

    -- 5. Obtém a pasta física do arquivo
    if fPath ~= "" then
      fFolder = LrPathUtils.parent(fPath) or ""
    end
    if fFolder == "" then
      pcall(function()
        local folderObj = photo:getRawMetadata('folder')
        if folderObj and folderObj.getPath then
          local p = folderObj:getPath()
          if p and type(p) == "string" and p ~= "" then
            fFolder = p
          end
        end
      end)
    end

    -- 6. Se tínhamos a pasta e o nome, mas fPath estava vazio, reconstitui
    if fPath == "" and fFolder ~= "" and fName ~= "" then
      fPath = LrPathUtils.child(fFolder, fName)
    end

    -- 7. Fallback para nome caso nada tenha retornado
    if fName == "" then
      fName = "Foto_" .. tostring(#allPhotosList + 1)
    end

    return fPath, fName, fFolder
  end

  for _, photo in ipairs(targetPhotos) do
    local filePath, fileName, folderPath = getPhotoInfo(photo)
    if not firstFolderPath and folderPath ~= "" then
      firstFolderPath = folderPath
    end

    local rating = safeRaw(photo, 'rating', 0)
    local pickStatus = safeRaw(photo, 'pickStatus', 0)
    local colorLabel = safeRaw(photo, 'colorNameForLabel', "none")
    
    local rawStackPos = safeRaw(photo, 'stackPositionInFolder', 1)
    local stackPos = tonumber(rawStackPos) or 1
    local stackCount = tonumber(safeRaw(photo, 'stackCountInFolder', 1)) or 1
    local isCollapsed = safeRaw(photo, 'stackInFolderIsCollapsed', 0)
    
    -- Metadados de captura
    local camera = safeFormatted(photo, 'camera', "")
    if camera == "" then camera = safeRaw(photo, 'camera', "Camera Detectada") end
    local lens = safeFormatted(photo, 'lens', "")
    if lens == "" then lens = safeRaw(photo, 'lens', "Lente Principal") end
    local iso = tonumber(safeRaw(photo, 'isoSpeedRating', 0)) or 0
    local shutter = safeFormatted(photo, 'shutterSpeed', "")
    local aperture = safeFormatted(photo, 'aperture', "")
    local focalLength = safeFormatted(photo, 'focalLength', "")
    local captureTime = safeFormatted(photo, 'dateTimeOriginal', "")
    local fileSize = safeFormatted(photo, 'fileSize', "")

    -- Identificador único de pilha
    local stackKey = folderPath .. "_stack_" .. tostring(isCollapsed) .. "_" .. tostring(math.floor((#stacksList) / 8))
    if stackCount > 1 then
      stackKey = folderPath .. "_lrstack_" .. tostring(math.floor(stackPos / 10))
    end

    if not stacksMap[stackKey] then
      stacksMap[stackKey] = {
        id = "stack_" .. tostring(#stacksList + 1),
        name = "Pilha " .. tostring(#stacksList + 1),
        folder = folderPath,
        photos = {}
      }
      table.insert(stacksList, stacksMap[stackKey])
    end

    local photoData = {
      id = tostring(#allPhotosList + 1),
      name = fileName,
      fileName = fileName,
      folder = folderPath,
      path = filePath,
      fullPath = filePath,
      rating = rating,
      pickStatus = pickStatus,
      colorLabel = colorLabel,
      camera = camera,
      lens = lens,
      iso = iso,
      shutter = shutter,
      aperture = aperture,
      focalLength = focalLength,
      captureTime = captureTime,
      fileSize = fileSize,
      stackPosition = #stacksMap[stackKey].photos + 1
    }

    table.insert(stacksMap[stackKey].photos, photoData)
    table.insert(allPhotosList, photoData)
  end

  if #stacksList == 0 then
    stacksList = { { id = "stack_1", name = "Selecao Atual", folder = firstFolderPath or "", photos = allPhotosList } }
  end

  -- 2. Montagem do JSON estruturado
  local jsonParts = {}
  table.insert(jsonParts, '{\n')
  table.insert(jsonParts, '  "type": "catalog_selection",\n')
  table.insert(jsonParts, string.format('  "timestamp": %d,\n', os.time()))
  table.insert(jsonParts, string.format('  "count": %d,\n', #allPhotosList))
  table.insert(jsonParts, string.format('  "stackCount": %d,\n', #stacksList))
  table.insert(jsonParts, string.format('  "sessionFolder": "%s",\n', escapeJson(firstFolderPath or "")))
  
  -- Array de Pilhas
  table.insert(jsonParts, '  "stacks": [\n')
  for sIdx, st in ipairs(stacksList) do
    table.insert(jsonParts, '    {\n')
    table.insert(jsonParts, string.format('      "id": "%s",\n', escapeJson(st.id)))
    table.insert(jsonParts, string.format('      "name": "%s",\n', escapeJson(st.name)))
    table.insert(jsonParts, string.format('      "folder": "%s",\n', escapeJson(st.folder)))
    table.insert(jsonParts, '      "photos": [\n')
    for pIdx, p in ipairs(st.photos) do
      table.insert(jsonParts, '        {\n')
      table.insert(jsonParts, string.format('          "id": "%s",\n', escapeJson(p.id)))
      table.insert(jsonParts, string.format('          "name": "%s",\n', escapeJson(p.name)))
      table.insert(jsonParts, string.format('          "fileName": "%s",\n', escapeJson(p.fileName)))
      table.insert(jsonParts, string.format('          "path": "%s",\n', escapeJson(p.path)))
      table.insert(jsonParts, string.format('          "fullPath": "%s",\n', escapeJson(p.fullPath)))
      table.insert(jsonParts, string.format('          "folder": "%s",\n', escapeJson(p.folder)))
      table.insert(jsonParts, string.format('          "rating": %d,\n', p.rating))
      table.insert(jsonParts, string.format('          "pickStatus": %d,\n', p.pickStatus))
      table.insert(jsonParts, string.format('          "colorLabel": "%s",\n', escapeJson(p.colorLabel)))
      table.insert(jsonParts, string.format('          "camera": "%s",\n', escapeJson(p.camera)))
      table.insert(jsonParts, string.format('          "lens": "%s",\n', escapeJson(p.lens)))
      table.insert(jsonParts, string.format('          "iso": %d,\n', p.iso))
      table.insert(jsonParts, string.format('          "shutter": "%s",\n', escapeJson(p.shutter)))
      table.insert(jsonParts, string.format('          "aperture": "%s",\n', escapeJson(p.aperture)))
      table.insert(jsonParts, string.format('          "focalLength": "%s",\n', escapeJson(p.focalLength)))
      table.insert(jsonParts, string.format('          "captureTime": "%s",\n', escapeJson(p.captureTime)))
      table.insert(jsonParts, string.format('          "fileSize": "%s",\n', escapeJson(p.fileSize)))
      table.insert(jsonParts, string.format('          "stackPosition": %d\n', p.stackPosition))
      table.insert(jsonParts, '        }' .. (pIdx < #st.photos and ',' or '') .. '\n')
    end
    table.insert(jsonParts, '      ]\n')
    table.insert(jsonParts, '    }' .. (sIdx < #stacksList and ',' or '') .. '\n')
  end
  table.insert(jsonParts, '  ],\n')

  -- Array unificado de fotos com suporte total a todos os atributos
  table.insert(jsonParts, '  "photos": [\n')
  for pIdx, p in ipairs(allPhotosList) do
    table.insert(jsonParts, '    {\n')
    table.insert(jsonParts, string.format('      "id": "%s",\n', escapeJson(p.id)))
    table.insert(jsonParts, string.format('      "name": "%s",\n', escapeJson(p.name)))
    table.insert(jsonParts, string.format('      "fileName": "%s",\n', escapeJson(p.fileName)))
    table.insert(jsonParts, string.format('      "path": "%s",\n', escapeJson(p.path)))
    table.insert(jsonParts, string.format('      "fullPath": "%s",\n', escapeJson(p.fullPath)))
    table.insert(jsonParts, string.format('      "folder": "%s",\n', escapeJson(p.folder)))
    table.insert(jsonParts, string.format('      "rating": %d,\n', p.rating))
    table.insert(jsonParts, string.format('      "pickStatus": %d,\n', p.pickStatus))
    table.insert(jsonParts, string.format('      "colorLabel": "%s",\n', escapeJson(p.colorLabel)))
    table.insert(jsonParts, string.format('      "camera": "%s",\n', escapeJson(p.camera)))
    table.insert(jsonParts, string.format('      "lens": "%s",\n', escapeJson(p.lens)))
    table.insert(jsonParts, string.format('      "iso": %d,\n', p.iso))
    table.insert(jsonParts, string.format('      "shutter": "%s",\n', escapeJson(p.shutter)))
    table.insert(jsonParts, string.format('      "aperture": "%s",\n', escapeJson(p.aperture)))
    table.insert(jsonParts, string.format('      "focalLength": "%s",\n', escapeJson(p.focalLength)))
    table.insert(jsonParts, string.format('      "captureTime": "%s",\n', escapeJson(p.captureTime)))
    table.insert(jsonParts, string.format('      "fileSize": "%s",\n', escapeJson(p.fileSize)))
    table.insert(jsonParts, string.format('      "stackPosition": %d\n', p.stackPosition))
    table.insert(jsonParts, '    }' .. (pIdx < #allPhotosList and ',' or '') .. '\n')
  end
  table.insert(jsonParts, '  ]\n')
  table.insert(jsonParts, '}')

  local jsonString = table.concat(jsonParts)

  -- 3. Salva o arquivo de intercâmbio em locais estratégicos do Windows
  local tempDir = nil
  pcall(function() tempDir = LrPathUtils.getStandardFilePath('temp') end)
  local tempPayloadPath = tempDir and LrPathUtils.child(tempDir, "xtreme_lrc_payload.json") or "C:\\Windows\\Temp\\xtreme_lrc_payload.json"
  
  -- Grava no %TEMP%
  local fTemp = io.open(tempPayloadPath, "w")
  if fTemp then
    fTemp:write(jsonString)
    fTemp:close()
  end

  -- Também salva na pasta da sessão fotográfica (se acessível)
  local sessionPayloadPath = nil
  if firstFolderPath and firstFolderPath ~= "" then
    sessionPayloadPath = LrPathUtils.child(firstFolderPath, "xtreme_lrc_payload.json")
    local fSess = io.open(sessionPayloadPath, "w")
    if fSess then
      fSess:write(jsonString)
      fSess:close()
    end
  end

  -- Versão compacta em uma linha única para transmissão via socket sem quebras intermediárias
  local compactJson = jsonString:gsub("[\r\n]+%s*", " ")

  -- 4. Tenta enviar em tempo real via Socket TCP (127.0.0.1:49152) se o app já estiver aberto
  local socketDelivered = false
  local socketAttemptDone = false

  pcall(function()
    LrFunctionContext.callWithContext("SendToClassifierSocket", function(sockContext)
      local sender = LrSocket.bind {
        functionContext = sockContext,
        plugin = _PLUGIN,
        port = 49152,
        mode = "send",
        onConnected = function(socket)
          socket:send(compactJson .. "\n")
          socketDelivered = true
          LrTasks.sleep(0.15)
          socket:close()
          socketAttemptDone = true
        end,
        onError = function(socket, err)
          socketAttemptDone = true
        end,
        onClosed = function(socket)
          socketAttemptDone = true
        end
      }

      -- Espera até 800ms para ver se o socket conectou e enviou
      local waitStart = os.clock()
      while not socketAttemptDone and (os.clock() - waitStart) < 0.8 do
        LrTasks.sleep(0.05)
      end
    end)
  end)

  if socketDelivered then
    LrDialogs.showBezel(string.format("Xtreme Stack Classifier: %d fotos sincronizadas instantaneamente!", #allPhotosList), 2.5)
    return
  end

  -- 5. Se o Socket não estava aberto, inicia o aplicativo no Windows
  local exePath = findWindowsExecutable()

  if exePath then
    -- No Windows: 'start "" "caminho_exe" "argumento"' desacopla o processo e não bloqueia o Lightroom
    local launchCmd = string.format('start "" "%s" "%s"', exePath, tempPayloadPath)
    LrTasks.execute(launchCmd)

    LrDialogs.showBezel(
      string.format("Abrindo Xtreme Stack Classifier no Windows com %d fotos...", #allPhotosList),
      3
    )
  else
    -- Diálogo explicativo e intuitivo para localizar o .exe ou .bat
    local choice = LrDialogs.confirm(
      "Xtreme Stack Classifier - Fotos Prontas",
      string.format(
        "Sucesso! %d fotos (%d pilhas) do Lightroom Classic foram preparadas.\n\nArquivo de fotos salvo em:\n%s\n\nAbra o 'Xtreme Stack Classifier v2.2' no seu Menu Iniciar para carregar automaticamente, ou selecione o executavel agora:",
        #allPhotosList, #stacksList, tempPayloadPath
      ),
      "Localizar Executavel (.exe / .bat)",
      "Fechar",
      "Abrir Pasta das Fotos"
    )

    if choice == "ok" then
      local chosen = LrDialogs.runOpenPanel {
        title = "Selecione o Xtreme_Stack_Classifier.exe ou Abrir_Xtreme_Classifier.bat",
        canChooseFiles = true,
        canChooseDirectories = false,
        allowsMultipleSelection = false,
        fileTypes = { "exe", "bat", "lnk" },
      }

      if chosen and #chosen > 0 then
        local prefs = LrPrefs.prefsForPlugin()
        prefs.appExecutablePath = chosen[1]

        local launchCmd = string.format('start "" "%s" "%s"', chosen[1], tempPayloadPath)
        LrTasks.execute(launchCmd)
        
        LrDialogs.showBezel("Xtreme Stack Classifier iniciado com sucesso!", 3)
      end
    elseif choice == "other" then
      -- Abre a pasta no Windows Explorer
      local dirToOpen = sessionPayloadPath and firstFolderPath or tempDir
      if dirToOpen then
        LrTasks.execute(string.format('start "" explorer.exe "%s"', dirToOpen))
      end
    end
  end
end)
