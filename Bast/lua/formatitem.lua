-- $Id$

require "colours"
require "bastspell"
require "aardutils"


flags = {'K', 'G', 'H', 'I', 'M'}

flagcolours = {
 K = 'red',
 M = 'blue',
 G = 'white',
 H = 'cyan',
 I = 'lightgray',
}

flagaardcolours = {
 K = 'R',
 M = 'B',
 G = 'W',
 H = 'C',
 I = 'w',
}
 
flagname = {
 K = 'kept',
 M = 'magic',
 G = 'glow',
 H = 'hum',
 I = 'invis',
}

local divider = '+-----------------------------------------------------------------+'

function formatsingleline(linename, linecolour, data, datacolour)
  --print('formatsingleline', linename)
  if not datacolour then
    datacolour = '@W'
  end

  data = tostring(data)

  local printstring = '| %s%-11s@w: %s%s'
  local ttext = string.format(printstring, linecolour, linename, datacolour, data)
  local newnum = 66 - #strip_colours(ttext)
  ttext = ttext .. string.format("%" .. tostring(newnum) .. "s@w|", "")

  return ttext
end

function formatdoubleline(linename, linecolour, data, linename2, data2)
  --print('formatsingleline', linename)
  if not linecolour then
    linecolour = '@W'
  end

  data = tostring(data)
  data2 = tostring(data2)

  local adddata = 24 + getcolourlengthdiff(data)
  local adddata2 = 17 + getcolourlengthdiff(data2)

  local printstring = '| %s%-11s@w: @W%-' .. tostring(adddata) .. 's %s%-7s@w: @W%-' .. tostring(adddata2) .. 's@w|'

  return string.format(printstring, linecolour, linename, data, linecolour, linename2, data2)
end

function formatspecialline(linename, linecolour, data, linename2, data2)
  --print('formatsingleline', linename)
  if not linecolour then
    linecolour = '@W'
  end

  data = tostring(data)
  data2 = tostring(data2)

  local adddata = 20 + getcolourlengthdiff(data)

  local printstring = '| %s%-11s@w: @W%-' .. tostring(adddata) .. 's'

  local ttext = string.format(printstring, linecolour, linename, data)

  if linename2 then
    local adddata2 = 14 + getcolourlengthdiff(data2)
    local printstring2 = ' %s%-13s:  @W%-' .. tostring(adddata2) .. 's@w|'
    ttext = ttext .. string.format(printstring2, linecolour, linename2, data2)
  else
    local newnum = 66 - #strip_colours(ttext)
    ttext = ttext .. string.format("%" .. tostring(newnum) .. "s@w|", "")
  end

  return ttext
end

function formatmod(linename, linecolour, mods)
  --print('formatmod', linename)
  if not linecolour then
    linecolour = '@W'
  end

  local printstring = '| %s%-11s: '
  local ttext = string.format(printstring, linecolour, linename)

  for i,v in pairs(mods) do
    local pstring = '@W%-13s: %s%+-9d@w'

    local tcolour = '@r'
    if tonumber(v) > 0 then
      tcolour = '@g'
    end

    ttext = ttext .. string.format(pstring, i, tcolour, tonumber(v))

  end

  local newnum = 66 - #strip_colours(ttext)
  ttext = ttext .. string.format("%" .. tostring(newnum) .. "s@w|", "")

  return ttext
end

function formatstatsheader()
  return string.format('|     @w%-4s %-4s  %-3s %-3s %-3s %-3s %-3s %-3s   %-3s   %-4s %-4s %-4s   |',
                          'DR', 'HR', 'Str', 'Int', 'Wis',
                          'Dex', 'Con', 'Luc', 'Sav', 'HP', 'MN', 'MV')
end

function formatstats(stats)
  local colours = {}
  for i,v in pairs(stats) do
    if tonumber(v) > 0 then
      colours[i] = '@G'
    else
      colours[i] = '@R'
    end
  end

  return string.format('|     @w%s%-4s@w %s%-4s@w  %s%-3s@w %s%-3s@w %s%-3s@w %s%-3s@w %s%-3s@w %s%-3s@w   %s%-3s@w   %s%-4s@w %s%-4s@w %s%-4s@w   |',
                          colours['Damage roll'] or "@w", stats['Damage roll'] or "-",
                          colours['Hit roll'] or "@w", stats['Hit roll'] or "-",
                          colours['Strength'] or "@w", stats['Strength'] or "-",
                          colours['Intelligence'] or "@w", stats['Intelligence'] or "-",
                          colours['Wisdom'] or "@w", stats['Wisdom'] or "-",
                          colours['Dexterity'] or "@w", stats['Dexterity'] or "-",
                          colours['Constitution'] or "@w", stats['Constitution'] or "-",
                          colours['Luck'] or "@w", stats['Luck'] or "-",
                          colours['Saves'] or "@w", stats['Saves'] or "-",
                          colours['Hit points'] or "@w", stats['Hit points'] or "-",
                          colours['Mana'] or "@w", stats['Mana'] or "-",
                          colours['Moves'] or "@w", stats['Moves'] or "-")
end

function formatresist(resists)
  local colours = {}
  local ttext = {}
  local foundfirst = false
  local foundsecond = false
  for i,v in pairs(resists) do
    if not foundfirst and (i == 'Bash' or i == 'Pierce' or i == 'Slash' or i == 'All physical' or
                           i == 'All magic' or i == 'Disease' or i == 'Poison') then
      foundfirst = true
    end
    if not foundsecond and (i == 'Acid' or i == 'Air' or i == 'Cold' or i == 'Earth' or
                            i == 'Electric' or i == 'Energy' or i == 'Fire' or i == 'Holy' or
                            i == 'Light' or i == 'Magic' or i == 'Mental' or i == 'Negative' or
                            i == 'Shadow' or i == 'Sonic' or i == 'Water') then
      foundsecond = true
    end
    if tonumber(v) > 0 then
      colours[i] = '@G'
    else
      colours[i] = '@R'
    end
  end

  if foundfirst then
    table.insert(ttext, string.format('|%5s@w%-5s %-7s %-7s  %-8s  %-8s  %-5s %-5s %5s|',
                            '', 'Bash', 'Pierce', 'Slash', 'All Phys', 'All Mag', 'Diss', 'Poisn', ''))
    table.insert(ttext, string.format('|%6s%s%-5s  %s%-7s %s%-7s   %s%-8s %s%-8s %s%-5s %s%-5s @w%4s|',
                            '',
                            colours['Bash'] or "@w", resists['Bash'] or "-",
                            colours['Pierce'] or "@w", resists['Pierce'] or "-",
                            colours['Slash'] or "@w", resists['Slash'] or "-",
                            colours['All physical'] or "@w", resists['All physical'] or "-",
                            colours['All magic'] or "@w", resists['All magic'] or "-",
                            colours['Disease'] or "@w", resists['Disease'] or "-",
                            colours['Poison'] or "@w", resists['Poison'] or "-",
                            ''))
  end
  if foundsecond then
    table.insert(ttext, divider)
    table.insert(ttext, string.format('|%5s%-5s  %-5s %-5s %-5s   %-5s   %-5s   %-5s   %-5s@w %3s|',
                          '', 'Acid', 'Air', 'Cold', 'Earth', 'Eltrc', 'Enrgy', 'Fire', 'Holy', ''))

    table.insert(ttext, string.format('|%5s%s%-5s  %s%-5s %s%-5s %s%-5s   %s%-5s   %s%-5s   %s%-5s   %s%-5s@w %3s|',
                          '',
                          colours['Acid'] or "@w", resists['Acid'] or "-",
                          colours['Air'] or "@w", resists['Air'] or "-",
                          colours['Cold'] or "@w", resists['Cold'] or "-",
                          colours['Earth'] or "@w", resists['Earth'] or "-",
                          colours['Electric'] or "@w", resists['Electric'] or "-",
                          colours['Energy'] or "@w", resists['Energy'] or "-",
                          colours['Fire'] or "@w", resists['Fire'] or "-",
                          colours['Holy'] or "@w", resists['Holy'] or "-",
                          ''))

    table.insert(ttext, string.format('|%4s %-5s  %-5s %-5s %-5s   %-5s   %-5s   %-5s @w %10s|',
                          '', 'Light', 'Magic', 'Mntl', 'Ngtv', 'Shdw', 'Sonic', 'Water', ''))

    table.insert(ttext, string.format('|%4s %s%-5s  %s%-5s %s%-5s %s%-5s   %s%-5s   %s%-5s   %s%-5s@w %11s|',
                          '',
                          colours['Light'] or "@w", resists['Light'] or "-",
                          colours['Magic'] or "@w", resists['Magic'] or "-",
                          colours['Mental'] or "@w", resists['Mental'] or "-",
                          colours['Negative'] or "@w", resists['Negative'] or "-",
                          colours['Shadow'] or "@w", resists['Shadow'] or "-",
                          colours['Sonic'] or "@w", resists['Sonic'] or "-",
                          colours['Water'] or "@w", resists['Water'] or "-",
                          ''))
  end

  return ttext
end

function formatitem(item)
  -- item should be from invdetails
  --tprint(item)
  local ltext = {}

  table.insert(ltext, divider)

  if item.keywords ~= '' and item.keywords ~= nil then
    local keyws = wrap(item.keywords, 49)
    local header = 'Keywords'
    for i,v in ipairs(keyws) do
      table.insert(ltext, formatsingleline(header, '@R', v))
      header = ''
    end
  end

  if item.identifier ~= '' and item.identifier ~= nil then
    local tstr = strjoin(', ', item.identifier)
    local idents = wrap(tstr, 49)
    local header = 'Identifier'
    for i,v in ipairs(idents) do
      table.insert(ltext, formatsingleline(header, '@R', v))
      header = ''
    end
  end

  if item.cname and item.cname ~= '' then
    table.insert(ltext, formatsingleline('Name', '@R', '@w' .. item.cname))
  end

  if tonumber(item.serial) then
    table.insert(ltext, formatsingleline('Id', '@R', item.serial))
  end

  -- Worn here
  -- Type, Level here
  if item.type and tonumber(item.level) then
    table.insert(ltext, formatdoubleline('Type', '@c', objecttypes[item.type]:gsub("^%l", string.upper), 'Level', item.level))
  elseif item.level then
    table.insert(ltext, formatsingleline('Level', '@c', item.level))    
  end

  -- Worth, Weight here
  if tonumber(item.worth) and tonumber(item.weight) then
    table.insert(ltext, formatdoubleline('Worth', '@c', commas(item.worth), 'Weight', item.weight))
  end

  if tonumber(item.type) == 1 then
    if item.light and next(item.light) then
      table.insert(ltext, formatsingleline('Duration', '@c', string.format('%s minutes', item.light.duration)))
    else
      table.insert(ltext, formatsingleline('Duration', '@c', 'Permanent'))
    end
  end

  if item.wearable and item.wearable ~= "" then
    table.insert(ltext, formatsingleline('Wearable', '@c', item.wearable))
  end

  if tonumber(item.score) then
    table.insert(ltext, formatsingleline('Score', '@c', item.score, '@Y'))
  end

  if item.material and item.material ~= "" then
    table.insert(ltext, formatsingleline('Material', '@c', item.material))
  end

  if item.flags and item.flags ~= "" then
    local flags = wrap(item.flags, 49)
    local t = 0
    for i,v in ipairs(flags) do
      local header = 'Flags'
      if t ~= 0 then
        header = ''
      end
      v = v:gsub('precious', '@Yprecious@w')
      table.insert(ltext, formatsingleline(header, '@c', trim(v)))
      t = t + 1
    end
  end

  if item.owner and item.owner ~= "" then
    table.insert(ltext, formatsingleline('Owned by', '@c', item.owner))
  end

  if item.fromclan and item.fromclan ~= "" then
    table.insert(ltext, formatsingleline('Clan Item', '@G', "@M" .. item.fromclan .. "@w"))
  end

  if item.foundat and item.foundat ~= "" then
    table.insert(ltext, formatsingleline('Found at', '@G', "@M" .. item.foundat .. "@w"))
  end

  if item.leadsto and item.leadsto ~= "" then
    table.insert(ltext, formatsingleline('Leads to', '@G', "@M" .. item.leadsto .. "@w"))
  end

  if item.note then
    table.insert(ltext, divider)

    for i,v in pairs(item.note) do
      local notews = wrap(v, 49)
      local header = 'Note'
      for i,v in pairs(notews) do
        table.insert(ltext, formatsingleline(header, '@W', v, '@w'))
        header = ''
      end
    end
  end

  if item.affectmod and next(item.affectmod) then
    local amods = strjoin(', ', item.affectmod)
    local keyws = wrap(amods, 49)
    local header = 'Affect Mods'
    for i,v in ipairs(keyws) do
      table.insert(ltext, formatsingleline(header, '@G', v))
      header = ''
    end
  end

  if item.container and next(item.container) then
    table.insert(ltext, divider)
    table.insert(ltext, formatspecialline('Capacity', '@c', item.container.capacity, 'Heaviest Item', item.container.heaviestitem))
    table.insert(ltext, formatspecialline('Holding', '@c', item.container.holding, 'Items Inside', item.container.itemsinside))
    table.insert(ltext, formatspecialline('Tot Weight', '@c', item.container.totalweight, 'Item Burden', item.container.itemburden))
    table.insert(ltext, formatspecialline('', '@c', string.format('@wItems inside weigh @Y%d@w%%@w of their usual weight', item.container.itemweightpercent)))
   end

   if item.weapon and next(item.weapon) then
    table.insert(ltext, divider)
    table.insert(ltext, formatspecialline('Weapon Type', '@c', item.weapon.wtype, 'Average Dam', item.weapon.avedam))
    table.insert(ltext, formatspecialline('Inflicts', '@c', item.weapon.inflicts, 'Damage Type', item.weapon.damtype))
    if item.weapon.special ~= "" and item.weapon.special ~= nil then
      table.insert(ltext, formatspecialline('Specials', '@c', item.weapon.special))
    end
  end

  if tonumber(item.type) == 20 then
    if item.portal and next(item.portal) then
      table.insert(ltext, divider)
      table.insert(ltext, formatsingleline('Portal', '@R', string.format('@Y%s@w uses remaining.', item.portal.uses)))
    end
  end

  if item.statmod and next(item.statmod) then
    table.insert(ltext, divider)
    table.insert(ltext, formatstatsheader())
    table.insert(ltext, formatstats(item.statmod))
  end

  if item.resistmod and next(item.resistmod) then
    table.insert(ltext, divider)

    for i,v in pairs(formatresist(item.resistmod)) do
      table.insert(ltext, v)
    end
  end

  if item.skillmod and next(item.skillmod) then
     table.insert(ltext, divider)

     local header = 'Skill Mods'
     for i,v in pairs(item.skillmod) do
       local spell = find_spell(i)
       local tcolour = '@R'
       if tonumber(v) > 0 then
         tcolour = '@G'
       end
       table.insert(ltext, formatspecialline(header, '@c',
                               string.format('Modifies @g%s@w by %s%+d@w', tostring(spell.name):gsub("^%l", string.upper), tcolour, tonumber(v))))
       header = ''
     end
  end

  if item.spells and next(item.spells) then
     table.insert(ltext, divider)

    local header = 'Spells'
    for i=1,4 do
      local key = 'sn' .. tostring(i)
      if item.spells[key] ~= "" and item.spells[key] ~= nil and tonumber(item.spells[key]) ~= 0 then
        local spell = find_spell(item.spells[key])
        local plural = ''
        if tonumber(item.spells.uses) > 1 then
          plural = 's'
        end
        table.insert(ltext, formatspecialline(header, '@c',
                                string.format("%d use%s of level %d '@g%s@w'", tonumber(item.spells.uses), plural,
                                          tonumber(item.spells.level), tostring(spell.name):lower())))
      end
      header = ''
    end
  end

  if item.food and next(item.food) then
    table.insert(ltext, divider)

    local header = 'Food'
    table.insert(ltext, formatspecialline(header, '@c',
                                string.format("Will replenish hunger by %d%%", tonumber(item.food.percent))))
  end

  if item.drink and next(item.drink) then
    table.insert(ltext, divider)

    table.insert(ltext, formatspecialline('Drink', '@c',
                                string.format("%d servings of %s. Max: %d", tonumber(item.drink.servings), item.drink.liquid,
                                           tonumber(item.drink.liquidmax)/20)))

    table.insert(ltext, formatspecialline('', '@c',
                                string.format("Each serving replenishes thirst by %d%%.", tonumber(item.drink.thirstpercent))))

    table.insert(ltext, formatspecialline('', '@c',
                                string.format("Each serving replenishes hunger by %d%%.", tonumber(item.drink.hungerpercent))))
  end

  if item.furniture and next(item.furniture) then
    table.insert(ltext, divider)

    local header = 'Heal Rate'
    table.insert(ltext, formatspecialline(header, '@c',
                                string.format("Health [@Y%d@w]    Magic [@Y%d@w]", tonumber(item.furniture.hpregen), tonumber(item.furniture.manaregen))))
  end

  table.insert(ltext, divider)

  return ltext
end

function containerheader(extras)
  if not extras then
    extras = {}
  end
  local header = {}

  -- # of items
  if extras['group'] then
    table.insert(header, string.format(" %3s  ", '#'))
  end

  if extras['flags'] then
    table.insert(header, '(')
    local count=0
    for i,flag in pairs(flags) do
      local colour = flagaardcolours[flag]
      count = count + 1
      if count == 1 then
        table.insert(header, ' @' .. colour .. flag .. ' ')
      else
        table.insert(header, '@' .. colour .. flag .. ' ')
      end
    end
  
    table.insert(header, '@w) ')
  end

  -- Level
  table.insert(header, '(@G')
  table.insert(header, string.format("%3s", "Lvl"))
  table.insert(header, '@w)  ')

  if extras['serial'] then
    table.insert(header, '(@x136')
    table.insert(header, string.format("%-12s", "Serial"))
    table.insert(header, '@w)  ')  
  end

  if extras['score'] then
    table.insert(header, '(@x136')
    table.insert(header, string.format("%5s", "Score"))
    table.insert(header, '@w)  ')  
  end
  
  table.insert(header, string.format("%s", 'Item Name'))
  local hl = strjoin('', header)
  
  return hl
end

function buildcontainer(db, container, extras)
  if not extras then
    extras = {}
  end
  local contents = {}
  if extras['sql'] then
    contents = db:runselect(extras['sql'])
  else
    contents = db:getcontainercontents(container, 'place', false, nil)
  end
  
  local titem = {}
  if not next(contents) then
    titem = {containerid=container}
  else
    titem = copytable.deep(contents[1])
  end
  
  local hl = containerheader(extras)
  
  local items = {}
  local numstyles = {}
  local foundgroup = {}
  
  if not next(contents) then
    table.insert(items, {'You have nothing in your inventory'})
  else
    for key,invitem in pairs(contents) do
      local item = db:getitemdetails(invitem.serial)
      if not item then
        item = invitem
      end
      item.level = invitem.level
      local stylekey = item.name .. item.shortflags .. tostring(item.level)
      local doit = true
      local sitem = {}
      if extras['group'] and numstyles[stylekey] then
        foundgroup[stylekey] = (foundgroup[stylekey] or 1) + 1
        doit = false
        table.remove(numstyles[stylekey].item, numstyles[stylekey].countcol)
        table.insert(numstyles[stylekey].item, numstyles[stylekey].countcol, string.format("(%3d) ", foundgroup[stylekey]))
        if extras['serial'] and foundgroup[stylekey] == 2 then
          table.remove(numstyles[stylekey].item, numstyles[stylekey].serialcol)
          table.insert(numstyles[stylekey].item, numstyles[stylekey].serialcol, string.format("%-12s", "Many"))
        end
      end
      if doit then
        if type(item) == 'table' then

          -- # of items
          if extras['group'] then
            table.insert(sitem, string.format(" %3s  ", " "))
            if not numstyles[stylekey] then
              numstyles[stylekey] = {item=sitem,countcol=#sitem,serial=item.serial}
            end
          end

          if extras['flags'] then
            table.insert(sitem, '(')
            count = 0
            for i,flag in pairs(flags) do
              local colour = flagaardcolours[flag]
              count = count + 1
              if string.find(item.shortflags, flag) then
                if count == 1 then
                  table.insert(sitem, ' @' .. colour .. flag .. ' ')
                else
                  table.insert(sitem, '@' .. colour .. flag .. ' ')
                end
              else
                if count == 1 then
                  table.insert(sitem, '   ')
                else
                  table.insert(sitem, '  ')
                end
              end
            end
            table.insert(sitem, '@w)')

            table.insert(sitem, ' ')
          end

          -- Level
          table.insert(sitem, '(@G')
          table.insert(sitem, string.format("%3d", tonumber(item.level)))
          table.insert(sitem, '@w)  ')

          if extras['serial'] then
            table.insert(sitem, '(@x136')
            table.insert(sitem, string.format("%-12s", tostring(item.serial or '')))
            if extras['group'] then
              if numstyles[stylekey] then
                numstyles[stylekey].serialcol = #sitem    
              end
            end
            table.insert(sitem, '@w)  ')            
          end
          
          if extras['score'] then
            table.insert(sitem, '(@C')    
            table.insert(sitem, string.format("%5s", tostring(item.score or 'Unkn')))
            table.insert(sitem, '@w)  ')        
          end  
          
          -- Name
          table.insert(sitem, item.cname)

          table.insert(items, sitem)
        end
      end
    end
  end
  
  -- leave this here because of the count
  local titems = {}
  for i,v in ipairs(items) do
    table.insert(titems, strjoin('', v))
  end
 
  return hl, titems
end

function wornheader(extras)
  if not extras then
    extras = {}
  end  
  local header = {}

  table.insert(header,  '@G[@w')
  table.insert(header,  string.format(' %-8s ', 'Location'))
  table.insert(header,  '@G]@w ')

  if extras['flags'] then
    table.insert(header,  '(')
    local count=0
    for i,flag in pairs(flags) do
      local colour = flagaardcolours[flag]
      count = count + 1
      if count == 1 then
        table.insert(header,  ' @' .. colour .. flag .. '@x ')
      else
        table.insert(header,  '@' .. colour .. flag .. '@x ')
      end
    end
    table.insert(header,  '@w) ')
  end
  
  -- Level
  table.insert(header, '(')
  table.insert(header,  string.format("@G%3s@w", 'Lvl'))
  table.insert(header,  ') ')

  if extras['serial'] then
    table.insert(header, '(@x136')
    table.insert(header, string.format("%-12s", "Serial"))
    table.insert(header, '@w)  ')  
  end
  
  if extras['score'] then
    table.insert(header, '(@C')
    table.insert(header, string.format("%-5s", 'Score'))
    table.insert(header, '@w)  ')        
  end 
  
  table.insert(header,  string.format("%s", 'Item Name'))

  table.insert(header,  '  ')

  return strjoin('', header)  
end

function buildwornoutput(db, container, extras)
  if not extras then
    extras = {}
  end
  local items = {}

  local contents = {}
  
  if extras['sql'] then
    contents = db:runselect(extras['sql'])
  else
    contents = db:getcontainercontents(container, 'place', false, nil)
  end
  local titem = {}

  local hl = wornheader(extras)
  
  local item = {}

  local itemsbywearloc = {}
  if next(contents) then
    for i,v in pairs(contents) do
      itemsbywearloc[v.wearslot] = v
    end
  end

  for i=0,#wearlocs do
    actualslot = i
    local invitem = itemsbywearloc[actualslot]
    local item = nil
    if invitem then
      item = db:getitemdetails(invitem.serial)
      if not item then
        item = invitem
      end
      item.level = invitem.level
    end
    if item then
      item.wearslot = actualslot
      item = buildwornitemout(item, extras)
    else
      local doit = true
      if optionallocs[actualslot] then
        doit = false
      end
      if ((actualslot == 23 or actualslot == 26) and itemsbywearloc[25]) then
        doit = false
      end
      if doit and not extras['sql'] then
        item = buildwornitemout({cname="@r< empty >@w", shortflags="", wearslot=actualslot}, extras)
      end
    end
    if item then
      table.insert(items, strjoin('', item))
    end
  end
  
  return hl, items

end

function buildwornitemout(item, extras)
  if not extras then
    extras = {}
  end
    
  local sitem = {}

  table.insert(sitem, '@G[@w')

  local colour = '@c'
  if wearlocs[item.wearslot] == 'wielded' or wearlocs[item.wearslot] == 'second' then
    colour = '@R'
  elseif wearlocs[item.wearslot] == 'above' or wearlocs[item.wearslot] == 'light' then
    colour = '@W'
  elseif wearlocs[item.wearslot] == 'portal' or wearlocs[item.wearslot] == 'sleeping' then
    colour = '@C'
  end
  table.insert(sitem, string.format(' %s%-8s@x ', colour, wearlocs[item.wearslot]))
  table.insert(sitem, '@G]@w ') 
  
  if extras['flags'] then
    table.insert(sitem, '(') 
  
    count = 0
    for i,flag in pairs(flags) do
      local aardcolour = flagaardcolours[flag]
      count = count + 1
      if string.find(item.shortflags, flag) then
        if count == 1 then
          table.insert(sitem, ' @' .. aardcolour .. flag .. ' ')
        else
          table.insert(sitem, '@' .. aardcolour .. flag .. ' ')
        end
      else
        if count == 1 then
          table.insert(sitem, '   ')
        else
          table.insert(sitem, '  ')
        end
      end
    end
    table.insert(sitem, '@w)')

    table.insert(sitem, ' ')
  end

  -- Level
  table.insert(sitem, '(')
  table.insert(sitem, string.format("@G%3s@w", tostring(item.level or "")))
  table.insert(sitem, ') ')

  if extras['serial'] then
    table.insert(sitem, '(@x136')
    table.insert(sitem, string.format("%-12s", tostring(item.serial or '')))
    table.insert(sitem, '@w)  ')        
  end
  
  if extras['score'] then
    table.insert(sitem, '(@C')    
    table.insert(sitem, string.format("%5s", tostring(item.score or 'Unkn')))
    table.insert(sitem, '@w)  ')        
  end  
  
  -- Name
  table.insert(sitem, item.cname)

  return sitem
end
