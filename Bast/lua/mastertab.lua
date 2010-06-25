-- $Id$
--[[
  if hide windows is pushed twice it doesn't remember what was hidden
--]]
require 'miniwin'
require 'tprint'
require 'copytable'

Mastertabwin = Miniwin:subclass()
--string.gsub(tests, "[a-zA-z]", " ")
-- add hide all and show all menu items

function Mastertabwin:initialize(args)
  super(self, args)   -- notice call to superclass's constructor
  self.tabs = {}
  self.tab_padding = 10
  self.text = {}
  self.tabcount = 0
  self.hotspots = {}
  self.alreadyhidden = false
  self:add_setting( 'orientation', {type="number", help="orientation of the tabs, 0 = horizontal, 1 = vertical", low=0, high=1, default=1, sortlev=44})

  local td = {}
  td.id = GetPluginID()
  td.text = " Show Windows "
  td.func = self.showall
  td.name = 'z1Show all'
  td.win = self.id .. 'ShowAll'
  td.popup = " Show Windows "
  self:addtab(td)
  td = {}
  td.id = GetPluginID()
  td.text = " Hide Windows "
  td.func = self.hideall
  td.name = 'z2Hide all'
  td.win = self.id .. 'HideAll'
  td.popup = " Hide Windows "
  self:addtab(td)

end

function Mastertabwin:hideall()
  if not self.alreadyhidden then
    self.alreadyhidden = true
    for i,v in pairs(self.tabs) do
      v.last = WindowInfo(v.win, 5)
      WindowShow(v.win, false)
    end
  end
end

function Mastertabwin:showall()
  for i,v in pairs(self.tabs) do
    if v.last ~= nil then
      WindowShow(v.win, v.last)
    end
  end
  self.alreadyhidden = false
end

function Mastertabwin:counttabs()
  local count = 0
  for i,v in pairs(self.tabs) do
    count = count + 1
  end
  return count
end

function Mastertabwin:addtab(args)
  self:mdebug('addtab: ', args)
  self.tabs[args.win] = args
  self:drawtabs()
end

function Mastertabwin:removetab(args)
  self.tabs[args.win] = nil
  self:drawtabs()
end

function Mastertabwin:createtabstyle(start, key, newstyle)
  local tstyle = copytable.deep(newstyle)
  tstyle.start = start
  tstyle.text = newstyle.text
  tstyle.length = WindowTextWidth (self.id, self.default_font_id, strip_colours(tstyle.text))
  if self.tabs[key].win then
    tstyle.mousedown = self.tabs[key].func or self.toggletab
    tstyle.hint = self.tabs[key].popup or "Toggle " .. self.tabs[key].name
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
  if self.orientation == 0 then
    self:drawtabs_horizontal()
  elseif self.orientation == 1 then
    self:drawtabs_vertical()
  end
  self:show(true)
end

function Mastertabwin:drawtabs_vertical()
  self:mdebug('drawtabs_vertical')
  local ttext = {}
  for i,v in tableSort(self.tabs, 'name', 'Default') do
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
    table.insert(ttext, tstyle)
  end
  self:mdebug('ttext in drawtabs_vertical', ttext)
  self:createwin(ttext)
end

function Mastertabwin:drawtabs_horizontal()
  self:mdebug('drawtabs_horizontal')
  outputwinwidth = GetInfo(281)
  local alltext = {}
  local ttext = {}
  local start = self.width_padding
  for i,v in tableSort(self.tabs, 'name', 'Default') do
    start = start + self.tab_padding / 2
    v.start = start
    if type(v.text) == 'table' then
      for init,istyle in ipairs(v.text) do
        local style = self:createtabstyle(start, i, istyle)
        table.insert(ttext, style)
        start = start + style.length
      end
      start = start + self.tab_padding / 2
      v['end'] = start
    else
      v.start = start
      local style = self:createtabstyle(start, i, {text = v.text})
      table.insert(ttext, style)
      start = start + style.length + self.tab_padding / 2
      v['end'] = start
    end
    if start > outputwinwidth / 2 then
      table.insert(alltext, ttext)
      ttext = {}
    end
    if next(ttext) then
      table.insert(alltext, ttext)
    end
  end
  self:mdebug('ttext in drawtabs_horizontal', ttext)
  self:mdebug('alltext in drawtabs_horizontal', alltext)
  self:createwin(alltext)
end

function Mastertabwin:drawwin()
  self:mdebug('drawing tab win')
  if not next(self.text) then
    return
  end

  if self.change_orient then
    self.change_orient = false
    self:drawtabs()
  end

  self:pre_create_window_internal()

  if self.orientation == 1 then
    j = 1
    for i,v in tableSort(self.tabs, 'name', 'Default') do
      local tabcolour = v.tabcolour or self.bg_colour
      local bcolour = self:get_colour(tabcolour)
      WindowRectOp (self.id, 2, self.width_padding, self:get_top_of_line(j), self:calc_window_width() - self.width_padding, self:get_bottom_of_line(j), bcolour)
      if j > 1 then
        WindowLine (self.id, 1, self:get_top_of_line(j), self:calc_window_width() - 1, self:get_top_of_line(j), ColourNameToRGB ("white"), 0, 1)
      end
      j = j + 1
    end
  end

  if self.orientation == 0 then
    for i,v in tableSort(self.tabs, 'name', 'Default') do
      local tabcolour = v.tabcolour or self.bg_colour
      local bcolour = self:get_colour(tabcolour)
      local tend = v['end']
      if tend > self:calc_window_width() - self.width_padding then
        tend = self:calc_window_width() - self.width_padding
      end

      WindowRectOp (self.id, 2, v.start - self.tab_padding / 2, self:get_top_of_line(1), v['end'], self:get_bottom_of_line(1), bcolour)
      WindowLine (self.id, v['end'] - 1, 0, v['end'] - 1, self.window_data.height, ColourNameToRGB ("white"), 0, 1)
    end
  end

  for i, v in ipairs (self.window_data) do
    self:Display_Line (i, self.window_data[i].text)
  end -- for

  self:post_create_window_internal()

end

function Mastertabwin:set(option, value, args)
   if option == 'orientation' then
     self.change_orient = true
   end
   retcode = super(self, option, value, args)
   return retcode
end
