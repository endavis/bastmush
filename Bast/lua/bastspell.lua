-- $Id$
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

function SecondsToClock(sSeconds)
  local nSeconds = tonumber(sSeconds)
  if nSeconds == 0 or nSeconds == nil then
    --return nil;
    return "00:00:00";
  elseif nSeconds < 0 then
    return tostring(sSeconds)
  else
    local nHours = string.format("%02.f", math.floor(nSeconds/3600));
    local nMins = string.format("%02.f", math.floor(nSeconds/60 - (nHours*60)));
    local nSecs = string.format("%02.f", math.floor(nSeconds - nHours*3600 - nMins *60));
    if nHours ~= "00" then
      return nHours..":"..nMins..":"..nSecs
    else
      return nMins..":"..nSecs
    end
  end
end

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

function load_spells(stype, client)
  local tspell = {}
  local db = Statdb:new{}
  if stype == 'all' then
    tspell = db:getallskills()
  elseif stype == 'spellup' then
    tspell = db:getspellupskills(client)
  elseif stype == 'learned' then
    tspell = db:getlearnedskills()    
  elseif stype == 'combat' then
    tspell = db:getcombatskills()
  elseif stype == 'notpracticed' then
    tspell = db:getnotpracticedskills()
  elseif stype == 'notlearned' then
    tspell = db:getnotlearnedskills()    
  elseif stype == 'affected' then
    if GetPluginInfo("aaa72f3b5453567e2bba9d50", 17) then
      local res, text = CallPlugin("aaa72f3b5453567e2bba9d50", "get_spells", stype)
      tspell = assert (loadstring ('return ' .. text or ""))()
    end
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
    if GetPluginInfo("aaa72f3b5453567e2bba9d50", 17) then    
      local res, text = CallPlugin("aaa72f3b5453567e2bba9d50", "get_recoveries", rtype)
      tspell = assert (loadstring ('return ' .. text or ""))()
    end
  end
  recoveries[rtype] = tspell    
end

function cancastother(sn)
   if spells['all'][sn].spellup == 1 and       -- it is a spellup
        spells['all'][sn].target == 2 and   -- can be cast on others
        spells['all'][sn].type == 1 then   -- spell not skill  
     return true
   else
     return false
   end  
end

