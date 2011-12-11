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

objecttypes/objecttypesrev table
  - table of object types

wearlocs/wearlocsreverse tables
  - table of wear locations

optionallocs tables
  - table of wear locations that are optional when showing eq

spelltarget table
  - table of spell targets

statestrings table
  - table of statestrings

--]]

function hasmore(text)
  local _place = string.find(text, '}')
  local _stlen = string.len(text)
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
      local ttext = styles[1].text
      local _place = string.find(ttext, '}')
      if _place then
        styles[1].text = string.sub(ttext, _place + 1)
      end
    end
  end
  return styles
end

function findkeyword(item)
  local wlist = utils.split(item, " ")
  local badwords = {
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
    local tfind = string.find(v, "'")
    if badwords[string.lower(v)] ~= 1 and tfind == nil then
      name = v
      break
    end
  end
  return string.lower(name)
end

function getactuallevel(level, remorts, tier)
  if level == nil then
    return -1
  end
  local tier = tier or 0
  return (tier * 7 * 201) + (remorts - 1) * 201 + level
end

function convertlevel(level)
  local level = tonumber(level)
  if level < 1 then
    return {tier = -1, remort = -1, level = -1}
  end
  local tier = math.floor(level / (7 * 201))
  if level % (7 * 201) == 0 then
    tier = math.floor(level / (7 * 201)) - 1
  end
  local remort = math.floor((level - (tier * 7 * 201)) / 202) + 1
  local alevel = level % 201
  if level % 201 == 0 then
    alevel = 201
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
  'light',
  'scroll',
  'wand',
  'staff',
  'weapon',
  'treasure',
  'armor',
  'potion',
  'furniture',
  'trash',
  'container',
  'drink',
  'key',
  'food',
  'boat',
  'mobcorpse',
  'corpse',
  'fountain',
  'pill',
  'portal',
  'beacon',
  'giftcard',
  'bold',
  'raw material',
  'campfire'
}
objecttypes[0] = 'None'

objecttypesrev = {}
for i,v in ipairs(objecttypes) do
  objecttypesrev[v] = i
end
objecttypesrev['None'] = 0

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

wearlocreverse = {
 light = 0,
 head = 1,
 eyes = 2,
 lear = 3,
 rear = 4,
 neck1 = 5,
 neck2 = 6,
 back = 7,
 medal1 = 8,
 medal2 = 9,
 medal3 = 10,
 medal4 = 11,
 torso = 12,
 body = 13,
 waist = 14,
 arms = 15,
 lwrist = 16,
 rwrist = 17,
 hands = 18,
 lfinger = 19,
 rfinger = 20,
 legs = 21,
 feet = 22,
 shield = 23,
 wielded = 24,
 second = 25,
 hold = 26,
 float = 27,
 tattoo1 = 28,
 tattoo2 = 29,
 above = 30,
 portal = 31,
 sleeping = 32,
}

optionallocs = {
  [8]=true,
  [9]=true,
  [10]=true,
  [11]=true,
  [25]=true,
  [28]=true,
  [29]=true,
  [30]=true,
  [31]=true,
  [32]=true,
}

statestrings = {
  [1] = 'login',
  [2] = 'motd',
  [3] = 'active',
  [4] = 'afk',
  [5] = 'note',
  [6] = 'edit',
  [7] = 'page',
  [8] = 'combat',
  [9] = 'sleeping',
  [11] = 'resting',
  [12] = 'running'
}

spelltarget_table = {}
spelltarget_table[0] = 'special'
spelltarget_table[1] = 'attack'
spelltarget_table[2] = 'spellup'
spelltarget_table[3] = 'selfonly'
spelltarget_table[4] = 'object'

spelltype_table = {'spell', 'skill'}

statabb = {
  strength = 'Str',
  intelligence = 'Int',
  wisdom = 'Wis',
  dexterity = 'Dex',
  constitution = 'Con',
  luck = 'Luc',
  ['hit points'] = 'HP',
  mana = 'MN',
  moves = 'MV',
  saves = 'Sav',
  ['damage roll'] = 'DR',
  ['hit roll'] = 'HR',
}
