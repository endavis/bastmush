-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

functions in this module

quote - usage: quote(str)
  quote a string

wrap - usage: wrap(line, length)
  wrap the line at length, will try to find closest comma or space

strjoin - usage: strjoin(delimiter, list)
  join the list with delimiter

capitalize - usage: capitalize(str)
  capitalize a string

ReadableNumber- usage: ReadableNumber(num, places)
  format a number into readable string of num places
   10000000 would be turned into "10 M"

trimr - usage: trimr(str)
  trim whitespace from the right side of a string
--]]

function quote(str)
  return "\""..str.."\""
end

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

function capitalize (s)
  return string.sub (s, 1, 1):upper () .. string.sub (s, 2):lower ()
end -- capitalize

function ReadableNumber(num, places)
  local ret
  local placeValue = ("%%.%df"):format(places or 0)
  if not num then
      return 0
  elseif num >= 1000000000000 then
      ret = placeValue:format(num / 1000000000000) .. " T" -- trillion
  elseif num >= 1000000000 then
      ret = placeValue:format(num / 1000000000) .. " B" -- billion
  elseif num >= 1000000 then
      ret = placeValue:format(num / 1000000) .. " M" -- million
  elseif num >= 1000 then
      ret = placeValue:format(num / 1000) .. " K" -- thousand
  else
      ret = num -- hundreds
  end
  return ret
end

function trimr(s)
  return s:find('^%s*$') and '' or s:match('^(.*%S)')
end

function jcenter(s, length, outside, middle)
  if middle == nil then
    middle = ' '
  end
  slen = #s
  half = math.floor((length - slen - 2)/ 2)
  nstr = outside .. string.rep(middle, half) .. s .. string.rep(middle, half)
  if #nstr + 1 ~= length then
    nstr = nstr .. ' '
  elseif #nstr > length then
    print('huh')
  end
  nstr = nstr .. outside
  return nstr
end

function jleft(s, length, outside)
  slen = #s + 3
  rest = length - slen
  nstr = outside .. ' ' .. s .. string.rep(' ', rest) .. '|'
  return nstr
end
