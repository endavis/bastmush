-- $Id$

require 'miniwin'
require 'tprint'

Mastertabwin = Miniwin:subclass()
--string.gsub(tests, "[a-zA-z]", " ")
-- add hide all and show all menu items

function Mastertabwin:initialize(args)
  self.classinit = true
  super(self, args)   -- notice call to superclass's constructor
  self.tabs = {}
  self.tab_padding = 10
  self.text = {}
  self.tabcount = 0
--  self:add_setting( 'orientation', {type="number", help="orientation of the tabs, 0 = horizontal, 1 = vertical", low=0, high=1, default=0, sortlev=44})

  local td = {}
  td.id = GetPluginID()
  td.text = "Show All"
  td.func = self.showall
  td.name = 'z1Show all'
  td.win = self.win .. 'ShowAll'
  td.popup = "Show all Windows"
  self:addtab(td)
  td = {}
  td.id = GetPluginID()
  td.text = "Hide All"
  td.func = self.hideall
  td.name = 'z2Hide all'
  td.win = self.win .. 'HideAll'
  td.popup = "Hide all Windows"
  self:addtab(td)
end

function Mastertabwin:hideall()
  for i,v in pairs(self.tabs) do
    WindowShow(v.win, false)
  end
end

function Mastertabwin:showall()
  for i,v in pairs(self.tabs) do
    WindowShow(v.win, true)
  end
end

function Mastertabwin:counttabs()
  local count = 0
  for i,v in pairs(self.tabs) do
    count = count + 1
  end
  return count
end

function Mastertabwin:addtab(args)
  self.tabs[args.win] = args
  self:drawtabs()
end

function Mastertabwin:removetab(args)
  self.tabs[args.win] = nil
  self:drawtabs()
end

function Mastertabwin:createtabstyle(key, start)
  local tstyle = {}
  tstyle.text = self.tabs[key].text
  tstyle.mousedown = self.tabs[key].func or self.toggletab
  tstyle.hint = self.tabs[key].popup or "Toggle " .. self.tabs[key].name
  tstyle.hotspot_id = key
  tstyle.textcolour = self.hyperlink_colour
  tstyle.start = start
  return tstyle
end

function Mastertabwin:toggletab(flags, hotspot_id)
  WindowShow(hotspot_id, not (WindowInfo(hotspot_id, 5)))
end

function Mastertabwin:drawtabs()
  local ttext = {}
  start = 0
  for i,v in tableSort(self.tabs, 'name', 'Default') do
    start = start + self.tab_padding / 2
    style = self:createtabstyle(i, start)
    table.insert(ttext, style)
    start = start + WindowTextWidth (self.win, self.default_font_id, style.text) + self.tab_padding / 2
  end
  self:createwin({ttext})
end

function Mastertabwin:drawwin()
  super(self)
  if self.window_data ~= nil then
    for i,v in ipairs(self.window_data) do
      for x,y in ipairs(v.text) do
        if x ~= 1 then
          WindowLine (self.win, y.start - self.tab_padding / 2, 0, y.start - self.tab_padding / 2, self.window_data.height, ColourNameToRGB ("white"), 0, 1)
        end
      end
    end
  end
end


function sort_table_keys(ttable, sortkey)
  --[[
     sort the keys of the options table
  --]]
  local function sortfunc (a, b)
    return (ttable[a][sortkey] < ttable[b][sortkey])
  end


  local t2 = {}
  for i,v in pairs(ttable) do
    table.insert(t2, i)
  end
  table.sort(t2, sortfunc)

  return t2

end
