-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples
 
functions in this module

wrap - usage: wrap(line, length)
  wrap the line at length, will try to find closest comma or space
--]]

function wrap(line, length)
  local lines = {}
  while #line > length do
    -- find a space not followed by a space, or a , closest to the end of the line
    local col = string.find (line:sub (1, length), "[%s,][^%s,]*$")
    if col and col > 2 then
--      col = col - 1  -- use the space to indent
    else
      col = length  -- just cut off at wrap_column
    end -- if

    table.insert(lines, line:sub (1, col))
    line = line:sub (col + 1)

  end
  table.insert(lines, line)
  return lines
end

function strjoin(delimiter, list)
  local len = #list
  if len == 0 then 
    return "" 
  end
  local string = list[1]
  for i = 2, len do 
    string = string .. delimiter .. list[i] 
  end
  return string
end
