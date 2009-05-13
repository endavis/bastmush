-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples
 
functions in this module
--]]
 
 function findkeyword(item)
  wlist = utils.split(item, " ")
  badwords = {
    ring = 1,
    aardwolf = 1,
    of = 1,
    the = 1,
    davinci = 1,
    a = 1,
    an = 1,
  }
  local name = ""
  for i,v in ipairs(wlist) do
    tfind = string.find(v, "'")
    if badwords[string.lower(v)] ~= 1 and tfind == nil then
      name = v
      break
    end
  end
  return string.lower(name)
end

function getactuallevel(remorts, level)
  return (remorts - 1) * 201 + level
end
