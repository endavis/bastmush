-- $Id: aardutils.lua 845 2010-09-28 15:47:29Z endavis $
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

functions in this module

--]]
require "chardb"

spells = {}
spells['affected'] = {}
recoveries = {}
recoveries['affected'] = {}

function PrefixCheck (t, s)
  for name, item in pairs (t) do
    if string.match (name, "^" .. s) then -- prefix match, so "avoid" matches "avoidance"
      return name, item
    end -- if name matches
  end -- checking table
  return nil  -- not found
end -- PrefixCheck

function justWords(str)
  local t = {}
  local function helper(word) table.insert(t, word) return "" end
  if not str:gsub("%w+", helper):find"%S" then return t end
end  

function find_spell(item)
  local db = Statdb:new{}
  
  if item then
    item = trim (item):lower ()
    local sn = tonumber (item)

    -- see if numeric spell number given
    if sn then
      local a = db:lookupskillbysn(sn)
      if a then
        return a
      end
    elseif not sn then
      -- look up word
      local a = db:lookupskillbyname(item)
      if a then
        return a
      end
    end -- if
  else
    ColourNote ("red", "", "A nil value was passed to find_spell")
  end

  return false
end -- find_spellsn

function load_spells(stype)
  local tspell = {}
  local db = Statdb:new{}
  if stype == 'all' then
    tspell = db:getallskills()
  elseif stype == 'spellup' then
    tspell = db:getspellupskills()
  elseif stype == 'learned' then
    tspell = db:getlearnedskills()    
  elseif stype == 'combat' then
    tspell = db:getcombatskills()
  elseif stype == 'affected' then
    local res, text = CallPlugin("aaa72f3b5453567e2bba9d50", "get_spells", stype)
    tspell = assert (loadstring ('return ' .. text or ""))()
  end
  spells[stype] = tspell
end

function load_recoveries(rtype)
  local tspell = {}
  local db = Statdb:new{}
  if rtype == 'all' then
    tspell = db:getallrecoveries()
    --print('getting all')
    --tprint(tspell)
  elseif rtype == 'affected' then
    local res, text = CallPlugin("aaa72f3b5453567e2bba9d50", "get_recoveries", rtype)
    tspell = assert (loadstring ('return ' .. text or ""))()
  end
  recoveries[rtype] = tspell    
end

