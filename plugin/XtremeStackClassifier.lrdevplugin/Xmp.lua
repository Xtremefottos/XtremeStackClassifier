--[[
    Sidecar XMP — native Adobe fields only:
      xmp:Rating 0-5
      lr:Pick    1 | 0 | -1
      xmp:Label  Red | Yellow | Green | Blue | Purple | (omitted)
]]

local M = {}

local LABEL = {
    none = "",
    red = "Red",
    yellow = "Yellow",
    green = "Green",
    blue = "Blue",
    purple = "Purple",
}

local function escapeXml(value)
    local s = tostring(value or "")
    s = string.gsub(s, "&", string.char(38) .. "amp;")
    s = string.gsub(s, "<", string.char(38) .. "lt;")
    s = string.gsub(s, ">", string.char(38) .. "gt;")
    s = string.gsub(s, '"', string.char(38) .. "quot;")
    return s
end

function M.serialize(rating, pick, color)
    local adobe = LABEL[color] or ""
    local labelAttr = ""
    if adobe ~= "" then
        labelAttr = string.format('\n    xmp:Label="%s"', escapeXml(adobe))
    end
    return table.concat({
        '<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>',
        '<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Xtreme Stack Classifier">',
        ' <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">',
        '  <rdf:Description rdf:about=""',
        '    xmlns:xmp="http://ns.adobe.com/xap/1.0/"',
        '    xmlns:lr="http://ns.adobe.com/lightroom/1.0/"',
        string.format('    xmp:Rating="%s"', tostring(rating or 0)),
        string.format('    lr:Pick="%s"', tostring(pick or 0)) .. labelAttr .. "/>",
        ' </rdf:RDF>',
        '</x:xmpmeta>',
        '<?xpacket end="w"?>',
        '',
    }, "\n")
end

function M.sidecarPath(photoPath)
    local LrPathUtils = import "LrPathUtils"
    return LrPathUtils.replaceExtension(photoPath, "xmp")
end

function M.writeBeside(photo)
    local path = photo:getRawMetadata("path")
    if not path or path == "" then return false, "no path" end
    local rating = photo:getRawMetadata("rating") or 0
    local pick = photo:getRawMetadata("pickStatus") or 0
    local color = photo:getRawMetadata("colorNameForLabel") or "none"
    local xml = M.serialize(rating, pick, color)
    local xmpPath = M.sidecarPath(path)
    local fh, err = io.open(xmpPath, "w")
    if not fh then return false, err end
    fh:write(xml)
    fh:close()
    return true, xmpPath
end

return M
