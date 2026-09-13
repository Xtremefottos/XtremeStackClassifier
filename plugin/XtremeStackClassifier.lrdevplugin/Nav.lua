--[[
    1-based navigation. No Lightroom objects.
    stacks[stackIndex][photoIndex], compareIndex or nil.
]]

local Nav = {}

function Nav.wrap(i, n)
    if n == nil or n < 1 then return 1 end
    i = tonumber(i) or 1
    local idx = ((i - 1) % n) + 1
    if idx < 1 then idx = idx + n end
    return idx
end

function Nav.clamp(i, n)
    if n == nil or n < 1 then return 1 end
    i = tonumber(i) or 1
    if i < 1 then return 1 end
    if i > n then return n end
    return i
end

function Nav.new(stackCount)
    return {
        stackIndex = 1,
        photoIndex = 1,
        compareIndex = nil,
        stackCount = stackCount or 1,
    }
end

function Nav.nextPhoto(state, stackSize)
    state.photoIndex = Nav.wrap(state.photoIndex + 1, stackSize)
    return state.photoIndex
end

function Nav.prevPhoto(state, stackSize)
    state.photoIndex = Nav.wrap(state.photoIndex - 1, stackSize)
    return state.photoIndex
end

function Nav.selectPhoto(state, i, stackSize)
    state.photoIndex = Nav.clamp(i, stackSize)
    return state.photoIndex
end

function Nav.nextStack(state, stackCount)
    state.stackIndex = Nav.wrap(state.stackIndex + 1, stackCount)
    state.photoIndex = 1
    state.compareIndex = nil
    return state.stackIndex
end

function Nav.prevStack(state, stackCount)
    state.stackIndex = Nav.wrap(state.stackIndex - 1, stackCount)
    state.photoIndex = 1
    state.compareIndex = nil
    return state.stackIndex
end

function Nav.selectStack(state, i, stackCount)
    state.stackIndex = Nav.clamp(i, stackCount)
    state.photoIndex = 1
    state.compareIndex = nil
    return state.stackIndex
end

function Nav.toggleCompare(state, stackSize)
    if state.compareIndex then
        state.compareIndex = nil
        return nil
    end
    if stackSize < 2 then
        state.compareIndex = nil
        return nil
    end
    if state.photoIndex < stackSize then
        state.compareIndex = state.photoIndex + 1
    else
        state.compareIndex = Nav.wrap(state.photoIndex - 1, stackSize)
    end
    return state.compareIndex
end

return Nav
