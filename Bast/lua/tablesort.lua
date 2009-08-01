-- tablesort.lua
-- $Id$
-- iterator for sorting tables by keys or internel keys

-- Author: Eric Davis - 1st August 2009

--[[
     sort the table by the keys or an internal key to each table, will sort string or integer keys

  > test = {}
  > test['a'] = {}
  > test['b'] = {}
  > test['b']['sortlev'] = 40

  Example 1
  > for i,v in pairsSort(test) do
     print(i)
    end

  returns
   a
   b

  Example 2
  > for i,v in pairsSort(test, 'sortlev', 50) do
     print(i)
    end

  returns
   b
   a

--]]

function tableSort(ttable, sortkey, default)
  local function sortfunc (a, b)
    if sortkey then
      local akey = ttable[a][sortkey] or default
      local bkey = ttable[b][sortkey] or default
      return (akey < bkey)
    else
      return (a < b)
    end
  end

  local t2 = {}
  if ttable then
    for i,v in pairs(ttable) do
      table.insert(t2, i)
    end
    table.sort(t2, sortfunc)
  end

  local i = 0        -- iterator variable
  return function () -- iterator function
    i = i + 1
    return t2[i], ttable[t2[i]]
  end  -- iterator function

end