--[[
    Read existing Library stacks. Write rating / pickStatus / colorNameForLabel.
    Does not create, collapse, or dissolve stacks.
]]

local LrApplication = import "LrApplication"
local LrLogger = import "LrLogger"
local LrTasks = import "LrTasks"

local catalog = LrApplication.activeCatalog()
local logger = LrLogger("XtremeStackClassifier")
logger:enable("logfile")

local M = {}

function M.pcall(fn)
    local ok, result = LrTasks.pcall(fn)
    if not ok then
        logger:error(tostring(result))
        return false, result
    end
    return true, result
end

local function looksLikePhoto(value)
    if value == nil then return false end
    local ok = pcall(function () return value.localIdentifier end)
    return ok
end

local function buildLocalIdMapIfNeeded(needMap)
    if not needMap then return nil end
    local map = {}
    for _, p in ipairs(catalog:getAllPhotos()) do
        local ok, id = pcall(function () return p.localIdentifier end)
        if ok and id ~= nil then
            map[tonumber(id)] = p
        end
    end
    return map
end

local function normalizeStackMembers(rawMembers)
    if not rawMembers or #rawMembers == 0 then return {} end
    local needsMap = false
    for _, member in ipairs(rawMembers) do
        if not looksLikePhoto(member) then
            needsMap = true
            break
        end
    end
    local idMap = buildLocalIdMapIfNeeded(needsMap)
    local members = {}
    for _, member in ipairs(rawMembers) do
        local photo = member
        if not looksLikePhoto(member) then
            photo = idMap and idMap[tonumber(member)] or nil
        end
        if photo then
            members[#members + 1] = photo
        end
    end
    return members
end

function M.photoKey(photo)
    if not looksLikePhoto(photo) then return nil end
    local ok, uuid = pcall(function () return photo:getRawMetadata("uuid") end)
    if ok and uuid then return tostring(uuid) end
    local okId, id = pcall(function () return photo.localIdentifier end)
    return okId and tostring(id) or nil
end

function M.getFileName(photo)
    local ok, value = pcall(function () return photo:getFormattedMetadata("fileName") end)
    return ok and (value or "") or ""
end

function M.getStatus(photo)
    local rating = photo:getRawMetadata("rating") or 0
    local flag = photo:getRawMetadata("pickStatus") or 0
    local color = photo:getRawMetadata("colorNameForLabel") or "none"
    if color == nil or color == "" then color = "none" end
    return rating, flag, color
end

function M.isUnclassified(photo)
    local rating, flag, color = M.getStatus(photo)
    return rating == 0 and flag == 0 and color == "none"
end

function M.stackHasUnclassified(stack)
    for _, photo in ipairs(stack) do
        if M.isUnclassified(photo) then return true end
    end
    return false
end

function M.snapshot(photo)
    local rating, flag, color = M.getStatus(photo)
    return { photo = photo, rating = rating, flag = flag, color = color }
end

function M.getSelectedPhotos()
    local photos = catalog:getTargetPhotos()
    if not photos or #photos == 0 then
        local target = catalog:getTargetPhoto()
        if target then return { target } end
        return {}
    end
    return photos
end

local function getStackForPhoto(photo)
    local meta = photo:getRawMetadata()
    local members = normalizeStackMembers(meta and meta.stackInFolderMembers)
    if #members > 0 then return members end
    return { photo }
end

function M.uniqueStacks(selectedPhotos)
    local stacks = {}
    local byKey = {}
    for _, photo in ipairs(selectedPhotos) do
        local members = getStackForPhoto(photo)
        local key = (#members > 0) and M.photoKey(members[1]) or nil
        if key and not byKey[key] then
            local copy = {}
            for _, member in ipairs(members) do
                if looksLikePhoto(member) then
                    copy[#copy + 1] = member
                end
            end
            if #copy > 0 then
                stacks[#stacks + 1] = copy
                byKey[key] = #stacks
            end
        end
    end
    return stacks
end

-- Native catalog keys only: rating, pickStatus, colorNameForLabel.
function M.withWriteDo(actionName, fn)
    catalog:withWriteAccessDo(actionName, fn)
end

function M.withWrite(actionName, photos, mutator)
    catalog:withWriteAccessDo(actionName, function ()
        for _, photo in ipairs(photos) do
            mutator(photo)
        end
    end)
end

function M.setRating(photo, value)
    photo:setRawMetadata("rating", value)
end

function M.setPick(photo, value)
    photo:setRawMetadata("pickStatus", value)
end

function M.setLabel(photo, value)
    photo:setRawMetadata("colorNameForLabel", value)
end

function M.restoreSnapshot(entry)
    entry.photo:setRawMetadata("rating", entry.rating)
    entry.photo:setRawMetadata("pickStatus", entry.flag)
    entry.photo:setRawMetadata("colorNameForLabel", entry.color)
end

function M.selectInLibrary(stack)
    if not stack or #stack == 0 then return end
    local others = {}
    for i = 2, #stack do others[#others + 1] = stack[i] end
    catalog:setSelectedPhotos(stack[1], others)
end

function M.countSession(stacks)
    local total = 0
    local classified = 0
    for _, stack in ipairs(stacks) do
        for _, photo in ipairs(stack) do
            total = total + 1
            if not M.isUnclassified(photo) then
                classified = classified + 1
            end
        end
    end
    return classified, total
end

M.catalog = catalog
return M
