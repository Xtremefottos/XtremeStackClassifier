--[[
  XmpExporter.lua
  Gera sidecars .xmp nativos sem campos proprietários, garantindo total
  compatibilidade com Lightroom Classic e Camera Raw.
]]

local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local XmpExporter = {}

function XmpExporter.exportSingleXmp(photo)
  local photoPath = photo:getRawMetadata('path')
  if not photoPath then return false end

  local baseDir = LrPathUtils.parent(photoPath)
  local baseLeaf = LrPathUtils.removeExtension(LrPathUtils.leafName(photoPath))
  local xmpPath = LrPathUtils.child(baseDir, baseLeaf .. ".xmp")

  local rating = photo:getRawMetadata('rating') or 0
  local pickStatus = photo:getRawMetadata('pickStatus') or 0
  local colorLabel = photo:getRawMetadata('colorNameForLabel') or ""

  -- Mapeamento das cores para padrão Adobe
  local labelMap = {
    red = "Red",
    yellow = "Yellow",
    green = "Green",
    blue = "Blue",
    purple = "Purple"
  }
  local labelString = labelMap[colorLabel:lower()] or colorLabel

  -- Montagem do XML Adobe XMP NATIVO (Sem tags proprietárias xtreme:StackKey, conforme spec 2.2)
  local xmpContent = string.format([[<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 7.0">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about=""
    xmlns:xmp="http://ns.adobe.com/xap/1.0/"
    xmlns:lr="http://ns.adobe.com/lightroom/1.0/"
    xmp:Rating="%d"
    xmp:Label="%s"
    lr:Pick="%d">
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>]], rating, labelString, pickStatus)

  -- Grava o arquivo .xmp no disco ao lado da foto original
  local file, err = io.open(xmpPath, "w")
  if file then
    file:write(xmpContent)
    file:close()
    return true
  else
    return false, err
  end
end

return XmpExporter
