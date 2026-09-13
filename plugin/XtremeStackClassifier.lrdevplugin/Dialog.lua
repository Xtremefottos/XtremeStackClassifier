--[[
    Xtreme Stack Classifier — LrView dialog
    Single 1-based state. Navigation buttons and filmstrip share applyView().
    No edit_field (it swallows P/X/1-5/arrows).
]]

local LrBinding = import "LrBinding"
local LrColor = import "LrColor"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrPathUtils = import "LrPathUtils"
local LrPrefs = import "LrPrefs"
local LrTasks = import "LrTasks"
local LrView = import "LrView"

local Locale = dofile(LrPathUtils.child(_PLUGIN.path, "Locale.lua"))
local Nav = dofile(LrPathUtils.child(_PLUGIN.path, "Nav.lua"))
local Cat = dofile(LrPathUtils.child(_PLUGIN.path, "Catalog.lua"))
local Xmp = dofile(LrPathUtils.child(_PLUGIN.path, "Xmp.lua"))

local f = LrView.osFactory()
local bind = LrView.bind
local prefs = LrPrefs.prefsForPlugin()

if prefs.locale ~= "en" then prefs.locale = "pt" end
if prefs.autoAdvance == nil then prefs.autoAdvance = false end
if prefs.filterUnclassified == nil then prefs.filterUnclassified = false end

local FRAME_IDLE = LrColor(0.35, 0.35, 0.36)
local FRAME_ACTIVE = LrColor(0.84, 0.78, 0.55)
local BG = LrColor(0.08, 0.08, 0.09)

local COLOR_CYCLE = { "none", "red", "yellow", "green", "blue", "purple" }

local function T(locale, key)
    return Locale.t(locale, key)
end

local function buildDialog(allStacks)
    LrFunctionContext.postAsyncTaskWithContext("Xtreme Stack Classifier", function (context)
        local props = LrBinding.makePropertyTable(context)
        local locale = prefs.locale or "pt"
        props.locale = locale
        props.uiEpoch = 1
        props.filterUnclassified = prefs.filterUnclassified and true or false
        props.autoAdvance = prefs.autoAdvance and true or false
        props.message = ""
        props.currentName = ""
        props.currentStatus = ""
        props.compareName = ""
        props.compareOn = false
        props.statsLine = ""
        props.stackLine = ""
        props.photoLine = ""
        props.loupePhoto = nil
        props.comparePhoto = nil

        local state = Nav.new(#allStacks)
        local undoStack = {}
        local closeDialog = nil

        local function t(key)
            return T(props.locale, key)
        end

        local function bumpUi()
            props.uiEpoch = (props.uiEpoch or 1) + 1
        end

        local maxStackSize = 1
        for _, stack in ipairs(allStacks) do
            if #stack > maxStackSize then maxStackSize = #stack end
        end
        local railCount = #allStacks

        local function visibleStacks()
            if not props.filterUnclassified then return allStacks end
            local list = {}
            for _, stack in ipairs(allStacks) do
                if Cat.stackHasUnclassified(stack) then
                    list[#list + 1] = stack
                end
            end
            return list
        end

        local function currentStack()
            local stacks = visibleStacks()
            return stacks[state.stackIndex]
        end

        local function currentPhoto()
            local stack = currentStack()
            if not stack then return nil end
            return stack[state.photoIndex]
        end

        local function flagLabel(flag)
            if flag == 1 then return t("flagPick") end
            if flag == -1 then return t("flagReject") end
            return t("flagNeutral")
        end

        local function colorLabel(color)
            if color == "red" then return t("colorRed") end
            if color == "yellow" then return t("colorYellow") end
            if color == "green" then return t("colorGreen") end
            if color == "blue" then return t("colorBlue") end
            if color == "purple" then return t("colorPurple") end
            return t("colorNone")
        end

        local function statusText(photo)
            local rating, flag, color = Cat.getStatus(photo)
            local star = string.rep("*", rating) .. string.rep("-", 5 - rating)
            return string.format(
                "%s: %s    %s: %s    %s: %s",
                t("stars"), star,
                t("flag"), flagLabel(flag),
                t("color"), colorLabel(color)
            )
        end

        local function stackTitle(stack, index, active)
            local pending = 0
            for _, photo in ipairs(stack) do
                if Cat.isUnclassified(photo) then pending = pending + 1 end
            end
            local mark = active and "> " or ""
            return string.format(
                "%s%d  %s  ·  %d %s  ·  %d %s",
                mark, index, Cat.getFileName(stack[1]),
                #stack, t("photos"),
                pending, t("remaining")
            )
        end

        -- THE single bind point: status, ">", loupe, compare, rail.
        local function applyView()
            local stacks = visibleStacks()
            local nStacks = #stacks
            if nStacks == 0 then
                props.loupePhoto = nil
                props.comparePhoto = nil
                props.compareOn = false
                props.currentName = t("heroEmpty")
                props.compareName = ""
                props.currentStatus = ""
                props.stackLine = t("stacks") .. ": 0"
                props.photoLine = ""
                props.statsLine = ""
                for i = 1, maxStackSize do
                    props["slotOn" .. i] = false
                    props["slotPhoto" .. i] = nil
                    props["slotName" .. i] = ""
                end
                for i = 1, railCount do
                    props["railOn" .. i] = false
                    props["railTitle" .. i] = ""
                end
                return
            end

            state.stackIndex = Nav.clamp(state.stackIndex, nStacks)
            local stack = stacks[state.stackIndex]
            local n = #stack
            state.photoIndex = Nav.clamp(state.photoIndex, n)
            if state.compareIndex then
                state.compareIndex = Nav.clamp(state.compareIndex, n)
                if state.compareIndex == state.photoIndex then
                    state.compareIndex = nil
                end
            end

            -- Invalidate cached LrPicture before pointing at the new photo.
            props.loupePhoto = nil
            props.comparePhoto = nil
            props.loupePhoto = stack[state.photoIndex]
            if state.compareIndex then
                props.comparePhoto = stack[state.compareIndex]
                props.compareOn = true
            else
                props.compareOn = false
            end

            props.currentName = Cat.getFileName(stack[state.photoIndex])
            props.compareName = state.compareIndex and Cat.getFileName(stack[state.compareIndex]) or ""
            props.currentStatus = statusText(stack[state.photoIndex])
            props.photoLine = string.format(
                "%s %d / %d  ·  %s",
                t("photo"), state.photoIndex, n, props.currentName
            )
            props.stackLine = string.format(
                "%s %d / %d  ·  %d %s",
                t("stack"), state.stackIndex, nStacks, n, t("photos")
            )
            local classified, total = Cat.countSession(stacks)
            props.statsLine = string.format(
                "%s %s %s %s  ·  %s %s",
                tostring(classified), t("of"), tostring(total), t("classified"),
                tostring(total - classified), t("remaining")
            )

            for i = 1, maxStackSize do
                local photo = stack[i]
                if photo then
                    props["slotOn" .. i] = true
                    props["slotPhoto" .. i] = nil
                    props["slotPhoto" .. i] = photo
                    local mark = (i == state.photoIndex) and "> " or ""
                    props["slotName" .. i] = mark .. tostring(i) .. "  " .. Cat.getFileName(photo)
                else
                    props["slotOn" .. i] = false
                    props["slotPhoto" .. i] = nil
                    props["slotName" .. i] = ""
                end
            end

            for i = 1, railCount do
                local railStack = stacks[i]
                if railStack then
                    props["railOn" .. i] = true
                    props["railTitle" .. i] = stackTitle(railStack, i, i == state.stackIndex)
                else
                    props["railOn" .. i] = false
                    props["railTitle" .. i] = ""
                end
            end
        end

        local function nextPhoto()
            local stack = currentStack()
            if not stack or #stack == 0 then return end
            Nav.nextPhoto(state, #stack)
            applyView()
        end

        local function prevPhoto()
            local stack = currentStack()
            if not stack or #stack == 0 then return end
            Nav.prevPhoto(state, #stack)
            applyView()
        end

        local function nextStack()
            local stacks = visibleStacks()
            if #stacks == 0 then
                LrDialogs.message(t("pluginTitle"), t("filterEmpty"))
                return
            end
            Nav.nextStack(state, #stacks)
            applyView()
        end

        local function prevStack()
            local stacks = visibleStacks()
            if #stacks == 0 then return end
            Nav.prevStack(state, #stacks)
            applyView()
        end

        local function selectPhoto(i)
            local stack = currentStack()
            if not stack then return end
            if i < 1 or i > #stack then return end
            Nav.selectPhoto(state, i, #stack)
            applyView()
        end

        local function selectStack(i)
            local stacks = visibleStacks()
            if i < 1 or i > #stacks then return end
            Nav.selectStack(state, i, #stacks)
            applyView()
        end

        local function toggleCompare()
            local stack = currentStack()
            if not stack then return end
            Nav.toggleCompare(state, #stack)
            applyView()
        end

        local function pushUndo(entries)
            undoStack[#undoStack + 1] = entries
            if #undoStack > 40 then table.remove(undoStack, 1) end
        end

        local function classify(mode, value)
            local photo = currentPhoto()
            if not photo then return end
            LrTasks.startAsyncTask(function ()
                local snap = Cat.snapshot(photo)
                local ok, err = Cat.pcall(function ()
                    Cat.withWrite("Xtreme classify", { photo }, function (p)
                        if mode == "rating" then Cat.setRating(p, value)
                        elseif mode == "flag" then Cat.setPick(p, value)
                        else Cat.setLabel(p, value)
                        end
                    end)
                end)
                if ok then
                    pushUndo({ snap })
                    props.message = t("appliedPhoto")
                    if props.autoAdvance then nextPhoto() else applyView() end
                else
                    props.message = t("failed") .. ": " .. tostring(err)
                    LrDialogs.message(t("pluginTitle"), tostring(err), "critical")
                end
            end)
        end

        local function classifyStack(mode, value)
            local stack = currentStack()
            if not stack then return end
            LrTasks.startAsyncTask(function ()
                local snaps = {}
                local photos = {}
                for _, p in ipairs(stack) do
                    snaps[#snaps + 1] = Cat.snapshot(p)
                    photos[#photos + 1] = p
                end
                local ok, err = Cat.pcall(function ()
                    Cat.withWrite("Xtreme classify", photos, function (p)
                        if mode == "rating" then Cat.setRating(p, value)
                        elseif mode == "flag" then Cat.setPick(p, value)
                        else Cat.setLabel(p, value)
                        end
                    end)
                end)
                if ok then
                    pushUndo(snaps)
                    props.message = t("appliedStack")
                    applyView()
                else
                    props.message = t("failed") .. ": " .. tostring(err)
                    LrDialogs.message(t("pluginTitle"), tostring(err), "critical")
                end
            end)
        end

        local function confirmApply(mode)
            local photo = currentPhoto()
            if not photo then return end
            local r = LrDialogs.confirm(t("confirmTitle"), t("confirmBody"), t("apply"), t("cancel"))
            if r ~= "ok" then return end
            local rating, flag, color = Cat.getStatus(photo)
            if mode == "rating" then classifyStack("rating", rating)
            elseif mode == "flag" then classifyStack("flag", flag)
            else classifyStack("color", color)
            end
        end

        local function pickRejectRest()
            local stack = currentStack()
            local current = currentPhoto()
            if not stack or not current then return end
            local r = LrDialogs.confirm(t("confirmPickReject"), t("confirmPickRejectBody"), t("apply"), t("cancel"))
            if r ~= "ok" then return end
            LrTasks.startAsyncTask(function ()
                local snaps = {}
                local photos = {}
                for _, p in ipairs(stack) do
                    snaps[#snaps + 1] = Cat.snapshot(p)
                    photos[#photos + 1] = p
                end
                local currentId = Cat.photoKey(current)
                local ok, err = Cat.pcall(function ()
                    Cat.withWrite("Xtreme classify", photos, function (p)
                        if Cat.photoKey(p) == currentId then Cat.setPick(p, 1)
                        else Cat.setPick(p, -1)
                        end
                    end)
                end)
                if ok then
                    pushUndo(snaps)
                    props.message = t("appliedStack")
                    applyView()
                else
                    props.message = t("failed") .. ": " .. tostring(err)
                end
            end)
        end

        local function undoLast()
            local entries = table.remove(undoStack)
            if not entries then
                props.message = t("nothingToUndo")
                return
            end
            LrTasks.startAsyncTask(function ()
                local ok, err = Cat.pcall(function ()
                    Cat.withWriteDo("Xtreme classify", function ()
                        for _, e in ipairs(entries) do
                            Cat.restoreSnapshot(e)
                        end
                    end)
                end)
                if ok then
                    props.message = t("undone")
                    applyView()
                else
                    props.message = t("failed") .. ": " .. tostring(err)
                end
            end)
        end

        local function cycleColor()
            local photo = currentPhoto()
            if not photo then return end
            local _, _, current = Cat.getStatus(photo)
            local idx = 1
            for i, name in ipairs(COLOR_CYCLE) do
                if name == current then idx = i break end
            end
            classify("color", COLOR_CYCLE[(idx % #COLOR_CYCLE) + 1])
        end

        local function selectInLightroom()
            local stack = currentStack()
            if not stack then return end
            LrTasks.startAsyncTask(function ()
                Cat.selectInLibrary(stack)
                props.message = t("selectedInLr")
            end)
        end

        local function exportSidecars()
            LrTasks.startAsyncTask(function ()
                local ok, err = Cat.pcall(function ()
                    local written = 0
                    for _, stack in ipairs(allStacks) do
                        for _, photo in ipairs(stack) do
                            local done = Xmp.writeBeside(photo)
                            if done then written = written + 1 end
                        end
                    end
                    props.message = t("exportedXmp") .. " (" .. tostring(written) .. ")"
                end)
                if not ok then
                    props.message = t("failed") .. ": " .. tostring(err)
                end
            end)
        end

        props:addObserver("filterUnclassified", function ()
            prefs.filterUnclassified = props.filterUnclassified
            state.stackIndex = 1
            state.photoIndex = 1
            state.compareIndex = nil
            applyView()
        end)
        props:addObserver("autoAdvance", function ()
            prefs.autoAdvance = props.autoAdvance
        end)
        props:addObserver("locale", function ()
            prefs.locale = props.locale
            bumpUi()
            applyView()
        end)

        applyView()

        local function epochTitle(key)
            return bind {
                key = "uiEpoch",
                transform = function ()
                    return t(key)
                end,
            }
        end

        local railItems = {}
        for i = 1, railCount do
            local index = i
            railItems[#railItems + 1] = f:push_button {
                title = bind("railTitle" .. index),
                visible = bind("railOn" .. index),
                action = function () selectStack(index) end,
                width = 210,
            }
        end

        local stripCells = {}
        for i = 1, maxStackSize do
            local index = i
            stripCells[#stripCells + 1] = f:column {
                visible = bind("slotOn" .. index),
                width = bind {
                    key = "slotOn" .. index,
                    transform = function (on)
                        if on then return 96 else return 0 end
                    end,
                },
                spacing = 2,
                f:catalog_photo {
                    photo = bind("slotPhoto" .. index),
                    width = 96,
                    height = 72,
                    frame_width = 2,
                    frame_color = FRAME_IDLE,
                    mouse_down = function ()
                        selectPhoto(index)
                    end,
                },
                f:push_button {
                    title = bind("slotName" .. index),
                    action = function () selectPhoto(index) end,
                    width = 96,
                },
            }
        end

        local stripRow = f:row { spacing = 4, unpack(stripCells) }
        local stripView
        if maxStackSize <= 10 then
            stripView = stripRow
        else
            stripView = f:scrolled_view {
                fill_horizontal = 1,
                height = 118,
                horizontal_scroller = true,
                vertical_scroller = false,
                stripRow,
            }
        end

        local contents = f:column {
            bind_to_object = props,
            fill_horizontal = 1,
            fill_vertical = 1,
            width = 1280,
            height = 820,
            spacing = 6,
            fill_color = BG,

            -- LINHA 0 header
            f:row {
                fill_horizontal = 1,
                spacing = 12,
                f:column {
                    spacing = 0,
                    f:static_text {
                        title = "XTREME STACK CLASSIFIER",
                        font = "title",
                    },
                    f:static_text { title = "Studio Marclay" },
                },
                f:spacer { fill_horizontal = 1 },
                f:static_text {
                    title = bind "statsLine",
                    width_in_chars = 42,
                },
                f:spacer { fill_horizontal = 1 },
                f:popup_menu {
                    value = bind "locale",
                    items = {
                        { title = "Português", value = "pt" },
                        { title = "English", value = "en" },
                    },
                    width_in_chars = 12,
                },
            },

            -- LINHA 1 corpo
            f:row {
                fill_horizontal = 1,
                fill_vertical = 1,
                spacing = 10,

                -- COL A pilhas 220
                f:column {
                    width = 220,
                    fill_vertical = 1,
                    spacing = 4,
                    f:static_text { title = epochTitle("stacks"), font = "bold" },
                    f:row {
                        spacing = 4,
                        f:push_button {
                            title = epochTitle("prevStack"),
                            action = function () prevStack() end,
                        },
                        f:push_button {
                            title = epochTitle("nextStack"),
                            action = function () nextStack() end,
                        },
                    },
                    f:static_text {
                        title = bind "stackLine",
                        width_in_chars = 28,
                    },
                    f:checkbox {
                        title = epochTitle("filterUnclassified"),
                        value = bind "filterUnclassified",
                        checked_value = true,
                        unchecked_value = false,
                    },
                    f:scrolled_view {
                        width = 220,
                        fill_vertical = 1,
                        horizontal_scroller = false,
                        vertical_scroller = true,
                        f:column { spacing = 3, unpack(railItems) },
                    },
                },

                -- COL B viewer
                f:column {
                    fill_horizontal = 1,
                    fill_vertical = 1,
                    spacing = 4,
                    f:row {
                        fill_horizontal = 1,
                        fill_vertical = 1,
                        spacing = 8,
                        f:push_button {
                            title = epochTitle("prevPhoto"),
                            action = function () prevPhoto() end,
                        },
                        f:catalog_photo {
                            photo = bind "loupePhoto",
                            fill_horizontal = 1,
                            fill_vertical = 1,
                            width = 720,
                            height = 480,
                            frame_width = 2,
                            frame_color = FRAME_ACTIVE,
                        },
                        f:push_button {
                            title = epochTitle("nextPhoto"),
                            action = function () nextPhoto() end,
                        },
                        f:column {
                            visible = bind "compareOn",
                            width = bind {
                                key = "compareOn",
                                transform = function (on)
                                    if on then return 280 else return 0 end
                                end,
                            },
                            spacing = 4,
                            f:catalog_photo {
                                photo = bind "comparePhoto",
                                width = 280,
                                height = 200,
                                frame_width = 1,
                                frame_color = FRAME_IDLE,
                                mouse_down = function ()
                                    if state.compareIndex then
                                        selectPhoto(state.compareIndex)
                                    end
                                end,
                            },
                            f:static_text {
                                title = bind "compareName",
                                width_in_chars = 28,
                                truncation = "middle",
                            },
                        },
                    },
                    f:row {
                        fill_horizontal = 1,
                        f:spacer { fill_horizontal = 1 },
                        f:column {
                            f:static_text {
                                title = bind "photoLine",
                                alignment = "center",
                                truncation = "middle",
                            },
                            f:static_text {
                                title = bind "currentStatus",
                                alignment = "center",
                            },
                        },
                        f:spacer { fill_horizontal = 1 },
                    },
                },
            },

            -- LINHA 2 filmstrip alinhada com COL B
            f:row {
                fill_horizontal = 1,
                spacing = 10,
                f:spacer { width = 220 },
                f:column {
                    fill_horizontal = 1,
                    height = 118,
                    stripView,
                },
            },

            -- LINHA 3 dock — 2 rows
            f:row {
                fill_horizontal = 1,
                spacing = 8,
                f:checkbox {
                    title = epochTitle("autoAdvance"),
                    value = bind "autoAdvance",
                    checked_value = true,
                    unchecked_value = false,
                },
                f:push_button {
                    title = epochTitle("compare"),
                    action = function () toggleCompare() end,
                },
                f:spacer { width = 16 },
                f:push_button { title = "0", action = function () classify("rating", 0) end },
                f:push_button { title = "1", action = function () classify("rating", 1) end },
                f:push_button { title = "2", action = function () classify("rating", 2) end },
                f:push_button { title = "3", action = function () classify("rating", 3) end },
                f:push_button { title = "4", action = function () classify("rating", 4) end },
                f:push_button { title = "5", action = function () classify("rating", 5) end },
                f:spacer { width = 16 },
                f:push_button { title = epochTitle("flagNeutral"), action = function () classify("flag", 0) end },
                f:push_button { title = epochTitle("flagPick"), action = function () classify("flag", 1) end },
                f:push_button { title = epochTitle("flagReject"), action = function () classify("flag", -1) end },
                f:spacer { width = 16 },
                f:push_button { title = epochTitle("colorNone"), action = function () classify("color", "none") end },
                f:push_button { title = epochTitle("colorRed"), action = function () classify("color", "red") end },
                f:push_button { title = epochTitle("colorYellow"), action = function () classify("color", "yellow") end },
                f:push_button { title = epochTitle("colorGreen"), action = function () classify("color", "green") end },
                f:push_button { title = epochTitle("colorBlue"), action = function () classify("color", "blue") end },
                f:push_button { title = epochTitle("colorPurple"), action = function () classify("color", "purple") end },
                f:push_button { title = "C", action = function () cycleColor() end },
            },

            f:row {
                fill_horizontal = 1,
                spacing = 8,
                f:push_button { title = epochTitle("applyStarStack"), action = function () confirmApply("rating") end },
                f:push_button { title = epochTitle("applyFlagStack"), action = function () confirmApply("flag") end },
                f:push_button { title = epochTitle("applyColorStack"), action = function () confirmApply("color") end },
                f:push_button { title = epochTitle("pickRejectRest"), action = function () pickRejectRest() end },
                f:spacer { fill_horizontal = 1 },
                f:push_button { title = epochTitle("selectInLr"), action = function () selectInLightroom() end },
                f:push_button { title = epochTitle("exportXmp"), action = function () exportSidecars() end },
                f:push_button { title = epochTitle("undo"), action = function () undoLast() end },
                f:push_button {
                    title = epochTitle("close"),
                    action = function ()
                        if closeDialog then closeDialog() end
                    end,
                },
            },

            -- LINHA 4 footer
            f:row {
                fill_horizontal = 1,
                f:static_text {
                    title = epochTitle("tip"),
                    truncation = "end",
                    width_in_chars = 70,
                },
                f:spacer { fill_horizontal = 1 },
                f:static_text { title = bind "message" },
            },
        }

        -- presentModalDialog injects OK/Cancel and cannot host dock Fechar.
        -- Floating + 1280×820 contents is the same chrome without a 3rd button row.
        LrDialogs.presentFloatingDialog(_PLUGIN, {
            title = "Xtreme Stack Classifier",
            contents = contents,
            blockTask = true,
            resizable = true,
            save_frame = "com.studiomarclay.xtreme.stackclassifier.dialog",
            onShow = function (dialog)
                closeDialog = dialog.close
            end,
        })
    end)
end

LrTasks.startAsyncTask(function ()
    local locale = prefs.locale or "pt"
    local ok, selected = Cat.pcall(Cat.getSelectedPhotos)
    if not ok or not selected or #selected == 0 then
        LrDialogs.message(T(locale, "pluginTitle"), T(locale, "noSelection"))
        return
    end
    local okStacks, stacks = Cat.pcall(function () return Cat.uniqueStacks(selected) end)
    if not okStacks or not stacks or #stacks == 0 then
        LrDialogs.message(T(locale, "pluginTitle"), T(locale, "noStacks"))
        return
    end
    buildDialog(stacks)
end)
