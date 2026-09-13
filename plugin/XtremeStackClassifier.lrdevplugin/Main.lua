--[[ Compat shim — entry point is Dialog.lua ]]
local LrPathUtils = import "LrPathUtils"
dofile(LrPathUtils.child(_PLUGIN.path, "Dialog.lua"))
