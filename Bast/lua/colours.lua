require "findfile"

DEFAULT_TEXTCOLOUR = "@w"

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

function getcolourlengthdiff(colouredstring)
  local lennocolour = #strip_colours(colouredstring)
  local lencolour = #colouredstring
  local addspace = lencolour - lennocolour
  return addspace
end

function centercolourline(s, length, outside, middle, middlecolour)
  if middlecolour == nil then
    middlecolour = ''
  end
  if middle == nil then
    middle = ' '
  end
  slen = #strip_colours(s)
  half = math.floor((length - slen)/ 2)
  nstr = outside .. middlecolour .. string.rep(middle, half) .. s .. middlecolour .. string.rep(middle, half)
  if #strip_colours(nstr) ~= length then
    nstr = nstr .. ' '
  elseif #strip_colours(nstr) > length then
    print('huh')
  end
  nstr = nstr .. outside
  return nstr
end
