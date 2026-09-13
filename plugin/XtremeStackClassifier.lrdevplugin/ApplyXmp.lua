--[[
    Lê sidecars .xmp ao lado dos arquivos da seleção e grava no catálogo.
    Caminho de volta do programa no PC → Lightroom Classic.
]]

local LrDialogs = import "LrDialogs"
local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"

local Cat = dofile(LrPathUtils.child(_PLUGIN.path, "Catalog.lua"))
local Xmp = dofile(LrPathUtils.child(_PLUGIN.path, "Xmp.lua"))

local LABEL = {
    Red = "red",
    Yellow = "yellow",
    Green = "green",
    Blue = "blue",
    Purple = "purple",
}

local function attr(xml, name)
    local pattern = name .. '="([^"]*)"'
    return string.match(xml, pattern)
end

LrTasks.startAsyncTask(function ()
    local selected = Cat.getSelectedPhotos()
    if not selected or #selected == 0 then
        LrDialogs.message("Xtreme Stack Classifier", "Selecione as fotos cujos .xmp quer aplicar.", "info")
        return
    end

    local applied = 0
    local missing = 0
    local snaps = {}
    local jobs = {}

    for _, photo in ipairs(selected) do
        local path = photo:getRawMetadata("path")
        if path and path ~= "" then
            local xmpPath = Xmp.sidecarPath(path)
            if LrFileUtils.exists(xmpPath) then
                local fh = io.open(xmpPath, "r")
                if fh then
                    local xml = fh:read("*a")
                    fh:close()
                    local rating = tonumber(attr(xml, "xmp:Rating") or "0") or 0
                    local pick = tonumber(attr(xml, "lr:Pick") or "0") or 0
                    local adobe = attr(xml, "xmp:Label") or ""
                    local color = LABEL[adobe] or "none"
                    snaps[#snaps + 1] = Cat.snapshot(photo)
                    jobs[#jobs + 1] = { photo = photo, rating = rating, pick = pick, color = color }
                else
                    missing = missing + 1
                end
            else
                missing = missing + 1
            end
        end
    end

    if #jobs == 0 then
        LrDialogs.message(
            "Xtreme Stack Classifier",
            "Nenhum sidecar .xmp encontrado ao lado dos arquivos.",
            "warning"
        )
        return
    end

    local ok, err = Cat.pcall(function ()
        Cat.withWriteDo("Xtreme classify", function ()
            for _, job in ipairs(jobs) do
                Cat.setRating(job.photo, job.rating)
                Cat.setPick(job.photo, job.pick)
                Cat.setLabel(job.photo, job.color)
                applied = applied + 1
            end
        end)
    end)

    if ok then
        LrDialogs.message(
            "Xtreme Stack Classifier",
            string.format("Aplicados %d sidecars no catálogo. Sem .xmp: %d.", applied, missing),
            "info"
        )
    else
        LrDialogs.message("Xtreme Stack Classifier", tostring(err), "critical")
    end
end)
