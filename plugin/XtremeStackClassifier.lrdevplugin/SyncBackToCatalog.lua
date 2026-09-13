--[[
  SyncBackToCatalog.lua
  Lê as classificações (estrelas 0-5, picks/rejeitadas, rótulos de cor e pilhas)
  feitas no Xtreme Stack Classifier e atualiza as fotos no Catálogo do Lightroom Classic.
]]

local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrProgressScope = import 'LrProgressScope'

-- Normalizador de caminhos no Windows/Mac
local function normPath(p)
  if not p or type(p) ~= "string" then return "" end
  return p:gsub("\\", "/"):lower()
end

local function leafName(p)
  if not p or type(p) ~= "string" then return "" end
  return (p:match("([^\\/]+)$") or p):lower()
end

local function extractVal(str, key)
  local quoted = string.match(str, '"' .. key .. '"%s*:%s*"([^"]*)"')
  if quoted then return quoted end
  return string.match(str, '"' .. key .. '"%s*:%s*([%-%w%.]+)')
end

-- Parser de JSON para Lua 5.1
local function parsePhotoUpdates(jsonStr)
  local updates = {}
  local clean = jsonStr
  for objStr in clean:gmatch("%{([^%}]+)%}") do
    local rating = extractVal(objStr, "rating")
    local pickStatus = extractVal(objStr, "pickStatus")
    local colorLabel = extractVal(objStr, "colorLabel")

    if rating or pickStatus or colorLabel then
      local p = extractVal(objStr, "path") or extractVal(objStr, "filePath") or extractVal(objStr, "fullPath")
      local fn = extractVal(objStr, "fileName") or extractVal(objStr, "name")
      local id = extractVal(objStr, "id")
      local isCover = extractVal(objStr, "isStackCover")
      local stackPos = extractVal(objStr, "stackPosition")

      if p then
        p = p:gsub("\\\\", "\\")
      end
      if not fn and p then
        fn = p:match("([^\\/]+)$")
      end

      table.insert(updates, {
        path = p,
        fileName = fn,
        id = id,
        rating = rating and tonumber(rating),
        pickStatus = pickStatus and tonumber(pickStatus),
        colorLabel = colorLabel and colorLabel:lower() or "",
        isStackCover = (isCover == "true"),
        stackPosition = stackPos and tonumber(stackPos) or 1
      })
    end
  end
  return updates
end

LrTasks.startAsyncTask(function()
  local catalog = LrApplication.activeCatalog()
  local progress = LrProgressScope {
    title = "Sincronizando Metadados com Xtreme Stack Classifier...",
  }
  progress:setCancelable(true)

  -- 1. Busca abrangente do arquivo de feedback JSON
  local possiblePaths = {}
  
  -- Local 1: %TEMP%/xtreme_lrc_feedback.json
  local tempDir = nil
  pcall(function() tempDir = LrPathUtils.getStandardFilePath('temp') end)
  if tempDir then
    table.insert(possiblePaths, LrPathUtils.child(tempDir, "xtreme_lrc_feedback.json"))
  end
  table.insert(possiblePaths, "C:\\Windows\\Temp\\xtreme_lrc_feedback.json")

  -- Local 2: Pasta das fotos selecionadas no catálogo
  local targetPhotos = catalog:getTargetPhotos()
  if targetPhotos and #targetPhotos > 0 then
    local pPath = targetPhotos[1]:getRawMetadata('path')
    if pPath then
      local photoDir = LrPathUtils.parent(pPath)
      if photoDir then
        table.insert(possiblePaths, LrPathUtils.child(photoDir, "xtreme_lrc_feedback.json"))
      end
    end
  end

  -- Local 3: Pasta de Downloads do usuário
  local homeDir = nil
  pcall(function() homeDir = LrPathUtils.getStandardFilePath('home') or LrPathUtils.getStandardFilePath('documents') end)
  if homeDir then
    table.insert(possiblePaths, LrPathUtils.child(homeDir, "Downloads\\xtreme_lrc_feedback.json"))
  end

  local feedbackPath = nil
  for _, p in ipairs(possiblePaths) do
    if LrFileUtils.exists(p) then
      feedbackPath = p
      break
    end
  end

  -- Se não encontrou automaticamente, permite selecionar manualmente
  if not feedbackPath then
    local chosen = LrDialogs.runOpenPanel {
      title = "Localizar xtreme_lrc_feedback.json",
      prompt = "Selecionar Feedback JSON do Xtreme",
      canChooseFiles = true,
      canChooseDirectories = false,
      allowsMultipleSelection = false,
      fileTypes = { "json" },
    }
    if chosen and #chosen > 0 then
      feedbackPath = chosen[1]
    end
  end

  -- 2. Indexação inteligente das fotos do catálogo para matching instantâneo
  local photosToScan = targetPhotos
  if not photosToScan or #photosToScan == 0 then
    photosToScan = catalog:getAllPhotos()
  end

  local indexByPath = {}
  local indexByName = {}
  for _, photo in ipairs(photosToScan) do
    local pPath = photo:getRawMetadata('path')
    if pPath then
      indexByPath[normPath(pPath)] = photo
      indexByName[leafName(pPath)] = photo
    end
  end

  local updatedCount = 0
  local pickedPhotos = {}
  local rejectedCount = 0
  local starCounts = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0 }

  -- 3. Se temos o JSON de feedback, aplica todas as alterações no catálogo
  if feedbackPath and LrFileUtils.exists(feedbackPath) then
    local file = io.open(feedbackPath, "r")
    if file then
      local content = file:read("*a")
      file:close()

      local updates = parsePhotoUpdates(content)

      if #updates > 0 then
        catalog:withWriteAccessDo("Sincronizar Xtreme com Catalogo", function()
          for _, item in ipairs(updates) do
            local matchedPhoto = nil
            if item.path then
              matchedPhoto = indexByPath[normPath(item.path)]
            end
            if not matchedPhoto and item.fileName then
              matchedPhoto = indexByName[leafName(item.fileName)]
            end

            if matchedPhoto then
              local changed = false

              -- Rating (0 a 5 estrelas)
              if item.rating ~= nil and item.rating >= 0 and item.rating <= 5 then
                matchedPhoto:setRawMetadata('rating', item.rating)
                starCounts[item.rating] = (starCounts[item.rating] or 0) + 1
                changed = true
              end

              -- Pick Status (1 = Escolhida / Flag, -1 = Rejeitada / X, 0 = Sem bandeira)
              if item.pickStatus ~= nil and (item.pickStatus == 1 or item.pickStatus == -1 or item.pickStatus == 0) then
                matchedPhoto:setRawMetadata('pickStatus', item.pickStatus)
                changed = true
              end

              -- Rótulo de cor (red, yellow, green, blue, purple ou "" para limpar)
              if item.colorLabel ~= nil then
                local col = item.colorLabel:lower()
                if col == "none" or col == "" then
                  matchedPhoto:setRawMetadata('colorNameForLabel', '')
                elseif col == "red" or col == "yellow" or col == "green" or col == "blue" or col == "purple" then
                  matchedPhoto:setRawMetadata('colorNameForLabel', col)
                end
                changed = true
              end

              if item.pickStatus == 1 or item.rating == 5 then
                table.insert(pickedPhotos, matchedPhoto)
              elseif item.pickStatus == -1 then
                rejectedCount = rejectedCount + 1
              end

              if changed then
                updatedCount = updatedCount + 1
              end
            end
          end
        end)
      end
    end
  end

  -- 4. Complemento/Fallback: Varredura de sidecars .xmp ao lado das fotos
  catalog:withWriteAccessDo("Ler Metadados Sidecars .XMP", function()
    for _, photo in ipairs(photosToScan) do
      local pPath = photo:getRawMetadata('path')
      if pPath then
        local baseDir = LrPathUtils.parent(pPath)
        local baseLeaf = LrPathUtils.removeExtension(LrPathUtils.leafName(pPath))
        local xmpPath = LrPathUtils.child(baseDir, baseLeaf .. ".xmp")

        if LrFileUtils.exists(xmpPath) then
          local xFile = io.open(xmpPath, "r")
          if xFile then
            local xContent = xFile:read("*a")
            xFile:close()

            local rMatch = xContent:match('xmp:Rating="([0-5])"')
            local pMatch = xContent:match('lr:Pick="(-?1|0)"')
            local lMatch = xContent:match('xmp:Label="([^"]+)"')

            local changed = false
            if rMatch then
              photo:setRawMetadata('rating', tonumber(rMatch))
              changed = true
            end
            if pMatch then
              photo:setRawMetadata('pickStatus', tonumber(pMatch))
              changed = true
            end
            if lMatch and lMatch ~= "" then
              photo:setRawMetadata('colorNameForLabel', lMatch:lower())
              changed = true
            end

            if changed and updatedCount == 0 then
              updatedCount = updatedCount + 1
            end
          end
        end
      end
    end
  end)

  -- 5. Criação automática da coleção "Xtreme - Escolhidas" no catálogo
  if #pickedPhotos > 0 then
    pcall(function()
      catalog:withWriteAccessDo("Criar Colecao Xtreme - Escolhidas", function()
        local col = catalog:createCollection("Xtreme - Escolhidas", nil, true)
        if col then
          col:addPhotos(pickedPhotos)
        end
      end)
    end)
  end

  progress:done()

  -- 6. Relatório visual e claro para o fotógrafo
  if updatedCount > 0 then
    LrDialogs.showBezel(string.format("Xtreme: %d fotos sincronizadas!", updatedCount), 3)
    LrDialogs.message(
      "Sincronizacao Concluida!",
      string.format(
        "Sucesso! O Xtreme Stack Classifier transferiu todas as alteracoes para o Catalogo LrC:

" ..
        "• Total de fotos atualizadas: %d
" ..
        "• Fotos Escolhidas (5★ / Pick): %d
" ..
        "• Fotos Rejeitadas (2★ / Rejeitada): %d

" ..
        "As notas, bandeiras e cores ja estao ativas no Modulo Biblioteca!
" ..
        "Uma colecao chamada 'Xtreme - Escolhidas' foi criada/atualizada para sua conveniencia.",
        updatedCount, #pickedPhotos, rejectedCount
      ),
      "info"
    )
  else
    LrDialogs.message(
      "Nenhuma atualizacao encontrada",
      "Nao foi possivel encontrar alteracoes no arquivo xtreme_lrc_feedback.json ou em arquivos .XMP.

" ..
      "Dica: No Xtreme Stack Classifier, clique no botao 'Enviar para o LrC Classic' ou 'Exportar Sidecars .XMP' e tente novamente.",
      "warning"
    )
  end
end)
