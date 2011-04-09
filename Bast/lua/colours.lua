require "findfile"

DEFAULT_COLOUR = "@w"

nfile = scan_dir_for_file (GetInfo(60), "aardwolf_colors.lua")
if nfile then
  -- pull in aardwolf_colors
  dofile (nfile)
else
  print("Could not load aardwolf_colors.lua, please copy it to your plugin directory")
  print('It can be downloaded from: http://code.google.com/p/aardwolfclientpackage/')
  print('It is also included in the Aardwolf MUSHclient')
end

function TextToColourTell (Text)
    local newstyles = ColoursToStyles(Text)
    for i,v in ipairs(newstyles) do
      ColourTell(RGBColourToName(v.textcolour), v.backcolour, v.text)
    end
      
end  -- TextToColourTell
