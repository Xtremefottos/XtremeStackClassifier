--[[
  PluginInit.lua - Inicializador do Xtreme Stack Classifier
  Ouve o programa Windows (TCP 127.0.0.1:49153) e grava no catálogo do Classic.
]]
local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrSocket = import 'LrSocket'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'

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

      if p then p = p:gsub("\\\\", "\\") end
      if not fn and p then fn = p:match("([^\\/]+)$") end

      table.insert(updates, {
        path = p,
        fileName = fn,
        id = id,
        rating = rating and tonumber(rating),
        pickStatus = pickStatus and tonumber(pickStatus),
        colorLabel = colorLabel and colorLabel:lower() or "",
      })
    end
  end
  return updates
end

-- Tarefa assíncrona em background que escuta conexões TCP na porta 49153
LrTasks.startAsyncTask(function()
  pcall(function()
    LrFunctionContext.callWithContext("XtremeRealtimeReceiver", function(context)
      local receiver = LrSocket.bind {
        functionContext = context,
        plugin = _PLUGIN,
        port = 49153,
        mode = "receive",
        onMessage = function(socket, message)
          if not message or message == "" then return end
          local updates = parsePhotoUpdates(message)
          if #updates == 0 then return end

          local catalog = LrApplication.activeCatalog()
          local allPhotos = catalog:getTargetPhotos()
          if not allPhotos or #allPhotos == 0 then
            allPhotos = catalog:getAllPhotos()
          end

          local indexByPath = {}
          local indexByName = {}
          for _, photo in ipairs(allPhotos) do
            local pPath = photo:getRawMetadata('path')
            if pPath then
              indexByPath[normPath(pPath)] = photo
              indexByName[leafName(pPath)] = photo
            end
          end

          local count = 0
          catalog:withWriteAccessDo("Xtreme Sincronizacao em Tempo Real", function()
            for _, item in ipairs(updates) do
              local photo = nil
              if item.path then photo = indexByPath[normPath(item.path)] end
              if not photo and item.fileName then photo = indexByName[leafName(item.fileName)] end

              if photo then
                if item.rating ~= nil and item.rating >= 0 and item.rating <= 5 then
                  photo:setRawMetadata('rating', item.rating)
                end
                if item.pickStatus ~= nil then
                  photo:setRawMetadata('pickStatus', item.pickStatus)
                end
                if item.colorLabel ~= nil then
                  local col = item.colorLabel:lower()
                  if col == "none" or col == "" then
                    photo:setRawMetadata('colorNameForLabel', '')
                  elseif col == "red" or col == "yellow" or col == "green" or col == "blue" or col == "purple" then
                    photo:setRawMetadata('colorNameForLabel', col)
                  end
                end
                count = count + 1
              end
            end
          end)

          if count > 0 then
            LrDialogs.showBezel(string.format("Xtreme: %d fotos atualizadas em tempo real!", count), 2)
          end
        end,
        onError = function(socket, err)
          -- Modo silencioso
        end,
        onClosed = function(socket)
        end
      }

      while true do
        LrTasks.sleep(1)
      end
    end)
  end)
end)
