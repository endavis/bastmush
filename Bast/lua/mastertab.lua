-- $Id$
--[[
  if hide windows is pushed twice it doesn't remember what was hidden
--]]
require 'miniwin'
require 'tprint'
require 'copytable'
require 'tablefuncs'

Mastertabwin = Miniwin:subclass()
--string.gsub(tests, "[a-zA-z]", " ")
-- add hide all and show all menu items

function Mastertabwin:initialize(args)
  super(self, args)   -- notice call to superclass's constructor
  self.wtabs = {}
  --self.tab_padding = 10
  self.tab_padding = 0
  self.text = {}
  self.tabcount = 0
  self.hotspots = {}
  self.alreadyhidden = false
  self.notitletext = true
  self:add_setting( 'orientation', {type="number", help="orientation of the tabs, 0 = horizontal, 1 = vertical", low=0, high=1, default=1, sortlev=44, longname="Change Orientation"})

  local td = {}
  td.id = GetPluginID()
  td.text = " Show Windows "
  td.func = self.showall
  td.name = 'z1Show all'
  td.win = self.id .. 'ShowAll'
  td.popup = " Show Windows "
  self:addwtab(td)
  td = {}
  td.id = GetPluginID()
  td.text = " Hide Windows "
  td.func = self.hideall
  td.name = 'z2Hide all'
  td.win = self.id .. 'HideAll'
  td.popup = " Hide Windows "
  self:addwtab(td)

end

function Mastertabwin:hideall()
  if not self.alreadyhidden then
    self.alreadyhidden = true
    for i,v in pairs(self.wtabs) do
      v.last = WindowInfo(v.win, 5)
      WindowShow(v.win, false)
    end
  end
end

function Mastertabwin:showall()
  for i,v in pairs(self.wtabs) do
    if v.last ~= nil then
      WindowShow(v.win, v.last)
    end
  end
  self.alreadyhidden = false
end

function Mastertabwin:addwtab(args)
  if args.win ~= self.win then
    self:mdebug('addtab: ', args)
    self.wtabs[args.win] = args
    self:drawtabs()
  end
end

function Mastertabwin:removewtab(args)
  self.wtabs[args.win] = nil
  self:drawtabs()
end

function Mastertabwin:createtabstyle(start, key, newstyle)
  local tstyle = copytable.deep(newstyle)
  tstyle.start = start
  tstyle.text = newstyle.text
  tstyle.length = WindowTextWidth (self.id, self.default_font_id, strip_colours(tstyle.text))
  if self.wtabs[key].win then
    tstyle.mousedown = self.wtabs[key].func or self.toggletab
    tstyle.hint = self.wtabs[key].popup or "Toggle " .. self.wtabs[key].name
    tstyle.hotspot_id = key .. start
    self.hotspots[key .. start] = key
  end
  return tstyle
end

function Mastertabwin:toggletab(flags, hotspot_id)
  self:mdebug('flags', flags, 'hotspot_id', hotspot_id)
  WindowShow(self.hotspots[hotspot_id], not (WindowInfo(self.hotspots[hotspot_id], 5)))
end

function Mastertabwin:drawtabs()
  if not self.disabled then
    if self.orientation == 0 then
      self:drawtabs_horizontal()
    elseif self.orientation == 1 then
      self:drawtabs_vertical()
    end
    self:show(true)
  end
end

function Mastertabwin:drawtabs_vertical()
  --self:mdebug('drawtabs_vertical')
  local ttext = {}
  for i,v in tableSort(self.wtabs, 'name', 'Default') do
    --self:mdebug('v in drawtab_vertical', v)
    --local tabcolour = v.tabcolour or self.bg_colour
    local start = self.width_padding
    local tstyle = {}
    if type(v.text) == 'table' then
      for init,istyle in ipairs(v.text) do
        local style = self:createtabstyle(start, i, istyle)
        style.hjust = 'center'
        table.insert(tstyle, style)
      end
      v['end'] = nil
    else
      local style = self:createtabstyle(start, i, {text = v.text})
      style.hjust = 'center'
      table.insert(tstyle, style)
      v['end'] = nil
    end
--     tstyle.leftborder = true
--     tstyle.rightborder = true
--     tstyle.topborder = true
--     tstyle.bottomborder = true
    tstyle.lineborder = true
    tstyle.bordercolour = self.border_colour
    tstyle.backcolour = v.tabcolour or nil
    --self:mdebug('style being added', tstyle)
    table.insert(ttext, tstyle)
  end
  --self:mdebug('ttext in drawtabs_vertical', ttext)
  self:addtab('default', ttext)
  self:changetotab('default')
end

function Mastertabwin:drawtabs_horizontal()
  --self:mdebug('drawtabs_horizontal')
  outputwinwidth = GetInfo(281)
  local alltext = {}
  local ttext = {}
  local start = self.width_padding

  for i,v in tableSort(self.wtabs, 'name', 'Default') do
    start = start + self.tab_padding / 2
    v.start = start
    local tstyle = {}
    if type(v.text) == 'table' then
      for init,istyle in ipairs(v.text) do
        local style = self:createtabstyle(start, i, istyle)
        tstyle.topborder = true
        tstyle.bottomborder = true
        tstyle.backcolour = v.tabcolour or nil
        table.insert(tstyle, style)
        start = start + style.length
      end
      start = start + self.tab_padding / 2
      v['end'] = start
    else
      v.start = start
      local style = self:createtabstyle(start, i, {text = v.text})
      style.backcolour = v.tabcolour or nil
      table.insert(tstyle, style)
      start = start + style.length + self.tab_padding / 2
      v['end'] = start
    end
    tstyle[1].leftborder = true
    tstyle[#tstyle].rightborder = true
    tableExtend(ttext, tstyle)
    --if self.x + start > (outputwinwidth - self.x) / 2 then
    --  table.insert(alltext, ttext)
    --  start = self.width_padding
    --  ttext = {}
    --end
  end
  table.insert(alltext, ttext)
  --self:mdebug('ttext in drawtabs_horizontal', ttext)
  self:mdebug('alltext in drawtabs_horizontal', alltext)
  self:addtab('default', ttext)
  self:changetotab('default')

end

function Mastertabwin:set(option, value, args)
   if option == 'orientation' then
     self.change_orient = true
   end
   retcode = super(self, option, value, args)
   return retcode
end
