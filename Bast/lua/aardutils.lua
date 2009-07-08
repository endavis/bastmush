-- $Id$
--[[
http://code.google.com/p/bastmush
 - Documentation and examples

functions in this module
--]]

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
  if level < 1 then
    return -1, -1, -1
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