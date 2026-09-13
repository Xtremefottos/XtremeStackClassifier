--[[
    Envia a seleção (e os membros da pilha) para o programa no PC (porta 49152).
]]

local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrPathUtils = import "LrPathUtils"
local LrSocket = import "LrSocket"
local LrTasks = import "LrTasks"

local Cat = dofile(LrPathUtils.child(_PLUGIN.path, "Catalog.lua"))

local function escapeJsonString(str)
    if not str then return "" end
    str = tostring(str)
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\r", "\\r")
    str = string.gsub(str, "\t", "\\t")
    return str
end

local function photoJson(photo, stackKey)
    local path = photo:getRawMetadata("path") or ""
    local rating = photo:getRawMetadata("rating") or 0
    local pick = photo:getRawMetadata("pickStatus") or 0
    local color = photo:getRawMetadata("colorNameForLabel") or ""
    local filename = photo:getFormattedMetadata("fileName") or ""
    local camera = photo:getFormattedMetadata("cameraModel") or ""
    local lens = photo:getFormattedMetadata("lens") or ""
    local shutter = photo:getFormattedMetadata("shutterSpeed") or ""
    local aperture = photo:getFormattedMetadata("aperture") or ""
    local iso = tostring(photo:getRawMetadata("isoSpeedRating") or "")
    local id = tostring(photo.localIdentifier or filename)
    return string.format(
        '{"id":"%s","name":"%s","path":"%s","rating":%d,"pickStatus":%d,"colorLabel":"%s","camera":"%s","lens":"%s","shutter":"%s","aperture":"%s","iso":"%s","stackKey":"%s"}',
        escapeJsonString(id),
        escapeJsonString(filename),
        escapeJsonString(path),
        rating,
        pick,
        escapeJsonString(color),
        escapeJsonString(camera),
        escapeJsonString(lens),
        escapeJsonString(shutter),
        escapeJsonString(aperture),
        escapeJsonString(iso),
        escapeJsonString(stackKey or "")
    )
end

LrFunctionContext.postAsyncTaskWithContext("XtremeSendToDesktop", function (context)
    local selected = Cat.getSelectedPhotos()
    if not selected or #selected == 0 then
        LrDialogs.message("Xtreme Stack Classifier", "Selecione ao menos 1 foto no Library.", "info")
        return
    end

    local stacks = Cat.uniqueStacks(selected)
    local items = {}
    for si, stack in ipairs(stacks) do
        local key = Cat.photoKey(stack[1]) or ("stack-" .. tostring(si))
        for _, photo in ipairs(stack) do
            items[#items + 1] = photoJson(photo, key)
        end
    end

    if #items == 0 then
        LrDialogs.message("Xtreme Stack Classifier", "Nenhuma foto válida na seleção.", "warning")
        return
    end

    local payload = string.format(
        '{"type":"selection","count":%d,"photos":[%s]}\n',
        #items,
        table.concat(items, ",")
    )

    local connected = false
    local client = LrSocket.bind {
        functionContext = context,
        plugin = _PLUGIN,
        port = 49152,
        mode = "send",
        onConnected = function (socket)
            connected = true
            socket:send(payload)
            LrTasks.startAsyncTask(function ()
                LrTasks.sleep(0.35)
                socket:close()
                LrDialogs.message(
                    "Xtreme Stack Classifier",
                    string.format("%d fotos enviadas para o programa no PC.", #items),
                    "info"
                )
            end)
        end,
        onError = function ()
            if not connected then
                LrDialogs.message(
                    "Xtreme Stack Classifier",
                    "Não conectou ao programa no PC (porta 49152).\nAbra o Xtreme Stack Classifier no computador e tente de novo.",
                    "warning"
                )
            end
        end,
    }
    if client == nil then
        LrDialogs.message(
            "Xtreme Stack Classifier",
            "LrSocket indisponível nesta versão do Classic.",
            "critical"
        )
    end
end)
