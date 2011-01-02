-- $Id: aardutils.lua 845 2010-09-28 15:47:29Z endavis $
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

functions in this module


data structures in this module
spelltarget_table 
 - map target from slist to a string

spelltype_table
 - map type from slist to a string
--]]

spells = {}
recoveries = {}
spells_xref = {}

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

function find_spellsn(item)
  if not item then
    ColourNote ("red", "", "A nil value was passed to find_spellsn")
    return false
  end
  item = trim (item):lower ()
  local sn = tonumber (item)
  local name
  invalid = false
  -- see if numeric spell numbner given
  if sn and not spells['all'] [sn] then
    ColourNote ("red", "", "Spell number '" .. item .. "' does not exist.")
    invalid = true
    sn = nil
  elseif not sn then
    -- look up word
    sn = spells_xref [item]  -- look for exact match first
                             -- (otherwise "bless" might match "bless weapon")
    if not sn then
      _, sn = PrefixCheck (spells_xref, item)
    end -- not found by exact match
    if not sn then
      ColourNote ("red", "", "Spell named '" .. item .. "' does not exist.")
      invalid = true
    end -- name not found
  end -- if
  return sn, invalid
end -- find_spellsn

function load_spells(stype)
  local res, text = CallPlugin("aaa72f3b5453567e2bba9d50", "get_spells", stype)
  spells[stype] = assert (loadstring ('return ' .. text or ""))()
end

function load_recoveries(rtype)
  local res, text = CallPlugin("aaa72f3b5453567e2bba9d50", "get_recoveries", rtype)
  recoveries[rtype] = assert (loadstring ('return ' .. text or ""))()
end

function load_spells_xrefs()
  local res, text = CallPlugin("aaa72f3b5453567e2bba9d50", "get_spells_xref", rtype)
  spells_xref = assert (loadstring ('return ' .. text or ""))()
end

