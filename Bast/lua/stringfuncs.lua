-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples
 
functions in this module
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

