-- $Id: aardutils.lua 2088 2013-07-07 01:08:07Z endavis $
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

function getactuallevel(level, remorts, tier, redos)
  if level == nil then
    return -1
  end
  local tier = tier or 0
  local redos = redos or 0
  if redos == 0 then
    return (tier * 7 * 201) + ((remorts - 1) * 201) + level
  else
    return (tier * 7 * 201) + (redos * 7 * 201) + ((remorts - 1) * 201) + level
  end
end

function convertlevel(level)
  if (level == nil) then
    return {tier = -1, redos = -1, remort = -1, level = -1}
  end
  local level = tonumber(level)
  if level < 1 then
    return {tier = -1, redos = -1, remort = -1, level = -1}
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
  local redos = 0
  if tier > 9 then
        redos = tier - 9
        tier = 9
  end
  return {tier = tier, redos = redos, remort = remort, level = alevel}
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
 [0] = 'light',
 [1] = 'head',
 [2] = 'eyes',
 [3] = 'lear',
 [4] = 'rear',
 [5] = 'neck1',
 [6] = 'neck2',
 [7] = 'back',
 [8] = 'medal1',
 [9] = 'medal2',
 [10] = 'medal3',
 [11] = 'medal4',
 [12] = 'torso',
 [13] = 'body',
 [14] = 'waist',
 [15] = 'arms',
 [16] = 'lwrist',
 [17] = 'rwrist',
 [18] = 'hands',
 [19] = 'lfinger',
 [20] = 'rfinger',
 [21] = 'legs',
 [22] = 'feet',
 [23] = 'shield',
 [24] = 'wielded',
 [25] = 'second',
 [26] = 'hold',
 [27] = 'float',
 [28] = 'tattoo1',
 [29] = 'tattoo2',
 [30] = 'above',
 [31] = 'portal',
 [32] = 'sleeping',
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


damages = {
'misses',
'tickles',
'bruises',
'scratches',
'grazes',
'nicks',
'scars',
'hits',
'injures',
'wounds',
'mauls',
'maims',
'mangles',
'mars',
'LACERATES',
'DECIMATES',
'DEVASTATES',
'ERADICATES',
'OBLITERATES',
'EXTIRPATES',
'INCINERATES',
'MUTILATES',
'DISEMBOWELS',
'MASSACRES',
'DISMEMBERS',
'RENDS',
'- BLASTS -',
'-= DEMOLISHES =-',
'** SHREDS **',
'**** DESTROYS ****',
'***** PULVERIZES *****',
'-=- VAPORIZES -=-',
'<-==-> ATOMIZES <-==->',
'<-:-> ASPHYXIATES <-:->',
'<-*-> RAVAGES <-*->',
'<>*<> FISSURES <>*<>',
'<*><*> LIQUIDATES <*><*>',
'<*><*><*> EVAPORATES <*><*><*>',
'<-=-> SUNDERS <-=->',
'<=-=><=-=> TEARS INTO <=-=><=-=>',
'<->*<=> WASTES <=>*<->',
'<-+-><-*-> CREMATES <-*-><-+->',
'<*><*><*><*> ANNIHILATES <*><*><*><*>',
'<--*--><--*--> IMPLODES <--*--><--*-->',
'<-><-=-><-> EXTERMINATES <-><-=-><->',
'<-==-><-==-> SHATTERS <-==-><-==->',
'<*><-:-><*> SLAUGHTERS <*><-:-><*>',
'<-*-><-><-*-> RUPTURES <-*-><-><-*->',
'<-*-><*><-*-> NUKES <-*-><*><-*->',
'-<[=-+-=]<:::<>:::> GLACIATES <:::<>:::>[=-+-=]>-',
'<-=-><-:-*-:-><*--*> METEORITES <*--*><-:-*-:-><-=->',
'<-:-><-:-*-:-><-*-> SUPERNOVAS <-*-><-:-*-:-><-:->',
'does UNSPEAKABLE things to',
'does UNTHINKABLE things to',
'does UNIMAGINABLE things to',
'does UNBELIEVABLE things to',
'pimpslaps'
}

local damagerev = {}
for i,v in ipairs(damages) do
  damagerev[v] = true
end

local damageforregex = {}
for i,v in ipairs(damages) do
  local dam = v
  local chars = {'%', '[', '(', ')', '.', '+', '-', '*', '?', '^', '$'}
  for cin,char in ipairs(chars) do
    dam = string.gsub(dam, "%" .. char, "%%" .. char)
  end
  damageforregex[dam] = i
end

function parsedamageline(line)
  timer_start('aardutils:parsedamageline')
  local ddict = {}
  tsplit = utils.split(line, ' ')
  ddict['hits'] = 1
  local thits = string.match(tsplit[1], '^%[(%d*)%]')
  if thits then
    ddict['hits'] = thits
    table.remove(tsplit, 1)
  end
  if tsplit[1] == 'Your' then
    table.remove(tsplit,1)
  end
  ddict['damage'] = 0
  local tdam = string.match(tsplit[#tsplit], '^%[(%d*)%]')
  if tdam then
    ddict['damage'] = tdam
    table.remove(tsplit, #tsplit)
  end
  local nline = strjoin(' ', tsplit)
  for i,v in pairs(damageforregex) do
      local regex = string.format('^(.*) (%s) (.*).', i)
      local damtype, verb, enemy = string.match(nline, regex)
      if damtype and verb and enemy then
        found = true
        ddict['damtype'] = damtype
        ddict['damverb'] = damages[v]
        ddict['enemy'] = enemy
        break
      end
  end
  timer_end('aardutils:parsedamageline')
  return ddict
end


damtypes = {
  'acidic bite',
  'air',
  'beating',
  'bite',
  'blast',
  'charge',
  'chill',
  'chomp',
  'chop',
  'claw',
  'cleave',
  'crush',
  'decaying touch',
  'digestion',
  'divine power',
  'drain',
  'earth',
  'flame',
  'flaming bite',
  'freezing bite',
  'friction',
  'grep',
  'hit',
  'light',
  'life drain',
  'magic',
  'mental energy',
  'mind force',
  'peck',
  'pierce',
  'pound',
  'punch',
  'scratch',
  'shock',
  'shadow',
  'shocking bite',
  'slap',
  'slash',
  'slice',
  'slime',
  'smash',
  'stab',
  'sting',
  'suction',
  'thrust',
  'thwack',
  'wail',
  'water blast',
  'whip',
  'wrath',
}

damtypesrev = {}
for i,v in ipairs(damtypes) do
  damtypesrev[v] = true
end

function checkcorrectwearlocation(itemwearloc, where)
  --print('itemwearloc', itemwearloc, 'where', where)
  if itemwearloc == where then
    return true
  elseif (where == 'second' or where == 'wielded') and itemwearloc == 'wield' then
    return true
  elseif string.find(where, itemwearloc) then
    return true
  elseif where == 'portal' and string.find(itemwearloc, where) then
    return true
  end
  return false
end
