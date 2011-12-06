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
  self.dontuseaardz = true
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
  td.pluginid = GetPluginID()
  td.text = " Show Windows "
  td.func = self.showall
  td.name = 'z1Show all'
  td.objectid = self.id .. 'ShowAll'
  td.winid = self.id .. 'ShowAll'
  td.popup = " Show Windows "
  td.fake = true
  self:addwtab(td)
  td = {}
  td.pluginid = GetPluginID()
  td.text = " Hide Windows "
  td.func = self.hideall
  td.objectid = self.id .. 'HideAll'
  td.name = 'z2Hide all'
  td.winid = self.id .. 'HideAll'
  td.popup = " Hide Windows "
  td.fake = true
  self:addwtab(td)
  -- add a show hidden windows
end

function Mastertabwin:hideall()
  if not self.alreadyhidden then
    self.alreadyhidden = true
    for i,v in pairs(self.wtabs) do
      if v.fake ~= true then
        local id = v.objectid
        local plugin = v.pluginid
        local ttable = {flag=false, id=id}
        v.last = WindowInfo(v.winid, 5)
        CallPlugin(plugin, 'showwin', serialize.save_simple( ttable ))
        --WindowShow(v.win, false)
      end
    end
  end
end

function Mastertabwin:showall()
  for i,v in pairs(self.wtabs) do
    if v.last ~= nil and v.fake ~= true then
      local id = v.objectid
      local plugin = v.pluginid
      local ttable = {flag=v.last, id=id}
      CallPlugin(plugin, 'showwin', serialize.save_simple( ttable ))
      --indowShow(v.win, v.last)
    end
  end
  self.alreadyhidden = false
end

function Mastertabwin:addwtab(args)
  if args.winid ~= self.winid then
    self:mdebug('addtab: ', args)
    self.wtabs[args.objectid] = args
    self:drawtabs()
  end
end

function Mastertabwin:removewtab(args)
  self.wtabs[args.objectid] = nil
  self:drawtabs()
end

function Mastertabwin:createtabstyle(start, key, newstyle)
  local tstyle = copytable.deep(newstyle)
  tstyle.start = start
  tstyle.text = newstyle.text
  tstyle.length = WindowTextWidth (self.id, self.default_font_id, strip_colours(tstyle.text))
  if self.wtabs[key].winid then
    tstyle.mouseup = self.tabclick
    tstyle.hint = self.wtabs[key].popup or "Do stuff to " .. self.wtabs[key].name
    tstyle.hotspot_id = key
    self.hotspots[key] = key
  end
  return tstyle
end

function Mastertabwin:buildmenu(hotspot_id)
  local menu = self.wtabs[hotspot_id].name
  local menu = menu .. '|| Bring to Front | Send to Back | Show | Hide'

  return menu
end

function Mastertabwin:menuclickwindow(result, hotspot_id)
  local plugincmd = GetPluginVariable(self.wtabs[hotspot_id].pluginid, "cmd")
  if result:match("Bring to Front") then
    Execute(plugincmd .. ' ' .. self.wtabs[hotspot_id].name .. ' front')
  elseif result:match("Send to Back") then
    Execute(plugincmd .. ' ' .. self.wtabs[hotspot_id].name .. ' back')
  elseif result:match("Show") then
    Execute(plugincmd .. ' ' .. self.wtabs[hotspot_id].name .. ' show')
  elseif result:match("Hide") then
    Execute(plugincmd .. ' ' .. self.wtabs[hotspot_id].name .. ' hide')
  end
end

function Mastertabwin:tabclick(flags, hotspot_id)
  -- right click for window menu, left click for plugin menu
  if bit.band(flags, 0x10) ~= 0 then
    -- left
    if self.wtabs[hotspot_id].func then
      self.wtabs[hotspot_id].func(self)
    else
      self:mdebug('flags', flags, 'hotspot_id', hotspot_id)
      local id = self.wtabs[hotspot_id].objectid
      local flag = not (WindowInfo(self.wtabs[hotspot_id].winid, 5))
      local plugin = self.wtabs[hotspot_id].pluginid
      local ttable = {flag=flag, id=id}
      CallPlugin(plugin, 'showwin', serialize.save_simple( ttable ))
      --WindowShow(self.hotspots[hotspot_id], not (WindowInfo(self.hotspots[hotspot_id], 5)))
    end
  elseif bit.band(flags, 0x20) ~= 0 and self.wtabs[hotspot_id].func == nil then
    -- right
    local result = WindowMenu(self.winid, WindowInfo (self.winid, 14), WindowInfo (self.winid, 15), self:buildmenu(hotspot_id))
    if result ~= "" then
      self:menuclickwindow(result, hotspot_id)
    end
  end
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
  self:addtab('default', alltext)
  self:changetotab('default')

end

function Mastertabwin:set(option, value, args)
   retcode = super(self, option, value, args)
   if retcode and option == 'orientation' and not self.classinit then
     self:drawtabs()
   end
   return retcode
end
