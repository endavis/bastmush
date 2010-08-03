-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

functions in this module
removetag - usage:removetag(stylerun)
  remove the tag in a style run

printstyles - usage:printstyles(stylerun)
  use colourtell to print a style run

findkeyword - usage: findkeyword(item)
  return the first keyword of the item that is not an article

getactuallevel - usage: getactuallevel(level, remorts, tier)
  - find the actual level based on remorts, tier, and current level

convertlevel - usage: convertlevel(level)
  - opposite of getactuallevel, return a table with keys tier, remort, level

classabb table
  - a table of class abbreviations, key is the abbreviation, value is
    the long name for the class

objecttypes table
  - table of object types

wearlocs table
  - table of wear locations
--]]

function hasmore(text)
  _place = string.find(text, '}')
  _stlen = string.len(text)
  if _place == _stlen then
    return false
  else
    return true
  end
end

function removetag(styles)
  if styles[1] then
    if not hasmore(styles[1].text) then
      table.remove (styles, 1)  -- get rid of tag
    else
      ttext = styles[1].text
      _place = string.find(ttext, '}')
      if _place then
        styles[1].text = string.sub(ttext, _place + 1)
      end
    end
  end
  return styles
end

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

function getactuallevel(level, remorts, tier)
  tier = tier or 0
  return (tier * 7 * 201) + (remorts - 1) * 201 + level
end

function convertlevel(level)
  level = tonumber(level)
  if level < 1 then
    return {tier = -1, remort = -1, level = -1}
  end
  if level % (7 * 201) == 0 then
    tier = math.floor(level / (7 * 201)) - 1
  else
    tier = math.floor(level / (7 * 201))
  end
  remort = math.floor((level - (tier * 7 * 201)) / 202) + 1
  if level % 201 == 0 then
    alevel = 201
  else
    alevel = level % 201
  end
  return {tier = tier, remort = remort, level = alevel}
end

function printstyles(styles)
  if styles then
    for _, v in ipairs (styles) do
      if next(v) then
        for _, v2 in ipairs (v) do
            ColourTell (RGBColourToName (v2.textcolour), 
                    RGBColourToName (v2.backcolour), 
                    v2.text)  
        end
        Note("")
      end
    end -- for each style run
    Note ("")  -- wrap up line

  end
end

classabb = {
  mag = 'mage',
  thi = 'thief',
  pal = 'paladin',
  war = 'warrior',
  psi = 'psionicist',
  cle = 'cleric',
  ran = 'ranger',
}

objecttypes = {
  'Light',
  'Scroll',
  'Wand',
  'Staff',
  'Weapon',
  'Treasure',
  'Armor',
  'Potion',
  'Furniture',
  'Trash',
  'Container',
  'Drink',
  'Key',
  'Food',
  'Boat',
  'Mobcorpse',
  'Corpse',
  'Fountain',
  'Pill',
  'Portal',
  'Beacon',
  'Giftcard',
  'Gold',
  'Raw material',
}

wearlocs = {
 'light',
 'head',
 'eyes',
 'lear',
 'rear',
 'neck1',
 'neck2',
 'back',
 'medal1',
 'medal2',
 'medal3',
 'medal4',
 'torso',
 'body',
 'waist',
 'arms',
 'lwrist',
 'rwrist',
 'hands',
 'lfinger',
 'rfinger',
 'legs',
 'feet',
 'shield',
 'wielded',
 'second',
 'hold',
 'float',
 'tattoo1',
 'tattoo2',
 'above',
 'portal',
 'sleeping',
}

 