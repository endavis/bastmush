-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

functions in this module
tableSort
     sort the table by the keys or an internal key to each table, will sort string or integer keys

  > test = {}
  > test['a'] = {}
  > test['b'] = {}
  > test['b']['sortlev'] = 40

  Example 1
  > for i,v in tableSort(test) do
     print(i)
    end

  returns
   a
   b

  Example 2
  > for i,v in tableSort(test, 'sortlev', 50) do
     print(i)
    end

  returns
   b
   a

tableExtend
  extend a table by adding another table

tableCountItems(ttable)
  count the items in a table

tableCountKeys(ttable, key, value, tnot)
  goes through a nested table and counts the tables that have key=value or key ~= value
    ttable = a nested table
    key = the key to check
    value = the value to check
    tnot = true if count the items that the tablevalue ~= value

--]]
function tableSort(ttable, sortkey, default, reverse)
  reverse = reverse or false
  local function sortfunc (a, b)
    if sortkey then
      local akey = ttable[a][sortkey] or default
      local bkey = ttable[b][sortkey] or default
      if type(akey) == 'boolean' then
        if akey then
          akey = 1
        else
          akey = 0
        end
      end
      if type(bkey) == 'boolean' then
        if bkey then
          bkey = 1
        else
          bkey = 0
        end
      end
      if akey == nil or bkey == nil then
        if akey == nil then
          print('BUG: akey: ', sortkey, ' - is nil for item', a)
        elseif bkey == nil then
          print('BUG: bkey: ', sortkey, ' - is nil for item', b)
        end
        return false
      end
      if reverse then
        return (bkey < akey)
      else
        return (akey < bkey)
      end
    else
      if reverse then
        return (b < a)
      else
        return (a < b)
      end
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

function tableExtend(t, ...)
  local pos, values
  if select('#', ...) == 1 then
    pos,values = #t+1, ...
  else
    pos,values = ...
  end
  if #values > 0 then
    for i=#t,pos,-1 do
      t[i+#values] = t[i]
    end
    local offset = 1 - pos
    for i=pos,pos+#values-1 do
      t[i] = values[i + offset]
    end
  end
end

function tableCountItems(ttable)
  local count = 0
  for i,v in pairs(ttable) do
    count = count + 1
  end
  if count == 0 then
    for i,v in ipairs(ttable) do
      count = count + 1
    end
  end
  return count
end

function tableCountKeys(ttable, key, value, tnot)
  local count = 0
  for i,v in pairs(ttable) do
    if tnot and v[key] ~= value then
      count = count + 1
    elseif not tnot and v[key] == value then
      count = count + 1
    end
  end
  return count
end

function tableRandomItem(t) --Selects a random item from a table
  local keys = {}
  for key, value in pairs(t) do
      keys[#keys+1] = key --Store keys in another table
  end
  index = keys[math.random(1, #keys)]
  return index, t[index]
end